# runtime_ci_tooling v0.9.2

> Bug fix release — 2026-02-22

## Bug Fixes

- **`autodoc --init` scaffolding failure** — Previously, running `autodoc --init` was a no-op that instructed users to create `autodoc.json` manually and was prone to failing with an `ArgParserException`. This command now actively scans `lib/src/` to automatically scaffold `autodoc.json` using the new shared `autodoc_scaffold.dart` utility. ([#2](https://github.com/open-runtime/runtime_ci_tooling/issues/2))
- **Hanging `tee` processes in changelog generation** — Fixed an indentation issue with the heredoc `JSONEOF` terminator in `gemini_changelog_prompt.dart` that was causing `tee` to hang during execution.
- **Inaccurate rate limit logging** — Corrected the retry log message in `autodoc_command.dart` to properly report generic network or transient errors instead of incorrectly claiming that all retryable errors were due to rate limits.
- **Outdated `.cicd_runs` path usage** — Updated remaining hardcoded output paths across CLI commands, agent scripts, and prompt files to use the new `.runtime_ci/runs` directory structure for full consistency.

## Upgrade

```bash
dart pub upgrade runtime_ci_tooling
```

## Contributors

Thanks to everyone who contributed to this release:
- @tsavo-at-pieces
## Issues Addressed

- [#2](https://github.com/open-runtime/runtime_ci_tooling/issues/2) — Bug: autodoc --init fails with ArgParserException (confidence: 100%)
## Full Changelog

[v0.9.1...v0.9.2](https://github.com/open-runtime/runtime_ci_tooling/compare/v0.9.1...v0.9.2)
