- **Decision**: patch
  - The changes consist of updating consumer manifest snapshots and replacing a deprecated GitHub Actions macOS runner for Intel x64 (`macos-13` to `macos-15-intel`). These are purely internal CI and maintenance updates with no changes to the public API surface.

- **Key Changes**:
  - Refreshed consumer manifest snapshots in the `.consumers` directory to reflect the workspace `enable-all` state.
  - Updated the internal `_platformRunners` map in `lib/src/cli/utils/workflow_generator.dart` to use `macos-15-intel` instead of the deprecated `macos-13` runner.

- **Breaking Changes**: None

- **New Features**: None

- **References**:
  - `chore: refresh consumer manifests for workspace enable-all`
  - `fix: replace deprecated macos-13 runner with macos-15-intel`