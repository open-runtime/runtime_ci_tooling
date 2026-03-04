## [0.14.3] - 2026-03-03

### Changed
- Refactored GitHub Actions workflows to pass context variables via env variables rather than command-line string interpolation

### Fixed
- Increased release pipeline timeout from 60 to 120 minutes to prevent Autodoc and compose-artifacts from timing out during Gemini-powered documentation generation

### Security
- Extracted GitHub tokens and PATs into environment variables instead of inlining them in shell scripts to prevent credential exposure in logs or potential shell injection vulnerabilities (fixes #33)