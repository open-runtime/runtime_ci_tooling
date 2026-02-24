# Quickstart: CI/CD Automation CLI

## 1. Overview
The **CI/CD Automation CLI** (`manage_cicd`) provides comprehensive, cross-platform tooling for managing AI-powered release pipelines, both locally and in CI environments. It automates complex engineering tasks such as issue triage, repository discovery, changelog composition, release notes authoring, and documentation generation using Gemini.

It also includes utility commands for validating configurations, managing templates, and ensuring code quality across the workspace.

## 2. Installation & Setup

Before running commands, ensure your environment is configured. The CLI relies on external tools like `gh`, `gemini`, `git`, `node`, and `jq`.

```bash
# Install required tools and dependencies automatically
dart run runtime_ci_tooling:manage_cicd setup

# Validate your environment and configuration
dart run runtime_ci_tooling:manage_cicd status
```

### Environment Variables
- `GEMINI_API_KEY`: Required for AI-powered commands (e.g., `explore`, `compose`, `release-notes`, `triage`, `autodoc`).
- `GH_TOKEN` or `GITHUB_TOKEN`: Required for GitHub CLI (`gh`) interactions.
- `CI_STAGING_DIR`: Override the default staging directory for artifacts (defaults to `/tmp` in CI or system temp locally).

## 3. Initializing a Repository

To adopt `runtime_ci_tooling` in a new repository, run the `init` command. This scaffolds required configuration files (`.runtime_ci/config.json`, `autodoc.json`, `CHANGELOG.md`) and installs a pre-commit hook.

```bash
dart run runtime_ci_tooling:manage_cicd init
```

*Note: After initialization, you can customize `.runtime_ci/config.json` to configure area labels, cross-repo capabilities, and Gemini model preferences.*

## 4. Command Reference & Examples

The CLI provides numerous commands covering the full development lifecycle. Global options `--dry-run` and `--verbose` (`-v`) can be applied to any command.

### 4.1 Release Pipeline Workflows
The AI-powered release pipeline operates in stages to determine versions, generate changelogs, and author narrative release notes.

- **`version`**: Show the next semantic version based on commit history.
  ```bash
  dart run runtime_ci_tooling:manage_cicd version --prev-tag v1.0.0
  ```

- **`determine-version`**: Determine the version bump and optionally write to GitHub Actions output.
  ```bash
  dart run runtime_ci_tooling:manage_cicd determine-version --output-github-actions
  ```

- **`explore`** (Stage 1): Run the Explorer Agent to analyze commits and PRs.
  ```bash
  dart run runtime_ci_tooling:manage_cicd explore --version 1.1.0
  ```

- **`compose`** (Stage 2): Use Gemini to append updates to `CHANGELOG.md`.
  ```bash
  dart run runtime_ci_tooling:manage_cicd compose
  ```

- **`release-notes`** (Stage 3): Generate rich narrative release notes, migration guides, and link related issues.
  ```bash
  dart run runtime_ci_tooling:manage_cicd release-notes
  ```

- **`release`**: Run the full local release pipeline (runs version, explore, and compose sequentially).
  ```bash
  dart run runtime_ci_tooling:manage_cicd release --verbose
  ```

- **`create-release`**: Finalize the release by committing changes, tagging, and creating a GitHub Release.
  ```bash
  dart run runtime_ci_tooling:manage_cicd create-release --version 1.1.0 --artifacts-dir .runtime_ci/release_artifacts --repo org/repo
  ```

### 4.2 Issue Triage
The AI-powered issue triage system manages the lifecycle of GitHub issues using Gemini.

- **Auto-Triage**: Process all open untriaged issues.
  ```bash
  dart run runtime_ci_tooling:manage_cicd triage auto --force
  ```

- **Single Issue**: Triage a specific issue by number.
  ```bash
  dart run runtime_ci_tooling:manage_cicd triage single 42
  # Or using shorthand:
  dart run runtime_ci_tooling:manage_cicd triage 42
  ```

- **Pre-Release Triage**: Correlate issues and Sentry errors against the diff for an upcoming release.
  ```bash
  dart run runtime_ci_tooling:manage_cicd triage pre-release --prev-tag v1.0.0 --version 1.1.0
  ```

- **Post-Release Triage**: Close issues and update comments after a release is published.
  ```bash
  dart run runtime_ci_tooling:manage_cicd triage post-release --version 1.1.0 --release-tag v1.1.0 --release-url https://github.com/org/repo/releases/tag/v1.1.0
  ```

