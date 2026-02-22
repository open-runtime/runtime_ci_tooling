- **Decision**: patch
  The changes consist entirely of bug fixes (`fix:`), chores (`chore:`), and internal refactoring, which align with a patch-level release under semantic versioning. No public-facing API signatures were modified or removed, and no substantial new features were added to the package's external surface.

- **Key Changes**:
  - Migrated hardcoded `.cicd_runs` output paths to the new `.runtime_ci/runs` directory structure across multiple CLI commands and prompt scripts.
  - Fixed the `autodoc --init` command so that it now actively scaffolds `autodoc.json` instead of simply instructing the user to create it manually.
  - Extracted shared documentation scaffolding logic into `lib/src/cli/utils/autodoc_scaffold.dart`.
  - Added shared configuration constants in `lib/src/cli/utils/ci_constants.dart`.
  - Fixed a heredoc `JSONEOF` terminator indentation bug in `gemini_changelog_prompt.dart` that was causing `tee` to hang.
  - Corrected the retry logging message in `autodoc_command.dart` to accurately reflect network/rate-limiting errors.
  
- **Breaking Changes**:
  - None. (All structural modifications occurred under `lib/src/`, which is internal to the Dart package, and CLI flags retain backward compatibility).

- **New Features**:
  - None.

- **References**:
  - PR/Issue #2 (Closed by `autodoc --init` scaffolding fix).
  - Commits:
    - `fix: complete .cicd_runs → .runtime_ci/runs path migration`
    - `fix: make autodoc --init actually scaffold autodoc.json (closes #2)`
    - `chore: add runtime_ci_tooling generated files`
