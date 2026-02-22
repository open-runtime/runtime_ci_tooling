# Gemini Prompt Templates API Reference

This document provides the API reference for the Gemini Prompt Templates module within `runtime_ci_tooling`. This module contains scripts and utilities for generating AI prompts used in continuous integration, specifically for auto-generating documentation and release notes based on source code analysis.

## 1. Classes

### **CiConfig** -- Reads package name and repo owner from `.runtime_ci/config.json`.

Singleton configuration manager that traverses upwards from the current working directory to locate `.runtime_ci/config.json`. If unavailable, it falls back to default values (`runtime_isomorphic_library` / `open-runtime`).

- **Fields:**
  - `String packageName` -- The package name read from the repository configuration or fallback.
  - `String repoOwner` -- The repository owner read from the repository configuration or fallback.

- **Methods/Getters:**
  - `static CiConfig get current` -- Singleton getter that reads the configuration once and caches it for subsequent calls.

#### Example Usage
```dart
import 'package:runtime_ci_tooling/src/prompts/_ci_config.dart';

void main() {
  // Fetch configuration, traversing parents to find .runtime_ci/config.json
  final config = CiConfig.current;
  
  print('Package: \${config.packageName}');
  print('Repo Owner: \${config.repoOwner}');
}
```

## 2. Enums

*(No public enums defined in this module)*

## 3. Extensions

*(No public extensions defined in this module)*

## 4. Top-Level Functions (CLI Scripts)

This module primarily exposes Dart scripts designed to be executed via the command line to generate LLM prompts.

### **autodoc_api_reference_prompt.dart**
Generates an `API_REFERENCE.md` prompt for a proto module by analyzing `.proto` and `.pb.dart` generated files.

- **Signature:** `void main(List<String> args)`
- **Parameters:**
  - `args[0]`: `<module_name>` - The name of the module to document.
  - `args[1]`: `<source_dir>` - The directory containing `.proto` definitions.
  - `args[2]` (Optional): `[lib_dir]` - The directory containing generated Dart code.
- **Example Execution:**
  ```bash
  dart run scripts/prompts/autodoc_api_reference_prompt.dart my_module proto/src lib/src
  ```

### **autodoc_examples_prompt.dart**
Generates an `EXAMPLES.md` prompt for a proto module by locating services, messages, enums, tests, and extensions.

- **Signature:** `void main(List<String> args)`
- **Parameters:**
  - `args[0]`: `<module_name>` - The name of the module.
  - `args[1]`: `<source_dir>` - The directory containing `.proto` definitions.
  - `args[2]` (Optional): `[lib_dir]` - The directory containing generated Dart code.
- **Example Execution:**
  ```bash
  dart run scripts/prompts/autodoc_examples_prompt.dart my_module proto/src lib/src
  ```

### **autodoc_migration_prompt.dart**
Generates a `MIGRATION.md` prompt by analyzing the git diff of proto files to highlight breaking changes, added/removed definitions.

- **Signature:** `void main(List<String> args)`
- **Parameters:**
  - `args[0]`: `<module_name>` - The name of the module.
  - `args[1]`: `<source_dir>` - The directory containing `.proto` definitions.
  - `args[2]` (Optional): `[prev_hash]` - The previous git commit hash or tag to compare against. If omitted, uses recent git history.
- **Example Execution:**
  ```bash
  dart run scripts/prompts/autodoc_migration_prompt.dart my_module proto/src v1.0.0
  ```

### **autodoc_quickstart_prompt.dart**
Generates a `QUICKSTART.md` prompt aimed at providing a 5-minute getting started guide for a module based on its proto footprint and Dart implementations.

- **Signature:** `void main(List<String> args)`
- **Parameters:**
  - `args[0]`: `<module_name>` - The name of the module.
  - `args[1]`: `<source_dir>` - The directory containing `.proto` definitions.
  - `args[2]` (Optional): `[lib_dir]` - The directory containing generated Dart code.
- **Example Execution:**
  ```bash
  dart run scripts/prompts/autodoc_quickstart_prompt.dart my_module proto/src lib/src
  ```

### **gemini_changelog_composer_prompt.dart**
Stage 2 Changelog Composer Agent prompt generator. Focused ONLY on updating `CHANGELOG.md` with a concise Keep-a-Changelog entry based on stage 1 artifacts (`commit_analysis.json`, `pr_data.json`).

- **Signature:** `void main(List<String> args)`
- **Parameters:**
  - `args[0]`: `<prev_tag>` - The previous release tag.
  - `args[1]`: `<new_version>` - The new release version.
- **Example Execution:**
  ```bash
  dart run scripts/prompts/gemini_changelog_composer_prompt.dart v1.0.0 1.1.0
  ```

### **gemini_changelog_prompt.dart**
Stage 1 Explorer Agent prompt generator. Generates the changelog analysis prompt with interpolated context including project tree, commit messages, diff statistics, and version info. Piped to Gemini CLI for autonomous exploration.

- **Signature:** `void main(List<String> args)`
- **Parameters:**
  - `args[0]`: `<prev_tag>` - The previous release tag.
  - `args[1]`: `<new_version>` - The new release version.
- **Example Execution:**
  ```bash
  dart run scripts/prompts/gemini_changelog_prompt.dart v1.0.0 1.1.0 | gemini -o json --yolo -s -m gemini-3-flash-preview
  ```

### **gemini_documentation_prompt.dart**
Stage 2 Documentation Update prompt generator. Instructs Gemini Pro to analyze proto/API changes and update `README.md` sections accordingly.

- **Signature:** `void main(List<String> args)`
- **Parameters:**
  - `args[0]`: `<prev_tag>` - The previous release tag.
  - `args[1]`: `<new_version>` - The new release version.
- **Example Execution:**
  ```bash
  dart run scripts/prompts/gemini_documentation_prompt.dart v1.0.0 1.1.0
  ```

### **gemini_release_notes_author_prompt.dart**
Stage 3 Release Notes Author prompt generator. Produces rich, narrative release notes distinct from the CHANGELOG, featuring highlights, breaking changes, migration guides, and linked issues.

- **Signature:** `void main(List<String> args)`
- **Parameters:**
  - `args[0]`: `<prev_tag>` - The previous release tag.
  - `args[1]`: `<new_version>` - The new release version.
  - `args[2]` (Optional): `[bump_type]` - Options are `patch`, `minor`, or `major`. Will be inferred if omitted.
- **Example Execution:**
  ```bash
  dart run scripts/prompts/gemini_release_notes_author_prompt.dart v1.0.0 1.1.0 minor
  ```

### **gemini_triage_prompt.dart**
Generates an issue triage prompt for Gemini Pro to analyze a GitHub issue and perform comprehensive triage: type classification, priority assignment, and duplicate detection.

- **Signature:** `void main(List<String> args)`
- **Parameters:**
  - `args[0]`: `<issue_number>` - The GitHub issue number.
  - `args[1]`: `<issue_title>` - The issue title.
  - `args[2]`: `<issue_author>` - The author username.
  - `args[3]`: `<existing_labels>` - Labels already applied.
  - `args[4]`: `<issue_body>` - The content of the issue.
  - `args[5]`: `<open_issues_list>` - List of currently open issues to detect duplicates.
- **Example Execution:**
  ```bash
  dart run scripts/prompts/gemini_triage_prompt.dart "123" "Bug title" "user" "bug" "Body text" "Open issues list..."
  ```
