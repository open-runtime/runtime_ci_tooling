import 'dart:io';

import 'package:path/path.dart' as p;

import '../../triage/utils/config.dart';

/// Utilities for finding and working with the repository root.
abstract final class RepoUtils {
  static final RegExp _controlChars = RegExp(r'[\r\n\t\x00-\x1f]');

  /// Find the repository root by walking up and looking for pubspec.yaml
  /// with the matching package name from config.
  static String? findRepoRoot() {
    var dir = Directory.current;
    for (var i = 0; i < 10; i++) {
      final pubspec = File('${dir.path}/pubspec.yaml');
      if (pubspec.existsSync()) {
        final content = pubspec.readAsStringSync();
        if (content.contains(RegExp(r'^name:\s+' + RegExp.escape(config.repoName) + r'\s*$', multiLine: true))) {
          return dir.path;
        }
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return null;
  }

  /// Resolve and validate the test log directory.
  ///
  /// - Defaults to `<repoRoot>/.dart_tool/test-logs` when TEST_LOG_DIR is unset.
  /// - If TEST_LOG_DIR is provided, it must be an absolute path and (when
  ///   RUNNER_TEMP is set) must stay within RUNNER_TEMP.
  static String resolveTestLogDir(String repoRoot, {Map<String, String>? environment}) {
    final env = environment ?? Platform.environment;
    final defaultDir = p.join(repoRoot, '.dart_tool', 'test-logs');
    final raw = env['TEST_LOG_DIR'];
    if (raw == null) return defaultDir;

    final trimmed = raw.trim();
    if (trimmed.isEmpty) return defaultDir;
    if (_controlChars.hasMatch(trimmed)) {
      throw StateError('TEST_LOG_DIR must not contain newlines or control characters');
    }

    final normalized = p.normalize(trimmed);
    if (!p.isAbsolute(normalized)) {
      throw StateError('TEST_LOG_DIR must be an absolute path');
    }

    final runnerTempRaw = env['RUNNER_TEMP']?.trim();
    if (runnerTempRaw != null && runnerTempRaw.isNotEmpty) {
      if (_controlChars.hasMatch(runnerTempRaw)) {
        throw StateError('RUNNER_TEMP must not contain newlines or control characters');
      }
      final runnerTemp = p.normalize(runnerTempRaw);
      if (!(normalized == runnerTemp || p.isWithin(runnerTemp, normalized))) {
        throw StateError('TEST_LOG_DIR must be within RUNNER_TEMP: "$runnerTemp"');
      }
    }

    return normalized;
  }

  /// Return true when the path itself is a symlink.
  static bool isSymlinkPath(String path) {
    return FileSystemEntity.typeSync(path, followLinks: false) == FileSystemEntityType.link;
  }

  /// Create a directory if needed, and refuse symlink-backed paths.
  static void ensureSafeDirectory(String dirPath) {
    if (isSymlinkPath(dirPath)) {
      throw FileSystemException('Refusing to use symlink directory', dirPath);
    }
    Directory(dirPath).createSync(recursive: true);
    if (isSymlinkPath(dirPath)) {
      throw FileSystemException('Refusing to use symlink directory', dirPath);
    }
  }

  /// Write file content while refusing symlink targets.
  static void writeFileSafely(String filePath, String content, {FileMode mode = FileMode.write}) {
    if (isSymlinkPath(filePath)) {
      throw FileSystemException('Refusing to write through symlink', filePath);
    }
    File(filePath).writeAsStringSync(content, mode: mode);
  }
}
