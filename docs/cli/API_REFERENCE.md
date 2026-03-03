# CI/CD CLI API Reference

This document provides a comprehensive API reference for the CI/CD CLI module.

## 1. Classes

### CLI Engine & Commands

**ManageCicdCli** -- CLI entry point for CI/CD Automation.
- **Methods:**
  - `Future<void> run(Iterable<String> args)`: Runs the command runner.
  - `static GlobalOptions parseGlobalOptions(ArgResults? results)`: Parses global options from ArgResults.
  - `static bool isVerbose(ArgResults? results)`: Returns true if verbose mode is enabled.
  - `static bool isDryRun(ArgResults? results)`: Returns true if dry-run mode is enabled.

**AnalyzeCommand** -- Run `dart analyze` on the root package and all configured sub-packages.

**ArchiveRunCommand** -- Archive a CI/CD run to `.runtime_ci/audit/vX.X.X/` for permanent storage.

**AuditAllCommand** -- Recursively audit all `pubspec.yaml` files under a directory against the package registry.

**AuditCommand** -- Audit a `pubspec.yaml` against the package registry for dependency issues.

**AutodocCommand** -- Generate/update documentation for proto modules using Gemini Pro.

**ComposeCommand** -- Run Stage 2 Changelog Composer (Gemini Pro).

**ConfigureMcpCommand** -- Set up MCP servers (GitHub, Sentry).

**ConsumersCommand** -- Discover runtime_ci_tooling consumers and sync latest release data.
- **Methods:**
  - `static int computeNextDiscoveryIndexFromNames(Iterable<String> fileNames)`: Computes the next discovery index.
  - `static String buildDiscoverySnapshotName({required int index, required DateTime localTime})`: Builds a discovery filename.
  - `static String resolveVersionFolderName(String tagName)`: Keeps release folder names aligned with tag names.
  - `static String snapshotIdentityFromPath(String path)`: Filename identity used for resume across workspaces.
  - `static bool isSnapshotSourceCompatible(...)`: Checks snapshot source compatibility.
  - `static bool isReleaseSummaryReusable(...)`: Checks if release summary is reusable.
  - `static String buildReleaseOutputPath(...)`: Returns the expected release output path.
  - `static String? selectTagFromReleaseList(...)`: Selects the latest matching tag.

**CreateReleaseCommand** -- Create git tag, GitHub Release, commit all changes.

**DetermineVersionCommand** -- Determine SemVer bump via Gemini + regex.

**DocumentationCommand** -- Run documentation update via Gemini 3 Pro Preview.

**ExploreCommand** -- Run Stage 1 Explorer Agent (Gemini 3 Pro Preview).

**InitCommand** -- Scan repo and generate `.runtime_ci/config.json` + `autodoc.json` + scaffold workflows.

**MergeAuditTrailsCommand** -- Merge CI/CD audit artifacts from multiple jobs.

**ReleaseCommand** -- Run the full local release pipeline.

**ReleaseNotesCommand** -- Run Stage 3 Release Notes Author (Gemini 3 Pro Preview).

**SetupCommand** -- Install all prerequisites (Node.js, Gemini CLI, gh, jq, tree).

**StatusCommand** -- Show current CI/CD configuration status.

**TestCommand** -- Run `dart test`.

**TriageCommand** -- Issue triage pipeline with AI-powered investigation.

**TriageAutoCommand** -- Auto-triage all untriaged open issues.

**TriageSingleCommand** -- Triage a single issue by number.
- **Methods:**
  - `static Future<void> runSingle(int issueNumber, ArgResults? globalResults)`: Shared logic for triaging a single issue.

**TriagePostReleaseCommand** -- Close loop after release.

**TriagePreReleaseCommand** -- Scan issues for upcoming release.

**TriageResumeCommand** -- Resume a previously interrupted triage run.

**TriageStatusCommand** -- Show triage pipeline status.

**UpdateAllCommand** -- Discover and update all `runtime_ci_tooling` packages under a root directory.

**UpdateCommand** -- Update templates, configs, and workflows from `runtime_ci_tooling`.

**ValidateCommand** -- Validate all configuration files.

**VerifyProtosCommand** -- Verify proto source and generated files exist.

**VersionCommand** -- Show the next SemVer version (no side effects).

