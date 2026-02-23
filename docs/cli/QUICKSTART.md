# CI/CD CLI Quickstart

## 1. Overview
The **CI/CD CLI** module provides a cross-platform command-line interface for managing AI-powered release pipelines, issue triage, and documentation generation. It orchestrates GitHub Actions workflows, local repository configuration (`.runtime_ci`), and integrates with Gemini CLI to automate tasks like changelog composition, release notes authoring, and repository scanning.

## 2. Usage as a Command-Line Tool
The primary way to use the CLI is via the `dart run` command from your terminal:

```bash
dart run runtime_ci_tooling:manage_cicd <command> [arguments]
```

## 3. Programmatic Setup
The CLI can also be embedded programmatically. The entry point is the `ManageCicdCli` class, which extends `CommandRunner`. It registers all available commands automatically.

```dart
import 'dart:io';
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';

Future<void> main(List<String> args) async {
  final cli = ManageCicdCli();
  
  try {
    await cli.run(args);
  } on UsageException catch (e) {
    stderr.writeln(e);
    exit(64);
  }
}
```

## 4. Global Options
The CLI provides global options that apply to all commands:
- `--dry-run`: Show what would be done without executing.
- `-v, --verbose`: Show detailed command output.

Example:
```dart
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';

Future<void> main() async {
  final cli = ManageCicdCli();
  await cli.run(['--verbose', 'status']);
}
```

## 5. Command Reference & Common Operations

### Initialization & Setup
- **`init`**: Scaffolds `.runtime_ci/config.json`, `autodoc.json`, and sets up git pre-commit hooks.
- **`setup`**: Installs all prerequisites (Node.js, Gemini CLI, `gh`, `jq`, `tree`).
- **`status`**: Shows current CI/CD configuration status, tool versions, and MCP server configuration.
- **`validate`**: Validates all configuration files (YAML, JSON, TOML, Dart prompts).
- **`configure-mcp`**: Sets up MCP servers (GitHub, Sentry) in `.gemini/settings.json`.

```dart
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';

Future<void> main() async {
  final cli = ManageCicdCli();
  await cli.run(['init']);
  await cli.run(['setup']);
  await cli.run(['status', '--verbose']);
  await cli.run(['configure-mcp']);
}
```

### Template Updates
- **`update`**: Updates templates, configs, and workflows from `runtime_ci_tooling`. Options include `--force`, `--templates`, `--config`, `--workflows`, `--autodoc`, and `--backup`.
- **`update-all`**: Discovers and updates all `runtime_ci_tooling` packages under a root directory. Accepts options like `--scan-root`, `--concurrency`, and passthrough flags.

```dart
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';

Future<void> main() async {
  final cli = ManageCicdCli();
  // Update workflows and make backups
  await cli.run(['update', '--workflows', '--backup']);
  // Update all packages in a directory concurrently
  await cli.run(['update-all', '--scan-root', '../projects', '--concurrency', '4']);
}
```

### Release Pipeline
The release commands use Gemini to automate versioning and changelogs:
- **`version`**: Shows the next SemVer version without side effects. Options: `--prev-tag`, `--version`.
- **`determine-version`**: Determines SemVer bump (useful in CI with `--output-github-actions`).
- **`explore`**: Runs Stage 1 Explorer Agent (Gemini 3 Pro Preview) to analyze commits and PRs.
- **`compose`**: Runs Stage 2 Changelog Composer to update `CHANGELOG.md`.
- **`release-notes`**: Runs Stage 3 Release Notes Author to generate rich release notes, migration guides, and highlights.
- **`documentation`**: Runs documentation updates via Gemini.
- **`release`**: Runs the full local release pipeline (`version` + `explore` + `compose`).
- **`create-release`**: Creates git tag, GitHub Release, and commits all changes. Options: `--artifacts-dir`, `--repo`.

