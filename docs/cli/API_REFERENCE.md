# CI/CD CLI API Reference

This document provides a comprehensive API reference for the `runtime_ci_tooling` CI/CD CLI module.
This module provides a suite of CLI commands and utilities for managing the CI/CD pipeline, interacting with Gemini AI, and handling GitHub releases.

## 1. Commands

The CLI exposes several commands to manage the release pipeline and CI tasks.

### `AnalyzeCommand`
Runs `dart analyze` on the repository, failing only on errors (ignores warnings).
- **Name:** `analyze`
- **Method:** `Future<void> run()`

### `ArchiveRunCommand`
Archives a CI/CD run from `.runtime_ci/runs/` to `.runtime_ci/audit/vX.X.X/` for permanent storage.
- **Name:** `archive-run`

### `AutodocCommand`
Generates or updates documentation for modules using Gemini Pro.
- **Name:** `autodoc`
- **Options:** `--init`, `--force`, `--module`, `--dry-run`

### `ComposeCommand`
Runs Stage 2 Changelog Composer using Gemini Pro, updating `CHANGELOG.md` and `README.md`.
- **Name:** `compose`

### `ConfigureMcpCommand`
Sets up Model Context Protocol (MCP) servers (GitHub, Sentry) in `.gemini/settings.json`.
- **Name:** `configure-mcp`

### `ConsumersCommand`
Discovers repositories that consume `runtime_ci_tooling` and syncs latest release data.
- **Name:** `consumers`
- **Static Methods:**
  - `int computeNextDiscoveryIndexFromNames(Iterable<String> fileNames)`
  - `String buildDiscoverySnapshotName({required int index, required DateTime localTime})`
  - `String resolveVersionFolderName(String tagName)`
  - `String snapshotIdentityFromPath(String path)`
  - `bool isSnapshotSourceCompatible({required String? sourceSnapshotPath, required String? sourceSnapshotIdentity, required String expectedSnapshotPath})`
  - `bool isReleaseSummaryReusable({required String status, required String outputPath, required String? tag, required String? exactTag})`
  - `String buildReleaseOutputPath({required String outputDir, required String repoName, required String tagName})`
  - `String? selectTagFromReleaseList({required List<Map<String, dynamic>> releases, required bool includePrerelease, RegExp? tagPattern})`

### `CreateReleaseCommand`
Creates a git tag, GitHub Release, and commits all changes.
- **Name:** `create-release`

### `DetermineVersionCommand`
Determines the next SemVer version via Gemini analysis or regex fallback. Outputs for GitHub Actions if `--output-github-actions` is set.
- **Name:** `determine-version`

### `DocumentationCommand`
Runs documentation update using Gemini 3 Pro Preview.
- **Name:** `documentation`

### `ExploreCommand`
Runs Stage 1 Explorer Agent using Gemini 3 Pro Preview to analyze commits, PRs, and breaking changes.
- **Name:** `explore`

### `InitCommand`
Scans the repository and generates `.runtime_ci/config.json`, `autodoc.json`, and scaffolds workflows.
- **Name:** `init`

### `MergeAuditTrailsCommand`
Merges CI/CD audit artifacts from multiple parallel jobs into a single run directory.
- **Name:** `merge-audit-trails`

### `ReleaseCommand`
Runs the full local release pipeline (Version, Explore, and Compose).
- **Name:** `release`

### `ReleaseNotesCommand`
Runs Stage 3 Release Notes Author using Gemini 3 Pro Preview to generate rich narrative release notes.
- **Name:** `release-notes`

### `SetupCommand`
Installs all prerequisites (Node.js, Gemini CLI, gh, jq, tree) cross-platform.
- **Name:** `setup`

### `StatusCommand`
Shows the current CI/CD configuration status and validates required tools and configurations.
- **Name:** `status`

### `TestCommand`
Runs `dart test`, excluding tags like `gcp` and `integration`.
- **Name:** `test`

