# runtime_ci_tooling v0.16.1

> Bug fix release — 2026-03-11

## Bug Fixes

- **Updated Gemini references** — Updated human-readable display strings, CLI descriptions, and documentation to correctly reference the "Gemini 3.1 Pro Preview" model ID. ([#40](https://github.com/open-runtime/runtime_ci_tooling/pull/40), [#41](https://github.com/open-runtime/runtime_ci_tooling/pull/41))
- **Fixed CI workflow golden test** — Regenerated `.github/workflows/ci.yaml` to match the current v0.16.0 tooling version, fixing the golden file test. ([#41](https://github.com/open-runtime/runtime_ci_tooling/pull/41))

## Upgrade

```bash
dart pub upgrade runtime_ci_tooling
```

## Contributors

Thanks to everyone who contributed to this release:
- @tsavo-at-pieces
## Issues Addressed

- [#41](https://github.com/open-runtime/runtime_ci_tooling/issues/41) — fix: add Preview suffix to Gemini references and regenerate CI workflow (confidence: 100%)
- [#40](https://github.com/open-runtime/runtime_ci_tooling/issues/40) — fix: update Gemini model references to 3.1 Pro (confidence: 100%)
## Full Changelog

[v0.16.0...v0.16.1](https://github.com/open-runtime/runtime_ci_tooling/compare/v0.16.0...v0.16.1)
