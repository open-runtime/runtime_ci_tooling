# Issue Triage Engine API Reference

## Enums

### TaskStatus
Represents the state of a triage task.
- `pending`: Task is pending execution.
- `running`: Task is currently running.
- `completed`: Task completed successfully.
- `failed`: Task failed.
- `skipped`: Task was skipped.

### AgentType
Identifies the type of investigation agent.
- `codeAnalysis`: Code Analysis Agent.
- `prCorrelation`: PR Correlation Agent.
- `duplicate`: Duplicate Detection Agent.
- `sentiment`: Comment Sentiment Agent.
- `changelog`: Changelog/Release Agent.

### RiskLevel
Defines the confidence-based risk of a triage decision.
- `low`: Low risk.
- `medium`: Medium risk.
- `high`: High risk.

### ActionType
Specifies the type of automated action to perform.
- `label`: Apply a label to an issue.
- `comment`: Post a comment to an issue.
- `close`: Close an issue.
- `linkPr`: Link a related PR.
- `linkIssue`: Link a related issue.
- `none`: No action.

## Classes

### Configuration

#### TriageConfig
Centralized, config-driven loader for the runtime CI tooling pipeline.
- `String? loadedFrom`: The resolved path to the config file that was loaded.
- `bool isConfigured` (getter): Whether this repo has opted into the CI tooling.
- `String repoName` (getter): Dart package name / GitHub repo name.
- `String repoOwner` (getter): GitHub org or user.
- `String triagedLabel` (getter): Label to mark issues as triaged.
- `String changelogPath` (getter): Path to the changelog file.
- `String releaseNotesPath` (getter): Path to the release notes folder.
- `String gcpProject` (getter): GCP project ID for Secret Manager and other cloud resources.
- `String sentryOrganization` (getter): Sentry organization slug.
- `List<String> sentryProjects` (getter): List of Sentry projects.
- `bool sentryScanOnPreRelease` (getter): Whether to scan Sentry on pre-release.
- `int sentryRecentErrorsHours` (getter): Hours of recent Sentry errors to scan.
- `bool preReleaseScanSentry` (getter): Whether to scan Sentry during pre-release.
- `bool preReleaseScanGithub` (getter): Whether to scan GitHub during pre-release.
- `bool postReleaseCloseOwnRepo` (getter): Whether to auto-close own-repo issues.
- `bool postReleaseCloseCrossRepo` (getter): Whether to auto-close cross-repo issues.
- `bool postReleaseCommentCrossRepo` (getter): Whether to comment on cross-repo issues.
- `bool postReleaseLinkSentry` (getter): Whether to link Sentry issues during post-release.
- `bool crossRepoEnabled` (getter): Whether cross-repo linking is enabled.
- `List<CrossRepoEntry> crossRepoRepos` (getter): Configured cross-repo entries.
- `List<String> crossRepoOrgs` (getter): Allowlist of cross-repo organizations.
- `bool crossRepoDiscoveryEnabled` (getter): Whether cross-repo discovery is enabled.
- `List<String> crossRepoDiscoverySearchOrgs` (getter): Organizations for auto-discovery.
- `List<String> typeLabels` (getter): Configured type labels.
- `List<String> priorityLabels` (getter): Configured priority labels.
- `List<String> areaLabels` (getter): Configured area labels.
- `double autoCloseThreshold` (getter): Confidence threshold for auto-closing.
- `double suggestCloseThreshold` (getter): Confidence threshold for suggesting closure.
- `double commentThreshold` (getter): Confidence threshold for commenting.
- `List<String> enabledAgents` (getter): List of enabled agent names.
- `String flashModel` (getter): Default Gemini flash model name.
- `String proModel` (getter): Default Gemini pro model name.
- `int maxTurns` (getter): Max turns for Gemini.
- `int maxConcurrent` (getter): Max concurrent Gemini tasks.
- `int maxRetries` (getter): Max retries for Gemini.
- `String geminiApiKeyEnv` (getter): Environment variable name for Gemini API key.
- `List<String> githubTokenEnvNames` (getter): Environment variable names for GitHub token.
- `String gcpSecretName` (getter): GCP secret name for tokens.

**Methods**:
- `bool shouldRunAgent(String agentName, String repoRoot)`: Checks if a conditional agent should run based on file existence.
- `String? resolveGeminiApiKey()`: Resolves the Gemini API key from env vars or GCP Secret Manager.
- `String? resolveGithubToken()`: Resolves a GitHub token from any of the configured env var names.
- `factory TriageConfig.load()`: Loads config by searching upward from CWD for `runtime.ci.config.json` or fallback.

