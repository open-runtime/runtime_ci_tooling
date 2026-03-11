# CI/CD CLI API Reference

## 1. Classes

### Core Usage Example

```dart
import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';

void main(List<String> args) async {
  final runner = ManageCicdCli();
  await runner.run(args);
}
```


### Commands
**ManageCicdCli** -- CLI entry point for CI/CD Automation.
- **Methods**:
  - `run(Iterable<String> args) -> Future<void>`: Runs the command with arguments. Intercepts and rewrites shorthand `triage <number>`.
  - `parseGlobalOptions(ArgResults? results) -> GlobalOptions`: Parses global options from ArgResults.
  - `isVerbose(ArgResults? results) -> bool`: Returns true if verbose mode is enabled.
  - `isDryRun(ArgResults? results) -> bool`: Returns true if dry-run mode is enabled.

**AnalyzeCommand** -- Run `dart analyze` on the root package and all configured sub-packages.
- **Fields**:
  - `name`: `String`
  - `description`: `String`
- **Methods**:
  - `run() -> Future<void>`

  **Example:**
  ```dart
  import 'package:runtime_ci_tooling/src/cli/commands/analyze_command.dart';

  final command = AnalyzeCommand();
  // Typically invoked via ManageCicdCli, but can be run directly.
  ```


**ArchiveRunCommand** -- Archive a CI/CD run to `.runtime_ci/audit/vX.X.X/` for permanent storage.
- **Fields**:
  - `name`: `String`
  - `description`: `String`
- **Methods**:
  - `run() -> Future<void>`

**AuditAllCommand** -- Recursively audit all pubspec.yaml files under a directory against the package registry.
- **Fields**:
  - `name`: `String`
  - `description`: `String`
- **Methods**:
  - `run() -> Future<void>`

**AuditCommand** -- Audit a pubspec.yaml against the package registry for dependency issues.
- **Fields**:
  - `name`: `String`
  - `description`: `String`
- **Methods**:
  - `run() -> Future<void>`

**AutodocCommand** -- Generate/update documentation for proto modules using Gemini 3.1 Pro.
- **Fields**:
  - `name`: `String`
  - `description`: `String`
- **Methods**:
  - `run() -> Future<void>`

**ComposeCommand** -- Run Stage 2 Changelog Composer (Gemini 3.1 Pro).
- **Fields**:
  - `name`: `String`
  - `description`: `String`
- **Methods**:
  - `run() -> Future<void>`

**ConfigureMcpCommand** -- Set up MCP servers (GitHub, Sentry).
- **Fields**:
  - `name`: `String`
  - `description`: `String`
- **Methods**:
  - `run() -> Future<void>`

**ConsumersCommand** -- Discover runtime_ci_tooling consumers and sync latest release data.
- **Fields**:
  - `name`: `String`
  - `description`: `String`
- **Methods**:
  - `computeNextDiscoveryIndexFromNames(Iterable<String> fileNames) -> int`
  - `buildDiscoverySnapshotName({required int index, required DateTime localTime}) -> String`
  - `resolveVersionFolderName(String tagName) -> String`
  - `snapshotIdentityFromPath(String path) -> String`
  - `isSnapshotSourceCompatible({required String? sourceSnapshotPath, required String? sourceSnapshotIdentity, required String expectedSnapshotPath}) -> bool`
  - `isReleaseSummaryReusable({required String status, required String outputPath, required String? tag, required String? exactTag}) -> bool`
  - `buildReleaseOutputPath({required String outputDir, required String repoName, required String tagName}) -> String`
  - `selectTagFromReleaseList({required List<Map<String, dynamic>> releases, required bool includePrerelease, RegExp? tagPattern}) -> String?`
  - `run() -> Future<void>`

**CreateReleaseCommand** -- Create git tag, GitHub Release, commit all changes.
- **Fields**:
  - `name`: `String`
  - `description`: `String`