=== CLI Options

**ArchiveRunOptions** -- CLI options for the `archive-run` command.
- **Fields:**
  - `String? runDir`: Directory containing the CI run to archive.
- **Constructors:**
  - `const ArchiveRunOptions({this.runDir})`
  - `factory ArchiveRunOptions.fromArgResults(ArgResults results)`

**AutodocOptions** -- CLI options for the `autodoc` command.
- **Fields:**
  - `bool init`: Scan repo and create initial autodoc.json.
  - `bool force`: Regenerate all docs regardless of hash.
  - `String? module`: Only generate for a specific module.
- **Constructors:**
  - `const AutodocOptions({this.init = false, this.force = false, this.module})`
  - `factory AutodocOptions.fromArgResults(ArgResults results)`

**CreateReleaseOptions** -- CLI options for the `create-release` command.
- **Fields:**
  - `String? artifactsDir`: Directory containing downloaded CI artifacts.
  - `String? repo`: GitHub repository slug (owner/repo).
- **Constructors:**
  - `const CreateReleaseOptions({this.artifactsDir, this.repo})`
  - `factory CreateReleaseOptions.fromArgResults(ArgResults results)`

**DetermineVersionOptions** -- CLI options for the `determine-version` command.
- **Fields:**
  - `bool outputGithubActions`: Write version outputs to `$GITHUB_OUTPUT`.
- **Constructors:**
  - `const DetermineVersionOptions({this.outputGithubActions = false})`
  - `factory DetermineVersionOptions.fromArgResults(ArgResults results)`

**GlobalOptions** -- Global CLI options available to all commands.
- **Fields:**
  - `bool dryRun`: Show what would be done without executing.
  - `bool verbose`: Show detailed command output.
- **Constructors:**
  - `const GlobalOptions({this.dryRun = false, this.verbose = false})`
  - `factory GlobalOptions.fromArgResults(ArgResults results)`

**ManageCicdOptions** -- Combined CLI options for the `manage_cicd` entry point.
- **Fields:**
  - `bool dryRun`, `bool verbose`, `String? prevTag`, `String? version`, `bool outputGithubActions`, `String? artifactsDir`, `String? repo`, `String? releaseTag`, `String? releaseUrl`, `String? manifest`.
- **Constructors:**
  - `const ManageCicdOptions(...)`

**MergeAuditTrailsOptions** -- CLI options for the `merge-audit-trails` command.
- **Fields:**
  - `String? incomingDir`: Directory containing incoming audit trail artifacts.
  - `String? outputDir`: Output directory for merged audit trails.
- **Constructors:**
  - `const MergeAuditTrailsOptions({this.incomingDir, this.outputDir})`
  - `factory MergeAuditTrailsOptions.fromArgResults(ArgResults results)`

**PostReleaseTriageOptions** -- CLI options for the `post-release-triage` command.
- **Fields:**
  - `String? releaseTag`: Git tag for the release.
  - `String? releaseUrl`: URL of the GitHub release page.
  - `String? manifest`: Path to issue_manifest.json.
- **Constructors:**
  - `const PostReleaseTriageOptions({this.releaseTag, this.releaseUrl, this.manifest})`
  - `factory PostReleaseTriageOptions.fromArgResults(ArgResults results)`

**TriageCliOptions** -- Combined CLI options for the `triage_cli` entry point.
- **Fields:**
  - `bool dryRun`, `bool verbose`, `bool auto`, `bool status`, `bool force`, `bool preRelease`, `bool postRelease`, `String? resume`, `String? prevTag`, `String? version`, `String? releaseTag`, `String? releaseUrl`, `String? manifest`.
- **Constructors:**
  - `const TriageCliOptions(...)`

**TriageOptions** -- CLI options shared by triage subcommands that acquire a lock.
- **Fields:**
  - `bool force`: Override an existing triage lock.
- **Constructors:**
  - `const TriageOptions({this.force = false})`
  - `factory TriageOptions.fromArgResults(ArgResults results)`

**UpdateAllOptions** -- CLI options for the `update-all` command.
- **Fields:**
  - `String? scanRoot`, `int concurrency`, `bool force`, `bool workflows`, `bool templates`, `bool config`, `bool autodoc`, `bool backup`.
