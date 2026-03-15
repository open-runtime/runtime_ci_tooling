import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../../triage/utils/config.dart';
import '../utils/exit_util.dart';
import '../utils/language_support.dart';
import '../utils/logger.dart';
import '../utils/repo_utils.dart';
import '../utils/step_summary.dart';
import '../utils/test_results_util.dart';
import '../utils/sub_package_utils.dart';
import '../utils/utf8_bounded_buffer.dart';
import '../utils/workflow_generator.dart';

typedef _ExitHandler = Future<Never> Function(int code);

/// Run `dart test` on the root package and all configured sub-packages with
/// full output capture (two-layer strategy).
///
/// **Layer 1 — Zone-aware reporter:** `--file-reporter json:` captures all
/// `print()` calls as `PrintEvent` objects with test attribution.
///
/// Note: `dart test` currently applies only the last `--file-reporter` flag,
/// so this command intentionally configures a single file reporter (JSON).
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
    Map<String, String>? environment,
  }) async {
    // ── Resolve language from CI config ────────────────────────────────
    final fullConfig = WorkflowGenerator.loadFullConfig(repoRoot);
    final ciConfig = fullConfig?['ci'] as Map<String, dynamic>?;
    final languageId = ciConfig?['language'] as String? ?? 'dart';
    final language = resolveLanguage(languageId);

    Logger.header('Running ${language.displayName} tests');

    final failures = <String>[];

    // Determine log directory: TEST_LOG_DIR (CI) or .dart_tool/test-logs/ (local)
    final logDir = await _resolveLogDirOrExit(repoRoot, exitHandler, environment: environment);
    Logger.info('Log directory: $logDir');

    // ── Multi-package support (config.packages — top-level, not ci) ──
    final packages = (fullConfig?['packages'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    if (packages.isNotEmpty) {
      for (final pkg in packages) {
        final pkgLanguage = resolveLanguage(pkg['language'] as String? ?? language.id);
        final pkgPath = pkg['path'] as String;
        final pkgName = pkg['name'] as String? ?? p.basename(pkgPath);
        final features = pkg['features'] as Map<String, dynamic>? ?? {};
        if (features['test'] == false) continue;

        final pkgDir = p.join(repoRoot, pkgPath);
        Logger.info('Testing package: $pkgName ($pkgPath)');

        if (!Directory(pkgDir).existsSync()) {
          Logger.warn('  Directory not found: $pkgDir — skipping');
          continue;
        }

        if (!File(p.join(pkgDir, pkgLanguage.manifestFile)).existsSync()) {
          Logger.error('  No ${pkgLanguage.manifestFile} in $pkgDir — cannot test');
          failures.add(pkgName);
          continue;
        }

        final pkgTestDir = Directory(p.join(pkgDir, 'test'));
        if (!pkgTestDir.existsSync()) {
          Logger.info('  No test/ directory in $pkgName — skipping');
          continue;
        }

        // Install dependencies
        final depCmd = pkgLanguage.dependencyInstallCommand();
        final depResult = await _runCommandWithTimeout(
          depCmd.first,
          depCmd.skip(1).toList(),
          pkgDir,
          pubGetTimeout,
          onTimeout: () {
            Logger.error('  ${depCmd.join(' ')} timed out for $pkgName (${pubGetTimeout.inMinutes}-minute limit)');
          },
        );
        if (depResult == null) {
          failures.add(pkgName);
          continue;
        }
        if (depResult.exitCode != 0) {
          final depStderr = (depResult.stderr as String).trim();
          if (depStderr.isNotEmpty) Logger.error(depStderr);
          Logger.error('  ${depCmd.join(' ')} failed for $pkgName (exit code ${depResult.exitCode})');
          failures.add(pkgName);
          continue;
        }

        final pkgLogDir = p.join(logDir, pkgName);
        try {
          RepoUtils.ensureSafeDirectory(pkgLogDir);
        } on FileSystemException catch (e) {
          Logger.error('Cannot use package log directory for $pkgName: $e');
          failures.add(pkgName);
          continue;
        }

        // Run tests — use Dart-specific file-reporter for Dart/Flutter,
        // generic test command otherwise.
        final bool isDartLike = pkgLanguage is DartLanguageSupport;
        final pkgJsonPath = p.join(pkgLogDir, 'results.json');
        final String executable;
        final List<String> testArgs;
        if (isDartLike) {
          executable = Platform.resolvedExecutable;
          testArgs = _buildDartTestArgs(pkgJsonPath);
        } else {
          final fullCmd = pkgLanguage.testCommand(ci: true);
          executable = fullCmd.first;
          testArgs = fullCmd.skip(1).toList();
        }

        final pkgProcess = await Process.start(executable, testArgs, workingDirectory: pkgDir);
        final pkgExitCode = await _runTestProcess(pkgProcess, pkgName, pkgLogDir, processTimeout);

        if (isDartLike) {
          final pkgResults = await TestResultsUtil.parseTestResultsJson(pkgJsonPath);
          TestResultsUtil.writeTestJobSummary(pkgResults, pkgExitCode, platformId: pkgName);
        }

        if (pkgExitCode != 0) {
          Logger.error('Tests failed for $pkgName (exit code $pkgExitCode)');
          failures.add(pkgName);
        } else {
          Logger.success('Tests passed for $pkgName');
        }
      }

      // After multi-package loop, check failures and exit
      if (failures.isNotEmpty) {
        Logger.error('Tests failed for ${failures.length} package(s): ${failures.join(', ')}');
        final failureBullets = failures.map((name) => '- `${StepSummary.escapeHtml(name)}`').join('\n');
        StepSummary.write('\n## Multi-Package Test Failures\n\n$failureBullets\n');
        await exitHandler(1);
      }

      Logger.success('All package tests passed');
      await stdout.flush();
      await stderr.flush();
      return;
    }

    // ── Single-package (legacy) behavior ─────────────────────────────

    final jsonPath = p.join(logDir, 'results.json');
    // Skip gracefully if no test/ directory exists
    final testDir = Directory(p.join(repoRoot, 'test'));
    if (!testDir.existsSync()) {
      Logger.success('No test/ directory found — skipping root tests');
      StepSummary.write('## Test Results\n\n**No test/ directory found — skipped.**\n');
    } else {
      // Determine test execution strategy based on language
      final bool isDartLike = language is DartLanguageSupport;
      final String executable;
      final List<String> testArgs;
      if (isDartLike) {
        // Build Dart-specific test arguments with a single JSON file reporter.
        // Human-readable output is still captured by `--reporter expanded`
        // and shell-level `tee` in CI.
        executable = Platform.resolvedExecutable;
        testArgs = _buildDartTestArgs(jsonPath);
      } else {
        // Use language-generic test command
        final fullCmd = language.testCommand(ci: true);
        executable = fullCmd.first;
        testArgs = fullCmd.skip(1).toList();
      }

      Logger.info('Running: $executable ${testArgs.join(' ')}');

      // Use Process.start with piped output so we can both stream to console
      // AND capture the full output for summary generation.
      final process = await Process.start(executable, testArgs, workingDirectory: repoRoot);

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
        RepoUtils.writeFileSafely(p.join(logDir, 'test_stdout.log'), stdoutBuf.toString());
        if (!stderrBuf.isEmpty) {
          RepoUtils.writeFileSafely(p.join(logDir, 'test_stderr.log'), stderrBuf.toString());
        }
      } on FileSystemException catch (e) {
        Logger.warn('Could not write log files: $e');
      }

      if (isDartLike) {
        // Parse the JSON results file for structured test data (Dart only)
        final results = await TestResultsUtil.parseTestResultsJson(jsonPath);

        // Generate and write the rich job summary
        TestResultsUtil.writeTestJobSummary(results, exitCode);
      }

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

      // Sub-packages may override the repo language; fall back to root.
      final spLanguageId = sp['language'] as String? ?? language.id;
      final spLanguage = resolveLanguage(spLanguageId);
      final bool spIsDartLike = spLanguage is DartLanguageSupport;

      Logger.header('Testing sub-package: $name ($path)');

      if (!Directory(dir).existsSync()) {
        Logger.warn('  Directory not found: $dir — skipping');
        continue;
      }

      if (!File(p.join(dir, spLanguage.manifestFile)).existsSync()) {
        Logger.error('  No ${spLanguage.manifestFile} in $dir — cannot test');
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
      // manifest files that the root dependency install may not cover).
      // Use Process.start so we can kill on timeout (Process.run would hang).
      final depCmd = spLanguage.dependencyInstallCommand();
      final depResult = await _runCommandWithTimeout(
        depCmd.first,
        depCmd.skip(1).toList(),
        dir,
        pubGetTimeout,
        onTimeout: () {
          Logger.error('  ${depCmd.join(' ')} timed out for $name (${pubGetTimeout.inMinutes}-minute limit)');
        },
      );
      if (depResult == null) {
        failures.add(name);
        continue;
      }
      if (depResult.exitCode != 0) {
        final depStderr = (depResult.stderr as String).trim();
        if (depStderr.isNotEmpty) Logger.error(depStderr);
        Logger.error('  ${depCmd.join(' ')} failed for $name (exit code ${depResult.exitCode})');
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

      // Build test command — Dart/Flutter uses file-reporter for structured
      // JSON results; other languages use their generic CI test command.
      final spJsonPath = p.join(spLogDir, 'results.json');
      final String spExecutable;
      final List<String> spTestArgs;
      if (spIsDartLike) {
        spExecutable = Platform.resolvedExecutable;
        spTestArgs = _buildDartTestArgs(spJsonPath);
      } else {
        final fullCmd = spLanguage.testCommand(ci: true);
        spExecutable = fullCmd.first;
        spTestArgs = fullCmd.skip(1).toList();
      }

      final spProcess = await Process.start(spExecutable, spTestArgs, workingDirectory: dir);
      final spExitCode = await _runTestProcess(spProcess, name, spLogDir, processTimeout);

      if (spIsDartLike) {
        final spResults = await TestResultsUtil.parseTestResultsJson(spJsonPath);
        TestResultsUtil.writeTestJobSummary(spResults, spExitCode, platformId: name);
      }

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

  /// Build the Dart-specific test arguments with JSON file reporter.
  ///
  /// This preserves the original `dart test` invocation: expanded reporter
  /// for console output, JSON file reporter for structured results, and
  /// standard exclude-tags for CI.
  static List<String> _buildDartTestArgs(String jsonPath) => <String>[
    'test',
    '--exclude-tags',
    'gcp,integration',
    '--chain-stack-traces',
    '--reporter',
    'expanded',
    '--file-reporter',
    'json:$jsonPath',
  ];

  /// Run a started test [process], streaming and capturing output.
  ///
  /// Returns the process exit code (or -1 on timeout kill). Writes captured
  /// stdout/stderr to log files under [logDir].
  static Future<int> _runTestProcess(Process process, String label, String logDir, Duration processTimeout) async {
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

    int exitCode;
    try {
      exitCode = await process.exitCode.timeout(processTimeout);
    } on TimeoutException {
      Logger.error('Test process for $label exceeded ${processTimeout.inMinutes}-minute timeout — killing.');
      exitCode = await _killAndAwaitExit(process);
    }

    try {
      await Future.wait([stdoutSub.asFuture<void>(), stderrSub.asFuture<void>()]).timeout(const Duration(seconds: 30));
    } catch (_) {
      // Process killed or streams timed out
    } finally {
      await stdoutSub.cancel();
      await stderrSub.cancel();
    }

    try {
      RepoUtils.writeFileSafely(p.join(logDir, 'test_stdout.log'), stdoutBuf.toString());
      if (!stderrBuf.isEmpty) {
        RepoUtils.writeFileSafely(p.join(logDir, 'test_stderr.log'), stderrBuf.toString());
      }
    } on FileSystemException catch (e) {
      Logger.warn('Could not write log files for $label: $e');
    }

    return exitCode;
  }

  /// Runs [executable] with [args] in [workingDirectory] with [timeout].
  ///
  /// Kills the process on timeout to avoid indefinite hangs. Returns null on
  /// timeout. This is a generalized version of the original Dart-specific
  /// `_runPubGetWithTimeout` — it works for any language's dependency install.
  static Future<ProcessResult?> _runCommandWithTimeout(
    String executable,
    List<String> args,
    String workingDirectory,
    Duration timeout, {
    void Function()? onTimeout,
  }) async {
    final process = await Process.start(
      executable,
      args,
      workingDirectory: workingDirectory,
      environment: {'GIT_LFS_SKIP_SMUDGE': '1'},
    );
    const truncationSuffix = '\n\n... (output truncated).';
    final stdoutBuf = Utf8BoundedBuffer(maxBytes: _maxPubGetBufferBytes, truncationSuffix: truncationSuffix);
    final stderrBuf = Utf8BoundedBuffer(maxBytes: _maxPubGetBufferBytes, truncationSuffix: truncationSuffix);

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

  static Future<String> _resolveLogDirOrExit(
    String repoRoot,
    _ExitHandler exitHandler, {
    Map<String, String>? environment,
  }) async {
    try {
      final logDir = RepoUtils.resolveTestLogDir(repoRoot, environment: environment);
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
