# Issue Triage Engine - API Reference

This document covers the models, enums, configuration, and phases of the Issue Triage Engine.

## 1. Classes

### TriageConfig
Centralized, config-driven loader for the runtime CI tooling pipeline.
- **Fields:**
  - `loadedFrom` (`String?`): The resolved path to the config file that was loaded (null if defaults).
  - `isConfigured` (`bool`): Whether this repo has opted into the CI tooling by having a config file.
  - `repoName` (`String`): Dart package name / GitHub repo name.
  - `repoOwner` (`String`): GitHub org or user.
  - `triagedLabel` (`String`): Label marking an issue as triaged.
  - `changelogPath` (`String`): Path to the changelog file.
  - `releaseNotesPath` (`String`): Path to the release notes directory.
  - `gcpProject` (`String`): GCP project ID for Secret Manager.
  - `sentryOrganization` (`String`): Sentry organization slug.
  - `sentryProjects` (`List<String>`): Sentry projects to scan.
  - `sentryScanOnPreRelease` (`bool`): Whether to scan Sentry during pre-release triage.
  - `sentryRecentErrorsHours` (`int`): Hours to look back for Sentry errors.
  - `preReleaseScanSentry` (`bool`): Whether to scan Sentry during pre-release.
  - `preReleaseScanGithub` (`bool`): Whether to scan GitHub during pre-release.
  - `postReleaseCloseOwnRepo` (`bool`): Whether to close own-repo issues post-release.
  - `postReleaseCloseCrossRepo` (`bool`): Whether to close cross-repo issues post-release.
  - `postReleaseCommentCrossRepo` (`bool`): Whether to comment on cross-repo issues post-release.
  - `postReleaseLinkSentry` (`bool`): Whether to link Sentry issues post-release.
  - `crossRepoEnabled` (`bool`): Whether cross-repo workflows are enabled.
  - `crossRepoRepos` (`List<CrossRepoEntry>`): List of configured dependent repositories.
  - `crossRepoOrgs` (`List<String>`): Optional allowlist of organizations considered for cross-repo workflows.
  - `crossRepoDiscoveryEnabled` (`bool`): Whether automatic cross-repo discovery is enabled.
  - `crossRepoDiscoverySearchOrgs` (`List<String>`): Organizations used for auto-discovery.
  - `typeLabels` (`List<String>`): Configured type labels (e.g., bug, feature-request).
  - `priorityLabels` (`List<String>`): Configured priority labels.
  - `areaLabels` (`List<String>`): Configured area labels.
  - `autoCloseThreshold` (`double`): Confidence threshold to automatically close an issue.
  - `suggestCloseThreshold` (`double`): Confidence threshold to suggest closing an issue.
  - `commentThreshold` (`double`): Confidence threshold to post a comment.
  - `enabledAgents` (`List<String>`): List of enabled triage agents.
  - `flashModel` (`String`): Gemini flash model name.
  - `proModel` (`String`): Gemini pro model name.
  - `maxTurns` (`int`): Maximum turns for Gemini CLI.
  - `maxConcurrent` (`int`): Maximum concurrent Gemini CLI executions.
  - `maxRetries` (`int`): Maximum retries for Gemini CLI.
  - `geminiApiKeyEnv` (`String`): Environment variable name for the Gemini API key.
  - `githubTokenEnvNames` (`List<String>`): Environment variable names for the GitHub token.
  - `gcpSecretName` (`String`): GCP secret name for credentials.

**Example:**
```dart
import 'package:runtime_ci_tooling/src/triage/utils/config.dart';

final conf = TriageConfig.load();
print('Repository: ${conf.repoOwner}/${conf.repoName}');
```

### RunContext
Manages a run-scoped audit trail directory for CI/CD operations.
- **Fields:**
  - `repoRoot` (`String`): Root directory of the repository.
  - `runDir` (`String`): Path to the specific run directory.
  - `command` (`String`): CLI command that initiated the run.
  - `startedAt` (`DateTime`): Timestamp when the run started.
  - `args` (`List<String>`): Arguments passed to the command.
  - `runId` (`String`): The unique identifier for this run (directory name).

