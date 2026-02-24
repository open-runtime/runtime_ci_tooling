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
