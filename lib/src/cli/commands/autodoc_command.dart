import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:args/command_runner.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../triage/utils/config.dart';
import '../../triage/utils/run_context.dart';
import '../manage_cicd_cli.dart';
import '../options/autodoc_options.dart';
import '../utils/autodoc_scaffold.dart'
    show
        kAutodocIndexPath,
        resolveAutodocOutputPath,
        scaffoldAutodocJson,
        validateAutodocPath,
        validateAutodocSubPackage;
import '../utils/gemini_utils.dart';
import '../utils/logger.dart';
import '../utils/process_runner.dart';
import '../utils/repo_utils.dart';
import '../utils/step_summary.dart';
import '../utils/sub_package_utils.dart';
import '../utils/version_detection.dart';

const String _kGeminiProModel = 'gemini-3.1-pro-preview';

/// Generate/update documentation for proto modules using Gemini 3.1 Pro Preview.
///
/// Uses autodoc.json for configuration, hash-based change detection for
/// incremental updates, and parallel Gemini execution.
class AutodocCommand extends Command<void> {
  @override
  final String name = 'autodoc';

  @override
  final String description = 'Generate/update module docs (--init, --force, --module, --dry-run).';

  AutodocCommand() {
    AutodocOptionsArgParser.populateParser(argParser);
  }

