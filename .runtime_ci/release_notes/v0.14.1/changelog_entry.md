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