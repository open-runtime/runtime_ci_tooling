# Issue Triage Engine API Reference

This document provides a comprehensive API reference for the Issue Triage Engine module.

## 1. Classes

### TriageAction
A concrete action to take on a GitHub issue.
- **Fields:**
  - `type` (`ActionType`): The type of action to perform.
  - `description` (`String`): Description of the action.
  - `parameters` (`Map<String, dynamic>`): Action-specific parameters (e.g., labels, comments).
  - `executed` (`bool`): Whether the action has been executed.
  - `verified` (`bool`): Whether the action execution was verified.
  - `error` (`String?`): Any error that occurred during execution.
- **Methods:**
  - `toJson() -> Map<String, dynamic>`: Serializes the action to JSON.
- **Constructors:**
  - `TriageAction({required ActionType type, required String description, Map<String, dynamic> parameters = const {}, bool executed = false, bool verified = false, String? error})`
  - `TriageAction.fromJson(Map<String, dynamic> json)`

**Example:**
```dart
import 'package:runtime_ci_tooling/src/triage/models/triage_decision.dart';

final action = TriageAction(
  type: ActionType.comment,
  description: 'Post informational findings',
  parameters: {'body': 'The issue was investigated.'},
)
  ..executed = true
  ..verified = false;
```

### TriageDecision
The aggregated triage decision for a single issue.
- **Fields:**
  - `issueNumber` (`int`): The GitHub issue number.
  - `aggregateConfidence` (`double`): Overall confidence level of the decision.
  - `riskLevel` (`RiskLevel`): Categorized risk level (low, medium, high).
  - `rationale` (`String`): Explanation of the decision.
  - `actions` (`List<TriageAction>`): Set of concrete actions to take.
  - `investigationResults` (`List<InvestigationResult>`): Findings from all executed agents.
- **Methods:**
  - `toJson() -> Map<String, dynamic>`: Serializes the decision to JSON.
- **Constructors:**
  - `TriageDecision({required int issueNumber, required double aggregateConfidence, required RiskLevel riskLevel, required String rationale, required List<TriageAction> actions, List<InvestigationResult> investigationResults = const []})`
  - `TriageDecision.fromJson(Map<String, dynamic> json)`
  - `TriageDecision.fromResults({required int issueNumber, required List<InvestigationResult> results})`

**Example:**
```dart
import 'package:runtime_ci_tooling/src/triage/models/triage_decision.dart';

final decision = TriageDecision(
  issueNumber: 123,
  aggregateConfidence: 0.95,
  riskLevel: RiskLevel.high,
  rationale: 'Multiple agents confirmed resolution.',
  actions: [
    TriageAction(
      type: ActionType.close,
      description: 'Close the issue',
    )
  ],
);
```

### TriageTask
A single investigation or action task within the game plan.
- **Fields:**
  - `id` (`String`): Unique identifier for the task.
  - `agent` (`AgentType`): Type of agent running the task.
  - `status` (`TaskStatus`): Current progress status.
  - `error` (`String?`): Error details if the task failed.
  - `result` (`Map<String, dynamic>?`): The payload/result produced by the agent.
- **Methods:**
  - `toJson() -> Map<String, dynamic>`
- **Constructors:**
  - `TriageTask({required String id, required AgentType agent, TaskStatus status = TaskStatus.pending, String? error, Map<String, dynamic>? result})`
  - `TriageTask.fromJson(Map<String, dynamic> json)`

**Example:**
```dart
import 'package:runtime_ci_tooling/src/triage/models/game_plan.dart';

final task = TriageTask(
  id: 'issue-123-code',
  agent: AgentType.codeAnalysis,
)
  ..status = TaskStatus.running
  ..error = null;
```

### IssuePlan
The triage plan for a single GitHub issue.
- **Fields:**
  - `number` (`int`): Issue number.
  - `title` (`String`): Issue title.
  - `author` (`String`): Issue author.
  - `existingLabels` (`List<String>`): Labels currently applied.
  - `tasks` (`List<TriageTask>`): List of agent tasks mapped to this issue.
  - `decision` (`Map<String, dynamic>?`): Stored resulting decision.
  - `investigationComplete` (`bool`): True if all tasks are completed or failed.
