# runtime_ci_tooling v0.10.0

# Version Bump Rationale

**Decision:** minor

**Why:** The recent changes introduce new additive features and configurable parameters (cross-platform staging directory overrides, new optional parameters on exposed agent tasks, new fields on public models) along with a suite of critical bug fixes. There are no breaking changes to public APIs.

**Key Changes:**
* Replaced hardcoded `/tmp/` paths with a configurable cross-platform `kStagingDir` that falls back to `Directory.systemTemp.path` and can be overridden via the `CI_STAGING_DIR` environment variable.
* Added `investigationResults` to `TriageDecision` serialization and public models to expose underlying data and prevent data loss.
* Added optional `resultsDir` parameter to `buildTask` across all exposed agent files to support custom output paths.
* Resolved critical data integrity bugs by replacing `.firstWhere` fallbacks with `.firstOrNull` (or `.where(...).firstOrNull`) to prevent the triage pipeline from acting on the wrong issues.
* Improved JSON parsing with bracket-counting extraction to prevent greedy regex bugs.
* Replaced process-killing `exit(1)` with a custom `GeminiPrerequisiteError` exception in internal utilities to improve library usage stability.
* Updated validation routines to dynamically query properties (e.g., `config.triagedLabel` and `config.releaseNotesPath`) rather than relying on hardcoded strings.

**New Features:**
* Environment variable control over staging directories (`CI_STAGING_DIR`).
* Access to aggregated `investigationResults` within parsed `TriageDecision` objects.
* Ability to pass custom `resultsDir` to exposed agent configurations.

**Breaking Changes:**
* None

**References:**
* open-runtime/runtime_ci_tooling#4
* Commits: C1-C5, H1-H11, M3-M12


## Changelog

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

---
[Full Changelog](https://github.com/open-runtime/runtime_ci_tooling/compare/v0.9.2...v0.10.0)
