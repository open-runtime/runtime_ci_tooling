# CI/CD CLI API Reference

This module provides the core command-line interface for managing the AI-powered release pipeline, issue triage, and general CI/CD automation locally and in GitHub Actions.

## 1. Commands

### AnalyzeCommand
Run `dart analyze` (fail on errors only). 

This command runs `dart analyze --no-fatal-warnings`, ensuring that only actual errors fail the CI pipeline, while infos and warnings are reported but non-fatal.

**Example Usage:**
```bash
dart run runtime_ci_tooling:manage_cicd analyze
```

### ArchiveRunCommand
Archive a CI/CD run to `.runtime_ci/audit/vX.X.X/` for permanent storage.
If the `--version` option is missing, it will skip the process. It finds the latest run automatically if `--run-dir` is not provided.

**Options:**
- `runDir` (`String?`): Directory containing the CI run to archive.

### AutodocCommand
Generate/update module documentation. Uses `autodoc.json` for configuration and hash-based change detection for incremental updates using Gemini.

**Options:**
- `init` (`bool`): Scan repo and create initial `autodoc.json`.
- `force` (`bool`): Regenerate all docs regardless of hash.
- `module` (`String?`): Only generate for a specific module.

**Example Usage:**
```bash
# Generate all docs
dart run runtime_ci_tooling:manage_cicd autodoc
# Force regenerate specific module
dart run runtime_ci_tooling:manage_cicd autodoc --force --module core
```

### ComposeCommand
Run Stage 2 Changelog Composer. Uses the Gemini Pro model to synthesize PR data and commit history into updates for `CHANGELOG.md` and `README.md`.

### ConfigureMcpCommand
Configure MCP servers (`github` and `sentry`) in `.gemini/settings.json`. 
It detects `GH_TOKEN` or `GITHUB_TOKEN` to configure the GitHub MCP server, and sets up the Sentry MCP server.

### ConsumersCommand
Discover repositories that consume `runtime_ci_tooling` and sync latest release data. 
Useful for cross-repository updates.

### CreateReleaseCommand
Create git tag, GitHub Release, and commit all changes. Replaces shell scripts in the release job. 

**Options:**
- `artifactsDir` (`String?`): Directory containing downloaded CI artifacts.
- `repo` (`String?`): GitHub repository slug (`owner/repo`).

### DetermineVersionCommand
Determine SemVer bump via Gemini + regex heuristic. 
Analyzes commit history and outputs JSON. With `--output-github-actions`, it writes `prev_tag`, `new_version`, and `should_release` to `$GITHUB_OUTPUT`.

### DocumentationCommand
Run documentation update via Gemini 3 Pro Preview. 

### ExploreCommand
Run Stage 1 Explorer Agent. Analyzes commits and PRs to prepare context for changelog composition. Writes artifacts to `/tmp/`.

### InitCommand
Scan the current repo and bootstrap `.runtime_ci/config.json`, `.runtime_ci/autodoc.json`, and optional scaffolding (e.g., `CHANGELOG.md`, `.gitignore` entries, pre-commit hooks).

### MergeAuditTrailsCommand
Merge CI/CD audit artifacts from multiple jobs into a single run directory under `.runtime_ci/runs/`. Used in CI.

**Options:**
- `incomingDir` (`String?`): Directory containing incoming artifacts.
- `outputDir` (`String?`): Output directory for merged trails.

### ReleaseCommand
Run the full local release pipeline sequentially: Version Detection, Explore, and Compose.

### ReleaseNotesCommand
Run Stage 3 Release Notes Author. Generates rich release notes, migration guides, and linked issues using Gemini Pro. 

### SetupCommand
Install all prerequisites cross-platform, including Node.js, Gemini CLI, `gh`, `jq`, and `tree`.

### StatusCommand
Show current CI/CD configuration status. Validates the existence of configuration files, tool versions, and API keys.

### TestCommand
Run `dart test`. Excludes `gcp` and `integration` tags.

### Triage Command Group
Issue triage pipeline with AI-powered investigation.
- **TriageAutoCommand**: `auto` - Auto-triage all untriaged open issues.
- **TriagePostReleaseCommand**: `post-release` - Close loop after release (comment/close issues, link Sentry).
- **TriagePreReleaseCommand**: `pre-release` - Scan issues for upcoming release.
- **TriageResumeCommand**: `resume <run_id>` - Resume an interrupted triage run.
- **TriageSingleCommand**: `single <number>` - Triage a single issue.
- **TriageStatusCommand**: `status` - Show triage pipeline status.

