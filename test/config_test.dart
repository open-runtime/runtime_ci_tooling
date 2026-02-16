import 'dart:io';

import 'package:test/test.dart';

import 'package:runtime_ci_tooling/src/triage/utils/config.dart';
import 'package:runtime_ci_tooling/src/triage/utils/run_context.dart';

void main() {
  group('Constants', () {
    test('kConfigFileName points to .runtime_ci/config.json', () {
      expect(kConfigFileName, equals('.runtime_ci/config.json'));
    });

    test('kLegacyConfigPaths includes backward-compatible paths', () {
      expect(kLegacyConfigPaths, contains('runtime.ci.config.json'));
      expect(kLegacyConfigPaths, contains('scripts/triage/triage_config.json'));
      expect(kLegacyConfigPaths, contains('triage_config.json'));
    });

    test('kRuntimeCiDir is .runtime_ci', () {
      expect(kRuntimeCiDir, equals('.runtime_ci'));
    });

    test('run/audit/release/version paths nest under .runtime_ci', () {
      expect(kCicdRunsDir, startsWith('$kRuntimeCiDir/'));
      expect(kCicdAuditDir, startsWith('$kRuntimeCiDir/'));
      expect(kReleaseNotesDir, startsWith('$kRuntimeCiDir/'));
      expect(kVersionBumpsDir, startsWith('$kRuntimeCiDir/'));
    });
  });

  group('TriageConfig', () {
    test('config singleton loads without crashing', () {
      reloadConfig();
      expect(config, isNotNull);
    });

    test('reloadConfig replaces the singleton', () {
      reloadConfig();
      final first = config;
      reloadConfig();
      final second = config;
      expect(identical(first, second), isFalse);
    });

    test('config loads .runtime_ci/config.json from this repo', () {
      reloadConfig();
      // This repo ships with .runtime_ci/config.json, so it should be found
      // whether tests are run from the repo root or from the monorepo root.
      final configFile = File('.runtime_ci/config.json');
      if (configFile.existsSync()) {
        expect(config.isConfigured, isTrue);
        expect(config.loadedFrom, isNotNull);
        expect(config.repoName, equals('runtime_ci_tooling'));
        expect(config.repoOwner, equals('open-runtime'));
      }
    });

    test('gcpProject reads gcp.project from config', () {
      reloadConfig();
      if (config.isConfigured) {
        // This repo's config sets gcp.project to global-cloud-runtime
        expect(config.gcpProject, equals('global-cloud-runtime'));
      }
    });

    test('default label lists are non-empty', () {
      reloadConfig();
      expect(config.typeLabels, isNotEmpty);
      expect(config.priorityLabels, isNotEmpty);
    });

    test('default thresholds are sensible', () {
      reloadConfig();
      expect(config.autoCloseThreshold, greaterThan(0));
      expect(config.autoCloseThreshold, lessThanOrEqualTo(1));
      expect(config.suggestCloseThreshold, lessThan(config.autoCloseThreshold));
      expect(config.commentThreshold, lessThan(config.suggestCloseThreshold));
    });

    test('default Gemini model names are non-empty', () {
      reloadConfig();
      expect(config.flashModel, isNotEmpty);
      expect(config.proModel, isNotEmpty);
    });

    test('enabledAgents defaults include core agents', () {
      reloadConfig();
      expect(config.enabledAgents, contains('code_analysis'));
      expect(config.enabledAgents, contains('duplicate'));
    });
  });
}
