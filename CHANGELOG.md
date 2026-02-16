# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.4.0] - 2026-02-16

### Changed
- Replaced wrapper scripts with `bin/` executables for zero-boilerplate portability (commit 53149d9)
- Moved `autodoc.json` configuration to `.runtime_ci/` directory (auto-migrates from legacy location) (commit 6f54632)

### Fixed
- Fixed `git add` failure in release process by adding files individually (commit 1d45361)

[Unreleased]: https://github.com/open-runtime/runtime_ci_tooling/compare/v0.4.0...HEAD
[0.4.0]: https://github.com/open-runtime/runtime_ci_tooling/releases/tag/v0.4.0
