# Issue Triage Engine API Reference

This document provides a comprehensive API reference for the Issue Triage Engine module.

## 1. Classes

### TriageAction
A concrete action to take on a GitHub issue.
- **Fields:**
  - `type` (`ActionType`): The type of action to perform.
  - `description` (`String`): A human-readable description of the action.
  - `parameters` (`Map<String, dynamic>`): Additional parameters required for the action.
  - `executed` (`bool`): Whether the action has been executed.
  - `verified` (`bool`): Whether the action's success has been verified.
  - `error` (`String?`): An error message if the action failed.

**Example:**
```dart
final action = TriageAction(
  type: ActionType.label,
  description: 'Apply recommended labels',
)..parameters = {'labels': ['bug']}
  ..executed = false
  ..verified = false;
```

### TriageDecision
The aggregated triage decision for a single issue.
- **Fields:**
  - `issueNumber` (`int`): The GitHub issue number.
  - `aggregateConfidence` (`double`): The weighted average confidence score from all agents.
  - `riskLevel` (`RiskLevel`): The assessed risk level of applying the decision.
  - `rationale` (`String`): A human-readable explanation of how the decision was reached.
  - `actions` (`List<TriageAction>`): The list of actions to apply.
  - `investigationResults` (`List<InvestigationResult>`): The underlying investigation results.

**Example:**
```dart
final decision = TriageDecision(
  issueNumber: 123,
  aggregateConfidence: 0.85,
  riskLevel: RiskLevel.medium,
  rationale: 'High confidence from code analysis.',
  actions: [action],
)..investigationResults = [result];
```

### TriageTask
A single investigation or action task within the game plan.
- **Fields:**
  - `id` (`String`): A unique identifier for the task.
  - `agent` (`AgentType`): The type of agent assigned to this task.
  - `status` (`TaskStatus`): The current execution status.
  - `error` (`String?`): Error message if the task failed.
  - `result` (`Map<String, dynamic>?`): The raw JSON result from the agent.

**Example:**
```dart
final task = TriageTask(
  id: 'issue-123-code',
  agent: AgentType.codeAnalysis,
)..status = TaskStatus.pending
  ..error = null
  ..result = null;
```

### IssuePlan
The triage plan for a single GitHub issue.
- **Fields:**
  - `number` (`int`): The GitHub issue number.
  - `title` (`String`): The issue title.
  - `author` (`String`): The issue author.
  - `existingLabels` (`List<String>`): Labels currently applied to the issue.
  - `tasks` (`List<TriageTask>`): Investigation tasks to run.
  - `decision` (`Map<String, dynamic>?`): The final JSON decision after investigation.
  - `investigationComplete` (`bool`): (Getter) Whether all investigation tasks have completed.

**Example:**
```dart
final plan = IssuePlan(
  number: 123,
  title: 'Fix crash on startup',
  author: 'user1',
  existingLabels: ['bug'],
  tasks: [task],
)..decision = null;
```

### LinkSpec
A link to create between two entities (issue, PR, changelog, release notes).
- **Fields:**
  - `sourceType` (`String`): 'issue', 'pr', 'changelog', or 'release_notes'.
  - `sourceId` (`String`): Identifier for the source entity.
  - `targetType` (`String`): Target entity type.
  - `targetId` (`String`): Identifier for the target entity.
  - `description` (`String`): Description of the link relationship.
  - `applied` (`bool`): Whether the link has been physically created (e.g., via comment).

**Example:**
```dart
final link = LinkSpec(
  sourceType: 'issue',
  sourceId: '123',
  targetType: 'pr',
  targetId: '456',
  description: 'Related PR: Fix crash',
)..applied = false;
```

### GamePlan
The top-level game plan that orchestrates the entire triage pipeline.
- **Fields:**
  - `planId` (`String`): Unique identifier for this game plan run.
  - `createdAt` (`DateTime`): When the plan was created.
  - `issues` (`List<IssuePlan>`): The issues scheduled for triage.
  - `linksToCreate` (`List<LinkSpec>`): Cross-references to establish.

**Example:**
```dart
final gamePlan = GamePlan(
  planId: 'plan-123',
  createdAt: DateTime.now(),
  issues: [issuePlan],
)..linksToCreate = [linkSpec];
```