**Example:**
```dart
import 'package:runtime_ci_tooling/src/triage/utils/run_context.dart';

final ctx = RunContext.create('/path/to/repo', 'triage_cli', args: ['--auto']);
ctx.saveArtifact('plan', 'plan.json', '{"status": "ok"}');
ctx.finalize(exitCode: 0);
```

### GeminiResult
The structured result from a Gemini CLI invocation.
- **Fields:**
  - `taskId` (`String`): Identifier of the executed task.
  - `response` (`String?`): Text response from Gemini.
  - `stats` (`Map<String, dynamic>?`): Execution stats.
  - `error` (`Map<String, dynamic>?`): Error details if execution failed.
  - `attempts` (`int`): Number of execution attempts.
  - `durationMs` (`int`): Duration of execution in milliseconds.
  - `success` (`bool`): Whether the execution succeeded.
  - `toolCalls` (`int`): Total tool calls made.
  - `turnsUsed` (`int`): Turns used (proxy via tool calls).
  - `errorMessage` (`String`): Resolved error message.

### GeminiTask
A single task to execute via Gemini CLI.
- **Fields:**
  - `id` (`String`): Task identifier.
  - `prompt` (`String`): Prompt for the model.
  - `model` (`String`): Model name.
  - `maxTurns` (`int`): Maximum turns allowed.
  - `allowedTools` (`List<String>`): Tools the model is allowed to use.
  - `fileIncludes` (`List<String>`): Files to include in the context.
  - `workingDirectory` (`String?`): Directory to execute the command.
  - `sandbox` (`bool`): Whether to use the sandbox.
  - `auditDir` (`String?`): Optional audit directory to save prompts/responses.

**Example:**
```dart
import 'package:runtime_ci_tooling/src/triage/utils/gemini_runner.dart';

final task = GeminiTask(
  id: 'task-1',
  prompt: 'Analyze this code.',
  model: 'gemini-3.1-pro-preview',
  maxTurns: 10,
);
```

### GamePlan
The top-level game plan that orchestrates the entire triage pipeline.
- **Fields:**
  - `planId` (`String`): Unique identifier for the game plan.
  - `createdAt` (`DateTime`): Creation timestamp.
  - `issues` (`List<IssuePlan>`): List of issues to triage.
  - `linksToCreate` (`List<LinkSpec>`): List of links to create across entities.

**Example:**
```dart
import 'package:runtime_ci_tooling/src/triage/models/game_plan.dart';

final plan = GamePlan(
  planId: 'triage-12345',
  createdAt: DateTime.now(),
  issues: [],
)
  ..linksToCreate.add(LinkSpec(
    sourceType: 'issue',
    sourceId: '1',
    targetType: 'pr',
    targetId: '2',
    description: 'Fixes issue',
  ));
```

### IssuePlan
The triage plan for a single GitHub issue.
- **Fields:**
  - `number` (`int`): Issue number.
  - `title` (`String`): Issue title.
  - `author` (`String`): Issue author username.
  - `existingLabels` (`List<String>`): Currently applied labels.
  - `tasks` (`List<TriageTask>`): Investigation tasks for this issue.
  - `decision` (`Map<String, dynamic>?`): Generated triage decision.
  - `investigationComplete` (`bool`): Whether all investigation tasks have completed.

**Example:**
```dart
import 'package:runtime_ci_tooling/src/triage/models/game_plan.dart';

final issue = IssuePlan(
  number: 42,
  title: 'Bug in parsing',
  author: 'user1',
  existingLabels: ['bug'],
  tasks: [],
)
  ..decision = {'status': 'close'};
```

