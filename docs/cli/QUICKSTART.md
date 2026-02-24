# CI/CD CLI Quickstart

## 1. Overview
The **CI/CD CLI** module provides a cross-platform command-line runner and programmatic utilities for managing AI-powered release pipelines, monorepo dependency auditing, and issue triage. It automates tasks like determining semantic version bumps (`DetermineVersionCommand`), composing changelogs (`ComposeCommand`), verifying workspace integrity (`PubspecAuditor`), and rendering CI/CD GitHub action workflows (`WorkflowGenerator`).

## 2. Import
Import the core CLI runner or specific programmatic utilities based on your needs:

```dart
// Core CLI Runner
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';

// Standalone Utilities
import 'package:runtime_ci_tooling/src/cli/utils/repo_utils.dart';
import 'package:runtime_ci_tooling/src/cli/utils/workflow_generator.dart';
import 'package:runtime_ci_tooling/src/cli/utils/audit/package_registry.dart';
import 'package:runtime_ci_tooling/src/cli/utils/audit/pubspec_auditor.dart';
import 'package:runtime_ci_tooling/src/cli/utils/audit/audit_finding.dart';
```

## 3. Setup
To execute CLI commands programmatically, instantiate the `ManageCicdCli` class. This runner comes pre-configured with all `runtime_ci_tooling` subcommands (e.g., `init`, `explore`, `triage`, `audit`).

```dart
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';

void main() async {
  final cli = ManageCicdCli();
  
  // Example: Run 'status' with verbose logging
  await cli.run(['--verbose', 'status']);
}
```

## 4. Common Operations

### Available Commands
The `ManageCicdCli` supports a wide array of subcommands for the CI/CD lifecycle:
- **Infrastructure Management**: `setup`, `validate`, `status`, `configure-mcp`
- **Release Pipeline (Gemini-powered)**: `explore`, `compose`, `release-notes`, `documentation`, `release`
- **CI/CD Actions**: `determine-version`, `create-release`, `archive-run`, `merge-audit-trails`
- **Code Quality**: `test`, `analyze`, `verify-protos`
- **Issue Triage**: `triage` (with subcommands `single`, `auto`, `status`, `pre-release`, `post-release`, `resume`)
- **Monorepo & Templates**: `update`, `update-all`, `audit`, `audit-all`, `autodoc`, `init`, `consumers`

### Bootstrapping a Repository
You can initialize a repository by generating required CI configurations (`.runtime_ci/config.json`, `.runtime_ci/autodoc.json`, and `.git/hooks/pre-commit`).

```dart
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';

Future<void> initRepository() async {
  final cli = ManageCicdCli();
  // Analyzes the current workspace and scaffolds required CI/CD files
  await cli.run(['init']);
}
```

### Auditing Workspace Dependencies
To validate that all `git` dependencies in a `pubspec.yaml` match the central workspace registry (checking URLs, tags, and version constraints):

```dart
import 'package:runtime_ci_tooling/src/cli/utils/audit/package_registry.dart';
import 'package:runtime_ci_tooling/src/cli/utils/audit/pubspec_auditor.dart';
import 'package:runtime_ci_tooling/src/cli/utils/audit/audit_finding.dart';

void auditDependencies() {
  final registry = PackageRegistry.load('configs/external_workspace_packages.yaml');
  final auditor = PubspecAuditor(registry: registry);
  
  final findings = auditor.auditPubspec('pubspec.yaml');
  
  for (final finding in findings) {
    if (finding.severity == AuditSeverity.error) {
      print('Error in ${finding.dependencyName}: ${finding.message}');
    }
  }
}
```

### Rendering GitHub Action Workflows
You can programmatically generate a GitHub Actions workflow YAML based on your `.runtime_ci/config.json` specifications:

```dart
import 'package:runtime_ci_tooling/src/cli/utils/repo_utils.dart';
import 'package:runtime_ci_tooling/src/cli/utils/workflow_generator.dart';

void generateWorkflow() {
  final repoRoot = RepoUtils.findRepoRoot();
  if (repoRoot == null) return;

  final ciConfig = WorkflowGenerator.loadCiConfig(repoRoot);
  if (ciConfig != null) {
    final generator = WorkflowGenerator(
      ciConfig: ciConfig, 
      toolingVersion: '1.0.0'
    );
    final yamlOutput = generator.render();
    print(yamlOutput);
  }
}
```

## 5. Configuration
The CLI relies heavily on the following configuration files and environment variables:

**Configuration Files:**
* `.runtime_ci/config.json`: The core settings file (generated via `manage_cicd init`) specifying sub-packages, tool settings, thresholds, and GitHub platforms.
* `.runtime_ci/autodoc.json`: Configuration mapping source directories to documentation outputs used by the `AutodocCommand`.
* `configs/external_workspace_packages.yaml`: The central source of truth for repository references used by `AuditAllCommand` and `AuditCommand`.

**Environment Variables:**
* `GEMINI_API_KEY`: Required by exploration, triage, and changelog generation tools (`ExploreCommand`, `ComposeCommand`).
* `GH_TOKEN` or `GITHUB_TOKEN`: Required to interact with GitHub APIs, configure MCP servers, and push release branches.
* `CI_STAGING_DIR`: Optional. Used to override where CI artifacts are staged (defaults to `/tmp/` or system temp).

## 6. Related Modules
* **Triage (`lib/src/triage/`)**: Detailed AI triage logic invoked by the `TriageCommand` subcommands (`TriageSingleCommand`, `TriageAutoCommand`).
* **Prompts (`lib/src/prompts/`)**: Contains the Gemini 3 Pro prompt definitions executed by tools like `ReleaseNotesCommand` and `AutodocCommand`.
