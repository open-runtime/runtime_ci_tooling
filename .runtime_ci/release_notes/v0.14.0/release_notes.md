# runtime_ci_tooling v0.14.0

# Version Bump Rationale

**Decision**: minor

**Why**: 
The recent commits introduce new capabilities, including a new `build_runner` feature flag for CI codegen and a new `audit-all` CLI command. These are backwards-compatible additive changes that expand the capabilities of the tooling without introducing breaking changes to existing public APIs or workflows, thereby warranting a minor version bump.

**Key Changes**:
- **New Feature**: Added `build_runner` feature flag for generating `.g.dart` files in CI to avoid environment drift and stale codegen risks.
- **New Feature**: Added `audit-all` command to recursively audit all `pubspec.yaml` files under a directory against the package registry.
- **Fix/Improvement**: Replaced shell-based file hashing with pure-Dart crypto for better cross-platform (Windows) compatibility.
- **Security/CI Hardening**: Masked sensitive tokens in CI logs (`::add-mask::`), reduced checkout depth to 1 for faster executions, and migrated away from hardcoded `/tmp/` to `$RUNNER_TEMP` for Windows support.
- **CI Improvement**: Added artifact uploading on test failure to aid in diagnostics.
- **Testing**: Added extensive test suite (`69-test`) covering `WorkflowGenerator.validate()` and `loadCiConfig()`.
- **Fix**: Normalized CRLF to LF in `_preserveUserSections` to prevent silent data loss on Windows.

**Breaking Changes**:
- None

**New Features**:
- `build_runner` feature flag support in CI configs (`.runtime_ci/config.json`).
- `audit-all` CLI command for sweeping monorepo directory audits.

**References**:
- PR #23: fix: comprehensive audit fixes - cross-platform hashing, CI hardening, test suite
- feat: add build_runner feature flag for CI codegen


## Changelog

## [0.14.0] - 2026-02-24

### Added
- Added `build_runner` feature flag for CI codegen to generate `.g.dart` files in CI instead of relying on local developer builds
- Added `manage_cicd audit` and `audit-all` commands for `pubspec.yaml` dependency validation against `external_workspace_packages.yaml` registry (refs open-runtime/aot_monorepo#411) (#22)
- Added sibling dependency conversion and per-package tag creation for multi-package releases, automatically converting bare sibling dependencies during release (#22)
- Used org-managed runners as default platform definitions for Linux (`ubuntu-x64`/`arm64`) and Windows (`windows-x64`/`arm64`)

### Changed
- Updated CI workflow templates and generator with latest patterns and removed deprecated config entries from templates (#22)

### Fixed
- Fixed cross-platform hashing in `template_manifest.dart` using pure-Dart crypto and normalized CRLF to LF to prevent data loss on Windows (#23, fixes #5, #8, #10, #11, #12, #13)
- Added strict input validation for `dart_sdk`, `feature` keys, `sub_packages`, and hardened triage config `require_file` to prevent path traversal
- Replaced shell-based hashing with pure-Dart crypto in autodoc to ensure caching works on macOS, Windows, and minimal CI images
- Normalized version input by stripping the leading 'v' prefix and validated SemVer in `create-release`
- Fixed passing `allFindings` to `fixPubspec` and added `pub_semver` dependency
- Validated YAML before writing and created backups in pubspec auditor to prevent corruption (#22)
- Fixed tag existence checks by using `refs/tags/` prefix and handled errors for per-package tags (#22)
- Increased test process timeout from 30 to 45 minutes to fix Windows named pipe tests on CI runners (#22)
- Added `yaml_edit` dependency required for pubspec auditor

### Security
- Added `::add-mask::` token masking before `git config` in all CI workflow locations to prevent Personal Access Token (PAT) leaks in logs, added `fetch-depth: 1` to checkout steps, and fixed analysis cache key drift (#23)

---
[Full Changelog](https://github.com/open-runtime/runtime_ci_tooling/compare/v0.13.0...v0.14.0)
