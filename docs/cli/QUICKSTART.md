# QUICKSTART: CI/CD CLI Module

## 1. Overview
The CI/CD CLI module provides a comprehensive command-line interface for managing AI-powered release pipelines, issue triage, and repository automation. It exposes the `ManageCicdCli` class, which extends Dart's `CommandRunner` to execute workflows for changelog generation, Sentry integration, code analysis, template management, and release artifact syncing.

## 2. Import
To programmatically consume the CLI in your own Dart scripts:
```dart
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';
import 'package:runtime_ci_tooling/src/cli/options/global_options.dart';
import 'package:runtime_ci_tooling/src/cli/options/version_options.dart';
// Import specific options as needed
```

## 3. Setup & Programmatic Execution
Most users will interact with the CLI directly via `dart run runtime_ci_tooling:manage_cicd`. However, you can instantiate and run the `ManageCicdCli` programmatically in your own executable.

```dart
import 'dart:io';
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';

void main(List<String> args) async {
  final cli = ManageCicdCli();
  
  try {
    await cli.run(args);
  } on UsageException catch (e) {
    stderr.writeln(e.message);
    stderr.writeln(e.usage);
    exit(64);
  } catch (e) {
    stderr.writeln('Error: $e');
    exit(1);
  }
}
```

## 4. Global Options
The CLI accepts global options before the command name. These are parsed into a `GlobalOptions` instance:

- `--dry-run`: Show what would be done without executing side-effects.
- `-v`, `--verbose`: Enable detailed command output.

Example:
```bash
dart run runtime_ci_tooling:manage_cicd --dry-run --verbose <command>
```

Programmatic parsing:
```dart
import 'package:args/args.dart';
import 'package:runtime_ci_tooling/src/cli/options/global_options.dart';

final parser = ArgParser();
GlobalOptionsArgParser.populateParser(parser);
final results = parser.parse(['--verbose', '--dry-run']);
final globalOptions = GlobalOptions.fromArgResults(results);

print(globalOptions.verbose); // true
print(globalOptions.dryRun); // true
```

## 5. Available Commands & Options

### `init`
Scan the current repository and generate necessary configuration files (`.runtime_ci/config.json`, `autodoc.json`, `.gitignore` entries, and starter workflows).
```bash
dart run runtime_ci_tooling:manage_cicd init
```

### `setup`
Install all required system tools (Node.js, Gemini CLI, GitHub CLI, jq).
```bash
dart run runtime_ci_tooling:manage_cicd setup
```

### `validate`
Validate all configuration files (YAML, JSON, TOML, Dart prompts) within the workspace.
```bash
dart run runtime_ci_tooling:manage_cicd validate
```

### `status`
Show the current CI/CD configuration status, tool availability, and environment readiness.
```bash
dart run runtime_ci_tooling:manage_cicd status
```

### `analyze` & `test` & `verify-protos`
Standard Dart operations wrapped by the CLI:
- `analyze`: Run `dart analyze` (failing on errors only).
- `test`: Run `dart test` (excluding tags like `gcp,integration`).
- `verify-protos`: Verify that proto source and generated files exist.

### `version` & `determine-version`
Determine the next Semantic Versioning bump based on commit history.
- `version`: Show the next version (no side effects). Accepts `VersionOptions`.
- `determine-version`: Write the version bump rationale. Accepts `DetermineVersionOptions` & `VersionOptions`:
  - `--output-github-actions`: Write version outputs to `$GITHUB_OUTPUT` for GitHub Actions.

```bash
dart run runtime_ci_tooling:manage_cicd determine-version --output-github-actions
```

### `explore` (Stage 1)
Run the Stage 1 Explorer Agent (Gemini 3 Pro Preview) to analyze commits and PRs.
Accepts `VersionOptions`:
- `--prev-tag <tag>`: Override previous tag detection.
- `--version <ver>`: Override version (skip auto-detection).

```bash
dart run runtime_ci_tooling:manage_cicd explore --prev-tag v1.0.0 --version 1.1.0
```

