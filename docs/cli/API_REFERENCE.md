# CI/CD CLI API Reference

This document provides a comprehensive API reference for the `runtime_ci_tooling` CI/CD Command Line Interface module, including all commands, configuration options, and utilities.

## 1. CLI Command Runner

### `ManageCicdCli`
CLI entry point for CI/CD Automation. Provides commands for managing the full CI/CD lifecycle.
* **Methods**:
  * `run(Iterable<String> args) -> Future<void>`: Executes the CLI command and intelligently intercepts `triage <number>` shorthands.
  * `parseGlobalOptions(ArgResults? results) -> GlobalOptions` *(static)*: Parses global options from `ArgResults`.
  * `isVerbose(ArgResults? results) -> bool` *(static)*: Returns true if verbose mode is enabled.
  * `isDryRun(ArgResults? results) -> bool` *(static)*: Returns true if dry-run mode is enabled.

## 2. CLI Commands

### Pipeline & Setup Commands
* **`InitCommand`** (`init`): Scan repo and generate `.runtime_ci/config.json` + `autodoc.json` + scaffold workflows.
* **`SetupCommand`** (`setup`): Install all prerequisites (`Node.js`, `Gemini CLI`, `gh`, `jq`, `tree`).
* **`StatusCommand`** (`status`): Show current CI/CD configuration status.
* **`ValidateCommand`** (`validate`): Validate all configuration files.
* **`ConfigureMcpCommand`** (`configure-mcp`): Set up MCP servers (GitHub, Sentry) in `.gemini/settings.json`.

### Release & Changelog Commands
* **`ReleaseCommand`** (`release`): Run the full local release pipeline.
* **`ExploreCommand`** (`explore`): Run Stage 1 Explorer Agent (Gemini 3 Pro Preview).
* **`ComposeCommand`** (`compose`): Run Stage 2 Changelog Composer (Gemini Pro).
* **`ReleaseNotesCommand`** (`release-notes`): Run Stage 3 Release Notes Author (Gemini 3 Pro Preview).
* **`CreateReleaseCommand`** (`create-release`): Create git tag, GitHub Release, and commit all changes.
* **`DetermineVersionCommand`** (`determine-version`): Determine SemVer bump via Gemini + regex (CI: `--output-github-actions`).
* **`VersionCommand`** (`version`): Show the next SemVer version (no side effects).

### Triage Commands
* **`TriageCommand`** (`triage`): Issue triage pipeline with AI-powered investigation.
  * **`TriageSingleCommand`** (`single`): Triage a single issue by number.
  * **`TriageAutoCommand`** (`auto`): Auto-triage all untriaged open issues.
  * **`TriagePreReleaseCommand`** (`pre-release`): Scan issues for upcoming release.
  * **`TriagePostReleaseCommand`** (`post-release`): Close loop after release.
  * **`TriageResumeCommand`** (`resume`): Resume a previously interrupted triage run.
  * **`TriageStatusCommand`** (`status`): Show triage pipeline status.

### Tooling & Maintenance Commands
* **`AnalyzeCommand`** (`analyze`): Run `dart analyze` (fail on errors only).
* **`TestCommand`** (`test`): Run `dart test`.
* **`VerifyProtosCommand`** (`verify-protos`): Verify proto source and generated files exist.
* **`AutodocCommand`** (`autodoc`): Generate/update module docs using Gemini (`--init`, `--force`, `--module`, `--dry-run`).
* **`DocumentationCommand`** (`documentation`): Run documentation update via Gemini 3 Pro Preview.
* **`UpdateCommand`** (`update`): Update templates, configs, and workflows from `runtime_ci_tooling`.
* **`UpdateAllCommand`** (`update-all`): Discover and update all `runtime_ci_tooling` packages under a root directory.
* **`ConsumersCommand`** (`consumers`): Discover `runtime_ci_tooling` consumers and sync latest release data.
* **`ArchiveRunCommand`** (`archive-run`): Archive `.runtime_ci/runs/` to `.runtime_ci/audit/vX.X.X/` for permanent storage.
* **`MergeAuditTrailsCommand`** (`merge-audit-trails`): Merge CI/CD audit artifacts from multiple jobs (CI use).

