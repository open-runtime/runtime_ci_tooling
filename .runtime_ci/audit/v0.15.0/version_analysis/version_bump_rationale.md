# Version Bump Rationale

- **Decision**: minor
- **Why**: The release includes new features and expands the public API surface with new utility classes and methods, but does not introduce any breaking changes to existing public APIs.

**Key Changes**:
- Added `web_test` feature, `build_runner` support, and enhanced managed test capabilities with full output capture and rich job summaries.
- Added new public APIs: `TestResultsUtil`, `TestResults`, `TestFailure`, new methods in `RepoUtils`, `Utf8BoundedBuffer`, and `exitWithCode`.
- Standardized Windows `pub-cache` paths, made artifact retention configurable, improved stream parsing performance (async line-by-line parsing), and hardened CI workflow generation and test execution boundaries.
- Improved process timeout controls, bounds on output capture, and added safe path evaluation.

**Breaking Changes**:
- None. (Internal changes to `CiProcessRunner.exec` return type from `void` to `Future<void>` in an `abstract final` class are source-compatible for callers, and `StepSummary.write` added a backwards-compatible optional named parameter).

**New Features**:
- Added web_test support and build_runner support.
- Configurable artifact retention policy and robust log capture system via bounding buffers.

**References**:
- PR #29: `feat: add web_test, build_runner, and enhanced managed test`
- Commits adding public utilities and docs: `fix: standardize Windows pub-cache paths, make artifact retention configurable, update docs`, `feat: enhanced managed test with full output capture and rich job summaries`, `fix: stream test result parsing and harden test command exits`.