- **Constructors:**
  - `const UpdateAllOptions(...)`
  - `factory UpdateAllOptions.fromArgResults(ArgResults results)`

**UpdateOptions** -- CLI options for the `update` command.
- **Fields:**
  - `bool force`, `bool templates`, `bool config`, `bool workflows`, `bool autodoc`, `bool backup`.
- **Constructors:**
  - `const UpdateOptions(...)`
  - `factory UpdateOptions.fromArgResults(ArgResults results)`

**VersionOptions** -- Version-related CLI options shared by multiple commands.
- **Fields:**
  - `String? prevTag`: Override previous tag detection.
  - `String? version`: Override version (skip auto-detection).
- **Constructors:**
  - `const VersionOptions({this.prevTag, this.version})`
  - `factory VersionOptions.fromArgResults(ArgResults results)`

### Audit Utilities

**AuditFinding** -- A single finding from auditing a pubspec dependency against the package registry.
- **Fields:**
  - `String pubspecPath`: Absolute path to the pubspec.yaml that was audited.
  - `String dependencyName`: The dependency name that triggered this finding.
  - `AuditSeverity severity`: How severe this finding is.
  - `AuditCategory category`: Which audit rule was violated.
  - `String message`: Human-readable description of the issue.
  - `String? currentValue`: The current value in the pubspec.
  - `String? expectedValue`: The expected value from the registry.
- **Constructors:**
  - `const AuditFinding(...)`

**RegistryEntry** -- A single entry from the external workspace packages registry.
- **Fields:**
  - `String githubOrg`, `String githubRepo`, `String version`, `String tagPattern`, `String localPath`, `String? packageName`, `String? gitPath`.
  - `String expectedGitUrl`: The expected SSH git URL for this package (getter).
- **Constructors:**
  - `const RegistryEntry(...)`

**PackageRegistry** -- Loads the external workspace packages YAML and provides O(1) lookup by dependency name.
- **Constructors:**
  - `factory PackageRegistry.load(String yamlPath)`
- **Methods:**
  - `static PackageRegistry? loadFromFile(String yamlPath)`
  - `static PackageRegistry? loadFromString(String yamlContent)`
  - `RegistryEntry? lookup(String packageName)`: Look up a registry entry by dependency name.
- **Fields/Getters:**
  - `Iterable<String> names`: All registered dependency names.
  - `Map<String, RegistryEntry> entries`: All entries as an unmodifiable map.
  - `int length`: Total number of unique entries.

**PubspecAuditor** -- Audits pubspec.yaml dependency declarations against a PackageRegistry.
- **Fields:**
  - `PackageRegistry registry`: The package registry to validate against.
- **Constructors:**
  - `const PubspecAuditor({required this.registry})`
- **Methods:**
  - `List<AuditFinding> auditPubspec(String pubspecPath)`: Audit a single pubspec.yaml file and return all findings.
  - `bool fixPubspec(String pubspecPath, List<AuditFinding> findings)`: Apply fixes for the given findings to the pubspec.

### Core Utilities

**FileUtils** -- File system utilities for CI/CD operations.
- **Methods:**
  - `static void copyDirRecursive(Directory src, Directory dst)`
  - `static int countFiles(Directory dir)`
  - `static String readFileOr(String path, [String fallback = "(not available)"])`

**GeminiPrerequisiteError** -- Exception thrown when Gemini CLI prerequisites are not met.
- **Fields:**
  - `String message`

**GeminiUtils** -- Utilities for Gemini CLI integration.
- **Methods:**
  - `static bool geminiAvailable({bool warnOnly = false})`
  - `static void requireGeminiCli()`
  - `static void requireApiKey()`
  - `static String extractJson(String rawOutput)`
  - `static String? extractJsonObject(String text)`

**HookInstaller** -- Installs and manages git pre-commit hooks for Dart repos.
- **Methods:**
  - `static bool install(String repoRoot, {int lineLength = 120, bool dryRun = false})`

**Logger** -- ANSI-styled console logging for CI/CD commands.
- **Methods:**
  - `static void header(String msg)`
  - `static void info(String msg)`
  - `static void success(String msg)`
  - `static void warn(String msg)`
  - `static void error(String msg)`

