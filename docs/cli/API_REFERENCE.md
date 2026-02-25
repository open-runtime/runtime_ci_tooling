# CI/CD CLI API Reference

This module provides the primary `CommandRunner` and associated commands for the CI/CD automation CLI used by the runtime team.

## 1. CLI Entry Point

### `ManageCicdCli`
CLI entry point for CI/CD Automation. Provides commands for managing the full CI/CD lifecycle.

**Example Usage:**
```dart
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';
import 'package:runtime_ci_tooling/src/cli/options/global_options.dart';

void main(List<String> args) async {
  final runner = ManageCicdCli();
  
  // Example of using parsed global options
  // GlobalOptions globalOpts = ManageCicdCli.parseGlobalOptions(runner.argParser.parse(args));
  
  await runner.run(args);
}
```

- `run(Iterable<String> args)`: `Future<void>` - Intercepts and executes commands. Automatically rewrites `triage <number>` to `triage single <number>`.
- `parseGlobalOptions(ArgResults? results)`: `static GlobalOptions` - Parse global options from `ArgResults`.
- `isVerbose(ArgResults? results)`: `static bool` - Returns `true` if verbose mode is enabled.
- `isDryRun(ArgResults? results)`: `static bool` - Returns `true` if dry-run mode is enabled.

---

## 2. Command Classes

All commands extend `Command<void>` from the `args` package. 

### Core Commands
- **AnalyzeCommand**
  - `name`: `'analyze'`
  - `description`: 'Run dart analyze (fail on errors only).'
  - `run()`: Runs dart analyze on the root package and all configured sub-packages.

- **ArchiveRunCommand**
  - `name`: `'archive-run'`
  - `description`: 'Archive .runtime_ci/runs/ to .runtime_ci/audit/vX.X.X/ for permanent storage.'

- **AuditAllCommand** / **AuditCommand**
  - Audits `pubspec.yaml` files against the package registry for dependency issues. Supports `--fix`.

- **AutodocCommand**
  - `name`: `'autodoc'`
  - `description`: 'Generate/update module docs (--init, --force, --module, --dry-run).'

- **ComposeCommand**
  - `name`: `'compose'`
  - `description`: 'Run Stage 2 Changelog Composer (Gemini Pro).'

- **ConfigureMcpCommand**
  - `name`: `'configure-mcp'`
  - `description`: 'Set up MCP servers (GitHub, Sentry).'

- **ConsumersCommand**
  - `name`: `'consumers'`
  - `description`: 'Discover runtime_ci_tooling consumers and sync latest release data.'
  - `computeNextDiscoveryIndexFromNames(Iterable<String> fileNames)`: `static int`
  - `buildDiscoverySnapshotName({required int index, required DateTime localTime})`: `static String`
  - `resolveVersionFolderName(String tagName)`: `static String`
  - `snapshotIdentityFromPath(String path)`: `static String`

- **CreateReleaseCommand**
  - `name`: `'create-release'`
  - `description`: 'Create git tag, GitHub Release, commit all changes.'

- **DetermineVersionCommand**
  - `name`: `'determine-version'`
  - `description`: 'Determine SemVer bump via Gemini + regex (CI: --output-github-actions).'

- **DocumentationCommand**
  - `name`: `'documentation'`
  - `description`: 'Run documentation update via Gemini 3 Pro Preview.'

- **ExploreCommand**
  - `name`: `'explore'`
  - `description`: 'Run Stage 1 Explorer Agent (Gemini 3 Pro Preview).'

- **InitCommand**
  - `name`: `'init'`
  - `description`: 'Scan repo and generate .runtime_ci/config.json + autodoc.json + scaffold workflows.'

- **MergeAuditTrailsCommand**
  - `name`: `'merge-audit-trails'`
  - `description`: 'Merge CI/CD audit artifacts from multiple jobs (CI use).'

- **ReleaseCommand**
  - `name`: `'release'`
  - `description`: 'Run the full local release pipeline.'

- **ReleaseNotesCommand**
  - `name`: `'release-notes'`
  - `description`: 'Run Stage 3 Release Notes Author (Gemini 3 Pro Preview).'

- **SetupCommand**
  - `name`: `'setup'`
  - `description`: 'Install all prerequisites (Node.js, Gemini CLI, gh, jq, tree).'

- **StatusCommand**
  - `name`: `'status'`
  - `description`: 'Show current CI/CD configuration status.'