- **Methods**:
  - `run() -> Future<void>`

**DetermineVersionCommand** -- Determine SemVer bump via Gemini + regex.
- **Fields**:
  - `name`: `String`
  - `description`: `String`
- **Methods**:
  - `run() -> Future<void>`

**DocumentationCommand** -- Run documentation update via Gemini 3.1 Pro Preview.
- **Fields**:
  - `name`: `String`
  - `description`: `String`
- **Methods**:
  - `run() -> Future<void>`

**ExploreCommand** -- Run Stage 1 Explorer Agent (Gemini 3.1 Pro Preview).
- **Fields**:
  - `name`: `String`
  - `description`: `String`
- **Methods**:
  - `run() -> Future<void>`

**InitCommand** -- Scan repo and generate config files + scaffold workflows.
- **Fields**:
  - `name`: `String`
  - `description`: `String`
- **Methods**:
  - `run() -> Future<void>`

**MergeAuditTrailsCommand** -- Merge CI/CD audit artifacts from multiple jobs.
- **Fields**:
  - `name`: `String`
  - `description`: `String`
- **Methods**:
  - `run() -> Future<void>`

**ReleaseCommand** -- Run the full local release pipeline.
- **Fields**:
  - `name`: `String`
  - `description`: `String`
- **Methods**:
  - `run() -> Future<void>`

**ReleaseNotesCommand** -- Run Stage 3 Release Notes Author (Gemini 3.1 Pro Preview).
- **Fields**:
  - `name`: `String`
  - `description`: `String`
- **Methods**:
  - `run() -> Future<void>`

**SetupCommand** -- Install all prerequisites.
- **Fields**:
  - `name`: `String`
  - `description`: `String`
- **Methods**:
  - `run() -> Future<void>`

**StatusCommand** -- Show current CI/CD configuration status.
- **Fields**:
  - `name`: `String`
  - `description`: `String`
- **Methods**:
  - `run() -> Future<void>`

**TestCommand** -- Run `dart test` with full output capture and job summary.
- **Fields**:
  - `name`: `String`
  - `description`: `String`
- **Methods**:
  - `run() -> Future<void>`
  - `runWithRoot(String repoRoot, {Duration processTimeout, Duration pubGetTimeout, _ExitHandler exitHandler, Map<String, String>? environment}) -> Future<void>`

**TriageCommand** -- Issue triage pipeline with AI-powered investigation.
- **Fields**:
  - `name`: `String`
  - `description`: `String`

**TriageAutoCommand** -- Auto-triage all untriaged open issues.
- **Fields**:
  - `name`: `String`
  - `description`: `String`
- **Methods**:
  - `run() -> Future<void>`

**TriagePostReleaseCommand** -- Close loop after release.
- **Fields**:
  - `name`: `String`
  - `description`: `String`
- **Methods**:
  - `run() -> Future<void>`

**TriagePreReleaseCommand** -- Scan issues for upcoming release.
- **Fields**:
  - `name`: `String`
  - `description`: `String`
- **Methods**:
  - `run() -> Future<void>`

**TriageResumeCommand** -- Resume a previously interrupted triage run.
- **Fields**:
  - `name`: `String`
  - `description`: `String`
  - `invocation`: `String`
- **Methods**:
  - `run() -> Future<void>`

**TriageSingleCommand** -- Triage a single issue by number.
- **Fields**:
  - `name`: `String`
  - `description`: `String`
  - `invocation`: `String`
- **Methods**:
  - `run() -> Future<void>`
  - `runSingle(int issueNumber, ArgResults? globalResults) -> Future<void>`

**TriageStatusCommand** -- Show triage pipeline status.
- **Fields**:
  - `name`: `String`
  - `description`: `String`
- **Methods**:
  - `run() -> Future<void>`

**UpdateAllCommand** -- Discover and update all runtime_ci_tooling packages under a root directory.
- **Fields**:
  - `name`: `String`
  - `description`: `String`
