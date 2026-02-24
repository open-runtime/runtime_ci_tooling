# Issue Triage Engine API Reference

This document provides a comprehensive API reference for the Issue Triage Engine module. It includes detailed descriptions of models, enums, pipeline utilities, and top-level functions, complete with usage examples demonstrating the builder pattern and correct Dart `camelCase` naming conventions.

## 1. Enums

### TaskStatus
The current execution status of an investigation task.
- `pending`: Task is waiting to be executed.
- `running`: Task is currently executing.
- `completed`: Task finished successfully.
- `failed`: Task encountered an error.
- `skipped`: Task was bypassed.

### AgentType
The specific type of investigation agent handling a task.
- `codeAnalysis`: Analyzes code changes.
- `prCorrelation`: Correlates with pull requests.
- `duplicate`: Finds duplicate issues.
- `sentiment`: Analyzes issue sentiment.
- `changelog`: Checks changelog references.

### RiskLevel
Assessed risk level based on the combined confidence of agents.
- `low`: Low confidence or impact.
- `medium`: Moderate confidence or impact.
- `high`: High confidence or impact.

### ActionType
The type of physical action taken on the repository.
- `label`: Applies a label.
- `comment`: Adds a comment.
- `close`: Closes the issue.
- `linkPr`: Links a PR.
- `linkIssue`: Links an issue.
- `none`: No action taken.

## 2. Models

### TriageAction
A concrete action to take on a GitHub issue.

**Fields:**
- `type` (ActionType): The type of action.
- `description` (String): A human-readable description.
- `parameters` (Map<String, dynamic>): Action-specific parameters (e.g., `labels`, `body`).
- `executed` (bool): Whether the action was performed.
- `verified` (bool): Whether the action's success was verified.
- `error` (String?): Error message if execution failed.

**Example:**
```dart
final action = TriageAction(
  type: ActionType.label,
  description: 'Apply recommended labels',
  parameters: {'labels': ['bug', 'p1']},
)
  ..executed = true
  ..verified = true;
```

### TriageDecision
The aggregated triage decision for a single issue.

**Fields:**
- `issueNumber` (int): Target issue number.
- `aggregateConfidence` (double): Combined confidence score.
- `riskLevel` (RiskLevel): The calculated risk level.
- `rationale` (String): Explanation of the decision.
- `actions` (List<TriageAction>): Actions to perform.
- `investigationResults` (List<InvestigationResult>): Original agent results.

**Example:**
```dart
final decision = TriageDecision(
  issueNumber: 123,
  aggregateConfidence: 0.85,
  riskLevel: RiskLevel.medium,
  rationale: 'High confidence from code analysis.',
  actions: [action],
  investigationResults: [result],
);
```

### TriageTask
A single investigation or action task within the game plan.

**Fields:**
- `id` (String): Unique task identifier.
- `agent` (AgentType): The assigned agent type.
- `status` (TaskStatus): Current task status.
- `error` (String?): Error message if failed.
- `result` (Map<String, dynamic>?): JSON result payload.

**Example:**
```dart
final task = TriageTask(
  id: 'issue-123-code',
  agent: AgentType.codeAnalysis,
)
  ..status = TaskStatus.completed
  ..result = {'confidence': 0.9};
```

### IssuePlan
The triage plan for a single GitHub issue.

**Fields:**
- `number` (int): The issue number.
- `title` (String): The issue title.
- `author` (String): The issue author.
- `existingLabels` (List<String>): Currently applied labels.
- `tasks` (List<TriageTask>): Investigation tasks to run.
- `decision` (Map<String, dynamic>?): Stored triage decision.

**Example:**
```dart
final plan = IssuePlan(
  number: 123,
  title: 'Fix crash on startup',
  author: 'octocat',
  existingLabels: ['bug'],
  tasks: [task],
)..decision = decision.toJson();
```

### LinkSpec
A link to create between two entities (issue, PR, changelog, release notes).

**Fields:**
- `sourceType` (String): Type of the source entity.
- `sourceId` (String): Identifier of the source.
- `targetType` (String): Type of the target entity.
- `targetId` (String): Identifier of the target.
- `description` (String): Link description.
- `applied` (bool): Whether the link was successfully created.

**Example:**
```dart
final link = LinkSpec(
  sourceType: 'issue',
  sourceId: '123',
  targetType: 'pr',
  targetId: '456',
  description: 'Related PR: #456',
)..applied = false;
```

### GamePlan
The top-level game plan that orchestrates the entire triage pipeline.

**Fields:**
- `planId` (String): Unique ID for this run.
- `createdAt` (DateTime): Timestamp of creation.
- `issues` (List<IssuePlan>): Issues to triage.
- `linksToCreate` (List<LinkSpec>): Aggregate list of links to process.

**Example:**
```dart
final gamePlan = GamePlan(
  planId: 'triage-2023-10-01',
  createdAt: DateTime.now(),
  issues: [plan],
);
```

### InvestigationResult
Data class for investigation agent results.

**Fields:**
- `agentId` (String): Identifier of the agent.
- `issueNumber` (int): Targeted issue number.
- `confidence` (double): Score between 0.0 and 1.0.
- `summary` (String): Brief conclusion.
- `evidence` (List<String>): Supporting facts.
- `recommendedLabels` (List<String>): Labels to apply.
- `suggestedComment` (String?): Optional comment text.
- `suggestClose` (bool): Whether closure is recommended.
- `closeReason` (String?): Reason for closure.
- `relatedEntities` (List<RelatedEntity>): Referenced artifacts.
- `turnsUsed` (int): Number of interaction turns.
- `toolCallsMade` (int): Number of tool invocations.
- `durationMs` (int): Execution time.

