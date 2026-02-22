# Gemini Prompt Templates API Reference

This document provides the API reference for the **Gemini Prompt Templates** module, which contains script generators for generating structured prompts used by the Gemini CLI.

## 1. Classes

### `CiConfig`
Reads package name and repo owner from `.runtime_ci/config.json`. Falls back to `runtime_isomorphic_library` / `open-runtime` when config is unavailable (e.g., when running locally outside a properly initialized repo).

- **Fields:**
  - `String packageName`: The package name resolved from configuration or fallback.
  - `String repoOwner`: The repository owner resolved from configuration or fallback.
- **Key Methods / Getters:**
  - `static CiConfig get current`: Singleton getter that reads the configuration once and caches it for subsequent calls.

#### Example Usage

```dart
import 'package:runtime_ci_tooling/src/prompts/_ci_config.dart';

void main() {
  final config = CiConfig.current;
  print('Package Name: ${config.packageName}');
  print('Repository Owner: ${config.repoOwner}');
}
```

## 2. Enums
*(No public enums are defined in this module)*

## 3. Extensions
*(No public extensions are defined in this module)*

## 4. Top-Level Functions (Scripts)

The prompt templates are structured as standalone Dart scripts. Each script provides a top-level `main` function that acts as the entry point for generating the respective prompt output.

### `autodoc_api_reference_prompt.dart - main`
- **Signature:** `void main(List<String> args)`
- **Description:** Autodoc: API_REFERENCE.md generator for a proto module.
- **Parameters:** 
  - `args` (`List<String>`): Command line arguments. Requires `<module_name> <source_dir> [lib_dir]`.
- **Return Type:** `void`

#### Example Usage

```bash
dart run scripts/prompts/autodoc_api_reference_prompt.dart my_module proto/src/my_module lib/src/my_module
```

### `autodoc_examples_prompt.dart - main`
- **Signature:** `void main(List<String> args)`
- **Description:** Autodoc: EXAMPLES.md generator for a proto module.
- **Parameters:**
  - `args` (`List<String>`): Command line arguments. Requires `<module_name> <source_dir> [lib_dir]`.
- **Return Type:** `void`

#### Example Usage

```bash
dart run scripts/prompts/autodoc_examples_prompt.dart my_module proto/src/my_module lib/src/my_module
```

### `autodoc_migration_prompt.dart - main`
- **Signature:** `void main(List<String> args)`
- **Description:** Autodoc: MIGRATION.md generator for a proto module.
- **Parameters:**
  - `args` (`List<String>`): Command line arguments. Requires `<module_name> <source_dir> [prev_hash]`.
- **Return Type:** `void`

#### Example Usage

```bash
dart run scripts/prompts/autodoc_migration_prompt.dart my_module proto/src/my_module v1.0.0
```

### `autodoc_quickstart_prompt.dart - main`
- **Signature:** `void main(List<String> args)`
- **Description:** Autodoc: QUICKSTART.md generator for a proto module.
- **Parameters:**
  - `args` (`List<String>`): Command line arguments. Requires `<module_name> <source_dir> [lib_dir]`.
- **Return Type:** `void`

#### Example Usage

```bash
dart run scripts/prompts/autodoc_quickstart_prompt.dart my_module proto/src/my_module lib/src/my_module
```

### `gemini_changelog_composer_prompt.dart - main`
- **Signature:** `void main(List<String> args)`
- **Description:** Stage 2 Changelog Composer Agent prompt generator. Focused ONLY on updating `CHANGELOG.md` with a concise Keep-a-Changelog entry. Release notes are handled separately by Stage 3.
- **Parameters:**
  - `args` (`List<String>`): Command line arguments. Requires `<prev_tag> <new_version>`.
- **Return Type:** `void`

#### Example Usage

```bash
dart run scripts/prompts/gemini_changelog_composer_prompt.dart v1.0.0 1.1.0
```

### `gemini_changelog_prompt.dart - main`
- **Signature:** `void main(List<String> args)`
- **Description:** Stage 1 Explorer Agent prompt generator. Generates the changelog analysis prompt with interpolated context including project tree, commit messages, diff statistics, and version info. The output is typically piped to Gemini CLI for autonomous exploration.
- **Parameters:**
  - `args` (`List<String>`): Command line arguments. Requires `<prev_tag> <new_version>`.
- **Return Type:** `void`

#### Example Usage

```bash
dart run scripts/prompts/gemini_changelog_prompt.dart v1.0.0 1.1.0 | gemini -o json --yolo -s -m gemini-3-flash-preview
```

### `gemini_documentation_prompt.dart - main`
- **Signature:** `void main(List<String> args)`
- **Description:** Stage 2 Documentation Update prompt generator. Generates a prompt that instructs Gemini Pro to analyze proto/API changes and update `README.md` sections accordingly. Focuses on keeping documentation in sync with the codebase without restructuring existing content.
- **Parameters:**
  - `args` (`List<String>`): Command line arguments. Requires `<prev_tag> <new_version>`.
- **Return Type:** `void`

#### Example Usage

```bash
dart run scripts/prompts/gemini_documentation_prompt.dart v1.0.0 1.1.0 | gemini -o json --yolo -s -m gemini-3.1-pro-preview
```

### `gemini_release_notes_author_prompt.dart - main`
- **Signature:** `void main(List<String> args)`
- **Description:** Stage 3 Release Notes Author prompt generator. Produces rich, narrative release notes distinct from the CHANGELOG. Output includes an executive summary, highlights, breaking changes with code examples, and linked issues.
- **Parameters:**
  - `args` (`List<String>`): Command line arguments. Requires `<prev_tag> <new_version> [patch|minor|major]`.
- **Return Type:** `void`

#### Example Usage

```bash
dart run scripts/prompts/gemini_release_notes_author_prompt.dart v1.0.0 1.1.0 minor
```

### `gemini_triage_prompt.dart - main`
- **Signature:** `void main(List<String> args)`
- **Description:** Issue Triage prompt generator. Generates a prompt for Gemini Pro to analyze a GitHub issue and perform comprehensive triage: type classification, priority assignment, duplicate detection, area classification, and helpful comment generation.
- **Parameters:**
  - `args` (`List<String>`): Command line arguments. Requires `<issue_number> <issue_title> <issue_author> <existing_labels> <issue_body> <open_issues_list>`.
- **Return Type:** `void`

#### Example Usage

```bash
dart run scripts/prompts/gemini_triage_prompt.dart 42 "Fix critical bug" "johndoe" "bug,urgent" "The app crashes on startup." "12: Login issue
15: UI glitch"
```
