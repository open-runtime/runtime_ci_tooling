# Issue Triage Engine API Reference

This document provides a comprehensive API reference for the Issue Triage Engine, detailing its classes, enums, and top-level functions. Example code blocks are provided to demonstrate typical usage patterns.

## 1. Classes

### `ValidationResult`
Validation result representing the success status and any error messages.

- **Fields**:
  - `bool valid` - Whether the validation was successful.
  - `String path` - Path to the validated file.
  - `List<String> errors` - List of validation error messages.

- **Methods**:
  - `String toString()` - Returns the string representation of validation.

**Example**:
```dart
final result = ValidationResult(
  valid: false,
  path: '.runtime_ci/config.json',
  errors: ['Missing required keys: repository.name']
);
print(result.toString());
```

### `RunContext`
Manages a run-scoped audit trail directory for CI/CD operations. It provides a two-tier design for local development trails and committed per-release audit snapshots.

- **Fields**:
  - `String repoRoot` - The repository root.
  - `String runDir` - Path to the run directory.
  - `String command` - The command that started the run.
  - `DateTime startedAt` - When the run started.
  - `List<String> args` - Command arguments.
  - `String runId` - The run ID (directory name).

- **Constructors**:
  - `factory RunContext.create(String repoRoot, String command, {List<String> args = const []})` - Creates a new run context with a timestamped directory.
  - `factory RunContext.load(String repoRoot, String runDirPath)` - Loads an existing run context.

- **Methods**:
  - `String subdir(String name)` - Gets or creates a subdirectory within the run directory.
  - `void savePrompt(String phase, String prompt)` - Saves a prompt sent to Gemini CLI.
  - `void saveResponse(String phase, String rawResponse)` - Saves the response from Gemini CLI.
  - `void saveArtifact(String phase, String filename, String content)` - Saves a structured artifact.
  - `void saveJsonArtifact(String phase, String filename, Map<String, dynamic> data)` - Saves a JSON artifact.
  - `String artifactPath(String phase, String filename)` - Gets the path for an artifact file.
  - `String? readArtifact(String phase, String filename)` - Reads an artifact file.
  - `bool hasArtifact(String phase, String filename)` - Checks if an artifact exists.
  - `void finalize({int? exitCode})` - Updates the meta.json with completion info.
  - `void archiveForRelease(String version)` - Archives important artifacts for permanent storage.
  - `static String? findLatestRun(String repoRoot, {String? command})` - Finds the most recent run directory for a given command.
  - `static List<Directory> listRuns(String repoRoot)` - Lists all run directories.

**Example**:
```dart
final context = RunContext.create('/path/to/repo', 'triage', args: ['--auto']);
context.savePrompt('investigate', 'Analyze this issue...');
context.saveResponse('investigate', '{"response": "Findings..."}');
context.finalize(exitCode: 0);
```

### `TriageConfig`
Centralized, config-driven loader for the runtime CI tooling pipeline. It dynamically parses `.runtime_ci/config.json` to configure triage thresholds, cross-repo connections, and more.

- **Fields**:
  - `String? loadedFrom` - The resolved path to the config file that was loaded.
  - `bool isConfigured` - Whether this repo has opted into the CI tooling by having a config file.
  - `String repoName` - Dart package name / GitHub repo name.
  - `String repoOwner` - GitHub org or user.
  - `String triagedLabel` - Label indicating issue has been triaged.
  - `String changelogPath` - Path to changelog.
  - `String releaseNotesPath` - Path to release notes.
  - `String gcpProject` - GCP project ID.
  - `String sentryOrganization` - Sentry organization name.
  - `List<String> sentryProjects` - Sentry projects.
  - `bool sentryScanOnPreRelease` - Whether to scan Sentry on pre-release.
  - `int sentryRecentErrorsHours` - Sentry recent errors scan window in hours.
  - `bool preReleaseScanSentry` - Pre-release scan Sentry toggle.
  - `bool preReleaseScanGithub` - Pre-release scan GitHub toggle.
  - `bool postReleaseCloseOwnRepo` - Post-release close own repo toggle.
  - `bool postReleaseCloseCrossRepo` - Post-release close cross repo toggle.
  - `bool postReleaseCommentCrossRepo` - Post-release comment cross repo toggle.
  - `bool postReleaseLinkSentry` - Post-release link Sentry toggle.
  - `bool crossRepoEnabled` - Cross repo enabled toggle.
  - `List<CrossRepoEntry> crossRepoRepos` - List of cross repos.
  - `List<String> crossRepoOrgs` - Cross repo orgs allowlist.
  - `bool crossRepoDiscoveryEnabled` - Cross repo discovery enabled toggle.
  - `List<String> crossRepoDiscoverySearchOrgs` - Cross repo discovery search orgs.
  - `List<String> typeLabels` - Type labels.
  - `List<String> priorityLabels` - Priority labels.
  - `List<String> areaLabels` - Area labels.
  - `double autoCloseThreshold` - Auto close threshold confidence.
  - `double suggestCloseThreshold` - Suggest close threshold confidence.
  - `double commentThreshold` - Comment threshold confidence.
  - `List<String> enabledAgents` - Enabled agents list.
  - `String flashModel` - Gemini flash model.
  - `String proModel` - Gemini pro model.
  - `int maxTurns` - Max turns for Gemini.
  - `int maxConcurrent` - Max concurrent Gemini runs.
  - `int maxRetries` - Max retries for Gemini.
  - `String geminiApiKeyEnv` - Gemini API key environment variable name.
  - `List<String> githubTokenEnvNames` - GitHub token environment variables list.
  - `String gcpSecretName` - GCP secret name.

