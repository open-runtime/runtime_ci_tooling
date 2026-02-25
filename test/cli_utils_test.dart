import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart' hide TestFailure;

import 'package:runtime_ci_tooling/src/cli/utils/process_runner.dart';
import 'package:runtime_ci_tooling/src/cli/utils/repo_utils.dart';
import 'package:runtime_ci_tooling/src/cli/utils/step_summary.dart';
import 'package:runtime_ci_tooling/src/cli/utils/sub_package_utils.dart';
import 'package:runtime_ci_tooling/src/cli/utils/test_results_util.dart';

bool _canCreateSymlink() {
  final tempDir = Directory.systemTemp.createTempSync('symlink_probe_');
  try {
    final target = File(p.join(tempDir.path, 'target.txt'));
    target.writeAsStringSync('ok');
    final linkPath = p.join(tempDir.path, 'link.txt');
    Link(linkPath).createSync(target.path);
    return RepoUtils.isSymlinkPath(linkPath);
  } on FileSystemException {
    return false;
  } finally {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  }
}

void main() {
  final symlinksSupported = _canCreateSymlink();

  group('RepoUtils.resolveTestLogDir', () {
    late Directory tempDir;
    late String repoRoot;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('repo_utils_resolve_');
      repoRoot = tempDir.path;
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('returns default path when TEST_LOG_DIR is unset', () {
      final resolved = RepoUtils.resolveTestLogDir(
        repoRoot,
        environment: const <String, String>{},
      );
      expect(resolved, equals(p.join(repoRoot, '.dart_tool', 'test-logs')));
    });

    test('returns default path when TEST_LOG_DIR is empty/whitespace', () {
      final resolved = RepoUtils.resolveTestLogDir(
        repoRoot,
        environment: const <String, String>{'TEST_LOG_DIR': '   '},
      );
      expect(resolved, equals(p.join(repoRoot, '.dart_tool', 'test-logs')));
    });

    test('throws when TEST_LOG_DIR contains control characters', () {
      expect(
        () => RepoUtils.resolveTestLogDir(
          repoRoot,
          environment: const <String, String>{'TEST_LOG_DIR': '/tmp/logs\nbad'},
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('throws when TEST_LOG_DIR is relative', () {
      expect(
        () => RepoUtils.resolveTestLogDir(
          repoRoot,
          environment: const <String, String>{'TEST_LOG_DIR': 'relative/path'},
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('throws when TEST_LOG_DIR is outside RUNNER_TEMP', () {
      final runnerTemp = p.join(repoRoot, 'runner-temp');
      final outside = p.join(repoRoot, 'outside', 'logs');
      expect(
        () => RepoUtils.resolveTestLogDir(
          repoRoot,
          environment: {'RUNNER_TEMP': runnerTemp, 'TEST_LOG_DIR': outside},
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('accepts TEST_LOG_DIR inside RUNNER_TEMP', () {
      final runnerTemp = p.join(repoRoot, 'runner-temp');
      final inside = p.join(runnerTemp, 'logs');
      final resolved = RepoUtils.resolveTestLogDir(
        repoRoot,
        environment: {'RUNNER_TEMP': runnerTemp, 'TEST_LOG_DIR': inside},
      );
      expect(resolved, equals(inside));
    });
  });

  group('RepoUtils filesystem safety', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('repo_utils_fs_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('ensureSafeDirectory creates a missing normal directory', () {
      final dirPath = p.join(tempDir.path, 'logs');
      RepoUtils.ensureSafeDirectory(dirPath);
      expect(Directory(dirPath).existsSync(), isTrue);
      expect(RepoUtils.isSymlinkPath(dirPath), isFalse);
    });

    test('writeFileSafely writes to a normal file path', () {
      final filePath = p.join(tempDir.path, 'stdout.log');
      RepoUtils.writeFileSafely(filePath, 'hello world');
      expect(File(filePath).readAsStringSync(), equals('hello world'));
    });

    test('writeFileSafely appends when FileMode.append is used', () {
      final filePath = p.join(tempDir.path, 'stdout.log');
      RepoUtils.writeFileSafely(filePath, 'hello');
      RepoUtils.writeFileSafely(filePath, ' world', mode: FileMode.append);
      expect(File(filePath).readAsStringSync(), equals('hello world'));
    });

    test(
      'ensureSafeDirectory rejects symlink-backed directories',
      skip: !symlinksSupported,
      () {
        final targetDir = Directory(p.join(tempDir.path, 'target'))
          ..createSync(recursive: true);
        final linkDirPath = p.join(tempDir.path, 'linked');
        Link(linkDirPath).createSync(targetDir.path);
        expect(
          () => RepoUtils.ensureSafeDirectory(linkDirPath),
          throwsA(isA<FileSystemException>()),
        );
      },
    );

    test(
      'writeFileSafely rejects symlink file targets',
      skip: !symlinksSupported,
      () {
        final targetFile = File(p.join(tempDir.path, 'target.txt'))
          ..writeAsStringSync('base');
        final linkPath = p.join(tempDir.path, 'linked.txt');
        Link(linkPath).createSync(targetFile.path);
        expect(
          () => RepoUtils.writeFileSafely(linkPath, 'new content'),
          throwsA(isA<FileSystemException>()),
        );
      },
    );
  });

  group('TestResultsUtil.parseTestResultsJson', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('test_results_parse_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('returns unparsed empty results when file does not exist', () {
      final missingPath = p.join(tempDir.path, 'missing.json');
      final results = TestResultsUtil.parseTestResultsJson(missingPath);
      expect(results.parsed, isFalse);
      expect(results.passed, equals(0));
      expect(results.failed, equals(0));
      expect(results.skipped, equals(0));
      expect(results.failures, isEmpty);
    });

    test('returns unparsed results when NDJSON file is empty', () {
      final jsonPath = p.join(tempDir.path, 'empty.json');
      File(jsonPath).writeAsStringSync('');
      final results = TestResultsUtil.parseTestResultsJson(jsonPath);
      expect(results.parsed, isFalse);
      expect(results.passed, equals(0));
      expect(results.failed, equals(0));
      expect(results.skipped, equals(0));
      expect(results.failures, isEmpty);
    });

    test('returns unparsed results when NDJSON file has only blank lines', () {
      final jsonPath = p.join(tempDir.path, 'blank.json');
      File(jsonPath).writeAsStringSync('\n  \n\t\n');
      final results = TestResultsUtil.parseTestResultsJson(jsonPath);
      expect(results.parsed, isFalse);
      expect(results.passed, equals(0));
      expect(results.failed, equals(0));
      expect(results.skipped, equals(0));
      expect(results.failures, isEmpty);
    });

    test(
      'returns unparsed results when file has valid JSON but no structured events',
      () {
        final jsonPath = p.join(tempDir.path, 'no_events.json');
        File(
          jsonPath,
        ).writeAsStringSync('{"type":"unknown","data":1}\n{"other":"value"}\n');
        final results = TestResultsUtil.parseTestResultsJson(jsonPath);
        expect(results.parsed, isFalse);
        expect(results.passed, equals(0));
        expect(results.failed, equals(0));
        expect(results.skipped, equals(0));
        expect(results.failures, isEmpty);
      },
    );

    test('parses pass/fail/skipped counts and failure details', () {
      final jsonPath = p.join(tempDir.path, 'results.json');
      File(jsonPath).writeAsStringSync(
        [
          '{"type":"testStart","test":{"id":1,"name":"passes"},"time":100}',
          '{"type":"testDone","testID":1,"result":"success","hidden":false,"skipped":false,"time":120}',
          '{"type":"testStart","test":{"id":2,"name":"fails"},"time":130}',
          '{"type":"print","testID":2,"message":"hello from test"}',
          '{"type":"error","testID":2,"error":"boom","stackTrace":"trace line"}',
          '{"type":"testDone","testID":2,"result":"failure","hidden":false,"skipped":false,"time":170}',
          '{"type":"testStart","test":{"id":3,"name":"skipped"},"time":180}',
          '{"type":"testDone","testID":3,"result":"success","hidden":false,"skipped":true,"time":190}',
          '{"type":"done","time":200}',
        ].join('\n'),
      );

      final results = TestResultsUtil.parseTestResultsJson(jsonPath);
      expect(results.parsed, isTrue);
      expect(results.passed, equals(1));
      expect(results.failed, equals(1));
      expect(results.skipped, equals(1));
      expect(results.totalDurationMs, equals(200));
      expect(results.failures, hasLength(1));
      expect(results.failures.first.name, equals('fails'));
      expect(results.failures.first.error, contains('boom'));
      expect(results.failures.first.stackTrace, contains('trace line'));
      expect(results.failures.first.printOutput, contains('hello from test'));
      expect(results.failures.first.durationMs, equals(40));
    });

    test('caps failures list at 50 to prevent unbounded growth', () {
      final lines = <String>[];
      for (var i = 0; i < 60; i++) {
        lines.addAll([
          '{"type":"testStart","test":{"id":$i,"name":"fail_$i"},"time":${i * 2}}',
          '{"type":"testDone","testID":$i,"result":"failure","hidden":false,"skipped":false,"time":${i * 2 + 1}}',
        ]);
      }
      lines.add('{"type":"done","time":200}');
      final jsonPath = p.join(tempDir.path, 'many_failures.json');
      File(jsonPath).writeAsStringSync(lines.join('\n'));

      final results = TestResultsUtil.parseTestResultsJson(jsonPath);
      expect(results.failed, equals(60));
      expect(results.failures.length, lessThanOrEqualTo(50));
    });

    test('ignores malformed JSON lines and hidden test entries', () {
      final jsonPath = p.join(tempDir.path, 'results.json');
      File(jsonPath).writeAsStringSync(
        [
          '{"type":"testStart","test":{"id":10,"name":"hidden fail"},"time":10}',
          '{bad json line',
          '{"type":"error","testID":10,"error":"hidden boom","stackTrace":"hidden trace"}',
          '{"type":"testDone","testID":10,"result":"failure","hidden":true,"skipped":false,"time":20}',
          '{"type":"testStart","test":{"id":11,"name":"visible pass"},"time":21}',
          '{"type":"testDone","testID":11,"result":"success","hidden":false,"skipped":false,"time":30}',
          '{"type":"done","time":30}',
        ].join('\n'),
      );

      final results = TestResultsUtil.parseTestResultsJson(jsonPath);
      expect(results.parsed, isTrue);
      expect(results.passed, equals(1));
      expect(results.failed, equals(0));
      expect(results.failures, isEmpty);
    });

    test('malformed JSON circuit breaker limits warning flood', () {
      final jsonPath = p.join(tempDir.path, 'flood.json');
      final lines = <String>[
        '{"type":"testStart","test":{"id":1,"name":"ok"},"time":0}',
        ...List.generate(10, (_) => '{invalid'),
        '{"type":"testDone","testID":1,"result":"success","hidden":false,"skipped":false,"time":10}',
        '{"type":"done","time":10}',
      ];
      File(jsonPath).writeAsStringSync(lines.join('\n'));

      final results = TestResultsUtil.parseTestResultsJson(jsonPath);
      expect(results.parsed, isTrue);
      expect(results.passed, equals(1));
    });

    test('truncates stored failure details to prevent unbounded growth', () {
      final longError = 'x' * 12000;
      final longStack = 'y' * 10000;
      final longPrint = 'z' * 8000;
      final jsonPath = p.join(tempDir.path, 'huge.json');
      File(jsonPath).writeAsStringSync(
        [
          '{"type":"testStart","test":{"id":1,"name":"huge"},"time":0}',
          '{"type":"error","testID":1,"error":"$longError","stackTrace":"$longStack"}',
          '{"type":"print","testID":1,"message":"$longPrint"}',
          '{"type":"testDone","testID":1,"result":"failure","hidden":false,"skipped":false,"time":100}',
          '{"type":"done","time":100}',
        ].join('\n'),
      );

      final results = TestResultsUtil.parseTestResultsJson(jsonPath);
      expect(results.failures, hasLength(1));
      expect(results.failures.first.error.length, lessThan(10000));
      expect(results.failures.first.error, contains('(truncated)'));
      expect(results.failures.first.stackTrace.length, lessThan(7000));
      expect(results.failures.first.stackTrace, contains('(truncated)'));
      expect(results.failures.first.printOutput.length, lessThan(7000));
      expect(results.failures.first.printOutput, contains('(truncated)'));
    });
  });

  group('TestResultsUtil.writeTestJobSummary', () {
    TestResults _parsed({
      required int passed,
      required int failed,
      required int skipped,
      int durationMs = 500,
    }) {
      final results = TestResults()
        ..parsed = true
        ..passed = passed
        ..failed = failed
        ..skipped = skipped
        ..totalDurationMs = durationMs;
      return results;
    }

    test(
      'emits NOTE when parsed results are successful and exit code is 0',
      () {
        String? summary;
        final results = _parsed(passed: 3, failed: 0, skipped: 1);

        TestResultsUtil.writeTestJobSummary(
          results,
          0,
          platformId: 'linux-x64',
          writeSummary: (markdown) => summary = markdown,
        );

        expect(summary, isNotNull);
        expect(summary!, contains('## Test Results — linux-x64'));
        expect(summary!, contains('> [!NOTE]'));
        expect(summary!, contains('All 4 tests passed'));
      },
    );

    test(
      'emits CAUTION when exit code is non-zero even if failed count is zero',
      () {
        String? summary;
        final results = _parsed(passed: 2, failed: 0, skipped: 0);

        TestResultsUtil.writeTestJobSummary(
          results,
          1,
          platformId: 'linux <x64>',
          writeSummary: (markdown) => summary = markdown,
        );

        expect(summary, isNotNull);
        expect(summary!, contains('## Test Results — linux &lt;x64&gt;'));
        expect(summary!, contains('> [!CAUTION]'));
        expect(
          summary!,
          contains(
            'Tests exited with code 1 despite no structured test failures.',
          ),
        );
      },
    );

    test('emits CAUTION for unparsed results with non-zero exit code', () {
      String? summary;
      final results = TestResults(); // parsed=false by default

      TestResultsUtil.writeTestJobSummary(
        results,
        7,
        platformId: 'runner',
        writeSummary: (markdown) => summary = markdown,
      );

      expect(summary, isNotNull);
      expect(summary!, contains('> [!CAUTION]'));
      expect(
        summary!,
        contains(
          'Tests failed (exit code 7) — no structured results available.',
        ),
      );
    });

    test('emits NOTE for unparsed results with zero exit code', () {
      String? summary;
      final results = TestResults(); // parsed=false by default

      TestResultsUtil.writeTestJobSummary(
        results,
        0,
        platformId: 'runner',
        writeSummary: (markdown) => summary = markdown,
      );

      expect(summary, isNotNull);
      expect(summary!, contains('> [!NOTE]'));
      expect(
        summary!,
        contains(
          'Tests passed (exit code 0) — no structured results available.',
        ),
      );
    });

    test('emits CAUTION when parsed results contain failures', () {
      String? summary;
      final results = _parsed(passed: 1, failed: 1, skipped: 0);
      results.failures.add(
        TestFailure(
          name: 'failing test',
          error: 'boom',
          stackTrace: 'trace',
          printOutput: '',
          durationMs: 12,
        ),
      );

      TestResultsUtil.writeTestJobSummary(
        results,
        0,
        platformId: 'linux',
        writeSummary: (markdown) => summary = markdown,
      );

      expect(summary, isNotNull);
      expect(summary!, contains('> [!CAUTION]'));
      expect(summary!, contains('1 of 2 tests failed'));
      expect(summary!, contains('### Failed Tests'));
      expect(summary!, contains('failing test'));
    });

    test('truncates failure details after 20 entries in summary', () {
      String? summary;
      final results = _parsed(passed: 0, failed: 25, skipped: 0);
      for (var i = 0; i < 25; i++) {
        results.failures.add(
          TestFailure(
            name: 'failing test $i',
            error: 'boom $i',
            stackTrace: 'trace $i',
            printOutput: '',
            durationMs: i,
          ),
        );
      }

      TestResultsUtil.writeTestJobSummary(
        results,
        1,
        platformId: 'linux',
        writeSummary: (markdown) => summary = markdown,
      );

      expect(summary, isNotNull);
      expect(
        summary!,
        contains(
          '_...and 5 more failures. See test logs artifact for full details._',
        ),
      );
      expect(summary!, isNot(contains('failing test 24')));
    });

    test('escapes unsafe HTML in failure content (closing tags, etc.)', () {
      String? summary;
      final results = _parsed(passed: 0, failed: 1, skipped: 0);
      results.failures.add(
        TestFailure(
          name: 'test with </details>',
          error: 'Error: </details><script>alert(1)</script>',
          stackTrace: '<summary>fake</summary>',
          printOutput: '',
          durationMs: 0,
        ),
      );

      TestResultsUtil.writeTestJobSummary(
        results,
        1,
        platformId: 'linux',
        writeSummary: (markdown) => summary = markdown,
      );

      expect(summary, isNotNull);
      expect(summary!, contains('&lt;/details&gt;'));
      expect(summary!, contains('&lt;script&gt;'));
      expect(summary!, contains('&lt;summary&gt;'));
      expect(summary!, isNot(contains('<script>alert(1)</script>')));
    });

    test('handles adversarial backtick content in failure output', () {
      String? summary;
      final results = _parsed(passed: 0, failed: 1, skipped: 0);
      results.failures.add(
        TestFailure(
          name: 'backtick test',
          error: '```' * 10 + 'content' + '```' * 10,
          stackTrace: '',
          printOutput: '',
          durationMs: 0,
        ),
      );

      TestResultsUtil.writeTestJobSummary(
        results,
        1,
        platformId: 'linux',
        writeSummary: (markdown) => summary = markdown,
      );

      expect(summary, isNotNull);
      expect(summary!, contains('### Failed Tests'));
      expect(summary!, contains('backtick test'));
      // Fence should be longer than content's backticks; output should be valid
      expect(summary!.split('```').length, greaterThan(2));
    });
  });

  group('StepSummary', () {
    test('write uses byte size not char size for limit guard', () {
      // GitHub step summary limit is 1 MiB; guard must use UTF-8 byte count.
      // Multi-byte chars (e.g. 語) have more bytes than chars — old bug used
      // markdown.length (chars) and could overflow.
      late Directory tempDir;
      tempDir = Directory.systemTemp.createTempSync('step_summary_bytes_');
      try {
        final summaryPath = p.join(tempDir.path, 'summary.md');
        const maxBytes = (1024 * 1024) - (4 * 1024);
        // Fill to maxBytes - 2 so that "語" (3 bytes) would exceed
        File(summaryPath).writeAsStringSync('x' * (maxBytes - 2));
        expect(File(summaryPath).lengthSync(), equals(maxBytes - 2));

        StepSummary.write(
          '語',
          environment: {'GITHUB_STEP_SUMMARY': summaryPath},
        );
        // Should skip append (would exceed); file size unchanged
        expect(File(summaryPath).lengthSync(), equals(maxBytes - 2));
      } finally {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      }
    });

    test('collapsible escapes content to prevent HTML injection', () {
      final out = StepSummary.collapsible(
        'Title</summary><script>evil</script>',
        'Content with </details> and <img src=x onerror=alert(1)>',
      );
      expect(out, contains('&lt;/summary&gt;'));
      expect(out, contains('&lt;script&gt;'));
      expect(out, contains('&lt;/details&gt;'));
      expect(out, contains('&lt;img'));
      expect(out, isNot(contains('<script>evil</script>')));
      expect(out, contains('<details>'));
      expect(out, contains('</details>'));
    });
  });

  group('SubPackageUtils.loadSubPackages', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('sub_pkg_load_');
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    void _writeConfig(Map<String, dynamic> ci) {
      final configDir = Directory('${tempDir.path}/.runtime_ci')..createSync();
      File(
        '${configDir.path}/config.json',
      ).writeAsStringSync(json.encode({'ci': ci}));
    }

    test('returns empty when no sub_packages', () {
      _writeConfig({'dart_sdk': '3.9.2', 'features': {}});
      expect(SubPackageUtils.loadSubPackages(tempDir.path), isEmpty);
    });

    test('valid sub-packages pass through', () {
      _writeConfig({
        'dart_sdk': '3.9.2',
        'features': {},
        'sub_packages': [
          {'name': 'core', 'path': 'packages/core'},
          {'name': 'api', 'path': 'packages/api'},
        ],
      });
      final result = SubPackageUtils.loadSubPackages(tempDir.path);
      expect(result.length, equals(2));
      expect(result[0]['name'], equals('core'));
      expect(result[0]['path'], equals('packages/core'));
      expect(result[1]['name'], equals('api'));
      expect(result[1]['path'], equals('packages/api'));
    });

    test('skips invalid name (unsupported chars)', () {
      _writeConfig({
        'dart_sdk': '3.9.2',
        'features': {},
        'sub_packages': [
          {'name': 'foo bar', 'path': 'packages/foo'},
        ],
      });
      final result = SubPackageUtils.loadSubPackages(tempDir.path);
      expect(result, isEmpty);
    });

    test('skips invalid path (traversal)', () {
      _writeConfig({
        'dart_sdk': '3.9.2',
        'features': {},
        'sub_packages': [
          {'name': 'evil', 'path': '../../../etc/passwd'},
        ],
      });
      final result = SubPackageUtils.loadSubPackages(tempDir.path);
      expect(result, isEmpty);
    });

    test('skips invalid path (absolute)', () {
      _writeConfig({
        'dart_sdk': '3.9.2',
        'features': {},
        'sub_packages': [
          {'name': 'foo', 'path': '/usr/local'},
        ],
      });
      final result = SubPackageUtils.loadSubPackages(tempDir.path);
      expect(result, isEmpty);
    });

    test('skips invalid path (leading dash)', () {
      _writeConfig({
        'dart_sdk': '3.9.2',
        'features': {},
        'sub_packages': [
          {'name': 'foo', 'path': '--help'},
        ],
      });
      final result = SubPackageUtils.loadSubPackages(tempDir.path);
      expect(result, isEmpty);
    });

    test('valid entries pass when mixed with invalid', () {
      _writeConfig({
        'dart_sdk': '3.9.2',
        'features': {},
        'sub_packages': [
          {'name': 'bad', 'path': '../../../etc'},
          {'name': 'good', 'path': 'packages/good'},
        ],
      });
      final result = SubPackageUtils.loadSubPackages(tempDir.path);
      expect(result.length, equals(1));
      expect(result[0]['name'], equals('good'));
      expect(result[0]['path'], equals('packages/good'));
    });
  });

  group('CiProcessRunner.exec', () {
    test('fatal path exits with process exit code after flushing stdout/stderr',
        () async {
      final scriptPath = p.join(
        p.current,
        'test',
        'scripts',
        'fatal_exit_probe.dart',
      );
      final result = Process.runSync(
        Platform.resolvedExecutable,
        ['run', scriptPath],
        runInShell: false,
      );
      final expectedCode = Platform.isWindows ? 7 : 1;
      expect(result.exitCode, equals(expectedCode),
          reason: 'fatal exec should exit with failing command exit code');
    });
  });

  group('CiProcessRunner.runWithTimeout', () {
    test('completes normally when process finishes within timeout', () async {
      final result = await CiProcessRunner.runWithTimeout(
        Platform.resolvedExecutable,
        ['--version'],
        timeout: const Duration(seconds: 10),
      );
      expect(result.exitCode, equals(0));
      expect(result.stdout, contains('Dart'));
    });

    test(
      'returns timeout result and kills process when timeout exceeded',
      () async {
        final executable = Platform.isWindows ? 'ping' : 'sleep';
        final args = Platform.isWindows ? ['127.0.0.1', '-n', '60'] : ['60'];
        final result = await CiProcessRunner.runWithTimeout(
          executable,
          args,
          timeout: const Duration(milliseconds: 500),
          timeoutExitCode: 124,
          timeoutMessage: 'Timed out',
        );
        expect(result.exitCode, equals(124));
        expect(result.stderr, equals('Timed out'));
      },
    );
  });
}