- **TestCommand**
  - `name`: `'test'`
  - `description`: 'Run dart test.'

- **UpdateAllCommand** / **UpdateCommand**
  - `name`: `'update'` / `'update-all'`
  - `description`: 'Update templates, configs, and workflows from runtime_ci_tooling.'

- **ValidateCommand**
  - `name`: `'validate'`
  - `description`: 'Validate all configuration files.'

- **VerifyProtosCommand**
  - `name`: `'verify-protos'`
  - `description`: 'Verify proto source and generated files exist.'

- **VersionCommand**
  - `name`: `'version'`
  - `description`: 'Show the next SemVer version (no side effects).'

### Triage Commands
- **TriageCommand** (Group)
  - `name`: `'triage'`
  - `description`: 'Issue triage pipeline with AI-powered investigation.'
  - Contains subcommands: `TriageSingleCommand`, `TriageAutoCommand`, `TriageStatusCommand`, `TriageResumeCommand`, `TriagePreReleaseCommand`, `TriagePostReleaseCommand`.

---

## 3. Options Classes

Options classes use `build_cli` annotations to parse command line arguments. Each class has an associated extension that populates the `ArgParser`.

**Example:**
```dart
import 'package:runtime_ci_tooling/src/cli/options/version_options.dart';

// Constructing options using Dart cascade and named params
final options = VersionOptions(
  prevTag: 'v1.0.0',
  version: '1.1.0',
);

// Note: Protobuf-style cascade (..field = value) is not applicable here 
// since these option classes are immutable and instantiated via constructor parameters.
```

- **ArchiveRunOptions**
  - `runDir`: `String?`
- **AutodocOptions**
  - `init`: `bool`
  - `force`: `bool`
  - `module`: `String?`
- **CreateReleaseOptions**
  - `artifactsDir`: `String?`
  - `repo`: `String?`
- **DetermineVersionOptions**
  - `outputGithubActions`: `bool`
- **GlobalOptions**
  - `dryRun`: `bool`
  - `verbose`: `bool`
- **ManageCicdOptions**
  - Combined CLI options for the `manage_cicd.dart` entry point.
- **MergeAuditTrailsOptions**
  - `incomingDir`: `String?`
  - `outputDir`: `String?`
- **PostReleaseTriageOptions**
  - `releaseTag`: `String?`
  - `releaseUrl`: `String?`
  - `manifest`: `String?`
- **TriageCliOptions** / **TriageOptions**
  - Options for triage commands (e.g., `force`, `auto`, `status`).
- **UpdateAllOptions** / **UpdateOptions**
  - `force`, `templates`, `config`, `workflows`, `autodoc`, `backup` flags.
- **VersionOptions**
  - `prevTag`: `String?`
  - `version`: `String?`

---

## 4. Utility Classes

### Audit Utilities
- **AuditFinding**
  - Represents a single finding from auditing a pubspec dependency.
  - Fields: `pubspecPath`, `dependencyName`, `severity`, `category`, `message`, `currentValue`, `expectedValue`.
- **RegistryEntry**
  - Represents an entry from the external workspace packages registry.
  - Fields: `githubOrg`, `githubRepo`, `version`, `tagPattern`, `localPath`, `packageName`, `gitPath`, `expectedGitUrl`.
- **PackageRegistry**
  - Loads the external workspace packages YAML.
  - `PackageRegistry.load(String yamlPath)`
  - `lookup(String packageName)`: `RegistryEntry?`
- **PubspecAuditor**
  - Audits pubspec.yaml dependency declarations against a `PackageRegistry`.
  - `auditPubspec(String pubspecPath)`: `List<AuditFinding>`
  - `fixPubspec(String pubspecPath, List<AuditFinding> findings)`: `bool`

### IO & Process Utilities
- **FileUtils**
  - `copyDirRecursive(Directory src, Directory dst)`: `static void`
  - `countFiles(Directory dir)`: `static int`
  - `readFileOr(String path, [String fallback = '(not available)'])`: `static String`

- **CiProcessRunner**
  - `commandExists(String command)`: `static bool`
  - `runSync(String command, String workingDirectory, {bool verbose = false})`: `static String`
  - `exec(String executable, List<String> args, {String? cwd, bool fatal = false, bool verbose = false})`: `static void`

**Example:**
```dart
import 'package:runtime_ci_tooling/src/cli/utils/process_runner.dart';

final isGitInstalled = CiProcessRunner.commandExists('git');
if (isGitInstalled) {
  final branch = CiProcessRunner.runSync('git branch --show-current', '.');
  print('Current branch: \$branch');
}
```

