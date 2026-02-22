import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../../triage/utils/config.dart';
import '../../triage/utils/run_context.dart';
import '../manage_cicd_cli.dart';
import '../options/update_options.dart';
import '../utils/hook_installer.dart';
import '../utils/logger.dart';
import '../utils/repo_utils.dart';
import '../utils/template_manifest.dart';
import '../utils/template_resolver.dart';
import '../utils/workflow_generator.dart';

/// Update templates, configs, and workflows from runtime_ci_tooling.
///
/// Detects drift between the package's templates and the consumer's
/// installed copies, then updates intelligently based on file category:
///   - overwritable: Replace if template changed (warn on local edits)
///   - cautious: Warn only; require --force to replace
///   - templated: Render from Mustache skeleton + config.json ci section
///   - mergeable: Deep-merge new keys; preserve existing values
///   - regeneratable: Re-scan lib/src/ for new modules
class UpdateCommand extends Command<void> {
  @override
  final String name = 'update';

  @override
  final String description = 'Update templates, configs, and workflows from runtime_ci_tooling.';

  UpdateCommand() {
    UpdateOptionsArgParser.populateParser(argParser);
  }

  @override
  Future<void> run() async {
    final repoRoot = RepoUtils.findRepoRoot();
    if (repoRoot == null) {
      Logger.error('Could not find ${config.repoName} repo root.');
      exit(1);
    }
    final global = ManageCicdCli.parseGlobalOptions(globalResults);
    final opts = UpdateOptions.fromArgResults(argResults!);
    final dryRun = global.dryRun;
    final verbose = global.verbose;
    final force = opts.force;

    Logger.header('Update Runtime CI Tooling Templates');

    // --- Step 1: Resolve templates directory ---
    final templatesDir = TemplateResolver.resolveTemplatesDir();
    if (!Directory(templatesDir).existsSync()) {
      Logger.error('Templates directory not found at $templatesDir');
      Logger.error('Ensure runtime_ci_tooling is properly installed. Run: dart pub get');
      exit(1);
    }
    if (verbose) Logger.info('Templates directory: $templatesDir');

    // --- Step 2: Load manifest ---
    final manifest = TemplateResolver.readManifest();
    final entries = (manifest['templates'] as List).cast<Map<String, dynamic>>().map(TemplateEntry.fromJson).toList();
    final toolingVersion = TemplateResolver.resolveToolingVersion();

    Logger.info('runtime_ci_tooling version: $toolingVersion');
    Logger.info('Templates available: ${entries.length}');

    // --- Step 3: Load consumer's tracking file ---
    final tracker = TemplateVersionTracker.load(repoRoot);
    final lastVersion = tracker.lastToolingVersion;
    if (lastVersion != null) {
      Logger.info('Last updated from: v$lastVersion');
    } else {
      Logger.info('No previous update tracked (first update)');
    }
    Logger.info('');

    // --- Step 4: Process each template entry ---
    var updatedCount = 0;
    var skippedCount = 0;
    var warningCount = 0;
    final results = <_UpdateResult>[];

    for (final entry in entries) {
      if (!_shouldProcess(entry, opts)) {
        skippedCount++;
        continue;
      }

      final result = switch (entry.category) {
        'overwritable' => _processOverwritable(
          repoRoot,
          templatesDir,
          entry,
          tracker,
          toolingVersion,
          force: force,
          dryRun: dryRun,
          verbose: verbose,
          backup: opts.backup,
        ),
        'cautious' => _processCautious(
          repoRoot,
          templatesDir,
          entry,
          tracker,
          toolingVersion,
          force: force,
          dryRun: dryRun,
          verbose: verbose,
          backup: opts.backup,
        ),
        'templated' => _processTemplated(
          repoRoot,
          entry,
          tracker,
          toolingVersion,
          force: force,
          dryRun: dryRun,
          verbose: verbose,
          backup: opts.backup,
        ),
        'mergeable' => _processMergeable(
          repoRoot,
          templatesDir,
          entry,
          tracker,
          toolingVersion,
          force: force,
          dryRun: dryRun,
          verbose: verbose,
        ),
        'regeneratable' => _processRegeneratable(repoRoot, entry, dryRun: dryRun, verbose: verbose),
        _ => _UpdateResult(entry.id, 'skipped', reason: 'unknown category: ${entry.category}'),
      };

      results.add(result);
      switch (result.action) {
        case 'updated':
          updatedCount++;
        case 'skipped':
          skippedCount++;
        case 'warning':
          warningCount++;
      }
    }

    // --- Step 5: Save tracking file ---
    if (!dryRun && updatedCount > 0) {
      tracker.save(repoRoot);
      Logger.success('Saved template tracking to $kRuntimeCiDir/template_versions.json');
    }

    // --- Step 5.5: Install/refresh pre-commit hook ---
    // Respects consumer's configured line_length; falls back to 120.
    final ciConfig = WorkflowGenerator.loadCiConfig(repoRoot);
    final lineLength = (ciConfig?['line_length'] as num?)?.toInt() ?? 120;
    if (HookInstaller.install(repoRoot, lineLength: lineLength, dryRun: dryRun)) {
      updatedCount++;
    }

    // --- Step 6: Summary ---
    Logger.info('');
    Logger.header('Update Summary');
    for (final result in results) {
      final icon = switch (result.action) {
        'updated' => '+',
        'warning' => '!',
        _ => ' ',
      };
      final reason = result.reason != null ? ' (${result.reason})' : '';
      Logger.info('  $icon ${result.templateId}$reason');
    }
    Logger.info('');
    Logger.info('Updated: $updatedCount  Skipped: $skippedCount  Warnings: $warningCount');
    if (dryRun) Logger.info('[DRY-RUN] No files were modified.');
  }