### InvestigationResult
Data class for investigation agent results.
- **Fields:**
  - `agentId` (`String`): The identifier of the agent that produced the result.
  - `issueNumber` (`int`): The associated issue number.
  - `confidence` (`double`): The confidence score (0.0 to 1.0).
  - `summary` (`String`): A concise summary of findings.
  - `evidence` (`List<String>`): Bullet points of supporting evidence.
  - `recommendedLabels` (`List<String>`): Labels the agent suggests applying.
  - `suggestedComment` (`String?`): Optional comment text suggested by the agent.
  - `suggestClose` (`bool`): Whether the agent recommends closing the issue.
  - `closeReason` (`String?`): Reason for closure (e.g., "completed", "not_planned", "duplicate").
  - `relatedEntities` (`List<RelatedEntity>`): Entities discovered during investigation.
  - `turnsUsed` (`int`): Number of interaction turns used by the LLM.
  - `toolCallsMade` (`int`): Number of tool calls made by the agent.
  - `durationMs` (`int`): Investigation duration in milliseconds.

**Example:**
```dart
final result = InvestigationResult(
  agentId: 'code_analysis',
  issueNumber: 123,
  confidence: 0.9,
  summary: 'Issue is fixed in recent commits.',
)..evidence = ['Commit abc fixes this']
  ..recommendedLabels = ['fixed']
  ..suggestedComment = 'Closing as fixed.'
  ..suggestClose = true
  ..closeReason = 'completed'
  ..relatedEntities = [entity]
  ..turnsUsed = 2
  ..toolCallsMade = 1
  ..durationMs = 1500;
```

### RelatedEntity
A reference to a related entity (PR, issue, commit, file) found during investigation.
- **Fields:**
  - `type` (`String`): 'pr', 'issue', 'commit', 'file'.
  - `id` (`String`): PR number, issue number, commit SHA, file path.
  - `description` (`String`): Context about the entity.
  - `relevance` (`double`): The relevance score (0.0 to 1.0).

**Example:**
```dart
final entity = RelatedEntity(
  type: 'commit',
  id: 'abc1234',
  description: 'Commit fixing the issue',
)..relevance = 0.95;
```

### RunContext
Manages a run-scoped audit trail directory for CI/CD operations.
- **Fields:**
  - `repoRoot` (`String`): The root directory of the repository.
  - `runDir` (`String`): The path to the specific run directory.
  - `command` (`String`): The CLI command executed.
  - `startedAt` (`DateTime`): Run start time.
  - `args` (`List<String>`): CLI arguments.
  - `runId` (`String`): (Getter) The directory name for the run.

**Example:**
```dart
final runContext = RunContext.create('/repo', 'triage')
  ..savePrompt('plan', 'prompt text')
  ..saveResponse('plan', 'response text');
```

### ValidationResult
JSON validation utilities for triage pipeline artifacts.
- **Fields:**
  - `valid` (`bool`): Whether validation succeeded.
  - `path` (`String`): The path to the validated file.
  - `errors` (`List<String>`): A list of validation errors.

**Example:**
```dart
final result = ValidationResult(
  valid: false,
  path: 'file.json',
)..errors = ['Missing required key: plan_id'];
```