  @override
  Future<void> run() async {
    final repoRoot = RepoUtils.findRepoRoot();
    if (repoRoot == null) {
      Logger.error('Could not find ${config.repoName} repo root.');
      exit(1);
    }
    final global = ManageCicdCli.parseGlobalOptions(globalResults);
    final adOpts = AutodocOptions.fromArgResults(argResults!);

    Logger.header('Autodoc: Documentation Generation');

    final force = adOpts.force;
    final dryRun = global.dryRun;
    final init = adOpts.init;
    final targetModule = adOpts.module;

    final configPath = '$repoRoot/$kRuntimeCiDir/autodoc.json';

    // Support legacy location at repo root -- migrate if found
    final legacyPath = '$repoRoot/autodoc.json';
    if (!File(configPath).existsSync() && File(legacyPath).existsSync()) {
      Directory('$repoRoot/$kRuntimeCiDir').createSync(recursive: true);
      File(legacyPath).copySync(configPath);
      File(legacyPath).deleteSync();
      Logger.success('Migrated autodoc.json to $kRuntimeCiDir/autodoc.json');
    }

    if (init) {
      if (File(configPath).existsSync()) {
        Logger.info('$kRuntimeCiDir/autodoc.json already exists.');
        Logger.info('Use `manage_cicd autodoc --force` to regenerate all docs.');
      } else {
        final created = scaffoldAutodocJson(repoRoot);
        if (created) {
          Logger.success('Created $kRuntimeCiDir/autodoc.json');
          Logger.info('Next: run `manage_cicd autodoc` to generate docs.');
        } else {
          Logger.warn('No lib/ directory found — cannot scaffold autodoc.json.');
        }
      }
      return;
    }

    if (!File(configPath).existsSync()) {
      Logger.error('autodoc.json not found at $kRuntimeCiDir/autodoc.json');
      Logger.error('Run: dart run runtime_ci_tooling:manage_cicd autodoc --init');
      return;
    }

    // Load config
    final configContent = File(configPath).readAsStringSync();
    final autodocConfig = json.decode(configContent) as Map<String, dynamic>;
    final rawModules = (autodocConfig['modules'] as List).cast<Map<String, dynamic>>();
    final maxConcurrent = (autodocConfig['max_concurrent'] as int?) ?? 4;
    final templates = (autodocConfig['templates'] as Map<String, dynamic>?) ?? {};

    // Validate module paths — skip modules with unsafe paths (traversal, absolute, etc.)
    final modules = <Map<String, dynamic>>[];
    for (final module in rawModules) {
      final id = (module['id'] as String?) ?? '<unknown>';
      final errors = <String>[];

      final outputErr = validateAutodocPath(module['output_path'], fieldName: 'output_path');
      if (outputErr != null) errors.add(outputErr);

      final spErr = validateAutodocSubPackage(module['sub_package']);
      if (spErr != null) errors.add(spErr);

      for (final field in ['source_paths', 'lib_paths']) {
        final paths = module[field];
        if (paths is! List) {
          errors.add('$field must be a list of strings');
          continue;
        }
        for (final entry in paths) {
          final pathErr = validateAutodocPath(entry, fieldName: field);
          if (pathErr != null) errors.add(pathErr);
        }
      }

      if (errors.isNotEmpty) {
        Logger.warn('Skipping autodoc module "$id": ${errors.join('; ')}');
        continue;
      }
      modules.add(module);
    }

    if (modules.isEmpty) {
      if (rawModules.isEmpty) {
        Logger.warn('No autodoc modules configured; nothing to generate.');
      } else {
        Logger.warn(
          'All ${rawModules.length} configured autodoc module(s) were invalid and have been skipped; nothing to generate.',
        );
      }
      return;
    }

    if (!GeminiUtils.geminiAvailable(warnOnly: true)) {
      Logger.warn('Gemini unavailable -- skipping autodoc generation.');
      return;
    }

    final subPackages = SubPackageUtils.loadSubPackages(repoRoot);
    SubPackageUtils.logSubPackages(subPackages);
    var subPackageDiffContext = '';
    if (subPackages.isNotEmpty) {
      String prevTag;
      try {
        prevTag = VersionDetection.detectPrevTag(repoRoot, verbose: global.verbose);
      } catch (_) {
        prevTag = '';
      }
      subPackageDiffContext = SubPackageUtils.buildSubPackageDiffContext(
        repoRoot: repoRoot,
        prevTag: prevTag,
        subPackages: subPackages,
        verbose: global.verbose,
      );
    }

    // Build task queue based on hash comparison
    final tasks = <Future<void> Function()>[];
    final updatedModules = <String>[];
    var skippedCount = 0;

    for (final module in modules) {
      final id = module['id'] as String;
      if (targetModule != null && id != targetModule) continue;

      final sourcePaths = (module['source_paths'] as List).cast<String>();
      final moduleSubPackage = _resolveModuleSubPackage(
        module: module,
        sourcePaths: sourcePaths,
        subPackages: subPackages,
      );
      if (moduleSubPackage != null && module['sub_package'] == null) {
        module['sub_package'] = moduleSubPackage;
      }

      final configuredOutputPath = module['output_path'] as String;
      final normalizedOutputPath = _resolveOutputPathForModule(
        configuredOutputPath: configuredOutputPath,
        moduleSubPackage: moduleSubPackage,
      );
      if (normalizedOutputPath != configuredOutputPath) {
        module['output_path'] = normalizedOutputPath;
      }

      final currentHash = _computeModuleHash(
        repoRoot,
        sourcePaths,
        moduleSubPackage: moduleSubPackage,
        outputPath: normalizedOutputPath,
      );
      final previousHash = module['hash'] as String? ?? '';

      if (currentHash == previousHash && !force) {
        skippedCount++;
        if (global.verbose) Logger.info('  $id: unchanged, skipping');
        continue;
      }

      final name = module['name'] as String;
      final outputPath = '$repoRoot/$normalizedOutputPath';
      final libPaths = (module['lib_paths'] as List?)?.cast<String>() ?? [];
      final generateTypes = (module['generate'] as List).cast<String>();
      final libDir = libPaths.isNotEmpty ? '$repoRoot/${libPaths.first}' : '';
      final packageSuffix = moduleSubPackage == null ? '' : ' [sub-package: $moduleSubPackage]';

      Logger.info(
        '  $id ($name)$packageSuffix: ${force ? "forced" : "changed"} -> generating ${generateTypes.join(", ")}',
      );

      if (dryRun) {
        updatedModules.add(id);
        continue;
      }

      // Create output directory
      Directory(outputPath).createSync(recursive: true);

      // Queue Gemini tasks for each doc type
      for (final docType in generateTypes) {
        final templateKey = docType;
        final templatePath = templates[templateKey] as String?;
        if (templatePath == null) {
          Logger.warn('  No template for doc type: $docType');
          continue;
        }

        tasks.add(
          () => _generateAutodocFile(
            repoRoot: repoRoot,
            moduleId: id,
            moduleName: name,
            docType: docType,
            templatePath: templatePath,
            sourceDir: '$repoRoot/${sourcePaths.first}',
            libDir: libDir,
            outputPath: outputPath,
            previousHash: previousHash,
            moduleSubPackage: moduleSubPackage,
            subPackageDiffContext: subPackageDiffContext,
            hierarchicalAutodocInstructions: SubPackageUtils.buildHierarchicalAutodocInstructions(
              moduleName: name,
              subPackages: subPackages,
              moduleSubPackage: moduleSubPackage,
            ),
            verbose: global.verbose,
          ),
        );
      }

      updatedModules.add(id);
      // Update hash
      module['hash'] = currentHash;
      module['last_updated'] = DateTime.now().toUtc().toIso8601String();
    }

    if (dryRun) {
      Logger.info('');
      Logger.info(
        '[DRY-RUN] Would generate docs for ${updatedModules.length} modules, skipped $skippedCount unchanged',
      );
      for (final id in updatedModules) {
        Logger.info('  - $id');
      }
      return;
    }

    if (tasks.isEmpty) {
      Logger.success('All $skippedCount modules unchanged. Nothing to generate.');
      return;
    }

    // Execute with a true worker pool — starts the next task as soon as any slot frees.
    Logger.info('');
    Logger.info('Running ${tasks.length} Gemini doc generation tasks (max $maxConcurrent parallel)...');

    await _forEachConcurrent(tasks, maxConcurrent);

    if (subPackages.isNotEmpty) {
      _writeHierarchicalDocsIndex(repoRoot: repoRoot, modules: modules, subPackages: subPackages);
    }

    // Save updated config with new hashes
    File(configPath).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(autodocConfig));

