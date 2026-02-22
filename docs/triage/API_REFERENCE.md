# Issue Triage Engine API Reference

## 1. Classes

### Models

#### **TriageAction** -- A concrete action to take on a GitHub issue.
- **Fields:**
  - `ActionType type`: The type of action to perform.
  - `String description`: Human-readable description of the action.
  - `Map<String, dynamic> parameters`: Action-specific parameters (e.g., labels, comment body).
  - `bool executed`: Whether the action has been executed.
  - `bool verified`: Whether the action's execution has been verified.
  - `String? error`: Error message if execution failed.
- **Constructors:**
  - `TriageAction({required ActionType type, required String description, Map<String, dynamic> parameters, bool executed, bool verified, String? error})`
  - `TriageAction.fromJson(Map<String, dynamic> json)` (Factory)
- **Methods:**
  - `Map<String, dynamic> toJson()`: Serializes the action to JSON.

**Example Usage:**
```dart
final action = TriageAction(
  type: ActionType.comment,
  description: 'Post informational findings',
  parameters: {'body': 'The issue seems resolved.'},
)
  ..executed = false
  ..verified = false;
```

#### **TriageDecision** -- The aggregated triage decision for a single issue.
- **Fields:**
  - `int issueNumber`: The GitHub issue number.
  - `double aggregateConfidence`: The combined confidence score from all investigation agents.
  - `RiskLevel riskLevel`: The computed risk level of applying the actions.
  - `String rationale`: Human-readable explanation of how the decision was reached.
  - `List<TriageAction> actions`: The list of concrete actions to execute.
  - `List<InvestigationResult> investigationResults`: The raw results from the agents.
- **Constructors:**
  - `TriageDecision({required int issueNumber, required double aggregateConfidence, required RiskLevel riskLevel, required String rationale, required List<TriageAction> actions, List<InvestigationResult> investigationResults})`
  - `TriageDecision.fromJson(Map<String, dynamic> json)` (Factory)
  - `TriageDecision.fromResults({required int issueNumber, required List<InvestigationResult> results})` (Factory): Creates a decision and formulates actions based on aggregated investigation results.
- **Methods:**
  - `Map<String, dynamic> toJson()`: Serializes the decision to JSON.

**Example Usage:**
```dart
final decision = TriageDecision.fromResults(
  issueNumber: 42,
  results: [investigationResult],
);
```

#### **TriageTask** -- A single investigation or action task within the game plan.
- **Fields:**
  - `String id`: Unique identifier for the task.
  - `AgentType agent`: The type of agent assigned to this task.
  - `TaskStatus status`: Current execution status.
  - `String? error`: Error message if the task failed.
  - `Map<String, dynamic>? result`: The JSON result produced by the agent.
- **Constructors:**
  - `TriageTask({required String id, required AgentType agent, TaskStatus status, String? error, Map<String, dynamic>? result})`
  - `TriageTask.fromJson(Map<String, dynamic> json)` (Factory)
- **Methods:**
  - `Map<String, dynamic> toJson()`: Serializes the task to JSON.

**Example Usage:**
```dart
final task = TriageTask(
  id: 'issue-42-code',
  agent: AgentType.codeAnalysis,
)
  ..status = TaskStatus.pending
  ..result = {'summary': 'Fix found'};
```

#### **IssuePlan** -- The triage plan for a single GitHub issue.
- **Fields:**
  - `int number`: The GitHub issue number.
  - `String title`: The title of the issue.
  - `String author`: The author of the issue.
  - `List<String> existingLabels`: Labels currently applied to the issue.
  - `List<TriageTask> tasks`: Investigation tasks scheduled for this issue.
  - `Map<String, dynamic>? decision`: The serialized triage decision once made.
  - `bool investigationComplete` (Getter): Whether all tasks have completed or failed.
- **Constructors:**
  - `IssuePlan({required int number, required String title, required String author, List<String> existingLabels, required List<TriageTask> tasks, Map<String, dynamic>? decision})`
  - `IssuePlan.fromJson(Map<String, dynamic> json)` (Factory)
- **Methods:**
  - `Map<String, dynamic> toJson()`: Serializes the issue plan to JSON.

**Example Usage:**
```dart
final issue = IssuePlan(
  number: 42,
  title: 'Null pointer exception in startup',
  author: 'johndoe',
  existingLabels: ['bug'],
  tasks: [TriageTask(id: 'task-1', agent: AgentType.codeAnalysis)],
)..decision = {'resolved': true};
```

