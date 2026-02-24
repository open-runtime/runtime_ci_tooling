# CI/CD CLI Module Quickstart

## 1. Overview
The **CI/CD CLI** module provides a cross-platform, programmatic, and terminal-based interface for managing the complete lifecycle of AI-powered release pipelines. Powered by Gemini Pro and GitHub Actions, it automates version detection, changelog composition, release notes generation, sub-package updates, and intelligent issue triage. It exposes the core `ManageCicdCli` command runner, which can be executed from the terminal or invoked programmatically in Dart.

## 2. Import
To use the CLI programmatically within your Dart tooling, import the main CLI runner and options:

```dart
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';
import 'package:runtime_ci_tooling/src/cli/options/global_options.dart';
```

## 3. Setup
You can invoke the CLI from the command line using `dart run runtime_ci_tooling:manage_cicd <command>`, or you can instantiate the `ManageCicdCli` runner programmatically.

```dart
import 'dart:io';
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';

void main(List<String> args) async {
  // Instantiate the CommandRunner
  final cli = ManageCicdCli();
  
  try {
    // Run the desired command with its arguments
    await cli.run(args);
  } on UsageException catch (e) {
    stderr.writeln(e.message);
    stderr.writeln(e.usage);
    exit(64);
  } catch (e) {
    stderr.writeln('Fatal error: $e');
    exit(1);
  }
}
```

## 4. Comprehensive Command Reference
To ensure complete coverage of the module's capabilities, below is a detailed list of every command class registered in `ManageCicdCli` and their relevant options:

*   **`InitCommand`** (`init`): Scans the repository and bootstraps `.runtime_ci/config.json`, `autodoc.json`, and installs Git hooks.
*   **`SetupCommand`** (`setup`): Installs all prerequisites (`gh`, `node`, `npm`, `jq`, `tree`, `@google/gemini-cli`).
*   **`ValidateCommand`** (`validate`): Validates all CI configuration files (JSON, YAML, TOML, Dart).
*   **`StatusCommand`** (`status`): Shows current CI/CD configuration status and required tool paths.
*   **`AnalyzeCommand`** (`analyze`): Runs `dart analyze` across the root and configured sub-packages (fails on errors).
*   **`TestCommand`** (`test`): Runs `dart test` across the root and sub-packages.
*   **`VersionCommand`** (`version`): Shows the next SemVer version detected from git history and Gemini analysis.
    *   `--prev-tag <tag>`: Override previous tag detection.
    *   `--version <ver>`: Override version (skip auto-detection).
*   **`DetermineVersionCommand`** (`determine-version`): Determines SemVer bump via Gemini and regex.
    *   `--output-github-actions`: Write version outputs to `$GITHUB_OUTPUT`.
*   **`ExploreCommand`** (`explore`): Runs the Stage 1 Explorer Agent (Gemini) locally to map commit and PR data.
*   **`ComposeCommand`** (`compose`): Runs the Stage 2 Changelog Composer (Gemini) to update `CHANGELOG.md`.
*   **`ReleaseNotesCommand`** (`release-notes`): Runs the Stage 3 Release Notes Author (Gemini) to create rich notes, linked issues, and migration guides.
*   **`ReleaseCommand`** (`release`): Orchestrates the full local release pipeline (runs `version`, `explore`, and `compose` sequentially).
*   **`CreateReleaseCommand`** (`create-release`): Creates a git tag, GitHub release, and commits all artifact changes automatically.
    *   `--artifacts-dir <dir>`: Directory containing downloaded CI artifacts.
    *   `--repo <owner/repo>`: GitHub repository slug.
*   **`AutodocCommand`** (`autodoc`): Generates and incrementally updates module documentation using Gemini Pro and `autodoc.json`.
    *   `--init`: Scan repo and create initial `autodoc.json`.
    *   `--force`: Regenerate all docs regardless of hash.
    *   `--module <id>`: Only generate for a specific module.
*   **`DocumentationCommand`** (`documentation`): General AI-powered documentation update runner.
*   **`TriageCommand`** (`triage`): Branch command for issue triage. Includes subcommands:
    *   **`TriageAutoCommand`** (`auto`): Auto-triage all untriaged open issues.
    *   **`TriageSingleCommand`** (`single <n>`): Triage a specific issue by number.
    *   **`TriagePreReleaseCommand`** (`pre-release`): Scan issues for an upcoming release and produce a manifest.
    *   **`TriagePostReleaseCommand`** (`post-release`): Link Sentry/GitHub post-release and close resolved issues.
    *   **`TriageResumeCommand`** (`resume <id>`): Resume a previously interrupted triage run.
    *   **`TriageStatusCommand`** (`status`): Show active lock and recent pipeline status.
