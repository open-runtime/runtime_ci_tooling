## [0.9.2] - 2026-02-22

### Added
- Added automatic scaffolding of `autodoc.json` during `autodoc --init` based on `lib/src/` structure (fixes #2)
- Added `runtime_ci_tooling` generated files

### Changed
- Completed `.cicd_runs` → `.runtime_ci/runs` path migration in CLI tools, agent scripts, and prompt files

### Fixed
- Fixed `autodoc --init` failing or acting as a no-op (fixes #2)
- Fixed heredoc `JSONEOF` terminator indentation in `gemini_changelog_prompt.dart` to prevent `tee` from hanging
- Fixed retry log message in `autodoc_command.dart` to be generic for all errors instead of claiming rate limiting, and fixed environment spread consistency