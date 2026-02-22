import 'package:test/test.dart';

import 'package:runtime_ci_tooling/src/cli/commands/consumers_command.dart';

void main() {
  group('computeNextDiscoveryIndexFromNames', () {
    test('returns 1 when no discovery files exist', () {
      final next = ConsumersCommand.computeNextDiscoveryIndexFromNames(const []);
      expect(next, equals(1));
    });

    test('ignores non-matching files and increments max index', () {
      final next = ConsumersCommand.computeNextDiscoveryIndexFromNames(const [
        'readme.md',
        'discovery_run_2_local_time_22_02_26.json',
        'discovery_run_10_local_time_23_02_26.json',
      ]);
      expect(next, equals(11));
    });

    test('supports legacy discovery_#N files while transitioning', () {
      final next = ConsumersCommand.computeNextDiscoveryIndexFromNames(const [
        'discovery_#3_local_time_22_02_26.json',
        'discovery_run_4_local_time_22_02_26.json',
      ]);
      expect(next, equals(5));
    });
  });

  group('buildDiscoverySnapshotName', () {
    test('formats index and local dd_mm_yy timestamp', () {
      final name = ConsumersCommand.buildDiscoverySnapshotName(index: 7, localTime: DateTime(2026, 2, 22, 15, 30, 0));
      expect(name, equals('discovery_run_7_local_time_22_02_26.json'));
    });
  });

  group('selectTagFromReleaseList', () {
    final releases = <Map<String, dynamic>>[
      {'tagName': 'v2.1.0-beta.1', 'isPrerelease': true, 'isDraft': false},
      {'tagName': 'v2.0.0', 'isPrerelease': false, 'isDraft': false},
      {'tagName': 'v1.9.9', 'isPrerelease': false, 'isDraft': false},
    ];

    test('skips prerelease by default and picks latest stable', () {
      final tag = ConsumersCommand.selectTagFromReleaseList(releases: releases, includePrerelease: false);
      expect(tag, equals('v2.0.0'));
    });

    test('includes prerelease when enabled', () {
      final tag = ConsumersCommand.selectTagFromReleaseList(releases: releases, includePrerelease: true);
      expect(tag, equals('v2.1.0-beta.1'));
    });

    test('applies regex filter before selection', () {
      final tag = ConsumersCommand.selectTagFromReleaseList(
        releases: releases,
        includePrerelease: true,
        tagPattern: RegExp(r'^v2\.0\.0$'),
      );
      expect(tag, equals('v2.0.0'));
    });
  });

  group('buildReleaseOutputPath', () {
    test('uses .consumers/repo/tag path shape', () {
      final path = ConsumersCommand.buildReleaseOutputPath(
        outputDir: '.consumers',
        repoName: 'runtime_isomorphic_library',
        tagName: 'v1.2.3',
      );
      expect(path, equals('.consumers/runtime_isomorphic_library/v1.2.3'));
    });
  });
}
