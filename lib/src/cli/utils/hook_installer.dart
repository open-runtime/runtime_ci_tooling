import 'dart:io';

import 'logger.dart';

/// Installs and manages git pre-commit hooks for Dart formatting.
class HookInstaller {
  /// Installs or refreshes the pre-commit hook that runs
  /// `dart format --line-length [lineLength]` on staged `lib/` Dart files.
  ///
  /// Only staged `lib/` Dart files are formatted — unstaged changes and files
  /// outside `lib/` are never touched. If a pre-existing custom hook is detected
  /// (one not created by runtime_ci_tooling) it is backed up to
  /// `.git/hooks/pre-commit.bak` before being replaced.
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
      Logger.info(
        '  [dry-run] would install .git/hooks/pre-commit '
        '(dart format --line-length $lineLength staged lib/ files)',
      );
      return false;
    }

    const marker = '# Installed and managed by runtime_ci_tooling manage_cicd (init/update)';
    final hookFile = File('${hooksDir.path}/pre-commit');

    // Back up any pre-existing hook that we did not create.
    if (hookFile.existsSync()) {
      final existing = hookFile.readAsStringSync();
      if (!existing.contains(marker)) {
        final bakFile = File('${hooksDir.path}/pre-commit.bak');
        hookFile.copySync(bakFile.path);
        Logger.warn('Backed up existing .git/hooks/pre-commit → pre-commit.bak');
      }
    }

    // Only format staged lib/ Dart files — leave all other files untouched.
    final hookContent =
        '#!/bin/sh\n'
        '# Pre-commit hook: format staged Dart files at line-length $lineLength\n'
        '$marker\n'
        'STAGED_DART=\$(git diff --name-only --cached | grep \'^lib/.*\\.dart\$\')\n'
        'if [ -z "\$STAGED_DART" ]; then\n'
        '  exit 0\n'
        'fi\n'
        'if ! command -v dart >/dev/null 2>&1; then\n'
        '  echo "[runtime_ci] dart not found, skipping format"\n'
        '  exit 0\n'
        'fi\n'
        // shellcheck disable=SC2086 -- word splitting is intentional for file list
        'dart format --line-length $lineLength \$STAGED_DART\n'
        'echo "\$STAGED_DART" | xargs git add\n';

    hookFile.writeAsStringSync(hookContent);
    if (!Platform.isWindows) {
      Process.runSync('chmod', ['+x', hookFile.path]);
    }
    Logger.success('Installed .git/hooks/pre-commit (dart format --line-length $lineLength)');
    return true;
  }
}
