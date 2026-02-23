# CI/CD CLI Quickstart

## 1. Overview
The **CI/CD CLI** module provides a cross-platform command-line interface for managing the AI-powered release pipeline, document generation, repository discovery, and issue triage. It includes a comprehensive suite of commands that leverage the Gemini CLI to explore commit histories, compose changelogs, author release notes, generate module documentation, and automatically triage GitHub issues.

## 2. Setup and Usage
The CLI relies on the `ManageCicdCli` command runner. You can interact with the tool via the pre-compiled executable in any repository where this package is installed:

```bash
dart run runtime_ci_tooling:manage_cicd <command>
```

To use the CLI programmatically or extend its functionality, import the main CLI runner and the corresponding options classes:

```dart
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';
import 'package:runtime_ci_tooling/src/cli/options/global_options.dart';

void main(List<String> args) async {
  final cli = ManageCicdCli();
  
  try {
    await cli.run(args);
  } catch (e) {
    print('CLI Error: $e');
  }
}
```

## 3. Available Commands

The CLI supports a robust set of commands for managing the full CI/CD lifecycle:

### Project Initialization & Setup
- `init`: Scan the repo and generate `.runtime_ci/config.json`, `autodoc.json`, and scaffold workflows.
- `setup`: Install all prerequisites (Node.js, Gemini CLI, `gh`, `jq`, `tree`).
- `configure-mcp`: Set up Model Context Protocol (MCP) servers (GitHub, Sentry) in `.gemini/settings.json`.
- `validate`: Validate all configuration files (YAML, JSON, TOML, Dart prompts).
- `status`: Show current CI/CD configuration status.
- `update`: Update templates, configs, and workflows from `runtime_ci_tooling`.
- `update-all`: Discover and update all `runtime_ci_tooling` packages under a root directory.

### Code Quality & Testing
- `analyze`: Run `dart analyze` (fail on errors only).
- `test`: Run `dart test`.
- `verify-protos`: Verify proto source and generated Dart files exist.

### AI-Powered Release Pipeline
- `release`: Run the full local release pipeline (`version` + `explore` + `compose`).
- `version`: Determine the next SemVer version from commit history without side effects.
- `determine-version`: Determine SemVer bump via Gemini + regex (outputs JSON and to `$GITHUB_OUTPUT`).
- `explore`: Run Stage 1 Explorer Agent (Gemini 3 Pro Preview) to analyze commits, PRs, and breaking changes.
- `compose`: Run Stage 2 Changelog Composer to update `CHANGELOG.md`.
- `release-notes`: Run Stage 3 Release Notes Author to generate rich release notes, migration guides, and highlights.
- `documentation`: Run documentation update via Gemini.
- `create-release`: Create git tag, GitHub Release, and commit all changes.

### Issue Triage
The `triage` command group provides an AI-powered pipeline:
- `triage auto`: Auto-triage all untriaged open issues.
- `triage single <number>`: Triage a single specific issue.
- `triage status`: Show triage pipeline status.
- `triage resume <run_id>`: Resume a previously interrupted triage run.
- `triage pre-release`: Scan issues for upcoming release (requires `--prev-tag` and `--version`).
- `triage post-release`: Close loop after release (requires `--version` and `--release-tag`).

### Documentation Generation
- `autodoc`: Generate/update module docs using Gemini based on `autodoc.json`.

### CI/CD Artifacts & Consumers
- `archive-run`: Archive `.runtime_ci/runs/` to `.runtime_ci/audit/vX.X.X/` for permanent storage.
- `merge-audit-trails`: Merge CI/CD audit artifacts from multiple jobs (for CI use).
- `consumers`: Discover `runtime_ci_tooling` consumers and sync latest release data.

## 4. Common Workflows

### Initializing a Project
Scaffold `.runtime_ci/config.json`, `CHANGELOG.md`, `.gitignore` entries, and configure GitHub/Sentry MCPs:

```bash
dart run runtime_ci_tooling:manage_cicd init
dart run runtime_ci_tooling:manage_cicd setup
dart run runtime_ci_tooling:manage_cicd configure-mcp
```

### Auto-Generating Documentation
Generate or update API references and quickstarts via `autodoc`.

```bash
# 1. Scaffold autodoc.json based on the lib/src/ layout
dart run runtime_ci_tooling:manage_cicd autodoc --init

# 2. Generate documentation using Gemini (reads from autodoc.json)
dart run runtime_ci_tooling:manage_cicd autodoc

# 3. Force regeneration of a specific module
dart run runtime_ci_tooling:manage_cicd autodoc --force --module commands
```

### Issue Triage
Automate issue management with `triage`.

```bash
# Auto-triage all open untriaged issues
dart run runtime_ci_tooling:manage_cicd triage auto

# Triage a single specific issue (can also use 'triage 42' as shorthand)
dart run runtime_ci_tooling:manage_cicd triage single 42

# View current triage lock status and run history
dart run runtime_ci_tooling:manage_cicd triage status
```

### Release Pipeline Execution
Execute the full pipeline locally:

```bash
dart run runtime_ci_tooling:manage_cicd release --prev-tag v0.1.0 --version 0.2.0
```

Or run specific stages individually:
```bash
dart run runtime_ci_tooling:manage_cicd explore --prev-tag v0.1.0 --version 0.2.0
dart run runtime_ci_tooling:manage_cicd compose --prev-tag v0.1.0 --version 0.2.0
dart run runtime_ci_tooling:manage_cicd release-notes --prev-tag v0.1.0 --version 0.2.0
```

### Package Management & Discovery
Discover dependent projects and update shared pipeline workflows:

```bash
# Batch update runtime_ci_tooling configurations across local repositories
dart run runtime_ci_tooling:manage_cicd update-all --force --workflows

# Discover consumer repositories across GitHub orgs and sync release artifacts
dart run runtime_ci_tooling:manage_cicd consumers --org open-runtime --package runtime_ci_tooling
```

## 5. Configuration

### Files
- **`.runtime_ci/config.json`**: The core repository config. Stores CI workflow parameters, area labels, MCP settings, and feature flags.
- **`.runtime_ci/autodoc.json`**: Tracks the generation state for docs, containing source paths, hashes, and prompt templates for each target module.
- **`.gemini/settings.json`**: Configures the MCP servers utilized by the Gemini CLI agents for operations like `explore` and `triage`.

### Environment Variables
- `GEMINI_API_KEY`: Required for executing AI tasks (`explore`, `compose`, `release-notes`, `autodoc`, `triage`).
- `GH_TOKEN`, `GITHUB_TOKEN`, or `GITHUB_PAT`: Required to communicate with the GitHub API (used by `gh` and the GitHub MCP server).
- `SENTRY_ACCESS_TOKEN`: Required if Sentry MCP is enabled and requires authorization.
- `CI_STAGING_DIR`: Optional override for the path where intermediate JSON artifacts (like `commit_analysis.json`) are buffered during multi-stage CI runs.
