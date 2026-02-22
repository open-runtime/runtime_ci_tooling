## [0.9.1] - 2026-02-22

### Changed
- Improved performance by adding true parallel execution with rate-limit retry for autodoc generation (fixes #3)
- Improved the retry mechanism in autodoc to cover transient network errors such as connection resets and timeouts

### Removed
- Removed stale root-level orphaned documentation files (QUICKSTART.md and API_REFERENCE.md) since autodoc now writes to module-scoped paths

### Fixed
- Fixed pipeline bugs including duration logging accuracy, replaced unreliable file writing tools with shell commands in the explorer, and updated audit paths for triage runs (fixes #4)