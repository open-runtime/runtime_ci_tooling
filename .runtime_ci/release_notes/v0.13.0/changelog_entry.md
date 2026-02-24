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