import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

/// Tests that validate the example multi-package config files under
/// `docs/examples/`. These configs document real repo archetypes and serve
/// as integration fixtures for the multi-package CI pipeline.
void main() {
  /// Helper: load and decode a JSON example config.
  Map<String, dynamic> loadExample(String filename) {
    final file = File('docs/examples/$filename');
    if (!file.existsSync()) {
      fail('Example config not found: docs/examples/$filename');
    }
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }

  /// Helper: extract the packages list from a config.
  List<Map<String, dynamic>> packages(Map<String, dynamic> config) {
    return (config['packages'] as List).cast<Map<String, dynamic>>();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Shared structure validation
  // ═══════════════════════════════════════════════════════════════════════════

  group('Common config structure', () {
    final examples = ['multi-package-native.json', 'multi-package-generator.json', 'multi-package-monorepo.json'];

    for (final example in examples) {
      group(example, () {
        late Map<String, dynamic> config;

        setUp(() => config = loadExample(example));

        test('has required repository.name and repository.owner', () {
          final repo = config['repository'] as Map<String, dynamic>;
          expect(repo['name'], isA<String>());
          expect((repo['name'] as String), isNotEmpty);
          expect(repo['owner'], isA<String>());
          expect((repo['owner'] as String), isNotEmpty);
        });

        test('has ci section with languages list', () {
          final ci = config['ci'] as Map<String, dynamic>;
          final languages = ci['languages'] as List;
          expect(languages, isNotEmpty);
          for (final lang in languages) {
            expect(lang, anyOf('dart', 'flutter', 'rust'));
          }
        });

        test('packages list is non-empty', () {
          expect(packages(config), isNotEmpty);
        });

        test('every package has name, path, language, and features', () {
          for (final pkg in packages(config)) {
            expect(pkg['name'], isA<String>(), reason: 'package missing name');
            expect(pkg['path'], isA<String>(), reason: '${pkg['name']} missing path');
            expect(
              pkg['language'],
              anyOf('dart', 'flutter', 'rust'),
              reason: '${pkg['name']} has invalid language: ${pkg['language']}',
            );
            final features = pkg['features'] as Map<String, dynamic>;
            expect(features.containsKey('test'), isTrue, reason: '${pkg['name']} missing features.test');
            expect(features.containsKey('analyze'), isTrue, reason: '${pkg['name']} missing features.analyze');
            expect(features.containsKey('format'), isTrue, reason: '${pkg['name']} missing features.format');
          }
        });

        test('no duplicate package names', () {
          final names = packages(config).map((p) => p['name']).toList();
          expect(names.toSet().length, names.length, reason: 'Duplicate package names found');
        });

        test('no duplicate package paths', () {
          final paths = packages(config).map((p) => p['path']).toList();
          expect(paths.toSet().length, paths.length, reason: 'Duplicate package paths found');
        });
      });
    }
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // native_clipboard archetype (Dart + Flutter + Rust builder)
  // ═══════════════════════════════════════════════════════════════════════════

  group('Multi-package native (native_clipboard)', () {
    late Map<String, dynamic> config;
    late List<Map<String, dynamic>> pkgs;

    setUp(() {
      config = loadExample('multi-package-native.json');
      pkgs = packages(config);
    });

    test('repository is open-runtime/native_clipboard', () {
      expect(config['repository']['name'], 'native_clipboard');
      expect(config['repository']['owner'], 'open-runtime');
    });

    test('has 4 packages (dart, flutter, builder, example)', () {
      expect(pkgs.length, 4);
    });

    test('core dart package at path "dart"', () {
      final dart = pkgs.firstWhere((p) => p['name'] == 'runtime_native_clipboard');
      expect(dart['path'], 'dart');
      expect(dart['language'], 'dart');
      expect(dart['features']['test'], true);
    });

    test('flutter wrapper at path "flutter"', () {
      final flutter = pkgs.firstWhere((p) => p['name'] == 'runtime_flutter_native_clipboard');
      expect(flutter['path'], 'flutter');
      expect(flutter['language'], 'flutter');
      expect(flutter['features']['test'], true);
    });

    test('builder utility at path "dart/utils"', () {
      final builder = pkgs.firstWhere((p) => p['name'] == 'runtime_native_clipboard_builder');
      expect(builder['path'], 'dart/utils');
      expect(builder['language'], 'dart');
      expect(builder['features']['test'], false);
    });

    test('example app has test disabled', () {
      final example = pkgs.firstWhere((p) => p['name'] == 'native_clipboard_example');
      expect(example['language'], 'flutter');
      expect(example['features']['test'], false);
      expect(example['features']['analyze'], true);
    });

    test('ci languages include both dart and flutter', () {
      final languages = (config['ci']['languages'] as List).cast<String>();
      expect(languages, containsAll(['dart', 'flutter']));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // copy_with_extension archetype (annotation + generator pair)
  // ═══════════════════════════════════════════════════════════════════════════

  group('Multi-package generator (copy_with_extension)', () {
    late Map<String, dynamic> config;
    late List<Map<String, dynamic>> pkgs;

    setUp(() {
      config = loadExample('multi-package-generator.json');
      pkgs = packages(config);
    });

    test('repository is numen31337/copy_with_extension', () {
      expect(config['repository']['name'], 'copy_with_extension');
      expect(config['repository']['owner'], 'numen31337');
    });

    test('has 2 packages (annotation + generator)', () {
      expect(pkgs.length, 2);
    });

    test('annotation package has no tests (annotation-only)', () {
      final annotation = pkgs.firstWhere((p) => p['name'] == 'copy_with_extension');
      expect(annotation['path'], 'copy_with_extension');
      expect(annotation['features']['test'], false);
      expect(annotation['features']['analyze'], true);
    });

    test('generator package has tests and build_runner', () {
      final gen = pkgs.firstWhere((p) => p['name'] == 'copy_with_extension_gen');
      expect(gen['path'], 'copy_with_extension_gen');
      expect(gen['features']['test'], true);
      expect(gen['features']['build_runner'], true);
    });

    test('only dart language (no flutter)', () {
      final languages = (config['ci']['languages'] as List).cast<String>();
      expect(languages, ['dart']);
      for (final pkg in pkgs) {
        expect(pkg['language'], 'dart');
      }
    });

    test('runs on ubuntu only (pure dart)', () {
      final platforms = (config['ci']['platforms'] as List).cast<String>();
      expect(platforms, ['ubuntu-x64']);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // super_editor archetype (large multi-package Flutter monorepo)
  // ═══════════════════════════════════════════════════════════════════════════

  group('Multi-package monorepo (super_editor)', () {
    late Map<String, dynamic> config;
    late List<Map<String, dynamic>> pkgs;

    setUp(() {
      config = loadExample('multi-package-monorepo.json');
      pkgs = packages(config);
    });

    test('repository is superlistapp/super_editor', () {
      expect(config['repository']['name'], 'super_editor');
      expect(config['repository']['owner'], 'superlistapp');
    });

    test('has 26 packages (all pubspec.yaml locations)', () {
      expect(pkgs.length, 26);
    });

    test('core libraries have tests enabled', () {
      final coreLibNames = [
        'attributed_text',
        'super_editor',
        'super_editor_clipboard',
        'super_editor_markdown',
        'super_editor_quill',
        'super_editor_spellcheck',
        'super_keyboard',
        'super_text_layout',
      ];
      for (final name in coreLibNames) {
        final pkg = pkgs.firstWhere((p) => p['name'] == name, orElse: () => fail('Missing core package: $name'));
        expect(pkg['features']['test'], true, reason: '$name should have tests enabled');
      }
    });

    test('example apps have tests disabled', () {
      final examples = pkgs.where((p) => (p['name'] as String).contains('example'));
      expect(examples, isNotEmpty);
      for (final example in examples) {
        expect(example['features']['test'], false, reason: '${example['name']} is an example and should not run tests');
      }
    });

    test('showcase clones have tests disabled', () {
      final clones = pkgs.where((p) => (p['path'] as String).startsWith('super_clones/'));
      expect(clones.length, 7);
      for (final clone in clones) {
        expect(
          clone['features']['test'],
          false,
          reason: '${clone['name']} is a showcase clone and should not run tests',
        );
      }
    });

    test('doc/website packages have analyze and format disabled', () {
      final docs = pkgs.where((p) => (p['path'] as String).contains('doc/website') || p['name'] == 'website');
      expect(docs.length, 3);
      for (final doc in docs) {
        expect(doc['features']['analyze'], false, reason: '${doc['name']} docs should skip analyze');
        expect(doc['features']['format'], false, reason: '${doc['name']} docs should skip format');
      }
    });

    test('has both dart and flutter packages', () {
      final dartPkgs = pkgs.where((p) => p['language'] == 'dart');
      final flutterPkgs = pkgs.where((p) => p['language'] == 'flutter');
      expect(dartPkgs, isNotEmpty, reason: 'Should have pure Dart packages');
      expect(flutterPkgs, isNotEmpty, reason: 'Should have Flutter packages');
    });

    test('attributed_text is pure dart (no Flutter dependency)', () {
      final at = pkgs.firstWhere((p) => p['name'] == 'attributed_text');
      expect(at['language'], 'dart');
    });

    test('area labels cover major sub-packages', () {
      final areas = (config['labels']['area'] as List).cast<String>();
      expect(areas, containsAll(['area/super_editor', 'area/super_text_layout', 'area/super_keyboard']));
    });
  });
}
