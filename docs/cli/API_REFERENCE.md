# CI/CD CLI API Reference

This document provides a comprehensive API reference for the `runtime_ci_tooling` CI/CD CLI module. The code handles tasks such as automated issue triage, documentation scaffolding, pubspec auditing, and changelog/release note generation using LLMs.

## 1. Classes

### Commands
These classes represent individual CLI commands for the CI/CD pipeline, extending `args`'s `Command<void>`.

*   **AnalyzeCommand** -- Run `dart analyze` on the root package and all configured sub-packages (fail on errors only).
*   **ArchiveRunCommand** -- Archive a CI/CD run to `.runtime_ci/audit/vX.X.X/` for permanent storage.
*   **AuditAllCommand** -- Recursively audit all `pubspec.yaml` files under a directory against the package registry.
*   **AuditCommand** -- Audit a `pubspec.yaml` against the package registry for dependency issues.
*   **AutodocCommand** -- Generate/update documentation for proto modules using Gemini Pro.
*   **ComposeCommand** -- Run Stage 2 Changelog Composer (Gemini Pro).
*   **ConfigureMcpCommand** -- Set up MCP servers (GitHub, Sentry) in `.gemini/settings.json`.
*   **ConsumersCommand** -- Discover `runtime_ci_tooling` consumers and sync latest release data.
    *   `static int computeNextDiscoveryIndexFromNames(Iterable<String> fileNames)` -- Computes the next discovery index.
    *   `static String buildDiscoverySnapshotName({required int index, required DateTime localTime})` -- Builds a discovery filename.
    *   `static String resolveVersionFolderName(String tagName)` -- Keeps release folder names aligned with tag names.
    *   `static String snapshotIdentityFromPath(String path)` -- Filename identity used for resume.
    *   `static bool isSnapshotSourceCompatible({required String? sourceSnapshotPath, required String? sourceSnapshotIdentity, required String expectedSnapshotPath})` -- Checks if source is compatible.
    *   `static bool isReleaseSummaryReusable({required String status, required String outputPath, required String? tag, required String? exactTag})`
    *   `static String buildReleaseOutputPath({required String outputDir, required String repoName, required String tagName})`
    *   `static String? selectTagFromReleaseList({required List<Map<String, dynamic>> releases, required bool includePrerelease, RegExp? tagPattern})`
*   **CreateReleaseCommand** -- Create git tag, GitHub Release, commit all changes.
*   **DetermineVersionCommand** -- Determine SemVer bump via Gemini + regex (CI: `--output-github-actions`).
*   **DocumentationCommand** -- Run documentation update via Gemini 3 Pro Preview.
*   **ExploreCommand** -- Run Stage 1 Explorer Agent (Gemini 3 Pro Preview) locally.
*   **InitCommand** -- Scan repo and generate `.runtime_ci/config.json`, `autodoc.json`, and scaffold workflows.
*   **MergeAuditTrailsCommand** -- Merge CI/CD audit artifacts from multiple jobs into a single run directory.
*   **ReleaseCommand** -- Run the full local release pipeline (version + explore + compose).
*   **ReleaseNotesCommand** -- Run Stage 3 Release Notes Author (Gemini 3 Pro Preview) to generate rich, narrative release notes.
*   **SetupCommand** -- Install all prerequisites (`Node.js`, `Gemini CLI`, `gh`, `jq`, `tree`) cross-platform.
*   **StatusCommand** -- Show current CI/CD configuration status.
*   **TestCommand** -- Run `dart test` on the root package and all configured sub-packages.
*   **TriageAutoCommand** -- Auto-triage all untriaged open issues.
*   **TriageCommand** -- Issue triage pipeline with AI-powered investigation (groups triage subcommands).
*   **TriagePostReleaseCommand** -- Close loop after release (requires `--version` and `--release-tag`).
*   **TriagePreReleaseCommand** -- Scan issues for upcoming release (requires `--prev-tag` and `--version`).
*   **TriageResumeCommand** -- Resume a previously interrupted triage run.
*   **TriageSingleCommand** -- Triage a single issue by number.
    *   `static Future<void> runSingle(int issueNumber, ArgResults? globalResults)` -- Shared logic for single issue triage execution.
