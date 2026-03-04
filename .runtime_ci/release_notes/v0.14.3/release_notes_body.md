# runtime_ci_tooling v0.14.3

> Bug fix release — 2026-03-03

## Bug Fixes

- **Increase Release Pipeline Timeout** — Increased the release pipeline job timeout from 60 to 120 minutes in the CI workflows (`.github/workflows/release.yaml`) to prevent Autodoc and artifacts composition from timing out during Gemini-powered documentation generation.
- **Environment Variable Refactoring** — Extracted GitHub tokens (PATs) and workflow context variables (like `PREV_TAG` and `NEW_VERSION`) into safe environment variables instead of directly interpolating them into shell scripts. This prevents credential exposure in logs and eliminates potential shell injection vulnerabilities.

## Issues Addressed

- [#33](https://github.com/open-runtime/runtime_ci_tooling/issues/33) — Systematically harden CLI process trust boundaries (confidence: 90%)
## Upgrade

```bash
dart pub upgrade runtime_ci_tooling
```

## Contributors

Thanks to everyone who contributed to this release:
- @tsavo-at-pieces
## Full Changelog

[v0.14.2...v0.14.3](https://github.com/open-runtime/runtime_ci_tooling/compare/v0.14.2...v0.14.3)
