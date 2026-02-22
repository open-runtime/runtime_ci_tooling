# CI/CD CLI API Reference

This document provides a comprehensive API reference for the CI/CD CLI module, covering commands, options, utilities, and top-level functions used to manage the AI-powered release pipeline.

## 1. Classes

### CLI Application

#### `ManageCicdCli`
CLI entry point for CI/CD Automation. Provides commands for managing the full CI/CD lifecycle.

**Import:**
```dart
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';
```

**Methods:**
*   `ManageCicdCli()` -- Constructor.
*   `static GlobalOptions parseGlobalOptions(ArgResults? results)` -- Parse global options from ArgResults.
*   `static bool isVerbose(ArgResults? results)` -- Returns true if verbose mode is enabled.
*   `static bool isDryRun(ArgResults? results)` -- Returns true if dry-run mode is enabled.

**Example:**
```dart
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';

Future<void> main(List<String> args) async {
  final runner = ManageCicdCli();
  await runner.run(args);
}
```

### Commands

All commands inherit from `Command<void>` and are used via the `ManageCicdCli` runner.

**Example of adding a command:**
```dart
import 'package:runtime_ci_tooling/src/cli/commands/analyze_command.dart';

final command = AnalyzeCommand();
print(command.name); // 'analyze'
```

*   **AnalyzeCommand** -- Run `dart analyze` (fail on errors only).
    *   **Fields:** `String name`, `String description`
    *   **Methods:** `Future<void> run()`

*   **ArchiveRunCommand** -- Archive a CI/CD run to `.runtime_ci/audit/vX.X.X/` for permanent storage.
    *   **Fields:** `String name`, `String description`
    *   **Methods:** `Future<void> run()`

*   **AutodocCommand** -- Generate/update documentation for proto modules using Gemini Pro.
    *   **Fields:** `String name`, `String description`
    *   **Methods:** `Future<void> run()`

*   **ComposeCommand** -- Run Stage 2 Changelog Composer (Gemini Pro).
    *   **Fields:** `String name`, `String description`
    *   **Methods:** `Future<void> run()`

*   **ConfigureMcpCommand** -- Set up MCP servers (GitHub, Sentry).
    *   **Fields:** `String name`, `String description`
    *   **Methods:** `Future<void> run()`

*   **ConsumersCommand** -- Discover runtime_ci_tooling consumers and sync latest release data.
    *   **Fields:** `String name`, `String description`
    *   **Methods:**
        *   `Future<void> run()`
        *   `static int computeNextDiscoveryIndexFromNames(Iterable<String> fileNames)`
        *   `static String buildDiscoverySnapshotName({required int index, required DateTime localTime})`
        *   `static String resolveVersionFolderName(String tagName)`
        *   `static String snapshotIdentityFromPath(String path)`
        *   `static bool isSnapshotSourceCompatible({required String? sourceSnapshotPath, required String? sourceSnapshotIdentity, required String expectedSnapshotPath})`
        *   `static bool isReleaseSummaryReusable({required String status, required String outputPath, required String? tag, required String? exactTag})`
        *   `static String buildReleaseOutputPath({required String outputDir, required String repoName, required String tagName})`
        *   `static String? selectTagFromReleaseList({required List<Map<String, dynamic>> releases, required bool includePrerelease, RegExp? tagPattern})`

*   **CreateReleaseCommand** -- Create git tag, GitHub Release, commit all changes.
    *   **Fields:** `String name`, `String description`
    *   **Methods:** `Future<void> run()`

*   **DetermineVersionCommand** -- Determine SemVer bump via Gemini + regex (CI: `--output-github-actions`).
    *   **Fields:** `String name`, `String description`
    *   **Methods:** `Future<void> run()`

*   **DocumentationCommand** -- Run documentation update via Gemini 3 Pro Preview.
    *   **Fields:** `String name`, `String description`
    *   **Methods:** `Future<void> run()`