- **Constructors**:
  - `factory TriageConfig.load()` - Loads config by searching upward from CWD.

- **Methods**:
  - `bool shouldRunAgent(String agentName, String repoRoot)` - Check if a conditional agent should run based on file existence.
  - `String? resolveGeminiApiKey()` - Resolve the Gemini API key from env vars or GCP Secret Manager.
  - `String? resolveGithubToken()` - Resolve a GitHub token from any of the configured env var names.

### `CrossRepoEntry`
Entry defining cross-repo relationship.

- **Fields**:
  - `String owner` - Repository owner.
  - `String repo` - Repository name.
  - `String relationship` - Relationship description.
  - `String fullName` - Full repository name (owner/repo).

### `GeminiResult`
The structured result from a Gemini CLI invocation.

- **Fields**:
  - `String taskId` - Identifier of the task.
  - `String? response` - Gemini's textual response.
  - `Map<String, dynamic>? stats` - Execution stats.
  - `Map<String, dynamic>? error` - Execution error.
  - `int attempts` - Number of attempts made.
  - `int durationMs` - Execution duration in milliseconds.
  - `bool success` - Whether the invocation was successful.
  - `int toolCalls` - Total tool calls made.
  - `int turnsUsed` - Number of turns used.
  - `String errorMessage` - Resolved error message.

**Example**:
```dart
final result = GeminiResult(
  taskId: 'task-123',
  response: '{"agent_id": "duplicate"}',
  success: true,
  durationMs: 4500,
);

if (result.success) {
  print('Task completed with ${result.toolCalls} tool calls.');
}
```

### `GeminiTask`
A single task to execute via Gemini CLI.

- **Fields**:
  - `String id` - Identifier of the task.
  - `String prompt` - Prompt to send to Gemini.
  - `String model` - Model to use.
  - `int maxTurns` - Max turns allowed.
  - `List<String> allowedTools` - Tools Gemini is allowed to use.
  - `List<String> fileIncludes` - Files to include with prompt.
  - `String? workingDirectory` - Directory to run Gemini in.
  - `bool sandbox` - Whether to use sandbox mode.
  - `String? auditDir` - Directory to save prompts and responses.

**Example**:
```dart
final task = GeminiTask(
  id: 'issue-42-code',
  prompt: 'Analyze issue #42 code references...',
  model: 'gemini-3.1-pro-preview',
  allowedTools: ['run_shell_command(git)'],
);
```

### `GeminiRunner`
Manages parallel Gemini CLI execution with retry and rate limiting.

- **Fields**:
  - `int maxConcurrent` - Maximum concurrent tasks.
  - `int maxRetries` - Maximum retry attempts.
  - `Duration initialBackoff` - Initial backoff duration.
  - `Duration maxBackoff` - Maximum backoff duration.
  - `bool verbose` - Verbose logging toggle.

- **Methods**:
  - `Future<List<GeminiResult>> executeBatch(List<GeminiTask> tasks)` - Execute a batch of tasks in parallel.

### `TriageTask`
A single investigation or action task within the game plan.