## 3. Options Classes

Options classes encapsulate typed CLI arguments for respective commands.

* **`GlobalOptions`**:
  * `dryRun` (`bool`): Show what would be done without executing.
  * `verbose` (`bool`): Show detailed command output.
* **`VersionOptions`**:
  * `prevTag` (`String?`): Override previous tag detection.
  * `version` (`String?`): Override version (skip auto-detection).
* **`AutodocOptions`**:
  * `init` (`bool`): Scan repo and create initial `autodoc.json`.
  * `force` (`bool`): Regenerate all docs regardless of hash.
  * `module` (`String?`): Only generate for a specific module.
* **`CreateReleaseOptions`**:
  * `artifactsDir` (`String?`): Directory containing downloaded CI artifacts.
  * `repo` (`String?`): GitHub repository slug (owner/repo).
* **`DetermineVersionOptions`**:
  * `outputGithubActions` (`bool`): Write version outputs to `$GITHUB_OUTPUT` for GitHub Actions.
* **`UpdateOptions`**:
  * `force` (`bool`): Overwrite all files regardless of local customizations.
  * `templates` (`bool`): Only update template files.
  * `config` (`bool`): Only merge new keys into config.
  * `workflows` (`bool`): Only update GitHub workflow files.
  * `autodoc` (`bool`): Re-scan `lib/src/` and update `autodoc.json` modules.
  * `backup` (`bool`): Write `.bak` backup before overwriting files.
* **`UpdateAllOptions`**:
  * Incorporates all properties from `UpdateOptions`.
  * `scanRoot` (`String?`): Root directory to scan for packages.
  * `concurrency` (`int`): Max concurrent update processes.
* **`MergeAuditTrailsOptions`**:
  * `incomingDir` (`String?`): Directory containing incoming audit trail artifacts.
  * `outputDir` (`String?`): Output directory for merged audit trails.
* **`ArchiveRunOptions`**:
  * `runDir` (`String?`): Directory containing the CI run to archive.
* **`TriageOptions`**:
  * `force` (`bool`): Override an existing triage lock.
* **`PostReleaseTriageOptions`**:
  * `releaseTag` (`String?`): Git tag for the release.
  * `releaseUrl` (`String?`): URL of the GitHub release page.
  * `manifest` (`String?`): Path to `issue_manifest.json`.

## 4. Utilities

* **`CiProcessRunner`**: Utilities for running external processes.
  * `commandExists(String command) -> bool`
  * `runSync(String command, String workingDirectory, {bool verbose}) -> String`
  * `exec(String executable, List<String> args, {String? cwd, bool fatal, bool verbose}) -> void`
* **`GeminiUtils`**:
  * `geminiAvailable({bool warnOnly}) -> bool`
  * `requireGeminiCli() -> void`
  * `requireApiKey() -> void`
  * `extractJson(String rawOutput) -> String`
* **`ReleaseUtils`**:
  * `buildReleaseCommitMessage(...) -> String`
  * `gatherVerifiedContributors(String repoRoot, String prevTag) -> List<Map<String, String>>`
  * `buildFallbackReleaseNotes(String repoRoot, String version, String prevTag) -> String`
  * `addChangelogReferenceLinks(String repoRoot, String content) -> void`
* **`VersionDetection`**:
  * `detectPrevTag(String repoRoot, {bool verbose}) -> String`
  * `detectNextVersion(String repoRoot, String prevTag, {bool verbose}) -> String`
* **`HookInstaller`**:
  * `install(String repoRoot, {int lineLength, bool dryRun}) -> bool`
* **`TemplateResolver`**: Resolves paths within the `runtime_ci_tooling` package dynamically.
* **`WorkflowGenerator`**: Renders CI workflow YAML from Mustache skeleton and `config.json`.
* **`StepSummary`**: Utilities for writing GitHub Actions step summaries.
