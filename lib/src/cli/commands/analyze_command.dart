import 'dart:io';

import 'package:args/command_runner.dart';

import '../../triage/utils/config.dart';
import '../utils/language_support.dart';
import '../utils/logger.dart';
import '../utils/repo_utils.dart';
import '../utils/sub_package_utils.dart';
import '../utils/workflow_generator.dart';

/// Run static analysis on the root package and all configured sub-packages.
///
/// Supports multiple languages via [LanguageSupport]. The language is resolved
/// from `ci.language` in `.runtime_ci/config.json` (defaults to `"dart"` for
/// backward compatibility). Each sub-package may also override the language
/// via its own `language` field.
class AnalyzeCommand extends Command<void> {
  @override
  final String name = 'analyze';

  @override
  final String description = 'Run static analysis (fail on errors only).';

  @override
  Future<void> run() async {
    final repoRoot = RepoUtils.findRepoRoot();
    if (repoRoot == null) {
      Logger.error('Could not find ${config.repoName} repo root.');
      exit(1);
    }

    // Resolve language from CI config (defaults to Dart for backward compat).
    final fullConfig = WorkflowGenerator.loadFullConfig(repoRoot);
    final ciConfig = fullConfig?['ci'] as Map<String, dynamic>?;
    final languageId = ciConfig?['language'] as String? ?? 'dart';
    final language = resolveLanguage(languageId);

    // Check for multi-package configuration (packages is top-level, not ci).
    final packages = (fullConfig?['packages'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

    Logger.header('Running ${language.displayName} analysis');

    final failures = <String>[];

    if (packages.isNotEmpty) {
      // ── Multi-package mode ────────────────────────────────────────────
      for (final pkg in packages) {
        final pkgLanguageId = pkg['language'] as String? ?? language.id;
        final pkgLanguage = resolveLanguage(pkgLanguageId);
        final pkgName = pkg['name'] as String? ?? '<unnamed>';
        final pkgPath = pkg['path'] as String? ?? '.';
        final features = pkg['features'] as Map<String, dynamic>? ?? {};

        // Skip packages that have analysis explicitly disabled.
        if (features['analyze'] == false) {
          Logger.info('Skipping analysis for $pkgName (disabled in config)');
          continue;
        }

        final dir = '$repoRoot/$pkgPath';
        Logger.header('Analyzing package: $pkgName ($pkgPath)');

        if (!Directory(dir).existsSync()) {
          Logger.warn('  Directory not found: $dir — skipping');
          continue;
        }

        if (!File('$dir/${pkgLanguage.manifestFile}').existsSync()) {
          Logger.error('  No ${pkgLanguage.manifestFile} in $dir — cannot analyze');
          failures.add(pkgName);
          continue;
        }

        // Install dependencies for this package.
        final depCmd = pkgLanguage.dependencyInstallCommand();
        final depResult = Process.runSync(
          depCmd.first,
          depCmd.sublist(1),
          workingDirectory: dir,
          environment: {'GIT_LFS_SKIP_SMUDGE': '1'},
        );
        if (depResult.exitCode != 0) {
          final depStderr = (depResult.stderr as String).trim();
          if (depStderr.isNotEmpty) Logger.error(depStderr);
          Logger.error(
            '  ${depCmd.join(' ')} failed for $pkgName '
            '(exit code ${depResult.exitCode})',
          );
          failures.add(pkgName);
          continue;
        }

        // Run analysis.
        final analyzeArgs = pkgLanguage.analyzeCommand(fatalWarnings: false);
        final pkgResult = Process.runSync(analyzeArgs.first, analyzeArgs.sublist(1), workingDirectory: dir);

        final pkgStdout = (pkgResult.stdout as String).trim();
        if (pkgStdout.isNotEmpty) print(pkgStdout);

        final pkgStderr = (pkgResult.stderr as String).trim();
        if (pkgStderr.isNotEmpty) Logger.error(pkgStderr);

        if (pkgResult.exitCode != 0) {
          Logger.error('Analysis failed for $pkgName (exit code ${pkgResult.exitCode})');
          failures.add(pkgName);
        } else {
          Logger.success('Analysis passed for $pkgName');
        }
      }
    } else {
      // ── Single-package mode (backward compatible) ─────────────────────
      // --fatal-infos is non-negatable (infos are non-fatal by default).
      // --[no-]fatal-warnings supports negation; disable it so only errors
      // fail CI.
      final analyzeArgs = language.analyzeCommand(fatalWarnings: false);
      final result = Process.runSync(analyzeArgs.first, analyzeArgs.sublist(1), workingDirectory: repoRoot);

      final stdout = (result.stdout as String).trim();
      if (stdout.isNotEmpty) print(stdout);

      final stderr = (result.stderr as String).trim();
      if (stderr.isNotEmpty) Logger.error(stderr);

      if (result.exitCode != 0) {
        Logger.error('Root analysis failed with exit code ${result.exitCode}');
        failures.add(config.repoName);
      } else {
        Logger.success('Root analysis complete');
      }

      // ── Sub-package analysis ────────────────────────────────────────────
      final subPackages = SubPackageUtils.loadSubPackages(repoRoot);
      SubPackageUtils.logSubPackages(subPackages);

      for (final sp in subPackages) {
        final name = sp['name'] as String;
        final path = sp['path'] as String;
        final dir = '$repoRoot/$path';

        // Sub-packages may specify their own language; fall back to the
        // root language when unset.
        final spLanguageId = sp['language'] as String? ?? language.id;
        final spLanguage = resolveLanguage(spLanguageId);

        Logger.header('Analyzing sub-package: $name ($path)');

        if (!Directory(dir).existsSync()) {
          Logger.warn('  Directory not found: $dir — skipping');
          continue;
        }

        if (!File('$dir/${spLanguage.manifestFile}').existsSync()) {
          Logger.error('  No ${spLanguage.manifestFile} in $dir — cannot analyze');
          failures.add(name);
          continue;
        }

        // Ensure dependencies are resolved (sub-packages have independent
        // manifest files that the root install may not cover).
        final depCmd = spLanguage.dependencyInstallCommand();
        final pubGetResult = Process.runSync(
          depCmd.first,
          depCmd.sublist(1),
          workingDirectory: dir,
          environment: {'GIT_LFS_SKIP_SMUDGE': '1'},
        );
        if (pubGetResult.exitCode != 0) {
          final pubGetStderr = (pubGetResult.stderr as String).trim();
          if (pubGetStderr.isNotEmpty) Logger.error(pubGetStderr);
          Logger.error(
            '  ${depCmd.join(' ')} failed for $name '
            '(exit code ${pubGetResult.exitCode})',
          );
          failures.add(name);
          continue;
        }

        final spAnalyzeArgs = spLanguage.analyzeCommand(fatalWarnings: false);
        final spResult = Process.runSync(spAnalyzeArgs.first, spAnalyzeArgs.sublist(1), workingDirectory: dir);

        final spStdout = (spResult.stdout as String).trim();
        if (spStdout.isNotEmpty) print(spStdout);

        final spStderr = (spResult.stderr as String).trim();
        if (spStderr.isNotEmpty) Logger.error(spStderr);

        if (spResult.exitCode != 0) {
          Logger.error('Analysis failed for $name (exit code ${spResult.exitCode})');
          failures.add(name);
        } else {
          Logger.success('Analysis passed for $name');
        }
      }
    }

    if (failures.isNotEmpty) {
      Logger.error(
        'Analysis failed for ${failures.length} package(s): '
        '${failures.join(', ')}',
      );
      exit(1);
    }

    Logger.success('All analysis complete');
  }
}
