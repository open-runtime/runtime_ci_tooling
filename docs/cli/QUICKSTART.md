# CI/CD CLI Quickstart

## 1. Overview
The **CI/CD CLI** module provides a cross-platform command-line interface and programmatic API for managing the AI-powered release pipeline, running tests, auto-generating documentation, and executing issue triage. It includes a complete suite of tools to automate repository maintenance, changelog generation, and GitHub releases.

## 2. Import
To use the CLI components programmatically in your Dart scripts, import the core CLI runner and its commands or utilities:

```dart
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';
import 'package:runtime_ci_tooling/src/cli/options/global_options.dart';
import 'package:runtime_ci_tooling/src/cli/utils/logger.dart';
import 'package:runtime_ci_tooling/src/cli/utils/repo_utils.dart';
import 'package:runtime_ci_tooling/src/cli/utils/process_runner.dart';
```

## 3. Setup
The primary entry point for executing CLI commands is the `ManageCicdCli` class, which extends `CommandRunner<void>`.

```dart
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';

Future<void> main(List<String> args) async {
  final runner = ManageCicdCli();
  
  try {
    await runner.run(args);
  } on UsageException catch (e) {
    print(e.message);
    print(e.usage);
  }
}
```

## 4. Common Operations

### Parsing Global Options
You can parse global flags like `--dry-run` and `--verbose` from command-line arguments using the `ArgParser` and the generated options parsers.

```dart
import 'package:args/args.dart';
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';
import 'package:runtime_ci_tooling/src/cli/options/global_options.dart';

void checkOptions(List<String> args) {
  final parser = ArgParser();
  GlobalOptionsArgParser.populateParser(parser);
  final results = parser.parse(args);

  final GlobalOptions global = ManageCicdCli.parseGlobalOptions(results);
  
  if (global.verbose) {
    print('Verbose mode is enabled');
  }
  
  if (global.dryRun) {
    print('Dry run mode - no changes will be made');
  }
}
```

### Finding the Repository Root
Many commands depend on locating the repository root where `pubspec.yaml` and `.runtime_ci/config.json` reside.

```dart
import 'package:runtime_ci_tooling/src/cli/utils/repo_utils.dart';
import 'package:runtime_ci_tooling/src/cli/utils/logger.dart';

void checkRepo() {
  final String? repoRoot = RepoUtils.findRepoRoot();
  
  if (repoRoot == null) {
    Logger.error('Could not find the repository root.');
    return;
  }
  
  Logger.success('Found repository root at: $repoRoot');
}
```

### Running External Processes
The `CiProcessRunner` provides utility methods to safely execute shell commands.

```dart
import 'package:runtime_ci_tooling/src/cli/utils/process_runner.dart';
import 'package:runtime_ci_tooling/src/cli/utils/logger.dart';

void runBuild() {
  // Check if a command exists
  if (!CiProcessRunner.commandExists('gh')) {
    Logger.warn('GitHub CLI is not installed.');
  }

  // Run a command synchronously and get trimmed output
  final String output = CiProcessRunner.runSync(
    'dart --version', 
    '/path/to/repo', 
    verbose: true,
  );
  
  // Execute a command with fatal exit on failure
  CiProcessRunner.exec(
    'git', 
    ['status'], 
    cwd: '/path/to/repo', 
    fatal: true, 
    verbose: true,
  );
}
```

### Executing Specific Commands Programmatically
You can invoke specific commands by passing arguments to the runner, such as generating automated documentation, managing releases, or triaging issues.

```dart
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';

Future<void> runPipelineSteps() async {
  final runner = ManageCicdCli();
  
  // 1. Initial Setup and Validation
  await runner.run(['init']);
  await runner.run(['setup']);
  await runner.run(['validate']);
  
  // 2. Code Quality
  await runner.run(['analyze']);
  await runner.run(['test']);
  
  // 3. Documentation
  await runner.run(['autodoc', '--force']);
  
  // 4. Issue Triage
  await runner.run(['triage', 'auto']);
  
  // 5. Release Pipeline
  await runner.run(['version']); // Show next SemVer version
  await runner.run(['explore']); // AI: Explore changes
  await runner.run(['compose']); // AI: Compose changelog
  await runner.run(['release-notes']); // AI: Author release notes
  await runner.run(['create-release', '--version', '1.0.0']);
}
```

## 5. Using Parsed Command Options Programmatically
To invoke commands securely or instantiate parsed options inside your script, use the generated builder extensions from the `options/` directory.

```dart
import 'package:args/args.dart';
import 'package:runtime_ci_tooling/src/cli/options/update_all_options.dart';

void parseUpdateOptions(List<String> args) {
  final parser = ArgParser();
  UpdateAllOptionsArgParser.populateParser(parser);
  final results = parser.parse(args);
  
  final options = UpdateAllOptions.fromArgResults(results);
  print('Concurrency: ${options.concurrency}');
  print('Force: ${options.force}');
  print('Backup: ${options.backup}');
}
```

## 6. Configuration
The CLI relies on specific files and environment variables for its operation:

### Environment Variables
- `GEMINI_API_KEY`: Required for AI-powered stages (`explore`, `compose`, `release-notes`, `triage`, `autodoc`, `determine-version`).
- `GH_TOKEN` or `GITHUB_TOKEN`: Required for GitHub operations like issue triage, fetching repos, and creating releases.

### Key Configuration Files
- `.runtime_ci/config.json`: The core configuration file containing settings for repository details, CI features, Sentry, and cross-repo triage. Generated via `init` command.
- `.runtime_ci/autodoc.json`: Configuration for the `AutodocCommand` to map modules and prompt templates.
- `.gemini/settings.json`: Configuration for MCP servers used by the Gemini tools. Created via `configure-mcp` command.
- `pubspec.yaml`: Read to determine package name and current version.

### Key Directories
- `.runtime_ci/runs/`: Output directory for local CI/CD audit trails and intermediate JSON data (like `commit_analysis.json`).
- `.runtime_ci/release_notes/`: Directory where generated release notes, migration guides, and `linked_issues.json` are assembled.

## 7. Related Modules
- **Triage**: Interacts closely with the `triage` module (`package:runtime_ci_tooling/src/triage/...`) for executing `TriageCommand` subcommands, utilizing AI agents to investigate and act on issues across repositories.
