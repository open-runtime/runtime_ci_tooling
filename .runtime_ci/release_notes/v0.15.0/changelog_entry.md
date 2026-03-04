## [0.15.0] - 2026-03-04

### Added
- Added `web_test` CI feature with standalone ubuntu job, configurable concurrency, and test path filtering (#29)
- Enabled `build_runner` feature to run build_runner before analyze/test steps (#29)
- Enhanced managed test with full output capture and rich job summaries (#29)
- Added Utf8BoundedBuffer utility for testable byte-bounded stream capture (#29)
- Expanded workflow generator validation assertions and edge case tests (#29)

### Changed
- Made artifact retention days configurable via ci config (#29)
- Standardized Windows pub-cache paths to match release/triage templates (#29)
- Consolidated test utils into StepSummary and deleted standalone test_results_util (#29)
- Broadened CI dart formatting and safe staging to capture non-lib Dart edits (#29)

### Fixed
- Stabilized managed test verification across environments (fixes #31)
- Prevented release race and extended long-running release stages timeouts (#29)
- Hardened web_test for Ubuntu AppArmor userns restrictions (#29, fixes #35)
- Streamed test result parsing to avoid loading large NDJSON files into memory (#29)
- Tightened ci config validation rules for secrets and line lengths (#29)
- Hardened process execution and runtime config boundaries (#29)

### Security
- Hardened input validation, shell escaping, and symlink protection for all Mustache-interpolated values (#29)
- Added cumulative size guard to prevent exceeding GitHub step summary limit (#29)
- Guarded logDir creation and log file writes with FileSystemException catch blocks (#29)