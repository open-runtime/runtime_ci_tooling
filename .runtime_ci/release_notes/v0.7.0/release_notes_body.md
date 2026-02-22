# runtime_ci_tooling v0.7.0

> This minor release introduces automatic configuration scaffolding for our autodoc system, enabling zero-touch setup for new repositories. It also fixes a critical bug where AI-powered pipeline stages failed to execute due to an invalid Gemini model ID.

## Highlights

- **Auto-generated Autodoc Configuration** — The `init` command now intelligently scans your `lib/src/` subdirectories and automatically generates a `.runtime_ci/autodoc.json` file.
- **Pipeline Execution Fixed** — Resolved a `ModelNotFoundError` by correctly updating the Gemini Pro model ID to `gemini-3.1-pro-preview` across all AI-powered pipeline stages.
- **Completed Autodoc Prompts** — Finalized the implementation of remaining autodoc prompts, including a brand new migration guide generator.

## What's New

### Auto-generated `autodoc.json`
The `init` command has been upgraded to automate documentation setup. When you initialize `runtime_ci_tooling in a new repository, it now scans your Dart library structure and pre-populates the autodoc configuration, saving you from writing it by hand.

```json
{
  "id": "cli",
  "name": "Cli",
  "source_paths": [
    "lib/src/cli/"
  ],
  "lib_paths": [
    "lib/src/cli/"
  ],
  "output_path": "docs/cli/",
  "generate": [
    "quickstart",
    "api_reference"
  ],
  "hash": "",
  "last_updated": null
}
```

### New Migration Guide Generator
We've added `scripts/prompts/autodoc_migration_prompt.dart`, completing the suite of autodoc templates. This new prompt automatically generates a `MIGRATION.md` for your modules by analyzing the `git diff` between releases.

## Bug Fixes

- **Corrected Gemini Pro Model ID** — Fixed an issue where the Gemini Pro model ID was incorrectly specified as `gemini-3-1-pro-preview` instead of `gemini-3.1-pro-preview`, which caused execution failures in the AI pipeline.
- **Missing Autodoc Implementations** — Added missing autodoc prompt implementations and fixed context issues in `autodoc_api_reference_prompt.dart` where generated Dart code context was missing.

## Issues Addressed

No linked issues for this release.
## Upgrade

```bash
dart pub upgrade runtime_ci_tooling
```

## Contributors

Thanks to everyone who contributed to this release:
- @tsavo-at-pieces
## Full Changelog

[v0.6.6...v0.7.0](https://github.com/open-runtime/runtime_ci_tooling/compare/v0.6.6...v0.7.0)