*   **ExploreCommand** -- Run Stage 1 Explorer Agent (Gemini 3 Pro Preview).
    *   **Fields:** `String name`, `String description`
    *   **Methods:** `Future<void> run()`

*   **InitCommand** -- Scan repo and generate `.runtime_ci/config.json` + `autodoc.json` + scaffold workflows.
    *   **Fields:** `String name`, `String description`
    *   **Methods:** `Future<void> run()`

*   **MergeAuditTrailsCommand** -- Merge CI/CD audit artifacts from multiple jobs (CI use).
    *   **Fields:** `String name`, `String description`
    *   **Methods:** `Future<void> run()`

*   **ReleaseCommand** -- Run the full local release pipeline.
    *   **Fields:** `String name`, `String description`
    *   **Methods:** `Future<void> run()`

*   **ReleaseNotesCommand** -- Run Stage 3 Release Notes Author (Gemini 3 Pro Preview).
    *   **Fields:** `String name`, `String description`
    *   **Methods:** `Future<void> run()`

*   **SetupCommand** -- Install all prerequisites (Node.js, Gemini CLI, gh, jq, tree).
    *   **Fields:** `String name`, `String description`
    *   **Methods:** `Future<void> run()`

*   **StatusCommand** -- Show current CI/CD configuration status.
    *   **Fields:** `String name`, `String description`
    *   **Methods:** `Future<void> run()`

*   **TestCommand** -- Run dart test.
    *   **Fields:** `String name`, `String description`
    *   **Methods:** `Future<void> run()`

*   **TriageAutoCommand** -- Auto-triage all untriaged open issues.
    *   **Fields:** `String name`, `String description`
    *   **Methods:** `Future<void> run()`

*   **TriageCommand** -- Issue triage pipeline with AI-powered investigation.
    *   **Fields:** `String name`, `String description`
    *   **Methods:** `Future<void> run()`

*   **TriagePostReleaseCommand** -- Close loop after release (requires `--version` and `--release-tag`).
    *   **Fields:** `String name`, `String description`
    *   **Methods:** `Future<void> run()`

*   **TriagePreReleaseCommand** -- Scan issues for upcoming release (requires `--prev-tag` and `--version`).
    *   **Fields:** `String name`, `String description`
    *   **Methods:** `Future<void> run()`

*   **TriageResumeCommand** -- Resume a previously interrupted triage run.
    *   **Fields:** `String name`, `String description`, `String invocation`
    *   **Methods:** `Future<void> run()`

*   **TriageSingleCommand** -- Triage a single issue by number.
    *   **Fields:** `String name`, `String description`, `String invocation`
    *   **Methods:**
        *   `Future<void> run()`
        *   `static Future<void> runSingle(int issueNumber, ArgResults? globalResults)`

*   **TriageStatusCommand** -- Show triage pipeline status.
    *   **Fields:** `String name`, `String description`
    *   **Methods:** `Future<void> run()`

*   **UpdateCommand** -- Update templates, configs, and workflows from runtime_ci_tooling.
    *   **Fields:** `String name`, `String description`
    *   **Methods:** `Future<void> run()`

*   **ValidateCommand** -- Validate all configuration files.
    *   **Fields:** `String name`, `String description`
    *   **Methods:** `Future<void> run()`

*   **VerifyProtosCommand** -- Verify proto source and generated files exist.
    *   **Fields:** `String name`, `String description`
    *   **Methods:** `Future<void> run()`

*   **VersionCommand** -- Show the next SemVer version (no side effects).
    *   **Fields:** `String name`, `String description`
    *   **Methods:** `Future<void> run()`

### Options

These classes encapsulate command-line arguments using `build_cli`.

**Example:**
```dart
import 'package:runtime_ci_tooling/src/cli/options/global_options.dart';

final options = GlobalOptions(dryRun: true, verbose: false);
print(options.dryRun); // true
```

*   **ArchiveRunOptions** -- CLI options for the `archive-run` command.
    *   **Fields:** `String? runDir`
    *   **Methods:** `factory ArchiveRunOptions.fromArgResults(ArgResults results)`
