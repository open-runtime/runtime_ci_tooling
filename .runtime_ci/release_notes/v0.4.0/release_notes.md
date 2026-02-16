# runtime_ci_tooling v0.4.0

> This release introduces zero-boilerplate executables for easier tool usage and improves the robustness of the release process.

## Highlights

- **Zero-Boilerplate Executables** — New `bin/` executables allow direct usage without wrapper scripts.
- **Improved Release Reliability** — Fixed file staging to prevent partial release failures.
- **Automated Configuration Migration** — `autodoc.json` now lives in `.runtime_ci/` and auto-migrates.

## What's New

### Zero-Boilerplate Executables
Added `bin/manage_cicd.dart` and `bin/triage_cli.dart`. This allows direct execution of tools without generating wrapper scripts in the `scripts/` directory.

```bash
# New usage
dart run runtime_ci_tooling:manage_cicd
```

## Bug Fixes

- **Autodoc Configuration Migration** — `autodoc.json` is automatically migrated to `.runtime_ci/` if found in the root ([commit 6f54632](https://github.com/open-runtime/runtime_ci_tooling/commit/6f5463255a55e7a92f68ca9ac46061c5ccf4c75e))
- **Release Staging Reliability** — Fixed `git add` failure in release process by adding files individually ([commit 1d45361](https://github.com/open-runtime/runtime_ci_tooling/commit/1d45361026048d08790396009805988019056345))

## Issues Addressed

No linked issues for this release.
## Deprecations

- `scripts/` wrapper generation is deprecated. Use `bin/` executables directly.

## Upgrade

```bash
dart pub upgrade runtime_ci_tooling
```

## Contributors

Thanks to everyone who contributed to this release:
- @tsavo-at-pieces
## Full Changelog

[v0.3.0...v0.4.0](https://github.com/open-runtime/runtime_ci_tooling/compare/v0.3.0...v0.4.0)
