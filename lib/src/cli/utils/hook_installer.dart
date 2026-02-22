import 'dart:io';

import 'logger.dart';

/// Installs and manages git pre-commit hooks for Dart formatting.
class HookInstaller {
  /// Installs or refreshes the pre-commit hook that runs
  /// `dart format --line-length [lineLength] lib/`.
  ///
  /// Returns `true` if the hook was written, `false` if skipped
  /// (no `.git/hooks` directory, or dry-run mode).
  static bool install(String repoRoot, {int lineLength = 120, bool dryRun = false}) {
    final hooksDir = Directory('$repoRoot/.git/hooks');
    if (!hooksDir.existsSync()) {
      Logger.warn('No .git/hooks directory found — skipping pre-commit hook');
      return false;
    }
    if (dryRun) {
      Logger.info('  [dry-run] would install .git/hooks/pre-commit (dart format --line-length $lineLength)');
      return false;
    }
    final hookFile = File('${hooksDir.path}/pre-commit');
    final hookContent =
        '#!/bin/sh\n'
        '# Pre-commit hook: format Dart code at line-length $lineLength\n'
        '# Installed and managed by runtime_ci_tooling manage_cicd (init/update)\n'
        'if ! command -v dart >/dev/null 2>&1; then\n'
        '  echo "[runtime_ci] dart not found, skipping format"\n'
        '  exit 0\n'
        'fi\n'
        'dart format --line-length $lineLength lib/\n'
        'git add -u lib/\n';
    hookFile.writeAsStringSync(hookContent);
    if (!Platform.isWindows) {
      Process.runSync('chmod', ['+x', hookFile.path]);
    }
    Logger.success('Installed .git/hooks/pre-commit (dart format --line-length $lineLength)');
    return true;
  }
}