- **Fields**:
  - `String id` - Task identifier.
  - `AgentType agent` - Type of the agent handling the task.
  - `TaskStatus status` - Status of the task.
  - `String? error` - Error message if task failed.
  - `Map<String, dynamic>? result` - JSON result of the task.

- **Constructors**:
  - `factory TriageTask.fromJson(Map<String, dynamic> json)` - Constructs a TriageTask from JSON.

- **Methods**:
  - `Map<String, dynamic> toJson()` - Converts TriageTask to JSON map.

### `IssuePlan`
The triage plan for a single GitHub issue.

- **Fields**:
  - `int number` - Issue number.
  - `String title` - Issue title.
  - `String author` - Issue author.
  - `List<String> existingLabels` - Existing labels.
  - `List<TriageTask> tasks` - Triage tasks for this issue.
  - `Map<String, dynamic>? decision` - Action decision.
  - `bool investigationComplete` - Whether all investigation tasks have completed.

- **Constructors**:
  - `factory IssuePlan.fromJson(Map<String, dynamic> json)` - Constructs an IssuePlan from JSON.

- **Methods**:
  - `Map<String, dynamic> toJson()` - Converts IssuePlan to JSON map.

**Example**:
```dart
final plan = IssuePlan(
  number: 42,
  title: 'Bug in parsing',
  author: 'dev123',
  tasks: [
    TriageTask(id: 'task-1', agent: AgentType.codeAnalysis)
  ],
);
```

### `LinkSpec`
A link to create between two entities.

- **Fields**:
  - `String sourceType` - Type of source entity.
  - `String sourceId` - ID of source entity.
  - `String targetType` - Type of target entity.
  - `String targetId` - ID of target entity.
  - `String description` - Link description.
  - `bool applied` - Whether the link has been applied.

- **Constructors**:
  - `factory LinkSpec.fromJson(Map<String, dynamic> json)` - Constructs a LinkSpec from JSON.

- **Methods**:
  - `Map<String, dynamic> toJson()` - Converts LinkSpec to JSON map.

### `GamePlan`
The top-level game plan that orchestrates the entire triage pipeline.

- **Fields**:
  - `String planId` - Identifier of the plan.
  - `DateTime createdAt` - Plan creation date.
  - `List<IssuePlan> issues` - Issues to process.
  - `List<LinkSpec> linksToCreate` - Links to create.

- **Constructors**:
  - `factory GamePlan.fromJson(Map<String, dynamic> json)` - Constructs a GamePlan from JSON.
  - `factory GamePlan.forIssues(List<Map<String, dynamic>> issueData)` - Creates a default game plan for a list of issues.

- **Methods**:
  - `Map<String, dynamic> toJson()` - Converts GamePlan to JSON map.
  - `String toJsonString()` - Converts GamePlan to formatted JSON string.

### `InvestigationResult`
Data class for investigation agent results.

- **Fields**:
  - `String agentId` - Agent identifier.
  - `int issueNumber` - Issue number investigated.
  - `double confidence` - Confidence score.
  - `String summary` - Finding summary.
  - `List<String> evidence` - Evidence supporting findings.
  - `List<String> recommendedLabels` - Labels recommended to add.
  - `String? suggestedComment` - Suggested comment text.
  - `bool suggestClose` - Suggest close toggle.
  - `String? closeReason` - Close reason.
  - `List<RelatedEntity> relatedEntities` - Related entities found.
  - `int turnsUsed` - Agent turns used.
  - `int toolCallsMade` - Agent tool calls made.
  - `int durationMs` - Duration of investigation.

- **Constructors**:
  - `factory InvestigationResult.fromJson(Map<String, dynamic> json)` - Constructs an InvestigationResult from JSON.
  - `factory InvestigationResult.failed({required String agentId, required int issueNumber, required String error})` - Creates a failed result when an agent errors out.

- **Methods**:
  - `Map<String, dynamic> toJson()` - Converts InvestigationResult to JSON map.

### `RelatedEntity`
A reference to a related entity found during investigation.

- **Fields**:
  - `String type` - Entity type (e.g., pr, issue, commit, file).
  - `String id` - Entity ID.
  - `String description` - Entity description.
  - `double relevance` - Relevance score (0.0-1.0).

- **Constructors**:
  - `factory RelatedEntity.fromJson(Map<String, dynamic> json)` - Constructs a RelatedEntity from JSON.

- **Methods**:
  - `Map<String, dynamic> toJson()` - Converts RelatedEntity to JSON map.

