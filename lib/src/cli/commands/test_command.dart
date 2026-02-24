import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../../triage/utils/config.dart';
import '../utils/logger.dart';
import '../utils/repo_utils.dart';
import '../utils/sub_package_utils.dart';

/// Run `dart test` on the root package and all configured sub-packages.
class TestCommand extends Command<void> {
  @override
  final String name = 'test';

  @override
  final String description = 'Run dart test.';

  @override
  Future<void> run() async {
    final repoRoot = RepoUtils.findRepoRoot();
    if (repoRoot == null) {
      Logger.error('Could not find ${config.repoName} repo root.');
      exit(1);
    }

    Logger.header('Running dart test');

    const processTimeout = Duration(minutes: 45);
    final failures = <String>[];

    // Skip gracefully if no test/ directory exists
    final testDir = Directory('$repoRoot/test');
    if (!testDir.existsSync()) {
      Logger.success('No test/ directory found — skipping root tests');
    } else {
      // Use Process.start for streaming output instead of Process.runSync.
      // This ensures real-time output in CI (runSync buffers everything until
      // exit, so a hanging test produces zero output).
      final process = await Process.start(
        Platform.resolvedExecutable,
        ['test', '--exclude-tags', 'gcp,integration'],
        workingDirectory: repoRoot,
        mode: ProcessStartMode.inheritStdio,
      );

      // Process-level timeout: kill the test process if it exceeds 45 minutes.
      // Individual test timeouts should catch hangs, but this is a safety net
      // for cases where the test process itself doesn't exit (e.g., leaked
      // isolates, open sockets keeping the event loop alive).
      final exitCode = await process.exitCode.timeout(
        processTimeout,
        onTimeout: () {
          Logger.error('Test process exceeded ${processTimeout.inMinutes}-minute timeout — killing.');
          process.kill(ProcessSignal.sigkill);
          return -1;
        },
      );

      if (exitCode != 0) {
        Logger.error('Root tests failed with exit code $exitCode');
        failures.add(config.repoName);
      } else {
        Logger.success('Root tests passed');
      }
    }

    // ── Sub-package testing ───────────────────────────────────────────────
    final subPackages = SubPackageUtils.loadSubPackages(repoRoot);
    SubPackageUtils.logSubPackages(subPackages);

    for (final sp in subPackages) {
      final name = sp['name'] as String;
      final path = sp['path'] as String;
      final dir = '$repoRoot/$path';

      Logger.header('Testing sub-package: $name ($path)');

      if (!Directory(dir).existsSync()) {
        Logger.warn('  Directory not found: $dir — skipping');
        continue;
      }

      if (!File('$dir/pubspec.yaml').existsSync()) {
        Logger.error('  No pubspec.yaml in $dir — cannot test');
        failures.add(name);
        continue;
      }

      // Skip sub-packages with no test/ directory
      final spTestDir = Directory('$dir/test');
      if (!spTestDir.existsSync()) {
        Logger.info('  No test/ directory in $name — skipping');
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

      final spProcess = await Process.start(
        Platform.resolvedExecutable,
        ['test', '--exclude-tags', 'gcp,integration'],
        workingDirectory: dir,
        mode: ProcessStartMode.inheritStdio,
      );

      final spExitCode = await spProcess.exitCode.timeout(
        processTimeout,
        onTimeout: () {
          Logger.error('Test process for $name exceeded ${processTimeout.inMinutes}-minute timeout — killing.');
          spProcess.kill(ProcessSignal.sigkill);
          return -1;
        },
      );

      if (spExitCode != 0) {
        Logger.error('Tests failed for $name (exit code $spExitCode)');
        failures.add(name);
      } else {
        Logger.success('Tests passed for $name');
      }
    }

    if (failures.isNotEmpty) {
      Logger.error('Tests failed for ${failures.length} package(s): ${failures.join(', ')}');
      exit(1);
    }

    Logger.success('All tests passed');
  }
}