#### **LinkSpec** -- A link to create between two entities (issue, PR, changelog, release notes).
- **Fields:**
  - `String sourceType`: The source entity type (e.g., 'issue').
  - `String sourceId`: The ID of the source entity.
  - `String targetType`: The target entity type.
  - `String targetId`: The ID of the target entity.
  - `String description`: Description of the relationship.
  - `bool applied`: Whether the link has been successfully applied.
- **Constructors:**
  - `LinkSpec({required String sourceType, required String sourceId, required String targetType, required String targetId, required String description, bool applied})`
  - `LinkSpec.fromJson(Map<String, dynamic> json)` (Factory)
- **Methods:**
  - `Map<String, dynamic> toJson()`: Serializes the link specification to JSON.

**Example Usage:**
```dart
final link = LinkSpec(
  sourceType: 'issue',
  sourceId: '42',
  targetType: 'pr',
  targetId: '99',
  description: 'Fixed by PR #99',
)..applied = false;
```

#### **GamePlan** -- The top-level game plan that orchestrates the entire triage pipeline.
- **Fields:**
  - `String planId`: Unique identifier for the game plan.
  - `DateTime createdAt`: When the plan was created.
  - `List<IssuePlan> issues`: Issue plans included in this run.
  - `List<LinkSpec> linksToCreate`: Links to be created during the link phase.
- **Constructors:**
  - `GamePlan({required String planId, required DateTime createdAt, required List<IssuePlan> issues, List<LinkSpec> linksToCreate})`
  - `GamePlan.fromJson(Map<String, dynamic> json)` (Factory)
  - `GamePlan.forIssues(List<Map<String, dynamic>> issueData)` (Factory): Creates a default game plan for a list of issue data objects.
- **Methods:**
  - `Map<String, dynamic> toJson()`: Serializes the game plan to JSON.
  - `String toJsonString()`: Returns a pretty-printed JSON string of the game plan.

**Example Usage:**
```dart
final plan = GamePlan(
  planId: 'triage-run-1',
  createdAt: DateTime.now(),
  issues: [
    IssuePlan(
      number: 42,
      title: 'Bug report',
      author: 'alice',
      tasks: [],
    )
  ],
);
```

#### **InvestigationResult** -- Data class for investigation agent results.
- **Fields:**
  - `String agentId`: The ID of the agent that produced this result.
  - `int issueNumber`: The targeted GitHub issue number.
  - `double confidence`: The agent's confidence score (0.0 to 1.0).
  - `String summary`: A brief summary of the findings.
  - `List<String> evidence`: Supporting evidence for the findings.
  - `List<String> recommendedLabels`: Labels suggested by the agent.
  - `String? suggestedComment`: An optional comment suggested by the agent.
  - `bool suggestClose`: Whether the agent suggests closing the issue.
  - `String? closeReason`: Reason for closure if suggested.
  - `List<RelatedEntity> relatedEntities`: Other entities related to this issue.
  - `int turnsUsed`: Number of Gemini turns used.
  - `int toolCallsMade`: Number of tool calls made by the agent.
  - `int durationMs`: Duration of the agent's execution.
- **Constructors:**
  - `InvestigationResult({required String agentId, required int issueNumber, required double confidence, required String summary, List<String> evidence, List<String> recommendedLabels, String? suggestedComment, bool suggestClose, String? closeReason, List<RelatedEntity> relatedEntities, int turnsUsed, int toolCallsMade, int durationMs})`
  - `InvestigationResult.fromJson(Map<String, dynamic> json)` (Factory)
  - `InvestigationResult.failed({required String agentId, required int issueNumber, required String error})` (Factory): Creates a failed result when an agent errors out.
- **Methods:**
  - `Map<String, dynamic> toJson()`: Serializes the investigation result to JSON.

**Example Usage:**
```dart
final result = InvestigationResult(
  agentId: 'code_analysis',
  issueNumber: 42,
  confidence: 0.85,
  summary: 'Code fix found in recent commits.',
  evidence: ['Commit abc1234 references this issue.'],
  recommendedLabels: ['bug', 'resolved'],
  suggestedComment: 'Looks like this was fixed in abc1234.',
  suggestClose: true,
  closeReason: 'completed',
  relatedEntities: [
    RelatedEntity(
      type: 'commit',
      id: 'abc1234',
      description: 'Fixes the bug',
      relevance: 0.9,
    ),
  ],
);
```

