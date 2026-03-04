# CI/CD CLI Quickstart

## 1. Overview
The CI/CD CLI module (`manage_cicd`) provides cross-platform automation for the AI-powered release lifecycle, issue triage, and code quality workflows. It exposes the `ManageCicdCli` command runner and various utility classes to locally test or execute CI/CD stages like changelog composition, release note authoring, repository auditing, and workflow generation.

## 2. Import
```dart
// Core CLI Runner
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';

// CLI Utility Classes
import 'package:runtime_ci_tooling/src/cli/utils/logger.dart';
import 'package:runtime_ci_tooling/src/cli/utils/repo_utils.dart';
import 'package:runtime_ci_tooling/src/cli/utils/process_runner.dart';
import 'package:runtime_ci_tooling/src/cli/utils/version_detection.dart';

// Audit Module
import 'package:runtime_ci_tooling/src/cli/utils/audit/package_registry.dart';
import 'package:runtime_ci_tooling/src/cli/utils/audit/pubspec_auditor.dart';
import 'package:runtime_ci_tooling/src/cli/utils/audit/audit_finding.dart';
```

## 3. Setup
The primary way to use the module programmatically is by instantiating the `ManageCicdCli` class, which extends the standard Dart `CommandRunner`.

```dart
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';

Future<void> main(List<String> args) async {
  final cli = ManageCicdCli();
  
  try {
    await cli.run(args);
  } on UsageException catch (e) {
    print(e.message);
    print(e.usage);
  }
}
```

## 4. Common Operations

### Executing the AI-Powered Release Pipeline
Run the full local release lifecycle, which sequentially runs the `version`, `explore`, and `compose` commands.

```dart
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';

Future<void> main() async {
  final cli = ManageCicdCli();

  // Run the full pipeline with detailed logs
  await cli.run(['--verbose', 'release']);

  // Alternatively, run specific stages
  await cli.run(['explore', '--prev-tag', 'v1.0.0', '--version', '1.1.0']);
  await cli.run(['compose', '--prev-tag', 'v1.0.0', '--version', '1.1.0']);
}
```

### Running Code Quality and Monorepo Maintenance
Execute `dart analyze` and `dart test` across the root package and all configured sub-packages.

```dart
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';

Future<void> main() async {
  final cli = ManageCicdCli();

  // Run dart analyze (automatically ignores non-fatal warnings)
  await cli.run(['analyze']);

  // Run tests across the monorepo
  await cli.run(['test']);

  // Verify proto source and generated files exist
  await cli.run(['verify-protos']);
}
```

### Issue Triage Pipeline
Execute the AI-driven issue triage system. The CLI intercepts `triage <number>` and translates it to `triage single <number>`.

```dart
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';

Future<void> main() async {
  final cli = ManageCicdCli();

  // Triage a specific issue by number
  await cli.run(['triage', '42']); 

  // Auto-triage all open, untriaged issues
  await cli.run(['triage', 'auto']);

  // Output the current status of the triage pipeline
  await cli.run(['triage', 'status']);
}
```

### Auditing Dependencies
Validate `pubspec.yaml` files against the external workspace package registry using the CLI or programmatically via the utilities.

```dart
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';
import 'package:runtime_ci_tooling/src/cli/utils/audit/package_registry.dart';
import 'package:runtime_ci_tooling/src/cli/utils/audit/pubspec_auditor.dart';
import 'package:runtime_ci_tooling/src/cli/utils/audit/audit_finding.dart';

Future<void> main() async {
  // Via the CLI
  final cli = ManageCicdCli();
  await cli.run(['audit-all', '--fix']);

  // Programmatically via the Audit utility classes
  final registry = PackageRegistry.load('configs/external_workspace_packages.yaml');
  final auditor = PubspecAuditor(registry: registry);

  final findings = auditor.auditPubspec('lib/src/my_package/pubspec.yaml');
  for (final finding in findings) {
    if (finding.severity == AuditSeverity.error) {
      print('Failed: ${finding.dependencyName} (${finding.category.name})');
    }
  }
}
```

### Using Utility Classes
You can leverage the CLI's utility classes to script standalone operations without invoking the full `CommandRunner`.

```dart
import 'package:runtime_ci_tooling/src/cli/utils/logger.dart';
import 'package:runtime_ci_tooling/src/cli/utils/repo_utils.dart';
import 'package:runtime_ci_tooling/src/cli/utils/process_runner.dart';

Future<void> runCustomScript() async {
  final repoRoot = RepoUtils.findRepoRoot();
  
  if (repoRoot == null) {
    Logger.error('Could not determine repository root.');
    return;
  }
  
  Logger.header('Found Repository');
  Logger.success('Root path: $repoRoot');
  
  // Safely execute an external shell command
  final gitStatus = CiProcessRunner.runSync('git status --short', repoRoot, verbose: true);
  Logger.info(gitStatus);
}
```

## 5. Configuration

### Environment Variables
- `GEMINI_API_KEY`: Required for Gemini 3 Pro AI stages (e.g., `explore`, `compose`, `release-notes`, `triage`, `autodoc`).
- `GH_TOKEN` / `GITHUB_TOKEN` / `GITHUB_PAT`: Required for GitHub CLI operations, GitHub Actions APIs, and MCP server configuration.
- `CI_STAGING_DIR`: Optional. Overrides the staging directory for artifacts (defaults to `/tmp/` locally/CI).

### Global CLI Options
These flags are supported on all commands extending `ManageCicdCli`:
- `--dry-run`: Previews the actions, writes no files to disk, and executes no side-effects.
- `--verbose` / `-v`: Emits comprehensive debug logging and prints shell commands before execution.

### Configuration Files
- **`.runtime_ci/config.json`**: The core runtime pipeline configuration. Automatically scaffolded using `manage_cicd init`. Contains labels, thresholds, AI agents, cross-repo config, and `sub_packages`.
- **`.runtime_ci/autodoc.json`**: Configuration used by the `AutodocCommand` to map module source paths to target markdown documentation outputs.
- **`.gemini/settings.json`**: Defines configured Model Context Protocol (MCP) servers (GitHub, Sentry) used by AI pipelines. Generated via `manage_cicd configure-mcp`.
- **`pubspec.yaml`**: The canonical source of truth for the local version constraint, used by `DetermineVersionCommand` and bumped by `CreateReleaseCommand`.

## 6. Related Modules
- **Triage Pipeline (`lib/src/triage/`)**: Executed via the `TriageCommand` subcommands (`TriageSingleCommand`, `TriageAutoCommand`, `TriagePreReleaseCommand`, `TriagePostReleaseCommand`). Orchestrates GitHub issues into actionable PRs using agents.
- **Audit Module (`lib/src/cli/utils/audit/`)**: Powers the `AuditCommand` and `AuditAllCommand` via the `PubspecAuditor` and `PackageRegistry` to enforce consistency for git-sourced dependencies across monorepo architectures.