- **Methods**:
  - `run() -> Future<void>`

**UpdateCommand** -- Update templates, configs, and workflows from runtime_ci_tooling.
- **Fields**:
  - `name`: `String`
  - `description`: `String`
- **Methods**:
  - `run() -> Future<void>`

**ValidateCommand** -- Validate all configuration files.
- **Fields**:
  - `name`: `String`
  - `description`: `String`
- **Methods**:
  - `run() -> Future<void>`

**VerifyProtosCommand** -- Verify proto source and generated files exist.
- **Fields**:
  - `name`: `String`
  - `description`: `String`
- **Methods**:
  - `run() -> Future<void>`

**VersionCommand** -- Show the next SemVer version.
- **Fields**:
  - `name`: `String`
  - `description`: `String`
- **Methods**:
  - `run() -> Future<void>`

### Options Classes

Options classes are used to type-safely parse arguments using `build_cli`.

**Example:**
```dart
import 'package:runtime_ci_tooling/src/cli/options/global_options.dart';
import 'package:args/args.dart';

void parseArgs(List<String> args) {
  final parser = ArgParser();
  GlobalOptionsArgParser.populateParser(parser);
  
  final results = parser.parse(args);
  final options = GlobalOptions.fromArgResults(results);
  
  if (options.verbose) {
    print('Verbose mode enabled');
  }
}
```


**ArchiveRunOptions** -- CLI options for the archive-run command.
- **Fields**:
  - `runDir`: `String?`
- **Constructors**:
  - `ArchiveRunOptions({this.runDir})`
  - `factory ArchiveRunOptions.fromArgResults(ArgResults results)`

**AutodocOptions** -- CLI options for the autodoc command.
- **Fields**:
  - `init`: `bool`
  - `force`: `bool`
  - `module`: `String?`
- **Constructors**:
  - `AutodocOptions({this.init = false, this.force = false, this.module})`
  - `factory AutodocOptions.fromArgResults(ArgResults results)`

**CreateReleaseOptions** -- CLI options for the create-release command.
- **Fields**:
  - `artifactsDir`: `String?`
  - `repo`: `String?`
- **Constructors**:
  - `CreateReleaseOptions({this.artifactsDir, this.repo})`
  - `factory CreateReleaseOptions.fromArgResults(ArgResults results)`

**DetermineVersionOptions** -- CLI options for the determine-version command.
- **Fields**:
  - `outputGithubActions`: `bool`
- **Constructors**:
  - `DetermineVersionOptions({this.outputGithubActions = false})`
  - `factory DetermineVersionOptions.fromArgResults(ArgResults results)`

**GlobalOptions** -- Global CLI options available to all commands.
- **Fields**:
  - `dryRun`: `bool`
  - `verbose`: `bool`
- **Constructors**:
  - `GlobalOptions({this.dryRun = false, this.verbose = false})`
  - `factory GlobalOptions.fromArgResults(ArgResults results)`

**ManageCicdOptions** -- Combined CLI options for manage_cicd.dart entry point.
- **Fields**:
  - `dryRun`: `bool`
  - `verbose`: `bool`
  - `prevTag`: `String?`
  - `version`: `String?`
  - `outputGithubActions`: `bool`
  - `artifactsDir`: `String?`
  - `repo`: `String?`
  - `releaseTag`: `String?`
  - `releaseUrl`: `String?`
  - `manifest`: `String?`
- **Constructors**:
  - `ManageCicdOptions({...})`

**MergeAuditTrailsOptions** -- CLI options for the merge-audit-trails command.
- **Fields**:
  - `incomingDir`: `String?`
  - `outputDir`: `String?`
- **Constructors**:
  - `MergeAuditTrailsOptions({this.incomingDir, this.outputDir})`
  - `factory MergeAuditTrailsOptions.fromArgResults(ArgResults results)`

