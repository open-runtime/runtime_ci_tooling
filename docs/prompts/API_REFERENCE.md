# Gemini Prompt Templates API Reference

This module provides a collection of executable Dart scripts that generate specialized prompts for Gemini LLM agents. These prompts orchestrate various stages of the CI/CD lifecycle, such as documentation generation, changelog composing, release notes authoring, and issue triage.

## 1. Classes

### **CiConfig** 
Reads the package name and repository owner from `.runtime_ci/config.json`. Falls back to default values (`runtime_isomorphic_library` / `open-runtime`) when running outside a properly initialized repository.

- **Fields:**
  - `packageName` (`String`): The name of the package.
  - `repoOwner` (`String`): The repository owner.

- **Properties:**
  - `current` (`static CiConfig`): Singleton getter that reads the config once and caches it.

- **Constructors:**
  - Uses a private named constructor `CiConfig._` and a static internal loader.

**Dart Usage:**
```dart
import 'package:runtime_ci_tooling/src/prompts/_ci_config.dart';

void main() {
  final config = CiConfig.current;
  print('Package: ${config.packageName}');
  print('Owner: ${config.repoOwner}');
}
```

## 2. Enums

*(No public enums in this module)*

## 3. Extensions

*(No public extensions in this module)*

## 4. Executable Scripts

Because this module primarily consists of executable scripts, the public entry points are all `main` functions. They are listed below by the script they belong to:

### `autodoc_api_reference_prompt.dart`
Autodoc: API_REFERENCE.md generator for a proto module.
- **Parameters:** `args` (`List<String>`): Expects `<module_name> <source_dir> [lib_dir]`.
- **Usage:**
  ```bash
  dart run scripts/prompts/autodoc_api_reference_prompt.dart <module_name> <source_dir> [lib_dir]
  ```

### `autodoc_examples_prompt.dart`
Autodoc: EXAMPLES.md generator for a proto module.
- **Parameters:** `args` (`List<String>`): Expects `<module_name> <source_dir> [lib_dir]`.
- **Usage:**
  ```bash
  dart run scripts/prompts/autodoc_examples_prompt.dart <module_name> <source_dir> [lib_dir]
  ```

### `autodoc_migration_prompt.dart`
Autodoc: MIGRATION.md generator for a proto module.
- **Parameters:** `args` (`List<String>`): Expects `<module_name> <source_dir> [prev_hash]`.
- **Usage:**
  ```bash
  dart run scripts/prompts/autodoc_migration_prompt.dart <module_name> <source_dir> [prev_hash]
  ```

### `autodoc_quickstart_prompt.dart`
Autodoc: QUICKSTART.md generator for a proto module.
- **Parameters:** `args` (`List<String>`): Expects `<module_name> <source_dir> [lib_dir]`.
- **Usage:**
  ```bash
  dart run scripts/prompts/autodoc_quickstart_prompt.dart <module_name> <source_dir> [lib_dir]
  ```

### `gemini_changelog_composer_prompt.dart`
Stage 2 Changelog Composer Agent prompt generator. Focused ONLY on updating `CHANGELOG.md` with a concise Keep-a-Changelog entry.
- **Parameters:** `args` (`List<String>`): Expects `<prev_tag> <new_version>`.
- **Usage:**
  ```bash
  dart run scripts/prompts/gemini_changelog_composer_prompt.dart <prev_tag> <new_version>
  ```

### `gemini_changelog_prompt.dart`
Stage 1 Explorer Agent prompt generator. Generates the changelog analysis prompt with interpolated context including project tree, commit messages, diff statistics, and version info. The output is piped to Gemini CLI for autonomous exploration.
- **Parameters:** `args` (`List<String>`): Expects `<prev_tag> <new_version>`.
- **Usage:**
  ```bash
  dart run scripts/prompts/gemini_changelog_prompt.dart <prev_tag> <new_version> | gemini -o json --yolo -s -m gemini-3-flash-preview ...
  ```

### `gemini_documentation_prompt.dart`
Stage 2 Documentation Update prompt generator. Instructs Gemini Pro to analyze proto/API changes and update `README.md` sections accordingly.
- **Parameters:** `args` (`List<String>`): Expects `<prev_tag> <new_version>`.
- **Usage:**
  ```bash
  dart run scripts/prompts/gemini_documentation_prompt.dart <prev_tag> <new_version> | gemini -o json --yolo -s -m gemini-3.1-pro-preview @.runtime_ci/runs/explore/commit_analysis.json @README.md ...
  ```

### `gemini_release_notes_author_prompt.dart`
Stage 3 Release Notes Author prompt generator. Produces rich, narrative release notes distinct from the CHANGELOG.
- **Parameters:** `args` (`List<String>`): Expects `<prev_tag> <new_version> [patch|minor|major]`.
- **Usage:**
  ```bash
  dart run scripts/prompts/gemini_release_notes_author_prompt.dart <prev_tag> <new_version> [patch|minor|major]
  ```

### `gemini_triage_prompt.dart`
Issue Triage prompt generator for analyzing a GitHub issue and performing comprehensive triage: type classification, priority assignment, duplicate detection, area classification, and helpful comment generation.
- **Parameters:** `args` (`List<String>`): Expects `<issue_number> <issue_title> <issue_author> <existing_labels> <issue_body> <open_issues_list>`.
- **Usage:**
  ```bash
  dart run scripts/prompts/gemini_triage_prompt.dart <issue_number> "<issue_title>" <issue_author> "<existing_labels>" "<issue_body>" "<open_issues_list>"
  ```