### `TriageCommand`
Root command for the issue triage pipeline. Supports subcommands: `auto`, `status`, `resume`, `pre-release`, `post-release`, `single`.
- **Name:** `triage`

### `UpdateCommand`
Updates templates, configs, and workflows from `runtime_ci_tooling`.
- **Name:** `update`

### `UpdateAllCommand`
Batch-updates all packages under a root directory by discovering `.runtime_ci/config.json`.
- **Name:** `update-all`

### `ValidateCommand`
Validates all configuration files (JSON, YAML, Dart, TOML).
- **Name:** `validate`

### `VerifyProtosCommand`
Verifies that proto source and generated Dart files exist.
- **Name:** `verify-protos`

### `VersionCommand`
Shows the next SemVer version without making any side effects.
- **Name:** `version`

## 2. Options Classes

The CLI uses the `build_cli` pattern.

### `GlobalOptions`
- `bool dryRun` - Show what would be done without executing.
- `bool verbose` - Show detailed command output.

### `ManageCicdOptions`
Combined CLI options for `manage_cicd.dart` entry point.
- `bool dryRun`
- `bool verbose`
- `String? prevTag` - Override previous tag detection.
- `String? version` - Override version (skip auto-detection).
- `bool outputGithubActions` - Write version outputs to `$GITHUB_OUTPUT`.
- `String? artifactsDir` - Directory containing downloaded CI artifacts.
- `String? repo` - GitHub repository slug `owner/repo`.
- `String? releaseTag` - Git tag for the release.
- `String? releaseUrl` - URL of the GitHub release page.
- `String? manifest` - Path to `issue_manifest.json`.

### Command-Specific Options
- `ArchiveRunOptions` - Options for `archive-run` command (`runDir`).
- `AutodocOptions` - Options for `autodoc` command (`init`, `force`, `module`).
- `CreateReleaseOptions` - Options for `create-release` command (`artifactsDir`, `repo`).
- `DetermineVersionOptions` - Options for `determine-version` command (`outputGithubActions`).
- `MergeAuditTrailsOptions` - Options for `merge-audit-trails` command (`incomingDir`, `outputDir`).
- `PostReleaseTriageOptions` - Options for `post-release-triage` command (`releaseTag`, `releaseUrl`, `manifest`).
- `TriageCliOptions` - Combined CLI options for the modular `triage_cli.dart`.
- `TriageOptions` - Options shared by triage subcommands (`force`).
- `UpdateOptions` - Options for `update` command (`force`, `templates`, `config`, `workflows`, `autodoc`, `backup`).
- `UpdateAllOptions` - Options for `update-all` command (`scanRoot`, `concurrency`, `force`, `workflows`, `templates`, `config`, `autodoc`, `backup`).
- `VersionOptions` - Version-related options (`prevTag`, `version`).

## 3. Utilities

### `CiProcessRunner`
Utilities for running external processes.
- `static bool commandExists(String command)`
- `static String runSync(String command, String workingDirectory, {bool verbose = false})`
- `static void exec(String executable, List<String> args, {String? cwd, bool fatal = false, bool verbose = false})`

### `FileUtils`
File system utilities for CI/CD operations.
- `static void copyDirRecursive(Directory src, Directory dst)`
- `static int countFiles(Directory dir)`
- `static String readFileOr(String path, [String fallback = '(not available)'])`

### `GeminiUtils`
Utilities for Gemini CLI integration.
- `static bool geminiAvailable({bool warnOnly = false})`
- `static void requireGeminiCli()`
- `static void requireApiKey()`
- `static String extractJson(String rawOutput)`

### `HookInstaller`
Installs and manages git pre-commit hooks for Dart repos.
- `static bool install(String repoRoot, {int lineLength = 120, bool dryRun = false})`

### `Logger`
ANSI-styled console logging for CI/CD commands.
- `static void header(String msg)`
- `static void info(String msg)`
- `static void success(String msg)`
- `static void warn(String msg)`
- `static void error(String msg)`

