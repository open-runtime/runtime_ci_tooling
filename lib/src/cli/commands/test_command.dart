import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../../triage/utils/config.dart';
import '../utils/logger.dart';
import '../utils/repo_utils.dart';
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
      _writeStepSummary('## Test Results\n\n**No test/ directory found — skipped.**\n');
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
      final results = _parseTestResultsJson(jsonPath);

      // Generate and write the rich job summary
      _writeTestJobSummary(results, exitCode, logDir);

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
      exit(1);
    }

    Logger.success('All tests passed');
  }
}

// ── NDJSON Parsing ────────────────────────────────────────────────────────────

/// A single test failure with its error, stack trace, and captured print output.
class _TestFailure {
  final String name;
  final String error;
  final String stackTrace;
  final String printOutput;
  final int durationMs;

  _TestFailure({
    required this.name,
    required this.error,
    required this.stackTrace,
    required this.printOutput,
    required this.durationMs,
  });
}

/// Parsed results from the NDJSON test results file.
class _TestResults {
  int passed = 0;
  int failed = 0;
  int skipped = 0;
  int totalDurationMs = 0;
  final List<_TestFailure> failures = [];
  bool parsed = false;
}

/// Parse the NDJSON file produced by `--file-reporter json:`.
///
/// Each line is a JSON object with a `type` field. We track:
/// - `testStart`: register test name + start time
/// - `testDone`: record result, compute duration
/// - `error`: capture error message + stack trace (accumulated per test)
/// - `print`: capture print output, attribute to testID
/// - `done`: overall total time
_TestResults _parseTestResultsJson(String jsonPath) {
  final results = _TestResults();
  final file = File(jsonPath);
  if (!file.existsSync()) {
    Logger.warn('No JSON results file found at $jsonPath');
    return results;
  }

  results.parsed = true;

  // Tracking maps keyed by testID
  final testNames = <int, String>{};
  final testStartTimes = <int, int>{};
  final testErrors = <int, StringBuffer>{};
  final testStackTraces = <int, StringBuffer>{};
  final testPrints = <int, StringBuffer>{};

  final lines = file.readAsLinesSync();
  for (final line in lines) {
    if (line.trim().isEmpty) continue;
    try {
      final event = jsonDecode(line) as Map<String, dynamic>;
      final type = event['type'] as String?;

      switch (type) {
        case 'testStart':
          final test = event['test'] as Map<String, dynamic>?;
          if (test == null) break;
          final id = test['id'] as int?;
          if (id == null) break;
          testNames[id] = test['name'] as String? ?? 'unknown';
          testStartTimes[id] = event['time'] as int? ?? 0;

        case 'testDone':
          final id = event['testID'] as int?;
          if (id == null) break;
          final resultStr = event['result'] as String?;
          final hidden = event['hidden'] as bool? ?? false;
          final skipped = event['skipped'] as bool? ?? false;

          // Skip synthetic/hidden entries (group-level loading events)
          if (hidden) break;

          if (skipped) {
            results.skipped++;
          } else if (resultStr == 'success') {
            results.passed++;
          } else if (resultStr == 'failure' || resultStr == 'error') {
            results.failed++;
            final startTime = testStartTimes[id] ?? 0;
            final endTime = event['time'] as int? ?? 0;
            results.failures.add(
              _TestFailure(
                name: testNames[id] ?? 'unknown',
                error: testErrors[id]?.toString() ?? '',
                stackTrace: testStackTraces[id]?.toString() ?? '',
                printOutput: testPrints[id]?.toString() ?? '',
                durationMs: endTime - startTime,
              ),
            );
          }

        case 'error':
          final id = event['testID'] as int?;
          if (id == null) break;
          // Accumulate multiple errors per test (e.g. test failure + tearDown exception)
          testErrors.putIfAbsent(id, () => StringBuffer());
          if (testErrors[id]!.isNotEmpty) testErrors[id]!.write('\n---\n');
          testErrors[id]!.write(event['error'] as String? ?? '');
          testStackTraces.putIfAbsent(id, () => StringBuffer());
          if (testStackTraces[id]!.isNotEmpty) testStackTraces[id]!.write('\n---\n');
          testStackTraces[id]!.write(event['stackTrace'] as String? ?? '');

        case 'print':
          final id = event['testID'] as int?;
          if (id == null) break;
          final message = event['message'] as String? ?? '';
          testPrints.putIfAbsent(id, () => StringBuffer());
          testPrints[id]!.writeln(message);

        case 'done':
          final time = event['time'] as int? ?? 0;
          results.totalDurationMs = time;
      }
    } catch (e) {
      // Skip malformed JSON lines but continue parsing the rest
      Logger.warn('Skipping malformed JSON line: $e');
    }
  }

  return results;
}

// ── Job Summary ───────────────────────────────────────────────────────────────

