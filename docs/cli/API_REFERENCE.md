# CI/CD CLI API Reference

The `CI/CD CLI` module provides the core commands, utilities, and options for the `manage_cicd` tool. It is designed to be run from the command line but can also be extended or invoked programmatically.

## Core Runner & Commands

### `ManageCicdCli`
The main CLI entry point. Extends `CommandRunner<void>` from the `args` package.

```dart
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';

void main(List<String> args) async {
  final cli = ManageCicdCli();
  await cli.run(args);
}
```

**Methods:**
- `run(Iterable<String> args)`: `Future<void>` - Executes the CLI, intercepting shorthands like `triage 42` and mapping them to `triage single 42`.
- `parseGlobalOptions(ArgResults? results)`: `GlobalOptions` (static) - Extracts global flags like `--dry-run` or `--verbose`.
- `isVerbose(ArgResults? results)`: `bool` (static)
- `isDryRun(ArgResults? results)`: `bool` (static)

### Available Commands

All commands extend `Command<void>` and are automatically registered in `ManageCicdCli`.

- **`AnalyzeCommand`** (`analyze`) - Runs `dart analyze` with `--no-fatal-warnings`.
- **`ArchiveRunCommand`** (`archive-run`) - Archives CI run artifacts to `.runtime_ci/audit/vX.X.X/` using `ArchiveRunOptions` and `VersionOptions`.
- **`AutodocCommand`** (`autodoc`) - Generates documentation using Gemini based on `autodoc.json`.
- **`ComposeCommand`** (`compose`) - Uses Gemini to compose `CHANGELOG.md` updates.
- **`ConfigureMcpCommand`** (`configure-mcp`) - Sets up GitHub and Sentry MCP server definitions in `.gemini/settings.json`.
- **`ConsumersCommand`** (`consumers`) - Discovers packages dependent on `runtime_ci_tooling` and syncs release artifacts.
- **`CreateReleaseCommand`** (`create-release`) - Tags, commits, and creates a GitHub release.
- **`DetermineVersionCommand`** (`determine-version`) - Evaluates the next semantic version from git history.
- **`DocumentationCommand`** (`documentation`) - Auto-updates README.md and related docs using Gemini.
- **`ExploreCommand`** (`explore`) - Analyzes commits and PRs to formulate an initial release game plan.
- **`InitCommand`** (`init`) - Scaffolds `.runtime_ci/config.json`, `.gitignore`, and base templates in a consumer repository.
- **`MergeAuditTrailsCommand`** (`merge-audit-trails`) - Merges partial CI audit artifacts from multiple parallel jobs.
- **`ReleaseCommand`** (`release`) - Local pipeline that runs versioning, exploration, and changelog composition sequentially.
- **`ReleaseNotesCommand`** (`release-notes`) - Generates rich narrative release notes (distinct from the changelog) using Gemini.
- **`SetupCommand`** (`setup`) - Installs required dependencies (Node, Gemini CLI, gh, jq).
- **`StatusCommand`** (`status`) - Prints a diagnostic summary of the CI environment.
- **`TestCommand`** (`test`) - Runs `dart test` excluding integration tags.
- **`TriageCommand`** (`triage`) - The parent command for issue triage. Subcommands include `auto`, `single`, `pre-release`, `post-release`, `resume`, and `status`.
- **`UpdateAllCommand`** (`update-all`) - Discovers all packages under a root directory using `runtime_ci_tooling` and runs `update` on them.
- **`UpdateCommand`** (`update`) - Syncs local CI configs and GitHub workflows with the latest templates provided by the tooling.
- **`ValidateCommand`** (`validate`) - Checks JSON, YAML, and template syntax across the configuration.
- **`VerifyProtosCommand`** (`verify-protos`) - Validates that `.proto` files have corresponding `.pb.dart` generated files.
- **`VersionCommand`** (`version`) - Displays the computed next version without side effects.

---

## Options & Arguments

Command line flags and options are parsed using `build_cli`. Each set of options exposes a static `.fromArgResults()` factory.

