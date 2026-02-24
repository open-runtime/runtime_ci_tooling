# API Reference: CI/CD CLI Module

The CLI module provides cross-platform tooling for managing AI-powered release pipelines locally and in CI.

## 1. Classes

### Command Classes

Commands are implemented by extending `Command<void>` from the `args` package.

* **AnalyzeCommand**
  * `String name = 'analyze'`
  * `String description = 'Run dart analyze (fail on errors only).'`
  * `Future<void> run()`: Executes `dart analyze --no-fatal-warnings`.

* **ArchiveRunCommand**
  * `String name = 'archive-run'`
  * `String description = 'Archive .runtime_ci/runs/ to .runtime_ci/audit/vX.X.X/ for permanent storage.'`
  * `Future<void> run()`: Moves the specified run directory to the audit trail.

* **AutodocCommand**
  * `String name = 'autodoc'`
  * `String description = 'Generate/update module docs (--init, --force, --module, --dry-run).'`
  * `Future<void> run()`: Uses Gemini to generate documentation based on `autodoc.json`.

* **ComposeCommand**
  * `String name = 'compose'`
  * `String description = 'Run Stage 2 Changelog Composer (Gemini Pro).'`
  * `Future<void> run()`: Updates `CHANGELOG.md` based on PRs and commits.

* **ConfigureMcpCommand**
  * `String name = 'configure-mcp'`
  * `String description = 'Set up MCP servers (GitHub, Sentry).'`
  * `Future<void> run()`: Injects MCP server configuration into `.gemini/settings.json`.

* **ConsumersCommand**
  * `String name = 'consumers'`
  * `String description = 'Discover runtime_ci_tooling consumers and sync latest release data.'`
  * `static int computeNextDiscoveryIndexFromNames(Iterable<String> fileNames)`
  * `static String buildDiscoverySnapshotName({required int index, required DateTime localTime})`
  * `static String resolveVersionFolderName(String tagName)`
  * `static String snapshotIdentityFromPath(String path)`
  * `static bool isSnapshotSourceCompatible({required String? sourceSnapshotPath, required String? sourceSnapshotIdentity, required String expectedSnapshotPath})`
  * `static bool isReleaseSummaryReusable({required String status, required String outputPath, required String? tag, required String? exactTag})`
  * `static String buildReleaseOutputPath({required String outputDir, required String repoName, required String tagName})`
  * `static String? selectTagFromReleaseList({required List<Map<String, dynamic>> releases, required bool includePrerelease, RegExp? tagPattern})`
  * `Future<void> run()`

* **CreateReleaseCommand**
  * `String name = 'create-release'`
  * `String description = 'Create git tag, GitHub Release, commit all changes.'`
  * `Future<void> run()`

* **DetermineVersionCommand**
  * `String name = 'determine-version'`
  * `String description = 'Determine SemVer bump via Gemini + regex (CI: --output-github-actions).'`
  * `Future<void> run()`

* **DocumentationCommand**
  * `String name = 'documentation'`
  * `String description = 'Run documentation update via Gemini 3 Pro Preview.'`
  * `Future<void> run()`

* **ExploreCommand**
  * `String name = 'explore'`
  * `String description = 'Run Stage 1 Explorer Agent (Gemini 3 Pro Preview).'`
  * `Future<void> run()`

* **InitCommand**
  * `String name = 'init'`
  * `String description = 'Scan repo and generate .runtime_ci/config.json + autodoc.json + scaffold workflows.'`
  * `Future<void> run()`

* **MergeAuditTrailsCommand**
  * `String name = 'merge-audit-trails'`
  * `String description = 'Merge CI/CD audit artifacts from multiple jobs (CI use).'`
  * `Future<void> run()`

* **ReleaseCommand**
  * `String name = 'release'`
  * `String description = 'Run the full local release pipeline.'`
  * `Future<void> run()`

* **ReleaseNotesCommand**
  * `String name = 'release-notes'`
  * `String description = 'Run Stage 3 Release Notes Author (Gemini 3 Pro Preview).'`
  * `Future<void> run()`

* **SetupCommand**
  * `String name = 'setup'`
  * `String description = 'Install all prerequisites (Node.js, Gemini CLI, gh, jq, tree).'`
  * `Future<void> run()`

* **StatusCommand**
  * `String name = 'status'`
  * `String description = 'Show current CI/CD configuration status.'`
  * `Future<void> run()`

* **TestCommand**
  * `String name = 'test'`
  * `String description = 'Run dart test.'`
  * `Future<void> run()`

* **TriageCommand** Group and Subcommands:
  * **TriageCommand**: `String name = 'triage'`
  * **TriageAutoCommand**: `String name = 'auto'`
  * **TriagePostReleaseCommand**: `String name = 'post-release'`
  * **TriagePreReleaseCommand**: `String name = 'pre-release'`
  * **TriageResumeCommand**: `String name = 'resume'`
  * **TriageSingleCommand**: `String name = 'single'`
  * **TriageStatusCommand**: `String name = 'status'`

