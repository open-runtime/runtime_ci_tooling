# Gemini Prompt Templates API Reference

This module contains Dart scripts that generate specialized prompts for Gemini AI models. These prompts are used in the CI/CD pipeline to automatically generate documentation (API references, examples, quickstarts, migration guides), explore repository changes, compose changelogs, write release notes, and triage issues.

## 1. Classes

### **CiConfig**
Reads package name and repo owner from `.runtime_ci/config.json`. Falls back to `runtime_isomorphic_library` / `open-runtime` when the config is unavailable (e.g., when running locally outside a properly initialized repository).

- **Fields**:
  - `packageName` (`String`): The package name retrieved from configuration or the fallback value.
  - `repoOwner` (`String`): The repository owner retrieved from configuration or the fallback value.
- **Methods/Getters**:
  - `static CiConfig get current`: Singleton getter that reads the config once and caches it.

**Example Usage**:
```dart
import 'package:runtime_ci_tooling/src/prompts/_ci_config.dart';

void main() {
  final config = CiConfig.current;
  print('Package: ${config.packageName}');
  print('Owner: ${config.repoOwner}');
}
```

## 2. Enums

*(No public enums are defined in this module)*

## 3. Extensions

*(No public extensions are defined in this module)*

## 4. Top-Level Prompt Generators

The following top-level scripts are meant to be executed via `dart run` to generate text prompts. The output is typically piped directly to the `gemini` CLI for autonomous execution.

### **autodoc_api_reference_prompt.dart**
- **Description**: Autodoc Stage: Generates a prompt for an AI agent to write an `API_REFERENCE.md` for a proto module. It provides the AI with protobuf source files and generated Dart code context.
- **Usage**: `dart run scripts/prompts/autodoc_api_reference_prompt.dart <module_name> <source_dir> [lib_dir]`
- **Parameters**: 
  - `module_name`: The name of the module to document.
  - `source_dir`: Path to the directory containing `.proto` files.
  - `lib_dir` *(Optional)*: Path to the generated Dart code directory.

### **autodoc_examples_prompt.dart**
- **Description**: Autodoc Stage: Generates a prompt for an AI agent to write an `EXAMPLES.md` with practical, copy-paste-ready code examples based on proto definitions, existing test patterns, and extensions.
- **Usage**: `dart run scripts/prompts/autodoc_examples_prompt.dart <module_name> <source_dir> [lib_dir]`
- **Parameters**:
  - `module_name`: The name of the module.
  - `source_dir`: Path to `.proto` files.
  - `lib_dir` *(Optional)*: Path to the generated Dart code (also infers test directories).

### **autodoc_migration_prompt.dart**
- **Description**: Autodoc Stage: Generates a prompt for an AI agent to write a `MIGRATION.md` guide based on `git diff` outputs of `.proto` files, detailing breaking changes, new features, and upgrade steps.
- **Usage**: `dart run scripts/prompts/autodoc_migration_prompt.dart <module_name> <source_dir> [prev_hash]`
- **Parameters**:
  - `module_name`: The name of the module.
  - `source_dir`: Path to `.proto` files.
  - `prev_hash` *(Optional)*: The previous Git commit hash to compare against. If omitted, uses recent git history.

### **autodoc_quickstart_prompt.dart**
- **Description**: Autodoc Stage: Generates a prompt for an AI agent to write a `QUICKSTART.md` guide. Provides module structure, services, and key message types to help users get started in under 5 minutes.
- **Usage**: `dart run scripts/prompts/autodoc_quickstart_prompt.dart <module_name> <source_dir> [lib_dir]`
- **Parameters**:
  - `module_name`: The name of the module.
  - `source_dir`: Path to `.proto` files.
  - `lib_dir` *(Optional)*: Path to the generated Dart code.

### **gemini_changelog_composer_prompt.dart**
- **Description**: Stage 2 CI Pipeline: Generates a prompt for the Changelog Composer Agent to securely update `CHANGELOG.md` with a concise Keep-a-Changelog entry based on stage 1 artifacts (`commit_analysis.json`, `pr_data.json`, etc.).
- **Usage**: `dart run scripts/prompts/gemini_changelog_composer_prompt.dart <prev_tag> <new_version>`
- **Parameters**:
  - `prev_tag`: The previous release tag (e.g., `v1.0.0`).
  - `new_version`: The target version being released (e.g., `1.0.1`).

### **gemini_changelog_prompt.dart**
- **Description**: Stage 1 CI Pipeline: Generates a prompt for the Explorer Agent to deeply analyze the repository history (git diffs, commit messages, PRs) and extract structured JSON artifacts (`commit_analysis.json`, `breaking_changes.json`, `pr_data.json`).
- **Usage**: `dart run scripts/prompts/gemini_changelog_prompt.dart <prev_tag> <new_version>`
- **Parameters**:
  - `prev_tag`: The previous release tag.
  - `new_version`: The target version.

### **gemini_documentation_prompt.dart**
- **Description**: Stage 2 CI Pipeline: Generates a prompt for a Documentation Update Agent to safely target and update the `README.md` file corresponding to changes extracted during Stage 1.
- **Usage**: `dart run scripts/prompts/gemini_documentation_prompt.dart <prev_tag> <new_version>`
- **Parameters**:
  - `prev_tag`: The previous release tag.
  - `new_version`: The target version.

### **gemini_release_notes_author_prompt.dart**
- **Description**: Stage 3 CI Pipeline: Generates a prompt for the Release Notes Author to write detailed, user-friendly release notes (`release_notes.md`), migration guides, highlights, and issue cross-references to be published on the GitHub Release page.
- **Usage**: `dart run scripts/prompts/gemini_release_notes_author_prompt.dart <prev_tag> <new_version> [bump_type]`
- **Parameters**:
  - `prev_tag`: The previous release tag.
  - `new_version`: The target version.
  - `bump_type` *(Optional)*: One of `patch`, `minor`, or `major`. If omitted, the script infers the bump type from the version change.

### **gemini_triage_prompt.dart**
- **Description**: GitHub Actions Issue Triage: Generates a prompt to instruct an Issue Triage Agent to analyze new issues, determining their type, priority, and functional area. It also attempts duplicate detection and drafts an initial helpful response.
- **Usage**: `dart run scripts/prompts/gemini_triage_prompt.dart <issue_number> <issue_title> <issue_author> <existing_labels> <issue_body> <open_issues_list>`
- **Parameters**:
  - `issue_number`: GitHub issue number.
  - `issue_title`: Title of the issue.
  - `issue_author`: GitHub username of the reporter.
  - `existing_labels`: Existing labels on the issue.
  - `issue_body`: The content of the issue body.
  - `open_issues_list`: A formatted string representing open issues for duplicate checking.
