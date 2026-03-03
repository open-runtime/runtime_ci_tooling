# runtime_ci_tooling v0.14.2

> Bug fix release — 2026-03-03

## Bug Fixes

- **Runner Infrastructure Optimization** — Reconfigured the CI workflows via `.runtime_ci/config.json` to utilize standard GitHub-hosted runners (`ubuntu-latest` and `windows-latest`) for x64 architecture builds instead of large self-hosted infrastructure. This prevents long queue times associated with heavy self-hosted runners.
- **Dependency Alignment** — Aligned post-merge package dependency versions (`encrypt`, `grpc`, `runtime_isomorphic_library`, `image`, and `sentry`) across all consumer manifests to ensure a synchronized monorepo state.

## Upgrade

```bash
dart pub upgrade runtime_ci_tooling
```

## Issues Addressed

- [#32](https://github.com/open-runtime/runtime_ci_tooling/issues/32) — Expand TestCommand test coverage: timeout, failure, and sub-package paths (confidence: 0%)
- [#21](https://github.com/open-runtime/runtime_ci_tooling/issues/21) — Hierarchical autodoc + documentation for multi-package repos (confidence: 0%)
## Contributors

Thanks to everyone who contributed to this release:
- @tsavo-at-pieces
## Full Changelog

[v0.14.1...v0.14.2](https://github.com/open-runtime/runtime_ci_tooling/compare/v0.14.1...v0.14.2)