**PostReleaseTriageOptions** -- CLI options for the post-release-triage command.
- **Fields**:
  - `releaseTag`: `String?`
  - `releaseUrl`: `String?`
  - `manifest`: `String?`
- **Constructors**:
  - `PostReleaseTriageOptions({this.releaseTag, this.releaseUrl, this.manifest})`
  - `factory PostReleaseTriageOptions.fromArgResults(ArgResults results)`

**TriageCliOptions** -- Combined CLI options for triage_cli.dart entry point.
- **Fields**:
  - `dryRun`: `bool`
  - `verbose`: `bool`
  - `auto`: `bool`
  - `status`: `bool`
  - `force`: `bool`
  - `preRelease`: `bool`
  - `postRelease`: `bool`
  - `resume`: `String?`
  - `prevTag`: `String?`
  - `version`: `String?`
  - `releaseTag`: `String?`
  - `releaseUrl`: `String?`
  - `manifest`: `String?`
- **Constructors**:
  - `TriageCliOptions({...})`
  - `factory TriageCliOptions.fromArgResults(ArgResults results)`

**TriageOptions** -- CLI options shared by triage subcommands that acquire a lock.
- **Fields**:
  - `force`: `bool`
- **Constructors**:
  - `TriageOptions({this.force = false})`
  - `factory TriageOptions.fromArgResults(ArgResults results)`

**UpdateAllOptions** -- CLI options for the update-all command.
- **Fields**:
  - `scanRoot`: `String?`
  - `concurrency`: `int`
  - `force`: `bool`
  - `workflows`: `bool`
  - `templates`: `bool`
  - `config`: `bool`
  - `autodoc`: `bool`
  - `backup`: `bool`
- **Constructors**:
  - `UpdateAllOptions({...})`
  - `factory UpdateAllOptions.fromArgResults(ArgResults results)`

**UpdateOptions** -- CLI options for the update command.
- **Fields**:
  - `force`: `bool`
  - `templates`: `bool`
  - `config`: `bool`
  - `workflows`: `bool`
  - `autodoc`: `bool`
  - `backup`: `bool`
  - `diff`: `bool`
- **Methods**:
  - `updateAll`: `bool` (getter)
- **Constructors**:
  - `UpdateOptions({...})`
  - `factory UpdateOptions.fromArgResults(ArgResults results)`

**VersionOptions** -- Version-related CLI options.
- **Fields**:
  - `prevTag`: `String?`
  - `version`: `String?`
- **Constructors**:
  - `VersionOptions({this.prevTag, this.version})`
  - `factory VersionOptions.fromArgResults(ArgResults results)`

### Utilities & Core

**AuditFinding** -- A single finding from auditing a pubspec dependency.
- **Fields**:
  - `pubspecPath`: `String`
  - `dependencyName`: `String`
  - `severity`: `AuditSeverity`
  - `category`: `AuditCategory`
  - `message`: `String`
  - `currentValue`: `String?`
  - `expectedValue`: `String?`

**PackageRegistry** -- Registry of git-sourced workspace packages.
- **Fields**:
  - `names`: `Iterable<String>`
  - `entries`: `Map<String, RegistryEntry>`
  - `length`: `int`
- **Methods**:
  - `lookup(String packageName) -> RegistryEntry?`
  - `load(String yamlPath) -> PackageRegistry` (factory)
  - `loadFromFile(String yamlPath) -> PackageRegistry?` (static)
  - `loadFromString(String yamlContent) -> PackageRegistry?` (static)

**PubspecAuditor** -- Audits pubspec.yaml dependency declarations against a PackageRegistry.
- **Fields**:
  - `registry`: `PackageRegistry`
- **Methods**:
  - `auditPubspec(String pubspecPath) -> List<AuditFinding>`
  - `fixPubspec(String pubspecPath, List<AuditFinding> findings) -> bool`