#### **RelatedEntity** -- A reference to a related entity (PR, issue, commit, file) found during investigation.
- **Fields:**
  - `String type`: The type of entity ('pr', 'issue', 'commit', 'file').
  - `String id`: The identifier for the entity.
  - `String description`: Description of the entity.
  - `double relevance`: How relevant this entity is (0.0 to 1.0).
- **Constructors:**
  - `RelatedEntity({required String type, required String id, required String description, double relevance})`
  - `RelatedEntity.fromJson(Map<String, dynamic> json)` (Factory)
- **Methods:**
  - `Map<String, dynamic> toJson()`: Serializes the related entity to JSON.

**Example Usage:**
```dart
final entity = RelatedEntity(
  type: 'pr',
  id: '99',
  description: 'Implements feature XYZ',
  relevance: 0.85,
);
```

#### **VerificationCheck** -- Represents a single check performed during verification.
- **Fields:**
  - `String name`: Name of the check.
  - `bool passed`: Whether the check passed successfully.
  - `String message`: Descriptive result message.
- **Constructors:**
  - `VerificationCheck({required String name, required bool passed, required String message})`
- **Methods:**
  - `Map<String, dynamic> toJson()`: Serializes the verification check to JSON.

#### **IssueVerification** -- Verification result for a single issue.
- **Fields:**
  - `int issueNumber`: The GitHub issue number.
  - `bool passed`: Whether all checks for this issue passed.
  - `List<VerificationCheck> checks`: The individual checks performed.
- **Constructors:**
  - `IssueVerification({required int issueNumber, required bool passed, required List<VerificationCheck> checks})`
- **Methods:**
  - `Map<String, dynamic> toJson()`: Serializes the issue verification to JSON.

#### **VerificationReport** -- Aggregated report of all verifications.
- **Fields:**
  - `List<IssueVerification> verifications`: Verifications for all tested issues.
  - `DateTime timestamp`: When the report was generated.
  - `bool allPassed` (Getter): True if all issue verifications passed.
- **Constructors:**
  - `VerificationReport({required List<IssueVerification> verifications, required DateTime timestamp})`
- **Methods:**
  - `Map<String, dynamic> toJson()`: Serializes the verification report to JSON.

### Utilities

#### **RunContext** -- Manages a run-scoped audit trail directory for CI/CD operations.
- **Fields:**
  - `String repoRoot`: The root path of the repository.
  - `String runDir`: The path to the run's audit directory.
  - `String command`: The CLI command executed.
  - `DateTime startedAt`: Timestamp of when the run started.
  - `List<String> args`: The arguments passed to the command.
  - `String runId` (Getter): The unique identifier (directory name) of the run.
- **Constructors:**
  - `RunContext.create(String repoRoot, String command, {List<String> args})` (Factory): Creates a new run context with a timestamped directory.
  - `RunContext.load(String repoRoot, String runDirPath)` (Factory): Loads an existing run context from a run directory.
- **Methods:**
  - `String subdir(String name)`: Get or create a subdirectory within the run directory.
  - `void savePrompt(String phase, String prompt)`: Save a prompt sent to Gemini CLI.
  - `void saveResponse(String phase, String rawResponse)`: Save the response from Gemini CLI.
  - `void saveArtifact(String phase, String filename, String content)`: Save a text artifact.
  - `void saveJsonArtifact(String phase, String filename, Map<String, dynamic> data)`: Save a JSON artifact.
  - `String artifactPath(String phase, String filename)`: Get the path for an artifact file.
  - `String? readArtifact(String phase, String filename)`: Read an artifact file content.
  - `bool hasArtifact(String phase, String filename)`: Check if an artifact exists.
  - `void finalize({int? exitCode})`: Update the meta.json with completion info.
  - `void archiveForRelease(String version)`: Archive important artifacts for a release snapshot.
  - `static String? findLatestRun(String repoRoot, {String? command})`: Find the most recent run directory.
  - `static List<Directory> listRuns(String repoRoot)`: List all run directories.

#### **ValidationResult** -- Result of a JSON validation operation.
- **Fields:**
  - `bool valid`: Whether the validation succeeded.
  - `String path`: Path to the file validated.
  - `List<String> errors`: Validation error messages if any.