* **UpdateAllCommand**
  * `String name = 'update-all'`
  * `String description = 'Discover and update all runtime_ci_tooling packages under a root directory.'`
  * `Future<void> run()`

* **UpdateCommand**
  * `String name = 'update'`
  * `String description = 'Update templates, configs, and workflows from runtime_ci_tooling.'`
  * `Future<void> run()`

* **ValidateCommand**
  * `String name = 'validate'`
  * `String description = 'Validate all configuration files.'`
  * `Future<void> run()`

* **VerifyProtosCommand**
  * `String name = 'verify-protos'`
  * `String description = 'Verify proto source and generated files exist.'`
  * `Future<void> run()`

* **VersionCommand**
  * `String name = 'version'`
  * `String description = 'Show the next SemVer version (no side effects).'`
  * `Future<void> run()`

### Utility Classes

* **FileUtils**
  * `static void copyDirRecursive(Directory src, Directory dst)`
  * `static int countFiles(Directory dir)`
  * `static String readFileOr(String path, [String fallback = '(not available)'])`

* **GeminiUtils**
  * `static bool geminiAvailable({bool warnOnly = false})`
  * `static void requireGeminiCli()`
  * `static void requireApiKey()`
  * `static String extractJson(String rawOutput)`
  * `static String? extractJsonObject(String text)`

* **HookInstaller**
  * `static bool install(String repoRoot, {int lineLength = 120, bool dryRun = false})`

* **Logger**
  * ANSI-styled console logging: `header(String)`, `info(String)`, `success(String)`, `warn(String)`, `error(String)`.

* **CiProcessRunner**
  * `static bool commandExists(String command)`
  * `static String runSync(String command, String workingDirectory, {bool verbose = false})`
  * `static void exec(String executable, List<String> args, {String? cwd, bool fatal = false, bool verbose = false})`

* **PromptResolver**
  * `static String promptScript(String scriptName)`
  * `static String resolveToolingPackageRoot()`

* **ReleaseUtils**
  * `static String buildReleaseCommitMessage({required String repoRoot, required String version, required String prevTag, required Directory releaseDir, bool verbose = false})`
  * `static List<Map<String, String>> gatherVerifiedContributors(String repoRoot, String prevTag)`
  * `static String buildFallbackReleaseNotes(String repoRoot, String version, String prevTag)`
  * `static void addChangelogReferenceLinks(String repoRoot, String content)`

* **RepoUtils**
  * `static String? findRepoRoot()`

* **StepSummary**
  * `static void write(String markdown)`
  * `static String artifactLink([String label = 'View all artifacts'])`
  * `static String compareLink(String prevTag, String newTag, [String? label])`
  * `static String ghLink(String label, String path)`
  * `static String releaseLink(String tag)`
  * `static String collapsible(String title, String content, {bool open = false})`

* **TemplateVersionTracker**
  * `factory TemplateVersionTracker.load(String repoRoot)`
  * `String? get lastToolingVersion`
  * `String? getInstalledHash(String templateId)`
  * `String? getConsumerHash(String templateId)`
  * `void recordUpdate(...)`
  * `void save(String repoRoot)`

* **WorkflowGenerator**
  * `Map<String, dynamic> ciConfig`
  * `String toolingVersion`
  * `static Map<String, dynamic>? loadCiConfig(String repoRoot)`
  * `String render({String? existingContent})`
  * `static List<String> validate(Map<String, dynamic> ciConfig)`

## 2. Options Classes

Options classes are automatically generated via `build_cli`.

* **ManageCicdOptions**: Combined options for the main CLI.
* **GlobalOptions**: Provides `dryRun` and `verbose` flags.
* **VersionOptions**: Provides `prevTag` and `version` parameters.
* **ArchiveRunOptions**: `runDir`
* **AutodocOptions**: `init`, `force`, `module`
* **CreateReleaseOptions**: `artifactsDir`, `repo`
* **DetermineVersionOptions**: `outputGithubActions`
* **MergeAuditTrailsOptions**: `incomingDir`, `outputDir`
* **PostReleaseTriageOptions**: `releaseTag`, `releaseUrl`, `manifest`
* **TriageCliOptions**: Combined triage options.
* **TriageOptions**: `force`
* **UpdateAllOptions**: `scanRoot`, `concurrency`, `force`, `workflows`, `templates`, `config`, `autodoc`, `backup`
* **UpdateOptions**: `force`, `templates`, `config`, `workflows`, `autodoc`, `backup`

## 3. Top-Level Functions

* `bool scaffoldAutodocJson(String repoRoot, {bool overwrite = false})`
* `bool acquireTriageLock(bool force)`
* `void releaseTriageLock()`
* `String createTriageRunDir(String repoRoot)`
* `void saveCheckpoint(String runDir, GamePlan plan, String lastPhase)`
* `Map<int, List<InvestigationResult>> loadCachedResults(String runDir, GamePlan plan)`
* `List<TriageDecision> loadCachedDecisions(String runDir)`
* `String? findLatestManifest(String repoRoot)`
* `String computeFileHash(String filePath)`