- **Methods:**
  - `toJson() -> Map<String, dynamic>`
- **Constructors:**
  - `IssuePlan({required int number, required String title, required String author, List<String> existingLabels = const [], required List<TriageTask> tasks, Map<String, dynamic>? decision})`
  - `IssuePlan.fromJson(Map<String, dynamic> json)`

**Example:**
```dart
import 'package:runtime_ci_tooling/src/triage/models/game_plan.dart';

final plan = IssuePlan(
  number: 42,
  title: 'Crash on startup',
  author: 'dev123',
  existingLabels: ['bug'],
  tasks: [
    TriageTask(id: 'task-1', agent: AgentType.codeAnalysis),
  ],
)..decision = {'risk_level': 'low'};
```

### LinkSpec
A link to create between two entities (issue, PR, changelog, release notes).
- **Fields:**
  - `sourceType` (`String`): Source entity type (e.g., 'issue').
  - `sourceId` (`String`): ID of the source entity.
  - `targetType` (`String`): Target entity type (e.g., 'pr').
  - `targetId` (`String`): ID of the target entity.
  - `description` (`String`): Context/description of the link.
  - `applied` (`bool`): Whether the link was successfully created.
- **Methods:**
  - `toJson() -> Map<String, dynamic>`
- **Constructors:**
  - `LinkSpec({required String sourceType, required String sourceId, required String targetType, required String targetId, required String description, bool applied = false})`
  - `LinkSpec.fromJson(Map<String, dynamic> json)`

**Example:**
```dart
import 'package:runtime_ci_tooling/src/triage/models/game_plan.dart';

final link = LinkSpec(
  sourceType: 'issue',
  sourceId: '123',
  targetType: 'pr',
  targetId: '456',
  description: 'Related PR',
)..applied = true;
```

### GamePlan
The top-level game plan that orchestrates the entire triage pipeline.
- **Fields:**
  - `planId` (`String`): Unique ID of the overall plan.
  - `createdAt` (`DateTime`): Plan creation timestamp.
  - `issues` (`List<IssuePlan>`): Issues covered by this plan.
  - `linksToCreate` (`List<LinkSpec>`): Aggregated cross-links mapped.
- **Methods:**
  - `toJson() -> Map<String, dynamic>`
  - `toJsonString() -> String`
- **Constructors:**
  - `GamePlan({required String planId, required DateTime createdAt, required List<IssuePlan> issues, List<LinkSpec> linksToCreate = const []})`
  - `GamePlan.fromJson(Map<String, dynamic> json)`
  - `GamePlan.forIssues(List<Map<String, dynamic>> issueData)`

**Example:**
```dart
import 'package:runtime_ci_tooling/src/triage/models/game_plan.dart';

final gamePlan = GamePlan(
  planId: 'triage-2023-10-10',
  createdAt: DateTime.now(),
  issues: [],
  linksToCreate: [
    LinkSpec(
      sourceType: 'issue',
      sourceId: '1',
      targetType: 'issue',
      targetId: '2',
      description: 'Duplicate',
    )
  ],
);
```

### InvestigationResult
Data class for investigation agent results.
- **Fields:**
  - `agentId` (`String`): Source agent ID.
  - `issueNumber` (`int`): Targeted issue number.
  - `confidence` (`double`): Overall confidence level determined by the agent.
  - `summary` (`String`): High-level finding summary.
  - `evidence` (`List<String>`): Pieces of evidence justifying confidence.
  - `recommendedLabels` (`List<String>`): Labels proposed by the agent.
  - `suggestedComment` (`String?`): Optional textual comment provided by the agent.
  - `suggestClose` (`bool`): Indicates if the issue is a strong candidate for closing.
  - `closeReason` (`String?`): Proposed reason (e.g., 'completed', 'not_planned').
  - `relatedEntities` (`List<RelatedEntity>`): Entities cross-referenced during investigation.
  - `turnsUsed` (`int`): Count of turns the model used.
  - `toolCallsMade` (`int`): Count of tool calls generated.
  - `durationMs` (`int`): Duration of the request.
