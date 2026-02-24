# CI/CD CLI Quickstart

## 1. Overview
The CI/CD CLI module provides a cross-platform toolset for managing AI-powered release pipelines locally and in CI. It exposes the `ManageCicdCli` command runner and various utilities to handle repository configuration, version detection, automated changelog generation, and issue triage.

## 2. Command Line Usage
The CLI is typically executed directly via `dart run`. You can also globally activate it.

### Initializing a Project
To set up `.runtime_ci/config.json`, `.runtime_ci/autodoc.json`, and basic templates:
```bash
dart run runtime_ci_tooling:manage_cicd init
```

### Installing Prerequisites
Install required tools (`gh`, `jq`, `node`, `npm`, `gemini`):
```bash
dart run runtime_ci_tooling:manage_cicd setup
```

### Validating Configuration
Ensure your configuration files are valid:
```bash
dart run runtime_ci_tooling:manage_cicd validate
```

### AI-Powered Release Pipeline
You can run the release pipeline stages manually or all at once:
```bash
# Determine next version and rationale
dart run runtime_ci_tooling:manage_cicd version

# Stage 1: Explore (analyze commits and PRs)
dart run runtime_ci_tooling:manage_cicd explore

# Stage 2: Compose (update CHANGELOG.md)
dart run runtime_ci_tooling:manage_cicd compose

# Stage 3: Release Notes (generate GitHub release body)
dart run runtime_ci_tooling:manage_cicd release-notes

# Run all stages at once
dart run runtime_ci_tooling:manage_cicd release
```

### Issue Triage
Manage GitHub issues via the AI triage system:
```bash
# Triage a specific issue
dart run runtime_ci_tooling:manage_cicd triage 42

# Auto-triage all untriaged open issues
dart run runtime_ci_tooling:manage_cicd triage --auto

# View triage status
dart run runtime_ci_tooling:manage_cicd triage --status
```

## 3. Programmatic Usage

### Import
```dart
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';
import 'package:runtime_ci_tooling/src/cli/utils/repo_utils.dart';
import 'package:runtime_ci_tooling/src/cli/utils/logger.dart';
import 'package:runtime_ci_tooling/src/cli/utils/process_runner.dart';
import 'package:runtime_ci_tooling/src/cli/options/global_options.dart';
```

### Running CLI Commands Programmatically
To use the CLI programmatically, instantiate the `ManageCicdCli` class. It extends the standard Dart `CommandRunner<void>` and automatically registers all necessary commands.

```dart
final cli = ManageCicdCli();

// Install prerequisites (Node.js, Gemini CLI, gh, jq)
await cli.run(['setup']);

// Validate config files (e.g., .runtime_ci/config.json)
await cli.run(['validate']);
```

### Finding the Repository Root
Use `RepoUtils` to locate the root of the repository containing the `pubspec.yaml` matching the configured package name.
```dart
final repoRoot = RepoUtils.findRepoRoot();
if (repoRoot == null) {
  Logger.error('Could not find repo root.');
  return;
}
Logger.success('Found repository at: $repoRoot');
```

### Executing Shell Processes
Use `CiProcessRunner` to cleanly interact with external shell dependencies.
```dart
if (CiProcessRunner.commandExists('gemini')) {
  final version = CiProcessRunner.runSync(
    'gemini --version',
    repoRoot,
    verbose: true,
  );
  Logger.info('Gemini CLI version: $version');
} else {
  Logger.warn('Gemini CLI is not installed.');
}
```

### Parsing Global CLI Options
Extract global flags like `--dry-run` or `--verbose` from `ArgResults`.
```dart
// Assuming `argResults` is available from your Command implementation
final globalOptions = ManageCicdCli.parseGlobalOptions(argResults);

if (globalOptions.dryRun) {
  Logger.info('[DRY-RUN] Executing without side-effects.');
}
```

## 4. Configuration
The CLI module relies on several configuration files and environment variables:
*   **Environment Variables**:
    *   `GEMINI_API_KEY`: Required for AI-powered stages (`explore`, `compose`, `release-notes`, `triage`).
    *   `GH_TOKEN` or `GITHUB_TOKEN`: Required for interacting with the GitHub API.
    *   `CI_STAGING_DIR`: Override the default `/tmp` directory used for staging CI artifacts.
*   **Files**:
    *   `.runtime_ci/config.json`: Core repository and CI feature configuration.
    *   `.runtime_ci/autodoc.json`: Configuration for the `autodoc` command.
    *   `.gemini/settings.json`: Local Gemini CLI configuration (e.g., MCP servers).