/// Generate a rich GitHub Actions job summary from parsed test results.
void _writeTestJobSummary(_TestResults results, int exitCode, String logDir) {
  final buf = StringBuffer();

  // Determine platform identifier for the heading
  final platformId =
      Platform.environment['PLATFORM_ID'] ?? Platform.environment['RUNNER_NAME'] ?? Platform.operatingSystem;

  buf.writeln('## Test Results — $platformId');
  buf.writeln();

  if (!results.parsed) {
    // Fallback: no JSON file was produced (test binary crashed before writing)
    final status = exitCode == 0 ? 'passed' : 'failed';
    final icon = exitCode == 0 ? 'NOTE' : 'CAUTION';
    buf.writeln('> [!$icon]');
    buf.writeln('> Tests $status (exit code $exitCode) — no structured results available.');
    buf.writeln();
    buf.writeln('Check the expanded output in test logs for details.');
    buf.writeln();
    buf.writeln(_artifactLink(':package: View full test logs'));
    _writeStepSummary(buf.toString());
    return;
  }

  final total = results.passed + results.failed + results.skipped;
  final durationSec = (results.totalDurationMs / 1000).toStringAsFixed(1);

  // Status banner — alert box lines must all be prefixed with >
  if (results.failed == 0) {
    buf.writeln('> [!NOTE]');
    buf.writeln('> All $total tests passed in ${durationSec}s');
  } else {
    buf.writeln('> [!CAUTION]');
    buf.writeln('> ${results.failed} of $total tests failed');
  }
  buf.writeln();

  // Summary table
  buf.writeln('| Status | Count |');
  buf.writeln('|--------|------:|');
  buf.writeln('| :white_check_mark: Passed | ${results.passed} |');
  buf.writeln('| :x: Failed | ${results.failed} |');
  buf.writeln('| :fast_forward: Skipped | ${results.skipped} |');
  buf.writeln('| **Total** | **$total** |');
  buf.writeln('| **Duration** | **${durationSec}s** |');
  buf.writeln();

  // Failed test details
  if (results.failures.isNotEmpty) {
    buf.writeln('### Failed Tests');
    buf.writeln();

    // Cap at 20 failures to avoid exceeding the 1 MiB summary limit
    final displayFailures = results.failures.take(20).toList();
    for (final f in displayFailures) {
      final durStr = f.durationMs > 0 ? ' (${f.durationMs}ms)' : '';
      buf.writeln('<details>');
      buf.writeln('<summary><strong>:x: ${_escapeHtml(f.name)}</strong>$durStr</summary>');
      buf.writeln();

      if (f.error.isNotEmpty) {
        // Truncate very long error messages
        final error = f.error.length > 2000 ? '${f.error.substring(0, 2000)}\n... (truncated)' : f.error;
        buf.writeln('**Error:**');
        final fence = _codeFence(error);
        buf.writeln(fence);
        buf.writeln(error);
        buf.writeln(fence);
        buf.writeln();
      }

      if (f.stackTrace.isNotEmpty) {
        // Truncate very long stack traces
        final stack = f.stackTrace.length > 1500 ? '${f.stackTrace.substring(0, 1500)}\n... (truncated)' : f.stackTrace;
        buf.writeln('**Stack Trace:**');
        final fence = _codeFence(stack);
        buf.writeln(fence);
        buf.writeln(stack);
        buf.writeln(fence);
        buf.writeln();
      }

      if (f.printOutput.isNotEmpty) {
        final trimmed = f.printOutput.trimRight();
        final lineCount = trimmed.split('\n').length;
        // Truncate captured output if it's very long
        final printPreview = trimmed.length > 1500 ? '${trimmed.substring(0, 1500)}\n... (truncated)' : trimmed;
        buf.writeln('**Captured Output ($lineCount lines):**');
        final fence = _codeFence(printPreview);
        buf.writeln(fence);
        buf.writeln(printPreview);
        buf.writeln(fence);
        buf.writeln();
      }

      buf.writeln('</details>');
      buf.writeln();
    }

    if (results.failures.length > 20) {
      buf.writeln(
        '_...and ${results.failures.length - 20} more failures. '
        'See test logs artifact for full details._',
      );
      buf.writeln();
    }
  }

  // Artifact link
  buf.writeln('---');
  buf.writeln(_artifactLink(':package: View full test logs'));
  buf.writeln();

  _writeStepSummary(buf.toString());
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Write a markdown summary to $GITHUB_STEP_SUMMARY (visible in Actions UI).
/// No-op when running locally (env var not set).
void _writeStepSummary(String markdown) {
  final summaryFile = Platform.environment['GITHUB_STEP_SUMMARY'];
  if (summaryFile != null) {
    File(summaryFile).writeAsStringSync(markdown, mode: FileMode.append);
  }
}

/// Build a link to the current workflow run's artifacts page.
String _artifactLink([String label = 'View all artifacts']) {
  final server = Platform.environment['GITHUB_SERVER_URL'] ?? 'https://github.com';
  final repo = Platform.environment['GITHUB_REPOSITORY'];
  final runId = Platform.environment['GITHUB_RUN_ID'];
  if (repo == null || runId == null) return '';
  return '[$label]($server/$repo/actions/runs/$runId)';
}

/// Escape HTML special characters for safe embedding in GitHub markdown.
String _escapeHtml(String input) {
  return input.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
}

/// Choose a code fence delimiter that does not appear in [content].
/// Starts with triple backticks and extends as needed.
String _codeFence(String content) {
  var fence = '```';
  while (content.contains(fence)) {
    fence += '`';
  }
  return fence;
}
