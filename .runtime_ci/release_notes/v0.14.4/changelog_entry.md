## [0.14.4] - 2026-03-03

### Changed
- Updated a comment in create-release to avoid using a CI skip token literal in commit text, allowing follow-up pushes to execute CI verification

### Fixed
- Added [skip ci] to the fallback merge commit message in create-release to prevent non-fast-forward recovery merges from spawning a new CI/release run that can cancel the active release