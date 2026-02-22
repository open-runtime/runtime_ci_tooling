# CI/CD CLI API Reference

This document provides a comprehensive API reference for the **CI/CD CLI** module of `runtime_ci_tooling`. It covers the main command runner, all commands, options classes, and utility functions used to power the AI-assisted release and triage pipeline.

---

## 1. CLI Entry Point

### `ManageCicdCli`
The main CLI entry point for CI/CD Automation. It provides commands for managing the full CI/CD lifecycle, delegating to various command classes.

**Properties**
* `String name` - Returns `'manage_cicd'`.
* `String description` - Returns the CLI description.

**Methods**
* `static GlobalOptions parseGlobalOptions(ArgResults? results)` - Parses global options from `ArgResults`.
* `static bool isVerbose(ArgResults? results)` - Returns `true` if verbose mode is enabled.
* `static bool isDryRun(ArgResults? results)` - Returns `true` if dry-run mode is enabled.

**Example**
```dart
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';
import 'package:runtime_ci_tooling/src/cli/options/global_options.dart';

void main(List<String> args) async {
  final cli = ManageCicdCli();
  
  // Parse global options directly if needed
  // final global = ManageCicdCli.parseGlobalOptions(results);
  
  await cli.run(args);
}
```

---

## 2. Options Classes

Options classes use `build_cli` to parse command-line arguments into strongly-typed Dart objects.

### `GlobalOptions`
Global CLI options available to all commands.
* `bool dryRun` - Show what would be done without executing.
* `bool verbose` - Show detailed command output.

```dart
final options = GlobalOptions(
  dryRun: true,
  verbose: true,
);
```

### `ArchiveRunOptions`
* `String? runDir` - Directory containing the CI run to archive.

### `AutodocOptions`
* `bool init` - Scan repo and create initial `autodoc.json`.
* `bool force` - Regenerate all docs regardless of hash.
* `String? module` - Only generate for a specific module.

### `CreateReleaseOptions`
* `String? artifactsDir` - Directory containing downloaded CI artifacts.
* `String? repo` - GitHub repository slug `owner/repo`.

### `DetermineVersionOptions`
* `bool outputGithubActions` - Write version outputs to `$GITHUB_OUTPUT` for GitHub Actions.

### `MergeAuditTrailsOptions`
* `String? incomingDir` - Directory containing incoming audit trail artifacts.
* `String? outputDir` - Output directory for merged audit trails.

### `PostReleaseTriageOptions`
* `String? releaseTag` - Git tag for the release (e.g., `v0.6.0`).
* `String? releaseUrl` - URL of the GitHub release page.
* `String? manifest` - Path to `issue_manifest.json`.

### `TriageOptions`
* `bool force` - Override an existing triage lock.

### `TriageCliOptions`
Combined CLI options for `triage_cli.dart` entry point.
* `bool dryRun`
* `bool verbose`
* `bool auto` - Run in auto mode.
* `bool status` - Show triage status.
* `bool force` - Force re-run.
* `bool preRelease` - Pre-release mode.
* `bool postRelease` - Post-release mode.
* `String? resume` - Resume from checkpoint.
* `String? prevTag` - Override previous tag detection.
* `String? version` - Override version.
* `String? releaseTag` - The release tag.
* `String? releaseUrl` - URL to the release page.
* `String? manifest` - Path to manifest file.

### `UpdateAllOptions`
* `String? scanRoot` - Root directory to scan for packages (default: cwd).
* `int concurrency` - Max concurrent update processes.
* `bool force` - Overwrite all files regardless of local customizations.
* `bool workflows` - Only update GitHub workflow files.
* `bool templates` - Only update template files.
* `bool config` - Only merge new keys into `.runtime_ci/config.json`.
* `bool autodoc` - Re-scan `lib/src/` and update `autodoc.json`.
* `bool backup` - Write a `.bak` backup before overwriting files.

### `UpdateOptions`
Similar to `UpdateAllOptions` but without `scanRoot` and `concurrency`.
* `bool get updateAll` - Returns `true` if no specific filter flags are set (updates everything).

### `VersionOptions`
* `String? prevTag` - Override previous tag detection.
* `String? version` - Override version (skip auto-detection).

---

## 3. Commands

Each command extends `args` `Command<void>`. Below are the provided commands:

*   **`AnalyzeCommand`**: Run `dart analyze` (fail on errors only).
*   **`ArchiveRunCommand`**: Archive `.runtime_ci/runs/` to `.runtime_ci/audit/vX.X.X/` for permanent storage.
*   **`AutodocCommand`**: Generate/update module docs (`--init`, `--force`, `--module`, `--dry-run`).
*   **`ComposeCommand`**: Run Stage 2 Changelog Composer (Gemini Pro).
*   **`ConfigureMcpCommand`**: Set up MCP servers (GitHub, Sentry).
*   **`ConsumersCommand`**: Discover `runtime_ci_tooling` consumers and sync latest release data.
    *   *Static Methods*: 
        *   `computeNextDiscoveryIndexFromNames`, `buildDiscoverySnapshotName`, `resolveVersionFolderName`, `snapshotIdentityFromPath`, `isSnapshotSourceCompatible`, `isReleaseSummaryReusable`, `buildReleaseOutputPath`, `selectTagFromReleaseList`.
