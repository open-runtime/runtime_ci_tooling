import 'dart:io';

import '../../triage/utils/config.dart';

/// Utilities for finding and working with the repository root.
abstract final class RepoUtils {
  /// Find the repository root by walking up and looking for pubspec.yaml
  /// with the matching package name from config.
  static String? findRepoRoot() {
    var dir = Directory.current;
    for (var i = 0; i < 10; i++) {
      final pubspec = File('${dir.path}/pubspec.yaml');
      if (pubspec.existsSync()) {
        final content = pubspec.readAsStringSync();
        if (content.contains('name: ${config.repoName}')) {
          return dir.path;
        }
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return null;
  }
}