**RegistryEntry** -- A single entry from the external workspace packages registry.
- **Fields**:
  - `githubOrg`: `String`
  - `githubRepo`: `String`
  - `version`: `String`
  - `tagPattern`: `String`
  - `localPath`: `String`
  - `packageName`: `String?`
  - `gitPath`: `String?`
  - `expectedGitUrl`: `String`

**FileUtils** -- File system utilities.
- **Methods**:
  - `copyDirRecursive(Directory src, Directory dst) -> void` (static)
  - `countFiles(Directory dir) -> int` (static)
  - `readFileOr(String path, [String fallback = '(not available)']) -> String` (static)

**GeminiPrerequisiteError** -- Exception thrown when Gemini CLI prerequisites are not met.
- **Fields**:
  - `message`: `String`
- **Methods**:
  - `toString() -> String`

**GeminiUtils** -- Utilities for Gemini CLI integration.
- **Methods**:
  - `geminiAvailable({bool warnOnly = false}) -> bool` (static)
  - `requireGeminiCli() -> void` (static)
  - `requireApiKey() -> void` (static)
  - `extractJson(String rawOutput) -> String` (static)
  - `extractJsonObject(String text) -> String?` (static)

  **Example:**
  ```dart
  import 'package:runtime_ci_tooling/src/cli/utils/gemini_utils.dart';

  if (GeminiUtils.geminiAvailable(warnOnly: true)) {
    GeminiUtils.requireApiKey();
    final jsonOutput = GeminiUtils.extractJson('{"foo": "bar"}');
  }
  ```


**HookInstaller** -- Installs and manages git pre-commit hooks for Dart repos.
- **Methods**:
  - `install(String repoRoot, {int lineLength = 120, bool dryRun = false}) -> bool` (static)

**Logger** -- ANSI-styled console logging.
- **Methods**:
  - `header(String msg) -> void` (static)
  - `info(String msg) -> void` (static)
  - `success(String msg) -> void` (static)
  - `warn(String msg) -> void` (static)
  - `error(String msg) -> void` (static)

**CiProcessRunner** -- Utilities for running external processes.
- **Methods**:
  - `commandExists(String command) -> bool` (static)
  - `runSync(String command, String workingDirectory, {bool verbose = false}) -> String` (static)
  - `exec(String executable, List<String> args, {String? cwd, bool fatal = false, bool verbose = false}) -> Future<void>` (static)
  - `runWithTimeout(String executable, List<String> arguments, {String? workingDirectory, Duration timeout = const Duration(minutes: 5), int timeoutExitCode = 124, String timeoutMessage = 'Timed out'}) -> Future<ProcessResult>` (static)
  - `killAndAwaitExit(Process process) -> Future<void>` (static)

**PromptResolver** -- Resolves paths to prompt scripts.
- **Methods**:
  - `promptScript(String scriptName) -> String` (static)
  - `resolveToolingPackageRoot() -> String` (static)

**ReleaseUtils** -- Utilities for release management.
- **Methods**:
  - `buildReleaseCommitMessage({required String repoRoot, required String version, required String prevTag, required Directory releaseDir, bool verbose = false}) -> String` (static)
  - `gatherVerifiedContributors(String repoRoot, String prevTag) -> List<Map<String, String>>` (static)
  - `buildFallbackReleaseNotes(String repoRoot, String version, String prevTag) -> String` (static)
  - `addChangelogReferenceLinks(String repoRoot, String content) -> void` (static)

**RepoUtils** -- Utilities for repository roots and paths.
- **Methods**:
  - `findRepoRoot() -> String?` (static)
  - `resolveTestLogDir(String repoRoot, {Map<String, String>? environment}) -> String` (static)
  - `isSymlinkPath(String path) -> bool` (static)
  - `ensureSafeDirectory(String dirPath) -> void` (static)
  - `writeFileSafely(String filePath, String content, {FileMode mode = FileMode.write}) -> void` (static)

  **Example:**
  ```dart
  import 'package:runtime_ci_tooling/src/cli/utils/repo_utils.dart';

  final root = RepoUtils.findRepoRoot();
  if (root != null) {
    final logDir = RepoUtils.resolveTestLogDir(root);
    RepoUtils.ensureSafeDirectory(logDir);
  }
  ```