### TriageTask
A single investigation or action task within the game plan.
- **Fields:**
  - `id` (`String`): Task identifier.
  - `agent` (`AgentType`): Agent type assigned to the task.
  - `status` (`TaskStatus`): Current execution status.
  - `error` (`String?`): Error message if failed.
  - `result` (`Map<String, dynamic>?`): Task result payload.

**Example:**
```dart
import 'package:runtime_ci_tooling/src/triage/models/game_plan.dart';

final task = TriageTask(
  id: 'issue-42-code',
  agent: AgentType.codeAnalysis,
)
  ..status = TaskStatus.completed
  ..error = null
  ..result = {'confidence': 0.9};
```

### LinkSpec
A link to create between two entities (e.g., issue, PR, changelog, release notes).
- **Fields:**
  - `sourceType` (`String`): Type of the source entity.
  - `sourceId` (`String`): ID of the source entity.
  - `targetType` (`String`): Type of the target entity.
  - `targetId` (`String`): ID of the target entity.
  - `description` (`String`): Description of the relationship.
  - `applied` (`bool`): Whether the link has been successfully applied.

**Example:**
```dart
import 'package:runtime_ci_tooling/src/triage/models/game_plan.dart';

final link = LinkSpec(
  sourceType: 'issue',
  sourceId: '10',
  targetType: 'pr',
  targetId: '11',
  description: 'Related PR',
)
  ..applied = true;
```

### InvestigationResult
Data class for investigation agent results.
- **Fields:**
  - `agentId` (`String`): ID of the agent that produced the result.
  - `issueNumber` (`int`): Targeted issue number.
  - `confidence` (`double`): Confidence score of the result (0.0 - 1.0).
  - `summary` (`String`): Summary of findings.
  - `evidence` (`List<String>`): Supporting evidence for findings.
  - `recommendedLabels` (`List<String>`): Labels recommended by the agent.
  - `suggestedComment` (`String?`): Comment text suggested by the agent.
  - `suggestClose` (`bool`): Whether the agent suggests closing the issue.
  - `closeReason` (`String?`): Reason for closure (e.g., completed, duplicate).
  - `relatedEntities` (`List<RelatedEntity>`): Other related GitHub entities found.
  - `turnsUsed` (`int`): Turns used by the agent during investigation.
  - `toolCallsMade` (`int`): Number of tools invoked.
  - `durationMs` (`int`): Duration of the investigation.

**Example:**
```dart
import 'package:runtime_ci_tooling/src/triage/models/investigation_result.dart';

final result = InvestigationResult(
  agentId: 'code_analysis',
  issueNumber: 42,
  confidence: 0.95,
  summary: 'Fix found in commit abcdef',
  suggestClose: true,
  closeReason: 'completed',
);
```

### RelatedEntity
A reference to a related entity (PR, issue, commit, file) found during investigation.
- **Fields:**
  - `type` (`String`): Type of entity (pr, issue, commit, file).
  - `id` (`String`): Entity identifier.
  - `description` (`String`): Description of the entity.
  - `relevance` (`double`): Relevance score (0.0 - 1.0).

**Example:**
```dart
import 'package:runtime_ci_tooling/src/triage/models/investigation_result.dart';

final entity = RelatedEntity(
  type: 'commit',
  id: 'abc1234',
  description: 'Fixed the issue',
  relevance: 1.0,
);
```

### TriageDecision
The aggregated triage decision for a single issue.
- **Fields:**
  - `issueNumber` (`int`): Issue number being decided upon.
  - `aggregateConfidence` (`double`): Weighted aggregate confidence across all agent results.
  - `riskLevel` (`RiskLevel`): Overall risk level computed.
  - `rationale` (`String`): Human-readable explanation of the decision.
  - `actions` (`List<TriageAction>`): Actions prescribed by this decision.
  - `investigationResults` (`List<InvestigationResult>`): The raw results that informed this decision.

**Example:**
```dart
import 'package:runtime_ci_tooling/src/triage/models/triage_decision.dart';

final decision = TriageDecision(
  issueNumber: 42,
  aggregateConfidence: 0.9,
  riskLevel: RiskLevel.high,
  rationale: 'High confidence from code analysis.',
  actions: [],
);
```

