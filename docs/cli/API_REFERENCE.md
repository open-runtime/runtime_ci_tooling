# CI/CD CLI API Reference

This document provides a comprehensive reference for the CI/CD CLI module, covering commands, options, utilities, and configuration generators.

## 1. Commands

Commands extend `Command<void>` from the `args` package and define the CLI surface area.

### **AnalyzeCommand**
Run `dart analyze` to enforce code quality, failing only on errors.
- **Fields:**
  - `String name` -- The command name (`'analyze'`).
  - `String description` -- The command description.
- **Methods:**
  - `Future<void> run()` -- Executes the command.
```dart
import 'package:runtime_ci_tooling/src/cli/commands/analyze_command.dart';

final cmd = AnalyzeCommand();
await cmd.run();
```

### **ArchiveRunCommand**
Archive `.runtime_ci/runs/` to `.runtime_ci/audit/vX.X.X/` for permanent storage.
- **Fields:**
  - `String name` -- The command name (`'archive-run'`).
  - `String description` -- The command description.
- **Methods:**
  - `Future<void> run()` -- Executes the command.

### **AutodocCommand**
Generate/update module docs (`--init`, `--force`, `--module`, `--dry-run`).
- **Fields:**
  - `String name` -- The command name (`'autodoc'`).
  - `String description` -- The command description.
- **Methods:**
  - `Future<void> run()` -- Executes the command.

### **ComposeCommand**
Run Stage 2 Changelog Composer (Gemini Pro).
- **Fields:**
  - `String name` -- The command name (`'compose'`).
  - `String description` -- The command description.
- **Methods:**
  - `Future<void> run()` -- Executes the command.

### **ConfigureMcpCommand**
Set up MCP servers (GitHub, Sentry).
- **Fields:**
  - `String name` -- The command name (`'configure-mcp'`).
  - `String description` -- The command description.
- **Methods:**
  - `Future<void> run()` -- Executes the command.

### **ConsumersCommand**
Discover `runtime_ci_tooling` consumers and sync latest release data.
- **Fields:**
  - `String name` -- The command name (`'consumers'`).
  - `String description` -- The command description.
- **Methods:**
  - `static int computeNextDiscoveryIndexFromNames(Iterable<String> fileNames)` -- Computes the next discovery index.
  - `static String buildDiscoverySnapshotName({required int index, required DateTime localTime})` -- Builds a discovery filename in the required format.
  - `static String resolveVersionFolderName(String tagName)` -- Keeps release folder names aligned with tag names.
  - `static String snapshotIdentityFromPath(String path)` -- Filename identity used for resume across moved workspaces.
  - `static bool isSnapshotSourceCompatible({required String? sourceSnapshotPath, required String? sourceSnapshotIdentity, required String expectedSnapshotPath})` -- Checks snapshot source compatibility.
  - `static bool isReleaseSummaryReusable({required String status, required String outputPath, required String? tag, required String? exactTag})` -- Evaluates if a previous summary is reusable.
  - `static String buildReleaseOutputPath({required String outputDir, required String repoName, required String tagName})` -- Returns the expected release output path for a repo/tag.
  - `static String? selectTagFromReleaseList({required List<Map<String, dynamic>> releases, required bool includePrerelease, RegExp? tagPattern})` -- Selects the latest matching tag from `gh release list`.
  - `Future<void> run()` -- Executes the command.

### **CreateReleaseCommand**
Create git tag, GitHub Release, commit all changes.
- **Fields:**
  - `String name` -- The command name (`'create-release'`).
  - `String description` -- The command description.
- **Methods:**
  - `Future<void> run()` -- Executes the command.

### **DetermineVersionCommand**
Determine SemVer bump via Gemini + regex (CI: `--output-github-actions`).
- **Fields:**
  - `String name` -- The command name (`'determine-version'`).
  - `String description` -- The command description.
- **Methods:**
  - `Future<void> run()` -- Executes the command.

### **DocumentationCommand**
Run documentation update via Gemini 3 Pro Preview.
- **Fields:**
  - `String name` -- The command name (`'documentation'`).
  - `String description` -- The command description.
- **Methods:**
  - `Future<void> run()` -- Executes the command.