### Output & Logging
- **Logger**
  - `header(String msg)`: `static void`
  - `info(String msg)`: `static void`
  - `success(String msg)`: `static void`
  - `warn(String msg)`: `static void`
  - `error(String msg)`: `static void`

### Release & Versioning
- **ReleaseUtils**
  - `buildReleaseCommitMessage(...)`: `static String`
  - `gatherVerifiedContributors(String repoRoot, String prevTag)`: `static List<Map<String, String>>`
  - `buildFallbackReleaseNotes(String repoRoot, String version, String prevTag)`: `static String`
  - `addChangelogReferenceLinks(String repoRoot, String content)`: `static void`
- **VersionDetection**
  - `detectPrevTag(String repoRoot, {String? excludeTag, bool verbose = false})`: `static String`
  - `detectNextVersion(String repoRoot, String prevTag, {bool verbose = false})`: `static String`
  - `compareVersions(String a, String b)`: `static int`
- **SubPackageUtils**
  - `loadSubPackages(String repoRoot)`: `static List<Map<String, dynamic>>`
  - `buildSubPackageDiffContext(...)`: `static String`
  - `convertSiblingDepsForRelease(...)`: `static int`

### Tooling & Setup
- **ToolInstallers**
  - `installTool(String tool, {bool dryRun = false})`: `static Future<void>`
  - `installNodeJs()`, `installGeminiCli()`, `installGitHubCli()`, `installJq()`, `installTree()`
- **HookInstaller**
  - `install(String repoRoot, {int lineLength = 120, bool dryRun = false})`: `static bool`

### Gemini Integration
- **GeminiUtils**
  - `geminiAvailable({bool warnOnly = false})`: `static bool`
  - `requireGeminiCli()`: `static void`
  - `requireApiKey()`: `static void`
  - `extractJson(String rawOutput)`: `static String`
  - `extractJsonObject(String text)`: `static String?`

### Miscellaneous
- **PromptResolver**
  - `promptScript(String scriptName)`: `static String`
  - `resolveToolingPackageRoot()`: `static String`
- **RepoUtils**
  - `findRepoRoot()`: `static String?`
- **StepSummary**
  - `write(String markdown)`: `static void`
  - `artifactLink([String label = 'View all artifacts'])`: `static String`
  - `compareLink(String prevTag, String newTag, [String? label])`: `static String`
  - `ghLink(String label, String path)`: `static String`
  - `releaseLink(String tag)`: `static String`
  - `escapeHtml(String input)`: `static String`
  - `collapsible(String title, String content, {bool open = false})`: `static String`
- **TestResultsUtil**
  - `parseTestResultsJson(String jsonPath)`: `static TestResults`
  - `writeTestJobSummary(TestResults results, int exitCode)`: `static void`
- **TemplateResolver**
  - `resolvePackageRoot()`: `static String`
  - `resolveTemplatesDir()`: `static String`
- **WorkflowGenerator**
  - Renders CI workflow YAML from a Mustache skeleton template and config.json.
  - `loadCiConfig(String repoRoot)`: `static Map<String, dynamic>?`
  - `render({String? existingContent})`: `String`

---

## 5. Enums

- **AuditSeverity**
  - `error`, `warning`, `info`
- **AuditCategory**
  - `bareDependency`, `wrongOrg`, `wrongRepo`, `missingTagPattern`, `wrongTagPattern`, `staleVersion`, `wrongUrlFormat`

---

## 6. Top-Level Functions

- **scaffoldAutodocJson**
  - `bool scaffoldAutodocJson(String repoRoot, {bool overwrite = false})`
- **computeFileHash**
  - `String computeFileHash(String filePath)`
- **acquireTriageLock**
  - `bool acquireTriageLock(bool force)`
- **releaseTriageLock**
  - `void releaseTriageLock()`
- **createTriageRunDir**
  - `String createTriageRunDir(String repoRoot)`
- **saveCheckpoint**
  - `void saveCheckpoint(String runDir, GamePlan plan, String lastPhase)`
- **loadCachedResults**
  - `Map<int, List<InvestigationResult>> loadCachedResults(String runDir, GamePlan plan)`
- **loadCachedDecisions**
  - `List<TriageDecision> loadCachedDecisions(String runDir)`
- **findLatestManifest**
  - `String? findLatestManifest(String repoRoot)`