    Logger.success('Generated docs for ${updatedModules.length} modules, skipped $skippedCount unchanged.');
    Logger.info('Updated hashes saved to $kRuntimeCiDir/autodoc.json');

    StepSummary.write('''
## Autodoc: Documentation Generation

| Metric | Value |
|--------|-------|
| Modules updated | ${updatedModules.length} |
| Modules skipped | $skippedCount |
| Total tasks | ${tasks.length} |

### Updated Modules
${updatedModules.map((id) => '- `$id`').join('\n')}

${StepSummary.artifactLink()}
''');
  }

  /// Generate a single autodoc file using a two-pass Gemini pipeline:
  ///   Pass 1 (Author): Generates the initial documentation.
  ///   Pass 2 (Reviewer): Fact-checks, corrects Dart naming conventions,
  ///     fills gaps, and enhances detail/coverage.
  Future<void> _generateAutodocFile({
    required String repoRoot,
    required String moduleId,
    required String moduleName,
    required String docType,
    required String templatePath,
    required String sourceDir,
    required String libDir,
    required String outputPath,
    required String previousHash,
    required String? moduleSubPackage,
    required String subPackageDiffContext,
    required String hierarchicalAutodocInstructions,
    bool verbose = false,
  }) async {
    final outputFileName = switch (docType) {
      'quickstart' => 'QUICKSTART.md',
      'api_reference' => 'API_REFERENCE.md',
      'examples' => 'EXAMPLES.md',
      'migration' => 'MIGRATION.md',
      _ => '$docType.md',
    };

    final absOutputFile = '$outputPath/$outputFileName';

    Logger.info('  [$moduleId] Pass 1: Generating $outputFileName...');

    // Generate prompt from template
    final promptArgs = [moduleName, sourceDir];
    if (libDir.isNotEmpty) promptArgs.add(libDir);
    if (docType == 'migration' && previousHash.isNotEmpty) {
      promptArgs.add(previousHash);
    }

    final prompt = CiProcessRunner.runSync(
      'dart run "$repoRoot/$templatePath" ${promptArgs.map((a) => '"$a"').join(' ')}',
      repoRoot,
      verbose: verbose,
    );

    if (prompt.isEmpty) {
      Logger.warn('  [$moduleId] Empty prompt for $docType, skipping');
      return;
    }

    // Build context includes
    final includes = <String>['"@${sourceDir.replaceFirst('$repoRoot/', '')}"'];
    if (libDir.isNotEmpty) {
      final relLib = libDir.replaceFirst('$repoRoot/', '');
      if (Directory(libDir).existsSync()) includes.add('"@$relLib"');
    }

    // ══════════════════════════════════════════════════════════════════
    // PASS 1: Author -- generate the initial documentation
    // ══════════════════════════════════════════════════════════════════
    final pass1Prompt = File('$outputPath/.${docType}_pass1.txt');
    pass1Prompt.writeAsStringSync('''
$prompt

${moduleSubPackage == null ? '' : 'This module belongs to sub-package: "$moduleSubPackage".'}
${subPackageDiffContext.isEmpty ? '' : subPackageDiffContext}
${hierarchicalAutodocInstructions.isEmpty ? '' : hierarchicalAutodocInstructions}

## OUTPUT INSTRUCTIONS

Write the generated documentation to this exact file path using write_file:
  $absOutputFile

Be extremely thorough and detailed. Read ALL proto files and ALL generated
Dart code in the included context directories before writing.

CRITICAL Dart naming rules for protobuf-generated code:
- Proto field names with underscores (e.g., batch_id, send_at, mail_settings)
  become camelCase in Dart (e.g., batchId, sendAt, mailSettings).
- Always use camelCase for Dart field access in code examples.
- Message/Enum names stay PascalCase as defined in the proto.

Cover EVERY message, service, enum, and field defined in the proto files.
Do not skip any -- completeness is more important than brevity.
''');

    final pass1Result = await _runGeminiWithRetry(
      command: 'cat "${pass1Prompt.path}" | gemini --yolo -m $_kGeminiProModel ${includes.join(" ")}',
      workingDirectory: repoRoot,
      taskLabel: '$moduleId/pass1',
    );

    if (pass1Prompt.existsSync()) pass1Prompt.deleteSync();

    if (pass1Result.exitCode != 0) {
      Logger.warn('  [$moduleId] Pass 1 failed: ${(pass1Result.stderr as String).trim()}');
      return;
    }

    final outputFile = File(absOutputFile);
    if (!outputFile.existsSync() || outputFile.lengthSync() < 100) {
      Logger.warn('  [$moduleId] Pass 1 did not produce $outputFileName');
      return;
    }

    final pass1Size = outputFile.lengthSync();
    Logger.info('  [$moduleId] Pass 1 complete: $pass1Size bytes');

    // ══════════════════════════════════════════════════════════════════
    // PASS 2: Reviewer -- fact-check, correct, and enhance
    // ══════════════════════════════════════════════════════════════════
    Logger.info('  [$moduleId] Pass 2: Reviewing $outputFileName...');

    final pass2Prompt = File('$outputPath/.${docType}_pass2.txt');
    pass2Prompt.writeAsStringSync('''
You are a senior technical reviewer for Dart/protobuf documentation.

Your task is to review and improve the file at:
  $absOutputFile

This documentation was auto-generated for the **$moduleName** module.
The proto definitions are in: ${sourceDir.replaceFirst('$repoRoot/', '')}
${libDir.isNotEmpty ? 'Generated Dart code is in: ${libDir.replaceFirst('$repoRoot/', '')}' : ''}
${moduleSubPackage == null ? '' : 'This module belongs to sub-package: "$moduleSubPackage".'}
${subPackageDiffContext.isEmpty ? '' : subPackageDiffContext}
${hierarchicalAutodocInstructions.isEmpty ? '' : hierarchicalAutodocInstructions}

## Review Checklist

### 1. Dart Naming Conventions (CRITICAL)
Protobuf-generated Dart code converts snake_case field names to camelCase:
  - batch_id -> batchId
  - send_at -> sendAt
  - mail_settings -> mailSettings
  - tracking_settings -> trackingSettings
  - click_tracking -> clickTracking
  - open_tracking -> openTracking
  - sandbox_mode -> sandboxMode
  - dynamic_template_data -> dynamicTemplateData
  - content_id -> contentId
  - custom_args -> customArgs
  - ip_pool_name -> ipPoolName
  - reply_to -> replyTo
  - reply_to_list -> replyToList
  - template_id -> templateId
  - enable_text -> enableText
  - substitution_tag -> substitutionTag
  - group_id -> groupId
  - groups_to_display -> groupsToDisplay

Fix ALL instances where snake_case is used for Dart field access in code blocks.
Message and enum names remain PascalCase (e.g., SendMailRequest, MailFrom).

### 2. Completeness
Read ALL proto definitions in the source directory. Ensure the documentation
covers every service RPC, every message type, every enum, and every field.
If anything is missing, add it with proper examples.

### 3. Code Correctness
- Every code block must use valid Dart syntax
- Import paths must be real: package:${config.repoName}/...
- Cascade notation (..field = value) must use the correct camelCase field name
- No fabricated class names, methods, or fields

### 4. Detail and Quality
- Add examples for any under-documented features
- Include proto field comments as documentation in the code examples
- Show the builder pattern (cascade ..) for constructing messages
- Cover edge cases and optional fields

## Instructions

Read the proto files, read the current documentation file, then use edit_file
to make all necessary corrections and enhancements in-place.
Write the corrected file to the same path: $absOutputFile
''');

    final pass2Result = await _runGeminiWithRetry(
      command: 'cat "${pass2Prompt.path}" | gemini --yolo -m $_kGeminiProModel ${includes.join(" ")}',
      workingDirectory: repoRoot,
      taskLabel: '$moduleId/pass2',
    );

    if (pass2Prompt.existsSync()) pass2Prompt.deleteSync();

    if (pass2Result.exitCode != 0) {
      Logger.warn('  [$moduleId] Pass 2 failed (keeping Pass 1 output): ${(pass2Result.stderr as String).trim()}');
    }

    // Verify final output
    if (outputFile.existsSync() && outputFile.lengthSync() > 100) {
      final finalSize = outputFile.lengthSync();
      final delta = finalSize - pass1Size;
      final deltaStr = delta >= 0 ? '+$delta' : '$delta';
      Logger.success('  [$moduleId] $outputFileName: $finalSize bytes ($deltaStr from review)');
      return;
    }

    Logger.warn('  [$moduleId] No $outputFileName produced');
  }

  /// Executes [tasks] (closures returning futures) with at most [concurrency] running at once.
  ///
  /// Unlike fixed-size batching, this starts the next task as soon as any slot frees,
  /// so the pool stays at capacity without idle gaps between waves.
  Future<void> _forEachConcurrent(List<Future<void> Function()> tasks, int concurrency) async {
    var index = 0;
    final active = <Future<void>>[];

    while (index < tasks.length || active.isNotEmpty) {
      while (active.length < concurrency && index < tasks.length) {
        final f = tasks[index++]();
        active.add(f);
        // ignore: unawaited_futures
        f.whenComplete(() => active.remove(f));
      }
      if (active.isNotEmpty) await Future.any(active);
    }
  }

  static const _maxRetries = 3;
  static const _retryDelays = [Duration(seconds: 5), Duration(seconds: 15), Duration(seconds: 45)];
  static final _retryablePattern = RegExp(
    r'(429|RESOURCE_EXHAUSTED|rate.?limit|quota|fetch.?failed|ECONNRESET|ETIMEDOUT|ENOTFOUND)',
    caseSensitive: false,
  );

  /// Runs a Gemini CLI shell command, retrying on rate-limit errors with exponential backoff.
  ///
  /// Returns a [ProcessResult] identical in structure to [Process.runSync] output.
  Future<ProcessResult> _runGeminiWithRetry({
    required String command,
    required String workingDirectory,
    required String taskLabel,
  }) async {
    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      final result = await Process.run(
        'sh',
        ['-c', command],
        workingDirectory: workingDirectory,
        environment: {...Platform.environment},
      );

      if (result.exitCode == 0) return result;

      final stderr = result.stderr as String;
      final attemptsLeft = _maxRetries - attempt;

      if (_retryablePattern.hasMatch(stderr) && attemptsLeft > 0) {
        final delay = _retryDelays[attempt.clamp(0, _retryDelays.length - 1)];
        Logger.warn('  [$taskLabel] Retrying in ${delay.inSeconds}s ($attemptsLeft left)');
        await Future.delayed(delay);
        continue;
      }

      return result; // non-retryable or retries exhausted
    }
    // Unreachable but required by Dart control flow analysis.
    return await Process.run('sh', ['-c', 'exit 1'], workingDirectory: workingDirectory);
  }

  /// Compute SHA256 hash of all source files in the given paths.
  String _computeModuleHash(String repoRoot, List<String> sourcePaths, {String? moduleSubPackage, String? outputPath}) {
    // Pure-Dart hashing so caching works on macOS/Windows and minimal CI images
    // (no dependency on sha256sum/shasum/xargs/find).
    final filePaths = <String>[];

    for (final relPath in sourcePaths) {
      final absPath = p.normalize(p.join(repoRoot, relPath));
      final dir = Directory(absPath);
      if (!dir.existsSync()) {
        // Still include the missing directory marker so a later appearance
        // changes the hash and triggers regeneration.
        filePaths.add('missing_dir:$absPath');
        continue;
      }

      for (final entity in dir.listSync(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final path = entity.path;
        if (path.endsWith('.dart') || path.endsWith('.proto')) {
          filePaths.add(path);
        }
      }
    }

    filePaths.sort();

    final builder = BytesBuilder(copy: false);

    if (moduleSubPackage != null) {
      builder.add(utf8.encode('sub_package:$moduleSubPackage'));
      builder.addByte(0);
    }
    if (outputPath != null) {
      builder.add(utf8.encode('output_path:$outputPath'));
      builder.addByte(0);
    }

    for (final path in filePaths) {
      // Include the path name in the digest so renames affect the hash.
      builder.add(utf8.encode(path));
      builder.addByte(0);

      if (!path.startsWith('missing_dir:')) {
        try {
          builder.add(File(path).readAsBytesSync());
        } catch (e) {
          Logger.warn('Could not read $path for module hash: $e');
        }
      }

      builder.addByte(0);
    }

    return sha256.convert(builder.takeBytes()).toString();
  }

  String? _resolveModuleSubPackage({
    required Map<String, dynamic> module,
    required List<String> sourcePaths,
    required List<Map<String, dynamic>> subPackages,
  }) {
    if (subPackages.isEmpty) return null;

    final explicit = module['sub_package'];
    if (explicit is String && explicit.trim().isNotEmpty) {
      final explicitName = explicit.trim();
      final exists = subPackages.any((pkg) => (pkg['name'] as String) == explicitName);
      if (exists) return explicitName;
    }

    final normalizedSources = sourcePaths.map((s) => p.posix.normalize(s).replaceFirst(RegExp(r'^/+'), '')).toList();
    for (final pkg in subPackages) {
      final packagePath = p.posix.normalize(pkg['path'] as String).replaceFirst(RegExp(r'^/+'), '');
      final packagePrefix = packagePath.endsWith('/') ? packagePath : '$packagePath/';
      if (normalizedSources.any((src) => src.startsWith(packagePrefix))) {
        return pkg['name'] as String;
      }
    }
    return null;
  }

  String _resolveOutputPathForModule({required String configuredOutputPath, required String? moduleSubPackage}) {
    return resolveAutodocOutputPath(configuredOutputPath: configuredOutputPath, moduleSubPackage: moduleSubPackage);
  }

  void _writeHierarchicalDocsIndex({
    required String repoRoot,
    required List<Map<String, dynamic>> modules,
    required List<Map<String, dynamic>> subPackages,
  }) {
    if (subPackages.isEmpty) return;

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final pkg in subPackages) {
      grouped[pkg['name'] as String] = <Map<String, dynamic>>[];
    }

    for (final module in modules) {
      final sourcePaths = (module['source_paths'] as List).cast<String>();
      final resolvedPackage = _resolveModuleSubPackage(
        module: module,
        sourcePaths: sourcePaths,
        subPackages: subPackages,
      );
      if (resolvedPackage == null) continue;
      grouped.putIfAbsent(resolvedPackage, () => <Map<String, dynamic>>[]).add(module);
    }

    final buf = StringBuffer()
      ..writeln('<!-- DO NOT EDIT: Auto-generated by `manage_cicd autodoc`. -->')
      ..writeln()
      ..writeln('# Documentation Index')
      ..writeln()
      ..writeln('Generated by `manage_cicd autodoc` for multi-package repositories.')
      ..writeln();

    for (final pkg in subPackages) {
      final packageName = pkg['name'] as String;
      final packageModules = grouped[packageName] ?? <Map<String, dynamic>>[];
      if (packageModules.isEmpty) continue;
      buf.writeln('## $packageName');
      buf.writeln();
      for (final module in packageModules) {
        final moduleName = module['name'] as String;
        final outputPath = (module['output_path'] as String).replaceFirst(RegExp(r'^docs/'), '');
        buf.writeln('- [$moduleName](./$outputPath)');
      }
      buf.writeln();
    }

    Directory('$repoRoot/docs').createSync(recursive: true);
    final indexFile = File('$repoRoot/$kAutodocIndexPath');
    indexFile.writeAsStringSync(buf.toString());
    Logger.info('Updated hierarchical docs index: $kAutodocIndexPath');
  }
}