- **Status & Resume**: Check the status of the triage lock and runs, or resume an interrupted run.
  ```bash
  dart run runtime_ci_tooling:manage_cicd triage status
  dart run runtime_ci_tooling:manage_cicd triage resume triage_2026-02-24T12-34-56_1234
  ```

### 4.3 Documentation Generation (`autodoc`)
Automatically generates and reviews documentation based on `.runtime_ci/autodoc.json`.

```bash
# Generate all module docs defined in autodoc.json
dart run runtime_ci_tooling:manage_cicd autodoc

# Force regeneration regardless of source file hashes
dart run runtime_ci_tooling:manage_cicd autodoc --force

# Generate for a specific module only
dart run runtime_ci_tooling:manage_cicd autodoc --module core

# Re-scan lib/src/ and create/update autodoc.json
dart run runtime_ci_tooling:manage_cicd autodoc --init
```

### 4.4 Template & Configuration Management
Keep your repository's workflows and configurations up-to-date with the tooling.

- **`update`**: Updates GitHub Actions workflows, Gemini configurations, and config schemas.
  ```bash
  dart run runtime_ci_tooling:manage_cicd update --backup --force
  
  # Update specific parts only
  dart run runtime_ci_tooling:manage_cicd update --workflows
  dart run runtime_ci_tooling:manage_cicd update --templates
  dart run runtime_ci_tooling:manage_cicd update --config
  dart run runtime_ci_tooling:manage_cicd update --autodoc
  ```

- **`update-all`**: Run the update command across multiple consumer packages under a root directory.
  ```bash
  dart run runtime_ci_tooling:manage_cicd update-all --scan-root /path/to/workspace --concurrency 4 --force
  ```

### 4.5 Consumer Discovery & Sync (`consumers`)
Discover repositories that consume a package and sync their latest release artifacts into `.consumers/`.

```bash
# Scan default orgs (open-runtime, pieces-app) for consumers and download releases
dart run runtime_ci_tooling:manage_cicd consumers --package runtime_ci_tooling

# Scan specific orgs and run only discovery (no downloads)
dart run runtime_ci_tooling:manage_cicd consumers --org my-org --package my_package --discover-only

# Other useful flags:
# --releases-only (Skip discovery, just sync releases)
# --tag v1.0.0 (Fetch a specific tag)
# --include-prerelease (Include pre-releases)
# --discovery-workers 4 / --release-workers 4 (Concurrency control)
```

### 4.6 Code Quality & Validation
- **`analyze`**: Run `dart analyze` (configured to fail on errors only).
  ```bash
  dart run runtime_ci_tooling:manage_cicd analyze
  ```

- **`test`**: Run `dart test` excluding integration tags.
  ```bash
  dart run runtime_ci_tooling:manage_cicd test
  ```

- **`validate`**: Validate that all configuration files (JSON, YAML, TOML) are syntactically valid.
  ```bash
  dart run runtime_ci_tooling:manage_cicd validate
  ```

- **`verify-protos`**: Verify that `.proto` files have corresponding generated Dart files.
  ```bash
  dart run runtime_ci_tooling:manage_cicd verify-protos
  ```

### 4.7 Audit Trail Management
- **`merge-audit-trails`**: Merge partial CI audit artifacts from parallel workflow jobs.
  ```bash
  dart run runtime_ci_tooling:manage_cicd merge-audit-trails --incoming-dir .runtime_ci/runs_incoming --output-dir .runtime_ci/runs
  ```

- **`archive-run`**: Move a CI run into the permanent `.runtime_ci/audit/` directory.
  ```bash
  dart run runtime_ci_tooling:manage_cicd archive-run --run-dir .runtime_ci/runs/run_xyz --version 1.0.0
  ```

### 4.8 MCP Configuration
- **`configure-mcp`**: Inject GitHub and Sentry MCP server definitions into `.gemini/settings.json`.
  ```bash
  dart run runtime_ci_tooling:manage_cicd configure-mcp
  ```

## 5. Programmatic Usage

You can invoke the CLI from within your own Dart scripts. `ManageCicdCli` automatically wires up all commands.

```dart
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';
import 'package:runtime_ci_tooling/src/cli/options/global_options.dart';

void main(List<String> args) async {
  final cli = ManageCicdCli();
  
  try {
    // You can programmatically pass arguments:
    // await cli.run(['explore', '--version', '1.2.0', '--verbose']);
    await cli.run(args);
  } on UsageException catch (e) {
    print(e.message);
    print(e.usage);
  }
}
```
