import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../../triage/utils/config.dart';
import '../utils/logger.dart';
import '../utils/repo_utils.dart';
import '../utils/step_summary.dart';
import '../utils/sub_package_utils.dart';

/// Run `dart test` on the root package and all configured sub-packages with
/// full output capture (two-layer strategy).
///
/// **Layer 1 — Zone-aware reporters:** `--file-reporter json:` captures all
/// `print()` calls as `PrintEvent` objects with test attribution, and
/// `--file-reporter expanded:` captures human-readable output.
///
/// **Layer 2 — Shell-level `tee`:** Configured in the CI template to capture
/// anything that bypasses Dart zones (`stdout.write()`, isolate prints, FFI).
///
/// All log files are written to `$TEST_LOG_DIR` (set by CI template) or
/// `<repoRoot>/.dart_tool/test-logs/` locally.
class TestCommand extends Command<void> {
  @override
  final String name = 'test';

  @override
  final String description = 'Run dart test with full output capture and job summary.';

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

    // Determine log directory: TEST_LOG_DIR (CI) or .dart_tool/test-logs/ (local)
    final logDir = Platform.environment['TEST_LOG_DIR'] ?? '$repoRoot/.dart_tool/test-logs';
    Directory(logDir).createSync(recursive: true);
    Logger.info('Log directory: $logDir');

    final jsonPath = '$logDir/results.json';
    final expandedPath = '$logDir/expanded.txt';

    // Skip gracefully if no test/ directory exists
    final testDir = Directory('$repoRoot/test');
    if (!testDir.existsSync()) {
      Logger.success('No test/ directory found — skipping root tests');
      StepSummary.write('## Test Results\n\n**No test/ directory found — skipped.**\n');
    } else {
      // Build test arguments with two file reporters + expanded console output
      final testArgs = <String>[
        'test',
        '--exclude-tags',
        'gcp,integration',
        '--chain-stack-traces',
        '--reporter',
        'expanded',
        '--file-reporter',
        'json:$jsonPath',
        '--file-reporter',
        'expanded:$expandedPath',
      ];

      Logger.info('Running: dart ${testArgs.join(' ')}');

      // Use Process.start with piped output so we can both stream to console
      // AND capture the full output for summary generation.
      final process = await Process.start(Platform.resolvedExecutable, testArgs, workingDirectory: repoRoot);

      // Stream stdout and stderr to console in real-time while capturing
      final stdoutBuf = StringBuffer();
      final stderrBuf = StringBuffer();

      final stdoutDone = process.stdout.transform(utf8.decoder).listen((data) {
        stdout.write(data);
        stdoutBuf.write(data);
      }).asFuture<void>();

      final stderrDone = process.stderr.transform(utf8.decoder).listen((data) {
        stderr.write(data);
        stderrBuf.write(data);
      }).asFuture<void>();

      // Process-level timeout: kill the test process if it exceeds 45 minutes.
      final exitCode = await process.exitCode.timeout(
        processTimeout,
        onTimeout: () {
          Logger.error('Test process exceeded ${processTimeout.inMinutes}-minute timeout — killing.');
          process.kill(); // No signal arg — cross-platform safe
          return -1;
        },
      );

      try {
        await Future.wait([stdoutDone, stderrDone]).timeout(const Duration(seconds: 30));
      } catch (_) {
        // Ignore stream errors (e.g. process killed before streams drained)
      }

      // Write console output to log files
      File('$logDir/dart_stdout.log').writeAsStringSync(stdoutBuf.toString());
      if (stderrBuf.isNotEmpty) {
        File('$logDir/dart_stderr.log').writeAsStringSync(stderrBuf.toString());
      }

      // Parse the JSON results file for structured test data
      final results = StepSummary.parseTestResultsJson(jsonPath);

      // Generate and write the rich job summary
      StepSummary.writeTestJobSummary(results, exitCode);

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
          spProcess.kill(); // No signal arg — cross-platform safe
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
      final failureBullets = failures.map((name) => '- `$name`').join('\n');
      StepSummary.write('\n## Sub-package Test Failures\n\n$failureBullets\n');
      exit(1);
    }

    Logger.success('All tests passed');
  }
}