- **Constructors:**
  - `ValidationResult({required bool valid, required String path, List<String> errors})`

#### **TriageConfig** -- Centralized, config-driven loader for the runtime CI tooling pipeline.
- **Fields:**
  - `String? loadedFrom`: The resolved path to the loaded config file.
  - `bool isConfigured` (Getter): Whether this repo has a config file.
  - `String repoName` (Getter): Repository name.
  - `String repoOwner` (Getter): Repository owner.
  - `String triagedLabel` (Getter): Label applied when triage is complete.
  - `String changelogPath` (Getter): Path to the changelog file.
  - `String releaseNotesPath` (Getter): Path to the release notes output.
  - `String gcpProject` (Getter): GCP project ID for Secret Manager.
  - `String sentryOrganization` (Getter): Sentry organization name.
  - `List<String> sentryProjects` (Getter): Monitored Sentry projects.
  - `bool sentryScanOnPreRelease` (Getter): Whether to scan Sentry during pre-release.
  - `int sentryRecentErrorsHours` (Getter): Number of hours to look back for Sentry errors.
  - `bool preReleaseScanSentry` (Getter): Pre-release Sentry scan flag.
  - `bool preReleaseScanGithub` (Getter): Pre-release GitHub issue scan flag.
  - `bool postReleaseCloseOwnRepo` (Getter): Whether to close own-repo issues post-release.
  - `bool postReleaseCloseCrossRepo` (Getter): Whether to close cross-repo issues post-release.
  - `bool postReleaseCommentCrossRepo` (Getter): Whether to comment on cross-repo issues post-release.
  - `bool postReleaseLinkSentry` (Getter): Whether to link Sentry issues to the release.
  - `bool crossRepoEnabled` (Getter): Whether cross-repository functionality is enabled.
  - `List<CrossRepoEntry> crossRepoRepos` (Getter): Defined cross-repo dependencies.
  - `List<String> typeLabels` (Getter): Configured issue type labels.
  - `List<String> priorityLabels` (Getter): Configured issue priority labels.
  - `List<String> areaLabels` (Getter): Configured issue area labels.
  - `double autoCloseThreshold` (Getter): Confidence threshold to auto-close.
  - `double suggestCloseThreshold` (Getter): Confidence threshold to suggest closure.
  - `double commentThreshold` (Getter): Confidence threshold to comment.
  - `List<String> enabledAgents` (Getter): The agents enabled in the pipeline.
  - `String flashModel` (Getter): The Gemini Flash model identifier.
  - `String proModel` (Getter): The Gemini Pro model identifier.
  - `int maxTurns` (Getter): Max agent interaction turns.
  - `int maxConcurrent` (Getter): Maximum concurrent agent tasks.
  - `int maxRetries` (Getter): Maximum agent retries.
  - `String geminiApiKeyEnv` (Getter): The environment variable containing the Gemini key.
  - `List<String> githubTokenEnvNames` (Getter): Allowed environment variables for GitHub tokens.
  - `String gcpSecretName` (Getter): GCP secret name containing API keys.
- **Constructors:**
  - `TriageConfig.load()` (Factory): Loads config by searching upward from CWD.
- **Methods:**
  - `bool shouldRunAgent(String agentName, String repoRoot)`: Check if an agent should run based on files/config.
  - `String? resolveGeminiApiKey()`: Resolves the Gemini API key from env/secret manager.
  - `String? resolveGithubToken()`: Resolves a GitHub token from env/secret manager.

#### **CrossRepoEntry** -- Details for a cross-repository configuration.
- **Fields:**
  - `String owner`: The target repo owner.
  - `String repo`: The target repo name.
  - `String relationship`: Described relationship to this repository.
  - `String fullName` (Getter): Computed owner/repo string.
- **Constructors:**
  - `CrossRepoEntry({required String owner, required String repo, required String relationship})`

#### **GeminiResult** -- The structured result from a Gemini CLI invocation.
- **Fields:**
  - `String taskId`: Task ID for this result.
  - `String? response`: The string response text.
  - `Map<String, dynamic>? stats`: Output statistics from Gemini.
  - `Map<String, dynamic>? error`: Output error information from Gemini.
  - `int attempts`: How many attempts were made.
  - `int durationMs`: Processing duration in ms.
  - `bool success`: Whether the invocation succeeded.
  - `int toolCalls` (Getter): Total tool calls made.
  - `int turnsUsed` (Getter): Proxy for turns used, mapping to tool calls.
  - `String errorMessage` (Getter): Extracted error message.
