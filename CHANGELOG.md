# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.14.3] - 2026-03-03

### Changed
- Refactored GitHub Actions workflows to pass context variables via env variables rather than command-line string interpolation

### Fixed
- Increased release pipeline timeout from 60 to 120 minutes to prevent Autodoc and compose-artifacts from timing out during Gemini-powered documentation generation

### Security
- Extracted GitHub tokens and PATs into environment variables instead of inlining them in shell scripts to prevent credential exposure in logs or potential shell injection vulnerabilities (fixes #33)

## [0.14.1] - 2026-02-24

### Added
- Added operation logging for git config, git add, and pubspec writes (#28, fixes #26)

### Changed
- Converted shell-interpolated git commands to safe Process.runSync array args (#28)
- Replaced silent catch blocks with Logger.warn() to ensure errors are visible in CI logs (#28)
- Scoped CI auto-format `git add -A` to `git add lib/` in skeleton template to prevent staging unrelated files (#28)
- Regenerated CI workflow to use correct self-hosted runner names and bumped generated version stamp

### Fixed
- Fixed token and secrets leak in verbose logging by redacting matching patterns (#28)
- Fixed shell injection vulnerabilities by eliminating shell interpolation via config-controlled path and tag values (#28)
- Fixed template bug using `matrix.os` instead of `matrix.platform_id` for artifact naming
- Fixed staging issue related to unrelated files being added during format (#28, fixes #25, #26, #27)

### Security
- Redact GitHub PATs, generic auth tokens, and embedded credentials in URLs from verbose logging output (#28)
- Eliminate shell injection vulnerabilities by migrating git execution to safe Process.runSync with array arguments (#28)

## [0.14.0] - 2026-02-24

### Added
- Added `build_runner` feature flag for CI codegen to generate `.g.dart` files in CI instead of relying on local developer builds
- Added `manage_cicd audit` and `audit-all` commands for `pubspec.yaml` dependency validation against `external_workspace_packages.yaml` registry (refs open-runtime/aot_monorepo#411) (#22)
- Added sibling dependency conversion and per-package tag creation for multi-package releases, automatically converting bare sibling dependencies during release (#22)
- Used org-managed runners as default platform definitions for Linux (`ubuntu-x64`/`arm64`) and Windows (`windows-x64`/`arm64`)

### Changed
- Updated CI workflow templates and generator with latest patterns and removed deprecated config entries from templates (#22)

### Fixed
- Fixed cross-platform hashing in `template_manifest.dart` using pure-Dart crypto and normalized CRLF to LF to prevent data loss on Windows (#23, fixes #5, #8, #10, #11, #12, #13)
- Added strict input validation for `dart_sdk`, `feature` keys, `sub_packages`, and hardened triage config `require_file` to prevent path traversal
- Replaced shell-based hashing with pure-Dart crypto in autodoc to ensure caching works on macOS, Windows, and minimal CI images
- Normalized version input by stripping the leading 'v' prefix and validated SemVer in `create-release`
- Fixed passing `allFindings` to `fixPubspec` and added `pub_semver` dependency
- Validated YAML before writing and created backups in pubspec auditor to prevent corruption (#22)
- Fixed tag existence checks by using `refs/tags/` prefix and handled errors for per-package tags (#22)
- Increased test process timeout from 30 to 45 minutes to fix Windows named pipe tests on CI runners (#22)
- Added `yaml_edit` dependency required for pubspec auditor

### Security
- Added `::add-mask::` token masking before `git config` in all CI workflow locations to prevent Personal Access Token (PAT) leaks in logs, added `fetch-depth: 1` to checkout steps, and fixed analysis cache key drift (#23)

## [0.13.0] - 2026-02-24

### Added
- Added multi-package support for analyze, test, autodoc, changelog, and release commands (#18, fixes #17)
- Added multi-platform CI matrix generation with `ci.platforms` and `ci.runner_overrides` config (#18, fixes #14, fixes #20)
- Added custom CI/CD step injection for consumer-specific workflows via `extra-jobs` and `post-test` user sections (fixes #16)

### Changed
- Updated `.gitignore` with `custom_lint.log`, `.dart_tool/`, and `.claude/` entries

### Fixed
- Increased test process timeout from 20 to 30 minutes for slow named pipe tests on Windows CI
- Avoided queued self-hosted x64 runners by dropping x64 runner overrides for GitHub-hosted runners (#18)
- Removed debug leftover and redundant path normalization in post_release and autodoc_scaffold (#18)
- Addressed review findings: org guard, autodoc dedup, git diff fallback, and doc comments (#18)
- Added `--repo` to all `gh` commands and org allowlist to prevent upstream leakage in triage scripts (#18)
- Fixed early exit preventing sub-package execution, version bump silent no-op, variable shadowing, RangeError on underscores, and double-slash paths (#18)
- Fixed platform resolution deduplication and cast safety in `WorkflowGenerator` (fixes #6)
- Fixed cross-platform CI caching by including runner architecture in cache keys (fixes #7)

## [0.12.2] - 2026-02-24

### Added
- Multi-package support for analyze, test, autodoc, changelog, and release commands
- Extended platform matrix with explicit arch-qualified IDs: `ubuntu-x64`, `ubuntu-arm64`, `windows-x64`, `windows-arm64`
- `runner_overrides` config field to map platform IDs to custom org-managed runner labels

### Fixed
- Add `--repo` to all `gh` commands and org allowlist to prevent upstream leakage in triage
- Remove `|| true` debug leftover and redundant path normalization
- Avoid queued self-hosted x64 runners by preferring GitHub-hosted defaults
- Increase test process timeout from 20 to 30 minutes

## [0.12.0] - 2026-02-24

### Added
- Added an auto-format CI job that automatically commits dart formatting before analyze and test jobs

### Changed
- Replaced the old format_check validation step with the new auto-format job in CI workflow and skeleton
- Updated update-all command to prefer globally activated manage_cicd binary over dart run to prevent resolution workspace issues

### Fixed
- Fixed template resolution to walk Platform.script ancestors to find templates when running as a globally activated binary

## [0.11.3] - 2026-02-24

### Fixed
- Stream test output in real-time by using Process.start with inheritStdio, and add a 20-minute process-level timeout to catch test hangs

## [0.11.2] - 2026-02-23

### Fixed
- Fixed triage CLI failing with UsageException when given a bare issue number instead of routing to the single subcommand

## [0.11.1] - 2026-02-23

### Changed
- Refresh consumer manifests for workspace enable-all, updating tracked pubspec snapshots and root dependency metadata

### Fixed
- Replace deprecated macos-13 runner with macos-15-intel for Intel x64 macOS testing

## [0.11.0] - 2026-02-23

### Added
- Multi-platform CI workflow generation supporting configurable platform matrices via config.json's ci.platforms array

## [0.10.0] - 2026-02-22

### Added
- Added investigationResults to TriageDecision serialization to prevent data loss (#4)
- Added balanced bracket-counting JSON extraction replacing indexOf("{") (#4)
- Added logging/comments to 22 empty catch blocks across 13 files (#4)

### Changed
- Aligned agent output paths with investigate.dart read paths via resultsDir (#4)
- Deduplicated kCiConfigFiles and kStage1Artifacts into ci_constants.dart (#4)
- Centralized temporary paths via kStagingDir constant (env-overridable) (#4)
- Used config.triagedLabel and config.releaseNotesPath instead of hardcoded values in verify.dart and link.dart (#4)
- Replaced Ruby YAML validation with package:yaml in validate_command (#4)
- Replaced exit(1) with GeminiPrerequisiteError exceptions in gemini_utils (#4)
- Threw FormatException on unknown agent type instead of silent fallback (#4)

### Fixed
- Replaced firstWhere+.first fallback with firstOrNull+skip to prevent wrong-issue processing in investigate.dart and cross_repo_link.dart (#4, fixes #4)
- Replaced greedy regex with bracket-counting JSON extraction (#4, fixes #4)

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

## [0.9.1] - 2026-02-22

### Changed
- Improved performance by adding true parallel execution with rate-limit retry for autodoc generation (fixes #3)
- Improved the retry mechanism in autodoc to cover transient network errors such as connection resets and timeouts

### Removed
- Removed stale root-level orphaned documentation files (QUICKSTART.md and API_REFERENCE.md) since autodoc now writes to module-scoped paths

### Fixed
- Fixed pipeline bugs including duration logging accuracy, replaced unreliable file writing tools with shell commands in the explorer, and updated audit paths for triage runs (fixes #4)

## [0.9.0] - 2026-02-22

### Added
- Added `update-all` command to batch-update managed packages
- Added concurrent workers, GitHub code search prefilter, and snapshot identity to the `consumers` command
- Extended pre-commit hook to detect and strip `resolution: workspace` from staged `pubspec.yaml` files

### Changed
- Updated consumer package metadata to include `usage_signals` and snapshot tests
- Bumped `autodoc` and `compose-artifacts` CI timeouts to 60 minutes
- Changed version bump logic to ensure all commit types trigger at least a patch release

### Fixed
- Fixed standalone CI compatibility by removing `resolution: workspace` from `pubspec.yaml`
- Fixed `create-release` command to handle concurrent Autodoc commits using `git pull --rebase`
- Prevented LFS clone failures in CI templates by adding `GIT_LFS_SKIP_SMUDGE=1` to `dart pub get` steps
- Guaranteed required CI artifacts exist by adding shell fallbacks and removing `continue-on-error`
- Reverted formatting regressions in `consumers_command.dart`

## [0.8.0] - 2026-02-22

### Added
- Added `update` command for intelligently syncing templates (commands, settings, workflows, configs) to consumer repos
- Config-driven CI workflow generation via `ci` section in `config.json`
- `WorkflowGenerator` class with Mustache-based skeleton rendering (`ci.skeleton.yaml`)
- User-preservable sections (`# --- BEGIN USER / END USER ---`) survive workflow regeneration
- `ci` section defaults in `init` command for new consumers
- Strict type validation for all `ci` config fields (dart_sdk, features, secrets, pat_secret, line_length)
- `HookInstaller` utility and automatic git pre-commit hook installation in `init` and `update` commands — only staged `lib/` Dart files are formatted; existing custom hooks are backed up before replacement; hook respects consumer's `line_length` config

### Changed
- Replaced monolithic `ci.template.yaml` with config-driven `ci.skeleton.yaml`
- Fixed formatting in `update_options.g.dart`

## [0.7.1] - 2026-02-22

### Fixed
- Copied `docs/` and `autodoc.json` from artifacts in create-release

## [0.7.0] - 2026-02-22

### Added
- Added `autodoc.json` generation support in the `init` command

### Changed
- Fixed formatting in `init_command.dart` and `autodoc_api_reference_prompt.dart`

### Fixed
- Completed unfinished autodoc prompt implementations
- Corrected Gemini model ID to `gemini-3.1-pro-preview` to resolve `ModelNotFoundError` in AI-powered pipeline stages

## [0.6.0] - 2026-02-22

### Breaking Changes
- **BREAKING**: Removed package executables (bin/manage_cicd.dart). The CLI must now be invoked via scripts/.
  - Migration: Use `dart run scripts/manage_cicd.dart` instead of `dart run runtime_ci_tooling:manage_cicd`.
- **BREAKING**: Updated CI template secret names and removed SendGrid/LFS support.
  - Migration: Update GitHub Actions workflows to use new secret names (e.g., GEMINI_API_KEY instead of CICD_GEMINI_API_KEY_OPEN_RUNTIME) and remove LFS configuration if not needed.

### Added
- Added script wrappers in scripts/ for local execution
- Added build_cli and build_runner dependencies

### Changed
- Refactored CLI argument parsing to use typed options (build_cli)
- Updated CI workflow templates with new secret mappings and script paths

### Removed
- Removed bin/ executables (manage_cicd, triage_cli) in favor of scripts/
- Removed USAGE.md and SETUP.md documentation
- Removed SendGrid API keys and LFS configuration from CI template

## [0.5.0] - 2026-02-16

### Added
- Added comprehensive SETUP.md and USAGE.md documentation (commit bbe1e27)
- Added SendGrid Email Validation API key to CI template (commit 28cfa58)

### Fixed
- Fixed CI checkout to include LFS files so test assets are downloaded (commit a3996c9)

## [0.4.1] - 2026-02-16

### Changed
- Removed support for the `[Unreleased]` changelog section to streamline automated releases (commit ea5608f)

## [0.4.0] - 2026-02-16

### Changed
- Replaced wrapper scripts with `bin/` executables for zero-boilerplate portability (commit 53149d9)
- Moved `autodoc.json` configuration to `.runtime_ci/` directory (auto-migrates from legacy location) (commit 6f54632)

### Fixed
- Fixed `git add` failure in release process by adding files individually (commit 1d45361)

[0.14.3]: https://github.com/open-runtime/runtime_ci_tooling/compare/v0.14.1...v0.14.3
[0.14.1]: https://github.com/open-runtime/runtime_ci_tooling/compare/v0.14.0...v0.14.1
[0.14.0]: https://github.com/open-runtime/runtime_ci_tooling/compare/v0.13.0...v0.14.0
[0.13.0]: https://github.com/open-runtime/runtime_ci_tooling/compare/v0.12.2...v0.13.0
[0.12.2]: https://github.com/open-runtime/runtime_ci_tooling/compare/v0.12.0...v0.12.2
[0.12.0]: https://github.com/open-runtime/runtime_ci_tooling/compare/v0.11.3...v0.12.0
[0.11.3]: https://github.com/open-runtime/runtime_ci_tooling/compare/v0.11.2...v0.11.3
[0.11.2]: https://github.com/open-runtime/runtime_ci_tooling/compare/v0.11.1...v0.11.2
[0.11.1]: https://github.com/open-runtime/runtime_ci_tooling/compare/v0.11.0...v0.11.1
[0.11.0]: https://github.com/open-runtime/runtime_ci_tooling/compare/v0.10.0...v0.11.0
[0.10.0]: https://github.com/open-runtime/runtime_ci_tooling/compare/v0.9.2...v0.10.0
[0.9.2]: https://github.com/open-runtime/runtime_ci_tooling/compare/v0.9.1...v0.9.2
[0.9.1]: https://github.com/open-runtime/runtime_ci_tooling/compare/v0.9.0...v0.9.1
[0.9.0]: https://github.com/open-runtime/runtime_ci_tooling/compare/v0.8.0...v0.9.0
[0.8.0]: https://github.com/open-runtime/runtime_ci_tooling/compare/v0.7.1...v0.8.0
[0.7.1]: https://github.com/open-runtime/runtime_ci_tooling/compare/v0.7.0...v0.7.1
[0.7.0]: https://github.com/open-runtime/runtime_ci_tooling/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/open-runtime/runtime_ci_tooling/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/open-runtime/runtime_ci_tooling/compare/v0.4.1...v0.5.0
[0.4.1]: https://github.com/open-runtime/runtime_ci_tooling/compare/v0.4.0...v0.4.1
[0.4.0]: https://github.com/open-runtime/runtime_ci_tooling/releases/tag/v0.4.0