### TriageAction
A concrete action to take on a GitHub issue.
- **Fields:**
  - `type` (`ActionType`): Type of action.
  - `description` (`String`): Human-readable description of the action.
  - `parameters` (`Map<String, dynamic>`): Execution parameters for the action.
  - `executed` (`bool`): Whether the action has run.
  - `verified` (`bool`): Whether the action's success has been verified.
  - `error` (`String?`): Error encountered during execution.

**Example:**
```dart
import 'package:runtime_ci_tooling/src/triage/models/triage_decision.dart';

final action = TriageAction(
  type: ActionType.label,
  description: 'Add triaged label',
  parameters: {'labels': ['triaged']},
)
  ..executed = true
  ..verified = true;
```

### IssueVerification
Represents the verification status of all actions on a specific issue.
- **Fields:**
  - `issueNumber` (`int`): Target issue number.
  - `passed` (`bool`): True if all checks passed.
  - `checks` (`List<VerificationCheck>`): The individual checks performed.

### VerificationCheck
Represents a specific check performed to verify an applied action.
- **Fields:**
  - `name` (`String`): Name of the check.
  - `passed` (`bool`): Whether the check succeeded.
  - `message` (`String`): Result message of the check.

### VerificationReport
Aggregated verification report for all triaged issues.
- **Fields:**
  - `verifications` (`List<IssueVerification>`): Verifications for individual issues.
  - `timestamp` (`DateTime`): When the report was generated.
  - `allPassed` (`bool`): True if all issue verifications passed.

## 2. Enums

### TaskStatus
Represents the lifecycle state of a task in the game plan.
- `pending`: Task is waiting to be executed.
- `running`: Task is currently executing.
- `completed`: Task finished successfully.
- `failed`: Task encountered an error.
- `skipped`: Task was skipped.

### AgentType
Identifies the specialized agent assigned to an investigation.
- `codeAnalysis`: Deep reasoning agent exploring code diffs and test additions.
- `prCorrelation`: Agent analyzing PR descriptions and states to find fixes.
- `duplicate`: Agent comparing issues to detect duplicates.
- `sentiment`: Agent reading issue threads to gauge resolution consensus.
- `changelog`: Agent checking release artifacts for mentions of the issue.

### RiskLevel
Indicates the confidence and potential impact of automated actions.
- `low`: Low confidence, minimal automated action taken (e.g., labeling).
- `medium`: Moderate confidence, safe automated actions taken (e.g., commenting).
- `high`: High confidence, definitive automated actions taken (e.g., closing).

### ActionType
Categorizes the specific operation an action will perform.
- `label`: Apply labels to the issue.
- `comment`: Post a comment on the issue.
- `close`: Close the issue.
- `linkPr`: Add a cross-reference to a PR.
- `linkIssue`: Add a cross-reference to another issue.
- `none`: No action required.

## 3. Extensions

*(No extensions are defined in the public API)*

## 4. Top-Level Functions

### Configuration & Settings
- `TriageConfig get config`
  - Returns the singleton `TriageConfig` instance.
- `double get kCloseThreshold`
  - Returns the configured `autoCloseThreshold`.
- `double get kSuggestCloseThreshold`
  - Returns the configured `suggestCloseThreshold`.
- `double get kCommentThreshold`
  - Returns the configured `commentThreshold`.
- `void reloadConfig()`
  - Reloads `TriageConfig` from disk.
- `Map<String, dynamic> buildGitHubMcpConfig({String? token})`
  - Builds the GitHub MCP server configuration.
- `Map<String, dynamic> buildSentryMcpConfig()`
  - Builds the Sentry MCP server configuration.
- `Map<String, dynamic> readSettings(String repoRoot)`
  - Reads the current `.gemini/settings.json` file.
- `void writeSettings(String repoRoot, Map<String, dynamic> settings)`
  - Writes updated settings to `.gemini/settings.json`.
