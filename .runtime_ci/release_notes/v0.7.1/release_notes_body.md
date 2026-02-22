# runtime_ci_tooling v0.7.1

> Bug fix release — 2026-02-22

## Bug Fixes

- **Preserve generated documentation and hashes** — The `create-release` command now correctly copies the generated `docs/` directory and `.runtime_ci/autodoc.json` file from the CI artifacts directory to the repository root. Previously, these generated files were lost between pipeline jobs, resulting in missing documentation in the final release commit.

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

[v0.7.0...v0.7.1](https://github.com/open-runtime/runtime_ci_tooling/compare/v0.7.0...v0.7.1)