### `compose` (Stage 2)
Run the Stage 2 Changelog Composer (Gemini Pro) to generate `CHANGELOG.md` updates.
Accepts `VersionOptions`.

### `release-notes` (Stage 3)
Run the Stage 3 Release Notes Author (Gemini 3 Pro Preview) to create rich narrative release notes, migration guides, and highlights.
Accepts `VersionOptions`.

### `documentation`
Run documentation update via Gemini 3 Pro Preview.
Accepts `VersionOptions`.

### `release`
Run the full local release pipeline (`version` + `explore` + `compose`).
Accepts `VersionOptions`.

### `create-release`
Create a git tag, GitHub Release, and commit all changes.
Accepts `CreateReleaseOptions` & `VersionOptions`:
- `--artifacts-dir <dir>`: Directory containing downloaded CI artifacts.
- `--repo <owner/repo>`: GitHub repository slug.

### `triage`
The issue triage pipeline with AI-powered investigation.
Subcommands:
- `single <number>` or `<number>`: Triage a single issue.
- `auto`: Auto-triage all untriaged open issues.
- `status`: Show triage pipeline status.
- `resume <run_id>`: Resume a previously interrupted triage run.
- `pre-release`: Scan issues for an upcoming release (Requires `--prev-tag` and `--version`).
- `post-release`: Close loop after release (Requires `--version`, `--release-tag`). Optional: `--release-url`, `--manifest`.

Options class `TriageOptions` provides:
- `--force`: Override an existing triage lock.

Example:
```bash
dart run runtime_ci_tooling:manage_cicd triage 42 --force
```

### `autodoc`
Generate or update module documentation (API Reference, Quickstart, etc.) using Gemini.
Accepts `AutodocOptions`:
- `--init`: Scan repo and create initial autodoc.json.
- `--force`: Regenerate all docs regardless of hash.
- `--module <id>`: Only generate for a specific module.

```bash
dart run runtime_ci_tooling:manage_cicd autodoc --force --module core
```

### `update` & `update-all`
Update templates, configs, and workflows from `runtime_ci_tooling`.
Accepts `UpdateOptions` / `UpdateAllOptions`:
- `--force`: Overwrite all files regardless of local customizations.
- `--templates`: Only update template files.
- `--config`: Only merge new keys into `.runtime_ci/config.json`.
- `--workflows`: Only update GitHub workflow files.
- `--autodoc`: Re-scan `lib/src/` and update `autodoc.json`.
- `--backup`: Write `.bak` backup before overwriting.
- `--scan-root <dir>` (for `update-all`): Root directory to scan for packages.
- `--concurrency <N>` (for `update-all`): Max concurrent updates.

### `consumers`
Discover `runtime_ci_tooling` consumers and sync latest release data.
Options include:
- `--org <org>`, `--package <pkg>`, `--output-dir <dir>`
- `--discover-only`, `--releases-only`
- `--tag <tag>`, `--tag-regex <regex>`, `--include-prerelease`
- `--resume`, `--search-first`
- `--discovery-workers <N>`, `--release-workers <N>`, `--repo-limit <N>`

### `configure-mcp`
Set up MCP servers (GitHub, Sentry) in `.gemini/settings.json`.

### `archive-run` & `merge-audit-trails`
- `archive-run`: Archive `.runtime_ci/runs/` to `.runtime_ci/audit/vX.X.X/` for permanent storage. Accepts `ArchiveRunOptions` (`--run-dir`) and `VersionOptions`.
- `merge-audit-trails`: Merge CI/CD audit artifacts from multiple jobs (CI use). Accepts `MergeAuditTrailsOptions` (`--incoming-dir`, `--output-dir`).

## 6. Environment Dependencies
The CLI commands rely on specific environment variables:
- **`GEMINI_API_KEY`**: Required for all AI-powered commands (`explore`, `compose`, `release-notes`, `triage`, `autodoc`, `documentation`).
- **`GH_TOKEN` / `GITHUB_TOKEN`**: Required for GitHub API interactions via `gh` CLI.
- **`GITHUB_OUTPUT`, `GITHUB_STEP_SUMMARY`**: Evaluated during CI environments for proper integration.
