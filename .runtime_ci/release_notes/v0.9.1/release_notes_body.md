# runtime_ci_tooling v0.9.1

> Bug fix release — 2026-02-22

## Bug Fixes

- **Performance Improvement in Autodoc** — Replaced blocking synchronous execution with a true asynchronous worker pool, allowing Gemini documentation tasks to run concurrently. This reduces total autodoc generation time from ~39 minutes to ~6-10 minutes.
- **Enhanced Resilience for Network Failures** — Extended the retry logic in the autodoc command to catch transient network errors (like connection resets and timeouts) in addition to API rate limits, ensuring CI pipelines are robust against temporary outages.
- **Stabilized Artifact Writing in Stage 1 Explorer** — Addressed an issue where the Gemini CLI's `write_file` tool was unreliable during Stage 1 exploration by explicitly instructing the model to use robust shell commands (`mkdir`, `tee`, `cat`) to write JSON artifacts.
- **Consistent Audit Paths for Triage** — Updated hardcoded `.cicd_runs` path references to dynamically use the `$kCicdRunsDir` constant (`.runtime_ci/runs/`), ensuring triage runs align consistently with the rest of the pipeline's directory structure.
- **Fixed Pipeline Duration Logging** — Replaced unreliable internal API stats with wall-clock stopwatches in the `compose` and `release_notes` commands to guarantee accurate elapsed time reporting regardless of the Gemini CLI response shape.
- **Removed Stale Documentation** — Cleaned up orphaned root-level documentation files (`docs/QUICKSTART.md` and `docs/API_REFERENCE.md`) that have been superseded by module-scoped auto-generated documentation.

## Issues Addressed

- [#3](https://github.com/open-runtime/runtime_ci_tooling/issues/3) — enhancement: runtime_ci_tooling v2 — comprehensive pipeline, Gemini, and CLI improvements (confidence: 40%)
- [#4](https://github.com/open-runtime/runtime_ci_tooling/issues/4) — Comprehensive Code Audit: 40 findings (5 CRITICAL — logic errors, data loss, wrong paths) (confidence: 60%)
## Contributors

Thanks to everyone who contributed to this release:
- @tsavo-at-pieces
## Upgrade

```bash
dart pub upgrade runtime_ci_tooling
```

## Full Changelog

[v0.9.0...v0.9.1](https://github.com/open-runtime/runtime_ci_tooling/compare/v0.9.0...v0.9.1)
