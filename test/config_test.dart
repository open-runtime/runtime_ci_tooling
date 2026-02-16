import 'package:test/test.dart';

import 'package:runtime_ci_tooling/src/triage/utils/config.dart';

void main() {
  group('TriageConfig', () {
    test('kConfigFileName points to .runtime_ci/config.json', () {
      expect(kConfigFileName, equals('.runtime_ci/config.json'));
    });

    test('kLegacyConfigPaths includes backward-compatible paths', () {
      expect(kLegacyConfigPaths, contains('runtime.ci.config.json'));
      expect(kLegacyConfigPaths, contains('scripts/triage/triage_config.json'));
      expect(kLegacyConfigPaths, contains('triage_config.json'));
    });

    test('config singleton loads without crashing when no config file exists', () {
      reloadConfig();
      expect(config, isNotNull);
      expect(config.isConfigured, isFalse);
    });
  });
}