### `TriageAction`
A concrete action to take on a GitHub issue.

- **Fields**:
  - `ActionType type` - Action type.
  - `String description` - Action description.
  - `Map<String, dynamic> parameters` - Action parameters.
  - `bool executed` - Whether action was executed.
  - `bool verified` - Whether action was verified.
  - `String? error` - Action error message.

- **Constructors**:
  - `factory TriageAction.fromJson(Map<String, dynamic> json)` - Constructs a TriageAction from JSON.

- **Methods**:
  - `Map<String, dynamic> toJson()` - Converts TriageAction to JSON map.

### `TriageDecision`
The aggregated triage decision for a single issue.

- **Fields**:
  - `int issueNumber` - Issue number.
  - `double aggregateConfidence` - Aggregated confidence score.
  - `RiskLevel riskLevel` - Assessed risk level.
  - `String rationale` - Decision rationale.
  - `List<TriageAction> actions` - Actions to take.
  - `List<InvestigationResult> investigationResults` - Associated investigation results.

- **Constructors**:
  - `factory TriageDecision.fromJson(Map<String, dynamic> json)` - Constructs a TriageDecision from JSON.
  - `factory TriageDecision.fromResults({required int issueNumber, required List<InvestigationResult> results})` - Creates a decision from aggregated investigation results.

- **Methods**:
  - `Map<String, dynamic> toJson()` - Converts TriageDecision to JSON map.

### `VerificationCheck`
Represents a single verification check on a Triage action.

- **Fields**:
  - `String name` - Name of the check.
  - `bool passed` - Passed status.
  - `String message` - Check output message.

- **Constructors**:
  - `VerificationCheck({required String name, required bool passed, required String message})` - Constructs a VerificationCheck.

- **Methods**:
  - `Map<String, dynamic> toJson()` - Converts VerificationCheck to JSON map.

### `IssueVerification`
Represents verification outcome for an issue.

- **Fields**:
  - `int issueNumber` - The issue number.
  - `bool passed` - Whether all checks passed.
  - `List<VerificationCheck> checks` - Performed verification checks.

- **Constructors**:
  - `IssueVerification({required int issueNumber, required bool passed, required List<VerificationCheck> checks})` - Constructs an IssueVerification.

- **Methods**:
  - `Map<String, dynamic> toJson()` - Converts IssueVerification to JSON map.

### `VerificationReport`
Final report holding all issue verifications.

- **Fields**:
  - `List<IssueVerification> verifications` - List of issue verifications.
  - `DateTime timestamp` - Report timestamp.
  - `bool allPassed` - Whether all verifications passed.

- **Constructors**:
  - `VerificationReport({required List<IssueVerification> verifications, required DateTime timestamp})` - Constructs a VerificationReport.

- **Methods**:
  - `Map<String, dynamic> toJson()` - Converts VerificationReport to JSON map.

## 2. Enums

### `TaskStatus`
Represents the status of a triage task.
- `pending`: Task is waiting to start.
- `running`: Task is currently executing.
- `completed`: Task finished successfully.
- `failed`: Task encountered an error.
- `skipped`: Task was skipped.

### `AgentType`
Represents the type of investigation agent.
- `codeAnalysis`: Code Analysis Agent.
- `prCorrelation`: PR Correlation Agent.
- `duplicate`: Duplicate Detection Agent.
- `sentiment`: Comment Sentiment Agent.
- `changelog`: Changelog Agent.

### `RiskLevel`
Represents the risk level determined from triage confidence.
- `low`: Low risk.
- `medium`: Medium risk.
- `high`: High risk.

### `ActionType`
Represents the type of action to take.
- `label`: Add a label.
- `comment`: Add a comment.
- `close`: Close the issue.
- `linkPr`: Link to a pull request.
- `linkIssue`: Link to a related issue.
- `none`: No action required.

## 3. Extensions
*(None exist in the provided source code)*

## 4. Top-Level Functions

### `buildGitHubMcpConfig`
- **Signature**: `Map<String, dynamic> buildGitHubMcpConfig({String? token})`
- **Description**: Builds the GitHub MCP server configuration for `.gemini/settings.json`.

### `buildSentryMcpConfig`
- **Signature**: `Map<String, dynamic> buildSentryMcpConfig()`
- **Description**: Builds the Sentry MCP server configuration (remote, OAuth-based).