*   **AutodocOptions** -- CLI options for the `autodoc` command.
    *   **Fields:** `bool init`, `bool force`, `String? module`
    *   **Methods:** `factory AutodocOptions.fromArgResults(ArgResults results)`
*   **CreateReleaseOptions** -- CLI options for the `create-release` command.
    *   **Fields:** `String? artifactsDir`, `String? repo`
    *   **Methods:** `factory CreateReleaseOptions.fromArgResults(ArgResults results)`
*   **DetermineVersionOptions** -- CLI options for the `determine-version` command.
    *   **Fields:** `bool outputGithubActions`
    *   **Methods:** `factory DetermineVersionOptions.fromArgResults(ArgResults results)`
*   **GlobalOptions** -- Global CLI options available to all commands.
    *   **Fields:** `bool dryRun`, `bool verbose`
    *   **Methods:** `factory GlobalOptions.fromArgResults(ArgResults results)`
*   **ManageCicdOptions** -- Combined CLI options for the main entry point.
    *   **Fields:** `bool dryRun`, `bool verbose`, `String? prevTag`, `String? version`, `bool outputGithubActions`, `String? artifactsDir`, `String? repo`, `String? releaseTag`, `String? releaseUrl`, `String? manifest`
*   **MergeAuditTrailsOptions** -- CLI options for the `merge-audit-trails` command.
    *   **Fields:** `String? incomingDir`, `String? outputDir`
    *   **Methods:** `factory MergeAuditTrailsOptions.fromArgResults(ArgResults results)`
*   **PostReleaseTriageOptions** -- CLI options for the `post-release` command.
    *   **Fields:** `String? releaseTag`, `String? releaseUrl`, `String? manifest`
    *   **Methods:** `factory PostReleaseTriageOptions.fromArgResults(ArgResults results)`
*   **TriageCliOptions** -- Combined CLI options for the `triage_cli.dart` entry point.
    *   **Fields:** `bool dryRun`, `bool verbose`, `bool auto`, `bool status`, `bool force`, `bool preRelease`, `bool postRelease`, `String? resume`, `String? prevTag`, `String? version`, `String? releaseTag`, `String? releaseUrl`, `String? manifest`
*   **TriageOptions** -- CLI options shared by triage subcommands that acquire a lock.
    *   **Fields:** `bool force`
    *   **Methods:** `factory TriageOptions.fromArgResults(ArgResults results)`
*   **UpdateOptions** -- CLI options for the `update` command.
    *   **Fields:** `bool force`, `bool templates`, `bool config`, `bool workflows`, `bool autodoc`, `bool backup`
    *   **Methods:** `factory UpdateOptions.fromArgResults(ArgResults results)`
*   **VersionOptions** -- Version-related CLI options shared by commands.
    *   **Fields:** `String? prevTag`, `String? version`
    *   **Methods:** `factory VersionOptions.fromArgResults(ArgResults results)`

### Utilities

*   **FileUtils** -- File system utilities for CI/CD operations.
    *   **Import:** `import 'package:runtime_ci_tooling/src/cli/utils/file_utils.dart';`
    *   **Methods:**
        *   `static void copyDirRecursive(Directory src, Directory dst)`
        *   `static int countFiles(Directory dir)`
        *   `static String readFileOr(String path, [String fallback = '(not available)'])`
    *   **Example:**
        ```dart
        final content = FileUtils.readFileOr('README.md', 'Default content');
        ```

*   **GeminiUtils** -- Utilities for Gemini CLI integration.
    *   **Import:** `import 'package:runtime_ci_tooling/src/cli/utils/gemini_utils.dart';`
    *   **Methods:**
        *   `static bool geminiAvailable({bool warnOnly = false})`
        *   `static void requireGeminiCli()`
        *   `static void requireApiKey()`
        *   `static String extractJson(String rawOutput)`