### **ExploreCommand**
Run Stage 1 Explorer Agent (Gemini 3 Pro Preview).
- **Fields:**
  - `String name` -- The command name (`'explore'`).
  - `String description` -- The command description.
- **Methods:**
  - `Future<void> run()` -- Executes the command.

### **InitCommand**
Scan repo and generate `.runtime_ci/config.json` + `autodoc.json` + scaffold workflows.
- **Fields:**
  - `String name` -- The command name (`'init'`).
  - `String description` -- The command description.
- **Methods:**
  - `Future<void> run()` -- Executes the command.

### **MergeAuditTrailsCommand**
Merge CI/CD audit artifacts from multiple jobs (CI use).
- **Fields:**
  - `String name` -- The command name (`'merge-audit-trails'`).
  - `String description` -- The command description.
- **Methods:**
  - `Future<void> run()` -- Executes the command.

### **ReleaseCommand**
Run the full local release pipeline.
- **Fields:**
  - `String name` -- The command name (`'release'`).
  - `String description` -- The command description.
- **Methods:**
  - `Future<void> run()` -- Executes the command.

### **ReleaseNotesCommand**
Run Stage 3 Release Notes Author (Gemini 3 Pro Preview).
- **Fields:**
  - `String name` -- The command name (`'release-notes'`).
  - `String description` -- The command description.
- **Methods:**
  - `Future<void> run()` -- Executes the command.

### **SetupCommand**
Install all prerequisites (Node.js, Gemini CLI, gh, jq, tree).
- **Fields:**
  - `String name` -- The command name (`'setup'`).
  - `String description` -- The command description.
- **Methods:**
  - `Future<void> run()` -- Executes the command.

### **StatusCommand**
Show current CI/CD configuration status.
- **Fields:**
  - `String name` -- The command name (`'status'`).
  - `String description` -- The command description.
- **Methods:**
  - `Future<void> run()` -- Executes the command.

### **TestCommand**
Run dart test.
- **Fields:**
  - `String name` -- The command name (`'test'`).
  - `String description` -- The command description.
- **Methods:**
  - `Future<void> run()` -- Executes the command.

### **TriageCommand**
Issue triage pipeline with AI-powered investigation. Supports multiple subcommands.
- **Fields:**
  - `String name` -- The command name (`'triage'`).
  - `String description` -- The command description.
- **Methods:**
  - `Future<void> run()` -- Executes the command or passes to subcommands.

### **TriageAutoCommand**
Auto-triage all untriaged open issues.
- **Fields:**
  - `String name` -- The command name (`'auto'`).
  - `String description` -- The command description.
- **Methods:**
  - `Future<void> run()` -- Executes the command.

### **TriagePostReleaseCommand**
Close loop after release (requires `--version` and `--release-tag`).
- **Fields:**
  - `String name` -- The command name (`'post-release'`).
  - `String description` -- The command description.
- **Methods:**
  - `Future<void> run()` -- Executes the command.

### **TriagePreReleaseCommand**
Scan issues for upcoming release (requires `--prev-tag` and `--version`).
- **Fields:**
  - `String name` -- The command name (`'pre-release'`).
  - `String description` -- The command description.
- **Methods:**
  - `Future<void> run()` -- Executes the command.

### **TriageResumeCommand**
Resume a previously interrupted triage run.
- **Fields:**
  - `String name` -- The command name (`'resume'`).
  - `String description` -- The command description.
  - `String invocation` -- Target invocation.
- **Methods:**
  - `Future<void> run()` -- Executes the command.

### **TriageSingleCommand**
Triage a single issue by number.
- **Fields:**
  - `String name` -- The command name (`'single'`).
  - `String description` -- The command description.
  - `String invocation` -- Target invocation.
- **Methods:**
  - `static Future<void> runSingle(int issueNumber, ArgResults? globalResults)` -- Shared logic for triage execution.
  - `Future<void> run()` -- Executes the command.

### **TriageStatusCommand**
Show triage pipeline status.
- **Fields:**
  - `String name` -- The command name (`'status'`).
  - `String description` -- The command description.
- **Methods:**
  - `Future<void> run()` -- Executes the command.

### **UpdateAllCommand**
Discover and update all `runtime_ci_tooling` packages under a root directory.
- **Fields:**
  - `String name` -- The command name (`'update-all'`).
  - `String description` -- The command description.
