# Version Bump Analysis

**Decision**: **minor** (Target: v0.4.0)

## Rationale
This release introduces new CLI executables that simplify usage and portability, alongside robust fixes for the release process and configuration management. While it changes the recommended setup flow (no longer generating wrapper scripts), it maintains backward compatibility for existing installations.

## Key Changes
- **New Feature**: Added `bin/manage_cicd.dart` and `bin/triage_cli.dart` executables.
- **New Feature**: Exposed executables in `pubspec.yaml` allowing direct execution via `dart run runtime_ci_tooling:manage_cicd`.
- **Refactor**: Updated `init` command to stop generating local wrapper scripts (`scripts/`), favoring the new direct executable usage.
- **Enhancement**: `autodoc` configuration moved to `.runtime_ci/autodoc.json`. Auto-migration from the legacy root location is included.
- **Fix**: Improved robustness of release artifact staging by adding files individually, preventing failures when optional files are missing.

## Breaking Changes
- None for existing consumers who use previously generated wrapper scripts (the backing library files `lib/src/cli/` remain).
- Direct consumers of the repositorys `scripts/` directory (e.g., in raw git clones) must switch to `bin/` or `dart run runtime_ci_tooling:...`.

## References
- `refactor: replace wrapper scripts with bin/ executables for zero-boilerplate portability`
- `fix: move autodoc.json to .runtime_ci/ and migrate legacy location`
- `fix: add release files individually to prevent all-or-nothing git add failure`
