import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../../triage/utils/config.dart';
import '../utils/exit_util.dart';
import '../utils/logger.dart';
import '../utils/repo_utils.dart';
import '../utils/step_summary.dart';
import '../utils/test_results_util.dart';
import '../utils/sub_package_utils.dart';
import '../utils/utf8_bounded_buffer.dart';

typedef _ExitHandler = Future<Never> Function(int code);

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
  /// Maximum bytes to buffer per stdout/stderr stream to prevent OOM.
  static const int _maxLogBufferBytes = 2 * 1024 * 1024; // 2MB
  /// Maximum bytes for pub get output (typically small).
  static const int _maxPubGetBufferBytes = 512 * 1024; // 512KB
  @override
  final String name = 'test';

  @override
  final String description = 'Run dart test with full output capture and job summary.';

  @override
  Future<void> run() async {
    final repoRoot = RepoUtils.findRepoRoot();
    if (repoRoot == null) {
      Logger.error('Could not find ${config.repoName} repo root.');
      await exitWithCode(1);
    }
    await runWithRoot(repoRoot);
  }

  /// Run tests with an explicit [repoRoot], preserving the contract from
  /// manage_cicd when invoked as `manage_cicd test` (CWD may differ from root).
  static Future<void> runWithRoot(
    String repoRoot, {
    Duration processTimeout = const Duration(minutes: 45),
    Duration pubGetTimeout = const Duration(minutes: 5),
    _ExitHandler exitHandler = exitWithCode,
  }) async {
    Logger.header('Running dart test');

    final failures = <String>[];

    // Determine log directory: TEST_LOG_DIR (CI) or .dart_tool/test-logs/ (local)
    final logDir = await _resolveLogDirOrExit(repoRoot, exitHandler);
    Logger.info('Log directory: $logDir');

    final jsonPath = p.join(logDir, 'results.json');
    final expandedPath = p.join(logDir, 'expanded.txt');

    // Skip gracefully if no test/ directory exists
    final testDir = Directory(p.join(repoRoot, 'test'));
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
      // (byte-bounded to prevent OOM from runaway test output).
      const truncationSuffix = '\n\n... (output truncated, exceeded 2MB bytes). See console.log for full output.)';
      final stdoutBuf = Utf8BoundedBuffer(maxBytes: _maxLogBufferBytes, truncationSuffix: truncationSuffix);
      final stderrBuf = Utf8BoundedBuffer(maxBytes: _maxLogBufferBytes, truncationSuffix: truncationSuffix);

      void onStdout(String data) {
        stdout.write(data);
        stdoutBuf.append(data);
      }

      void onStderr(String data) {
        stderr.write(data);
        stderrBuf.append(data);
      }

      final stdoutSub = process.stdout.transform(Utf8Decoder(allowMalformed: true)).listen(onStdout);
      final stderrSub = process.stderr.transform(Utf8Decoder(allowMalformed: true)).listen(onStderr);

      final stdoutDone = stdoutSub.asFuture<void>();
      final stderrDone = stderrSub.asFuture<void>();

      // Process-level timeout: kill the test process if it exceeds 45 minutes.
      // On Unix: SIGTERM first, await up to 5s; if still alive, SIGKILL and await.
      // On Windows: single kill, then await exit.
      int exitCode;
      try {
        exitCode = await process.exitCode.timeout(processTimeout);
      } on TimeoutException {
        Logger.error('Test process exceeded ${processTimeout.inMinutes}-minute timeout — killing.');
        exitCode = await _killAndAwaitExit(process);
      }

      try {
        await Future.wait([stdoutDone, stderrDone]).timeout(const Duration(seconds: 30));
      } catch (_) {
        // Process killed or streams timed out
      } finally {
        await stdoutSub.cancel();
        await stderrSub.cancel();
      }

      // Write console output to log files
      try {
        RepoUtils.writeFileSafely(p.join(logDir, 'dart_stdout.log'), stdoutBuf.toString());
        if (!stderrBuf.isEmpty) {
          RepoUtils.writeFileSafely(p.join(logDir, 'dart_stderr.log'), stderrBuf.toString());
        }
      } on FileSystemException catch (e) {
        Logger.warn('Could not write log files: $e');
      }

      // Parse the JSON results file for structured test data
      final results = await TestResultsUtil.parseTestResultsJson(jsonPath);

      // Generate and write the rich job summary
      TestResultsUtil.writeTestJobSummary(results, exitCode);

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
      final dir = p.join(repoRoot, path);

      Logger.header('Testing sub-package: $name ($path)');

      if (!Directory(dir).existsSync()) {
        Logger.warn('  Directory not found: $dir — skipping');
        continue;
      }

      if (!File(p.join(dir, 'pubspec.yaml')).existsSync()) {
        Logger.error('  No pubspec.yaml in $dir — cannot test');
        failures.add(name);
        continue;
      }

      // Skip sub-packages with no test/ directory
      final spTestDir = Directory(p.join(dir, 'test'));
      if (!spTestDir.existsSync()) {
        Logger.info('  No test/ directory in $name — skipping');
        continue;
      }

      // Ensure dependencies are resolved (sub-packages have independent
      // pubspec.yaml files that the root `dart pub get` may not cover).
      // Use Process.start so we can kill on timeout (Process.run would hang).
      final pubGetResult = await _runPubGetWithTimeout(
        dir,
        pubGetTimeout,
        onTimeout: () {
          Logger.error('  dart pub get timed out for $name (${pubGetTimeout.inMinutes}-minute limit)');
        },
      );
      if (pubGetResult == null) {
        failures.add(name);
        continue;
      }
      if (pubGetResult.exitCode != 0) {
        final pubGetStderr = (pubGetResult.stderr as String).trim();
        if (pubGetStderr.isNotEmpty) Logger.error(pubGetStderr);
        Logger.error('  dart pub get failed for $name (exit code ${pubGetResult.exitCode})');
        failures.add(name);
        continue;
      }

      final spLogDir = p.join(logDir, name);
      try {
        RepoUtils.ensureSafeDirectory(spLogDir);
      } on FileSystemException catch (e) {
        Logger.error('Cannot use sub-package log directory for $name: $e');
        failures.add(name);
        continue;
      }
      final spJsonPath = p.join(spLogDir, 'results.json');
      final spExpandedPath = p.join(spLogDir, 'expanded.txt');

      final spTestArgs = <String>[
        'test',
        '--exclude-tags',
        'gcp,integration',
        '--chain-stack-traces',
        '--reporter',
        'expanded',
        '--file-reporter',
        'json:$spJsonPath',
        '--file-reporter',
        'expanded:$spExpandedPath',
      ];

      final spProcess = await Process.start(Platform.resolvedExecutable, spTestArgs, workingDirectory: dir);

      const spTruncationSuffix = '\n\n... (output truncated, exceeded 2MB bytes). See console.log for full output.)';
      final stdoutBuf = Utf8BoundedBuffer(maxBytes: _maxLogBufferBytes, truncationSuffix: spTruncationSuffix);
      final stderrBuf = Utf8BoundedBuffer(maxBytes: _maxLogBufferBytes, truncationSuffix: spTruncationSuffix);

      void onSpStdout(String data) {
        stdout.write(data);
        stdoutBuf.append(data);
      }

      void onSpStderr(String data) {
        stderr.write(data);
        stderrBuf.append(data);
      }

      final stdoutSub = spProcess.stdout.transform(Utf8Decoder(allowMalformed: true)).listen(onSpStdout);
      final stderrSub = spProcess.stderr.transform(Utf8Decoder(allowMalformed: true)).listen(onSpStderr);

      int spExitCode;
      try {
        spExitCode = await spProcess.exitCode.timeout(processTimeout);
      } on TimeoutException {
        Logger.error('Test process for $name exceeded ${processTimeout.inMinutes}-minute timeout — killing.');
        spExitCode = await _killAndAwaitExit(spProcess);
      }

      try {
        await Future.wait([
          stdoutSub.asFuture<void>(),
          stderrSub.asFuture<void>(),
        ]).timeout(const Duration(seconds: 30));
      } catch (_) {
        // Process killed or streams timed out
      } finally {
        await stdoutSub.cancel();
        await stderrSub.cancel();
      }

      try {
        RepoUtils.writeFileSafely(p.join(spLogDir, 'dart_stdout.log'), stdoutBuf.toString());
        if (!stderrBuf.isEmpty) {
          RepoUtils.writeFileSafely(p.join(spLogDir, 'dart_stderr.log'), stderrBuf.toString());
        }
      } on FileSystemException catch (e) {
        Logger.warn('Could not write sub-package log files: $e');
      }

      final spResults = await TestResultsUtil.parseTestResultsJson(spJsonPath);
      TestResultsUtil.writeTestJobSummary(spResults, spExitCode, platformId: name);

      if (spExitCode != 0) {
        Logger.error('Tests failed for $name (exit code $spExitCode)');
        failures.add(name);
      } else {
        Logger.success('Tests passed for $name');
      }
    }

    if (failures.isNotEmpty) {
      Logger.error('Tests failed for ${failures.length} package(s): ${failures.join(', ')}');
      final failureBullets = failures.map((name) => '- `${StepSummary.escapeHtml(name)}`').join('\n');
      StepSummary.write('\n## Sub-package Test Failures\n\n$failureBullets\n');
      await exitHandler(1);
    }

    Logger.success('All tests passed');
    await stdout.flush();
    await stderr.flush();
  }

  /// Runs `dart pub get` in [workingDirectory] with [timeout]. Kills the process
  /// on timeout to avoid indefinite hangs. Returns null on timeout.
  static Future<ProcessResult?> _runPubGetWithTimeout(
    String workingDirectory,
    Duration timeout, {
    void Function()? onTimeout,
  }) async {
    final process = await Process.start(
      Platform.resolvedExecutable,
      ['pub', 'get'],
      workingDirectory: workingDirectory,
      environment: {'GIT_LFS_SKIP_SMUDGE': '1'},
    );
    const pubGetTruncationSuffix = '\n\n... (output truncated).';
    final stdoutBuf = Utf8BoundedBuffer(maxBytes: _maxPubGetBufferBytes, truncationSuffix: pubGetTruncationSuffix);
    final stderrBuf = Utf8BoundedBuffer(maxBytes: _maxPubGetBufferBytes, truncationSuffix: pubGetTruncationSuffix);

    final stdoutDone = Completer<void>();
    final stderrDone = Completer<void>();
    final stdoutSub = process.stdout
        .transform(Utf8Decoder(allowMalformed: true))
        .listen(
          (data) => stdoutBuf.append(data),
          onDone: () => stdoutDone.complete(),
          onError: (_) => stdoutDone.complete(),
        );
    final stderrSub = process.stderr
        .transform(Utf8Decoder(allowMalformed: true))
        .listen(
          (data) => stderrBuf.append(data),
          onDone: () => stderrDone.complete(),
          onError: (_) => stderrDone.complete(),
        );
    try {
      final exitCode = await process.exitCode.timeout(timeout);
      await Future.wait([
        stdoutDone.future.timeout(const Duration(seconds: 5), onTimeout: () {}),
        stderrDone.future.timeout(const Duration(seconds: 5), onTimeout: () {}),
      ]);
      await Future.wait([stdoutSub.cancel(), stderrSub.cancel()]);
      return ProcessResult(process.pid, exitCode, stdoutBuf.toString(), stderrBuf.toString());
    } on TimeoutException {
      onTimeout?.call();
      await _killAndAwaitExit(process);
      try {
        await Future.wait([
          stdoutDone.future.timeout(const Duration(seconds: 5), onTimeout: () {}),
          stderrDone.future.timeout(const Duration(seconds: 5), onTimeout: () {}),
        ]);
        await Future.wait([stdoutSub.cancel(), stderrSub.cancel()]);
      } catch (_) {}
      return null;
    }
  }

  /// Kills [process] and awaits exit. On Unix: SIGTERM first, wait up to 5s;
  /// if still alive, SIGKILL and await. On Windows: single kill, then await.
  /// Returns -1 to indicate timeout-induced kill.
  static Future<int> _killAndAwaitExit(Process process) async {
    if (Platform.isWindows) {
      process.kill();
      await process.exitCode;
      return -1;
    }
    process.kill(ProcessSignal.sigterm);
    try {
      await process.exitCode.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
      await process.exitCode;
    }
    return -1;
  }

  static Future<String> _resolveLogDirOrExit(String repoRoot, _ExitHandler exitHandler) async {
    try {
      final logDir = RepoUtils.resolveTestLogDir(repoRoot);
      RepoUtils.ensureSafeDirectory(logDir);
      return logDir;
    } on StateError catch (e) {
      Logger.error('$e');
      await exitHandler(1);
    } on FileSystemException catch (e) {
      Logger.error('Cannot use log directory: $e');
      await exitHandler(1);
    }
  }
}