- **Methods:**
  - `Future<void> run()` -- Executes the command.

### **UpdateCommand**
Update templates, configs, and workflows from `runtime_ci_tooling`.
- **Fields:**
  - `String name` -- The command name (`'update'`).
  - `String description` -- The command description.
- **Methods:**
  - `Future<void> run()` -- Executes the command.

### **ValidateCommand**
Validate all configuration files.
- **Fields:**
  - `String name` -- The command name (`'validate'`).
  - `String description` -- The command description.
- **Methods:**
  - `Future<void> run()` -- Executes the command.

### **VerifyProtosCommand**
Verify proto source and generated files exist.
- **Fields:**
  - `String name` -- The command name (`'verify-protos'`).
  - `String description` -- The command description.
- **Methods:**
  - `Future<void> run()` -- Executes the command.

### **VersionCommand**
Show the next SemVer version (no side effects).
- **Fields:**
  - `String name` -- The command name (`'version'`).
  - `String description` -- The command description.
- **Methods:**
  - `Future<void> run()` -- Executes the command.

---

## 2. Options and Configurations

These classes hold parsed options from `ArgResults`.

### **ArchiveRunOptions**
- **Constructors:**
  - `const ArchiveRunOptions({String? runDir})`
  - `factory ArchiveRunOptions.fromArgResults(ArgResults results)`
- **Fields:**
  - `String? runDir` -- Directory containing the CI run to archive.
```dart
import 'package:runtime_ci_tooling/src/cli/options/archive_run_options.dart';

final options = ArchiveRunOptions()
  ..runDir = 'path/to/dir';
```

### **AutodocOptions**
- **Constructors:**
  - `const AutodocOptions({bool init = false, bool force = false, String? module})`
  - `factory AutodocOptions.fromArgResults(ArgResults results)`
- **Fields:**
  - `bool init` -- Scan repo and create initial autodoc.json.
  - `bool force` -- Regenerate all docs regardless of hash.
  - `String? module` -- Only generate for a specific module.

### **CreateReleaseOptions**
- **Constructors:**
  - `const CreateReleaseOptions({String? artifactsDir, String? repo})`
  - `factory CreateReleaseOptions.fromArgResults(ArgResults results)`
- **Fields:**
  - `String? artifactsDir` -- Directory containing downloaded CI artifacts.
  - `String? repo` -- GitHub repository slug owner/repo.

### **DetermineVersionOptions**
- **Constructors:**
  - `const DetermineVersionOptions({bool outputGithubActions = false})`
  - `factory DetermineVersionOptions.fromArgResults(ArgResults results)`
- **Fields:**
  - `bool outputGithubActions` -- Write version outputs to `$GITHUB_OUTPUT` for GitHub Actions.

### **GlobalOptions**
- **Constructors:**
  - `const GlobalOptions({bool dryRun = false, bool verbose = false})`
  - `factory GlobalOptions.fromArgResults(ArgResults results)`
- **Fields:**
  - `bool dryRun` -- Show what would be done without executing.
  - `bool verbose` -- Show detailed command output.

### **ManageCicdOptions**
- **Constructors:**
  - `const ManageCicdOptions({...})`
- **Fields:**
  - `bool dryRun`, `bool verbose`, `String? prevTag`, `String? version`, `bool outputGithubActions`, `String? artifactsDir`, `String? repo`, `String? releaseTag`, `String? releaseUrl`, `String? manifest`

### **MergeAuditTrailsOptions**
- **Constructors:**
  - `const MergeAuditTrailsOptions({String? incomingDir, String? outputDir})`
  - `factory MergeAuditTrailsOptions.fromArgResults(ArgResults results)`
- **Fields:**
  - `String? incomingDir` -- Directory containing incoming audit trail artifacts.
  - `String? outputDir` -- Output directory for merged audit trails.

### **PostReleaseTriageOptions**
- **Constructors:**
  - `const PostReleaseTriageOptions({String? releaseTag, String? releaseUrl, String? manifest})`
  - `factory PostReleaseTriageOptions.fromArgResults(ArgResults results)`
- **Fields:**
  - `String? releaseTag` -- Git tag for the release.
  - `String? releaseUrl` -- URL of the GitHub release page.
  - `String? manifest` -- Path to `issue_manifest.json`.

