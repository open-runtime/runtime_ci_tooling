# runtime_ci_tooling v0.14.4

> Bug fix release — 2026-03-03

## Bug Fixes

- **Prevented release self-cancellation on fallback merges** — Added a `[skip ci]` marker to the fallback merge commit message in the `create-release` command. This ensures that non-fast-forward recovery merges do not spawn a new CI/release run, which could cancel the in-progress release.
- **Improved CI verification for follow-up pushes** — Updated a comment in the `create-release` command to avoid using a literal CI skip token in the text. This allows subsequent follow-up pushes to properly execute CI verification.

## Upgrade

```bash
dart pub upgrade runtime_ci_tooling
```

## Contributors

Thanks to everyone who contributed to this release:
- @tsavo-at-pieces
## Issues Addressed

No linked issues for this release.
## Full Changelog

[v0.14.3...v0.14.4](https://github.com/open-runtime/runtime_ci_tooling/compare/v0.14.3...v0.14.4)