- **Methods:**
  - `toJson() -> Map<String, dynamic>`
- **Constructors:**
  - `InvestigationResult({required String agentId, required int issueNumber, required double confidence, required String summary, List<String> evidence = const [], List<String> recommendedLabels = const [], String? suggestedComment, bool suggestClose = false, String? closeReason, List<RelatedEntity> relatedEntities = const [], int turnsUsed = 0, int toolCallsMade = 0, int durationMs = 0})`
  - `InvestigationResult.fromJson(Map<String, dynamic> json)`
  - `InvestigationResult.failed({required String agentId, required int issueNumber, required String error})`

**Example:**
```dart
import 'package:runtime_ci_tooling/src/triage/models/investigation_result.dart';

final result = InvestigationResult(
  agentId: 'code_analysis',
  issueNumber: 42,
  confidence: 0.8,
  summary: 'Fix found in recent commit',
  evidence: ['Commit abc1234 addresses this'],
  recommendedLabels: ['bug-fixed'],
  suggestClose: true,
  closeReason: 'completed',
);
```

### RelatedEntity
A reference to a related entity (PR, issue, commit, file) found during investigation.
- **Fields:**
  - `type` (`String`): 'pr', 'issue', 'commit', 'file'.
  - `id` (`String`): Exact identifier.
  - `description` (`String`): Summary of the relationship.
  - `relevance` (`double`): Scale between 0.0-1.0 showing how tightly connected the entity is.
- **Methods:**
  - `toJson() -> Map<String, dynamic>`
- **Constructors:**
  - `RelatedEntity({required String type, required String id, required String description, double relevance = 0.5})`
  - `RelatedEntity.fromJson(Map<String, dynamic> json)`

**Example:**
```dart
import 'package:runtime_ci_tooling/src/triage/models/investigation_result.dart';

final entity = RelatedEntity(
  type: 'commit',
  id: 'sha123',
  description: 'Relevant commit fixing the crash',
  relevance: 0.9,
);
```

### RunContext
Manages a run-scoped audit trail directory for CI/CD operations.
- **Fields:**
  - `repoRoot` (`String`): Contextual root.
  - `runDir` (`String`): Directory storing run outputs.
  - `command` (`String`): Executed CLI command.
  - `startedAt` (`DateTime`): Timestamp.
  - `args` (`List<String>`): CLI args.
  - `runId` (`String`): Get the run ID (directory name).
- **Methods:**
  - `subdir(String name) -> String`
  - `savePrompt(String phase, String prompt) -> void`
  - `saveResponse(String phase, String rawResponse) -> void`
  - `saveArtifact(String phase, String filename, String content) -> void`
  - `saveJsonArtifact(String phase, String filename, Map<String, dynamic> data) -> void`
  - `artifactPath(String phase, String filename) -> String`
  - `readArtifact(String phase, String filename) -> String?`
  - `hasArtifact(String phase, String filename) -> bool`
  - `finalize({int? exitCode}) -> void`
  - `archiveForRelease(String version) -> void`
  - `static findLatestRun(String repoRoot, {String? command}) -> String?`
  - `static listRuns(String repoRoot) -> List<Directory>`
- **Constructors:**
  - `RunContext.create(String repoRoot, String command, {List<String> args = const []})`
  - `RunContext.load(String repoRoot, String runDirPath)`

**Example:**
```dart
import 'package:runtime_ci_tooling/src/triage/utils/run_context.dart';

final context = RunContext.create('/path/to/repo', 'triage');
context.savePrompt('investigate', 'Analyze this issue');
context.finalize(exitCode: 0);
```

### ValidationResult
Result artifact matching a validation run.
- **Fields:**
  - `valid` (`bool`): True if valid.
  - `path` (`String`): Source path of evaluated JSON file.
  - `errors` (`List<String>`): Collection of any validation discrepancies.