**StepSummary** -- Step summary utilities for GitHub Actions.
- **Methods**:
  - `write(String markdown, {Map<String, String>? environment}) -> void` (static)
  - `artifactLink([String label = 'View all artifacts']) -> String` (static)
  - `compareLink(String prevTag, String newTag, [String? label]) -> String` (static)
  - `ghLink(String label, String path) -> String` (static)
  - `releaseLink(String tag) -> String` (static)
  - `collapsible(String title, String content, {bool open = false}) -> String` (static)
  - `escapeHtml(String input) -> String` (static)

**SubPackageUtils** -- Utilities for working with sub-packages.
- **Methods**:
  - `loadSubPackages(String repoRoot) -> List<Map<String, dynamic>>` (static)
  - `buildSubPackageDiffContext({required String repoRoot, required String prevTag, required List<Map<String, dynamic>> subPackages, bool verbose = false}) -> String` (static)
  - `buildHierarchicalChangelogInstructions({required String newVersion, required List<Map<String, dynamic>> subPackages}) -> String` (static)
  - `buildHierarchicalReleaseNotesInstructions({required String newVersion, required List<Map<String, dynamic>> subPackages}) -> String` (static)
  - `buildHierarchicalDocumentationInstructions({required String newVersion, required List<Map<String, dynamic>> subPackages}) -> String` (static)
  - `buildHierarchicalAutodocInstructions({required String moduleName, required List<Map<String, dynamic>> subPackages, String? moduleSubPackage}) -> String` (static)
  - `enrichPromptWithSubPackages({required String repoRoot, required String prevTag, required String promptFilePath, required Function buildInstructions, required String newVersion, bool verbose = false}) -> List<Map<String, dynamic>>` (static)
  - `convertSiblingDepsForRelease({required String repoRoot, required String newVersion, required String effectiveRepo, required List<Map<String, dynamic>> subPackages, bool verbose = false}) -> int` (static)
  - `logSubPackages(List<Map<String, dynamic>> subPackages) -> void` (static)

**TemplateEntry** -- Represents one template entry from manifest.json.
- **Fields**:
  - `id`: `String`
  - `source`: `String?`
  - `destination`: `String`
  - `category`: `String`
  - `description`: `String`
- **Constructors**:
  - `factory TemplateEntry.fromJson(Map<String, dynamic> json)`

**TemplateVersionTracker** -- Tracks which template versions a consumer repo has installed.
- **Fields**:
  - `lastToolingVersion`: `String?`
- **Methods**:
  - `getInstalledHash(String templateId) -> String?`
  - `getConsumerHash(String templateId) -> String?`
  - `recordUpdate(String templateId, {required String templateHash, required String consumerFileHash, required String toolingVersion}) -> void`
  - `save(String repoRoot) -> void`
- **Constructors**:
  - `factory TemplateVersionTracker.load(String repoRoot)`

**TemplateResolver** -- Resolves paths within the runtime_ci_tooling package.
- **Methods**:
  - `resolvePackageRoot() -> String` (static)
  - `resolveTemplatesDir() -> String` (static)
  - `resolveTemplatePath(String relativePath) -> String` (static)
  - `readManifest() -> Map<String, dynamic>` (static)
  - `resolveToolingVersion() -> String` (static)

**TestFailure** -- A single failed test record.
- **Fields**:
  - `name`: `String`
  - `error`: `String`
  - `stackTrace`: `String`
  - `printOutput`: `String`
  - `durationMs`: `int`

