# CI/CD CLI Quickstart

## 1. Overview
The CI/CD CLI module provides a cross-platform toolset for managing AI-powered release pipelines, automated issue triage, and repository maintenance. It acts as the orchestration layer for GitHub Actions workflows, executing Gemini AI code analysis, and automating local developer tasks like testing, package auditing, and documentation generation.

## 2. Import
```dart
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';

// Import specific commands if invoking them programmatically
import 'package:runtime_ci_tooling/src/cli/commands/test_command.dart';
```

## 3. Setup
The primary entry point is the `ManageCicdCli` command runner. You can instantiate it directly to programmatically run CLI commands or hook it into your own executable binary.

```dart
import 'dart:io';
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';

void main(List<String> args) async {
  final cli = ManageCicdCli();
  
  try {
    await cli.run(args);
  } catch (e) {
    stderr.writeln(e);
    exit(1);
  }
}
```

## 4. Common Operations

### Running Tests with Output Capture
You can programmatically invoke the `TestCommand` to run tests across a monorepo with rich GitHub Actions step summaries and robust output capture.
```dart
import 'package:runtime_ci_tooling/src/cli/commands/test_command.dart';

Future<void> runTests(String repoRoot) async {
  // Runs dart test on the root package and all configured sub-packages
  await TestCommand.runWithRoot(repoRoot);
}
```

### Auditing Workspace Packages
The `AuditAllCommand` can be invoked to recursively scan and fix `pubspec.yaml` dependencies across a workspace based on a central registry.
```dart
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';

Future<void> auditPackages() async {
  final cli = ManageCicdCli();
  // Runs the audit-all command with auto-fix enabled for warning-level issues
  await cli.run(['audit-all', '--fix', '--severity', 'warning']);
}
```

### Generating AI Documentation
Use the `AutodocCommand` to analyze Dart modules and auto-generate comprehensive markdown documentation using Gemini.
```dart
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';

Future<void> generateDocs() async {
  final cli = ManageCicdCli();
  // Initializes autodoc.json if missing, then forces regeneration
  await cli.run(['autodoc', '--init']);
  await cli.run(['autodoc', '--force']);
}
```

### Validating CI Configurations
Ensure `.runtime_ci/config.json`, workflows, and agent prompts are valid.
```dart
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';

Future<void> validateConfig() async {
  final cli = ManageCicdCli();
  await cli.run(['validate', '--verbose']);
}
```

### Auto-triaging Issues
Run the `triage` command with `--auto` to invoke Gemini to automatically prioritize and investigate all untriaged open issues.
```dart
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';

Future<void> triageIssues() async {
  final cli = ManageCicdCli();
  await cli.run(['triage', 'auto']);
}
```

## 5. Configuration

The CLI relies on standard configuration files typically stored in your repository root:
*   `.runtime_ci/config.json`: Core repository configuration, including sub-packages, platform runners, and feature flags.
*   `.runtime_ci/autodoc.json`: Configuration mapping source paths to output documentation paths for the `autodoc` command.
*   `.gemini/settings.json`: Configuration for local MCP (Model Context Protocol) servers.

**Environment Variables**:
*   `GEMINI_API_KEY`: Required for all AI-powered commands (`explore`, `compose`, `release-notes`, `autodoc`, `triage`).
*   `GITHUB_TOKEN` or `GH_TOKEN`: Required for GitHub CLI (`gh`) interactions and release syncing.
*   `CI_STAGING_DIR`: Overrides the default artifact staging directory (`/tmp` in CI, `Directory.systemTemp` locally).

## 6. Related Modules
*   **Triage** (`lib/src/triage/`): The underlying core logic and AI models for the `triage` command group.
*   **Utils** (`lib/src/cli/utils/`): Provides reusable logic used by commands, including `CiProcessRunner`, `RepoUtils`, and `StepSummary`.