- **Methods:**
  - `toString() -> String`: Summarizes validation output.
- **Constructors:**
  - `ValidationResult({required bool valid, required String path, List<String> errors = const []})`

### TriageConfig
Centralized, config-driven loader for the runtime CI tooling pipeline.
- **Fields / Getters:**
  - `loadedFrom` (`String?`)
  - `isConfigured` (`bool`)
  - `repoName` (`String`)
  - `repoOwner` (`String`)
  - `triagedLabel` (`String`)
  - `changelogPath` (`String`)
  - `releaseNotesPath` (`String`)
  - `gcpProject` (`String`)
  - `sentryOrganization` (`String`)
  - `sentryProjects` (`List<String>`)
  - `sentryScanOnPreRelease` (`bool`)
  - `sentryRecentErrorsHours` (`int`)
  - `preReleaseScanSentry` (`bool`)
  - `preReleaseScanGithub` (`bool`)
  - `postReleaseCloseOwnRepo` (`bool`)
  - `postReleaseCloseCrossRepo` (`bool`)
  - `postReleaseCommentCrossRepo` (`bool`)
  - `postReleaseLinkSentry` (`bool`)
  - `crossRepoEnabled` (`bool`)
  - `crossRepoRepos` (`List<CrossRepoEntry>`)
  - `typeLabels` (`List<String>`)
  - `priorityLabels` (`List<String>`)
  - `areaLabels` (`List<String>`)
  - `autoCloseThreshold` (`double`)
  - `suggestCloseThreshold` (`double`)
  - `commentThreshold` (`double`)
  - `enabledAgents` (`List<String>`)
  - `flashModel` (`String`)
  - `proModel` (`String`)
  - `maxTurns` (`int`)
  - `maxConcurrent` (`int`)
  - `maxRetries` (`int`)
  - `geminiApiKeyEnv` (`String`)
  - `githubTokenEnvNames` (`List<String>`)
  - `gcpSecretName` (`String`)
- **Methods:**
  - `shouldRunAgent(String agentName, String repoRoot) -> bool`
  - `resolveGeminiApiKey() -> String?`
  - `resolveGithubToken() -> String?`
- **Constructors:**
  - `TriageConfig.load()`

**Example:**
```dart
import 'package:runtime_ci_tooling/src/triage/utils/config.dart';

final currentConfig = TriageConfig.load();
print('Repo: \${currentConfig.repoOwner}/\${currentConfig.repoName}');
```

### CrossRepoEntry
Configuration mapping indicating an integrated cross-repo structure.
- **Fields:**
  - `owner` (`String`): Organization or Owner scope.
  - `repo` (`String`): Repository namespace.
  - `relationship` (`String`): Purpose of linking.
  - `fullName` (`String`): Returns standard `$owner/$repo` format string.
- **Constructors:**
  - `CrossRepoEntry({required String owner, required String repo, required String relationship})`

### GeminiResult
Structured result wrapping executed tool invocations handled over Gemini process isolation.
- **Fields:**
  - `taskId` (`String`): Original mapping ID to execution context.
  - `response` (`String?`): Standard response block returned natively.
  - `stats` (`Map<String, dynamic>?`): Internal statistics matching request.
  - `error` (`Map<String, dynamic>?`): Unpacked error metrics.
  - `attempts` (`int`): Attempt counts required for output.
  - `durationMs` (`int`): Temporal limit of operation.
  - `success` (`bool`): Execution status.
  - `toolCalls` (`int`): Aggregate tool call count.
  - `turnsUsed` (`int`): Turns used during generation.
  - `errorMessage` (`String`): Formatted error message.
- **Constructors:**
  - `GeminiResult({required String taskId, String? response, Map<String, dynamic>? stats, Map<String, dynamic>? error, int attempts = 1, int durationMs = 0, required bool success})`