*   **HookInstaller** -- Installs and manages git pre-commit hooks for Dart repos.
    *   **Methods:**
        *   `static bool install(String repoRoot, {int lineLength = 120, bool dryRun = false})`

*   **Logger** -- ANSI-styled console logging for CI/CD commands.
    *   **Methods:**
        *   `static void header(String msg)`
        *   `static void info(String msg)`
        *   `static void success(String msg)`
        *   `static void warn(String msg)`
        *   `static void error(String msg)`

*   **CiProcessRunner** -- Utilities for running external processes.
    *   **Import:** `import 'package:runtime_ci_tooling/src/cli/utils/process_runner.dart';`
    *   **Methods:**
        *   `static bool commandExists(String command)`
        *   `static String runSync(String command, String workingDirectory, {bool verbose = false})`
        *   `static void exec(String executable, List<String> args, {String? cwd, bool fatal = false, bool verbose = false})`

*   **PromptResolver** -- Resolves paths to prompt scripts within the package.
    *   **Methods:**
        *   `static String promptScript(String scriptName)`
        *   `static String resolveToolingPackageRoot()`

*   **ReleaseUtils** -- Utilities for release management.
    *   **Import:** `import 'package:runtime_ci_tooling/src/cli/utils/release_utils.dart';`
    *   **Methods:**
        *   `static String buildReleaseCommitMessage({required String repoRoot, required String version, required String prevTag, required Directory releaseDir, bool verbose = false})`
        *   `static List<Map<String, String>> gatherVerifiedContributors(String repoRoot, String prevTag)`
        *   `static String buildFallbackReleaseNotes(String repoRoot, String version, String prevTag)`
        *   `static void addChangelogReferenceLinks(String repoRoot, String content)`

*   **RepoUtils** -- Utilities for finding and working with the repository root.
    *   **Methods:**
        *   `static String? findRepoRoot()`

*   **StepSummary** -- Step summary utilities for GitHub Actions.
    *   **Methods:**
        *   `static void write(String markdown)`
        *   `static String artifactLink([String label = 'View all artifacts'])`
        *   `static String compareLink(String prevTag, String newTag, [String? label])`
        *   `static String ghLink(String label, String path)`
        *   `static String releaseLink(String tag)`
        *   `static String collapsible(String title, String content, {bool open = false})`

*   **TemplateEntry** -- Represents one template entry from manifest.json.
    *   **Fields:** `String id`, `String? source`, `String destination`, `String category`, `String description`
    *   **Methods:** `factory TemplateEntry.fromJson(Map<String, dynamic> json)`

*   **TemplateVersionTracker** -- Tracks which template versions a consumer repo has installed.
    *   **Methods:**
        *   `factory TemplateVersionTracker.load(String repoRoot)`
        *   `String? get lastToolingVersion`
        *   `String? getInstalledHash(String templateId)`
        *   `String? getConsumerHash(String templateId)`
        *   `void recordUpdate(String templateId, {required String templateHash, required String consumerFileHash, required String toolingVersion})`
        *   `void save(String repoRoot)`

*   **TemplateResolver** -- Resolves paths within the runtime_ci_tooling package.
    *   **Methods:**
        *   `static String resolvePackageRoot()`
        *   `static String resolveTemplatesDir()`
        *   `static String resolveTemplatePath(String relativePath)`
        *   `static Map<String, dynamic> readManifest()`
        *   `static String resolveToolingVersion()`

*   **ToolInstallers** -- Cross-platform tool installation utilities.
    *   **Methods:**
        *   `static Future<void> installTool(String tool, {bool dryRun = false})`
        *   `static Future<void> installNodeJs()`
        *   `static Future<void> installGeminiCli()`
        *   `static Future<void> installGitHubCli()`
        *   `static Future<void> installJq()`
        *   `static Future<void> installTree()`

