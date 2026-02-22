import 'dart:convert';
import 'dart:io';

import 'logger.dart';

/// Resolves paths to prompt scripts within the runtime_ci_tooling package.
abstract final class PromptResolver {
  /// Cached path to the runtime_ci_tooling package root.
  static String? _toolingPackageRoot;

  /// Resolves the absolute path to a prompt script within this package.
  ///
  /// Prompt scripts live at `lib/src/prompts/` in the runtime_ci_tooling
  /// package. When this code runs from the package's own repo, that's just
  /// a relative path. When it runs from a consuming repo (e.g., via a thin
  /// wrapper), we resolve the package location from
  /// .dart_tool/package_config.json.
  static String promptScript(String scriptName) {
    _toolingPackageRoot ??= resolveToolingPackageRoot();
    return '$_toolingPackageRoot/lib/src/prompts/$scriptName';
  }

  /// Find the runtime_ci_tooling package root by checking:
  ///   1. package_config.json (works when consumed as a dependency)
  ///   2. CWD (works when running from the package's own repo)
  static String resolveToolingPackageRoot() {
    // Try 1: Look for the package in .dart_tool/package_config.json
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
                return Uri.parse(rootUri).toFilePath();
              }
              // Relative URI -- resolve against the .dart_tool/ directory
              final resolved = Uri.parse('${dir.path}/.dart_tool/').resolve(rootUri);
              final resolvedPath = resolved.toFilePath();
              // Strip trailing slash
              return resolvedPath.endsWith('/') ? resolvedPath.substring(0, resolvedPath.length - 1) : resolvedPath;
            }
          }
        } catch (_) {}
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }

    // Try 2: If we're running from the package's own repo
    if (File('lib/src/prompts/gemini_changelog_prompt.dart').existsSync()) {
      return Directory.current.path;
    }

    // Fallback
    Logger.warn('Could not resolve runtime_ci_tooling package root. Prompt scripts may not be found.');
    return Directory.current.path;
  }
}