### TriageConfig
Centralized, config-driven loader for the runtime CI tooling pipeline.
- **Fields:**
  - `loadedFrom` (`String?`): The resolved path to the config file that was loaded.
  - `isConfigured` (`bool`): (Getter) Whether this repo has opted into the CI tooling.
  - `repoName` (`String`): (Getter) Dart package name / GitHub repo name.
  - `repoOwner` (`String`): (Getter) GitHub org or user.
  - `triagedLabel` (`String`): (Getter) Label for triaged issues.
  - `changelogPath` (`String`): (Getter) Path to CHANGELOG.md.
  - `releaseNotesPath` (`String`): (Getter) Path to release notes.
  - `gcpProject` (`String`): (Getter) GCP project ID.
  - `sentryOrganization` (`String`): (Getter) Sentry organization slug.
  - `sentryProjects` (`List<String>`): (Getter) Associated Sentry projects.
  - `sentryScanOnPreRelease` (`bool`): (Getter) Whether to scan Sentry on pre-release.
  - `sentryRecentErrorsHours` (`int`): (Getter) Hours to look back for Sentry errors.
  - `preReleaseScanSentry` (`bool`): (Getter) Master flag for pre-release Sentry scanning.
  - `preReleaseScanGithub` (`bool`): (Getter) Whether to scan GitHub issues on pre-release.
  - `postReleaseCloseOwnRepo` (`bool`): (Getter) Whether to auto-close own-repo issues post-release.
  - `postReleaseCloseCrossRepo` (`bool`): (Getter) Whether to close cross-repo issues post-release.
  - `postReleaseCommentCrossRepo` (`bool`): (Getter) Whether to comment on cross-repo issues post-release.
  - `postReleaseLinkSentry` (`bool`): (Getter) Whether to link Sentry issues post-release.
  - `crossRepoEnabled` (`bool`): (Getter) Master flag for cross-repo processing.
  - `crossRepoRepos` (`List<CrossRepoEntry>`): (Getter) Configured cross-repo targets.
  - `typeLabels` (`List<String>`): (Getter) Available type labels.
  - `priorityLabels` (`List<String>`): (Getter) Available priority labels.
  - `areaLabels` (`List<String>`): (Getter) Available area labels.
  - `autoCloseThreshold` (`double`): (Getter) Confidence threshold for auto-closing.
  - `suggestCloseThreshold` (`double`): (Getter) Confidence threshold for suggesting closure.
  - `commentThreshold` (`double`): (Getter) Confidence threshold for informational comments.
  - `enabledAgents` (`List<String>`): (Getter) Agents enabled in the config.
  - `flashModel` (`String`): (Getter) Model to use for fast/flash operations.
  - `proModel` (`String`): (Getter) Model to use for reasoning operations.
  - `maxTurns` (`int`): (Getter) Maximum LLM turns allowed.
  - `maxConcurrent` (`int`): (Getter) Maximum concurrent tasks.
  - `maxRetries` (`int`): (Getter) Maximum retries for tasks.
  - `geminiApiKeyEnv` (`String`): (Getter) Environment variable name for the Gemini API key.
  - `githubTokenEnvNames` (`List<String>`): (Getter) Environment variable names to check for GitHub tokens.
  - `gcpSecretName` (`String`): (Getter) GCP secret name for the API key.

### CrossRepoEntry
A configured dependent repository.
- **Fields:**
  - `owner` (`String`): GitHub organization or user.
  - `repo` (`String`): GitHub repository name.
  - `relationship` (`String`): Relationship descriptor (e.g., 'related').
  - `fullName` (`String`): (Getter) The `owner/repo` string format.

### GeminiResult
The structured result from a Gemini CLI invocation.
- **Fields:**
  - `taskId` (`String`): Task identifier.
  - `response` (`String?`): Raw text response from Gemini.
  - `stats` (`Map<String, dynamic>?`): Execution statistics.
  - `error` (`Map<String, dynamic>?`): Error details if failed.
  - `attempts` (`int`): Number of attempts made.
  - `durationMs` (`int`): Execution duration in milliseconds.
  - `success` (`bool`): Whether the invocation succeeded.
  - `toolCalls` (`int`): (Getter) Total tool calls made.
  - `turnsUsed` (`int`): (Getter) Number of interaction turns used.
  - `errorMessage` (`String`): (Getter) The error message text.

### GeminiTask
A single task to execute via Gemini CLI.
- **Fields:**
  - `id` (`String`): Task identifier.
  - `prompt` (`String`): System instructions and prompt.
  - `model` (`String`): LLM model name.
  - `maxTurns` (`int`): Maximum interaction turns.
  - `allowedTools` (`List<String>`): Allowed MCP tools or commands.
  - `fileIncludes` (`List<String>`): Files to include in context.
  - `workingDirectory` (`String?`): Execution directory.
  - `sandbox` (`bool`): Whether to run in a sandbox environment.
  - `auditDir` (`String?`): Directory to save audit trail data.

