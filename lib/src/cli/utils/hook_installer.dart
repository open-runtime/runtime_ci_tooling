import 'dart:io';

import 'logger.dart';

/// Installs and manages git pre-commit hooks for Dart repos.
///
/// The installed hook performs two checks on every commit:
/// 1. Formats staged `lib/` Dart files with `dart format`.
/// 2. Strips `resolution: workspace` from any staged `pubspec.yaml` files and
///    validates that `dart pub get` still succeeds — preventing the monorepo-only
///    field from being committed to standalone repos where it breaks CI.
class HookInstaller {
  /// Installs or refreshes the pre-commit hook.
  ///
  /// If a pre-existing custom hook is detected (one not created by
  /// runtime_ci_tooling) it is backed up to `.git/hooks/pre-commit.bak`
  /// before being replaced.
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
        '(dart format --line-length $lineLength staged lib/ files + strip resolution: workspace)',
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

    // Two independent sections — each is a no-op when its trigger files aren't staged.
    // Section 1 must NOT use early-exit so section 2 always runs (e.g. pubspec-only commits).
    final hookContent =
        '#!/bin/sh\n'
        '# Pre-commit hook: format staged Dart files and strip resolution: workspace\n'
        '$marker\n'
        '\n'
        '# === 1. Format staged lib/ Dart files ===\n'
        'STAGED_DART=\$(git diff --name-only --cached | grep \'^lib/.*\\.dart\$\')\n'
        'if [ -n "\$STAGED_DART" ]; then\n'
        '  if ! command -v dart >/dev/null 2>&1; then\n'
        '    echo "[runtime_ci] dart not found, skipping format"\n'
        '  else\n'
        // shellcheck disable=SC2086 -- word splitting is intentional for file list
        '    dart format --line-length $lineLength \$STAGED_DART\n'
        '    echo "\$STAGED_DART" | xargs git add\n'
        '  fi\n'
        'fi\n'
        '\n'
        '# === 2. Strip resolution: workspace from staged pubspec.yaml files ===\n'
        '# runtime_aot_tooling --enable-all adds this field for monorepo workspace\n'
        '# membership, but it breaks standalone dart pub get. Strip it before committing.\n'
        "STAGED_PUBSPEC=\$(git diff --name-only --cached | grep 'pubspec\\.yaml\$')\n"
        'if [ -n "\$STAGED_PUBSPEC" ]; then\n'
        '  STRIPPED=0\n'
        '  for f in \$STAGED_PUBSPEC; do\n'
        "    if grep -q '^resolution: workspace' \"\$f\"; then\n"
        "      sed -i.bak '/^resolution: workspace/d' \"\$f\"\n"
        '      rm -f "\${f}.bak"\n'
        '      git add "\$f"\n'
        "      echo \"[runtime_ci] Stripped 'resolution: workspace' from \$f\"\n"
        '      STRIPPED=1\n'
        '    fi\n'
        '  done\n'
        '  if [ "\$STRIPPED" = "1" ] && command -v dart >/dev/null 2>&1; then\n'
        '    echo "[runtime_ci] Validating dart pub get after stripping resolution: workspace..."\n'
        '    if ! dart pub get 2>&1; then\n'
        '      echo "[runtime_ci] Error: dart pub get failed — fix pubspec.yaml before committing"\n'
        '      exit 1\n'
        '    fi\n'
        '    echo "[runtime_ci] dart pub get succeeded"\n'
        '  fi\n'
        'fi\n';

    hookFile.writeAsStringSync(hookContent);
    if (!Platform.isWindows) {
      Process.runSync('chmod', ['+x', hookFile.path]);
    }
    Logger.success(
      'Installed .git/hooks/pre-commit '
      '(dart format --line-length $lineLength + strip resolution: workspace)',
    );
    return true;
  }
}
