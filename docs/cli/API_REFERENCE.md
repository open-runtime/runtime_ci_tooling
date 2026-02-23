# CI/CD CLI API Reference

This document provides a comprehensive API reference for the CI/CD CLI module of `runtime_ci_tooling`.
The CLI module is built using `package:args/command_runner.dart` and `package:build_cli_annotations/build_cli_annotations.dart`.

## Core CLI Usage

```dart
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';
import 'package:runtime_ci_tooling/src/cli/options/global_options.dart';

void main(List<String> args) async {
  final cli = ManageCicdCli();
  try {
    // Run the parsed command
    await cli.run(args);
  } catch (e) {
    print('Command failed: $e');
  }
}
```

### 1. Classes

#### CLI Commands
- **ManageCicdCli** -- CLI entry point for CI/CD Automation.
  - *Methods*:
    - `ManageCicdCli()` -- Constructor.
    - `static GlobalOptions parseGlobalOptions(ArgResults? results)` -- Parse global options from ArgResults.
    - `static bool isVerbose(ArgResults? results)` -- Returns true if verbose mode is enabled.
    - `static bool isDryRun(ArgResults? results)` -- Returns true if dry-run mode is enabled.
- **AnalyzeCommand** -- Run `dart analyze` (fail on errors only).
- **ArchiveRunCommand** -- Archive a CI/CD run to `.runtime_ci/audit/vX.X.X/` for permanent storage.
- **AutodocCommand** -- Generate/update module docs (`--init`, `--force`, `--module`, `--dry-run`).
- **ComposeCommand** -- Run Stage 2 Changelog Composer (Gemini Pro).
- **ConfigureMcpCommand** -- Set up MCP servers (GitHub, Sentry).
- **ConsumersCommand** -- Discover `runtime_ci_tooling` consumers and sync latest release data.
  - *Methods*:
    - `static int computeNextDiscoveryIndexFromNames(Iterable<String> fileNames)`
    - `static String buildDiscoverySnapshotName({required int index, required DateTime localTime})`
    - `static String resolveVersionFolderName(String tagName)`
    - `static String snapshotIdentityFromPath(String path)`
    - `static bool isSnapshotSourceCompatible({required String? sourceSnapshotPath, required String? sourceSnapshotIdentity, required String expectedSnapshotPath})`
    - `static bool isReleaseSummaryReusable({required String status, required String outputPath, required String? tag, required String? exactTag})`
    - `static String buildReleaseOutputPath({required String outputDir, required String repoName, required String tagName})`
    - `static String? selectTagFromReleaseList({required List<Map<String, dynamic>> releases, required bool includePrerelease, RegExp? tagPattern})`
- **CreateReleaseCommand** -- Create git tag, GitHub Release, commit all changes.
- **DetermineVersionCommand** -- Determine SemVer bump via Gemini + regex (CI: `--output-github-actions`).
- **DocumentationCommand** -- Run documentation update via Gemini 3 Pro Preview.
- **ExploreCommand** -- Run Stage 1 Explorer Agent (Gemini 3 Pro Preview).
- **InitCommand** -- Scan repo and generate `.runtime_ci/config.json` + `autodoc.json` + scaffold workflows.
- **MergeAuditTrailsCommand** -- Merge CI/CD audit artifacts from multiple jobs (CI use).
- **ReleaseCommand** -- Run the full local release pipeline.
- **ReleaseNotesCommand** -- Run Stage 3 Release Notes Author (Gemini 3 Pro Preview).
- **SetupCommand** -- Install all prerequisites (Node.js, Gemini CLI, gh, jq, tree).
- **StatusCommand** -- Show current CI/CD configuration status.
- **TestCommand** -- Run `dart test`.
- **TriageCommand** -- Issue triage pipeline with AI-powered investigation.
- **TriageAutoCommand** -- Auto-triage all untriaged open issues.
- **TriagePostReleaseCommand** -- Close loop after release (requires `--version` and `--release-tag`).
- **TriagePreReleaseCommand** -- Scan issues for upcoming release (requires `--prev-tag` and `--version`).
- **TriageResumeCommand** -- Resume a previously interrupted triage run.
- **TriageSingleCommand** -- Triage a single issue by number.
  - *Methods*:
    - `static Future<void> runSingle(int issueNumber, ArgResults? globalResults)`
- **TriageStatusCommand** -- Show triage pipeline status.
- **UpdateAllCommand** -- Discover and update all `runtime_ci_tooling` packages under a root directory.
- **UpdateCommand** -- Update templates, configs, and workflows from `runtime_ci_tooling`.
- **ValidateCommand** -- Validate all configuration files.
- **VerifyProtosCommand** -- Verify proto source and generated files exist.
- **VersionCommand** -- Show the next SemVer version (no side effects).