**TestResults** -- Parsed aggregate test results.
- **Fields**:
  - `passed`: `int`
  - `failed`: `int`
  - `skipped`: `int`
  - `totalDurationMs`: `int`
  - `failures`: `List<TestFailure>`
  - `parsed`: `bool`

**TestResultsUtil** -- Test-results parsing and step-summary writing.
- **Methods**:
  - `parseTestResultsJson(String jsonPath) -> Future<TestResults>` (static)
  - `writeTestJobSummary(TestResults results, int exitCode, {String? platformId, void Function(String markdown)? writeSummary}) -> void` (static)

**ToolInstallers** -- Cross-platform tool installation utilities.
- **Methods**:
  - `installTool(String tool, {bool dryRun = false}) -> Future<void>` (static)
  - `installNodeJs() -> Future<void>` (static)
  - `installGeminiCli() -> Future<void>` (static)
  - `installGitHubCli() -> Future<void>` (static)
  - `installJq() -> Future<void>` (static)
  - `installTree() -> Future<void>` (static)

**Utf8BoundedBuffer** -- Collects text while enforcing a strict UTF-8 byte budget.
- **Fields**:
  - `maxBytes`: `int`
  - `truncationSuffix`: `String`
  - `byteLength`: `int`
  - `isTruncated`: `bool`
  - `isEmpty`: `bool`
- **Methods**:
  - `append(String data) -> void`
  - `truncateToUtf8Bytes(String input, int maxBytes) -> String` (static)

**VersionDetection** -- Semantic versioning utilities.
- **Methods**:
  - `detectPrevTag(String repoRoot, {String? excludeTag, bool verbose = false}) -> String` (static)
  - `detectNextVersion(String repoRoot, String prevTag, {bool verbose = false}) -> String` (static)
  - `compareVersions(String a, String b) -> int` (static)

  **Example:**
  ```dart
  import 'package:runtime_ci_tooling/src/cli/utils/version_detection.dart';

  final prevTag = VersionDetection.detectPrevTag(repoRoot);
  final nextVersion = VersionDetection.detectNextVersion(repoRoot, prevTag);
  print('Upgrading from $prevTag to $nextVersion');
  ```


**WorkflowGenerator** -- Renders CI workflow YAML from Mustache templates.
- **Fields**:
  - `ciConfig`: `Map<String, dynamic>`
  - `toolingVersion`: `String`
- **Methods**:
  - `render({String? existingContent}) -> String`
  - `logConfig() -> void`
  - `validateSubPackageEntry(Map<String, dynamic> sp, Set<String> seenNames, Set<String> seenPaths) -> String?` (static)

  **Example:**
  ```dart
  import 'package:runtime_ci_tooling/src/cli/utils/workflow_generator.dart';

  final ciConfig = WorkflowGenerator.loadCiConfig(repoRoot);
  if (ciConfig != null && WorkflowGenerator.validate(ciConfig).isEmpty) {
    final generator = WorkflowGenerator(ciConfig: ciConfig, toolingVersion: '1.0.0');
    final yaml = generator.render();
    print(yaml);
  }
  ```

  - `loadCiConfig(String repoRoot) -> Map<String, dynamic>?` (static)
  - `validate(Map<String, dynamic> ciConfig) -> List<String>` (static)

## 2. Enums

**AuditSeverity** -- Severity of an audit finding.
- `error`
- `warning`
- `info`

**AuditCategory** -- Category of a pubspec audit issue.
- `bareDependency`: The dep is just `name: ^version` with no git source.
- `wrongOrg`: The git URL points to the wrong GitHub org.
- `wrongRepo`: The git URL points to the wrong repo name.
- `missingTagPattern`: Git dep doesn't have a `tag_pattern` field.
- `wrongTagPattern`: `tag_pattern` doesn't match the registry value.
- `staleVersion`: Version constraint doesn't match the registry version.
- `wrongUrlFormat`: Git URL isn't using SSH format.

