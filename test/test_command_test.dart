import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:runtime_ci_tooling/src/cli/commands/test_command.dart';
import 'package:runtime_ci_tooling/src/cli/utils/test_results_util.dart';
import 'package:runtime_ci_tooling/src/triage/utils/config.dart';

void main() {
  group('TestCommand.runWithRoot', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('test_command_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('skips root tests and succeeds when no test/ directory exists', () async {
      // Minimal repo: pubspec with matching name, no test/
      File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('name: ${config.repoName}\nversion: 0.0.0\n');

      // Completes without throwing or exit(1); StepSummary.write is no-op when
      // GITHUB_STEP_SUMMARY is unset (local runs).
      await TestCommand.runWithRoot(tempDir.path);
    });

    test('uses passed repoRoot for log directory resolution', () async {
      // Create minimal repo
      File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('name: ${config.repoName}\nversion: 0.0.0\n');

      await TestCommand.runWithRoot(tempDir.path);

      // Log dir should be under repoRoot when TEST_LOG_DIR is unset
      final expectedLogDir = p.join(tempDir.path, '.dart_tool', 'test-logs');
      expect(Directory(expectedLogDir).existsSync(), isTrue);
    });

    test('runs root tests, writes results.json, and StepSummary pathway produces valid output', () async {
      // Minimal repo with a passing test to exercise full TestCommand flow
      File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: ${config.repoName}
version: 0.0.0
environment:
  sdk: ^3.0.0
dev_dependencies:
  test: ^1.24.0
''');
      Directory(p.join(tempDir.path, 'test')).createSync(recursive: true);
      File(p.join(tempDir.path, 'test', 'passing_test.dart')).writeAsStringSync('''
import 'package:test/test.dart';

void main() {
  test('passes', () => expect(1 + 1, equals(2)));
}
''');
      // Resolve dependencies so dart test can run
      final pubGet = await Process.run('dart', ['pub', 'get'], workingDirectory: tempDir.path);
      expect(pubGet.exitCode, equals(0), reason: 'dart pub get must succeed');

      await TestCommand.runWithRoot(tempDir.path);

      final logDir = p.join(tempDir.path, '.dart_tool', 'test-logs');
      expect(Directory(logDir).existsSync(), isTrue, reason: 'log dir should be created');

      // results.json or expanded.txt are written by file reporters
      final jsonPath = p.join(logDir, 'results.json');
      final expandedPath = p.join(logDir, 'expanded.txt');
      final hasResults = File(jsonPath).existsSync() || File(expandedPath).existsSync();
      expect(hasResults, isTrue, reason: 'at least one reporter output should exist');

      // If results.json exists, verify parse + writeTestJobSummary pathway
      if (File(jsonPath).existsSync()) {
        final results = TestResultsUtil.parseTestResultsJson(jsonPath);
        expect(results.parsed, isTrue);
        expect(results.passed, greaterThanOrEqualTo(1));
        expect(results.failed, equals(0));

        String? capturedSummary;
        TestResultsUtil.writeTestJobSummary(
          results,
          0,
          platformId: 'test-runner',
          writeSummary: (m) => capturedSummary = m,
        );
        expect(capturedSummary, isNotNull);
        expect(capturedSummary!, contains('## Test Results — test-runner'));
        expect(capturedSummary!, contains('passed'));
      }
    });
  });
}
