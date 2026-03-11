# Gemini Prompt Templates API Reference

This document provides the API reference for the **Gemini Prompt Templates** module, covering configuration parsing and the top-level CLI prompt generation scripts.

## Classes

### CiConfig

Reads package name and repo owner from `.runtime_ci/config.json`. Falls back to `runtime_isomorphic_library` / `open-runtime` when config is unavailable (e.g. when running locally outside a properly initialised repo).

- **Fields:**
  - `final String packageName`: The parsed or fallback package name.
  - `final String repoOwner`: The parsed or fallback repository owner.
- **Getters:**
  - `static CiConfig current`: Singleton that reads the configuration once and caches it.

**Example Usage:**
```dart
import 'package:runtime_ci_tooling/src/prompts/_ci_config.dart';

void main() {
  final config = CiConfig.current;
  print('Package: ${config.packageName}');
  print('Owner: ${config.repoOwner}');
}
```

## Enums
*(No public enums are defined in this module)*

## Extensions
*(No public extensions are defined in this module)*

## Top-Level Functions

The modules in `lib/src/prompts/` are primarily standalone CLI scripts. Each script exposes a public `main` function as its entry point. They output prompt definitions to stdout.

### main (autodoc_api_reference_prompt.dart)
`void main(List<String> args)`

Autodoc: API_REFERENCE.md generator for a proto module.
- **Parameters**: 
  - `args`: Command-line arguments (`<module_name>`, `<source_dir>`, `[lib_dir]`).

**Example Usage:**
```dart
import 'package:runtime_ci_tooling/src/prompts/autodoc_api_reference_prompt.dart' as prompt;

void main() {
  prompt.main(['my_module', 'proto/src/', 'lib/src/']);
}
```

### main (autodoc_examples_prompt.dart)
`void main(List<String> args)`

Autodoc: EXAMPLES.md generator for a proto module.
- **Parameters**: 
  - `args`: Command-line arguments (`<module_name>`, `<source_dir>`, `[lib_dir]`).

### main (autodoc_migration_prompt.dart)
`void main(List<String> args)`

Autodoc: MIGRATION.md generator for a proto module.
- **Parameters**: 
  - `args`: Command-line arguments (`<module_name>`, `<source_dir>`, `[prev_hash]`).

### main (autodoc_quickstart_prompt.dart)
`void main(List<String> args)`

Autodoc: QUICKSTART.md generator for a proto module.
- **Parameters**: 
  - `args`: Command-line arguments (`<module_name>`, `<source_dir>`, `[lib_dir]`).

### main (gemini_changelog_composer_prompt.dart)
`void main(List<String> args)`

Stage 2 Changelog Composer Agent prompt generator. Focused ONLY on updating `CHANGELOG.md` with a concise Keep-a-Changelog entry.
- **Parameters**: 
  - `args`: Command-line arguments (`<prev_tag>`, `<new_version>`).

### main (gemini_changelog_prompt.dart)
`void main(List<String> args)`

Stage 1 Explorer Agent prompt generator. Generates the changelog analysis prompt with interpolated context including project tree, commit messages, diff statistics, and version info.
- **Parameters**: 
  - `args`: Command-line arguments (`<prev_tag>`, `<new_version>`).

### main (gemini_documentation_prompt.dart)
`void main(List<String> args)`

Stage 2 Documentation Update prompt generator. Generates a prompt that instructs Gemini to analyze proto/API changes and update `README.md` sections accordingly.
- **Parameters**: 
  - `args`: Command-line arguments (`<prev_tag>`, `<new_version>`).

### main (gemini_release_notes_author_prompt.dart)
`void main(List<String> args)`

Stage 3 Release Notes Author prompt generator. Produces rich, narrative release notes distinct from the CHANGELOG.
- **Parameters**: 
  - `args`: Command-line arguments (`<prev_tag>`, `<new_version>`, `[bump_type]`).

### main (gemini_triage_prompt.dart)
`void main(List<String> args)`

Issue Triage prompt generator. Generates a prompt for Gemini to analyze a GitHub issue and perform comprehensive triage: type classification, priority assignment, duplicate detection, area classification, and helpful comment generation.
- **Parameters**: 
  - `args`: Command-line arguments (`<issue_number>`, `<issue_title>`, `<issue_author>`, `<existing_labels>`, `<issue_body>`, `<open_issues_list>`).