#### CrossRepoEntry
Cross-repository relationship entry.
- `String owner`: Repository owner.
- `String repo`: Repository name.
- `String relationship`: Relationship type.
- `String fullName` (getter): Full repository name (`owner/repo`).

### Context & Execution

#### RunContext
Manages a run-scoped audit trail directory for CI/CD operations.
- `String repoRoot`: Root directory of the repository.
- `String runDir`: Directory path for this run.
- `String command`: CLI command executed.
- `DateTime startedAt`: Timestamp of run start.
- `List<String> args`: Command arguments.
- `String runId` (getter): The run ID (directory name).

**Methods**:
- `String subdir(String name)`: Get or create a subdirectory within the run directory.
- `void savePrompt(String phase, String prompt)`: Save a prompt sent to Gemini CLI.
- `void saveResponse(String phase, String rawResponse)`: Save the response from Gemini CLI.
- `void saveArtifact(String phase, String filename, String content)`: Save a structured text artifact.
- `void saveJsonArtifact(String phase, String filename, Map<String, dynamic> data)`: Save a JSON artifact.
- `String artifactPath(String phase, String filename)`: Get the path for an artifact file.
- `String? readArtifact(String phase, String filename)`: Read an artifact file, returning null if it doesn't exist.
- `bool hasArtifact(String phase, String filename)`: Check if an artifact exists.
- `void finalize({int? exitCode})`: Update the meta.json with completion info.
- `void archiveForRelease(String version)`: Archive important artifacts to `cicd_audit/vX.X.X/` for permanent storage.
- `static String? findLatestRun(String repoRoot, {String? command})`: Find the most recent run directory for a given command.
- `static List<Directory> listRuns(String repoRoot)`: List all run directories.
- `factory RunContext.create(String repoRoot, String command, {List<String> args = const []})`: Creates a new run context.
- `factory RunContext.load(String repoRoot, String runDirPath)`: Loads an existing run context.

#### GeminiRunner
Manages parallel Gemini CLI execution with retry and rate limiting.
- `int maxConcurrent`: Max concurrent tasks.
- `int maxRetries`: Max retries per task.
- `Duration initialBackoff`: Initial backoff duration.
- `Duration maxBackoff`: Maximum backoff duration.
- `bool verbose`: Enable verbose logging.

**Methods**:
- `Future<List<GeminiResult>> executeBatch(List<GeminiTask> tasks)`: Execute a batch of tasks in parallel with concurrency limiting.

#### GeminiTask
A single task to execute via Gemini CLI.
- `String id`: Task identifier.
- `String prompt`: Prompt text.
- `String model`: Model name.
- `int maxTurns`: Maximum turns.
- `List<String> allowedTools`: Allowed tools.
- `List<String> fileIncludes`: Files to include.
- `String? workingDirectory`: Working directory for execution.
- `bool sandbox`: Use sandbox mode.
- `String? auditDir`: Directory for audit logs.

#### GeminiResult
The structured result from a Gemini CLI invocation.
- `String taskId`: Task identifier.
- `String? response`: The response text.
- `Map<String, dynamic>? stats`: Execution stats.
- `Map<String, dynamic>? error`: Error information.
- `int attempts`: Number of attempts made.
- `int durationMs`: Duration in milliseconds.
- `bool success`: Success status.
- `int toolCalls` (getter): Total tool calls made.
- `int turnsUsed` (getter): Proxy for turns used based on tool calls.
- `String errorMessage` (getter): Error message text.

### Plan Models

#### GamePlan
The top-level game plan that orchestrates the entire triage pipeline.
- `String planId`: Plan identifier.
- `DateTime createdAt`: Creation timestamp.
- `List<IssuePlan> issues`: Issues to triage.
- `List<LinkSpec> linksToCreate`: Links to create.

**Methods**:
- `Map<String, dynamic> toJson()`: Serializes the plan.
- `String toJsonString()`: Serializes the plan to a formatted JSON string.
- `factory GamePlan.fromJson(Map<String, dynamic> json)`: Deserializes the plan.
- `factory GamePlan.forIssues(List<Map<String, dynamic>> issueData)`: Creates a default game plan for a list of issues.