*   **TriageStatusCommand** -- Show triage pipeline status without running.
*   **UpdateAllCommand** -- Discover and update all `runtime_ci_tooling` packages under a root directory.
*   **UpdateCommand** -- Update templates, configs, and workflows from `runtime_ci_tooling`.
*   **ValidateCommand** -- Validate all configuration files.
*   **VerifyProtosCommand** -- Verify proto source and generated files exist.
*   **VersionCommand** -- Show the next SemVer version (no side effects).

### CLI Runner
*   **ManageCicdCli** -- CLI entry point for CI/CD Automation.
    *   `Future<void> run(Iterable<String> args)` -- Intercepts and executes commands.
    *   `static GlobalOptions parseGlobalOptions(ArgResults? results)` -- Parses global options.
    *   `static bool isVerbose(ArgResults? results)` -- Returns true if verbose mode is enabled.
    *   `static bool isDryRun(ArgResults? results)` -- Returns true if dry-run mode is enabled.

### Options
These classes represent parsed CLI arguments. Most include a `fromArgResults` factory and can be used in cascading style when created manually (though typically hydrated by `build_cli`).

*   **ArchiveRunOptions** -- Options for `archive-run`.
    *   `String? runDir` -- Directory containing the CI run to archive.
*   **AutodocOptions** -- Options for `autodoc`.
    *   `bool init` -- Scan repo and create initial autodoc.json.
    *   `bool force` -- Regenerate all docs regardless of hash.
    *   `String? module` -- Only generate for a specific module.
*   **CreateReleaseOptions** -- Options for `create-release`.
    *   `String? artifactsDir` -- Directory containing downloaded CI artifacts.
    *   `String? repo` -- GitHub repository slug owner/repo.
*   **DetermineVersionOptions** -- Options for `determine-version`.
    *   `bool outputGithubActions` -- Write version outputs to `$GITHUB_OUTPUT`.
*   **GlobalOptions** -- Options available to all commands.
    *   `bool dryRun` -- Show what would be done without executing.
    *   `bool verbose` -- Show detailed command output.
*   **ManageCicdOptions** -- Combined options for the `manage_cicd` entry point.
    *   *Includes fields for all above commands* (`dryRun`, `verbose`, `prevTag`, `version`, `outputGithubActions`, `artifactsDir`, `repo`, `releaseTag`, `releaseUrl`, `manifest`).
*   **MergeAuditTrailsOptions** -- Options for `merge-audit-trails`.
    *   `String? incomingDir` -- Directory containing incoming audit trail artifacts.
    *   `String? outputDir` -- Output directory for merged audit trails.
*   **PostReleaseTriageOptions** -- Options for `post-release-triage`.
    *   `String? releaseTag` -- Git tag for the release.
    *   `String? releaseUrl` -- URL of the GitHub release page.
    *   `String? manifest` -- Path to `issue_manifest.json`.
*   **TriageCliOptions** -- Combined options for the `triage_cli.dart` entry point.
    *   *Includes fields for triage operations* (`auto`, `status`, `force`, `preRelease`, `postRelease`, `resume`, `prevTag`, `version`, `releaseTag`, `releaseUrl`, `manifest`).
*   **TriageOptions** -- Shared options for triage commands.
    *   `bool force` -- Override an existing triage lock.
*   **UpdateAllOptions** -- Options for `update-all`.
    *   `String? scanRoot` -- Root directory to scan for packages.
    *   `int concurrency` -- Max concurrent update processes.
    *   `bool force`, `bool workflows`, `bool templates`, `bool config`, `bool autodoc`, `bool backup`.
*   **UpdateOptions** -- Options for `update`.
    *   `bool force`, `bool templates`, `bool config`, `bool workflows`, `bool autodoc`, `bool backup`.
    *   `bool get updateAll` -- Returns true if no specific filter flags are set.
*   **VersionOptions** -- Options for version-related commands.
    *   `String? prevTag` -- Override previous tag detection.
    *   `String? version` -- Override version (skip auto-detection).

### Audit Utilities
*   **AuditFinding** -- A single finding from auditing a pubspec dependency against the package registry.
    *   `String pubspecPath` -- Absolute path to the pubspec.yaml.
    *   `String dependencyName` -- The dependency name that triggered this finding.
    *   `AuditSeverity severity` -- How severe this finding is.
    *   `AuditCategory category` -- Which audit rule was violated.
    *   `String message` -- Human-readable description of the issue.
    *   `String? currentValue`, `String? expectedValue`.