### `readSettings`
- **Signature**: `Map<String, dynamic> readSettings(String repoRoot)`
- **Description**: Reads the current `.gemini/settings.json` file.

### `writeSettings`
- **Signature**: `void writeSettings(String repoRoot, Map<String, dynamic> settings)`
- **Description**: Writes updated settings to `.gemini/settings.json`.

### `ensureMcpConfigured`
- **Signature**: `bool ensureMcpConfigured(String repoRoot)`
- **Description**: Ensures MCP servers are configured in `.gemini/settings.json`. Returns true if configuration was updated, false if already configured.

### `validateMcpServers`
- **Signature**: `Future<Map<String, bool>> validateMcpServers(String repoRoot)`
- **Description**: Validates that required MCP servers are configured and accessible.

### `validateJsonFile`
- **Signature**: `ValidationResult validateJsonFile(String path, List<String> requiredKeys)`
- **Description**: Validates that a JSON file exists, is valid JSON, and contains required keys.

### `validateGamePlan`
- **Signature**: `ValidationResult validateGamePlan(String path)`
- **Description**: Validates a game plan JSON structure.

### `validateInvestigationResult`
- **Signature**: `ValidationResult validateInvestigationResult(String path)`
- **Description**: Validates an investigation result JSON structure.

### `writeJson`
- **Signature**: `void writeJson(String path, Map<String, dynamic> data)`
- **Description**: Writes a JSON object to a file with pretty formatting.

### `readJson`
- **Signature**: `Map<String, dynamic>? readJson(String path)`
- **Description**: Reads and parses a JSON file, returning null on error.

### `reloadConfig`
- **Signature**: `void reloadConfig()`
- **Description**: Reload config from disk (useful after modifications).

### `buildTask`
- **Signature**: `GeminiTask buildTask(IssuePlan issue, String repoRoot, {String? resultsDir})`
- **Description**: Builds a Gemini task for agent investigation. (Implemented by all specific agents like code analysis, duplicate detection, PR correlation, sentiment, changelog).

### `postReleaseTriage`
- **Signature**: `Future<void> postReleaseTriage({required String newVersion, required String releaseTag, required String releaseUrl, required String manifestPath, required String repoRoot, required String runDir, bool verbose = false})`
- **Description**: Run post-release actions based on the pre-release issue manifest.

### `act`
- **Signature**: `Future<List<TriageDecision>> act(GamePlan plan, Map<int, List<InvestigationResult>> investigationResults, String repoRoot, {required String runDir})`
- **Description**: Apply triage decisions for all issues in the game plan.

### `crossRepoLink`
- **Signature**: `Future<void> crossRepoLink(GamePlan plan, List<TriageDecision> decisions, String repoRoot, {required String runDir})`
- **Description**: Search and link related issues across configured dependent repos.

### `investigate`
- **Signature**: `Future<Map<int, List<InvestigationResult>>> investigate(GamePlan plan, String repoRoot, {required String runDir, bool verbose = false})`
- **Description**: Run investigation agents for every issue in the game plan.

### `link`
- **Signature**: `Future<void> link(GamePlan plan, List<TriageDecision> decisions, String repoRoot, {required String runDir})`
- **Description**: Cross-link all triaged issues to related artifacts.

### `planSingleIssue`
- **Signature**: `Future<GamePlan> planSingleIssue(int issueNumber, String repoRoot, {required String runDir})`
- **Description**: Creates a game plan for a single issue.

### `planAutoTriage`
- **Signature**: `Future<GamePlan> planAutoTriage(String repoRoot, {required String runDir})`
- **Description**: Creates a game plan for all open untriaged issues (auto mode).

### `loadPlan`
- **Signature**: `GamePlan? loadPlan({String? runDir})`
- **Description**: Loads an existing game plan from a run directory.

### `preReleaseTriage`
- **Signature**: `Future<String> preReleaseTriage({required String prevTag, required String newVersion, required String repoRoot, required String runDir, bool verbose = false})`
- **Description**: Scan issues and produce an issue manifest for the upcoming release.

### `verify`
- **Signature**: `Future<VerificationReport> verify(GamePlan plan, List<TriageDecision> decisions, String repoRoot, {required String runDir})`
- **Description**: Verify that all triage actions were applied correctly.

### `main`
- **Signature**: `Future<void> main(List<String> args)`
- **Description**: Triage CLI entry point. Orchestrates the 6-phase triage pipeline.