```dart
import 'package:runtime_ci_tooling/src/triage/models/game_plan.dart';

// Example: Using the builder pattern for constructing a game plan model setup
final task = TriageTask(
  id: 'task-1', 
  agent: AgentType.codeAnalysis,
)
  ..status = TaskStatus.completed
  ..error = null
  ..result = {'agent_id': 'code_analysis', 'issue_number': 42};

final issuePlan = IssuePlan(
  number: 42,
  title: 'Fix issue',
  author: 'user',
  existingLabels: ['bug'],
  tasks: [task],
)
  ..decision = {'aggregate_confidence': 0.9, 'risk_level': 'high'};

final plan = GamePlan(
  planId: 'plan-id',
  createdAt: DateTime.now(),
  issues: [issuePlan],
);
```

#### IssuePlan
The triage plan for a single GitHub issue.
- `int number`: Issue number.
- `String title`: Issue title.
- `String author`: Issue author.
- `List<String> existingLabels`: Labels currently applied.
- `List<TriageTask> tasks`: Investigation tasks.
- `Map<String, dynamic>? decision`: Triage decision details.
- `bool investigationComplete` (getter): Whether all investigation tasks have completed.

**Methods**:
- `Map<String, dynamic> toJson()`: Serializes the issue plan.
- `factory IssuePlan.fromJson(Map<String, dynamic> json)`: Deserializes the issue plan.

#### TriageTask
A single investigation or action task within the game plan.
- `String id`: Task identifier.
- `AgentType agent`: Type of agent.
- `TaskStatus status`: Current status.
- `String? error`: Error message if failed.
- `Map<String, dynamic>? result`: Task result.

**Methods**:
- `Map<String, dynamic> toJson()`: Serializes the task.
- `factory TriageTask.fromJson(Map<String, dynamic> json)`: Deserializes the task.

#### LinkSpec
A link to create between two entities (issue, PR, changelog, release notes).
- `String sourceType`: Type of source entity.
- `String sourceId`: Source entity identifier.
- `String targetType`: Type of target entity.
- `String targetId`: Target entity identifier.
- `String description`: Link description.
- `bool applied`: Whether the link was applied.

**Methods**:
- `Map<String, dynamic> toJson()`: Serializes the link spec.
- `factory LinkSpec.fromJson(Map<String, dynamic> json)`: Deserializes the link spec.

```dart
import 'package:runtime_ci_tooling/src/triage/models/game_plan.dart';

final link = LinkSpec(
  sourceType: 'issue',
  sourceId: '42',
  targetType: 'pr',
  targetId: '43',
  description: 'Related PR',
)..applied = true;
```

### Investigation & Decision Models

#### InvestigationResult
Data class for investigation agent results.
- `String agentId`: Agent identifier.
- `int issueNumber`: Associated issue number.
- `double confidence`: Confidence score.
- `String summary`: Findings summary.
- `List<String> evidence`: Supporting evidence items.
- `List<String> recommendedLabels`: Labels to apply.
- `String? suggestedComment`: Comment text to post.
- `bool suggestClose`: Whether to suggest closing.
- `String? closeReason`: Reason for closure.
- `List<RelatedEntity> relatedEntities`: Entities found during investigation.
- `int turnsUsed`: Turns used during investigation.
- `int toolCallsMade`: Tool calls made during investigation.
- `int durationMs`: Duration of investigation.

**Methods**:
- `Map<String, dynamic> toJson()`: Serializes the result.
- `factory InvestigationResult.fromJson(Map<String, dynamic> json)`: Deserializes the result.
- `factory InvestigationResult.failed({required String agentId, required int issueNumber, required String error})`: Creates a failed result.

```dart
import 'package:runtime_ci_tooling/src/triage/models/investigation_result.dart';

final result = InvestigationResult(
  agentId: 'code_analysis',
  issueNumber: 42,
  confidence: 0.95,
  summary: 'Fix found.',
  suggestClose: true,
  closeReason: 'completed',
);
```

#### RelatedEntity
A reference to a related entity (PR, issue, commit, file) found during investigation.
- `String type`: Type of entity ('pr', 'issue', 'commit', 'file').
- `String id`: Entity identifier.
- `String description`: Description of the entity.
- `double relevance`: Relevance score (0.0-1.0).

**Methods**:
- `Map<String, dynamic> toJson()`: Serializes the related entity.
- `factory RelatedEntity.fromJson(Map<String, dynamic> json)`: Deserializes the related entity.

#### TriageDecision
The aggregated triage decision for a single issue.
- `int issueNumber`: Associated issue number.
- `double aggregateConfidence`: Aggregate confidence score.
- `RiskLevel riskLevel`: Associated risk level.
- `String rationale`: Rationale for the decision.
- `List<TriageAction> actions`: Actions to perform.
- `List<InvestigationResult> investigationResults`: Results driving the decision.