*   **PackageRegistry** -- Loads external workspace packages YAML and provides O(1) lookup.
    *   *Factory constructors*: `PackageRegistry.load(String yamlPath)`.
    *   `static PackageRegistry? loadFromFile(String yamlPath)` -- Load from file.
    *   `static PackageRegistry? loadFromString(String yamlContent)` -- Load from raw YAML.
    *   `RegistryEntry? lookup(String packageName)` -- Look up a registry entry by dependency name.
    *   `Iterable<String> get names` -- All registered dependency names.
    *   `Map<String, RegistryEntry> get entries` -- All entries as an unmodifiable map.
    *   `int get length` -- Total number of unique entries.
*   **RegistryEntry** -- A single entry from the external workspace packages registry.
    *   `String githubOrg`, `String githubRepo`, `String version`, `String tagPattern`, `String localPath`.
    *   `String? packageName`, `String? gitPath`.
    *   `String get expectedGitUrl` -- The expected SSH git URL for this package.
*   **PubspecAuditor** -- Audits pubspec.yaml dependency declarations against a `PackageRegistry`.
    *   *Constructor*: `PubspecAuditor({required this.registry})`.
    *   `List<AuditFinding> auditPubspec(String pubspecPath)` -- Audit a single pubspec.yaml file and return all findings.
    *   `bool fixPubspec(String pubspecPath, List<AuditFinding> findings)` -- Apply fixes for the given findings.

### Tooling Utilities
*   **CiProcessRunner** -- Utilities for running external processes.
    *   `static bool commandExists(String command)` -- Check whether a command is available on PATH.
    *   `static String runSync(String command, String workingDirectory, {bool verbose = false})` -- Run shell command synchronously and return trimmed stdout.
    *   `static void exec(String executable, List<String> args, {String? cwd, bool fatal = false, bool verbose = false})` -- Execute a command, exiting on failure if fatal is true.
*   **FileUtils** -- File system utilities.
    *   `static void copyDirRecursive(Directory src, Directory dst)` -- Recursively copy a directory tree.
    *   `static int countFiles(Directory dir)` -- Count all files in a directory tree.
    *   `static String readFileOr(String path, [String fallback = '(not available)'])` -- Read file and return its content, or fallback.
*   **GeminiUtils** -- Utilities for Gemini CLI integration.
    *   `static bool geminiAvailable({bool warnOnly = false})` -- Check if Gemini CLI and API key are available.
    *   `static void requireGeminiCli()` -- Throws if Gemini CLI is not installed.
    *   `static void requireApiKey()` -- Throws if API key is not set.
    *   `static String extractJson(String rawOutput)` -- Extract the first balanced JSON object from raw output.
    *   `static String? extractJsonObject(String text)` -- Nullable variant of JSON extraction.
*   **GeminiPrerequisiteError** -- Exception thrown when Gemini CLI prerequisites are not met.
    *   `String message` -- Error details.
*   **HookInstaller** -- Installs and manages git pre-commit hooks for Dart repos.
    *   `static bool install(String repoRoot, {int lineLength = 120, bool dryRun = false})` -- Installs or refreshes the pre-commit hook.
*   **Logger** -- ANSI-styled console logging.
    *   `static void header(String msg)`, `static void info(String msg)`, `static void success(String msg)`, `static void warn(String msg)`, `static void error(String msg)`.
*   **PromptResolver** -- Resolves paths to prompt scripts.
    *   `static String promptScript(String scriptName)` -- Resolves absolute path to a prompt script.
    *   `static String resolveToolingPackageRoot()` -- Finds the runtime_ci_tooling package root.
*   **ReleaseUtils** -- Utilities for release management.
    *   `static String buildReleaseCommitMessage({required String repoRoot, required String version, required String prevTag, required Directory releaseDir, bool verbose = false})`
    *   `static List<Map<String, String>> gatherVerifiedContributors(String repoRoot, String prevTag)`
    *   `static String buildFallbackReleaseNotes(String repoRoot, String version, String prevTag)`
    *   `static void addChangelogReferenceLinks(String repoRoot, String content)`
*   **RepoUtils** -- Repository utilities.
    *   `static String? findRepoRoot()` -- Find repository root by walking up from CWD.
