import 'dart:convert';
import 'dart:io';

import 'logger.dart';

/// Resolves paths within the runtime_ci_tooling package.
///
/// When runtime_ci_tooling is consumed as a dependency, its templates
/// and other assets are in the pub cache. This class finds the package
/// root by parsing .dart_tool/package_config.json.
abstract final class TemplateResolver {
  static String? _cachedPackageRoot;

  /// Find the runtime_ci_tooling package root directory.
  ///
  /// Resolution order:
  ///   1. .dart_tool/package_config.json (works as a dependency)
  ///   2. CWD contains templates/ directly (running from package repo)
  static String resolvePackageRoot() {
    if (_cachedPackageRoot != null) return _cachedPackageRoot!;
    _cachedPackageRoot = _resolve();
    return _cachedPackageRoot!;
  }

  /// Resolve the absolute path to the templates/ directory.
  static String resolveTemplatesDir() => '${resolvePackageRoot()}/templates';

  /// Resolve a specific template file path.
  static String resolveTemplatePath(String relativePath) {
    return '${resolveTemplatesDir()}/$relativePath';
  }

  /// Read the templates/manifest.json.
  static Map<String, dynamic> readManifest() {
    final manifestPath = '${resolveTemplatesDir()}/manifest.json';
    final file = File(manifestPath);
    if (!file.existsSync()) {
      throw StateError(
        'Template manifest not found at $manifestPath. '
        'This indicates a corrupted runtime_ci_tooling installation.',
      );
    }
    return json.decode(file.readAsStringSync()) as Map<String, dynamic>;
  }

  /// Read the tooling version from pubspec.yaml in the package root.
  static String resolveToolingVersion() {
    final pubspecPath = '${resolvePackageRoot()}/pubspec.yaml';
    final file = File(pubspecPath);
    if (!file.existsSync()) return 'unknown';
    final match = RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(file.readAsStringSync());
    return match?.group(1) ?? 'unknown';
  }

  static String _resolve() {
    // Try 1: package_config.json (consumed as a dependency)
    var dir = Directory.current;
    for (var i = 0; i < 10; i++) {
      final configFile = File('${dir.path}/.dart_tool/package_config.json');
      if (configFile.existsSync()) {
        try {
          final configJson = json.decode(configFile.readAsStringSync()) as Map<String, dynamic>;
          final packages = configJson['packages'] as List<dynamic>? ?? [];
          for (final pkg in packages) {
            if (pkg is Map<String, dynamic> && pkg['name'] == 'runtime_ci_tooling') {
              final rootUri = pkg['rootUri'] as String? ?? '';
              if (rootUri.startsWith('file://')) {
                final path = Uri.parse(rootUri).toFilePath();
                return path.endsWith('/') ? path.substring(0, path.length - 1) : path;
              }
              final resolved = Uri.parse('${dir.path}/.dart_tool/').resolve(rootUri);
              final resolvedPath = resolved.toFilePath();
              return resolvedPath.endsWith('/') ? resolvedPath.substring(0, resolvedPath.length - 1) : resolvedPath;
            }
          }
        } catch (_) {}
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }

    // Try 2: Running from the package's own repo
    if (Directory('templates').existsSync() && File('templates/manifest.json').existsSync()) {
      return Directory.current.path;
    }

    Logger.warn('Could not resolve runtime_ci_tooling package root. Template files may not be found.');
    return Directory.current.path;
  }
}
