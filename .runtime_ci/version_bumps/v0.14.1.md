# Version Bump Rationale

**Decision**: patch
**Reasoning**: The commits since the last release tag (v0.14.0) consist entirely of bug fixes, security patches, and chore updates. There are no breaking changes to public APIs, nor are there any additive new features. According to semantic versioning principles, security patches and bug fixes dictate a patch release.

**Key Changes**:
- **Security**: Prevented token leaks by redacting GitHub PATs and secrets from verbose logs in `CiProcessRunner`.
- **Security**: Eliminated shell injection risks by converting shell-interpolated git commands to safe `Process.runSync` array arguments in release and sub-package utilities.
- **Bug Fix**: Regenerated the CI workflow template to use the correct self-hosted runner names (`runtime-ubuntu-24.04-x64-256gb-64core` and `runtime-windows-2025-x64-256gb-64core`).
- **Bug Fix**: Fixed a bug in the skeleton template for artifact naming (`matrix.os` replaced with `matrix.platform_id`).
- **Bug Fix**: Scoped the automated formatting `git add -A` to `git add lib/` in the CI skeleton to prevent staging unrelated files.
- **Maintenance**: Added operation logging and replaced silent error swallowing with visible `Logger.warn()` calls to improve CI observability.

**Breaking Changes**:
- None.

**New Features**:
- None.

**References**:
- PR #28 (sec: fix token leak, shell injection, and add operation logging)
- PR/Issues #25, #26, #27