### `PromptResolver`
Resolves paths to prompt scripts.
- `static String promptScript(String scriptName)`
- `static String resolveToolingPackageRoot()`

### `ReleaseUtils`
Utilities for release management.
- `static String buildReleaseCommitMessage({required String repoRoot, required String version, required String prevTag, required Directory releaseDir, bool verbose = false})`
- `static List<Map<String, String>> gatherVerifiedContributors(String repoRoot, String prevTag)`
- `static String buildFallbackReleaseNotes(String repoRoot, String version, String prevTag)`
- `static void addChangelogReferenceLinks(String repoRoot, String content)`

### `RepoUtils`
Utilities for finding and working with the repository root.
- `static String? findRepoRoot()`

### `StepSummary`
Step summary utilities for GitHub Actions.
- `static void write(String markdown)`
- `static String artifactLink([String label = 'View all artifacts'])`
- `static String compareLink(String prevTag, String newTag, [String? label])`
- `static String ghLink(String label, String path)`
- `static String releaseLink(String tag)`
- `static String collapsible(String title, String content, {bool open = false})`

### `TemplateResolver`
Resolves paths within the `runtime_ci_tooling` package.
- `static String resolvePackageRoot()`
- `static String resolveTemplatesDir()`
- `static String resolveTemplatePath(String relativePath)`
- `static Map<String, dynamic> readManifest()`
- `static String resolveToolingVersion()`

### `TemplateVersionTracker` & `TemplateEntry`
Tracks which template versions a consumer repo has installed.
- `TemplateEntry({required String id, required String? source, required String destination, required String category, required String description})`
- `TemplateVersionTracker.load(String repoRoot)`
- `String? getInstalledHash(String templateId)`
- `String? getConsumerHash(String templateId)`
- `void recordUpdate(String templateId, {required String templateHash, required String consumerFileHash, required String toolingVersion})`
- `void save(String repoRoot)`

### `ToolInstallers`
Cross-platform tool installation utilities.
- `static Future<void> installTool(String tool, {bool dryRun = false})`
- `static Future<void> installNodeJs()`
- `static Future<void> installGeminiCli()`
- `static Future<void> installGitHubCli()`
- `static Future<void> installJq()`
- `static Future<void> installTree()`

### `VersionDetection`
Version detection and semantic versioning utilities.
- `static String detectPrevTag(String repoRoot, {bool verbose = false})`
- `static String detectNextVersion(String repoRoot, String prevTag, {bool verbose = false})`
- `static int compareVersions(String a, String b)`

### `WorkflowGenerator`
Renders CI workflow YAML from a Mustache skeleton template and config.json.
- `WorkflowGenerator({required this.ciConfig, required this.toolingVersion})`
- `static Map<String, dynamic>? loadCiConfig(String repoRoot)`
- `String render({String? existingContent})`
- `static List<String> validate(Map<String, dynamic> ciConfig)`
- `void logConfig()`

## 4. Triage Top-Level Functions

- `bool acquireTriageLock(bool force)`
- `String computeFileHash(String filePath)`
- `String createTriageRunDir(String repoRoot)`
- `String? findLatestManifest(String repoRoot)`
- `List<TriageDecision> loadCachedDecisions(String runDir)`
- `Map<int, List<InvestigationResult>> loadCachedResults(String runDir, GamePlan plan)`
- `void releaseTriageLock()`
- `void saveCheckpoint(String runDir, GamePlan plan, String lastPhase)`

## Examples

**Running a command programmatically:**

```dart
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';

void main() async {
  final runner = ManageCicdCli();
  await runner.run(['status', '--verbose']);
}
```

**Executing process utilities:**

```dart
import 'package:runtime_ci_tooling/src/cli/utils/process_runner.dart';

// Check if git is installed
if (CiProcessRunner.commandExists('git')) {
  // Run git status synchronously
  final output = CiProcessRunner.runSync('git status', '/path/to/repo', verbose: true);
  print(output);
}
```
