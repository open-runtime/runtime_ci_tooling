# runtime_ci_tooling v0.11.3

> Bug fix release — 2026-02-24

## Bug Fixes

- **Stream Test Output & Add Timeout** — Replaced `Process.runSync` with `Process.start` using `ProcessStartMode.inheritStdio` to stream test output in real-time, preventing logs from being buffered indefinitely. Added a 20-minute process-level timeout to `TestCommand` to automatically catch and kill hanging test runs.

## Upgrade

```bash
dart pub upgrade runtime_ci_tooling
```

## Contributors

Thanks to everyone who contributed to this release:
- @tsavo-at-pieces
## Issues Addressed

No linked issues for this release.
## Full Changelog

[v0.11.2...v0.11.3](https://github.com/open-runtime/runtime_ci_tooling/compare/v0.11.2...v0.11.3)
