# CI/CD CLI Quickstart

## 1. Overview
The CI/CD CLI module provides a comprehensive command-line interface and programmatic entry point for managing the continuous integration, continuous delivery, and issue triage lifecycle. It orchestrates AI-powered agents (via Gemini) to automate changelog generation, release notes authoring, issue triaging, and documentation creation, while also supplying utilities for standard CI tasks like code analysis and test execution.

## 2. Import
```dart
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';
import 'package:runtime_ci_tooling/src/cli/options/global_options.dart';
```

## 3. Setup
To use the CLI programmatically in your Dart scripts, instantiate the `ManageCicdCli` runner. This runner registers all the available commands (like `release`, `triage`, `autodoc`, `status`, etc.).

```dart
import 'dart:io';
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';

Future<void> main(List<String> args) async {
  final runner = ManageCicdCli();
  
  try {
    await runner.run(args);
  } catch (e) {
    stderr.writeln(e);
    exit(1);
  }
}
```

## 4. Common Operations

### Checking CLI Status
You can programmatically invoke the status command to check configuration files, required tools (like `gh`, `git`, `gemini`), and MCP server configurations.

```dart
final runner = ManageCicdCli();
// Equivalent to running `dart run runtime_ci_tooling:manage_cicd status`
await runner.run(['status']);
```

### Initializing the Project
Scan the repository and generate the initial `.runtime_ci/config.json`, `.runtime_ci/autodoc.json`, and scaffold workflows.

```dart
final runner = ManageCicdCli();
await runner.run(['init']);
```

### Triaging Issues
Run the AI-powered issue triage pipeline using the `triage` command. It supports auto-triaging all open issues or targeting a single issue.

```dart
final runner = ManageCicdCli();

// Auto-triage all untriaged open issues with verbose logging
await runner.run(['triage', 'auto', '--verbose']);

// Triage a single issue by its number
await runner.run(['triage', 'single', '42']);

// Pre-release triage
await runner.run(['triage', 'pre-release', '--prev-tag', 'v1.0.0', '--version', '1.1.0']);
```

### Running the Release Pipeline
Execute the full local release pipeline, which includes version detection, exploring commits for changelog data, and composing the `CHANGELOG.md`.

```dart
final runner = ManageCicdCli();

// Run the release pipeline in dry-run mode
await runner.run(['release', '--dry-run']);

// Determine the next version
await runner.run(['version']);
```

### Managing Consumers
Discover repositories that consume the package and synchronize release artifacts across repositories.

```dart
final runner = ManageCicdCli();

// Discover consumers and run release syncing
await runner.run(['consumers', '--org', 'my-org', '--package', 'my_package']);
```

### Updating Workflows and Templates
Detects drift between the tooling package's templates and the consumer's installed copies, then updates intelligently.

```dart
final runner = ManageCicdCli();

// Update workflows, config, and templates
await runner.run(['update']);

// Batch-update all packages under a root directory
await runner.run(['update-all']);
```

### Generating Documentation
Initialize and generate documentation for the repository modules using the `autodoc` command.

```dart
final runner = ManageCicdCli();

// Scaffold the initial .runtime_ci/autodoc.json configuration
await runner.run(['autodoc', '--init']);

// Force regenerate documentation for a specific module without cache
await runner.run(['autodoc', '--force', '--module', 'cli']);
```

### Code Quality and Validation
Perform basic checks.

```dart
final runner = ManageCicdCli();

// Run `dart test`
await runner.run(['test']);

// Run `dart analyze`
await runner.run(['analyze']);

// Validate all configuration files
await runner.run(['validate']);
```

### Parsing Global Options
The module provides helpers to easily extract global options (like `--verbose` or `--dry-run`) from parsed `ArgResults`.

```dart
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';

void handleArgs(List<String> args) {
  final runner = ManageCicdCli();
  final results = runner.parse(args);
  
  final isDryRun = ManageCicdCli.isDryRun(results);
  final isVerbose = ManageCicdCli.isVerbose(results);
  
  if (isVerbose) {
    print('Verbose mode is enabled.');
  }
}
```

## 5. Configuration

The CLI's behavior is driven by environment variables and local repository configuration files.

### Environment Variables
- `GEMINI_API_KEY`: Required for all AI-powered features (exploration, changelog, triage, release-notes, autodoc).
- `GH_TOKEN` or `GITHUB_TOKEN`: Required for GitHub CLI (`gh`) operations and GitHub MCP server configuration.
- `CI_STAGING_DIR`: Optional. Specifies where CI artifacts are temporarily stored (defaults to `/tmp/` in CI or system temp locally).

### Configuration Files
- `.runtime_ci/config.json`: The central configuration defining CI behaviors, repository ownership, active agents, and triage thresholds. Generated via `manage_cicd init`.
- `.runtime_ci/autodoc.json`: Configuration for the autodoc generation pipeline. Generated via `manage_cicd autodoc --init`.
- `.gemini/settings.json`: Configuration for the Gemini MCP servers (can be bootstrapped via `manage_cicd configure-mcp`).
- `pubspec.yaml`: Read by the CLI to determine the current package name and base version for releases.

## 6. Related Modules
- `triage`: Contains the core logic, models (`GamePlan`, `TriageDecision`), and phases for the AI triage pipeline invoked by the `triage` commands.
- `utils`: Contains shared file, process, and GitHub utilities used by the CLI commands (e.g., `CiProcessRunner`, `RepoUtils`, `GeminiUtils`, `Logger`, `ReleaseUtils`).
