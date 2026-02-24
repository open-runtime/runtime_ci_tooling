# Gemini Prompt Templates API Reference

This document provides the API reference for the Gemini Prompt Templates module. These templates are executed as command-line Dart scripts, which generate prompts to pipe into the Gemini CLI for autonomous CI/CD tasks.

## 1. Classes

### CiConfig
Reads package name and repo owner from `.runtime_ci/config.json`. Falls back to `runtime_isomorphic_library` / `open-runtime` when config is unavailable (e.g., when running locally outside a properly initialized repo).

**Fields:**
- `packageName` (`String`) - The name of the package.
- `repoOwner` (`String`) - The owner of the repository.
- `current` (`static CiConfig`) - Singleton getter that reads the configuration once and caches it.

**Example Usage:**
```dart
import '_ci_config.dart';

final pkg = CiConfig.current.packageName;
final owner = CiConfig.current.repoOwner;
```

## 2. Enums
*(No public enums in this module)*

## 3. Extensions
*(No public extensions in this module)*

## 4. Top-Level Functions

The prompt scripts are designed to be executed as Dart executables. Each script contains a top-level `main` function and requires specific command-line arguments.

### main (autodoc_api_reference_prompt.dart)
Autodoc: `API_REFERENCE.md` generator for a proto module.
- **Signature:** `void main(List<String> args)`
- **Parameters:**
  - `args`: Command-line arguments (`<module_name> <source_dir> [lib_dir]`).
- **Return Type:** `void`
- **Example Usage:**
  ```bash
  dart run scripts/prompts/autodoc_api_reference_prompt.dart my_module proto/src lib/src | gemini -o json
  ```

### main (autodoc_examples_prompt.dart)
Autodoc: `EXAMPLES.md` generator for a proto module.
- **Signature:** `void main(List<String> args)`
- **Parameters:**
  - `args`: Command-line arguments (`<module_name> <source_dir> [lib_dir]`).
- **Return Type:** `void`
- **Example Usage:**
  ```bash
  dart run scripts/prompts/autodoc_examples_prompt.dart my_module proto/src lib/src | gemini -o json
  ```

### main (autodoc_migration_prompt.dart)
Autodoc: `MIGRATION.md` generator for a proto module.
- **Signature:** `void main(List<String> args)`
- **Parameters:**
  - `args`: Command-line arguments (`<module_name> <source_dir> [prev_hash]`).
- **Return Type:** `void`
- **Example Usage:**
  ```bash
  dart run scripts/prompts/autodoc_migration_prompt.dart my_module proto/src v1.0.0 | gemini -o json
  ```

### main (autodoc_quickstart_prompt.dart)
Autodoc: `QUICKSTART.md` generator for a proto module.
- **Signature:** `void main(List<String> args)`
- **Parameters:**
  - `args`: Command-line arguments (`<module_name> <source_dir> [lib_dir]`).
- **Return Type:** `void`
- **Example Usage:**
  ```bash
  dart run scripts/prompts/autodoc_quickstart_prompt.dart my_module proto/src lib/src | gemini -o json
  ```

### main (gemini_changelog_composer_prompt.dart)
Stage 2 Changelog Composer Agent prompt generator. Focused ONLY on updating `CHANGELOG.md` with a concise Keep-a-Changelog entry.
- **Signature:** `void main(List<String> args)`
- **Parameters:**
  - `args`: Command-line arguments (`<prev_tag> <new_version>`).
- **Return Type:** `void`
- **Example Usage:**
  ```bash
  dart run scripts/prompts/gemini_changelog_composer_prompt.dart v0.0.1 0.0.2 | gemini -o json --yolo -s
  ```

### main (gemini_changelog_prompt.dart)
Stage 1 Explorer Agent prompt generator. Generates the changelog analysis prompt with interpolated context including project tree, commit messages, diff statistics, and version info. The output is piped to Gemini CLI for autonomous exploration.
- **Signature:** `void main(List<String> args)`
- **Parameters:**
  - `args`: Command-line arguments (`<prev_tag> <new_version>`).
- **Return Type:** `void`
- **Example Usage:**
  ```bash
  dart run scripts/prompts/gemini_changelog_prompt.dart v0.0.1 0.0.2 |     gemini -o json --yolo -s -m gemini-3-flash-preview
  ```

### main (gemini_documentation_prompt.dart)
Stage 2 Documentation Update prompt generator. Generates a prompt that instructs Gemini Pro to analyze proto/API changes and update `README.md` sections accordingly.
- **Signature:** `void main(List<String> args)`
- **Parameters:**
  - `args`: Command-line arguments (`<prev_tag> <new_version>`).
- **Return Type:** `void`
- **Example Usage:**
  ```bash
  dart run scripts/prompts/gemini_documentation_prompt.dart v0.0.1 0.0.2 |     gemini -o json --yolo -s -m gemini-3.1-pro-preview     @.runtime_ci/runs/explore/commit_analysis.json @README.md
  ```

### main (gemini_release_notes_author_prompt.dart)
Stage 3 Release Notes Author prompt generator. Produces rich, narrative release notes distinct from the CHANGELOG.
- **Signature:** `void main(List<String> args)`
- **Parameters:**
  - `args`: Command-line arguments (`<prev_tag> <new_version> [patch|minor|major]`).
- **Return Type:** `void`
- **Example Usage:**
  ```bash
  dart run scripts/prompts/gemini_release_notes_author_prompt.dart v0.0.1 0.0.2 minor |     gemini -o json --yolo -s
  ```

### main (gemini_triage_prompt.dart)
Issue Triage prompt generator. Generates a prompt for Gemini Pro to analyze a GitHub issue and perform comprehensive triage: type classification, priority assignment, duplicate detection, area classification, and helpful comment generation.
- **Signature:** `void main(List<String> args)`
- **Parameters:**
  - `args`: Command-line arguments (`<issue_number> <issue_title> <issue_author> <existing_labels> <issue_body> <open_issues_list>`).
- **Return Type:** `void`
- **Example Usage:**
  ```bash
  dart run scripts/prompts/gemini_triage_prompt.dart 42 "Bug in login" "user1" "bug" "Body text" "12,13" |     gemini -o json --yolo -s
  ```
