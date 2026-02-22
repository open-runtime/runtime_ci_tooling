import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../../triage/utils/config.dart';
import '../../triage/utils/run_context.dart';
import '../manage_cicd_cli.dart';
import '../options/autodoc_options.dart';
import '../utils/gemini_utils.dart';
import '../utils/logger.dart';
import '../utils/process_runner.dart';
import '../utils/repo_utils.dart';
import '../utils/step_summary.dart';

const String _kGeminiProModel = 'gemini-3-pro-preview';

/// Generate/update documentation for proto modules using Gemini Pro.
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
      Logger.info('--init: autodoc.json should be created manually or already exists.');
      if (File(configPath).existsSync()) {
        Logger.success('autodoc.json exists at $configPath');
      } else {
        Logger.error('autodoc.json not found. Create it at $kRuntimeCiDir/autodoc.json');
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
    final modules = (autodocConfig['modules'] as List).cast<Map<String, dynamic>>();
    final maxConcurrent = (autodocConfig['max_concurrent'] as int?) ?? 4;
    final templates = (autodocConfig['templates'] as Map<String, dynamic>?) ?? {};

    if (!GeminiUtils.geminiAvailable(warnOnly: true)) {
      Logger.warn('Gemini unavailable -- skipping autodoc generation.');
      return;
    }

    // Build task queue based on hash comparison
    final tasks = <Future<void>>[];
    final updatedModules = <String>[];
    var skippedCount = 0;

    for (final module in modules) {
      final id = module['id'] as String;
      if (targetModule != null && id != targetModule) continue;

      final sourcePaths = (module['source_paths'] as List).cast<String>();
      final currentHash = _computeModuleHash(repoRoot, sourcePaths);
      final previousHash = module['hash'] as String? ?? '';

      if (currentHash == previousHash && !force) {
        skippedCount++;
        if (global.verbose) Logger.info('  $id: unchanged, skipping');
        continue;
      }

      final name = module['name'] as String;
      final outputPath = '$repoRoot/${module['output_path']}';
      final libPaths = (module['lib_paths'] as List?)?.cast<String>() ?? [];
      final generateTypes = (module['generate'] as List).cast<String>();
      final libDir = libPaths.isNotEmpty ? '$repoRoot/${libPaths.first}' : '';

      Logger.info('  $id ($name): ${force ? "forced" : "changed"} -> generating ${generateTypes.join(", ")}');

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
          _generateAutodocFile(
            repoRoot: repoRoot,
            moduleId: id,
            moduleName: name,
            docType: docType,
            templatePath: templatePath,
            sourceDir: '$repoRoot/${sourcePaths.first}',
            libDir: libDir,
            outputPath: outputPath,
            previousHash: previousHash,
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

    // Execute in parallel batches
    Logger.info('');
    Logger.info('Running ${tasks.length} Gemini doc generation tasks (max $maxConcurrent parallel)...');

    for (var i = 0; i < tasks.length; i += maxConcurrent) {
      final batch = tasks.skip(i).take(maxConcurrent).toList();
      await Future.wait(batch);
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
      'dart run $repoRoot/$templatePath ${promptArgs.map((a) => '"$a"').join(' ')}',
      repoRoot,
      verbose: verbose,
    );

    if (prompt.isEmpty) {
      Logger.warn('  [$moduleId] Empty prompt for $docType, skipping');
      return;
    }

    // Build context includes
    final includes = <String>['@${sourceDir.replaceFirst('$repoRoot/', '')}'];
    if (libDir.isNotEmpty) {
      final relLib = libDir.replaceFirst('$repoRoot/', '');
      if (Directory(libDir).existsSync()) includes.add('@$relLib');
    }

    // ══════════════════════════════════════════════════════════════════
    // PASS 1: Author -- generate the initial documentation
    // ══════════════════════════════════════════════════════════════════
    final pass1Prompt = File('$outputPath/.${docType}_pass1.txt');
    pass1Prompt.writeAsStringSync('''
$prompt

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

    final pass1Result = Process.runSync(
      'sh',
      ['-c', 'cat ${pass1Prompt.path} | gemini --yolo -m $_kGeminiProModel ${includes.join(" ")}'],
      workingDirectory: repoRoot,
      environment: {...Platform.environment},
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

    final pass2Result = Process.runSync(
      'sh',
      ['-c', 'cat ${pass2Prompt.path} | gemini --yolo -m $_kGeminiProModel ${includes.join(" ")}'],
      workingDirectory: repoRoot,
      environment: {...Platform.environment},
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

  /// Compute SHA256 hash of all source files in the given paths.
  String _computeModuleHash(String repoRoot, List<String> sourcePaths) {
    final paths = sourcePaths.map((p) => '$repoRoot/$p').join(' ');
    final result = Process.runSync('sh', [
      '-c',
      'find $paths -type f \\( -name "*.proto" -o -name "*.dart" \\) 2>/dev/null | sort | xargs cat 2>/dev/null | sha256sum | cut -d" " -f1',
    ], workingDirectory: repoRoot);
    if (result.exitCode == 0) {
      return (result.stdout as String).trim();
    }
    // Fallback: timestamp-based
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}
