# runtime_ci_tooling v0.6.0

## Version Bump Analysis

**Decision**: minor - The release includes new features via a `feat:` commit adopting typed CLI options and adding dynamic configuration capabilities.

**Key Changes**:
- **Refactor/CLI**: Adopted typed CLI options for `manage_cicd` and `triage_cli` commands using `build_cli` to centralize and improve argument parsing.
- **Dynamic Prompts**: Replaced hardcoded "runtime_isomorphic_library" strings in prompt generation scripts and Gemini TOML templates with dynamic interpolation reading from `pubspec.yaml` and `.runtime_ci/config.json`.
- **Bug Fixes**: 
  - Restored missing CLI flags (`--artifacts-dir`, `--repo`, `--release-tag`, `--release-url`, `--manifest`, `--output-github-actions`) to the new typed parsers.
  - Handled the `init` command properly before calling `_findRepoRoot()` to allow bootstrapping new projects without exceptions.
  - Temporarily reverted and fixed `resolution: workspace` to ensure standalone CI builds function correctly.
- **Dependencies**: Added `args`, `build_cli_annotations`, `build_cli`, and `build_runner` packages to `pubspec.yaml`.
- **Formatting**: Auto-formatted codebase using `dart format --line-length 120`.

**Breaking Changes**:
- None. The external CLI interface remains backwards-compatible, preserving existing flag usages.

**New Features**:
- Generated `build_cli` option models for CLI entry points.
- Extracted dynamic CI configuration values for broader reuse across different repositories.

**References**:
- PR/Commits related to typed CLI options (`feat: adopt typed CLI options...`, `fix: add all workflow CLI flags...`)
- Commits handling prompt dynamic properties (`fix: use dynamic package name in all prompts...`)
- Commits fixing bootstrap failures (`fix: handle init command before _findRepoRoot()`)


## Changelog

## [0.6.0] - 2026-02-22

### Breaking Changes
- **BREAKING**: Removed package executables (bin/manage_cicd.dart). The CLI must now be invoked via scripts/.
  - Migration: Use `dart run scripts/manage_cicd.dart` instead of `dart run runtime_ci_tooling:manage_cicd`.
- **BREAKING**: Updated CI template secret names and removed SendGrid/LFS support.
  - Migration: Update GitHub Actions workflows to use new secret names (e.g., GEMINI_API_KEY instead of CICD_GEMINI_API_KEY_OPEN_RUNTIME) and remove LFS configuration if not needed.

### Added
- Added script wrappers in scripts/ for local execution
- Added build_cli and build_runner dependencies

### Changed
- Refactored CLI argument parsing to use typed options (build_cli)
- Updated CI workflow templates with new secret mappings and script paths

### Removed
- Removed bin/ executables (manage_cicd, triage_cli) in favor of scripts/
- Removed USAGE.md and SETUP.md documentation
- Removed SendGrid API keys and LFS configuration from CI template

---
[Full Changelog](https://github.com/open-runtime/runtime_ci_tooling/compare/v0.5.0...v0.6.0)
