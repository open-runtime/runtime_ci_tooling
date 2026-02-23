# CI/CD CLI API Reference

This document provides a comprehensive reference for the CI/CD CLI module within `runtime_ci_tooling`. It covers the core command definitions, option parsers, utilities, and top-level functions used to build the CI/CD automation pipeline.

## 1. Commands

The CLI is built using the standard `args` package `Command` and `CommandRunner` architecture.

### `ManageCicdCli`
The root entry point for the CI/CD Automation CLI. Provides commands for managing the full CI/CD lifecycle locally and in CI.
- **Inherits:** `CommandRunner<void>`
- **Methods:**
  - `static parseGlobalOptions(ArgResults? results) -> GlobalOptions`: Parses global flags like `--verbose` and `--dry-run`.
  - `static isVerbose(ArgResults? results) -> bool`: Helper to check if verbose mode is enabled.
  - `static isDryRun(ArgResults? results) -> bool`: Helper to check if dry-run mode is enabled.

### Individual Commands
Each command extends `Command<void>` and overrides the `run()` method to perform its task.

- **`AnalyzeCommand`**: Runs `dart analyze` (failing on errors only).
- **`ArchiveRunCommand`**: Archives a CI/CD run to `.runtime_ci/audit/vX.X.X/` for permanent storage.
- **`AutodocCommand`**: Generates or updates module documentation using Gemini.
- **`ComposeCommand`**: Runs Stage 2 Changelog Composer (Gemini Pro).
- **`ConfigureMcpCommand`**: Sets up MCP servers (GitHub, Sentry) in `.gemini/settings.json`.
- **`ConsumersCommand`**: Discovers `runtime_ci_tooling` consumers and syncs latest release data.
  - *Utility Methods:* `computeNextDiscoveryIndexFromNames`, `buildDiscoverySnapshotName`, `resolveVersionFolderName`, `snapshotIdentityFromPath`, `isSnapshotSourceCompatible`, `isReleaseSummaryReusable`, `buildReleaseOutputPath`, `selectTagFromReleaseList`.
- **`CreateReleaseCommand`**: Creates a git tag, GitHub Release, and commits all changes.
- **`DetermineVersionCommand`**: Determines the SemVer bump via Gemini and regex heuristics. Output can be directed to `$GITHUB_OUTPUT`.
- **`DocumentationCommand`**: Runs documentation update via Gemini 3 Pro Preview.
- **`ExploreCommand`**: Runs Stage 1 Explorer Agent (Gemini 3 Pro Preview) to analyze commits, PRs, and breaking changes.
- **`InitCommand`**: Scans the repository and generates `.runtime_ci/config.json`, `autodoc.json`, and scaffolds workflows.
- **`MergeAuditTrailsCommand`**: Merges CI/CD audit artifacts from multiple jobs (used in CI).
- **`ReleaseCommand`**: Runs the full local release pipeline (version, explore, compose).
- **`ReleaseNotesCommand`**: Runs Stage 3 Release Notes Author (Gemini 3 Pro Preview) to generate rich release notes and migration guides.
- **`SetupCommand`**: Installs all prerequisites (`Node.js`, `Gemini CLI`, `gh`, `jq`, `tree`).
- **`StatusCommand`**: Shows the current CI/CD configuration status.
- **`TestCommand`**: Runs `dart test`.
- **`UpdateAllCommand`**: Discovers and updates all `runtime_ci_tooling` packages under a root directory.
- **`UpdateCommand`**: Updates templates, configs, and workflows from `runtime_ci_tooling`.
- **`ValidateCommand`**: Validates all configuration files (YAML, JSON, TOML, Dart prompts).
- **`VerifyProtosCommand`**: Verifies that proto source and generated Dart files exist.
- **`VersionCommand`**: Shows the next SemVer version without any side effects.

### Triage Subcommands
- **`TriageCommand`**: Issue triage pipeline with AI-powered investigation. Container for subcommands.
- **`TriageAutoCommand`**: Auto-triages all untriaged open issues.
- **`TriagePostReleaseCommand`**: Closes the loop after a release (requires `--version` and `--release-tag`).
- **`TriagePreReleaseCommand`**: Scans issues for an upcoming release (requires `--prev-tag` and `--version`).
- **`TriageResumeCommand`**: Resumes a previously interrupted triage run.
- **`TriageSingleCommand`**: Triages a single issue by number.
  - *Method:* `static runSingle(int issueNumber, ArgResults? globalResults) -> Future<void>`