*   **StepSummary** -- Step summary utilities for GitHub Actions.
    *   `static void write(String markdown)` -- Write markdown to `$GITHUB_STEP_SUMMARY`.
    *   `static String artifactLink([String label])`, `static String compareLink(String prevTag, String newTag, [String? label])`, `static String ghLink(String label, String path)`, `static String releaseLink(String tag)`, `static String collapsible(String title, String content, {bool open = false})`.
*   **SubPackageUtils** -- Utilities for loading sub-packages from `config.json`.
    *   `static List<Map<String, dynamic>> loadSubPackages(String repoRoot)`
    *   `static String buildSubPackageDiffContext({required String repoRoot, required String prevTag, required List<Map<String, dynamic>> subPackages, bool verbose = false})`
    *   `static String buildHierarchicalChangelogInstructions({required String newVersion, required List<Map<String, dynamic>> subPackages})`
    *   `static String buildHierarchicalReleaseNotesInstructions({required String newVersion, required List<Map<String, dynamic>> subPackages})`
    *   `static List<Map<String, dynamic>> enrichPromptWithSubPackages({required String repoRoot, required String prevTag, required String promptFilePath, required String Function(...) buildInstructions, required String newVersion, bool verbose = false})`
    *   `static int convertSiblingDepsForRelease({required String repoRoot, required String newVersion, required String effectiveRepo, required List<Map<String, dynamic>> subPackages, bool verbose = false})`
    *   `static void logSubPackages(List<Map<String, dynamic>> subPackages)`
*   **TemplateEntry** -- Represents one template entry from `manifest.json`.
    *   `String id`, `String? source`, `String destination`, `String category`, `String description`.
    *   *Factory*: `TemplateEntry.fromJson(Map<String, dynamic> json)`.
*   **TemplateVersionTracker** -- Tracks which template versions a consumer repo has installed.
    *   `String? get lastToolingVersion`
    *   *Factory*: `TemplateVersionTracker.load(String repoRoot)`
    *   `String? getInstalledHash(String templateId)`
    *   `String? getConsumerHash(String templateId)`
    *   `void recordUpdate(String templateId, {required String templateHash, required String consumerFileHash, required String toolingVersion})`
    *   `void save(String repoRoot)`
*   **TemplateResolver** -- Resolves paths within the package templates.
    *   `static String resolvePackageRoot()`
    *   `static String resolveTemplatesDir()`
    *   `static String resolveTemplatePath(String relativePath)`
    *   `static Map<String, dynamic> readManifest()`
    *   `static String resolveToolingVersion()`
*   **ToolInstallers** -- Cross-platform tool installation utilities.
    *   `static Future<void> installTool(String tool, {bool dryRun = false})`
    *   `static Future<void> installNodeJs()`, `installGeminiCli()`, `installGitHubCli()`, `installJq()`, `installTree()`.
*   **VersionDetection** -- Version detection logic.
    *   `static String detectPrevTag(String repoRoot, {String? excludeTag, bool verbose = false})`
    *   `static String detectNextVersion(String repoRoot, String prevTag, {bool verbose = false})`
    *   `static int compareVersions(String a, String b)`
*   **WorkflowGenerator** -- Renders CI workflow YAML from Mustache skeletons.
    *   *Constructor*: `WorkflowGenerator({required this.ciConfig, required this.toolingVersion})`.
    *   `Map<String, dynamic> ciConfig`, `String toolingVersion`.
    *   `static Map<String, dynamic>? loadCiConfig(String repoRoot)`
    *   `String render({String? existingContent})`
    *   `static List<String> validate(Map<String, dynamic> ciConfig)`
    *   `void logConfig()`

## 2. Enums

*   **AuditSeverity** -- Severity of an audit finding.
    *   `error`
    *   `warning`
    *   `info`
*   **AuditCategory** -- Category of a pubspec audit issue.
    *   `bareDependency` -- Plain version string with no git source.
    *   `wrongOrg` -- Git URL points to wrong GitHub org.
    *   `wrongRepo` -- Git URL points to wrong repo name.
    *   `missingTagPattern` -- No `tag_pattern` in git block.
    *   `wrongTagPattern` -- `tag_pattern` differs from registry.
    *   `staleVersion` -- Version constraint differs from registry.
    *   `wrongUrlFormat` -- Git URL isn't using SSH format.

## 3. Extensions

*   **ArchiveRunOptionsArgParser** on `ArchiveRunOptions`
    *   `static void populateParser(ArgParser parser)` -- Populates argument parser with options.