#### CLI Options Usage Example

```dart
import 'package:runtime_ci_tooling/src/cli/options/autodoc_options.dart';
import 'package:runtime_ci_tooling/src/cli/options/global_options.dart';

// Example of programmatically building and using options
void handleAutodoc() {
  final globalOpts = GlobalOptions(dryRun: true, verbose: true);
  final autodocOpts = AutodocOptions(
    init: false,
    force: true,
    module: 'triage',
  );

  if (globalOpts.verbose) {
    print('Forcing autodoc for module: ${autodocOpts.module}');
  }
}
```

#### CLI Options Details
- **ArchiveRunOptions** -- CLI options for the `archive-run` command.
  - *Fields*: `String? runDir` (Directory containing the CI run to archive)
  - *Constructors*: `const ArchiveRunOptions({this.runDir})`, `factory ArchiveRunOptions.fromArgResults(ArgResults results)`
- **AutodocOptions** -- CLI options for the `autodoc` command.
  - *Fields*: `bool init`, `bool force`, `String? module`
  - *Constructors*: `const AutodocOptions({this.init = false, this.force = false, this.module})`, `factory AutodocOptions.fromArgResults(ArgResults results)`
- **CreateReleaseOptions** -- CLI options for the `create-release` command.
  - *Fields*: `String? artifactsDir`, `String? repo`
  - *Constructors*: `const CreateReleaseOptions({this.artifactsDir, this.repo})`, `factory CreateReleaseOptions.fromArgResults(ArgResults results)`
- **DetermineVersionOptions** -- CLI options for the `determine-version` command.
  - *Fields*: `bool outputGithubActions`
  - *Constructors*: `const DetermineVersionOptions({this.outputGithubActions = false})`, `factory DetermineVersionOptions.fromArgResults(ArgResults results)`
- **GlobalOptions** -- Global CLI options available to all commands.
  - *Fields*: `bool dryRun`, `bool verbose`
  - *Constructors*: `const GlobalOptions({this.dryRun = false, this.verbose = false})`, `factory GlobalOptions.fromArgResults(ArgResults results)`
- **ManageCicdOptions** -- Combined CLI options for the `manage_cicd.dart` entry point.
  - *Fields*: `bool dryRun`, `bool verbose`, `String? prevTag`, `String? version`, `bool outputGithubActions`, `String? artifactsDir`, `String? repo`, `String? releaseTag`, `String? releaseUrl`, `String? manifest`
  - *Constructors*: `const ManageCicdOptions(...)`
- **MergeAuditTrailsOptions** -- CLI options for the `merge-audit-trails` command.
  - *Fields*: `String? incomingDir`, `String? outputDir`
  - *Constructors*: `const MergeAuditTrailsOptions({this.incomingDir, this.outputDir})`, `factory MergeAuditTrailsOptions.fromArgResults(ArgResults results)`
- **PostReleaseTriageOptions** -- CLI options for the `post-release` command.
  - *Fields*: `String? releaseTag`, `String? releaseUrl`, `String? manifest`
  - *Constructors*: `const PostReleaseTriageOptions()`, `factory PostReleaseTriageOptions.fromArgResults(ArgResults results)`
- **TriageCliOptions** -- Combined CLI options for the `triage_cli.dart` entry point.
  - *Fields*: `bool dryRun`, `bool verbose`, `bool auto`, `bool status`, `bool force`, `bool preRelease`, `bool postRelease`, `String? resume`, `String? prevTag`, `String? version`, `String? releaseTag`, `String? releaseUrl`, `String? manifest`
  - *Constructors*: `const TriageCliOptions(...)`
- **TriageOptions** -- CLI options shared by triage subcommands that acquire a lock.
  - *Fields*: `bool force`
  - *Constructors*: `const TriageOptions({this.force = false})`, `factory TriageOptions.fromArgResults(ArgResults results)`
- **UpdateAllOptions** -- CLI options for the `update-all` command.
  - *Fields*: `String? scanRoot`, `int concurrency`, `bool force`, `bool workflows`, `bool templates`, `bool config`, `bool autodoc`, `bool backup`
  - *Constructors*: `const UpdateAllOptions(...)`, `factory UpdateAllOptions.fromArgResults(ArgResults results)`
- **UpdateOptions** -- CLI options for the `update` command.
  - *Fields*: `bool force`, `bool templates`, `bool config`, `bool workflows`, `bool autodoc`, `bool backup`
  - *Methods/Getters*: `bool get updateAll`
  - *Constructors*: `const UpdateOptions(...)`, `factory UpdateOptions.fromArgResults(ArgResults results)`
