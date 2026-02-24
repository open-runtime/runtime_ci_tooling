import 'dart:io';

import 'package:args/command_runner.dart';

import '../../triage/utils/config.dart';
import '../utils/logger.dart';
import '../utils/repo_utils.dart';
import '../utils/sub_package_utils.dart';

/// Run `dart analyze` on the root package and all configured sub-packages.
class AnalyzeCommand extends Command<void> {
  @override
  final String name = 'analyze';

  @override
  final String description = 'Run dart analyze (fail on errors only).';

  @override
  Future<void> run() async {
    final repoRoot = RepoUtils.findRepoRoot();
    if (repoRoot == null) {
      Logger.error('Could not find ${config.repoName} repo root.');
      exit(1);
    }

    Logger.header('Running dart analyze');

    final failures = <String>[];

    // --fatal-infos is non-negatable (infos are non-fatal by default).
    // --[no-]fatal-warnings supports negation; disable it so only errors fail CI.
    final result = Process.runSync(Platform.resolvedExecutable, [
      'analyze',
      '--no-fatal-warnings',
    ], workingDirectory: repoRoot);

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

    // ── Sub-package analysis ──────────────────────────────────────────────
    final subPackages = SubPackageUtils.loadSubPackages(repoRoot);
    SubPackageUtils.logSubPackages(subPackages);

    for (final sp in subPackages) {
      final name = sp['name'] as String;
      final path = sp['path'] as String;
      final dir = '$repoRoot/$path';

      Logger.header('Analyzing sub-package: $name ($path)');

      if (!Directory(dir).existsSync()) {
        Logger.warn('  Directory not found: $dir — skipping');
        continue;
      }

      if (!File('$dir/pubspec.yaml').existsSync()) {
        Logger.error('  No pubspec.yaml in $dir — cannot analyze');
        failures.add(name);
        continue;
      }

      // Ensure dependencies are resolved (sub-packages have independent
      // pubspec.yaml files that the root `dart pub get` may not cover).
      final pubGetResult = Process.runSync(
        Platform.resolvedExecutable,
        ['pub', 'get'],
        workingDirectory: dir,
        environment: {'GIT_LFS_SKIP_SMUDGE': '1'},
      );
      if (pubGetResult.exitCode != 0) {
        final pubGetStderr = (pubGetResult.stderr as String).trim();
        if (pubGetStderr.isNotEmpty) Logger.error(pubGetStderr);
        Logger.error('  dart pub get failed for $name (exit code ${pubGetResult.exitCode})');
        failures.add(name);
        continue;
      }

      final spResult = Process.runSync(Platform.resolvedExecutable, [
        'analyze',
        '--no-fatal-warnings',
      ], workingDirectory: dir);

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

    if (failures.isNotEmpty) {
      Logger.error('Analysis failed for ${failures.length} package(s): ${failures.join(', ')}');
      exit(1);
    }

    Logger.success('All analysis complete');
  }
}
