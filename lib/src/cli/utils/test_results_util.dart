import 'dart:convert';
import 'dart:io';

import 'logger.dart';
import 'step_summary.dart';

/// A single test failure with its error, stack trace, and captured print output.
class TestFailure {
  final String name;
  final String error;
  final String stackTrace;
  final String printOutput;
  final int durationMs;

  TestFailure({
    required this.name,
    required this.error,
    required this.stackTrace,
    required this.printOutput,
    required this.durationMs,
  });
}

/// Parsed results from the NDJSON test results file produced by `--file-reporter json:`.
class TestResults {
  int passed = 0;
  int failed = 0;
  int skipped = 0;
  int totalDurationMs = 0;
  final List<TestFailure> failures = [];
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
TestResults parseTestResultsJson(String jsonPath) {
  final results = TestResults();
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
              TestFailure(
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

/// Choose a code fence delimiter that does not appear in [content].
String _codeFence(String content) {
  var fence = '```';
  while (content.contains(fence)) {
    fence += '`';
  }
  return fence;
}

/// Generate a rich GitHub Actions job summary from parsed test results.
///
/// Writes to $GITHUB_STEP_SUMMARY when running in CI. Platform identifier
/// and failure names are HTML-escaped for safe embedding.
void writeTestJobSummary(TestResults results, int exitCode, String logDir) {
  final buf = StringBuffer();

  // Determine platform identifier for the heading (HTML-escaped for safe embedding)
  final platformId =
      Platform.environment['PLATFORM_ID'] ?? Platform.environment['RUNNER_NAME'] ?? Platform.operatingSystem;

  buf.writeln('## Test Results — ${StepSummary.escapeHtml(platformId)}');
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
    buf.writeln(StepSummary.artifactLink(':package: View full test logs'));
    StepSummary.write(buf.toString());
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
      buf.writeln('<summary><strong>:x: ${StepSummary.escapeHtml(f.name)}</strong>$durStr</summary>');
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
  buf.writeln(StepSummary.artifactLink(':package: View full test logs'));
  buf.writeln();

  StepSummary.write(buf.toString());
}
