# runtime_ci_tooling v0.14.1

> Bug fix & security release — 2026-02-24

This patch release hardens the security of the CLI, prevents unrelated files from being committed by the CI bot, and fixes workflow runner correctness.

## Security Fixes

- **Token leak prevention in logs** — Redacts GitHub Personal Access Tokens (PATs) and other sensitive credentials from verbose command outputs in `CiProcessRunner`. ([#28](https://github.com/open-runtime/runtime_ci_tooling/pull/28))
- **Shell injection mitigation** — Eliminates vulnerabilities related to shell interpolation by migrating `git` executions to use strictly separated array arguments via `Process.runSync` in release and sub-package utilities. ([#28](https://github.com/open-runtime/runtime_ci_tooling/pull/28))

## Bug Fixes

- **Corrected self-hosted runner targets** — Regenerated the CI workflow and skeleton template to point to the correct internal build machines (`runtime-ubuntu-24.04-x64-256gb-64core` and `runtime-windows-2025-x64-256gb-64core`).
- **Fixed workflow artifact naming** — Replaced `matrix.os` with `matrix.platform_id` for workflow artifact uploads to avoid naming resolution errors.
- **Prevented unrelated file staging*j** — Scoped the auto-format commit step from `git add -A` to specifically `git add lib/` within the generated CI skeleton, preventing unrelated artifacts from accidentally leaking into format commits. ([#28](https://github.com/open-runtime/runtime_ci_tooling/pull/28))


## Miscellaneous

- **Improved CI observability** — Operation logging has been added for `git config`, `git add`, and pubspec writes, and silent `catch (_)` blocks have been replaced with `Logger.warn()` to ensure errors are visible in CI logs. ([#28](https://github.com/open-runtime/runtime_ci_tooling/pull/28))

## Upgrade

```bash
dart pub upgrade runtime_ci_tooling
```

## Contributors

Thanks to everyone who contributed to this release:
- @tsavo-at-pieces
## Full Changelog

[v0.14.0...v0.14.1](https://github.com/open-runtime/runtime_ci_tooling/compare/v0.14.0...v0.14.1)