## 3. Extensions

**ArchiveRunOptionsArgParser** on `ArchiveRunOptions` -- Helper for CLI arguments.
- `populateParser(ArgParser parser) -> void`

**AutodocOptionsArgParser** on `AutodocOptions` -- Helper for CLI arguments.
- `populateParser(ArgParser parser) -> void`

**CreateReleaseOptionsArgParser** on `CreateReleaseOptions` -- Helper for CLI arguments.
- `populateParser(ArgParser parser) -> void`

**DetermineVersionOptionsArgParser** on `DetermineVersionOptions` -- Helper for CLI arguments.
- `populateParser(ArgParser parser) -> void`

**GlobalOptionsArgParser** on `GlobalOptions` -- Helper for CLI arguments.
- `populateParser(ArgParser parser) -> void`

**MergeAuditTrailsOptionsArgParser** on `MergeAuditTrailsOptions` -- Helper for CLI arguments.
- `populateParser(ArgParser parser) -> void`

**PostReleaseTriageOptionsArgParser** on `PostReleaseTriageOptions` -- Helper for CLI arguments.
- `populateParser(ArgParser parser) -> void`

**TriageOptionsArgParser** on `TriageOptions` -- Helper for CLI arguments.
- `populateParser(ArgParser parser) -> void`

**UpdateAllOptionsArgParser** on `UpdateAllOptions` -- Helper for CLI arguments.
- `populateParser(ArgParser parser) -> void`

**UpdateOptionsArgParser** on `UpdateOptions` -- Helper for CLI arguments.
- `populateParser(ArgParser parser) -> void`
- `updateAll`: `bool` (getter) - Returns true if no specific filter flags are set.

**VersionOptionsArgParser** on `VersionOptions` -- Helper for CLI arguments.
- `populateParser(ArgParser parser) -> void`

## 4. Top-Level Functions

**main(List<String> args)** -- Entry point for the CLI tool.
- Parameters: `List<String> args`
- Returns: `void`

**acquireTriageLock(bool force)** -- Acquire a file-based lock for triage runs.
- Parameters: `bool force`
- Returns: `bool`

**releaseTriageLock()** -- Release the file-based lock.
- Parameters: None
- Returns: `void`

**createTriageRunDir(String repoRoot)** -- Create a unique run directory for a triage session.
- Parameters: `String repoRoot`
- Returns: `String`

**saveCheckpoint(String runDir, GamePlan plan, String lastPhase)** -- Save a checkpoint so the run can be resumed later.
- Parameters: `String runDir`, `GamePlan plan`, `String lastPhase`
- Returns: `void`

**loadCachedResults(String runDir, GamePlan plan)** -- Load cached investigation results.
- Parameters: `String runDir`, `GamePlan plan`
- Returns: `Map<int, List<InvestigationResult>>`

**loadCachedDecisions(String runDir)** -- Load cached triage decisions.
- Parameters: `String runDir`
- Returns: `List<TriageDecision>`

**findLatestManifest(String repoRoot)** -- Search recent triage runs for the latest issue_manifest.json.
- Parameters: `String repoRoot`
- Returns: `String?`

**resolveAutodocOutputPath({required String configuredOutputPath, required String? moduleSubPackage})** -- Resolves the output path for an autodoc module.
- Parameters: `String configuredOutputPath`, `String? moduleSubPackage`
- Returns: `String`

**scaffoldAutodocJson(String repoRoot, {bool overwrite = false})** -- Scaffold `.runtime_ci/autodoc.json`.
- Parameters: `String repoRoot`, `bool overwrite`
- Returns: `bool`

**exitWithCode(int code)** -- Flush stdout and stderr before exiting.
- Parameters: `int code`
- Returns: `Future<Never>`

**computeFileHash(String filePath)** -- Compute SHA256 hash of a file's contents.
- Parameters: `String filePath`
- Returns: `String`