### GeminiTask
Singular payload mapped directly into the binary runner queue.
- **Fields:**
  - `id` (`String`): Payload identifier.
  - `prompt` (`String`): Main text instructions.
  - `model` (`String`): Assigned targeting instance.
  - `maxTurns` (`int`): Task-specific execution boundary bounds.
  - `allowedTools` (`List<String>`): Set of CLI execution environments capable over session.
  - `fileIncludes` (`List<String>`): `@` prefixed contextual local includes.
  - `workingDirectory` (`String?`): Execution scoping constraints.
  - `sandbox` (`bool`): Runtime restriction mode toggle.
  - `auditDir` (`String?`): Traceable output dump file system directory mapping.
- **Constructors:**
  - `GeminiTask({required String id, required String prompt, String model = kDefaultFlashModel, int maxTurns = kDefaultMaxTurns, List<String> allowedTools = const [...], List<String> fileIncludes = const [], String? workingDirectory, bool sandbox = false, String? auditDir})`

**Example:**
```dart
import 'package:runtime_ci_tooling/src/triage/utils/gemini_runner.dart';

final task = GeminiTask(
  id: 'analysis-1',
  prompt: 'Analyze this issue',
  model: 'gemini-3.1-pro-preview',
  allowedTools: ['run_shell_command(gh)'],
);
```

### GeminiRunner
Manages parallel execution of isolated instances scaling via queue boundaries and applying exponential backoffs.
- **Fields:**
  - `maxConcurrent` (`int`)
  - `maxRetries` (`int`)
  - `initialBackoff` (`Duration`)
  - `maxBackoff` (`Duration`)
  - `verbose` (`bool`)
- **Methods:**
  - `executeBatch(List<GeminiTask> tasks) -> Future<List<GeminiResult>>`
- **Constructors:**
  - `GeminiRunner({int maxConcurrent = kDefaultMaxConcurrent, int maxRetries = kDefaultMaxRetries, Duration initialBackoff = kDefaultInitialBackoff, Duration maxBackoff = kDefaultMaxBackoff, bool verbose = false})`

### VerificationCheck
Individual phase checkpoint evaluation mapping.
- **Fields:**
  - `name` (`String`): Execution label identifier.
  - `passed` (`bool`): Validation truth condition output.
  - `message` (`String`): Detailed diagnostic context log.
- **Methods:**
  - `toJson() -> Map<String, dynamic>`
- **Constructors:**
  - `VerificationCheck({required String name, required bool passed, required String message})`

### IssueVerification
Combined state report matching individual target validation criteria.
- **Fields:**
  - `issueNumber` (`int`): Reference mapping token.
  - `passed` (`bool`): Total state representation mapping.
  - `checks` (`List<VerificationCheck>`): Aggregate checks.
- **Methods:**
  - `toJson() -> Map<String, dynamic>`
- **Constructors:**
  - `IssueVerification({required int issueNumber, required bool passed, required List<VerificationCheck> checks})`

### VerificationReport
Global validation representation tracking final resolution success markers.
- **Fields:**
  - `verifications` (`List<IssueVerification>`)
  - `timestamp` (`DateTime`)
  - `allPassed` (`bool`)
- **Methods:**
  - `toJson() -> Map<String, dynamic>`
- **Constructors:**
  - `VerificationReport({required List<IssueVerification> verifications, required DateTime timestamp})`

## 2. Enums

### TaskStatus
Indicates the current state of a task.
- `pending`
- `running`
- `completed`
- `failed`
- `skipped`

### AgentType
Specifies the designated expertise agent running an investigation.
- `codeAnalysis`
- `prCorrelation`
- `duplicate`
- `sentiment`
- `changelog`

### RiskLevel
Represents the triage risk associated with an issue resolution.
- `low`
- `medium`
- `high`

### ActionType
Categories of operations available to the execution planner context.
- `label`
- `comment`
- `close`
- `linkPr`
- `linkIssue`
- `none`

## 3. Extensions

*(No public extensions defined in the provided source code)*

## 4. Top-Level Functions & Getters

### Configuration & Context Getters
- **`get kCloseThreshold`**
  - Returns: `double`
  - Description: Gets the auto-close threshold.
