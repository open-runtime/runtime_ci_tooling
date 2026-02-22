import 'dart:io';

import 'package:runtime_ci_tooling/src/cli/utils/hook_installer.dart';
import 'package:test/test.dart';

/// Creates a temporary directory that mimics a git repo root with a `.git/hooks/` dir.
Directory _makeTempRepo() {
  final tmp = Directory.systemTemp.createTempSync('hook_installer_test_');
  Directory('${tmp.path}/.git/hooks').createSync(recursive: true);
  return tmp;
}

void main() {
  group('HookInstaller', () {
    test('returns false when .git/hooks/ directory is missing', () {
      final tmp = Directory.systemTemp.createTempSync('hook_installer_no_git_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      // No .git/ at all
      expect(HookInstaller.install(tmp.path), isFalse);
    });

    test('returns false in dry-run mode and does not write any file', () {
      final tmp = _makeTempRepo();
      addTearDown(() => tmp.deleteSync(recursive: true));
      final result = HookInstaller.install(tmp.path, dryRun: true);
      expect(result, isFalse);
      expect(File('${tmp.path}/.git/hooks/pre-commit').existsSync(), isFalse);
    });

    test('installs hook and returns true', () {
      final tmp = _makeTempRepo();
      addTearDown(() => tmp.deleteSync(recursive: true));
      expect(HookInstaller.install(tmp.path), isTrue);
      expect(File('${tmp.path}/.git/hooks/pre-commit').existsSync(), isTrue);
    });

    test('hook content uses custom line-length when specified', () {
      final tmp = _makeTempRepo();
      addTearDown(() => tmp.deleteSync(recursive: true));
      HookInstaller.install(tmp.path, lineLength: 80);
      final content = File('${tmp.path}/.git/hooks/pre-commit').readAsStringSync();
      expect(content, contains('--line-length 80'));
      expect(content, isNot(contains('--line-length 120')));
    });

    test('hook content uses default line-length of 120', () {
      final tmp = _makeTempRepo();
      addTearDown(() => tmp.deleteSync(recursive: true));
      HookInstaller.install(tmp.path);
      final content = File('${tmp.path}/.git/hooks/pre-commit').readAsStringSync();
      expect(content, contains('--line-length 120'));
    });

    test('hook content has correct shebang and managed-by marker', () {
      final tmp = _makeTempRepo();
      addTearDown(() => tmp.deleteSync(recursive: true));
      HookInstaller.install(tmp.path);
      final content = File('${tmp.path}/.git/hooks/pre-commit').readAsStringSync();
      expect(content, startsWith('#!/bin/sh\n'));
      expect(content, contains('# Installed and managed by runtime_ci_tooling manage_cicd (init/update)'));
    });

    test('hook content only formats staged lib/ Dart files', () {
      final tmp = _makeTempRepo();
      addTearDown(() => tmp.deleteSync(recursive: true));
      HookInstaller.install(tmp.path);
      final content = File('${tmp.path}/.git/hooks/pre-commit').readAsStringSync();
      // Must use git diff --cached to get only staged files
      expect(content, contains('git diff --name-only --cached'));
      // Must filter to lib/*.dart only
      expect(content, contains("grep '^lib/.*\\.dart\$'"));
    });

    test('hook only formats Dart files when staged lib/ Dart files exist (no early exit)', () {
      final tmp = _makeTempRepo();
      addTearDown(() => tmp.deleteSync(recursive: true));
      HookInstaller.install(tmp.path);
      final content = File('${tmp.path}/.git/hooks/pre-commit').readAsStringSync();
      // Format section must be conditional (not exit-early) so pubspec section always runs.
      // A pubspec-only commit must not be short-circuited by the Dart section.
      expect(content, contains('if [ -n "\$STAGED_DART" ]; then'));
      // Must NOT have the old early-exit pattern that would skip the pubspec check
      expect(content, isNot(contains('if [ -z "\$STAGED_DART" ]; then')));
      expect(content, isNot(contains('  exit 0')));
    });

    test('hook content includes pubspec.yaml resolution: workspace check', () {
      final tmp = _makeTempRepo();
      addTearDown(() => tmp.deleteSync(recursive: true));
      HookInstaller.install(tmp.path);
      final content = File('${tmp.path}/.git/hooks/pre-commit').readAsStringSync();
      // Must detect staged pubspec.yaml files
      expect(content, contains("grep 'pubspec\\.yaml\$'"));
      // Must check for the offending line
      expect(content, contains("grep -q '^resolution: workspace'"));
    });

    test('hook strips resolution: workspace using portable sed', () {
      final tmp = _makeTempRepo();
      addTearDown(() => tmp.deleteSync(recursive: true));
      HookInstaller.install(tmp.path);
      final content = File('${tmp.path}/.git/hooks/pre-commit').readAsStringSync();
      // sed -i.bak works on both macOS (requires extension) and Linux (accepts it)
      expect(content, contains("sed -i.bak '/^resolution: workspace/d'"));
      // Must clean up the temp .bak file
      expect(content, contains('rm -f "\${f}.bak"'));
      // Must re-stage the modified pubspec
      expect(content, contains('git add "\$f"'));
    });

    test('hook runs dart pub get only when resolution: workspace was actually stripped', () {
      final tmp = _makeTempRepo();
      addTearDown(() => tmp.deleteSync(recursive: true));
      HookInstaller.install(tmp.path);
      final content = File('${tmp.path}/.git/hooks/pre-commit').readAsStringSync();
      // dart pub get must be conditional on STRIPPED=1, not run for every pubspec change
      expect(content, contains('STRIPPED=1'));
      expect(content, contains('if [ "\$STRIPPED" = "1" ]'));
      expect(content, contains('dart pub get'));
    });

    test('hook aborts commit if dart pub get fails after stripping', () {
      final tmp = _makeTempRepo();
      addTearDown(() => tmp.deleteSync(recursive: true));
      HookInstaller.install(tmp.path);
      final content = File('${tmp.path}/.git/hooks/pre-commit').readAsStringSync();
      // Must exit 1 on dart pub get failure — silent continuation would allow a broken pubspec
      expect(content, contains('if ! dart pub get'));
      expect(content, contains('exit 1'));
    });

    test('backs up pre-existing custom hook before replacing', () {
      final tmp = _makeTempRepo();
      addTearDown(() => tmp.deleteSync(recursive: true));
      final hookFile = File('${tmp.path}/.git/hooks/pre-commit');
      hookFile.writeAsStringSync('#!/bin/sh\necho "custom hook"\n');

      HookInstaller.install(tmp.path);

      // Backup must exist and contain original content
      final bakFile = File('${tmp.path}/.git/hooks/pre-commit.bak');
      expect(bakFile.existsSync(), isTrue);
      expect(bakFile.readAsStringSync(), contains('custom hook'));
      // New hook must have been written
      final newContent = hookFile.readAsStringSync();
      expect(newContent, contains('runtime_ci_tooling'));
    });

    test('does NOT back up hook previously installed by runtime_ci_tooling', () {
      final tmp = _makeTempRepo();
      addTearDown(() => tmp.deleteSync(recursive: true));

      // First install
      HookInstaller.install(tmp.path);
      // Second install (e.g., after update)
      HookInstaller.install(tmp.path);

      // No backup should be created since the hook already has our marker
      expect(File('${tmp.path}/.git/hooks/pre-commit.bak').existsSync(), isFalse);
    });

    test('re-running install overwrites our own hook idempotently', () {
      final tmp = _makeTempRepo();
      addTearDown(() => tmp.deleteSync(recursive: true));

      HookInstaller.install(tmp.path, lineLength: 100);
      HookInstaller.install(tmp.path, lineLength: 80);

      final content = File('${tmp.path}/.git/hooks/pre-commit').readAsStringSync();
      // Must reflect the most recent line-length
      expect(content, contains('--line-length 80'));
      expect(content, isNot(contains('--line-length 100')));
    });
  });
}
