# Version Bump Rationale

**Decision**: patch

The changes introduced since `v0.9.0` consist entirely of bug fixes, performance optimizations, and documentation cleanup. No new features were added, and no breaking changes were made to the public API or CLI surface.

**Key Changes**:
- **Bug Fixes**: Fixed an issue where the Gemini CLI `write_file` tool was unreliable during Stage 1 exploration by explicitly instructing the model to use shell commands (`mkdir`, `tee`, `cat`).
- **Bug Fixes**: Corrected hardcoded path references from `.cicd_runs` to `.runtime_ci/runs` across the triage and release notes pipelines to ensure consistency.
- **Bug Fixes**: Replaced the deprecated `stats['session']['duration']` with a wall-clock `Stopwatch` in `compose` and `release_notes` commands for accurate duration reporting.
- **Performance**: Replaced `Process.runSync` with `Process.run` in the autodoc command to enable true parallel execution.
- **Performance**: Implemented an asynchronous worker pool (`_forEachConcurrent`) to keep concurrent generation tasks at maximum capacity.
- **Resilience**: Extended retry logic in the autodoc command to catch transient network errors (`fetch failed`, `ECONNRESET`, `ETIMEDOUT`, etc.) in addition to rate limits.
- **Chore/Docs**: Removed orphaned root-level documentation files (`docs/QUICKSTART.md` and `docs/API_REFERENCE.md`) since docs are now auto-generated into module-scoped subdirectories.
- **Chore/CI**: Bumped the CI workflow version stamp.

**Breaking Changes**: None

**New Features**: None

**References**:
- Commits: `fix: pipeline bugs...`, `fix(autodoc): extend retry...`, `chore(docs): remove stale...`, `fix(release): Stage 1 artifacts path...`, `perf(autodoc): true parallel execution...`