- **`TriageStatusCommand`**: Shows triage pipeline status without running.

## 2. Options Classes

Option classes are annotated with `@CliOptions()` from `build_cli_annotations` to generate boilerplate argument parsing.

- **`ArchiveRunOptions`**: Options for `archive-run`. (e.g. `runDir`)
- **`AutodocOptions`**: Options for `autodoc`. (e.g. `init`, `force`, `module`)
- **`CreateReleaseOptions`**: Options for `create-release`. (e.g. `artifactsDir`, `repo`)
- **`DetermineVersionOptions`**: Options for `determine-version`. (e.g. `outputGithubActions`)
- **`GlobalOptions`**: Available to all commands. (e.g. `dryRun`, `verbose`)
- **`ManageCicdOptions`**: Combined CLI options for the `manage_cicd.dart` entry point.
- **`MergeAuditTrailsOptions`**: Options for `merge-audit-trails`. (e.g. `incomingDir`, `outputDir`)
- **`PostReleaseTriageOptions`**: Options for `post-release-triage`. (e.g. `releaseTag`, `releaseUrl`, `manifest`)
- **`TriageCliOptions`**: Combined CLI options for the `triage_cli.dart` entry point.
- **`TriageOptions`**: Shared options for triage commands that acquire a lock (e.g. `force`).
- **`UpdateAllOptions`**: Options for `update-all`. (e.g. `scanRoot`, `concurrency`, `force`, `backup`)
- **`UpdateOptions`**: Options for `update`. (e.g. `force`, `templates`, `config`, `workflows`, `autodoc`, `backup`)
- **`VersionOptions`**: Shared options for commands that work with release versions (e.g. `prevTag`, `version`).

*Note:* Each option class has a corresponding extension (e.g., `VersionOptionsArgParser`) with a `static void populateParser(ArgParser parser)` method.

## 3. Utilities

### `CiProcessRunner`
Utilities for running external processes.
- `static commandExists(String command) -> bool`
- `static runSync(String command, String workingDirectory, {bool verbose = false}) -> String`
- `static exec(String executable, List<String> args, {String? cwd, bool fatal = false, bool verbose = false}) -> void`

### `FileUtils`
File system utilities for CI/CD operations.
- `static copyDirRecursive(Directory src, Directory dst) -> void`
- `static countFiles(Directory dir) -> int`
- `static readFileOr(String path, [String fallback = "(not available)"]) -> String`

### `GeminiUtils`
Utilities for Gemini CLI integration.
- `static geminiAvailable({bool warnOnly = false}) -> bool`
- `static requireGeminiCli() -> void`
- `static requireApiKey() -> void`
- `static extractJson(String rawOutput) -> String`
- `static extractJsonObject(String text) -> String?`

### `HookInstaller`
Installs and manages git pre-commit hooks for Dart repos.
- `static install(String repoRoot, {int lineLength = 120, bool dryRun = false}) -> bool`

### `Logger`
ANSI-styled console logging for CI/CD commands.
- `static header(String msg) -> void`
- `static info(String msg) -> void`
- `static success(String msg) -> void`
- `static warn(String msg) -> void`
- `static error(String msg) -> void`

### `PromptResolver`
Resolves paths to prompt scripts within the `runtime_ci_tooling` package.
- `static promptScript(String scriptName) -> String`
- `static resolveToolingPackageRoot() -> String`

### `ReleaseUtils`
Utilities for release management.
- `static buildReleaseCommitMessage({...}) -> String`
- `static gatherVerifiedContributors(String repoRoot, String prevTag) -> List<Map<String, String>>`
- `static buildFallbackReleaseNotes(String repoRoot, String version, String prevTag) -> String`
- `static addChangelogReferenceLinks(String repoRoot, String content) -> void`

### `RepoUtils`
Utilities for finding the repository root.
- `static findRepoRoot() -> String?`