**Methods**:
- `Map<String, dynamic> toJson()`: Serializes the decision.
- `factory TriageDecision.fromJson(Map<String, dynamic> json)`: Deserializes the decision.
- `factory TriageDecision.fromResults({required int issueNumber, required List<InvestigationResult> results})`: Creates a decision from aggregated results.

#### TriageAction
A concrete action to take on a GitHub issue.
- `ActionType type`: Type of action.
- `String description`: Description of the action.
- `Map<String, dynamic> parameters`: Action parameters.
- `bool executed`: Whether the action was executed.
- `bool verified`: Whether the action was verified.
- `String? error`: Error during execution.

**Methods**:
- `Map<String, dynamic> toJson()`: Serializes the action.
- `factory TriageAction.fromJson(Map<String, dynamic> json)`: Deserializes the action.

```dart
import 'package:runtime_ci_tooling/src/triage/models/triage_decision.dart';

final action = TriageAction(
  type: ActionType.label,
  description: 'Add bugs label',
  parameters: {'labels': ['bug']},
)
  ..executed = true
  ..verified = true
  ..error = null;
```

### Verification Models

#### VerificationReport
Contains the result of verifying triage actions.
- `List<IssueVerification> verifications`: Issue verification results.
- `DateTime timestamp`: When verification occurred.
- `bool allPassed` (getter): Whether all verifications passed.

**Methods**:
- `Map<String, dynamic> toJson()`: Serializes the report.

#### IssueVerification
Verification results for a specific issue.
- `int issueNumber`: Associated issue number.
- `bool passed`: Whether verification passed.
- `List<VerificationCheck> checks`: Individual verification checks.

**Methods**:
- `Map<String, dynamic> toJson()`: Serializes the issue verification.

#### VerificationCheck
A single verification check (e.g., label applied).
- `String name`: Name of the check.
- `bool passed`: Whether the check passed.
- `String message`: Verification message.

**Methods**:
- `Map<String, dynamic> toJson()`: Serializes the verification check.

### Utilities

#### ValidationResult
Result of JSON file validation.
- `bool valid`: Whether validation passed.
- `String path`: Path to the validated file.
- `List<String> errors`: Validation errors.

**Methods**:
- `String toString()`: Returns a string representation of the validation result.

## Top-Level Functions

### Pipeline Phases
- `Future<GamePlan> planSingleIssue(int issueNumber, String repoRoot, {required String runDir})`
- `Future<GamePlan> planAutoTriage(String repoRoot, {required String runDir})`
- `Future<Map<int, List<InvestigationResult>>> investigate(GamePlan plan, String repoRoot, {required String runDir, bool verbose = false})`
- `Future<List<TriageDecision>> act(GamePlan plan, Map<int, List<InvestigationResult>> investigationResults, String repoRoot, {required String runDir})`
- `Future<VerificationReport> verify(GamePlan plan, List<TriageDecision> decisions, String repoRoot, {required String runDir})`
- `Future<void> link(GamePlan plan, List<TriageDecision> decisions, String repoRoot, {required String runDir})`
- `Future<void> crossRepoLink(GamePlan plan, List<TriageDecision> decisions, String repoRoot, {required String runDir})`

### Release Phases
- `Future<String> preReleaseTriage({required String prevTag, required String newVersion, required String repoRoot, required String runDir, bool verbose = false})`
- `Future<void> postReleaseTriage({required String newVersion, required String releaseTag, required String releaseUrl, required String manifestPath, required String repoRoot, required String runDir, bool verbose = false})`

### Execution & Tasks
- `Future<void> main(List<String> args)`
- `GeminiTask buildTask(IssuePlan issue, String repoRoot, {String? resultsDir})`
- `GamePlan? loadPlan({String? runDir})`
- `void reloadConfig()`

### JSON Utilities
- `ValidationResult validateJsonFile(String path, List<String> requiredKeys)`
- `ValidationResult validateGamePlan(String path)`
- `ValidationResult validateInvestigationResult(String path)`
- `void writeJson(String path, Map<String, dynamic> data)`
- `Map<String, dynamic>? readJson(String path)`

### MCP Configuration
- `Map<String, dynamic> buildGitHubMcpConfig({String? token})`
- `Map<String, dynamic> buildSentryMcpConfig()`
- `Map<String, dynamic> readSettings(String repoRoot)`
- `void writeSettings(String repoRoot, Map<String, dynamic> settings)`
- `bool ensureMcpConfigured(String repoRoot)`
- `Future<Map<String, bool>> validateMcpServers(String repoRoot)`
