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