### GeminiRunner
Manages parallel Gemini CLI execution with retry and rate limiting.
- **Fields:**
  - `maxConcurrent` (`int`): Max concurrent processes.
  - `maxRetries` (`int`): Max retries for transient errors.
  - `initialBackoff` (`Duration`): Starting backoff duration.
  - `maxBackoff` (`Duration`): Maximum backoff duration.
  - `verbose` (`bool`): Enable verbose logging.

### VerificationCheck
A single check during the verification phase.
- **Fields:**
  - `name` (`String`): Identifier for the check.
  - `passed` (`bool`): Check success status.
  - `message` (`String`): Details of the verification outcome.

### IssueVerification
Verification results for a specific issue.
- **Fields:**
  - `issueNumber` (`int`): Issue number verified.
  - `passed` (`bool`): Whether all checks for this issue passed.
  - `checks` (`List<VerificationCheck>`): Individual checks performed.

### VerificationReport
Report summarizing verification for all triaged issues.
- **Fields:**
  - `verifications` (`List<IssueVerification>`): All issue verifications.
  - `timestamp` (`DateTime`): When the verification report was generated.
  - `allPassed` (`bool`): (Getter) True if all verifications across all issues passed.


## 2. Enums

### TaskStatus
Represents the current execution status of a `TriageTask`.
- `pending`: Task is queued to run.
- `running`: Task is actively being executed by an agent.
- `completed`: Task finished successfully.
- `failed`: Task encountered an error.
- `skipped`: Task was intentionally bypassed.

### AgentType
Indicates which agent should handle a `TriageTask`.
- `codeAnalysis`: The Code Analysis Agent (searches commits, PRs, diffs).
- `prCorrelation`: The PR Correlation Agent.
- `duplicate`: The Duplicate Detection Agent.
- `sentiment`: The Comment Sentiment Agent.
- `changelog`: The Changelog/Release Agent.

### RiskLevel
Categorizes the risk level associated with a `TriageDecision`.
- `low`: Safe to apply labels or informational comments.
- `medium`: Requires human review, suitable for suggesting closure.
- `high`: High confidence, suitable for automated closure.

### ActionType
Specifies the type of GitHub action to execute.
- `label`: Apply labels to an issue.
- `comment`: Post a comment on an issue.
- `close`: Close an issue.
- `linkPr`: Create a reference link to a PR.
- `linkIssue`: Create a reference link to another issue.
- `none`: No action to take.


## 3. Top-Level Functions & Getters

### Configuration Threshold Getters (from `models/triage_decision.dart`)
- **`double get kCloseThreshold`**
  Returns the confidence threshold for auto-closing issues.
- **`double get kSuggestCloseThreshold`**
  Returns the confidence threshold for suggesting issue closure.
- **`double get kCommentThreshold`**
  Returns the confidence threshold for adding informational comments.

### JSON Schema & Validation (from `utils/json_schemas.dart`)
- **`ValidationResult validateJsonFile(String path, List<String> requiredKeys)`**
  Validates that a JSON file exists, is valid JSON, and contains the specified required keys.
- **`ValidationResult validateGamePlan(String path)`**
  Validates a game plan JSON structure against expected keys.
- **`ValidationResult validateInvestigationResult(String path)`**
  Validates an investigation result JSON structure against expected keys.
- **`void writeJson(String path, Map<String, dynamic> data)`**
  Writes a JSON object to a file with pretty formatting.
- **`Map<String, dynamic>? readJson(String path)`**
  Reads and parses a JSON file, returning null on error.

### MCP Configuration Utilities (from `utils/mcp_config.dart`)
- **`Map<String, dynamic> buildGitHubMcpConfig({String? token})`**
  Builds the GitHub MCP server configuration payload for `.gemini/settings.json`.
- **`Map<String, dynamic> buildSentryMcpConfig()`**
  Builds the Sentry MCP server configuration payload.
- **`Map<String, dynamic> readSettings(String repoRoot)`**
  Reads the current `.gemini/settings.json` configuration file.
- **`void writeSettings(String repoRoot, Map<String, dynamic> settings)`**
  Writes the provided settings back to `.gemini/settings.json`.
- **`bool ensureMcpConfigured(String repoRoot)`**
  Ensures the required MCP servers (GitHub, Sentry) are configured in the repository's `.gemini/settings.json` file.