### `GlobalOptions`
Parsed from global arguments before the command name.
```dart
final global = ManageCicdCli.parseGlobalOptions(globalResults);
if (global.dryRun) {
  Logger.info('[DRY-RUN] Mode enabled');
}
```
- `dryRun` (`bool`)
- `verbose` (`bool`)

### Specific Command Options
- **`AutodocOptions`**: `init` (bool), `force` (bool), `module` (String?)
- **`ConsumersOptions`**: Controls orgs, package name, limits, and concurrency for repository scanning.
- **`CreateReleaseOptions`**: `artifactsDir` (String?), `repo` (String?)
- **`DetermineVersionOptions`**: `outputGithubActions` (bool)
- **`MergeAuditTrailsOptions`**: `incomingDir` (String?), `outputDir` (String?)
- **`PostReleaseTriageOptions`**: `releaseTag` (String?), `releaseUrl` (String?), `manifest` (String?)
- **`TriageOptions`**: `force` (bool) - Used to bypass lock files.
- **`UpdateAllOptions`**: `scanRoot` (String?), `concurrency` (int), `force` (bool), `workflows` (bool), `templates` (bool), `config` (bool), `autodoc` (bool), `backup` (bool)
- **`UpdateOptions`**: Matches flags in `UpdateAllOptions` but scoped to a single repository.
- **`VersionOptions`**: `prevTag` (String?), `version` (String?)

---

## Utilities

### Shell & Execution
- **`CiProcessRunner`**
  ```dart
  import 'package:runtime_ci_tooling/src/cli/utils/process_runner.dart';
  
  if (CiProcessRunner.commandExists('gh')) {
    final stdout = CiProcessRunner.runSync('gh auth status', repoRoot, verbose: true);
    CiProcessRunner.exec('git', ['add', '.'], cwd: repoRoot, fatal: true);
  }
  ```

### File System
- **`FileUtils`**
  Provides basic directory copying and file reading.
  ```dart
  import 'package:runtime_ci_tooling/src/cli/utils/file_utils.dart';
  
  FileUtils.copyDirRecursive(sourceDir, destDir);
  final count = FileUtils.countFiles(dir);
  final content = FileUtils.readFileOr('path/to/file.txt', 'fallback string');
  ```

### Logging
- **`Logger`**
  Used for styled console output.
  ```dart
  import 'package:runtime_ci_tooling/src/cli/utils/logger.dart';
  
  Logger.header('Starting Process');
  Logger.info('Normal message');
  Logger.warn('Warning message');
  Logger.error('Error message');
  Logger.success('Success message');
  ```

### Template System
- **`TemplateResolver`** - Finds the path to templates installed by the package.
- **`TemplateVersionTracker`** - Manages `.runtime_ci/template_versions.json` to monitor which versions of templates a consumer has installed.
- **`WorkflowGenerator`** - Dynamically renders GitHub Actions YAML using `Mustache` and user-preservable sections (`# --- BEGIN USER: name ---`).

### Gemini Integration
- **`GeminiUtils`**
  ```dart
  import 'package:runtime_ci_tooling/src/cli/utils/gemini_utils.dart';
  
  if (GeminiUtils.geminiAvailable(warnOnly: true)) {
    // extract balanced JSON from raw CLI output
    final jsonString = GeminiUtils.extractJson(rawOutput); 
  }
  ```

### Release & Versioning
- **`VersionDetection`**
  Calculates the next version using either a regex fallback or Gemini AI analysis.
  ```dart
  import 'package:runtime_ci_tooling/src/cli/utils/version_detection.dart';
  
  final prevTag = VersionDetection.detectPrevTag(repoRoot);
  final nextVersion = VersionDetection.detectNextVersion(repoRoot, prevTag);
  ```
- **`ReleaseUtils`**
  Extracts validated GitHub contributors and generates detailed commit messages.

### Project & Paths
- **`RepoUtils.findRepoRoot()`**: `String?` - Automatically discovers the root of the consumer package by ascending directories until `pubspec.yaml` is found.
- **`StepSummary`** - Writes markdown to `$GITHUB_STEP_SUMMARY` for rich CI interface reporting.
