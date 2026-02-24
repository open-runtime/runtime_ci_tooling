# Version Bump Rationale

- **Decision**: patch. The changes are bug fixes and internal improvements to the test command. No public API surface was changed.
- **Key Changes**:
  - Replaced `Process.runSync` with `Process.start` using `ProcessStartMode.inheritStdio` to stream test output in real-time.
  - Added a 20-minute process-level timeout to `TestCommand` to prevent test runs from hanging indefinitely.
- **Breaking Changes**: None.
- **New Features**: None.
- **References**: Commit `fix: stream test output and add process timeout to TestCommand`