- **Constructors:**
  - `GeminiResult({required String taskId, String? response, Map<String, dynamic>? stats, Map<String, dynamic>? error, int attempts = 1, int durationMs = 0, required bool success})`

#### **GeminiTask** -- A single task to execute via Gemini CLI.
- **Fields:**
  - `String id`: Unique task ID.
  - `String prompt`: The prompt string to execute.
  - `String model`: Target Gemini model.
  - `int maxTurns`: Max allowed turns.
  - `List<String> allowedTools`: Tools to explicitly enable.
  - `List<String> fileIncludes`: Files to pass to Gemini via @include.
  - `String? workingDirectory`: Path to execute the task in.
  - `bool sandbox`: Whether to use the Gemini CLI sandbox.
  - `String? auditDir`: Optional directory to log prompts and responses.
- **Constructors:**
  - `GeminiTask({required String id, required String prompt, String model = kDefaultFlashModel, int maxTurns = kDefaultMaxTurns, List<String> allowedTools = const ['run_shell_command(git)', 'run_shell_command(gh)'], List<String> fileIncludes = const [], String? workingDirectory, bool sandbox = false, String? auditDir})`

#### **GeminiRunner** -- Manages parallel Gemini CLI execution with retry and rate limiting.
- **Fields:**
  - `int maxConcurrent`: Maximum active tasks.
  - `int maxRetries`: Max backoff retries per task.
  - `Duration initialBackoff`: Starting backoff duration.
  - `Duration maxBackoff`: Capped backoff duration.
  - `bool verbose`: Verbosity flag.
- **Constructors:**
  - `GeminiRunner({int maxConcurrent = kDefaultMaxConcurrent, int maxRetries = kDefaultMaxRetries, Duration initialBackoff = kDefaultInitialBackoff, Duration maxBackoff = kDefaultMaxBackoff, bool verbose = false})`
- **Methods:**
  - `Future<List<GeminiResult>> executeBatch(List<GeminiTask> tasks)`: Execute a batch of tasks in parallel with concurrency limiting.

**Example Usage:**
```dart
final runner = GeminiRunner(maxConcurrent: 2, maxRetries: 3);
final results = await runner.executeBatch([
  GeminiTask(id: 'task1', prompt: 'Analyze this code'),
]);
```

## 2. Enums

#### **TaskStatus** -- Represents the current status of a triage task.
- `pending`: Task is waiting to be executed.
- `running`: Task is actively running.
- `completed`: Task finished successfully.
- `failed`: Task encountered an error.
- `skipped`: Task was skipped (e.g. already completed).

#### **AgentType** -- Identifies the specific agent to run for an investigation task.
- `codeAnalysis`: The Code Analysis Agent.
- `prCorrelation`: The PR Correlation Agent.
- `duplicate`: The Duplicate Detection Agent.
- `sentiment`: The Comment Sentiment Agent.
- `changelog`: The Changelog/Release Agent.

#### **RiskLevel** -- Assessed risk level of a triage decision.
- `low`: Low confidence or impact.
- `medium`: Medium confidence, suggest closure.
- `high`: High confidence, auto-close appropriate.

#### **ActionType** -- Specific action to be taken on an issue.
- `label`: Apply GitHub labels.
- `comment`: Post a comment.
- `close`: Close the issue.
- `linkPr`: Add a link to a related PR.
- `linkIssue`: Add a link to a related issue.
- `none`: No action.

## 3. Extensions

*(No public extensions exist in this module.)*

## 4. Top-Level Functions

#### `double get kCloseThreshold`
- **Description:** Gets the confidence threshold (from config) above which an issue will be automatically closed.

#### `double get kSuggestCloseThreshold`
- **Description:** Gets the confidence threshold (from config) above which a suggestion to close will be posted.

#### `double get kCommentThreshold`
- **Description:** Gets the confidence threshold (from config) above which an informational comment is posted.

#### `ValidationResult validateJsonFile(String path, List<String> requiredKeys)`
- **Description:** Validates that a JSON file exists, is valid JSON, and contains the specified required keys.

#### `ValidationResult validateGamePlan(String path)`
- **Description:** Validates that a file represents a structurally sound game plan JSON structure.

