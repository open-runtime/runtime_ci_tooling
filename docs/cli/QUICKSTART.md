# CI/CD CLI Quickstart

## 1. Overview
The CI/CD CLI module (`manage_cicd`) provides cross-platform automation for managing AI-powered release pipelines, code quality checks, and issue triage. Built around the `ManageCicdCli` class, it offers utilities for generating release notes, auditing dependencies, running tests with zone-aware capture, and orchestrating Gemini-powered tools.

## 2. Command-Line Usage

The primary way to interact with the CI/CD CLI is through the terminal. It provides various commands for the full CI/CD lifecycle.

```sh
# Initialize the repository with CI/CD configurations
dart run runtime_ci_tooling:manage_cicd init

# Set up CI/CD prerequisites (Node.js, Gemini CLI, gh, jq, etc.)
dart run runtime_ci_tooling:manage_cicd setup

# Check current CI/CD configuration status
dart run runtime_ci_tooling:manage_cicd status

# Run dart test with full output capture and job summary
dart run runtime_ci_tooling:manage_cicd test

# Run dart analyze on root and all sub-packages
dart run runtime_ci_tooling:manage_cicd analyze

# Run the full local release pipeline (version, explore, compose)
dart run runtime_ci_tooling:manage_cicd release

# Run issue triage on all open untriaged issues
dart run runtime_ci_tooling:manage_cicd triage auto
```

## 3. Programmatic Setup

While typically invoked via the terminal, you can set up and run the CLI programmatically by instantiating `ManageCicdCli`.

```dart
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';
import 'package:args/command_runner.dart';

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

## 4. Common Programmatic Operations

### Checking CI/CD Status
Runs the status command programmatically to verify configurations, MCP servers, and required tools.
```dart
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';

Future<void> checkStatus() async {
  final cli = ManageCicdCli();
  // Equivalent to: dart run runtime_ci_tooling:manage_cicd status --verbose
  await cli.run(['status', '--verbose']);
}
```

### Running Tests with Output Capture
The `TestCommand` provides a programmatic entry point for running tests across a workspace with full output capture.
```dart
import 'package:runtime_ci_tooling/src/cli/commands/test_command.dart';

Future<void> executeTests(String repoRoot) async {
  // Runs `dart test` on the root and all configured sub-packages,
  // generating a rich markdown step summary.
  await TestCommand.runWithRoot(
    repoRoot,
    processTimeout: const Duration(minutes: 45),
  );
}
```

### Parsing Global Options
The CLI uses `build_cli` to parse options. You can use these generated parsers in custom scripts.
```dart
import 'package:args/args.dart';
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';
import 'package:runtime_ci_tooling/src/cli/options/global_options.dart';

void checkGlobalFlags(List<String> args) {
  final parser = ArgParser();
  GlobalOptionsArgParser.populateParser(parser);
  
  final results = parser.parse(args);
  final globalOpts = ManageCicdCli.parseGlobalOptions(results);
  
  if (globalOpts.dryRun) {
    print('Executing in DRY-RUN mode');
  }
  if (globalOpts.verbose) {
    print('Verbose logging enabled');
  }
}
```

### Auditing Dependencies
You can programmatically audit dependencies against the package registry.
```dart
import 'package:runtime_ci_tooling/src/cli/utils/audit/package_registry.dart';
import 'package:runtime_ci_tooling/src/cli/utils/audit/pubspec_auditor.dart';

void runAudit(String registryPath, String pubspecPath) {
  final registry = PackageRegistry.load(registryPath);
  final auditor = PubspecAuditor(registry: registry);

  final findings = auditor.auditPubspec(pubspecPath);
  for (final finding in findings) {
    print('${finding.severity.name.toUpperCase()}: ${finding.message}');
  }
}
```

## 5. Configuration
The CLI relies heavily on the `.runtime_ci/config.json` configuration file at the repository root. This file is scaffolded using `manage_cicd init`.

**Important Environment Variables:**
- `GEMINI_API_KEY`: Required for AI operations (`explore`, `compose`, `release-notes`, `triage`, `autodoc`, `determine-version`).
- `GH_TOKEN` or `GITHUB_TOKEN`: Required for GitHub CLI integration (`gh`).
- `CI_STAGING_DIR`: Directory for CI artifacts (defaults to `Directory.systemTemp.path`).

## 6. Related Modules
- **Triage Module**: Commands like `TriageAutoCommand` and `TriageSingleCommand` interface with the `lib/src/triage/` engine.
- **Audit Utilities**: The `AuditAllCommand` and `AuditCommand` leverage `PackageRegistry` and `PubspecAuditor` from `lib/src/cli/utils/audit/`.
- **Workflow Generation**: `UpdateCommand` uses `WorkflowGenerator` to dynamically build GitHub Actions CI configurations from `.runtime_ci/config.json`.
