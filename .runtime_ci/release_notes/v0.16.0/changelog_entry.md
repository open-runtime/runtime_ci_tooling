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