- **`Future<Map<String, bool>> validateMcpServers(String repoRoot)`**
  Validates that required MCP servers are configured and accessible by the environment (e.g., verifying Docker availability).

### Global Configuration Instance (from `utils/config.dart`)
- **`TriageConfig get config`**
  Gets the singleton config instance. Automatically loaded from disk on first access.
- **`void reloadConfig()`**
  Forces a reload of the configuration from disk.

### Agent Builders
- **`GeminiTask buildTask(IssuePlan issue, String repoRoot)`** *(from `agents/changelog_agent.dart`)*
  Builds a Gemini task for changelog/release investigation.
- **`GeminiTask buildTask(IssuePlan issue, String repoRoot)`** *(from `agents/code_analysis_agent.dart`)*
  Builds a Gemini task for code analysis investigation.
- **`GeminiTask buildTask(IssuePlan issue, String repoRoot)`** *(from `agents/duplicate_agent.dart`)*
  Builds a Gemini task for duplicate detection.
- **`GeminiTask buildTask(IssuePlan issue, String repoRoot)`** *(from `agents/pr_correlation_agent.dart`)*
  Builds a Gemini task for PR correlation investigation.
- **`GeminiTask buildTask(IssuePlan issue, String repoRoot)`** *(from `agents/sentiment_agent.dart`)*
  Builds a Gemini task for comment sentiment analysis.

### Triage Phases
- **`Future<GamePlan> planSingleIssue(int issueNumber, String repoRoot, {required String runDir})`** *(from `phases/plan.dart`)*
  Creates a game plan targeting a single issue.
- **`Future<GamePlan> planAutoTriage(String repoRoot, {required String runDir})`** *(from `phases/plan.dart`)*
  Discovers all open untriaged issues and creates a game plan.
- **`GamePlan? loadPlan({String? runDir})`** *(from `phases/plan.dart`)*
  Loads an existing game plan from a run directory or fallback location.
- **`Future<Map<int, List<InvestigationResult>>> investigate(GamePlan plan, String repoRoot, {required String runDir, bool verbose = false})`** *(from `phases/investigate.dart`)*
  Dispatches investigation agents in parallel and returns their findings.
- **`Future<List<TriageDecision>> act(GamePlan plan, Map<int, List<InvestigationResult>> investigationResults, String repoRoot, {required String runDir})`** *(from `phases/act.dart`)*
  Applies triage decisions (labels, comments, state changes) to issues based on the investigation results.
- **`Future<VerificationReport> verify(GamePlan plan, List<TriageDecision> decisions, String repoRoot, {required String runDir})`** *(from `phases/verify.dart`)*
  Confirms that all actions from the Act phase were successfully applied by querying GitHub.
- **`Future<void> link(GamePlan plan, List<TriageDecision> decisions, String repoRoot, {required String runDir})`** *(from `phases/link.dart`)*
  Cross-links triaged issues to related artifacts (PRs, other issues, changelogs, release notes).
- **`Future<void> crossRepoLink(GamePlan plan, List<TriageDecision> decisions, String repoRoot, {required String runDir})`** *(from `phases/cross_repo_link.dart`)*
  Searches for and posts cross-references to related issues in configured dependent repositories.
- **`Future<String> preReleaseTriage({required String prevTag, required String newVersion, required String repoRoot, required String runDir, bool verbose = false})`** *(from `phases/pre_release.dart`)*
  Scans issues and Sentry errors, correlates them with git diffs, and produces an `issue_manifest.json` for the upcoming release. Returns the manifest file path.
- **`Future<void> postReleaseTriage({required String newVersion, required String releaseTag, required String releaseUrl, required String manifestPath, required String repoRoot, required String runDir, bool verbose = false})`** *(from `phases/post_release.dart`)*
  Runs post-release actions to link issues to the release, optionally auto-close high-confidence issues, and link Sentry tracking.

### CLI Entry Point (from `triage_cli.dart`)
- **`Future<void> main(List<String> args)`**
  The main entry point for the Triage CLI, orchestrating the full pipeline across Plan, Investigate, Act, Verify, Link, and Cross-Repo phases.
