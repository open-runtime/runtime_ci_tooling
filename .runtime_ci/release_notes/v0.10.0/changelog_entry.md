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