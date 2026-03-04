# Version Bump Rationale

- **Decision**: minor
- **Why**: This release introduces new capabilities and configuration options (new features) to the `runtime_ci_tooling` CLI and its generated artifacts, without introducing breaking changes to existing configurations or public APIs.

## Key Changes
- Added a new `--diff` flag to the `manage_cicd update` command to preview unified diffs for skipped or overwritten files.
- Introduced a `git_orgs` configuration option in `.runtime_ci/config.json` to configure git URL rewrites during CI checkout and dependency fetching.
- Enhanced `manage_cicd autodoc` to be sub-package aware, dynamically generating a non-destructive hierarchical documentation index (`docs/AUTODOC_INDEX.md`).
- Refactored `templates/github/workflows/ci.skeleton.yaml` to utilize mustache partials for shared CI workflow blocks (checkout, git config, dart setup, caching, analysis) to reduce duplication.
- Expanded validation and command tests to cover timeout and failing sub-package edge cases in managed CI workflows.

## Breaking Changes
- None.

## New Features
- CLI flag `update --diff` for previewing template differences.
- Configurable `git_orgs` URL rewriting for private repositories and sub-modules.
- Multi-package aware autodoc generation and structured index tracking.

## References
- PR #36: `fix: resolve PR #36 blockers and dedupe CI step templates`
- Commits: `feat: address runtime_ci_tooling open-issue backlog` and `feat: address open issue backlog in CI tooling`