*   **`CreateReleaseCommand`**: Create git tag, GitHub Release, commit all changes.
*   **`DetermineVersionCommand`**: Determine SemVer bump via Gemini + regex (CI: `--output-github-actions`).
*   **`DocumentationCommand`**: Run documentation update via Gemini 3 Pro Preview.
*   **`ExploreCommand`**: Run Stage 1 Explorer Agent (Gemini 3 Pro Preview).
*   **`InitCommand`**: Scan repo and generate `.runtime_ci/config.json` + `autodoc.json` + scaffold workflows.
*   **`MergeAuditTrailsCommand`**: Merge CI/CD audit artifacts from multiple jobs (CI use).
*   **`ReleaseCommand`**: Run the full local release pipeline.
*   **`ReleaseNotesCommand`**: Run Stage 3 Release Notes Author (Gemini 3 Pro Preview).
*   **`SetupCommand`**: Install all prerequisites (Node.js, Gemini CLI, gh, jq, tree).
*   **`StatusCommand`**: Show current CI/CD configuration status.
*   **`TestCommand`**: Run `dart test`.
*   **`TriageAutoCommand`**: Auto-triage all untriaged open issues.
*   **`TriageCommand`**: Issue triage pipeline with AI-powered investigation.
*   **`TriagePostReleaseCommand`**: Close loop after release (requires `--version` and `--release-tag`).
*   **`TriagePreReleaseCommand`**: Scan issues for upcoming release (requires `--prev-tag` and `--version`).
*   **`TriageResumeCommand`**: Resume a previously interrupted triage run.
*   **`TriageSingleCommand`**: Triage a single issue by number.
    *   *Static Methods*: `runSingle(int issueNumber, ArgResults? globalResults)`.
*   **`TriageStatusCommand`**: Show triage pipeline status.
*   **`UpdateAllCommand`**: Discover and update all `runtime_ci_tooling` packages under a root directory.
*   **`UpdateCommand`**: Update templates, configs, and workflows from `runtime_ci_tooling`.
*   **`ValidateCommand`**: Validate all configuration files.
*   **`VerifyProtosCommand`**: Verify proto source and generated files exist.
*   **`VersionCommand`**: Show the next SemVer version (no side effects).

---

## 4. Utilities

### `CiProcessRunner`
Utilities for running external processes.
* `static bool commandExists(String command)`
* `static String runSync(String command, String workingDirectory, {bool verbose = false})`
* `static void exec(String executable, List<String> args, {String? cwd, bool fatal = false, bool verbose = false})`

### `FileUtils`
File system utilities for CI/CD operations.
* `static void copyDirRecursive(Directory src, Directory dst)`
* `static int countFiles(Directory dir)`
* `static String readFileOr(String path, [String fallback = '(not available)'])`

### `GeminiUtils`
Utilities for Gemini CLI integration.
* `static bool geminiAvailable({bool warnOnly = false})`
* `static void requireGeminiCli()`
* `static void requireApiKey()`
* `static String extractJson(String rawOutput)`

### `HookInstaller`
Installs and manages git pre-commit hooks for Dart repos.
* `static bool install(String repoRoot, {int lineLength = 120, bool dryRun = false})`

### `Logger`
ANSI-styled console logging for CI/CD commands.
* `static void header(String msg)`
* `static void info(String msg)`
* `static void success(String msg)`
* `static void warn(String msg)`
* `static void error(String msg)`

### `PromptResolver`
Resolves paths to prompt scripts within the `runtime_ci_tooling` package.
* `static String promptScript(String scriptName)`
* `static String resolveToolingPackageRoot()`

### `ReleaseUtils`
Utilities for release management.
* `static String buildReleaseCommitMessage({required String repoRoot, required String version, required String prevTag, required Directory releaseDir, bool verbose = false})`
* `static List<Map<String, String>> gatherVerifiedContributors(String repoRoot, String prevTag)`
* `static String buildFallbackReleaseNotes(String repoRoot, String version, String prevTag)`
* `static void addChangelogReferenceLinks(String repoRoot, String content)`

### `RepoUtils`
* `static String? findRepoRoot()` - Find the repository root by locating `pubspec.yaml`.

### `StepSummary`
Step summary utilities for GitHub Actions.
* `static void write(String markdown)`
* `static String artifactLink([String label = 'View all artifacts'])`
* `static String compareLink(String prevTag, String newTag, [String? label])`
* `static String ghLink(String label, String path)`
* `static String releaseLink(String tag)`
* `static String collapsible(String title, String content, {bool open = false})`

### `TemplateVersionTracker` & `TemplateResolver`
Utilities to read manifests, locate template files, track their installed versions via hashing, and safely update consumer files.

### `WorkflowGenerator`
Renders CI workflow YAML from a Mustache skeleton template and `config.json`.
* `static Map<String, dynamic>? loadCiConfig(String repoRoot)`
* `String render({String? existingContent})`
* `static List<String> validate(Map<String, dynamic> ciConfig)`
* `void logConfig()`

---

## 5. Top-Level Functions

Several functions are exported at the top-level to aid CLI workflows:

* `void main(List<String> args)` - Main entrypoint for the CLI module.
* `bool acquireTriageLock(bool force)` - Acquire a file-based lock. Returns `true` if acquired, `false` if another run is active.
* `void releaseTriageLock()` - Release the file-based lock.
* `String createTriageRunDir(String repoRoot)` - Create a unique run directory for this triage session.
* `void saveCheckpoint(String runDir, GamePlan plan, String lastPhase)` - Save a checkpoint so the run can be resumed later.
* `Map<int, List<InvestigationResult>> loadCachedResults(String runDir, GamePlan plan)` - Load cached investigation results.
* `List<TriageDecision> loadCachedDecisions(String runDir)` - Load cached triage decisions.
* `String? findLatestManifest(String repoRoot)` - Search recent triage runs for the latest `issue_manifest.json`.
* `bool scaffoldAutodocJson(String repoRoot, {bool overwrite = false})` - Scaffold `.runtime_ci/autodoc.json`.
* `String computeFileHash(String filePath)` - Compute SHA256 hash of a file's contents.