```dart
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';

Future<void> main() async {
  final cli = ManageCicdCli();
  // Automatically determine next version and generate changelog
  await cli.run(['release']);

  // Specify specific version and tag manually
  await cli.run(['explore', '--prev-tag', 'v0.0.1', '--version', '0.0.2']);
  await cli.run(['compose', '--prev-tag', 'v0.0.1', '--version', '0.0.2']);
}
```

### AI-Powered Triage
The `triage` command is a modular pipeline for issue management. It supports global options like `--force`.
- **`triage single <number>`** (or `triage <number>`): Triage a specific issue.
- **`triage auto`**: Auto-triage all untriaged open issues.
- **`triage status`**: Show triage pipeline status.
- **`triage resume <run_id>`**: Resume an interrupted triage run.
- **`triage pre-release`**: Scan issues/Sentry and produce an issue manifest before a release. Requires `--prev-tag` and `--version`.
- **`triage post-release`**: Add comments and close issues post-release. Requires `--version` and `--release-tag`, optionally `--manifest` and `--release-url`.

```dart
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';

Future<void> main() async {
  final cli = ManageCicdCli();
  // Triage a single issue by number
  await cli.run(['triage', 'single', '42']);

  // Auto-triage all open untriaged issues
  await cli.run(['triage', 'auto']);

  // Run pre-release triage
  await cli.run(['triage', 'pre-release', '--prev-tag', 'v1.0.0', '--version', '1.1.0']);
}
```

### Documentation Generation
- **`autodoc`**: Generates or updates module docs using Gemini Pro based on `autodoc.json`. Options: `--init`, `--force`, `--module`, `--dry-run`.

```dart
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';

Future<void> main() async {
  final cli = ManageCicdCli();
  // Force regenerate all configured documentation modules
  await cli.run(['autodoc', '--force']);
}
```

### Code Quality & Utilities
- **`analyze`**: Runs `dart analyze` and fails on errors.
- **`test`**: Runs `dart test` excluding integration tags.
- **`verify-protos`**: Verifies proto source and generated files exist.
- **`consumers`**: Discovers `runtime_ci_tooling` consumers and syncs latest release data. Options: `--org`, `--package`, `--discover-only`, `--releases-only`, `--tag`, `--tag-regex`, `--include-prerelease`, `--resume`, `--search-first`, `--discovery-workers`, `--release-workers`, `--repo-limit`, `--output-dir`.
- **`archive-run`**: Archives a CI run to `.runtime_ci/audit/` for permanent storage. Options: `--run-dir`.
- **`merge-audit-trails`**: Merges CI/CD audit artifacts from multiple jobs into a single run directory. Options: `--incoming-dir`, `--output-dir`.

```dart
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';

Future<void> main() async {
  final cli = ManageCicdCli();
  await cli.run(['analyze']);
  await cli.run(['consumers', '--org', 'my-org', '--discover-only']);
}
```

## 6. Configuration
The CLI relies heavily on the following configuration files and environment variables:

**Files**:
- `.runtime_ci/config.json`: Core repository config, CI features, and agent thresholds.
- `.runtime_ci/autodoc.json`: Source paths and output rules for documentation generation.
- `.gemini/settings.json`: Configuration for GitHub and Sentry MCP servers.

**Environment Variables**:
- `GEMINI_API_KEY`: Required for all AI-powered commands (`explore`, `compose`, `release-notes`, `triage`, `autodoc`, etc.).
- `GH_TOKEN` or `GITHUB_TOKEN` or `GITHUB_PAT`: Required for GitHub CLI (`gh`) operations and GitHub MCP server.
- `CI_STAGING_DIR`: Optional override for the staging directory used in CI pipelines (defaults to system temp directory).

## 7. Related Modules
- `Triage` (`lib/src/triage/`): The core business logic, phase execution, and models (e.g., `GamePlan`, `TriageDecision`) utilized by the `triage` commands.
- `Prompts` (`lib/src/prompts/`): Executable Dart scripts that generate context-aware prompts for the Gemini CLI.
