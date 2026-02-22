import 'dart:convert';
import 'dart:io';

import '../../triage/utils/run_context.dart';

/// Scaffold `.runtime_ci/autodoc.json` by scanning `lib/src/` for modules.
///
/// Returns `true` if the file was created, `false` if it already existed
/// (or no `lib/` directory was found to scan).
///
/// This is the shared implementation used by both `init` and `autodoc --init`.
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
      final displayName = dirName.split('_').map((w) => '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
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
      'name': packageName.split('_').map((w) => '${w[0].toUpperCase()}${w.substring(1)}').join(' '),
      'source_paths': ['lib/'],
      'lib_paths': ['lib/'],
      'output_path': 'docs/',
      'generate': ['quickstart', 'api_reference'],
      'hash': '',
      'last_updated': null,
    });
  }

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