### UpdateCommand
Update templates, configs, and workflows from `runtime_ci_tooling`. Detects drift between the package's templates and the consumer's installed copies.

**Options:**
- `force` (`bool`): Overwrite all files.
- `templates` (`bool`): Only update template files.
- `config` (`bool`): Only merge new keys into config.
- `workflows` (`bool`): Only update workflow files.
- `autodoc` (`bool`): Re-scan and update `autodoc.json`.
- `backup` (`bool`): Write a backup before overwriting.

### UpdateAllCommand
Discover and update all `runtime_ci_tooling` packages under a root directory.

### ValidateCommand
Validate all configuration files (JSON, YAML, TOML, and Dart prompt scripts).

### VerifyProtosCommand
Verify proto source and generated files exist.

### VersionCommand
Show the next SemVer version without applying any side effects.

---

## 2. Options Classes

Options classes use `build_cli` to parse command-line arguments.

### GlobalOptions
Global CLI options available to all commands.
- `dryRun` (`bool`): Show what would be done without executing.
- `verbose` (`bool`): Show detailed command output.

### ManageCicdOptions
Combined options for `manage_cicd.dart` entry point. Includes global, version, CI/CD, and release options.

---

## 3. Utilities

### CiProcessRunner
Utilities for running external processes.
- `commandExists(String command)` (`bool`): Checks if a command exists on PATH.
- `runSync(String command, String workingDirectory, {bool verbose = false})` (`String`): Runs a command synchronously.
- `exec(String executable, List<String> args, {String? cwd, bool fatal = false, bool verbose = false})` (`void`): Executes a process, optionally exiting on failure.

### FileUtils
File system utilities for CI/CD operations.
- `copyDirRecursive(Directory src, Directory dst)` (`void`)
- `countFiles(Directory dir)` (`int`)
- `readFileOr(String path, [String fallback])` (`String`)

### GeminiUtils
Utilities for Gemini CLI integration.
- `geminiAvailable({bool warnOnly = false})` (`bool`)
- `requireGeminiCli()` (`void`)
- `requireApiKey()` (`void`)
- `extractJson(String rawOutput)` (`String`)

### Logger
ANSI-styled console logging for CI/CD commands.
- `header(String msg)`
- `info(String msg)`
- `success(String msg)`
- `warn(String msg)`
- `error(String msg)`

### ReleaseUtils
Utilities for release management.
- `buildReleaseCommitMessage(...)` (`String`): Builds rich commit message.
- `gatherVerifiedContributors(String repoRoot, String prevTag)` (`List<Map<String, String>>`): Uses `gh` and `git` to collect contributors.
- `buildFallbackReleaseNotes(...)` (`String`)
- `addChangelogReferenceLinks(...)` (`void`)

### RepoUtils
- `findRepoRoot()` (`String?`): Finds the repository root by locating `pubspec.yaml` containing the configured package name.

### StepSummary
Utilities for writing to GitHub Actions `$GITHUB_STEP_SUMMARY`.
- `write(String markdown)`
- `artifactLink([String label = 'View all artifacts'])`
- `compareLink(String prevTag, String newTag, [String? label])`
- `ghLink(String label, String path)`
- `releaseLink(String tag)`
- `collapsible(String title, String content, {bool open = false})`

### WorkflowGenerator
Renders CI workflow YAML from a Mustache skeleton template and `config.json`.
- `loadCiConfig(String repoRoot)` (`Map<String, dynamic>?`)
- `render({String? existingContent})` (`String`): Renders template, preserving user sections.
- `validate(Map<String, dynamic> ciConfig)` (`List<String>`)
- `logConfig()` (`void`)

### HookInstaller
Installs and manages git pre-commit hooks for Dart repos.
- `install(String repoRoot, {int lineLength = 120, bool dryRun = false})` (`bool`): Installs or refreshes the pre-commit hook.

### PromptResolver
Resolves paths to prompt scripts within the `runtime_ci_tooling` package.
- `promptScript(String scriptName)` (`String`)
- `resolveToolingPackageRoot()` (`String`)

### ToolInstallers
Cross-platform tool installation utilities.
- `installTool(String tool, {bool dryRun = false})` (`Future<void>`)