  bool _shouldProcess(TemplateEntry entry, UpdateOptions opts) {
    if (opts.updateAll) return true;
    return switch (entry.category) {
      'overwritable' => opts.templates,
      'cautious' => opts.workflows,
      'templated' => opts.workflows,
      'mergeable' => opts.config,
      'regeneratable' => opts.autodoc,
      _ => false,
    };
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Category Handlers
  // ═══════════════════════════════════════════════════════════════════════════

  _UpdateResult _processOverwritable(
    String repoRoot,
    String templatesDir,
    TemplateEntry entry,
    TemplateVersionTracker tracker,
    String toolingVersion, {
    required bool force,
    required bool dryRun,
    required bool verbose,
    required bool backup,
  }) {
    final templatePath = '$templatesDir/${entry.source}';
    final destPath = '$repoRoot/${entry.destination}';
    final templateHash = computeFileHash(templatePath);
    final installedHash = tracker.getInstalledHash(entry.id);

    if (templateHash == installedHash && !force) {
      if (verbose) Logger.info('  ${entry.id}: up to date');
      return _UpdateResult(entry.id, 'skipped', reason: 'up to date');
    }

    final destFile = File(destPath);
    if (!destFile.existsSync()) {
      if (!dryRun) {
        Directory(destFile.parent.path).createSync(recursive: true);
        File(templatePath).copySync(destPath);
        tracker.recordUpdate(
          entry.id,
          templateHash: templateHash,
          consumerFileHash: computeFileHash(destPath),
          toolingVersion: toolingVersion,
        );
      }
      Logger.success('  ${entry.id}: created ${entry.destination}');
      return _UpdateResult(entry.id, 'updated', reason: 'new file');
    }

    // Check for local customizations
    final currentDestHash = computeFileHash(destPath);
    final previousConsumerHash = tracker.getConsumerHash(entry.id);
    final hasLocalChanges = previousConsumerHash != null && currentDestHash != previousConsumerHash;

    if (hasLocalChanges && !force) {
      Logger.warn('  ${entry.id}: local customizations detected, skipping (use --force to overwrite)');
      return _UpdateResult(entry.id, 'warning', reason: 'local customizations -- use --force');
    }

    if (!dryRun) {
      if (backup) {
        destFile.copySync('$destPath.bak');
        Logger.info('  ${entry.id}: backed up to ${entry.destination}.bak');
      }
      File(templatePath).copySync(destPath);
      tracker.recordUpdate(
        entry.id,
        templateHash: templateHash,
        consumerFileHash: computeFileHash(destPath),
        toolingVersion: toolingVersion,
      );
    }
    Logger.success('  ${entry.id}: updated ${entry.destination}');
    return _UpdateResult(entry.id, 'updated');
  }

  _UpdateResult _processCautious(
    String repoRoot,
    String templatesDir,
    TemplateEntry entry,
    TemplateVersionTracker tracker,
    String toolingVersion, {
    required bool force,
    required bool dryRun,
    required bool verbose,
    required bool backup,
  }) {
    final templatePath = '$templatesDir/${entry.source}';
    final destPath = '$repoRoot/${entry.destination}';
    final templateHash = computeFileHash(templatePath);
    final installedHash = tracker.getInstalledHash(entry.id);

    if (templateHash == installedHash && !force) {
      if (verbose) Logger.info('  ${entry.id}: up to date');
      return _UpdateResult(entry.id, 'skipped', reason: 'up to date');
    }

    final destFile = File(destPath);
    if (!destFile.existsSync()) {
      if (!dryRun) {
        Directory(destFile.parent.path).createSync(recursive: true);
        File(templatePath).copySync(destPath);
        tracker.recordUpdate(
          entry.id,
          templateHash: templateHash,
          consumerFileHash: computeFileHash(destPath),
          toolingVersion: toolingVersion,
        );
      }
      Logger.success('  ${entry.id}: created ${entry.destination}');
      return _UpdateResult(entry.id, 'updated', reason: 'new file');
    }

    if (!force) {
      Logger.warn(
        '  ${entry.id}: template has changed. '
        'Review manually or use --force to overwrite: ${entry.destination}',
      );
      Logger.info('    Compare with: $templatePath');
      return _UpdateResult(entry.id, 'warning', reason: 'template changed -- review or use --force');
    }

    // --force: overwrite
    if (!dryRun) {
      if (backup) {
        destFile.copySync('$destPath.bak');
        Logger.info('  ${entry.id}: backed up to ${entry.destination}.bak');
      }
      File(templatePath).copySync(destPath);
      tracker.recordUpdate(
        entry.id,
        templateHash: templateHash,
        consumerFileHash: computeFileHash(destPath),
        toolingVersion: toolingVersion,
      );
    }
    Logger.success('  ${entry.id}: force-updated ${entry.destination}');
    return _UpdateResult(entry.id, 'updated', reason: 'forced');
  }

  _UpdateResult _processMergeable(
    String repoRoot,
    String templatesDir,
    TemplateEntry entry,
    TemplateVersionTracker tracker,
    String toolingVersion, {
    required bool force,
    required bool dryRun,
    required bool verbose,
  }) {
    final destPath = '$repoRoot/${entry.destination}';
    final destFile = File(destPath);

    if (!destFile.existsSync()) {
      Logger.warn('  ${entry.id}: ${entry.destination} does not exist. Run "init" first.');
      return _UpdateResult(entry.id, 'warning', reason: 'file missing -- run init');
    }

    final refPath = '$templatesDir/config.json';
    final refFile = File(refPath);
    if (!refFile.existsSync()) {
      Logger.warn('  ${entry.id}: reference config.json not found in templates/');
      return _UpdateResult(entry.id, 'skipped', reason: 'no reference template');
    }

    final refConfig = json.decode(refFile.readAsStringSync()) as Map<String, dynamic>;
    final consumerConfig = json.decode(destFile.readAsStringSync()) as Map<String, dynamic>;

    final addedKeys = <String>[];
    _deepMergeNewKeys(refConfig, consumerConfig, addedKeys, prefix: '');

    if (addedKeys.isEmpty) {
      if (verbose) Logger.info('  ${entry.id}: all config keys present');
      return _UpdateResult(entry.id, 'skipped', reason: 'all keys present');
    }

    Logger.info('  ${entry.id}: found ${addedKeys.length} new key(s):');
    for (final key in addedKeys) {
      Logger.info('    + $key');
    }

    if (!dryRun) {
      destFile.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(consumerConfig)}\n');
      tracker.recordUpdate(
        entry.id,
        templateHash: computeFileHash(refPath),
        consumerFileHash: computeFileHash(destPath),
        toolingVersion: toolingVersion,
      );
    }

    Logger.success('  ${entry.id}: merged ${addedKeys.length} new key(s) into ${entry.destination}');
    return _UpdateResult(entry.id, 'updated', reason: '${addedKeys.length} key(s) added');
  }