### **TriageCliOptions**
- **Constructors:**
  - `const TriageCliOptions({...})`
- **Fields:**
  - `bool dryRun`, `bool verbose`, `bool auto`, `bool status`, `bool force`, `bool preRelease`, `bool postRelease`, `String? resume`, `String? prevTag`, `String? version`, `String? releaseTag`, `String? releaseUrl`, `String? manifest`

### **TriageOptions**
- **Constructors:**
  - `const TriageOptions({bool force = false})`
  - `factory TriageOptions.fromArgResults(ArgResults results)`
- **Fields:**
  - `bool force` -- Override an existing triage lock.

### **UpdateAllOptions**
- **Constructors:**
  - `const UpdateAllOptions({...})`
  - `factory UpdateAllOptions.fromArgResults(ArgResults results)`
- **Fields:**
  - `String? scanRoot`, `int concurrency`, `bool force`, `bool workflows`, `bool templates`, `bool config`, `bool autodoc`, `bool backup`

### **UpdateOptions**
- **Constructors:**
  - `const UpdateOptions({...})`
  - `factory UpdateOptions.fromArgResults(ArgResults results)`
- **Fields:**
  - `bool force`, `bool templates`, `bool config`, `bool workflows`, `bool autodoc`, `bool backup`
- **Methods:**
  - `bool get updateAll` -- Returns true if no specific filter flags are set.

### **VersionOptions**
- **Constructors:**
  - `const VersionOptions({String? prevTag, String? version})`
  - `factory VersionOptions.fromArgResults(ArgResults results)`
- **Fields:**
  - `String? prevTag` -- Override previous tag detection.
  - `String? version` -- Override version (skip auto-detection).
```dart
import 'package:runtime_ci_tooling/src/cli/options/version_options.dart';

// Using cascade builder pattern:
final options = VersionOptions()
  ..prevTag = 'v1.0.0'
  ..version = '1.0.1';
```

---

## 3. Utilities and Services

### **CiProcessRunner**
- **Methods:**
  - `static bool commandExists(String command)` -- Check whether a command is available on the system PATH.
  - `static String runSync(String command, String workingDirectory, {bool verbose = false})` -- Run a shell command synchronously and return trimmed stdout.
  - `static void exec(String executable, List<String> args, {String? cwd, bool fatal = false, bool verbose = false})` -- Execute a command. Set fatal to true to exit on failure.

### **FileUtils**
- **Methods:**
  - `static void copyDirRecursive(Directory src, Directory dst)` -- Recursively copy a directory tree.
  - `static int countFiles(Directory dir)` -- Count all files in a directory tree.
  - `static String readFileOr(String path, [String fallback = '(not available)'])` -- Read a file and return its content, or a fallback message.

### **GeminiPrerequisiteError**
- **Constructors:**
  - `GeminiPrerequisiteError(this.message)`
- **Fields:**
  - `String message` -- Error message payload.
- **Methods:**
  - `String toString()` -- Returns the formatted error representation.

### **GeminiUtils**
- **Methods:**
  - `static bool geminiAvailable({bool warnOnly = false})` -- Returns true if Gemini CLI and API key are both available.
  - `static void requireGeminiCli()` -- Require Gemini CLI to be installed.
  - `static void requireApiKey()` -- Require GEMINI_API_KEY to be set.
  - `static String extractJson(String rawOutput)` -- Extract the first balanced JSON object from raw output.
  - `static String? extractJsonObject(String text)` -- Extract the first balanced JSON object from text, or null if none found.

### **HookInstaller**
- **Methods:**
  - `static bool install(String repoRoot, {int lineLength = 120, bool dryRun = false})` -- Installs or refreshes the pre-commit hook.

### **Logger**
- **Methods:**
  - `static void header(String msg)` -- Prints a bold header log.
  - `static void info(String msg)` -- Prints a standard informational log.
  - `static void success(String msg)` -- Prints a green success log.
  - `static void warn(String msg)` -- Prints a yellow warning log.
  - `static void error(String msg)` -- Prints a red error log to stderr.

### **ManageCicdCli**
- **Constructors:**
  - `ManageCicdCli()`
