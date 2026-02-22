# Version Bump Rationale

**Decision**: minor

**Why**: Several new features have been added since `v0.8.0`, most notably the `update-all` subcommand, config-driven CI workflow generation, and a pre-commit hook that manages `resolution: workspace`. These changes constitute additive functionality without introducing any breaking changes to the public API surface. Per the provided instructions, adding new features requires a `minor` version bump.

## Key Changes
*   **Update-all command**: Added the `manage_cicd update-all` subcommand for batch-updating managed packages recursively using a concurrent worker pool.
*   **Consumers improvements**: Added a search-first prefilter, snapshot identity capabilities, and concurrent processing to the `consumers` tooling.
*   **Config-driven workflows**: Implemented config-driven CI workflow generation with strict validation.
*   **Standalone CI compatibility**: Stripped `resolution: workspace` from `pubspec.yaml` to fix the standalone CI, reinforced by a new pre-commit hook.
*   **Release process stability**: Handled non-fast-forward failures in `create-release` by rebasing against concurrent Autodoc commits.

## Breaking Changes
*   None

## New Features
*   `update-all` subcommand to batch-update managed packages (`b270aca`).
*   Concurrent workers, search-first prefilter, and snapshot identity for consumers (`790203c`).
*   Pre-commit hook to dynamically strip `resolution: workspace` from `pubspec.yaml` (`bb02d64`).
*   Config-driven CI workflow generation with strict validation (`e82b0a5`).

## References
*   `b270aca` feat: add update-all command to batch-update managed packages
*   `e82b0a5` feat: config-driven CI workflow generation with strict validation
*   `790203c` feat: consumers — concurrent workers, search-first prefilter, snapshot identity
*   `bb02d64` feat: pre-commit hook strips resolution: workspace from pubspec.yaml
*   `2cd34b3` fix: remove resolution: workspace from pubspec.yaml (breaks standalone CI)
*   `08b4af3` fix: pull --rebase before push in create-release to handle concurrent Autodoc commits
