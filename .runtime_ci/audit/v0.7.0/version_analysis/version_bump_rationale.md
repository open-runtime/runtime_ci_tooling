## Decision: minor

This is a minor release because it introduces new features alongside important bug fixes and chore improvements, without breaking any public APIs.

## Key Changes
- **Feature**: The `init` command now auto-generates `.runtime_ci/autodoc.json` by scanning `lib/src/` subdirectories for modules.
- **Bug Fix**: Fixed a critical issue across all AI-powered pipeline stages where the Gemini Pro model ID was incorrectly specified as `gemini-3-1-pro-preview` instead of `gemini-3.1-pro-preview`, preventing execution.
- **Bug Fix**: Completed unfinished autodoc prompt implementations, including adding the missing `scripts/prompts/autodoc_migration_prompt.dart` script and updating `autodoc_api_reference_prompt.dart` to include generated Dart code context.
- **Chore**: Various formatting fixes.

## Breaking Changes
None.

## New Features
- `init` command automatically sets up `autodoc.json`.
- Added new `autodoc_migration_prompt.dart` script.

## References
- Commit: `feat: generate autodoc.json in init command`
- Commit: `fix: complete unfinished autodoc prompt implementations`
- Commit: `fix: correct Gemini pro model ID to gemini-3-pro-preview`
- Commit: `chore: fix Gemini model ID gemini-3-1-pro-preview → gemini-3.1-pro-preview`
