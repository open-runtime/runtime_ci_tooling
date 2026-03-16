import 'dart:convert';

/// Abstract interface for parsing test results from different frameworks.
abstract class TestResultParser {
  /// Parse raw JSON output from a test framework.
  TestSummary parse(String jsonOutput);

  /// The test framework name (e.g., "vitest", "jest", "dart_test").
  String get frameworkName;
}

/// Aggregated test results.
class TestSummary {
  final int passed;
  final int failed;
  final int skipped;
  final int total;
  final Duration duration;
  final List<TestFailure> failures;
  final String frameworkDisplay;

  TestSummary({
    required this.passed,
    required this.failed,
    required this.skipped,
    required this.total,
    required this.duration,
    required this.failures,
    this.frameworkDisplay = 'Unknown',
  });

  bool get success => failed == 0;

  String toMarkdownSummary() {
    final buf = StringBuffer();
    buf.writeln('### Test Results ($frameworkDisplay)');
    buf.writeln('');
    buf.writeln('| Status | Count |');
    buf.writeln('|--------|-------|');
    buf.writeln('| Passed | $passed |');
    buf.writeln('| Failed | $failed |');
    buf.writeln('| Skipped | $skipped |');
    buf.writeln('| **Total** | **$total** |');
    buf.writeln('');
    buf.writeln('Duration: ${duration.inSeconds}s');
    if (failures.isNotEmpty) {
      buf.writeln('');
      buf.writeln('### Failures');
      for (final f in failures) {
        buf.writeln('');
        buf.writeln('**${f.testName}**');
        buf.writeln('```');
        buf.writeln(f.message);
        buf.writeln('```');
      }
    }
    return buf.toString();
  }
}

/// A single test failure with its name, error message, and optional stack trace.
class TestFailure {
  final String testName;
  final String message;
  final String? stackTrace;

  TestFailure({required this.testName, required this.message, this.stackTrace});
}

/// Parser for vitest JSON reporter output.
///
/// Vitest JSON output shape:
/// ```json
/// {
///   "testResults": [
///     {
///       "assertionResults": [
///         { "status": "passed"|"failed"|"pending"|"skipped"|"todo",
///           "fullName": "...", "title": "...", "failureMessages": [...] }
///       ]
///     }
///   ],
///   "startTime": <epoch ms>,
///   "endTime": <epoch ms> (vitest extension, not always present)
/// }
/// ```
class VitestResultParser implements TestResultParser {
  @override
  String get frameworkName => 'vitest';

  @override
  TestSummary parse(String jsonOutput) {
    final json = jsonDecode(jsonOutput) as Map<String, dynamic>;
    final testResults = json['testResults'] as List<dynamic>? ?? [];

    var passed = 0;
    var failed = 0;
    var skipped = 0;
    final failures = <TestFailure>[];

    for (final suite in testResults) {
      final assertionResults = (suite as Map<String, dynamic>)['assertionResults'] as List<dynamic>? ?? [];
      for (final test in assertionResults) {
        final status = (test as Map<String, dynamic>)['status'] as String?;
        final fullName = test['fullName'] as String? ?? test['title'] as String? ?? 'unknown';
        switch (status) {
          case 'passed':
            passed++;
          case 'failed':
            failed++;
            final msgs = test['failureMessages'] as List<dynamic>? ?? [];
            failures.add(TestFailure(testName: fullName, message: msgs.join('\n')));
          case 'pending' || 'skipped' || 'todo':
            skipped++;
        }
      }
    }

    final startTime = json['startTime'] as int?;
    final endTime = json['endTime'] as int?;
    final durationMs = startTime != null && endTime != null ? endTime - startTime : 0;

    return TestSummary(
      passed: passed,
      failed: failed,
      skipped: skipped,
      total: passed + failed + skipped,
      duration: Duration(milliseconds: durationMs),
      failures: failures,
      frameworkDisplay: 'Vitest',
    );
  }
}

/// Parser for Jest JSON reporter output.
///
/// Jest JSON output shape (via `--json` flag):
/// ```json
/// {
///   "numPassedTests": N,
///   "numFailedTests": N,
///   "numPendingTests": N,
///   "numTodoTests": N,
///   "numTotalTests": N,
///   "startTime": <epoch ms>,
///   "wasInterrupted": false,
///   "testResults": [
///     {
///       "assertionResults": [
///         { "status": "passed"|"failed"|"pending",
///           "fullName": "...", "failureMessages": [...] }
///       ]
///     }
///   ]
/// }
/// ```
class JestResultParser implements TestResultParser {
  @override
  String get frameworkName => 'jest';

  @override
  TestSummary parse(String jsonOutput) {
    final json = jsonDecode(jsonOutput) as Map<String, dynamic>;

    final passed = json['numPassedTests'] as int? ?? 0;
    final failed = json['numFailedTests'] as int? ?? 0;
    final skipped = (json['numPendingTests'] as int? ?? 0) + (json['numTodoTests'] as int? ?? 0);

    final failures = <TestFailure>[];
    final testResults = json['testResults'] as List<dynamic>? ?? [];
    for (final suite in testResults) {
      final assertionResults = (suite as Map<String, dynamic>)['assertionResults'] as List<dynamic>? ?? [];
      for (final test in assertionResults) {
        if ((test as Map<String, dynamic>)['status'] == 'failed') {
          final msgs = test['failureMessages'] as List<dynamic>? ?? [];
          failures.add(TestFailure(testName: test['fullName'] as String? ?? 'unknown', message: msgs.join('\n')));
        }
      }
    }

    final startTime = json['startTime'] as int? ?? 0;
    final wasInterrupted = json['wasInterrupted'] as bool? ?? false;
    final durationMs = wasInterrupted ? 0 : DateTime.now().millisecondsSinceEpoch - startTime;

    return TestSummary(
      passed: passed,
      failed: failed,
      skipped: skipped,
      total: json['numTotalTests'] as int? ?? (passed + failed + skipped),
      duration: Duration(milliseconds: durationMs),
      failures: failures,
      frameworkDisplay: 'Jest',
    );
  }
}

/// Detect which parser to use based on content heuristics.
///
/// Returns `null` if the JSON cannot be parsed or does not match a known
/// framework output shape. Jest is detected first because its output always
/// includes `numPassedTests`; vitest uses a Jest-compatible shape but without
/// that top-level key.
TestResultParser? detectParser(String jsonOutput) {
  try {
    final json = jsonDecode(jsonOutput) as Map<String, dynamic>;
    // Jest always includes numPassedTests at the top level.
    if (json.containsKey('numPassedTests')) return JestResultParser();
    // Vitest outputs testResults without numPassedTests.
    if (json.containsKey('testResults')) return VitestResultParser();
    return null;
  } catch (_) {
    return null;
  }
}
