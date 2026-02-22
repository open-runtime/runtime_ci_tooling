## [0.9.0] - 2026-02-22

### Added
- Added `update-all` command to batch-update managed packages
- Added concurrent workers, GitHub code search prefilter, and snapshot identity to the `consumers` command
- Extended pre-commit hook to detect and strip `resolution: workspace` from staged `pubspec.yaml` files

### Changed
- Updated consumer package metadata to include `usage_signals` and snapshot tests
- Bumped `autodoc` and `compose-artifacts` CI timeouts to 60 minutes
- Changed version bump logic to ensure all commit types trigger at least a patch release

### Fixed
- Fixed standalone CI compatibility by removing `resolution: workspace` from `pubspec.yaml`
- Fixed `create-release` command to handle concurrent Autodoc commits using `git pull --rebase`
- Prevented LFS clone failures in CI templates by adding `GIT_LFS_SKIP_SMUDGE=1` to `dart pub get` steps
- Guaranteed required CI artifacts exist by adding shell fallbacks and removing `continue-on-error`
- Reverted formatting regressions in `consumers_command.dart`