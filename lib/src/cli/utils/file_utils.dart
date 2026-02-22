import 'dart:io';

/// File system utilities for CI/CD operations.
abstract final class FileUtils {
  /// Recursively copy a directory tree.
  static void copyDirRecursive(Directory src, Directory dst) {
    dst.createSync(recursive: true);
    for (final entity in src.listSync()) {
      final name = entity.path.split('/').last;
      if (entity is File) {
        entity.copySync('${dst.path}/$name');
      } else if (entity is Directory) {
        copyDirRecursive(entity, Directory('${dst.path}/$name'));
      }
    }
  }

  /// Count all files in a directory tree.
  static int countFiles(Directory dir) {
    var count = 0;
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is File) count++;
    }
    return count;
  }

  /// Read a file and return its content, or a fallback message if not found.
  static String readFileOr(String path, [String fallback = '(not available)']) {
    final f = File(path);
    return f.existsSync() ? f.readAsStringSync().trim() : fallback;
  }
}