- **VersionOptions** -- Version-related CLI options.
  - *Fields*: `String? prevTag`, `String? version`
  - *Constructors*: `const VersionOptions({this.prevTag, this.version})`, `factory VersionOptions.fromArgResults(ArgResults results)`

#### Utilities

```dart
import 'package:runtime_ci_tooling/src/cli/utils/process_runner.dart';

// Check if a tool is installed on the system path
if (CiProcessRunner.commandExists('git')) {
  final output = CiProcessRunner.runSync('git status', '/path/to/repo', verbose: true);
}
```

- **CiProcessRunner** -- Utilities for running external processes.
  - *Methods*:
    - `static bool commandExists(String command)`
    - `static String runSync(String command, String workingDirectory, {bool verbose = false})`
    - `static void exec(String executable, List<String> args, {String? cwd, bool fatal = false, bool verbose = false})`
- **FileUtils** -- File system utilities for CI/CD operations.
  - *Methods*:
    - `static void copyDirRecursive(Directory src, Directory dst)`
    - `static int countFiles(Directory dir)`
    - `static String readFileOr(String path, [String fallback = '(not available)'])`
- **GeminiPrerequisiteError** -- Exception thrown when Gemini CLI prerequisites are not met.
  - *Fields*: `String message`
- **GeminiUtils** -- Utilities for Gemini CLI integration.
  - *Methods*:
    - `static bool geminiAvailable({bool warnOnly = false})`
    - `static void requireGeminiCli()`
    - `static void requireApiKey()`
    - `static String extractJson(String rawOutput)`
    - `static String? extractJsonObject(String text)`
- **HookInstaller** -- Installs and manages git pre-commit hooks for Dart repos.
  - *Methods*:
    - `static bool install(String repoRoot, {int lineLength = 120, bool dryRun = false})`
- **Logger** -- ANSI-styled console logging for CI/CD commands.
  - *Methods*:
    - `static void header(String msg)`
    - `static void info(String msg)`
    - `static void success(String msg)`
    - `static void warn(String msg)`
    - `static void error(String msg)`
- **PromptResolver** -- Resolves paths to prompt scripts within the `runtime_ci_tooling` package.
  - *Methods*:
    - `static String promptScript(String scriptName)`
    - `static String resolveToolingPackageRoot()`
- **ReleaseUtils** -- Utilities for release management.
  - *Methods*:
    - `static String buildReleaseCommitMessage({required String repoRoot, required String version, required String prevTag, required Directory releaseDir, bool verbose = false})`
    - `static List<Map<String, String>> gatherVerifiedContributors(String repoRoot, String prevTag)`
    - `static String buildFallbackReleaseNotes(String repoRoot, String version, String prevTag)`
    - `static void addChangelogReferenceLinks(String repoRoot, String content)`
- **RepoUtils** -- Utilities for finding and working with the repository root.
  - *Methods*:
    - `static String? findRepoRoot()`
- **StepSummary** -- Step summary utilities for GitHub Actions.
  - *Methods*:
    - `static void write(String markdown)`
    - `static String artifactLink([String label = 'View all artifacts'])`
    - `static String compareLink(String prevTag, String newTag, [String? label])`
    - `static String ghLink(String label, String path)`
    - `static String releaseLink(String tag)`
    - `static String collapsible(String title, String content, {bool open = false})`
- **TemplateEntry** -- Represents one template entry from `manifest.json`.
  - *Fields*: `String id`, `String? source`, `String destination`, `String category`, `String description`
  - *Constructors*: `TemplateEntry(...)`, `factory TemplateEntry.fromJson(Map<String, dynamic> json)`
- **TemplateResolver** -- Resolves paths within the `runtime_ci_tooling` package.
  - *Methods*:
    - `static String resolvePackageRoot()`
    - `static String resolveTemplatesDir()`
    - `static String resolveTemplatePath(String relativePath)`
    - `static Map<String, dynamic> readManifest()`
    - `static String resolveToolingVersion()`
- **TemplateVersionTracker** -- Tracks which template versions a consumer repo has installed.
  - *Fields*: `static const String kTrackingFile = '.runtime_ci/template_versions.json'`
  - *Methods/Getters*:
    - `String? get lastToolingVersion`
    - `factory TemplateVersionTracker.load(String repoRoot)`
    - `String? getInstalledHash(String templateId)`
    - `String? getConsumerHash(String templateId)`
    - `void recordUpdate(String templateId, {required String templateHash, required String consumerFileHash, required String toolingVersion})`
    - `void save(String repoRoot)`