*   **VersionDetection** -- Version detection and semantic versioning utilities.
    *   **Import:** `import 'package:runtime_ci_tooling/src/cli/utils/version_detection.dart';`
    *   **Methods:**
        *   `static String detectPrevTag(String repoRoot, {bool verbose = false})`
        *   `static String detectNextVersion(String repoRoot, String prevTag, {bool verbose = false})`
        *   `static int compareVersions(String a, String b)`

*   **WorkflowGenerator** -- Renders CI workflow YAML from a Mustache skeleton template and config.json.
    *   **Import:** `import 'package:runtime_ci_tooling/src/cli/utils/workflow_generator.dart';`
    *   **Fields:** `Map<String, dynamic> ciConfig`, `String toolingVersion`
    *   **Methods:**
        *   `WorkflowGenerator({required this.ciConfig, required this.toolingVersion})`
        *   `static Map<String, dynamic>? loadCiConfig(String repoRoot)`
        *   `String render({String? existingContent})`
        *   `static List<String> validate(Map<String, dynamic> ciConfig)`
        *   `void logConfig()`

## 2. Enums
*(No public enums are present in the provided source code)*

## 3. Extensions

*   **ArchiveRunOptionsArgParser** on **ArchiveRunOptions** -- helper for argument parsers
    *   **Methods:** `static void populateParser(ArgParser parser)`
*   **AutodocOptionsArgParser** on **AutodocOptions** -- helper for argument parsers
    *   **Methods:** `static void populateParser(ArgParser parser)`
*   **CreateReleaseOptionsArgParser** on **CreateReleaseOptions** -- helper for argument parsers
    *   **Methods:** `static void populateParser(ArgParser parser)`
*   **DetermineVersionOptionsArgParser** on **DetermineVersionOptions** -- helper for argument parsers
    *   **Methods:** `static void populateParser(ArgParser parser)`
*   **GlobalOptionsArgParser** on **GlobalOptions** -- helper for argument parsers
    *   **Methods:** `static void populateParser(ArgParser parser)`
*   **MergeAuditTrailsOptionsArgParser** on **MergeAuditTrailsOptions** -- helper for argument parsers
    *   **Methods:** `static void populateParser(ArgParser parser)`
*   **PostReleaseTriageOptionsArgParser** on **PostReleaseTriageOptions** -- helper for argument parsers
    *   **Methods:** `static void populateParser(ArgParser parser)`
*   **TriageOptionsArgParser** on **TriageOptions** -- helper for argument parsers
    *   **Methods:** `static void populateParser(ArgParser parser)`
*   **UpdateOptionsArgParser** on **UpdateOptions** -- helper for argument parsers
    *   **Getters:** `bool get updateAll` (Returns true if no specific filter flags are set)
    *   **Methods:** `static void populateParser(ArgParser parser)`
*   **VersionOptionsArgParser** on **VersionOptions** -- helper for argument parsers
    *   **Methods:** `static void populateParser(ArgParser parser)`

## 4. Top-Level Functions

*   **computeFileHash** -- `String computeFileHash(String filePath)`
    *   Compute SHA256 hash of a file's contents.

*   **acquireTriageLock** -- `bool acquireTriageLock(bool force)`
    *   Acquire a file-based lock. Returns true if acquired, false if another run is active.

*   **releaseTriageLock** -- `void releaseTriageLock()`
    *   Release the file-based lock.

*   **createTriageRunDir** -- `String createTriageRunDir(String repoRoot)`
    *   Create a unique run directory for this triage session.

*   **saveCheckpoint** -- `void saveCheckpoint(String runDir, GamePlan plan, String lastPhase)`
    *   Save a checkpoint so the run can be resumed later.

*   **loadCachedResults** -- `Map<int, List<InvestigationResult>> loadCachedResults(String runDir, GamePlan plan)`
    *   Load cached investigation results from a game plan.

*   **loadCachedDecisions** -- `List<TriageDecision> loadCachedDecisions(String runDir)`
    *   Load cached triage decisions from a run directory.

*   **findLatestManifest** -- `String? findLatestManifest(String repoRoot)`
    *   Search recent triage runs for the latest issue_manifest.json.