- **Methods:**
  - `static GlobalOptions parseGlobalOptions(ArgResults? results)` -- Parse global options from ArgResults.
  - `static bool isVerbose(ArgResults? results)` -- Returns true if verbose mode is enabled.
  - `static bool isDryRun(ArgResults? results)` -- Returns true if dry-run mode is enabled.

### **PromptResolver**
- **Methods:**
  - `static String promptScript(String scriptName)` -- Resolves the absolute path to a prompt script.
  - `static String resolveToolingPackageRoot()` -- Find the `runtime_ci_tooling` package root.

### **ReleaseUtils**
- **Methods:**
  - `static String buildReleaseCommitMessage({required String repoRoot, required String version, required String prevTag, required Directory releaseDir, bool verbose = false})` -- Build a rich, detailed commit message.
  - `static List<Map<String, String>> gatherVerifiedContributors(String repoRoot, String prevTag)` -- Gather VERIFIED contributor usernames.
  - `static String buildFallbackReleaseNotes(String repoRoot, String version, String prevTag)` -- Build fallback release notes.
  - `static void addChangelogReferenceLinks(String repoRoot, String content)` -- Add Keep a Changelog reference-style links.

### **RepoUtils**
- **Methods:**
  - `static String? findRepoRoot()` -- Find the repository root by walking up and looking for `pubspec.yaml`.

### **StepSummary**
- **Methods:**
  - `static void write(String markdown)` -- Write a markdown summary to `$GITHUB_STEP_SUMMARY`.
  - `static String artifactLink([String label = 'View all artifacts'])` -- Build a link to the current workflow run's artifacts page.
  - `static String compareLink(String prevTag, String newTag, [String? label])` -- Build a GitHub compare link.
  - `static String ghLink(String label, String path)` -- Build a link to a file/path in the repository.
  - `static String releaseLink(String tag)` -- Build a link to a GitHub Release by tag.
  - `static String collapsible(String title, String content, {bool open = false})` -- Wrap content in a collapsible `<details>` block.

### **TemplateEntry**
- **Constructors:**
  - `TemplateEntry({required String id, String? source, required String destination, required String category, required String description})`
  - `factory TemplateEntry.fromJson(Map<String, dynamic> json)`
- **Fields:**
  - `String id`, `String? source`, `String destination`, `String category`, `String description`

### **TemplateResolver**
- **Methods:**
  - `static String resolvePackageRoot()` -- Find the `runtime_ci_tooling` package root directory.
  - `static String resolveTemplatesDir()` -- Resolve the absolute path to the templates directory.
  - `static String resolveTemplatePath(String relativePath)` -- Resolve a specific template file path.
  - `static Map<String, dynamic> readManifest()` -- Read the `templates/manifest.json`.
  - `static String resolveToolingVersion()` -- Read the tooling version from `pubspec.yaml`.

### **TemplateVersionTracker**
- **Constructors:**
  - `factory TemplateVersionTracker.load(String repoRoot)`
- **Methods:**
  - `String? getInstalledHash(String templateId)` -- Get the hash of a template as it was when last installed.
  - `String? getConsumerHash(String templateId)` -- Get the hash of a consumer's file at the time it was last installed.
  - `void recordUpdate(String templateId, {required String templateHash, required String consumerFileHash, required String toolingVersion})` -- Record that a template was installed/updated.
  - `void save(String repoRoot)` -- Save to disk.
- **Fields:**
  - `String? lastToolingVersion` -- Get the tooling version that was last used to update.

### **ToolInstallers**
- **Methods:**
  - `static Future<void> installTool(String tool, {bool dryRun = false})` -- Install a tool by name.
  - `static Future<void> installNodeJs()`
  - `static Future<void> installGeminiCli()`
  - `static Future<void> installGitHubCli()`
  - `static Future<void> installJq()`
  - `static Future<void> installTree()`

### **VersionDetection**
- **Methods:**
  - `static String detectPrevTag(String repoRoot, {bool verbose = false})` -- Detect the previous release tag from git history.
  - `static String detectNextVersion(String repoRoot, String prevTag, {bool verbose = false})` -- Detect the next semantic version based on commit history analysis.
  - `static int compareVersions(String a, String b)` -- Compare two semver versions.