- **ToolInstallers** -- Cross-platform tool installation utilities.
  - *Methods*:
    - `static Future<void> installTool(String tool, {bool dryRun = false})`
    - `static Future<void> installNodeJs()`
    - `static Future<void> installGeminiCli()`
    - `static Future<void> installGitHubCli()`
    - `static Future<void> installJq()`
    - `static Future<void> installTree()`
- **VersionDetection** -- Version detection and semantic versioning utilities.
  - *Methods*:
    - `static String detectPrevTag(String repoRoot, {bool verbose = false})`
    - `static String detectNextVersion(String repoRoot, String prevTag, {bool verbose = false})`
    - `static int compareVersions(String a, String b)`
- **WorkflowGenerator** -- Renders CI workflow YAML from a Mustache skeleton template and `config.json`.
  - *Fields*: `Map<String, dynamic> ciConfig`, `String toolingVersion`
  - *Constructors*: `WorkflowGenerator({required this.ciConfig, required this.toolingVersion})`
  - *Methods*:
    - `static Map<String, dynamic>? loadCiConfig(String repoRoot)`
    - `String render({String? existingContent})`
    - `static List<String> validate(Map<String, dynamic> ciConfig)`
    - `void logConfig()`

### 2. Enums
*(No public enums are exposed by this module.)*

### 3. Extensions
- **ArchiveRunOptionsArgParser** on **ArchiveRunOptions** -- Adds parsing support.
  - *Methods*: `static void populateParser(ArgParser parser)`
- **AutodocOptionsArgParser** on **AutodocOptions** -- Adds parsing support.
  - *Methods*: `static void populateParser(ArgParser parser)`
- **CreateReleaseOptionsArgParser** on **CreateReleaseOptions** -- Adds parsing support.
  - *Methods*: `static void populateParser(ArgParser parser)`
- **DetermineVersionOptionsArgParser** on **DetermineVersionOptions** -- Adds parsing support.
  - *Methods*: `static void populateParser(ArgParser parser)`
- **GlobalOptionsArgParser** on **GlobalOptions** -- Adds parsing support.
  - *Methods*: `static void populateParser(ArgParser parser)`
- **MergeAuditTrailsOptionsArgParser** on **MergeAuditTrailsOptions** -- Adds parsing support.
  - *Methods*: `static void populateParser(ArgParser parser)`
- **PostReleaseTriageOptionsArgParser** on **PostReleaseTriageOptions** -- Adds parsing support.
  - *Methods*: `static void populateParser(ArgParser parser)`
- **TriageCliOptionsArgParser** on **TriageCliOptions** -- Adds parsing support.
  - *Methods*: `static void populateParser(ArgParser parser)`
- **TriageOptionsArgParser** on **TriageOptions** -- Adds parsing support.
  - *Methods*: `static void populateParser(ArgParser parser)`
- **UpdateAllOptionsArgParser** on **UpdateAllOptions** -- Adds parsing support.
  - *Methods*: `static void populateParser(ArgParser parser)`
- **UpdateOptionsArgParser** on **UpdateOptions** -- Adds parsing support.
  - *Methods*: `static void populateParser(ArgParser parser)`
- **VersionOptionsArgParser** on **VersionOptions** -- Adds parsing support.
  - *Methods*: `static void populateParser(ArgParser parser)`

### 4. Top-Level Functions

- **scaffoldAutodocJson** -- `bool scaffoldAutodocJson(String repoRoot, {bool overwrite = false})`
  - Scaffold `.runtime_ci/autodoc.json` by scanning `lib/src/` for modules.
- **computeFileHash** -- `String computeFileHash(String filePath)`
  - Compute SHA256 hash of a file's contents.
- **acquireTriageLock** -- `bool acquireTriageLock(bool force)`
  - Acquire a file-based lock for triage.
- **releaseTriageLock** -- `void releaseTriageLock()`
  - Release the file-based lock for triage.
- **createTriageRunDir** -- `String createTriageRunDir(String repoRoot)`
  - Create a unique run directory for this triage session.
- **saveCheckpoint** -- `void saveCheckpoint(String runDir, GamePlan plan, String lastPhase)`
  - Save a checkpoint so the run can be resumed later.
- **loadCachedResults** -- `Map<int, List<InvestigationResult>> loadCachedResults(String runDir, GamePlan plan)`
  - Load cached investigation results from a game plan.
- **loadCachedDecisions** -- `List<TriageDecision> loadCachedDecisions(String runDir)`
  - Load cached triage decisions from a run directory.
- **findLatestManifest** -- `String? findLatestManifest(String repoRoot)`
  - Search recent triage runs for the latest `issue_manifest.json`.
