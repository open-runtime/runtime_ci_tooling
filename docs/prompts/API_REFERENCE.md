# Gemini Prompt Templates API Reference

## 1. Classes

### CiConfig
Reads package name and repo owner from `.runtime_ci/config.json`. Falls back to `runtime_isomorphic_library` / `open-runtime` when config is unavailable — e.g. when running locally outside a properly initialised repo.

- **Fields:**
  - `String packageName` - The name of the package.
  - `String repoOwner` - The owner of the repository.

- **Methods/Getters:**
  - `static CiConfig get current` - Singleton that reads the config once and caches it.

## 2. Enums

*(No public enums in this module)*

## 3. Extensions

*(No public extensions in this module)*

## 4. Top-Level Functions

### main (autodoc_api_reference_prompt.dart)
- **Signature:** `void main(List<String> args)`
- **Description:** Autodoc: `API_REFERENCE.md` generator for a proto module.
- **Parameters:** 
  - `args` - CLI arguments.
- **Usage:** `dart run scripts/prompts/autodoc_api_reference_prompt.dart <module_name> <source_dir> [lib_dir]`

### main (autodoc_examples_prompt.dart)
- **Signature:** `void main(List<String> args)`
- **Description:** Autodoc: `EXAMPLES.md` generator for a proto module.
- **Parameters:** 
  - `args` - CLI arguments.
- **Usage:** `dart run scripts/prompts/autodoc_examples_prompt.dart <module_name> <source_dir> [lib_dir]`

### main (autodoc_migration_prompt.dart)
- **Signature:** `void main(List<String> args)`
- **Description:** Autodoc: `MIGRATION.md` generator for a proto module.
- **Parameters:** 
  - `args` - CLI arguments.
- **Usage:** `dart run scripts/prompts/autodoc_migration_prompt.dart <module_name> <source_dir> [prev_hash]`

### main (autodoc_quickstart_prompt.dart)
- **Signature:** `void main(List<String> args)`
- **Description:** Autodoc: `QUICKSTART.md` generator for a proto module.
- **Parameters:** 
  - `args` - CLI arguments.
- **Usage:** `dart run scripts/prompts/autodoc_quickstart_prompt.dart <module_name> <source_dir> [lib_dir] <output_path>`

### main (gemini_changelog_composer_prompt.dart)
- **Signature:** `void main(List<String> args)`
- **Description:** Stage 2 Changelog Composer Agent prompt generator. Focused ONLY on updating `CHANGELOG.md` with a concise Keep-a-Changelog entry. Release notes are handled separately by Stage 3 (`gemini_release_notes_author_prompt.dart`).
- **Parameters:** 
  - `args` - CLI arguments.
- **Usage:** `dart run scripts/prompts/gemini_changelog_composer_prompt.dart <prev_tag> <new_version>`

### main (gemini_changelog_prompt.dart)
- **Signature:** `void main(List<String> args)`
- **Description:** Stage 1 Explorer Agent prompt generator. Generates the changelog analysis prompt with interpolated context including project tree, commit messages, diff statistics, and version info. The output is piped to Gemini CLI for autonomous exploration.
- **Parameters:** 
  - `args` - CLI arguments.
- **Usage:** `dart run scripts/prompts/gemini_changelog_prompt.dart <prev_tag> <new_version>`

### main (gemini_documentation_prompt.dart)
- **Signature:** `void main(List<String> args)`
- **Description:** Stage 2 Documentation Update prompt generator. Generates a prompt that instructs Gemini Pro to analyze proto/API changes and update `README.md` sections accordingly. Focuses on keeping documentation in sync with the codebase without restructuring existing content.
- **Parameters:** 
  - `args` - CLI arguments.
- **Usage:** `dart run scripts/prompts/gemini_documentation_prompt.dart <prev_tag> <new_version>`

### main (gemini_release_notes_author_prompt.dart)
- **Signature:** `void main(List<String> args)`
- **Description:** Stage 3 Release Notes Author prompt generator. Produces rich, narrative release notes distinct from the CHANGELOG. The CHANGELOG (Stage 2) is concise and literal. This stage produces detailed, user-friendly release documentation with executive summary, breaking changes, migration guides, etc.
- **Parameters:** 
  - `args` - CLI arguments.
- **Usage:** `dart run scripts/prompts/gemini_release_notes_author_prompt.dart <prev_tag> <new_version> [patch|minor|major]`

### main (gemini_triage_prompt.dart)
- **Signature:** `void main(List<String> args)`
- **Description:** Issue Triage prompt generator. Generates a prompt for Gemini Pro to analyze a GitHub issue and perform comprehensive triage: type classification, priority assignment, duplicate detection, area classification, and helpful comment generation.
- **Parameters:** 
  - `args` - CLI arguments.
- **Usage:** `dart run scripts/prompts/gemini_triage_prompt.dart <issue_number> <issue_title> <issue_author> <existing_labels> <issue_body> <open_issues_list>`

## 5. Dart Usage

### Accessing CI Configuration

The `CiConfig` class provides singleton access to the package name and repo owner from `.runtime_ci/config.json`.

```dart
import 'package:runtime_ci_tooling/src/prompts/_ci_config.dart';

void main() {
  final config = CiConfig.current;
  
  print('Package Name: ${config.packageName}');
  print('Repo Owner: ${config.repoOwner}');
}
```
