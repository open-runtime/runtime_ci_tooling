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