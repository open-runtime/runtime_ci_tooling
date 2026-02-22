# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.8.0] - 2026-02-22

### Added
- Added `update` command for intelligently syncing templates (commands, settings, workflows, configs) to consumer repos
- Config-driven CI workflow generation via `ci` section in `config.json`
- `WorkflowGenerator` class with Mustache-based skeleton rendering (`ci.skeleton.yaml`)
- User-preservable sections (`# --- BEGIN USER / END USER ---`) survive workflow regeneration
- `ci` section defaults in `init` command for new consumers
- Strict type validation for all `ci` config fields (dart_sdk, features, secrets, pat_secret, line_length)
- `HookInstaller` utility and automatic git pre-commit hook installation in `init` and `update` commands — only staged `lib/` Dart files are formatted; existing custom hooks are backed up before replacement; hook respects consumer's `line_length` config

### Changed
- Replaced monolithic `ci.template.yaml` with config-driven `ci.skeleton.yaml`
- Fixed formatting in `update_options.g.dart`

## [0.7.1] - 2026-02-22

### Fixed
- Copied `docs/` and `autodoc.json` from artifacts in create-release

## [0.7.0] - 2026-02-22

### Added
- Added `autodoc.json` generation support in the `init` command

### Changed
- Fixed formatting in `init_command.dart` and `autodoc_api_reference_prompt.dart`

### Fixed
- Completed unfinished autodoc prompt implementations
- Corrected Gemini model ID to `gemini-3.1-pro-preview` to resolve `ModelNotFoundError` in AI-powered pipeline stages

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

## [0.5.0] - 2026-02-16

### Added
- Added comprehensive SETUP.md and USAGE.md documentation (commit bbe1e27)
- Added SendGrid Email Validation API key to CI template (commit 28cfa58)

### Fixed
- Fixed CI checkout to include LFS files so test assets are downloaded (commit a3996c9)

## [0.4.1] - 2026-02-16

### Changed
- Removed support for the `[Unreleased]` changelog section to streamline automated releases (commit ea5608f)

## [0.4.0] - 2026-02-16

### Changed
- Replaced wrapper scripts with `bin/` executables for zero-boilerplate portability (commit 53149d9)
- Moved `autodoc.json` configuration to `.runtime_ci/` directory (auto-migrates from legacy location) (commit 6f54632)

### Fixed
- Fixed `git add` failure in release process by adding files individually (commit 1d45361)

[0.8.0]: https://github.com/open-runtime/runtime_ci_tooling/compare/v0.7.1...v0.8.0
[0.7.1]: https://github.com/open-runtime/runtime_ci_tooling/compare/v0.7.0...v0.7.1
[0.7.0]: https://github.com/open-runtime/runtime_ci_tooling/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/open-runtime/runtime_ci_tooling/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/open-runtime/runtime_ci_tooling/compare/v0.4.1...v0.5.0
[0.4.1]: https://github.com/open-runtime/runtime_ci_tooling/compare/v0.4.0...v0.4.1
[0.4.0]: https://github.com/open-runtime/runtime_ci_tooling/releases/tag/v0.4.0