#### `ValidationResult validateInvestigationResult(String path)`
- **Description:** Validates that a file represents a structurally sound investigation result JSON structure.

#### `void writeJson(String path, Map<String, dynamic> data)`
- **Description:** Writes a JSON map to a file with pretty formatting (2 spaces).

#### `Map<String, dynamic>? readJson(String path)`
- **Description:** Reads and parses a JSON file, returning null if it fails or doesn't exist.

#### `Map<String, dynamic> buildGitHubMcpConfig({String? token})`
- **Description:** Builds the GitHub MCP server configuration map for `.gemini/settings.json`.

#### `Map<String, dynamic> buildSentryMcpConfig()`
- **Description:** Builds the Sentry MCP server configuration map (remote, OAuth-based).

#### `Map<String, dynamic> readSettings(String repoRoot)`
- **Description:** Reads the current `.gemini/settings.json` file.

#### `void writeSettings(String repoRoot, Map<String, dynamic> settings)`
- **Description:** Writes an updated settings map to `.gemini/settings.json`.

#### `bool ensureMcpConfigured(String repoRoot)`
- **Description:** Ensures GitHub and Sentry MCP servers are configured in `.gemini/settings.json`.

#### `Future<Map<String, bool>> validateMcpServers(String repoRoot)`
- **Description:** Validates that required MCP servers are configured and accessible via Docker.

#### `TriageConfig get config`
- **Description:** Gets the singleton configuration instance, lazy-loading it from disk on first access.

#### `void reloadConfig()`
- **Description:** Forces a reload of the triage configuration from disk.

#### `Future<List<TriageDecision>> act(GamePlan plan, Map<int, List<InvestigationResult>> investigationResults, String repoRoot, {required String runDir})`
- **Description:** Phase 3: Applies triage decisions for all issues in the game plan based on investigation results.

#### `Future<void> crossRepoLink(GamePlan plan, List<TriageDecision> decisions, String repoRoot, {required String runDir})`
- **Description:** Phase 5b: Searches for related issues in configured dependent repositories and posts cross-references.

#### `Future<Map<int, List<InvestigationResult>>> investigate(GamePlan plan, String repoRoot, {required String runDir, bool verbose = false})`
- **Description:** Phase 2: Dispatches investigation agents in parallel and writes results to run-scoped directories.

#### `Future<void> link(GamePlan plan, List<TriageDecision> decisions, String repoRoot, {required String runDir})`
- **Description:** Phase 5: Creates bidirectional references between issues, PRs, changelogs, release notes, and documentation.

#### `Future<GamePlan> planSingleIssue(int issueNumber, String repoRoot, {required String runDir})`
- **Description:** Phase 1: Creates a game plan targeting a single specific issue.

**Example Usage:**
```dart
final plan = await planSingleIssue(42, '/path/to/repo', runDir: '/tmp/run');
```

#### `Future<GamePlan> planAutoTriage(String repoRoot, {required String runDir})`
- **Description:** Phase 1: Creates a game plan for all discovered open untriaged issues.

#### `GamePlan? loadPlan({String? runDir})`
- **Description:** Loads an existing game plan from a specified run directory or a default temporary location.

#### `Future<void> postReleaseTriage({required String newVersion, required String releaseTag, required String releaseUrl, required String manifestPath, required String repoRoot, required String runDir, bool verbose = false})`
- **Description:** Post-Release Phase: Uses the generated issue manifest to close out issues, update Sentry status, and inform cross-repo dependents.

#### `Future<String> preReleaseTriage({required String prevTag, required String newVersion, required String repoRoot, required String runDir, bool verbose = false})`
- **Description:** Pre-Release Phase: Scans GitHub and Sentry for issues likely solved by the diff, producing an `issue_manifest.json`.
- **Returns:** `Future<String>` yielding the path to the written manifest file.

#### `Future<VerificationReport> verify(GamePlan plan, List<TriageDecision> decisions, String repoRoot, {required String runDir})`
- **Description:** Phase 4: Confirms that all actions from Phase 3 were successfully applied by querying GitHub issue states.

#### `GeminiTask buildTask(IssuePlan issue, String repoRoot)`
- **Description:** Agent-scoped builder function used to translate an `IssuePlan` into an executable `GeminiTask`. Available within each specific agent (`changelog_agent`, `code_analysis_agent`, `duplicate_agent`, `pr_correlation_agent`, `sentiment_agent`).
