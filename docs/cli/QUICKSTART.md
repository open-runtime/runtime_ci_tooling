# CI/CD CLI Quickstart

## 1. Overview
The CI/CD Automation CLI (`ManageCicdCli`) provides cross-platform setup, validation, and execution of AI-powered release pipelines. It includes integrated utilities for release generation (Explorer, Composer, Release Notes Author), automated issue triage, documentation generation via Gemini, project scaffolding, and automated updates.

## 2. Import
```dart
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';
import 'package:runtime_ci_tooling/src/cli/options/global_options.dart';
```

## 3. Setup
You can invoke the CLI commands either directly via the shell or programmatically in Dart. To set up the command runner in a Dart script:

```dart
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';

void main(List<String> args) async {
  final runner = ManageCicdCli();
  
  // The runner will automatically parse global flags (like --dry-run or --verbose)
  // before dispatching to the respective command.
  await runner.run(args);
}
```

## 4. Common Operations

### Initialize a New Repository
Run initialization to scaffold `.runtime_ci/config.json`, `.runtime_ci/autodoc.json`, create a `CHANGELOG.md` and set up pre-commit hooks.

```dart
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';

Future<void> initProject() async {
  final cli = ManageCicdCli();
  await cli.run(['init']);
}
```

### Check Configuration Status
Verify that all prerequisites (Node.js, `gh`, `jq`, `gemini`) and configuration files are present.

```dart
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';

Future<void> checkStatus() async {
  final cli = ManageCicdCli();
  await cli.run(['status', '--verbose']);
}
```

### Auto-Triage Open Issues
Run the AI-powered issue triage pipeline to investigate, verify, and link issues automatically.

```dart
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';

Future<void> autoTriage() async {
  final cli = ManageCicdCli();
  await cli.run(['triage', 'auto', '--force']);
}
```

### Update Project Templates & Workflows
Update `.github/workflows`, `.gemini/` tools, and merge configurations from `runtime_ci_tooling` templates.

```dart
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';

Future<void> updateProject() async {
  final cli = ManageCicdCli();
  // Optional parameters: --force, --workflows, --templates, --config, --autodoc, --backup
  await cli.run(['update', '--backup']);
}
```

### Discover Consumers & Sync Releases
Discover downstream consumer repositories and sync release metadata to the `.consumers` directory.

```dart
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';

Future<void> syncConsumers() async {
  final cli = ManageCicdCli();
  await cli.run(['consumers', '--org', 'open-runtime', '--package', 'runtime_ci_tooling']);
}
```

### Generate Documentation (Autodoc)
Generate or update module documentation using the Gemini model and `autodoc.json` configuration.

```dart
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';

Future<void> generateDocs() async {
  final cli = ManageCicdCli();
  // Use --dry-run to simulate changes, or --force to overwrite regardless of file hashes
  await cli.run(['autodoc', '--force']);
}
```

### Execute the Full Release Pipeline
Run the entire AI release workflow (Explore, Compose, Release Notes) locally.

```dart
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';

Future<void> createRelease() async {
  final cli = ManageCicdCli();
  // Will determine the version and use Gemini to generate CHANGELOG and release notes
  await cli.run(['release']);
}
```

## 5. Configuration
The CLI relies on several core configuration files and environment variables:

- **`.runtime_ci/config.json`**: Primary repository and CI behavior configuration.
- **`.runtime_ci/autodoc.json`**: Instructions and templates for the `autodoc` command.
- **`.gemini/settings.json`**: Defines local context rules and MCP server bindings (like `github` and `sentry`).
- **Environment Variables**:
  - `GEMINI_API_KEY`: Required for AI agent tools (`explore`, `compose`, `release-notes`, `triage`).
  - `GH_TOKEN` or `GITHUB_TOKEN`: Required for interacting with the GitHub API.

## 6. Related Modules
- `triage`: Contains the specific sub-phases (`investigate`, `plan`, `act`, `verify`, `link`) executed by `TriageCommand`.
- `utils`: Exposes internal core functionality such as `CiProcessRunner`, `Logger`, `VersionDetection`, and `TemplateResolver`.

## 7. Other Utility Commands

The CLI also includes a suite of utility commands for CI pipelines and maintenance:

- **`analyze`**: Runs `dart analyze` with configurations to fail only on errors.
- **`test`**: Runs `dart test` excluding specific integration and GCP tags.
- **`verify-protos`**: Verifies that generated Dart files exist for all `.proto` files.
- **`archive-run`**: Archives the current CI/CD run's audit trail to `.runtime_ci/audit/`.
- **`merge-audit-trails`**: Merges distributed CI audit trail artifacts into a single run context.
- **`determine-version`**: Analyzes commit history to compute the next SemVer bump and outputs variables for GitHub Actions.
- **`update-all`**: Discovers all `runtime_ci_tooling` consumers under a root directory and batch updates them.