- **`get kSuggestCloseThreshold`**
  - Returns: `double`
  - Description: Gets the suggest-close threshold.
- **`get kCommentThreshold`**
  - Returns: `double`
  - Description: Gets the comment threshold.
- **`get config`**
  - Returns: `TriageConfig`
  - Description: Returns the loaded singleton config map instance.

### Orchestration Methods
- **`reloadConfig()`**
  - Returns: `void`
  - Description: Forces a complete reload of the `TriageConfig` state.

- **`act(GamePlan plan, Map<int, List<InvestigationResult>> investigationResults, String repoRoot, {required String runDir})`**
  - Returns: `Future<List<TriageDecision>>`
  - Description: Applies triage decisions enforcing strict idempotency.

- **`crossRepoLink(GamePlan plan, List<TriageDecision> decisions, String repoRoot, {required String runDir})`**
  - Returns: `Future<void>`
  - Description: Searches and links issues cross-repository.

- **`investigate(GamePlan plan, String repoRoot, {required String runDir, bool verbose = false})`**
  - Returns: `Future<Map<int, List<InvestigationResult>>>`
  - Description: Submits the primary batch execution sequence.

- **`link(GamePlan plan, List<TriageDecision> decisions, String repoRoot, {required String runDir})`**
  - Returns: `Future<void>`
  - Description: Integrates mappings across pull requests and issues.

- **`planSingleIssue(int issueNumber, String repoRoot, {required String runDir})`**
  - Returns: `Future<GamePlan>`
  - Description: Configures pipeline for a single issue.

- **`planAutoTriage(String repoRoot, {required String runDir})`**
  - Returns: `Future<GamePlan>`
  - Description: Configures pipeline for auto-triage of multiple issues.

- **`loadPlan({String? runDir})`**
  - Returns: `GamePlan?`
  - Description: Recovers previous pipeline from persistent state.

- **`postReleaseTriage({required String newVersion, required String releaseTag, required String releaseUrl, required String manifestPath, required String repoRoot, required String runDir, bool verbose = false})`**
  - Returns: `Future<void>`
  - Description: Resolves issues after a new release is cut.

- **`preReleaseTriage({required String prevTag, required String newVersion, required String repoRoot, required String runDir, bool verbose = false})`**
  - Returns: `Future<String>`
  - Description: Prepares triage context before release mapping diffs to issues.

- **`verify(GamePlan plan, List<TriageDecision> decisions, String repoRoot, {required String runDir})`**
  - Returns: `Future<VerificationReport>`
  - Description: Validates executed states.

### Agent Builders
- **`buildTask(IssuePlan issue, String repoRoot, {String? resultsDir})`**
  - Returns: `GeminiTask`
  - Description: Present across multiple agent modules to construct explicit agent payload context.

### JSON Schema Providers
- **`validateJsonFile(String path, List<String> requiredKeys)`**
  - Returns: `ValidationResult`
- **`validateGamePlan(String path)`**
  - Returns: `ValidationResult`
- **`validateInvestigationResult(String path)`**
  - Returns: `ValidationResult`
- **`writeJson(String path, Map<String, dynamic> data)`**
  - Returns: `void`
- **`readJson(String path)`**
  - Returns: `Map<String, dynamic>?`

### MCP Configuration Tools
- **`buildGitHubMcpConfig({String? token})`**
  - Returns: `Map<String, dynamic>`
- **`buildSentryMcpConfig()`**
  - Returns: `Map<String, dynamic>`
- **`readSettings(String repoRoot)`**
  - Returns: `Map<String, dynamic>`
- **`writeSettings(String repoRoot, Map<String, dynamic> settings)`**
  - Returns: `void`
- **`ensureMcpConfigured(String repoRoot)`**
  - Returns: `bool`
- **`validateMcpServers(String repoRoot)`**
  - Returns: `Future<Map<String, bool>>`

### CLI Entrypoint
- **`main(List<String> args)`**
  - Returns: `Future<void>`
