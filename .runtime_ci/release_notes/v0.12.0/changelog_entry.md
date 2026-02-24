## [0.12.0] - 2026-02-24

### Added
- Added an auto-format CI job that automatically commits dart formatting before analyze and test jobs

### Changed
- Replaced the old format_check validation step with the new auto-format job in CI workflow and skeleton
- Updated update-all command to prefer globally activated manage_cicd binary over dart run to prevent resolution workspace issues

### Fixed
- Fixed template resolution to walk Platform.script ancestors to find templates when running as a globally activated binary