### **WorkflowGenerator**
- **Constructors:**
  - `WorkflowGenerator({required Map<String, dynamic> ciConfig, required String toolingVersion})`
- **Fields:**
  - `Map<String, dynamic> ciConfig` -- The CI config section loaded from the repository.
  - `String toolingVersion` -- Target tooling version.
- **Methods:**
  - `static Map<String, dynamic>? loadCiConfig(String repoRoot)` -- Load the CI config section from a repo's `config.json`.
  - `String render({String? existingContent})` -- Render the CI workflow from the skeleton template.
  - `static List<String> validate(Map<String, dynamic> ciConfig)` -- Validate that the CI config has all required fields.
  - `void logConfig()` -- Log a summary of what will be generated.

---

## 4. Extensions

### **ArchiveRunOptionsArgParser** on **ArchiveRunOptions**
- **Methods:**
  - `static void populateParser(ArgParser parser)` -- Populates argument parser.

### **AutodocOptionsArgParser** on **AutodocOptions**
- **Methods:**
  - `static void populateParser(ArgParser parser)` -- Populates argument parser.

### **CreateReleaseOptionsArgParser** on **CreateReleaseOptions**
- **Methods:**
  - `static void populateParser(ArgParser parser)` -- Populates argument parser.

### **DetermineVersionOptionsArgParser** on **DetermineVersionOptions**
- **Methods:**
  - `static void populateParser(ArgParser parser)` -- Populates argument parser.

### **GlobalOptionsArgParser** on **GlobalOptions**
- **Methods:**
  - `static void populateParser(ArgParser parser)` -- Populates argument parser.

### **MergeAuditTrailsOptionsArgParser** on **MergeAuditTrailsOptions**
- **Methods:**
  - `static void populateParser(ArgParser parser)` -- Populates argument parser.

### **PostReleaseTriageOptionsArgParser** on **PostReleaseTriageOptions**
- **Methods:**
  - `static void populateParser(ArgParser parser)` -- Populates argument parser.

### **TriageOptionsArgParser** on **TriageOptions**
- **Methods:**
  - `static void populateParser(ArgParser parser)` -- Populates argument parser.

### **UpdateAllOptionsArgParser** on **UpdateAllOptions**
- **Methods:**
  - `static void populateParser(ArgParser parser)` -- Populates argument parser.

### **UpdateOptionsArgParser** on **UpdateOptions**
- **Methods:**
  - `static void populateParser(ArgParser parser)` -- Populates argument parser.

### **VersionOptionsArgParser** on **VersionOptions**
- **Methods:**
  - `static void populateParser(ArgParser parser)` -- Populates argument parser.

---

## 5. Top-Level Functions

### **scaffoldAutodocJson**
- **Signature:** `bool scaffoldAutodocJson(String repoRoot, {bool overwrite = false})`
- **Description:** Scaffold `.runtime_ci/autodoc.json` by scanning `lib/src/` for modules.

### **computeFileHash**
- **Signature:** `String computeFileHash(String filePath)`
- **Description:** Compute SHA256 hash of a file's contents.

### **acquireTriageLock**
- **Signature:** `bool acquireTriageLock(bool force)`
- **Description:** Acquire a file-based lock. Returns true if acquired, false if another run is active.

### **releaseTriageLock**
- **Signature:** `void releaseTriageLock()`
- **Description:** Release the file-based lock.

### **createTriageRunDir**
- **Signature:** `String createTriageRunDir(String repoRoot)`
- **Description:** Create a unique run directory for this triage session.

### **saveCheckpoint**
- **Signature:** `void saveCheckpoint(String runDir, GamePlan plan, String lastPhase)`
- **Description:** Save a checkpoint so the run can be resumed later.

### **loadCachedResults**
- **Signature:** `Map<int, List<InvestigationResult>> loadCachedResults(String runDir, GamePlan plan)`
- **Description:** Load cached investigation results from a game plan.

### **loadCachedDecisions**
- **Signature:** `List<TriageDecision> loadCachedDecisions(String runDir)`
- **Description:** Load cached triage decisions from a run directory.

### **findLatestManifest**
- **Signature:** `String? findLatestManifest(String repoRoot)`
- **Description:** Search recent triage runs for the latest `issue_manifest.json`.
