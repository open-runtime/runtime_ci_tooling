# runtime_ci_tooling v0.16.0

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


## Changelog

## [0.16.0] - 2026-03-04

### Added
- Added `manage_cicd update --diff` preview support and configurable CI Git URL rewrite orgs via `ci.git_orgs` (#36)
- Added multi-package hierarchical context/instructions for `documentation` and `autodoc`, including package-aware autodoc output pathing and a generated `docs/README.md` index (#36)

### Changed
- Deduplicated shared CI workflow setup/analysis/proto blocks via mustache partials to keep generated workflows consistent and maintainable (#36)
- Formatted codebase with `dart format --line-length 120` (#36)

### Fixed
- Fixed autodoc output path drift (#36)
- Ensured `update --diff` previews on local-customization skips with hardened path normalization across platforms (#36, fixes #38)
- Moved hierarchical autodoc index output to a non-destructive generated file (#36)
- Expanded regression coverage for `TestCommand` timeout/failure edge paths and added tests for new workflow generator and sub-package utility behaviors (#36, fixes #39)
- Confirmed issue #30 is resolved via streaming NDJSON parse in `TestResultsUtil` (#36)

---
[Full Changelog](https://github.com/open-runtime/runtime_ci_tooling/compare/v0.15.0...v0.16.0)