- `bool ensureMcpConfigured(String repoRoot)`
  - Ensures MCP servers are configured in `.gemini/settings.json`, returning `true` if updated.
- `Future<Map<String, bool>> validateMcpServers(String repoRoot)`
  - Validates that required MCP servers are configured and accessible.

### JSON & Schema Validation
- `ValidationResult validateJsonFile(String path, List<String> requiredKeys)`
  - Validates that a JSON file exists, is valid JSON, and contains specific keys.
- `ValidationResult validateGamePlan(String path)`
  - Validates a game plan JSON structure.
- `ValidationResult validateInvestigationResult(String path)`
  - Validates an investigation result JSON structure.
- `void writeJson(String path, Map<String, dynamic> data)`
  - Writes a JSON object to a file with pretty formatting.
- `Map<String, dynamic>? readJson(String path)`
  - Reads and parses a JSON file, returning `null` on error.

### Triage Pipeline Phases
- `Future<GamePlan> planSingleIssue(int issueNumber, String repoRoot, {required String runDir})`
  - Creates a game plan for a single issue.
- `Future<GamePlan> planAutoTriage(String repoRoot, {required String runDir})`
  - Creates a game plan for all open untriaged issues.
- `GamePlan? loadPlan({String? runDir})`
  - Loads an existing game plan from a run directory.
- `Future<Map<int, List<InvestigationResult>>> investigate(GamePlan plan, String repoRoot, {required String runDir, bool verbose = false})`
  - Dispatches investigation agents in parallel and writes results to run-scoped directories.
- `Future<List<TriageDecision>> act(GamePlan plan, Map<int, List<InvestigationResult>> investigationResults, String repoRoot, {required String runDir})`
  - Applies triage decisions (label, comment, close) based on investigation results.
- `Future<VerificationReport> verify(GamePlan plan, List<TriageDecision> decisions, String repoRoot, {required String runDir})`
  - Confirms that all actions from the Act phase were applied successfully.
- `Future<void> link(GamePlan plan, List<TriageDecision> decisions, String repoRoot, {required String runDir})`
  - Creates bidirectional references between issues, PRs, changelogs, and release notes.
- `Future<void> crossRepoLink(GamePlan plan, List<TriageDecision> decisions, String repoRoot, {required String runDir})`
  - Searches for related issues in configured dependent repositories and posts cross-references.
- `Future<String> preReleaseTriage({required String prevTag, required String newVersion, required String repoRoot, required String runDir, bool verbose = false})`
  - Scans issues and Sentry errors, correlates them with diffs, and produces an `issue_manifest.json` for the upcoming release.
- `Future<void> postReleaseTriage({required String newVersion, required String releaseTag, required String releaseUrl, required String manifestPath, required String repoRoot, required String runDir, bool verbose = false})`
  - Closes the loop after a release by commenting on issues, linking Sentry issues, and updating the release notes folder.

### Agent Builders
- `GeminiTask buildTask(IssuePlan issue, String repoRoot, {String? resultsDir})` (in `changelog_agent.dart`)
  - Builds a Gemini task for changelog/release artifact investigation.
- `GeminiTask buildTask(IssuePlan issue, String repoRoot, {String? resultsDir})` (in `code_analysis_agent.dart`)
  - Builds a Gemini task for codebase search and test analysis.
- `GeminiTask buildTask(IssuePlan issue, String repoRoot, {String? resultsDir})` (in `duplicate_agent.dart`)
  - Builds a Gemini task to detect duplicate issues.
- `GeminiTask buildTask(IssuePlan issue, String repoRoot, {String? resultsDir})` (in `pr_correlation_agent.dart`)
  - Builds a Gemini task to find PRs that may address the issue.
- `GeminiTask buildTask(IssuePlan issue, String repoRoot, {String? resultsDir})` (in `sentiment_agent.dart`)
  - Builds a Gemini task to analyze issue discussion threads for consensus and resolution sentiment.

