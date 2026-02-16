import 'dart:io';

/// Shared constants and utilities for CI/CD scripts.
///
/// Provides generic repo-root discovery and generated file detection.

/// All generated file extensions produced by protoc-gen-dart and protoc-gen-enhance.
///
/// MAINTENANCE: When adding new generated extensions, also update:
/// - packages/proto_enhancements_plugin/lib/src/proto_utils.dart (plugin output paths)
/// - manage_barrel_exports.dart _isGeneratedFile() (barrel file detection)
const List<String> kGeneratedExtensions = [
  '.pb.dart',
  '.pbenum.dart',
  '.pbjson.dart',
  '.pbgrpc.dart',
  '.enhance.oneof.dart',
  '.enhance.builder.dart',
  '.enhance.fixture.dart',
  '.enhance.timestamps.dart',
  '.enhance.collection.dart',
  '.enhance.map.dart',
  '.enhance.enum.dart',
  '.enhance.dx.dart',
  '.enhance.http.dart',
];

/// Check if a file path ends with a known generated extension.
bool isGeneratedFile(String filePath) {
  return kGeneratedExtensions.any((ext) => filePath.endsWith(ext));
}

/// Finds a Dart package repo root by walking up from the current directory,
/// looking for a `pubspec.yaml` with `name: <packageName>`.
///
/// Returns `null` if not found (e.g., running from outside the repo).
String? findRepoRoot(String packageName) {
  var current = Directory.current;
  do {
    final pubspec = File('${current.path}/pubspec.yaml');
    if (pubspec.existsSync() && pubspec.readAsStringSync().contains('name: $packageName')) {
      return current.path;
    }
    current = current.parent;
  } while (current.parent.path != current.path);
  return null;
}