**Example:**
```dart
final result = InvestigationResult(
  agentId: 'code_analysis',
  issueNumber: 123,
  confidence: 0.95,
  summary: 'Fix merged in PR #456',
  evidence: ['Found commit abc1234'],
  recommendedLabels: ['bug'],
  suggestClose: true,
  closeReason: 'completed',
  relatedEntities: [entity],
);
```

### RelatedEntity
A reference to a related entity (PR, issue, commit, file) found during investigation.

**Fields:**
- `type` (String): Entity type (e.g., 'pr', 'commit').
- `id` (String): Entity identifier.
- `description` (String): Brief description.
- `relevance` (double): Relevance score.

**Example:**
```dart
final entity = RelatedEntity(
  type: 'pr',
  id: '456',
  description: 'Fixes startup crash',
  relevance: 0.9,
);
```

## 3. Pipeline Utilities

### RunContext
Manages a run-scoped audit trail directory for CI/CD operations.

**Methods:**
- `subdir(String name)`
- `savePrompt(String phase, String prompt)`
- `saveResponse(String phase, String rawResponse)`
- `saveArtifact(String phase, String filename, String content)`
- `saveJsonArtifact(String phase, String filename, Map<String, dynamic> data)`
- `artifactPath(String phase, String filename)`
- `readArtifact(String phase, String filename)`
- `hasArtifact(String phase, String filename)`
- `finalize({int? exitCode})`
- `archiveForRelease(String version)`

**Example:**
```dart
final context = RunContext.create('/repo', 'triage_cli');
context.saveJsonArtifact('plan', 'game_plan.json', gamePlan.toJson());
context.finalize(exitCode: 0);
```

### GeminiRunner
Manages parallel Gemini CLI execution with retry and rate limiting.

**Methods:**
- `executeBatch(List<GeminiTask> tasks)`

**Example:**
```dart
final runner = GeminiRunner(
  maxConcurrent: 4,
  maxRetries: 3,
  verbose: true,
);
final results = await runner.executeBatch([task1, task2]);
```

### GeminiTask
A single task to execute via Gemini CLI.

**Example:**
```dart
final task = GeminiTask(
  id: 'task-1',
  prompt: 'Analyze this issue...',
  model: 'gemini-3.1-pro-preview',
  maxTurns: 10,
  allowedTools: ['run_shell_command(git)'],
);
```

### GeminiResult
The structured result from a Gemini CLI invocation.

**Example:**
```dart
final result = GeminiResult(
  taskId: 'task-1',
  response: 'Analysis complete.',
  stats: {'tools': {'totalCalls': 2}},
  success: true,
);
print(result.toolCalls); // Accesses tool calls
```

### TriageConfig
Centralized, config-driven loader for the runtime CI tooling pipeline.

**Example:**
```dart
final config = TriageConfig.load();
if (config.isConfigured) {
  print('Repo: ${config.repoOwner}/${config.repoName}');
}
```

### VerificationReport, IssueVerification, VerificationCheck
Classes for verifying applied actions.

**Example:**
```dart
final check = VerificationCheck(
  name: 'label_bug',
  passed: true,
  message: 'Label applied',
);

final verification = IssueVerification(
  issueNumber: 123,
  passed: true,
  checks: [check],
);

final report = VerificationReport(
  verifications: [verification],
  timestamp: DateTime.now(),
);
```

## 4. Top-Level Functions

### Core Pipeline Phases

- **`planSingleIssue`**
  ```dart
  Future<GamePlan> planSingleIssue(int issueNumber, String repoRoot, {required String runDir})
  ```
  Creates a game plan to run investigation agents for a single issue.

- **`planAutoTriage`**
  ```dart
  Future<GamePlan> planAutoTriage(String repoRoot, {required String runDir})
  ```
  Discovers all open, untriaged issues and creates a game plan for batch evaluation.

- **`investigate`**
  ```dart
  Future<Map<int, List<InvestigationResult>>> investigate(GamePlan plan, String repoRoot, {required String runDir, bool verbose = false})
  ```
  Dispatches agents in parallel to investigate issues listed in the game plan.

- **`act`**
  ```dart
  Future<List<TriageDecision>> act(GamePlan plan, Map<int, List<InvestigationResult>> investigationResults, String repoRoot, {required String runDir})
  ```
  Analyzes investigation results, makes triage decisions, and safely executes GitHub actions.

- **`verify`**
  ```dart
  Future<VerificationReport> verify(GamePlan plan, List<TriageDecision> decisions, String repoRoot, {required String runDir})
  ```
  Confirms that actions determined in the `act` phase were fully applied in the GitHub API.

- **`link`**
  ```dart
  Future<void> link(GamePlan plan, List<TriageDecision> decisions, String repoRoot, {required String runDir})
  ```
  Creates bidirectional cross-references (PRs, issues, changelog).

- **`crossRepoLink`**
  ```dart
  Future<void> crossRepoLink(GamePlan plan, List<TriageDecision> decisions, String repoRoot, {required String runDir})
  ```
  Searches configured related repositories to add linked cross-references.

- **`preReleaseTriage`**
  ```dart
  Future<String> preReleaseTriage({required String prevTag, required String newVersion, required String repoRoot, required String runDir, bool verbose = false})
  ```
  Scans for GitHub and Sentry issues resolved between releases, storing an `issue_manifest.json`.

- **`postReleaseTriage`**
  ```dart
  Future<void> postReleaseTriage({required String newVersion, required String releaseTag, required String releaseUrl, required String manifestPath, required String repoRoot, required String runDir, bool verbose = false})
  ```
  Executes comments and closures for issues listed in the pre-release manifest, acting only once the release has been officially shipped.