*   **AutodocOptionsArgParser** on `AutodocOptions`
    *   `static void populateParser(ArgParser parser)`
*   **CreateReleaseOptionsArgParser** on `CreateReleaseOptions`
    *   `static void populateParser(ArgParser parser)`
*   **DetermineVersionOptionsArgParser** on `DetermineVersionOptions`
    *   `static void populateParser(ArgParser parser)`
*   **GlobalOptionsArgParser** on `GlobalOptions`
    *   `static void populateParser(ArgParser parser)`
*   **MergeAuditTrailsOptionsArgParser** on `MergeAuditTrailsOptions`
    *   `static void populateParser(ArgParser parser)`
*   **PostReleaseTriageOptionsArgParser** on `PostReleaseTriageOptions`
    *   `static void populateParser(ArgParser parser)`
*   **TriageOptionsArgParser** on `TriageOptions`
    *   `static void populateParser(ArgParser parser)`
*   **UpdateAllOptionsArgParser** on `UpdateAllOptions`
    *   `static void populateParser(ArgParser parser)`
*   **UpdateOptionsArgParser** on `UpdateOptions`
    *   `static void populateParser(ArgParser parser)`
*   **VersionOptionsArgParser** on `VersionOptions`
    *   `static void populateParser(ArgParser parser)`

## 4. Top-Level Functions

*   `bool scaffoldAutodocJson(String repoRoot, {bool overwrite = false})` -- Scaffold `.runtime_ci/autodoc.json` by scanning `lib/src/` for modules.
*   `String computeFileHash(String filePath)` -- Compute SHA256 hash of a file's contents natively.
*   `bool acquireTriageLock(bool force)` -- Acquire a file-based lock. Returns true if acquired.
*   `void releaseTriageLock()` -- Release the file-based triage lock.
*   `String createTriageRunDir(String repoRoot)` -- Create a unique run directory for the triage session.
*   `void saveCheckpoint(String runDir, GamePlan plan, String lastPhase)` -- Save a checkpoint so the run can be resumed.
*   `Map<int, List<InvestigationResult>> loadCachedResults(String runDir, GamePlan plan)` -- Load cached investigation results.
*   `List<TriageDecision> loadCachedDecisions(String runDir)` -- Load cached triage decisions from a run directory.
*   `String? findLatestManifest(String repoRoot)` -- Search recent triage runs for the latest `issue_manifest.json`.

## 5. Constants

*   `String kStagingDir` -- Staging directory for CI artifacts (e.g., `/tmp`).
*   `List<String> kCiConfigFiles` -- Configuration files expected in a repo using runtime_ci_tooling.
*   `List<String> kStage1Artifacts` -- Stage 1 JSON artifacts produced by the explore phase.
*   `String kLockFilePath` -- Path to the triage lock file (prevents concurrent triage).

*(Parse helper functions generated by `build_cli` are also available globally for parsing string argument lists, e.g. `parseArchiveRunOptions(List<String> args)`, `parseGlobalOptions(List<String> args)`, etc.)*

## 6. Code Examples

### Loading and Auditing a Package Registry
```dart
import 'package:runtime_ci_tooling/src/cli/utils/audit/package_registry.dart';
import 'package:runtime_ci_tooling/src/cli/utils/audit/pubspec_auditor.dart';

void runAudit() {
  // Load registry from file
  final registry = PackageRegistry.load('configs/external_workspace_packages.yaml');

  // Initialize auditor with registry
  final auditor = PubspecAuditor(registry: registry);

  // Run audit against a specific pubspec.yaml
  final findings = auditor.auditPubspec('lib/pubspec.yaml');
  
  if (findings.isEmpty) {
    print('All dependencies are valid!');
  } else {
    for (final finding in findings) {
      print('${finding.severity}: ${finding.message} for ${finding.dependencyName}');
    }
  }
}
```

### Safely Extracting JSON from LLM Output
```dart
import 'package:runtime_ci_tooling/src/cli/utils/gemini_utils.dart';

void parseAgentResponse(String llmOutput) {
  try {
    // extractJson handles markdown code blocks and conversational text
    final jsonStr = GeminiUtils.extractJson(llmOutput);
    print('Extracted valid JSON: $jsonStr');
  } catch (e) {
    print('Failed to extract JSON: $e');
  }
}
```