**CiProcessRunner** -- Utilities for running external processes.
- **Methods:**
  - `static bool commandExists(String command)`
  - `static String runSync(String command, String workingDirectory, {bool verbose = false})`
  - `static void exec(String executable, List<String> args, {String? cwd, bool fatal = false, bool verbose = false})`

**PromptResolver** -- Resolves paths to prompt scripts within the runtime_ci_tooling package.
- **Methods:**
  - `static String promptScript(String scriptName)`
  - `static String resolveToolingPackageRoot()`

**ReleaseUtils** -- Utilities for release management.
- **Methods:**
  - `static String buildReleaseCommitMessage(...)`
  - `static List<Map<String, String>> gatherVerifiedContributors(String repoRoot, String prevTag)`
  - `static String buildFallbackReleaseNotes(String repoRoot, String version, String prevTag)`
  - `static void addChangelogReferenceLinks(String repoRoot, String content)`

**RepoUtils** -- Utilities for finding and working with the required repository root.
- **Methods:**
  - `static String? findRepoRoot()`

**StepSummary** -- Step summary utilities for GitHub Actions.
- **Methods:**
  - `static void write(String markdown)`
  - `static String artifactLink([String label = "View all artifacts"])`
  - `static String compareLink(String prevTag, String newTag, [String? label])`
  - `static String ghLink(String label, String path)`
  - `static String releaseLink(String tag)`
  - `static String collapsible(String title, String content, {bool open = false})`

**SubPackageUtils** -- Utilities for loading and working with sub-packages defined in `.runtime_ci/config.json`.
- **Methods:**
  - `static List<Map<String, dynamic>> loadSubPackages(String repoRoot)`
  - `static String buildSubPackageDiffContext(...)`
  - `static String buildHierarchicalChangelogInstructions(...)`
  - `static String buildHierarchicalReleaseNotesInstructions(...)`
  - `static List<Map<String, dynamic>> enrichPromptWithSubPackages(...)`
  - `static int convertSiblingDepsForRelease(...)`
  - `static void logSubPackages(List<Map<String, dynamic>> subPackages)`

**TemplateEntry** -- Represents one template entry from manifest.json.
- **Fields:**
  - `String id`, `String? source`, `String destination`, `String category`, `String description`.
- **Constructors:**
  - `TemplateEntry({required this.id, required this.source, required this.destination, required this.category, required this.description})`
  - `factory TemplateEntry.fromJson(Map<String, dynamic> json)`

**TemplateVersionTracker** -- Tracks which template versions a consumer repo has installed.
- **Constructors:**
  - `factory TemplateVersionTracker.load(String repoRoot)`
- **Methods:**
  - `String? getInstalledHash(String templateId)`
  - `String? getConsumerHash(String templateId)`
  - `void recordUpdate(String templateId, {required String templateHash, required String consumerFileHash, required String toolingVersion})`
  - `void save(String repoRoot)`
- **Fields/Getters:**
  - `String? lastToolingVersion`

**TemplateResolver** -- Resolves paths within the runtime_ci_tooling package.
- **Methods:**
  - `static String resolvePackageRoot()`
  - `static String resolveTemplatesDir()`
  - `static String resolveTemplatePath(String relativePath)`
  - `static Map<String, dynamic> readManifest()`
  - `static String resolveToolingVersion()`

**ToolInstallers** -- Cross-platform tool installation utilities.
- **Methods:**
  - `static Future<void> installTool(String tool, {bool dryRun = false})`
  - `static Future<void> installNodeJs()`
  - `static Future<void> installGeminiCli()`
  - `static Future<void> installGitHubCli()`
  - `static Future<void> installJq()`
  - `static Future<void> installTree()`

**VersionDetection** -- Version detection and semantic versioning utilities.
- **Methods:**
  - `static String detectPrevTag(String repoRoot, {String? excludeTag, bool verbose = false})`
  - `static String detectNextVersion(String repoRoot, String prevTag, {bool verbose = false})`
  - `static int compareVersions(String a, String b)`

**WorkflowGenerator** -- Renders CI workflow YAML from a Mustache skeleton template and config.json.
- **Fields:**
  - `Map<String, dynamic> ciConfig`
  - `String toolingVersion`
- **Constructors:**
  - `WorkflowGenerator({required this.ciConfig, required this.toolingVersion})`
