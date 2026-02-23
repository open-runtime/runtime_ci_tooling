# runtime_ci_tooling v0.11.1

> Bug fix release — 2026-02-23

## Bug Fixes

- **Update CI Runner for macOS** — Replaced the deprecated `macos-13` GitHub Actions runner with the new `macos-15-intel` runner for Intel x64 macOS testing.
- **Refresh Consumer Manifests** — Updated tracked `pubspec.yaml` snapshots in the `.consumers` directory to reflect the workspace `enable-all` state, tracking newer dependency versions.

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

[v0.11.0...v0.11.1](https://github.com/open-runtime/runtime_ci_tooling/compare/v0.11.0...v0.11.1)
