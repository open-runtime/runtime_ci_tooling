import 'dart:convert';
import 'dart:io';

import '../../triage/utils/config.dart';
import 'logger.dart';

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

/// Step summary utilities for GitHub Actions.
abstract final class StepSummary {
  /// Write a markdown summary to $GITHUB_STEP_SUMMARY (visible in Actions UI).
  /// No-op when running locally (env var not set).
  static void write(String markdown) {
    final summaryFile = Platform.environment['GITHUB_STEP_SUMMARY'];
    if (summaryFile != null) {
      File(summaryFile).writeAsStringSync(markdown, mode: FileMode.append);
    }
  }

  /// Build a link to the current workflow run's artifacts page.
  static String artifactLink([String label = 'View all artifacts']) {
    final server =
        Platform.environment['GITHUB_SERVER_URL'] ?? 'https://github.com';
    final repo = Platform.environment['GITHUB_REPOSITORY'];
    final runId = Platform.environment['GITHUB_RUN_ID'];
    if (repo == null || runId == null) return '';
    return '[$label]($server/$repo/actions/runs/$runId)';
  }

  /// Build a GitHub compare link between two refs.
  static String compareLink(String prevTag, String newTag, [String? label]) {
    final server =
        Platform.environment['GITHUB_SERVER_URL'] ?? 'https://github.com';
    final repo =
        Platform.environment['GITHUB_REPOSITORY'] ??
        '${config.repoOwner}/${config.repoName}';
    final text = label ?? '$prevTag...$newTag';
    return '[$text]($server/$repo/compare/$prevTag...$newTag)';
  }

  /// Build a link to a file/path in the repository.
  static String ghLink(String label, String path) {
    final server =
        Platform.environment['GITHUB_SERVER_URL'] ?? 'https://github.com';
    final repo =
        Platform.environment['GITHUB_REPOSITORY'] ??
        '${config.repoOwner}/${config.repoName}';
    final sha = Platform.environment['GITHUB_SHA'] ?? 'main';
    return '[$label]($server/$repo/blob/$sha/$path)';
  }

  /// Build a link to a GitHub Release by tag.
  static String releaseLink(String tag) {
    final server =
        Platform.environment['GITHUB_SERVER_URL'] ?? 'https://github.com';
    final repo =
        Platform.environment['GITHUB_REPOSITORY'] ??
        '${config.repoOwner}/${config.repoName}';
    return '[v$tag]($server/$repo/releases/tag/$tag)';
  }

  /// Wrap content in a collapsible <details> block for step summaries.
  static String collapsible(String title, String content, {bool open = false}) {
    if (content.trim().isEmpty) return '';
    final openAttr = open ? ' open' : '';
    return '\n<details$openAttr>\n<summary>$title</summary>\n\n$content\n\n</details>\n';
  }

  /// Escape HTML special characters for safe embedding in GitHub markdown.
  static String escapeHtml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }

  /// Parse the NDJSON file produced by `dart test --file-reporter json:...`.
  static TestResults parseTestResultsJson(String jsonPath) {
    final results = TestResults();
    final file = File(jsonPath);
    if (!file.existsSync()) {
      Logger.warn('No JSON results file found at $jsonPath');
      return results;
    }

    results.parsed = true;

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
            testErrors.putIfAbsent(id, () => StringBuffer());
            if (testErrors[id]!.isNotEmpty) testErrors[id]!.write('\n---\n');
            testErrors[id]!.write(event['error'] as String? ?? '');
            testStackTraces.putIfAbsent(id, () => StringBuffer());
            if (testStackTraces[id]!.isNotEmpty)
              testStackTraces[id]!.write('\n---\n');
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
        Logger.warn('Skipping malformed JSON line: $e');
      }
    }

    return results;
  }

  /// Write a rich test summary block to `$GITHUB_STEP_SUMMARY`.
  static void writeTestJobSummary(TestResults results, int exitCode) {
    final buf = StringBuffer();

    final platformId =
        Platform.environment['PLATFORM_ID'] ??
        Platform.environment['RUNNER_NAME'] ??
        Platform.operatingSystem;

    buf.writeln('## Test Results — ${escapeHtml(platformId)}');
    buf.writeln();

    if (!results.parsed) {
      final status = exitCode == 0 ? 'passed' : 'failed';
      final icon = exitCode == 0 ? 'NOTE' : 'CAUTION';
      buf.writeln('> [!$icon]');
      buf.writeln(
        '> Tests $status (exit code $exitCode) — no structured results available.',
      );
      buf.writeln();
      buf.writeln('Check the expanded output in test logs for details.');
      buf.writeln();
      buf.writeln(artifactLink(':package: View full test logs'));
      write(buf.toString());
      return;
    }

    final total = results.passed + results.failed + results.skipped;
    final durationSec = (results.totalDurationMs / 1000).toStringAsFixed(1);

    if (results.failed == 0) {
      buf.writeln('> [!NOTE]');
      buf.writeln('> All $total tests passed in ${durationSec}s');
    } else {
      buf.writeln('> [!CAUTION]');
      buf.writeln('> ${results.failed} of $total tests failed');
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
        buf.writeln(
          '<summary><strong>:x: ${escapeHtml(f.name)}</strong>$durStr</summary>',
        );
        buf.writeln();

        if (f.error.isNotEmpty) {
          final error = f.error.length > 2000
              ? '${f.error.substring(0, 2000)}\n... (truncated)'
              : f.error;
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
          final printPreview = trimmed.length > 1500
              ? '${trimmed.substring(0, 1500)}\n... (truncated)'
              : trimmed;
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
          '_...and ${results.failures.length - 20} more failures. See test logs artifact for full details._',
        );
        buf.writeln();
      }
    }

    buf.writeln('---');
    buf.writeln(artifactLink(':package: View full test logs'));
    buf.writeln();

    write(buf.toString());
  }

  static String _codeFence(String content) {
    var fence = '```';
    while (content.contains(fence)) {
      fence += '`';
    }
    return fence;
  }
}