- **Methods:**
  - `static Map<String, dynamic>? loadCiConfig(String repoRoot)`
  - `String render({String? existingContent})`
  - `static List<String> validate(Map<String, dynamic> ciConfig)`
  - `void logConfig()`

## 2. Enums

**AuditSeverity** -- Severity of an audit finding.
- `error`: Error level severity.
- `warning`: Warning level severity.
- `info`: Information level severity.

**AuditCategory** -- Category of a pubspec audit issue.
- `bareDependency`: The dep is just `name: ^version` with no git source.
- `wrongOrg`: The git URL points to the wrong GitHub org.
- `wrongRepo`: The git URL points to the wrong repo name.
- `missingTagPattern`: Git dep doesn't have a `tag_pattern` field.
- `wrongTagPattern`: `tag_pattern` doesn't match the registry value.
- `staleVersion`: Version constraint doesn't match the registry version.
- `wrongUrlFormat`: Git URL isn't using SSH format (`git@github.com:org/repo.git`).

## 3. Extensions

**ArchiveRunOptionsArgParser** on **ArchiveRunOptions** -- Helper to populate the argument parser.
- **Methods:** `static void populateParser(ArgParser parser)`

**AutodocOptionsArgParser** on **AutodocOptions** -- Helper to populate the argument parser.
- **Methods:** `static void populateParser(ArgParser parser)`

**CreateReleaseOptionsArgParser** on **CreateReleaseOptions** -- Helper to populate the argument parser.
- **Methods:** `static void populateParser(ArgParser parser)`

**DetermineVersionOptionsArgParser** on **DetermineVersionOptions** -- Helper to populate the argument parser.
- **Methods:** `static void populateParser(ArgParser parser)`

**GlobalOptionsArgParser** on **GlobalOptions** -- Helper to populate the argument parser.
- **Methods:** `static void populateParser(ArgParser parser)`

**MergeAuditTrailsOptionsArgParser** on **MergeAuditTrailsOptions** -- Helper to populate the argument parser.
- **Methods:** `static void populateParser(ArgParser parser)`

**PostReleaseTriageOptionsArgParser** on **PostReleaseTriageOptions** -- Helper to populate the argument parser.
- **Methods:** `static void populateParser(ArgParser parser)`

**TriageOptionsArgParser** on **TriageOptions** -- Helper to populate the argument parser.
- **Methods:** `static void populateParser(ArgParser parser)`

**UpdateAllOptionsArgParser** on **UpdateAllOptions** -- Helper to populate the argument parser.
- **Methods:** `static void populateParser(ArgParser parser)`

**UpdateOptionsArgParser** on **UpdateOptions** -- Helper to populate the argument parser.
- **Methods:** `static void populateParser(ArgParser parser)`
- **Getters:** `bool updateAll`

**VersionOptionsArgParser** on **VersionOptions** -- Helper to populate the argument parser.
- **Methods:** `static void populateParser(ArgParser parser)`

## 4. Top-Level Functions

**scaffoldAutodocJson**
- `bool scaffoldAutodocJson(String repoRoot, {bool overwrite = false})`
- Scaffold `.runtime_ci/autodoc.json` by scanning `lib/src/` for modules.

**computeFileHash**
- `String computeFileHash(String filePath)`
- Compute SHA256 hash of a file's contents.

**acquireTriageLock**
- `bool acquireTriageLock(bool force)`
- Acquire a file-based lock. Returns true if acquired, false if another run is active.

**releaseTriageLock**
- `void releaseTriageLock()`
- Release the file-based lock.

**createTriageRunDir**
- `String createTriageRunDir(String repoRoot)`
- Create a unique run directory for this triage session.

**saveCheckpoint**
- `void saveCheckpoint(String runDir, GamePlan plan, String lastPhase)`
- Save a checkpoint so the run can be resumed later.

**loadCachedResults**
- `Map<int, List<InvestigationResult>> loadCachedResults(String runDir, GamePlan plan)`
- Load cached investigation results from a game plan.

**loadCachedDecisions**
- `List<TriageDecision> loadCachedDecisions(String runDir)`
- Load cached triage decisions from a run directory.

**findLatestManifest**
- `String? findLatestManifest(String repoRoot)`
- Search recent triage runs for the latest `issue_manifest.json`.