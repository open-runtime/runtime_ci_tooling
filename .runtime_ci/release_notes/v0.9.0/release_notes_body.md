# runtime_ci_tooling v0.9.0

> This minor release introduces the `update-all` command for batch-updating managed packages, significantly improves `consumers` tooling performance with search-based prefiltering and concurrent workers, and introduces config-driven CI workflow generation.

## Highlights

- **`update-all` Subcommand** — Batch-update managed packages recursively using a concurrent worker pool
- **Consumers Tooling Improvements** — Search-first prefilter via GitHub code search, concurrent processing, and snapshot identity
- **Config-Driven CI Workflows** — Generate GitHub Actions workflows from `.runtime_ci/config.json` while preserving user-customized sections
- **Standalone CI Compatibility** — A new pre-commit hook automatically strips `resolution: workspace` from staged `pubspec.yaml` files

## What's New

### `update-all` Command
Added the `manage_cicd update-all` subcommand to recursively discover and batch-update all packages under a root directory that have opted into `runtime_ci_tooling`. It supports concurrent worker pools (configurable via `--concurrency`) and passes through all `update` flags like `--force`, `--workflows`, and `--backup`.

```bash
# Update all managed packages with 8 concurrent workers
manage_cicd update-all --concurrency 8 --workflows
```

### Consumers Performance Improvements
The `consumers` command now features a `--search-first` prefilter that uses GitHub code search to identify candidate repositories, drastically reducing API calls. It also utilizes concurrent workers (`--discovery-workers` and `--release-workers`) for parallel processing and implements snapshot identity for workspace-portable resume logic.

### Config-Driven CI Workflow Generation
Replaced the monolithic `ci.template.yaml` with a Mustache-based `ci.skeleton.yaml` that renders dynamically based on the repository's `.runtime_ci/config.json`. This allows for strict type validation of CI configurations while preserving custom blocks wrapped in `# --- BEGIN USER ---` / `# --- END USER ---` markers across updates.

### Pre-commit Hook Enhancements
The installed git pre-commit hook now includes a second independent section that detects and removes the `resolution: workspace` field from staged `pubspec.yaml` files. This ensures that monorepo workspace configurations do not leak into standalone repositories where they would break CI workflows.

## Bug Fixes

- **Fixed standalone CI compatibility** — Removed `resolution: workspace` from `pubspec.yaml` to prevent "found no workspace root" errors in standalone CI ([2cd34b3](https://github.com/open-runtime/runtime_ci_tooling/commit/2cd34b3))
- **Release process stability** — Fixed `create-release` to handle concurrent Autodoc commits via `git pull --rebase` before pushing ([08b4af3](https://github.com/open-runtime/runtime_ci_tooling/commit/08b4af3))
- **LFS clone failures** — Added `GIT_LFS_SKIP_SMUDGE=1` to `dart pub get` steps in CI templates to prevent LFS pointer resolution issues ([7cee3b3](https://github.com/open-runtime/runtime_ci_tooling/commit/7cee3b3))
- **CI artifact guarantees** — Guaranteed required CI artifacts exist by removing `continue-on-error` from downloads and adding shell fallbacks ([8d077a2](https://github.com/open-runtime/runtime_ci_tooling/commit/8d077a2))
- **Version bump enforcement** — Ensured all commit types trigger at least a patch release in the automated pipeline ([bbd45d3](https://github.com/open-runtime/runtime_ci_tooling/commit/bbd45d3))
- **Formatting regressions** — Reverted unintended formatting changes in `consumers_command.dart` introduced by the pre-commit hook ([df8b211](https://github.com/open-runtime/runtime_ci_tooling/commit/df8b211))

## Issues Addressed

No linked issues for this release.
## Upgrade

```bash
dart pub upgrade runtime_ci_tooling
```

## Contributors

Thanks to everyone who contributed to this release:
- @tsavo-at-pieces
## Full Changelog

[v0.8.0...v0.9.0](https://github.com/open-runtime/runtime_ci_tooling/compare/v0.8.0...v0.9.0)