  _UpdateResult _processRegeneratable(
    String repoRoot,
    TemplateEntry entry, {
    required bool dryRun,
    required bool verbose,
  }) {
    final destPath = '$repoRoot/${entry.destination}';
    final destFile = File(destPath);

    if (!destFile.existsSync()) {
      Logger.warn('  ${entry.id}: ${entry.destination} does not exist. Run "init" first.');
      return _UpdateResult(entry.id, 'warning', reason: 'file missing -- run init');
    }

    final autodocConfig = json.decode(destFile.readAsStringSync()) as Map<String, dynamic>;
    final existingModules = (autodocConfig['modules'] as List).cast<Map<String, dynamic>>();
    final existingIds = existingModules.map((m) => m['id'] as String).toSet();

    final srcDir = Directory('$repoRoot/lib/src');
    var newModuleCount = 0;

    if (srcDir.existsSync()) {
      final subdirs =
          srcDir.listSync().whereType<Directory>().where((d) => !d.path.split('/').last.startsWith('.')).toList()
            ..sort((a, b) => a.path.compareTo(b.path));

      for (final dir in subdirs) {
        final dirName = dir.path.split('/').last;
        if (!existingIds.contains(dirName)) {
          final displayName = dirName.split('_').map((w) => '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
          existingModules.add({
            'id': dirName,
            'name': displayName,
            'source_paths': ['lib/src/$dirName/'],
            'lib_paths': ['lib/src/$dirName/'],
            'output_path': 'docs/$dirName/',
            'generate': ['quickstart', 'api_reference'],
            'hash': '',
            'last_updated': null,
          });
          newModuleCount++;
          Logger.info('    + New module: $dirName');
        }
      }
    }

    if (newModuleCount == 0) {
      if (verbose) Logger.info('  ${entry.id}: no new modules found');
      return _UpdateResult(entry.id, 'skipped', reason: 'no new modules');
    }

    if (!dryRun) {
      destFile.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(autodocConfig)}\n');
    }

    Logger.success('  ${entry.id}: added $newModuleCount new module(s)');
    return _UpdateResult(entry.id, 'updated', reason: '$newModuleCount module(s) added');
  }