### `StepSummary`
Step summary utilities for GitHub Actions.
- `static write(String markdown) -> void`
- `static artifactLink([String label = "View all artifacts"]) -> String`
- `static compareLink(String prevTag, String newTag, [String? label]) -> String`
- `static ghLink(String label, String path) -> String`
- `static releaseLink(String tag) -> String`
- `static collapsible(String title, String content, {bool open = false}) -> String`

### `TemplateResolver`
Resolves paths within the `runtime_ci_tooling` package.
- `static resolvePackageRoot() -> String`
- `static resolveTemplatesDir() -> String`
- `static resolveTemplatePath(String relativePath) -> String`
- `static readManifest() -> Map<String, dynamic>`
- `static resolveToolingVersion() -> String`

### `TemplateVersionTracker`
Tracks which template versions a consumer repo has installed (stored in `.runtime_ci/template_versions.json`).
- `getInstalledHash(String templateId) -> String?`
- `getConsumerHash(String templateId) -> String?`
- `recordUpdate(...) -> void`
- `save(String repoRoot) -> void`

### `ToolInstallers`
Cross-platform tool installation utilities for required external binaries.
- `static installTool(String tool, {bool dryRun = false}) -> Future<void>`
- `static installNodeJs() -> Future<void>`
- `static installGeminiCli() -> Future<void>`
- `static installGitHubCli() -> Future<void>`
- `static installJq() -> Future<void>`
- `static installTree() -> Future<void>`

### `VersionDetection`
Version detection and semantic versioning utilities.
- `static detectPrevTag(String repoRoot, {bool verbose = false}) -> String`
- `static detectNextVersion(String repoRoot, String prevTag, {bool verbose = false}) -> String`
- `static compareVersions(String a, String b) -> int`

### `WorkflowGenerator`
Renders CI workflow YAML from a Mustache skeleton template and `config.json`.
- `static loadCiConfig(String repoRoot) -> Map<String, dynamic>?`
- `render({String? existingContent}) -> String`
- `static validate(Map<String, dynamic> ciConfig) -> List<String>`
- `logConfig() -> void`

## 4. Top-Level Functions & Constants

### Option Parsers (Generated)
- `ArchiveRunOptions parseArchiveRunOptions(List<String> args)`
- `AutodocOptions parseAutodocOptions(List<String> args)`
- `CreateReleaseOptions parseCreateReleaseOptions(List<String> args)`
- `DetermineVersionOptions parseDetermineVersionOptions(List<String> args)`
- `GlobalOptions parseGlobalOptions(List<String> args)`
- `ManageCicdOptions parseManageCicdOptions(List<String> args)`
- `MergeAuditTrailsOptions parseMergeAuditTrailsOptions(List<String> args)`
- `PostReleaseTriageOptions parsePostReleaseTriageOptions(List<String> args)`
- `TriageCliOptions parseTriageCliOptions(List<String> args)`
- `TriageOptions parseTriageOptions(List<String> args)`
- `UpdateAllOptions parseUpdateAllOptions(List<String> args)`
- `UpdateOptions parseUpdateOptions(List<String> args)`
- `VersionOptions parseVersionOptions(List<String> args)`

### Autodoc scaffolding
- `bool scaffoldAutodocJson(String repoRoot, {bool overwrite = false})`
- `String computeFileHash(String filePath)`

### Triage Utilities
- `bool acquireTriageLock(bool force)`
- `void releaseTriageLock()`
- `String createTriageRunDir(String repoRoot)`
- `void saveCheckpoint(String runDir, GamePlan plan, String lastPhase)`
- `Map<int, List<InvestigationResult>> loadCachedResults(String runDir, GamePlan plan)`
- `List<TriageDecision> loadCachedDecisions(String runDir)`
- `String? findLatestManifest(String repoRoot)`

### Constants
- **`kStagingDir`**: Staging directory for CI artifacts (e.g. `/tmp` in CI).
- **`kCiConfigFiles`**: List of expected config files in a repo using `runtime_ci_tooling`.
- **`kStage1Artifacts`**: Expected JSON artifacts from the explore phase.
- **`kLockFilePath`**: Lock file path preventing concurrent triage globally.
- **`kGeminiModel` / `kGeminiProModel`**: Default Gemini model names for different workflows.
