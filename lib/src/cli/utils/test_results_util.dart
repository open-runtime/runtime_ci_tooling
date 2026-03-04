import 'dart:convert';
import 'dart:io';

import 'logger.dart';
import 'step_summary.dart';

/// A single failed test record parsed from the JSON reporter output.
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

/// Parsed aggregate test results from the NDJSON file reporter.
class TestResults {
  int passed = 0;
  int failed = 0;
  int skipped = 0;
  int totalDurationMs = 0;
  final List<TestFailure> failures = [];
  bool parsed = false;
}

/// Maximum chars to store per failure field to prevent unbounded memory growth.
const int _maxStoredErrorChars = 8000;
const int _maxStoredStackTraceChars = 6000;
const int _maxStoredPrintChars = 6000;

/// Test-results parsing and step-summary writing for CI.
abstract final class TestResultsUtil {
  /// Parse the NDJSON file produced by `dart test --file-reporter json:...`.
  ///
  /// Uses streaming line-by-line parsing to avoid loading very large result
  /// files fully into memory.
  static Future<TestResults> parseTestResultsJson(String jsonPath) async {
    final results = TestResults();
    final file = File(jsonPath);
    if (!file.existsSync()) {
      Logger.warn('No JSON results file found at $jsonPath');
      return results;
    }

    final testNames = <int, String>{};
    final testStartTimes = <int, int>{};
    final testErrors = <int, StringBuffer>{};
    final testStackTraces = <int, StringBuffer>{};
    final testPrints = <int, StringBuffer>{};

    const _maxMalformedWarnings = 5;
    var malformedCount = 0;

    try {
      final lines = file.openRead().transform(const Utf8Decoder(allowMalformed: true)).transform(const LineSplitter());

      await for (final line in lines) {
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
              results.parsed = true;

            case 'testDone':
              final id = event['testID'] as int?;
              if (id == null) break;
              final resultStr = event['result'] as String?;
              final hidden = event['hidden'] as bool? ?? false;
              final skipped = event['skipped'] as bool? ?? false;

              if (hidden) break;

              results.parsed = true;
              if (skipped) {
                results.skipped++;
              } else if (resultStr == 'success') {
                results.passed++;
              } else if (resultStr == 'failure' || resultStr == 'error') {
                results.failed++;
                if (results.failures.length < 50) {
                  final startTime = testStartTimes[id] ?? 0;
                  final endTime = event['time'] as int? ?? 0;
                  final rawError = testErrors[id]?.toString() ?? '';
                  final rawStack = testStackTraces[id]?.toString() ?? '';
                  final rawPrint = testPrints[id]?.toString() ?? '';
                  results.failures.add(
                    TestFailure(
                      name: testNames[id] ?? 'unknown',
                      error: rawError.length > _maxStoredErrorChars
                          ? '${rawError.substring(0, _maxStoredErrorChars)}\n... (truncated)'
                          : rawError,
                      stackTrace: rawStack.length > _maxStoredStackTraceChars
                          ? '${rawStack.substring(0, _maxStoredStackTraceChars)}\n... (truncated)'
                          : rawStack,
                      printOutput: rawPrint.length > _maxStoredPrintChars
                          ? '${rawPrint.substring(0, _maxStoredPrintChars)}\n... (truncated)'
                          : rawPrint,
                      durationMs: endTime - startTime,
                    ),
                  );
                }
              }

            case 'error':
              results.parsed = true;
              final id = event['testID'] as int?;
              if (id == null) break;
              testErrors.putIfAbsent(id, () => StringBuffer());
              if (testErrors[id]!.isNotEmpty) testErrors[id]!.write('\n---\n');
              testErrors[id]!.write(event['error'] as String? ?? '');
              testStackTraces.putIfAbsent(id, () => StringBuffer());
              if (testStackTraces[id]!.isNotEmpty) testStackTraces[id]!.write('\n---\n');
              testStackTraces[id]!.write(event['stackTrace'] as String? ?? '');

            case 'print':
              results.parsed = true;
              final id = event['testID'] as int?;
              if (id == null) break;
              final message = event['message'] as String? ?? '';
              testPrints.putIfAbsent(id, () => StringBuffer());
              testPrints[id]!.writeln(message);

            case 'done':
              results.parsed = true;
              final time = event['time'] as int? ?? 0;
              results.totalDurationMs = time;
          }
        } catch (e) {
          malformedCount++;
          if (malformedCount <= _maxMalformedWarnings) {
            Logger.warn('Skipping malformed JSON line: $e');
          } else if (malformedCount == _maxMalformedWarnings + 1) {
            Logger.warn('Skipping malformed JSON lines (circuit breaker — suppressing further warnings)');
          }
        }
      }
    } on FileSystemException catch (e) {
      Logger.warn('Failed reading JSON results file at $jsonPath: $e');
      return results;
    }

    if (malformedCount > _maxMalformedWarnings) {
      final remainder = malformedCount - _maxMalformedWarnings;
      Logger.warn('Skipped $remainder additional malformed JSON line(s).');
    }

    return results;
  }

  /// Write a rich test summary block to `$GITHUB_STEP_SUMMARY`.
  ///
  /// Optional overrides are used by tests to capture deterministic output
  /// without requiring CI environment variables.
  static void writeTestJobSummary(
    TestResults results,
    int exitCode, {
    String? platformId,
    void Function(String markdown)? writeSummary,
  }) {
    final effectivePlatformId =
        platformId ??
        Platform.environment['PLATFORM_ID'] ??
        Platform.environment['RUNNER_NAME'] ??
        Platform.operatingSystem;
    final markdown = _buildTestJobSummaryMarkdown(
      results: results,
      exitCode: exitCode,
      platformId: effectivePlatformId,
    );
    final writer = writeSummary ?? StepSummary.write;
    writer(markdown);
  }

  static String _buildTestJobSummaryMarkdown({
    required TestResults results,
    required int exitCode,
    required String platformId,
  }) {
    final buf = StringBuffer();

    buf.writeln('## Test Results — ${StepSummary.escapeHtml(platformId)}');
    buf.writeln();

    if (!results.parsed) {
      final status = exitCode == 0 ? 'passed' : 'failed';
      final icon = exitCode == 0 ? 'NOTE' : 'CAUTION';
      buf.writeln('> [!$icon]');
      buf.writeln('> Tests $status (exit code $exitCode) — no structured results available.');
      buf.writeln();
      buf.writeln('Check the expanded output in test logs for details.');
      buf.writeln();
      buf.writeln(StepSummary.artifactLink(':package: View full test logs'));
      return buf.toString();
    }

    final total = results.passed + results.failed + results.skipped;
    final durationSec = (results.totalDurationMs / 1000).toStringAsFixed(1);
    final hasFailingStatus = results.failed > 0 || exitCode != 0;

    if (!hasFailingStatus) {
      buf.writeln('> [!NOTE]');
      buf.writeln('> All $total tests passed in ${durationSec}s');
    } else if (results.failed > 0) {
      buf.writeln('> [!CAUTION]');
      buf.writeln('> ${results.failed} of $total tests failed');
    } else {
      buf.writeln('> [!CAUTION]');
      buf.writeln('> Tests exited with code $exitCode despite no structured test failures.');
    }
    buf.writeln();

    buf.writeln('| Status | Count |');
    buf.writeln('|--------|------:|');
    buf.writeln('| :white_check_mark: Passed | ${results.passed} |');
    buf.writeln('| :x: Failed | ${results.failed} |');
    buf.writeln('| :fast_forward: Skipped | ${results.skipped} |');
    buf.writeln('| **Total** | **$total** |');
    buf.writeln('| **Duration** | **${durationSec}s** |');
    buf.writeln();

    if (results.failures.isNotEmpty) {
      buf.writeln('### Failed Tests');
      buf.writeln();

      final displayFailures = results.failures.take(20).toList();
      for (final f in displayFailures) {
        final durStr = f.durationMs > 0 ? ' (${f.durationMs}ms)' : '';
        buf.writeln('<details>');
        buf.writeln('<summary><strong>:x: ${StepSummary.escapeHtml(f.name)}</strong>$durStr</summary>');
        buf.writeln();

        if (f.error.isNotEmpty) {
          final error = f.error.length > 2000 ? '${f.error.substring(0, 2000)}\n... (truncated)' : f.error;
          buf.writeln('**Error:**');
          final fence = _codeFence(error);
          buf.writeln(fence);
          buf.writeln(error);
          buf.writeln(fence);
          buf.writeln();
        }

        if (f.stackTrace.isNotEmpty) {
          final stack = f.stackTrace.length > 1500
              ? '${f.stackTrace.substring(0, 1500)}\n... (truncated)'
              : f.stackTrace;
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
        buf.writeln('_...and ${results.failures.length - 20} more failures. See test logs artifact for full details._');
        buf.writeln();
      }
    }

    buf.writeln('---');
    buf.writeln(StepSummary.artifactLink(':package: View full test logs'));
    buf.writeln();
    return buf.toString();
  }

  /// Returns a markdown code fence string that will not appear inside [content].
  /// Handles adversarial content with long backtick runs by using fence length
  /// strictly greater than max consecutive backticks.
  static String _codeFence(String content) {
    var maxRun = 0;
    var run = 0;
    for (final c in content.codeUnits) {
      if (c == 0x60) {
        run++;
      } else {
        if (run > maxRun) maxRun = run;
        run = 0;
      }
    }
    if (run > maxRun) maxRun = run;
    // Fence must be longer than any backtick run in content.
    // Content is already preview-truncated, so this is naturally bounded.
    return '`' * (maxRun + 1 < 3 ? 3 : maxRun + 1);
  }
}
