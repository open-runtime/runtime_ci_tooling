import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'package:runtime_ci_tooling/src/cli/utils/workflow_generator.dart';

/// Helper: build a minimal valid CI config map.
Map<String, dynamic> _validConfig({
  String dartSdk = '3.9.2',
  Map<String, dynamic>? features,
  List<String>? platforms,
  Map<String, dynamic>? secrets,
  String? pat,
  dynamic lineLength,
  List<dynamic>? subPackages,
  Map<String, dynamic>? runnerOverrides,
}) {
  return <String, dynamic>{
    'dart_sdk': dartSdk,
    'features': features ?? <String, dynamic>{'proto': false, 'lfs': false},
    if (platforms != null) 'platforms': platforms,
    if (secrets != null) 'secrets': secrets,
    if (pat != null) 'personal_access_token_secret': pat,
    if (lineLength != null) 'line_length': lineLength,
    if (subPackages != null) 'sub_packages': subPackages,
    if (runnerOverrides != null) 'runner_overrides': runnerOverrides,
  };
}

void main() {
  // ===========================================================================
  // P0: validate() tests
  // ===========================================================================
  group('WorkflowGenerator.validate()', () {
    // ---- dart_sdk ----
    group('dart_sdk', () {
      test('missing dart_sdk produces error', () {
        final errors = WorkflowGenerator.validate({'features': <String, dynamic>{}});
        expect(errors, contains('ci.dart_sdk is required'));
      });

      test('null dart_sdk produces error', () {
        final errors = WorkflowGenerator.validate({
          'dart_sdk': null,
          'features': <String, dynamic>{},
        });
        expect(errors, contains('ci.dart_sdk is required'));
      });

      test('non-string dart_sdk produces error', () {
        final errors = WorkflowGenerator.validate({
          'dart_sdk': 42,
          'features': <String, dynamic>{},
        });
        expect(errors, anyElement(contains('must be a string')));
      });

      test('empty-string dart_sdk produces error', () {
        final errors = WorkflowGenerator.validate({
          'dart_sdk': '',
          'features': <String, dynamic>{},
        });
        expect(errors, anyElement(contains('non-empty')));
      });

      test('whitespace-only dart_sdk produces error', () {
        final errors = WorkflowGenerator.validate({
          'dart_sdk': '  ',
          'features': <String, dynamic>{},
        });
        // After trim the string is empty
        expect(errors, anyElement(contains('non-empty')));
      });

      test('dart_sdk with leading/trailing whitespace produces error', () {
        final errors = WorkflowGenerator.validate({
          'dart_sdk': ' 3.9.2 ',
          'features': <String, dynamic>{},
        });
        expect(errors, anyElement(contains('whitespace')));
      });

      test('dart_sdk with trailing newline triggers whitespace error', () {
        // A trailing \n makes trimmed != sdk, so the whitespace check fires first.
        final errors = WorkflowGenerator.validate({
          'dart_sdk': '3.9.2\n',
          'features': <String, dynamic>{},
        });
        expect(errors, anyElement(contains('whitespace')));
      });

      test('dart_sdk with embedded tab (after trim is identity) triggers newlines/tabs error', () {
        // A tab in the middle: trim() has no effect but the regex catches it.
        final errors = WorkflowGenerator.validate({
          'dart_sdk': '3.9\t.2',
          'features': <String, dynamic>{},
        });
        expect(errors, anyElement(contains('newlines/tabs')));
      });

      test('valid semver dart_sdk passes', () {
        final errors = WorkflowGenerator.validate(_validConfig(dartSdk: '3.9.2'));
        expect(errors.where((e) => e.contains('dart_sdk')), isEmpty);
      });

      test('valid semver with pre-release passes', () {
        final errors = WorkflowGenerator.validate(_validConfig(dartSdk: '3.10.0-beta.1'));
        expect(errors.where((e) => e.contains('dart_sdk')), isEmpty);
      });

      test('channel "stable" passes', () {
        final errors = WorkflowGenerator.validate(_validConfig(dartSdk: 'stable'));
        expect(errors.where((e) => e.contains('dart_sdk')), isEmpty);
      });

      test('channel "beta" passes', () {
        final errors = WorkflowGenerator.validate(_validConfig(dartSdk: 'beta'));
        expect(errors.where((e) => e.contains('dart_sdk')), isEmpty);
      });

      test('channel "dev" passes', () {
        final errors = WorkflowGenerator.validate(_validConfig(dartSdk: 'dev'));
        expect(errors.where((e) => e.contains('dart_sdk')), isEmpty);
      });

      test('invalid dart_sdk like "latest" produces error', () {
        final errors = WorkflowGenerator.validate(_validConfig(dartSdk: 'latest'));
        expect(errors, anyElement(contains('channel')));
      });

      test('invalid dart_sdk like "3.9" (not full semver) produces error', () {
        final errors = WorkflowGenerator.validate(_validConfig(dartSdk: '3.9'));
        expect(errors, anyElement(contains('channel')));
      });
    });

    // ---- features ----
    group('features', () {
      test('missing features produces error', () {
        final errors = WorkflowGenerator.validate({'dart_sdk': '3.9.2'});
        expect(errors, contains('ci.features is required'));
      });

      test('non-map features produces error', () {
        final errors = WorkflowGenerator.validate({
          'dart_sdk': '3.9.2',
          'features': 'not_a_map',
        });
        expect(errors, anyElement(contains('features must be an object')));
      });

      test('features with non-bool value produces error', () {
        final errors = WorkflowGenerator.validate({
          'dart_sdk': '3.9.2',
          'features': <String, dynamic>{'proto': 'yes'},
        });
        expect(errors, anyElement(contains('must be a bool')));
      });

      test('features with unknown key (typo) produces error', () {
        final errors = WorkflowGenerator.validate({
          'dart_sdk': '3.9.2',
          'features': <String, dynamic>{'prto': true}, // typo of 'proto'
        });
        expect(errors, anyElement(contains('unknown key "prto"')));
      });

      test('all known feature keys pass validation', () {
        final errors = WorkflowGenerator.validate(_validConfig(
          features: {
            'proto': true,
            'lfs': false,
            'format_check': true,
            'analysis_cache': false,
            'managed_analyze': true,
            'managed_test': false,
            'build_runner': true,
          },
        ));
        expect(errors.where((e) => e.contains('features')), isEmpty);
      });

      test('empty features map passes (no keys required)', () {
        final errors = WorkflowGenerator.validate(_validConfig(features: {}));
        expect(errors.where((e) => e.contains('features')), isEmpty);
      });
    });

    // ---- platforms ----
    group('platforms', () {
      test('non-list platforms produces error', () {
        final errors = WorkflowGenerator.validate(_validConfig(platforms: null)..['platforms'] = 'ubuntu');
        expect(errors, anyElement(contains('platforms must be an array')));
      });

      test('unknown platform entry produces error', () {
        final errors = WorkflowGenerator.validate(_validConfig(platforms: ['ubuntu', 'solaris']));
        expect(errors, anyElement(contains('invalid platform "solaris"')));
      });

      test('non-string platform entry produces error', () {
        final config = _validConfig();
        config['platforms'] = [42];
        final errors = WorkflowGenerator.validate(config);
        expect(errors, anyElement(contains('invalid platform')));
      });

      test('valid single platform passes', () {
        final errors = WorkflowGenerator.validate(_validConfig(platforms: ['ubuntu']));
        expect(errors.where((e) => e.contains('platforms')), isEmpty);
      });

      test('valid multi-platform passes', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(platforms: ['ubuntu', 'macos', 'windows']),
        );
        expect(errors.where((e) => e.contains('platforms')), isEmpty);
      });

      test('omitted platforms (null) does not produce error', () {
        final errors = WorkflowGenerator.validate(_validConfig());
        expect(errors.where((e) => e.contains('platforms')), isEmpty);
      });
    });

    // ---- secrets ----
    group('secrets', () {
      test('non-map secrets produces error', () {
        final config = _validConfig();
        config['secrets'] = 'not_a_map';
        final errors = WorkflowGenerator.validate(config);
        expect(errors, anyElement(contains('secrets must be an object')));
      });

      test('null secrets is fine (optional)', () {
        final errors = WorkflowGenerator.validate(_validConfig());
        expect(errors.where((e) => e.contains('secrets')), isEmpty);
      });

      test('valid secrets map passes', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(secrets: {'API_KEY': 'SOME_SECRET'}),
        );
        expect(errors.where((e) => e.contains('secrets')), isEmpty);
      });
    });

    // ---- personal_access_token_secret ----
    group('personal_access_token_secret', () {
      test('non-string pat produces error', () {
        final config = _validConfig();
        config['personal_access_token_secret'] = 123;
        final errors = WorkflowGenerator.validate(config);
        expect(errors, anyElement(contains('personal_access_token_secret')));
      });

      test('empty pat produces error', () {
        final errors = WorkflowGenerator.validate(_validConfig(pat: ''));
        expect(errors, anyElement(contains('personal_access_token_secret')));
      });

      test('valid pat passes', () {
        final errors = WorkflowGenerator.validate(_validConfig(pat: 'MY_PAT'));
        expect(errors.where((e) => e.contains('personal_access_token_secret')), isEmpty);
      });

      test('null pat is fine (optional, defaults to GITHUB_TOKEN)', () {
        final errors = WorkflowGenerator.validate(_validConfig());
        expect(errors.where((e) => e.contains('personal_access_token_secret')), isEmpty);
      });
    });

    // ---- line_length ----
    group('line_length', () {
      test('non-numeric line_length produces error', () {
        final errors = WorkflowGenerator.validate(_validConfig(lineLength: true));
        expect(errors, anyElement(contains('line_length')));
      });

      test('int line_length passes', () {
        final errors = WorkflowGenerator.validate(_validConfig(lineLength: 80));
        expect(errors.where((e) => e.contains('line_length')), isEmpty);
      });

      test('string line_length passes', () {
        final errors = WorkflowGenerator.validate(_validConfig(lineLength: '120'));
        expect(errors.where((e) => e.contains('line_length')), isEmpty);
      });

      test('null line_length is fine (optional)', () {
        final errors = WorkflowGenerator.validate(_validConfig());
        expect(errors.where((e) => e.contains('line_length')), isEmpty);
      });
    });

    // ---- sub_packages (Issue #9 validation) ----
    group('sub_packages', () {
      test('non-list sub_packages produces error', () {
        final config = _validConfig();
        config['sub_packages'] = 'not_a_list';
        final errors = WorkflowGenerator.validate(config);
        expect(errors, anyElement(contains('sub_packages must be an array')));
      });

      test('sub_packages entry that is not a map produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(subPackages: ['just_a_string']),
        );
        expect(errors, anyElement(contains('sub_packages entries must be objects')));
      });

      test('sub_packages with missing name produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(subPackages: [
            <String, dynamic>{'path': 'packages/foo'},
          ]),
        );
        expect(errors, anyElement(contains('name must be a non-empty string')));
      });

      test('sub_packages with empty name produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(subPackages: [
            <String, dynamic>{'name': '', 'path': 'packages/foo'},
          ]),
        );
        expect(errors, anyElement(contains('name must be a non-empty string')));
      });

      test('sub_packages with missing path produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(subPackages: [
            <String, dynamic>{'name': 'foo'},
          ]),
        );
        expect(errors, anyElement(contains('path must be a non-empty string')));
      });

      test('sub_packages with empty path produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(subPackages: [
            <String, dynamic>{'name': 'foo', 'path': ''},
          ]),
        );
        expect(errors, anyElement(contains('path must be a non-empty string')));
      });

      test('sub_packages path with directory traversal (..) produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(subPackages: [
            <String, dynamic>{'name': 'foo', 'path': '../../../etc/passwd'},
          ]),
        );
        expect(errors, anyElement(contains('must not traverse outside the repo')));
      });

      test('sub_packages path with embedded traversal produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(subPackages: [
            <String, dynamic>{'name': 'foo', 'path': 'packages/../../../etc'},
          ]),
        );
        expect(errors, anyElement(contains('must not traverse outside the repo')));
      });

      test('sub_packages absolute path produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(subPackages: [
            <String, dynamic>{'name': 'foo', 'path': '/usr/local/bin'},
          ]),
        );
        expect(errors, anyElement(contains('must be a relative repo path')));
      });

      test('sub_packages path starting with ~ produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(subPackages: [
            <String, dynamic>{'name': 'foo', 'path': '~/evil'},
          ]),
        );
        expect(errors, anyElement(contains('must be a relative repo path')));
      });

      test('sub_packages path with backslashes produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(subPackages: [
            <String, dynamic>{'name': 'foo', 'path': r'packages\foo'},
          ]),
        );
        expect(errors, anyElement(contains('forward slashes')));
      });

      test('sub_packages path with unsupported characters produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(subPackages: [
            <String, dynamic>{'name': 'foo', 'path': 'packages/foo bar'},
          ]),
        );
        expect(errors, anyElement(contains('unsupported characters')));
      });

      test('sub_packages path with leading/trailing whitespace produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(subPackages: [
            <String, dynamic>{'name': 'foo', 'path': ' packages/foo '},
          ]),
        );
        expect(errors, anyElement(contains('whitespace')));
      });

      test('sub_packages path with trailing tab triggers whitespace error', () {
        // Trailing \t means trimmed != value, so the whitespace check fires first.
        final errors = WorkflowGenerator.validate(
          _validConfig(subPackages: [
            <String, dynamic>{'name': 'foo', 'path': 'packages/foo\t'},
          ]),
        );
        expect(errors, anyElement(contains('whitespace')));
      });

      test('sub_packages path with embedded tab triggers newlines/tabs error', () {
        // Embedded tab: trim() is identity, so newlines/tabs check catches it.
        final errors = WorkflowGenerator.validate(
          _validConfig(subPackages: [
            <String, dynamic>{'name': 'foo', 'path': 'packages/f\too'},
          ]),
        );
        expect(errors, anyElement(contains('newlines/tabs')));
      });

      test('sub_packages duplicate name produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(subPackages: [
            <String, dynamic>{'name': 'foo', 'path': 'packages/foo'},
            <String, dynamic>{'name': 'foo', 'path': 'packages/bar'},
          ]),
        );
        expect(errors, anyElement(contains('duplicate name "foo"')));
      });

      test('sub_packages duplicate path (after normalization) produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(subPackages: [
            <String, dynamic>{'name': 'foo', 'path': 'packages/foo'},
            <String, dynamic>{'name': 'bar', 'path': 'packages/./foo'},
          ]),
        );
        expect(errors, anyElement(contains('duplicate path')));
      });

      test('valid sub_packages passes', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(subPackages: [
            <String, dynamic>{'name': 'core', 'path': 'packages/core'},
            <String, dynamic>{'name': 'api', 'path': 'packages/api'},
          ]),
        );
        expect(errors.where((e) => e.contains('sub_packages')), isEmpty);
      });

      test('null sub_packages is fine (optional)', () {
        final errors = WorkflowGenerator.validate(_validConfig());
        expect(errors.where((e) => e.contains('sub_packages')), isEmpty);
      });
    });

    // ---- runner_overrides ----
    group('runner_overrides', () {
      test('non-map runner_overrides produces error', () {
        final config = _validConfig();
        config['runner_overrides'] = 'invalid';
        final errors = WorkflowGenerator.validate(config);
        expect(errors, anyElement(contains('runner_overrides must be an object')));
      });

      test('runner_overrides with invalid platform key produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(runnerOverrides: {'solaris': 'my-runner'}),
        );
        expect(errors, anyElement(contains('invalid platform key "solaris"')));
      });

      test('runner_overrides with empty string value produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(runnerOverrides: {'ubuntu': ''}),
        );
        expect(errors, anyElement(contains('must be a non-empty string')));
      });

      test('valid runner_overrides passes', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(runnerOverrides: {'ubuntu': 'custom-runner-label'}),
        );
        expect(errors.where((e) => e.contains('runner_overrides')), isEmpty);
      });
    });

    // ---- fully valid config produces no errors ----
    test('fully valid config produces no errors', () {
      final errors = WorkflowGenerator.validate(_validConfig(
        dartSdk: '3.9.2',
        features: {'proto': true, 'lfs': false},
        platforms: ['ubuntu', 'macos'],
        secrets: {'API_KEY': 'MY_SECRET'},
        pat: 'MY_PAT',
        lineLength: 120,
        subPackages: [
          <String, dynamic>{'name': 'core', 'path': 'packages/core'},
        ],
        runnerOverrides: {'ubuntu': 'custom-runner'},
      ));
      expect(errors, isEmpty);
    });

    // ---- multiple errors accumulate ----
    test('multiple errors are accumulated (not short-circuited)', () {
      final errors = WorkflowGenerator.validate(<String, dynamic>{
        // missing dart_sdk, missing features
      });
      expect(errors.length, greaterThanOrEqualTo(2));
      expect(errors, anyElement(contains('dart_sdk')));
      expect(errors, anyElement(contains('features')));
    });
  });

  // ===========================================================================
  // P0: loadCiConfig() tests
  // ===========================================================================
  group('WorkflowGenerator.loadCiConfig()', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('wf_gen_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('returns null when config.json does not exist', () {
      final result = WorkflowGenerator.loadCiConfig(tempDir.path);
      expect(result, isNull);
    });

    test('returns null when config.json exists but has no "ci" key', () {
      final configDir = Directory('${tempDir.path}/.runtime_ci')..createSync();
      File('${configDir.path}/config.json').writeAsStringSync(json.encode({
        'repo_name': 'test_repo',
      }));
      final result = WorkflowGenerator.loadCiConfig(tempDir.path);
      expect(result, isNull);
    });

    test('returns the ci map when config.json has a valid "ci" section', () {
      final configDir = Directory('${tempDir.path}/.runtime_ci')..createSync();
      File('${configDir.path}/config.json').writeAsStringSync(json.encode({
        'ci': {
          'dart_sdk': '3.9.2',
          'features': {'proto': true},
        },
      }));
      final result = WorkflowGenerator.loadCiConfig(tempDir.path);
      expect(result, isNotNull);
      expect(result, isA<Map<String, dynamic>>());
      expect(result!['dart_sdk'], equals('3.9.2'));
      expect((result['features'] as Map)['proto'], isTrue);
    });

    test('throws StateError on malformed JSON', () {
      final configDir = Directory('${tempDir.path}/.runtime_ci')..createSync();
      File('${configDir.path}/config.json').writeAsStringSync('{ not valid json');
      expect(
        () => WorkflowGenerator.loadCiConfig(tempDir.path),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('Malformed JSON'))),
      );
    });

    test('throws StateError when "ci" is not a Map', () {
      final configDir = Directory('${tempDir.path}/.runtime_ci')..createSync();
      File('${configDir.path}/config.json').writeAsStringSync(json.encode({
        'ci': 'not_a_map',
      }));
      expect(
        () => WorkflowGenerator.loadCiConfig(tempDir.path),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('object'))),
      );
    });

    test('throws StateError when "ci" is a list instead of a map', () {
      final configDir = Directory('${tempDir.path}/.runtime_ci')..createSync();
      File('${configDir.path}/config.json').writeAsStringSync(json.encode({
        'ci': [1, 2, 3],
      }));
      expect(
        () => WorkflowGenerator.loadCiConfig(tempDir.path),
        throwsA(isA<StateError>()),
      );
    });
  });
}
