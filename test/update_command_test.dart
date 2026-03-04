import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Tests for the update command, including PR #36: --diff must emit unified
/// diff on the local-customization skip path for overwritable files.
void main() {
  group('UpdateCommand overwritable local-customization --diff', () {
    late Directory tempDir;
    late String packagePath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('update_cmd_');
      // Package root = CWD when running `dart test` from package root
      packagePath = p.normalize(Directory.current.path);
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test(
      'emits unified diff when skipping due to local customizations and --diff is set',
      () async {
        // Consumer repo: pubspec, config, overwritable file with local edits,
        // template_versions with consumer_hash != current file (local changes).
        final repoRoot = tempDir.path;

        // pubspec with path dep to runtime_ci_tooling (different name to avoid self-dep)
        File(p.join(repoRoot, 'pubspec.yaml')).writeAsStringSync('''
name: update_test_consumer
version: 0.0.0
environment:
  sdk: ^3.9.0
dependencies:
  runtime_ci_tooling:
    path: $packagePath
''');

        // .runtime_ci/config.json (repository.name must match pubspec for RepoUtils)
        Directory(p.join(repoRoot, '.runtime_ci')).createSync(recursive: true);
        File(p.join(repoRoot, '.runtime_ci', 'config.json')).writeAsStringSync(
          json.encode({
            'repository': {'name': 'update_test_consumer', 'owner': 'test'},
          }),
        );

        // Consumer file with local modifications (differs from template)
        const localContent =
            '{"_comment":"local customization","model":{"maxSessionTurns":99}}\n';
        Directory(p.join(repoRoot, '.gemini')).createSync(recursive: true);
        File(
          p.join(repoRoot, '.gemini', 'settings.json'),
        ).writeAsStringSync(localContent);

        // Template versions: consumer_hash = hash of "original" content so we
        // detect local changes. hash = old template hash so template appears
        // changed (we enter update path, not "up to date").
        final originalContent = '{"_comment":"original"}\n';
        final originalHash = sha256
            .convert(originalContent.codeUnits)
            .toString();
        const oldTemplateHash =
            '0000000000000000000000000000000000000000000000000000000000000001';

        File(
          p.join(repoRoot, '.runtime_ci', 'template_versions.json'),
        ).writeAsStringSync(
          json.encode({
            'tooling_version': '0.0.0',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
            'templates': {
              'gemini_settings': {
                'hash': oldTemplateHash,
                'consumer_hash': originalHash,
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              },
            },
          }),
        );

        // Resolve dependencies so package_config.json exists
        final pubGet = await Process.run('dart', [
          'pub',
          'get',
        ], workingDirectory: repoRoot);
        expect(pubGet.exitCode, equals(0), reason: 'pub get must succeed');

        // Run manage_cicd update --diff --templates from temp repo
        final result = await Process.run(
          'dart',
          [
            'run',
            'runtime_ci_tooling:manage_cicd',
            'update',
            '--diff',
            '--templates',
          ],
          workingDirectory: repoRoot,
          runInShell: false,
          environment: {'PATH': Platform.environment['PATH'] ?? ''},
        );

        final stdout = result.stdout as String;
        final stderr = result.stderr as String;
        final combined = '$stdout\n$stderr';

        expect(
          combined,
          contains('local customizations detected'),
          reason: 'Should warn about local customizations',
        );
        expect(
          combined,
          contains('[diff]'),
          reason:
              'PR #36: --diff must emit diff preview on local-customization skip path',
        );
        expect(
          combined,
          contains('.gemini/settings.json'),
          reason: 'Diff should reference the overwritable file path',
        );
      },
    );
  });
}
