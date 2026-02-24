# runtime_ci_tooling v0.13.0

# Version Bump Rationale

**Decision**: minor

**Reasoning**: 
The commit history since the `v0.12.1` release introduces significant new functionality (`feat`), specifically multi-package support for CLI commands and multi-platform CI matrix generation capabilities. These are additive changes and do not introduce breaking API changes. Therefore, a MINOR version bump is appropriate.

**Key Changes**:
- Added multi-package support for CLI commands, allowing operations to cascade over sub-packages.
- Added multi-platform CI matrix generation capabilities including configurable `platforms` and `runner_overrides`.
- Increased testing timeouts for CI workflows from 20 to 30 minutes to mitigate pipeline instability.
- Removed debug leftovers in `post_release.dart`.
- Fixed redundant path normalization when dealing with sub-packages.
- Added GitHub organization safety guard (`_kAllowedOrgs`) to all triage action scripts to prevent unintended changes to upstream/unauthorized repositories.
- Enforced `--repo` flag on `gh` commands across all GitHub operations to avoid ambiguities originating from local git remotes in forked repositories.
- Fixed git diff fallbacks when operating without previous tags.

**Breaking Changes**:
- None.

**New Features**:
- Multi-package cascading for repository automation.
- Multi-platform CI matrix workflow generation.
- Organizational allowlisting to safeguard triage bot behaviors on non-allowlisted repositories.

**References**:
- PR #18: `feat/multi-package-support`
- Commits adding `multi-platform CI matrix generation`
- Bug fixes to CI and code robustness


## Changelog

## [0.13.0] - 2026-02-24

### Added
- Added multi-package support for analyze, test, autodoc, changelog, and release commands (#18, fixes #17)
- Added multi-platform CI matrix generation with `ci.platforms` and `ci.runner_overrides` config (#18, fixes #14, fixes #20)
- Added custom CI/CD step injection for consumer-specific workflows via `extra-jobs` and `post-test` user sections (fixes #16)

### Changed
- Updated `.gitignore` with `custom_lint.log`, `.dart_tool/`, and `.claude/` entries

### Fixed
- Increased test process timeout from 20 to 30 minutes for slow named pipe tests on Windows CI
- Avoided queued self-hosted x64 runners by dropping x64 runner overrides for GitHub-hosted runners (#18)
- Removed debug leftover and redundant path normalization in post_release and autodoc_scaffold (#18)
- Addressed review findings: org guard, autodoc dedup, git diff fallback, and doc comments (#18)
- Added `--repo` to all `gh` commands and org allowlist to prevent upstream leakage in triage scripts (#18)
- Fixed early exit preventing sub-package execution, version bump silent no-op, variable shadowing, RangeError on underscores, and double-slash paths (#18)
- Fixed platform resolution deduplication and cast safety in `WorkflowGenerator` (fixes #6)
- Fixed cross-platform CI caching by including runner architecture in cache keys (fixes #7)

---
[Full Changelog](https://github.com/open-runtime/runtime_ci_tooling/compare/v0.12.1...v0.13.0)