*   **`ConfigureMcpCommand`** (`configure-mcp`): Sets up remote MCP servers (GitHub, Sentry) in `.gemini/settings.json`.
*   **`ArchiveRunCommand`** (`archive-run`): Archives `.runtime_ci/runs/` directories into permanent audit storage.
    *   `--run-dir <dir>`: Directory containing the CI run to archive.
*   **`MergeAuditTrailsCommand`** (`merge-audit-trails`): Merges scattered CI/CD audit artifacts from multiple GitHub Actions jobs.
    *   `--incoming-dir <dir>`: Directory containing incoming audit trail artifacts.
    *   `--output-dir <dir>`: Output directory for merged audit trails.
*   **`UpdateCommand`** (`update`): Safely updates templates, `.github/workflows/`, and `config.json` from the tooling baseline.
    *   `--force`, `--templates`, `--config`, `--workflows`, `--autodoc`, `--backup`
*   **`UpdateAllCommand`** (`update-all`): Discovers and updates multiple `runtime_ci_tooling` managed packages recursively.
    *   `--scan-root <dir>`, `--concurrency <n>`
*   **`ConsumersCommand`** (`consumers`): Discovers downstream repositories consuming the package and syncs release artifacts.
    *   `--org`, `--package`, `--output-dir`, `--discover-only`, `--releases-only`
*   **`VerifyProtosCommand`** (`verify-protos`): Verifies that `.proto` files have corresponding generated Dart code.

## 5. Common Operations

### Initializing a Project
Scaffold configurations, workflows, and Git hooks:

```dart
final cli = ManageCicdCli();
await cli.run(['init']);
```

### Triaging Issues
Execute the Gemini-powered triage pipeline on a single issue or all untriaged issues.

```dart
final cli = ManageCicdCli();

// Triage a single issue (Issue #42)
// Note: ManageCicdCli automatically translates `triage 42` to `triage single 42`.
await cli.run(['triage', '42']);

// Triage all open issues, ignoring cached results
await cli.run(['triage', 'auto', '--force']);
```

### Running the Full AI Release Pipeline
Generate the version bump rationale, changelog, and release notes:

```dart
final cli = ManageCicdCli();

// Run the full pipeline with verbose output, but do not write changes (dry-run)
await cli.run(['release', '--verbose', '--dry-run']);
```

### Generating Documentation
Incrementally generate or update documentation for your packages:

```dart
final cli = ManageCicdCli();

// Create initial autodoc.json tracking file
await cli.run(['autodoc', '--init']);

// Run the Gemini generation pipeline with high concurrency
await cli.run(['autodoc', '--force']);
```

### Updating Infrastructure
Update templates and workflows after bumping the tooling version:

```dart
final cli = ManageCicdCli();

// Update CI workflows and config safely
await cli.run(['update', '--workflows', '--config']);

// Recursively update all discovered Dart projects
await cli.run(['update-all', '--concurrency', '4']);
```

## 6. Configuration
The CLI behavior is dictated by:
*   **Environment Variables**:
    *   `GEMINI_API_KEY`: Required for all AI-powered operations (`explore`, `compose`, `triage`, `autodoc`, etc.).
    *   `GH_TOKEN` or `GITHUB_TOKEN`: Required for GitHub operations and MCP tool integrations.
    *   `CI_STAGING_DIR`: Override staging directory (defaults to system temp or `/tmp/` in CI).
*   **Configuration Files**: 
    *   `.runtime_ci/config.json`: Master CI/CD config specifying platforms, area labels, AI model choices, and sub-packages.
    *   `.runtime_ci/autodoc.json`: State file tracking file hashes to power incremental documentation generation.
    *   `.runtime_ci/template_versions.json`: State file tracking template versions and local modifications.
*   **Global Options**:
    *   `--dry-run`: Maps to `GlobalOptions.dryRun` to prevent filesystem/API writes. Show execution intents instead.
    *   `--verbose` / `-v`: Maps to `GlobalOptions.verbose` to enable rich debug logging and subprocess command tracing.

## 7. Related Modules
*   **Triage Module** (`lib/src/triage/`): The engine behind `TriageCommand`, managing investigation phases and GamePlans.
*   **Utils Module** (`lib/src/cli/utils/`): Provides helpers for process execution (`CiProcessRunner`), colored logging (`Logger`), repository navigation (`RepoUtils`), and file updates (`TemplateVersionTracker`).