  _UpdateResult _processTemplated(
    String repoRoot,
    TemplateEntry entry,
    TemplateVersionTracker tracker,
    String toolingVersion, {
    required bool force,
    required bool dryRun,
    required bool verbose,
    required bool backup,
  }) {
    // Templated entries require a source skeleton
    if (entry.source == null) {
      Logger.error('  ${entry.id}: templated entry requires a "source" field in manifest.json');
      return _UpdateResult(entry.id, 'error', reason: 'missing source in manifest');
    }

    // Load CI config from the consumer repo
    final ciConfig = WorkflowGenerator.loadCiConfig(repoRoot);
    if (ciConfig == null) {
      Logger.warn('  ${entry.id}: no "ci" section in config.json. '
          'Add a "ci" section to enable config-driven workflow generation.');
      return _UpdateResult(entry.id, 'warning', reason: 'no ci config -- add "ci" section to config.json');
    }

    // Validate config
    final errors = WorkflowGenerator.validate(ciConfig);
    if (errors.isNotEmpty) {
      for (final error in errors) {
        Logger.error('  ${entry.id}: $error');
      }
      return _UpdateResult(entry.id, 'warning', reason: 'invalid ci config');
    }

    final destPath = '$repoRoot/${entry.destination}';
    final destFile = File(destPath);

    // Read existing content for user-section preservation
    final existingContent = destFile.existsSync() ? destFile.readAsStringSync() : null;

    // Generate the workflow
    final generator = WorkflowGenerator(
      ciConfig: ciConfig,
      toolingVersion: toolingVersion,
    );

    if (verbose) {
      Logger.info('  ${entry.id}: rendering from config:');
      generator.logConfig();
    }

    final rendered = generator.render(existingContent: existingContent);

    // Check if content actually changed
    if (existingContent != null && rendered == existingContent && !force) {
      if (verbose) Logger.info('  ${entry.id}: output unchanged');
      return _UpdateResult(entry.id, 'skipped', reason: 'output unchanged');
    }

    if (!dryRun) {
      if (backup && destFile.existsSync()) {
        destFile.copySync('$destPath.bak');
        Logger.info('  ${entry.id}: backed up to ${entry.destination}.bak');
      }
      Directory(destFile.parent.path).createSync(recursive: true);
      destFile.writeAsStringSync(rendered);
      // Track with hash of the skeleton template source
      final skeletonPath = TemplateResolver.resolveTemplatePath(entry.source!);
      tracker.recordUpdate(
        entry.id,
        templateHash: computeFileHash(skeletonPath),
        consumerFileHash: computeFileHash(destPath),
        toolingVersion: toolingVersion,
      );
    }

    final action = existingContent == null ? 'generated' : 'regenerated';
    Logger.success('  ${entry.id}: $action ${entry.destination}');
    return _UpdateResult(entry.id, 'updated', reason: '$action from config');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Utilities
  // ═══════════════════════════════════════════════════════════════════════════

  /// Recursively merge keys from [source] into [target] that don't exist in
  /// target. Records added key paths to [addedKeys].
  void _deepMergeNewKeys(
    Map<String, dynamic> source,
    Map<String, dynamic> target,
    List<String> addedKeys, {
    required String prefix,
  }) {
    for (final key in source.keys) {
      if (key == '_comment') continue;
      final fullKey = prefix.isEmpty ? key : '$prefix.$key';

      if (!target.containsKey(key)) {
        target[key] = source[key];
        addedKeys.add(fullKey);
      } else if (source[key] is Map<String, dynamic> && target[key] is Map<String, dynamic>) {
        _deepMergeNewKeys(
          source[key] as Map<String, dynamic>,
          target[key] as Map<String, dynamic>,
          addedKeys,
          prefix: fullKey,
        );
      }
    }
  }
}

class _UpdateResult {
  final String templateId;
  final String action;
  final String? reason;

  _UpdateResult(this.templateId, this.action, {this.reason});
}
