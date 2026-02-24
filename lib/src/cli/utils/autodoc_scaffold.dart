import 'dart:convert';
import 'dart:io';

import '../../triage/utils/run_context.dart';
import 'logger.dart';
import 'sub_package_utils.dart';

/// Capitalize a snake_case name into a display-friendly title.
///
/// Splits on `_`, capitalizes the first letter of each non-empty segment,
/// and joins with spaces. Empty segments (from leading, trailing, or
/// consecutive underscores) are silently skipped.
String _titleCase(String snakeName) {
  return snakeName.split('_').where((w) => w.isNotEmpty).map((w) => '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
}

/// Scaffold `.runtime_ci/autodoc.json` by scanning `lib/src/` for modules.
///
/// Returns `true` if the file was created, `false` if it already existed
/// (or no `lib/` directory was found to scan).
///
/// This is the shared implementation used by both `init` and `autodoc --init`.
///
/// When a CI config with `sub_packages` is present, modules are also scaffolded
/// for each sub-package that has a `lib/` directory. Sub-package module IDs are
/// prefixed with `<sub_package_name>-` to avoid conflicts with root modules.
bool scaffoldAutodocJson(String repoRoot, {bool overwrite = false}) {
  final configDir = Directory('$repoRoot/$kRuntimeCiDir');
  final autodocFile = File('$repoRoot/$kRuntimeCiDir/autodoc.json');

  if (autodocFile.existsSync() && !overwrite) return false;

  // Read package name from pubspec.yaml
  String packageName = 'unknown';
  final pubspecFile = File('$repoRoot/pubspec.yaml');
  if (pubspecFile.existsSync()) {
    final content = pubspecFile.readAsStringSync();
    final nameMatch = RegExp(r'^name:\s*(\S+)', multiLine: true).firstMatch(content);
    if (nameMatch != null) packageName = nameMatch.group(1)!;
  }

  final modules = <Map<String, dynamic>>[];
  final libDir = Directory('$repoRoot/lib');
  final srcDir = Directory('$repoRoot/lib/src');

  if (srcDir.existsSync()) {
    // Scan lib/src/ subdirectories for modules
    final subdirs =
        srcDir.listSync().whereType<Directory>().where((d) => !d.path.split('/').last.startsWith('.')).toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    for (final dir in subdirs) {
      final dirName = dir.path.split('/').last;
      final displayName = _titleCase(dirName);
      modules.add({
        'id': dirName,
        'name': displayName,
        'source_paths': ['lib/src/$dirName/'],
        'lib_paths': ['lib/src/$dirName/'],
        'output_path': 'docs/$dirName/',
        'generate': ['quickstart', 'api_reference'],
        'hash': '',
        'last_updated': null,
      });
    }

    // Add top-level module for package entry points
    modules.add({
      'id': 'top_level',
      'name': 'Package Entry Points',
      'source_paths': ['lib/'],
      'lib_paths': <String>[],
      'output_path': 'docs/',
      'generate': ['quickstart'],
      'hash': '',
      'last_updated': null,
    });
  } else if (libDir.existsSync()) {
    // No lib/src/ — use lib/ as single module
    modules.add({
      'id': 'core',
      'name': _titleCase(packageName),
      'source_paths': ['lib/'],
      'lib_paths': ['lib/'],
      'output_path': 'docs/',
      'generate': ['quickstart', 'api_reference'],
      'hash': '',
      'last_updated': null,
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Sub-package module scaffolding
  // ═══════════════════════════════════════════════════════════════════════════
  _scaffoldSubPackageModules(repoRoot, modules);

  if (modules.isEmpty) return false;

  configDir.createSync(recursive: true);
  final autodocData = {
    'version': '1.0.0',
    'gemini_model': 'gemini-3.1-pro-preview',
    'max_concurrent': 4,
    'modules': modules,
    'templates': {
      'quickstart': 'scripts/prompts/autodoc_quickstart_prompt.dart',
      'api_reference': 'scripts/prompts/autodoc_api_reference_prompt.dart',
      'examples': 'scripts/prompts/autodoc_examples_prompt.dart',
    },
  };
  autodocFile.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(autodocData)}\n');
  return true;
}

/// Discover sub-packages from CI config and scaffold autodoc modules for each
/// one that has a `lib/` directory.
///
/// Each sub-package's modules are prefixed with the sub-package name to avoid
/// ID collisions with root modules (e.g. `my_sub_pkg-core`, `my_sub_pkg-utils`).
/// Output paths are scoped to the sub-package directory.
///
/// Delegates to [SubPackageUtils.loadSubPackages] for config loading so that
/// malformed JSON is handled gracefully (logged + skipped) instead of crashing.
void _scaffoldSubPackageModules(String repoRoot, List<Map<String, dynamic>> modules) {
  final validPackages = SubPackageUtils.loadSubPackages(repoRoot);
  if (validPackages.isEmpty) return;

  var scaffoldedCount = 0;

  for (final sp in validPackages) {
    final spName = sp['name'] as String;
    // Path is already normalized (trailing slashes stripped) by
    // SubPackageUtils.loadSubPackages().
    final spPath = sp['path'] as String;

    final spLibDir = Directory('$repoRoot/$spPath/lib');
    if (!spLibDir.existsSync()) continue;

    final spSrcDir = Directory('$repoRoot/$spPath/lib/src');

    if (spSrcDir.existsSync()) {
      // Scan sub-package's lib/src/ subdirectories
      final subdirs =
          spSrcDir.listSync().whereType<Directory>().where((d) => !d.path.split('/').last.startsWith('.')).toList()
            ..sort((a, b) => a.path.compareTo(b.path));

      for (final dir in subdirs) {
        final dirName = dir.path.split('/').last;
        final displayName = '$spName: ${_titleCase(dirName)}';
        modules.add({
          'id': '$spName-$dirName',
          'name': displayName,
          'source_paths': ['$spPath/lib/src/$dirName/'],
          'lib_paths': ['$spPath/lib/src/$dirName/'],
          'output_path': '$spPath/docs/$dirName/',
          'generate': ['quickstart', 'api_reference'],
          'hash': '',
          'last_updated': null,
        });
      }

      // Add top-level module for the sub-package entry points
      modules.add({
        'id': '$spName-top_level',
        'name': '$spName: Package Entry Points',
        'source_paths': ['$spPath/lib/'],
        'lib_paths': <String>[],
        'output_path': '$spPath/docs/',
        'generate': ['quickstart'],
        'hash': '',
        'last_updated': null,
      });
    } else {
      // No lib/src/ — use lib/ as a single module for this sub-package
      final displayName = _titleCase(spName);
      modules.add({
        'id': '$spName-core',
        'name': displayName,
        'source_paths': ['$spPath/lib/'],
        'lib_paths': ['$spPath/lib/'],
        'output_path': '$spPath/docs/',
        'generate': ['quickstart', 'api_reference'],
        'hash': '',
        'last_updated': null,
      });
    }

    scaffoldedCount++;
  }

  if (scaffoldedCount > 0) {
    Logger.info('  Discovered $scaffoldedCount sub-package(s) for autodoc scaffolding');
  }
}
