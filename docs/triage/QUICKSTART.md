# Issue Triage Engine - Quickstart

## 1. Overview
The Issue Triage Engine is an AI-powered, multi-agent pipeline designed to automate GitHub issue management. It operates through a 6-phase lifecycle (Plan, Investigate, Act, Verify, Link, and Cross-Repo Link) alongside Pre-Release and Post-Release phases to intelligently classify, investigate, and close issues.

This document details all the data models ("Messages"), Enums, and fields used within the engine, ensuring accurate camelCase property access in Dart.

	## 2. Enums

### `TaskStatus`
Tracks the execution state of a triage task.
- `pending`: Task is queued for execution.
- `running`: Task is currently executing.
- `completed`: Task finished successfully.
- `failed`: Task encountered an error.
- `skipped`: Task was bypassed (e.g., already completed in a previous run).

### `AgentType`
Defines the specialized AI agents available for investigation.
- `codeAnalysis`: Analyzes code and commits for fixes.
- `prCorrelation`: Finds PRs related to the issue.
- `duplicate`: Detects similar or identical issues.
- `sentiment`: Evaluates the tone and consensus in issue comments.
- `changelog`: Checks for issue mentions in changelogs or release notes.

### `RiskLevel`
Represents the confidence and impact of a proposed triage decision.
- `low`: Low confidence, minimal automated action taken.
- `medium`: Moderate confidence, usually suggests closure to a human.
- `high`: High confidence, allows automated issue closure.


### `ActionType`
The type of automated action to perform on GitHub.
- `label`: Apply GitHub labels.
- `comment`: Post a comment.
- `close`: Close the issue.
- `linkPr`: Create a reference to a Pull Request.
- `linkIssue`: Create a reference to another Issue.
- `none`: No action required.


## 3. Data Models (Messages)

### `GamePlan`
The top-level orchestration model for the triage pipeline.
- `planId` (String): Unique identifier for the run.
- `createdAt` (DateTime): Timestamp of plan creation.
- `issues` (List<IssuePlan>): Issues scheduled for triage.
- `linksToCreate` (List<LinkSpec>): Cross-references to be established.

**Example:**
```dart
final plan = GamePlan(
  planId: 'triage-123',
  createdAt: DateTime.now(),
  issues: [],
)..linksToCreate.add(LinkSpec(
  sourceType: 'issue',
  sourceId: '1',
  targetType: 'pr',
  targetId: '42',
  description: 'Related PR',
));
```

### `IssuePlan`
The triage schedule for a single GitHub issue.
- `number` (int): GitHub issue number.
- `title` (String): Issue title.
- `author` (String): Issue author username.
- `existingLabels` (List<String>): Labels already present.
- `tasks` (List<TriageTask>): Agent tasks to run for this issue.
- `decision` (Map<String, dynamic>?): The final decision after investigation.

**Example:**
```dart
final issue = IssuePlan(
  number: 101,
  title: 'Bug: Crash on startup',
  author: 'octocat',
  tasks: [],
)..decision = {'status': 'resolved'};
```

### `TriageTask`
A specific agent investigation task.
- `id` (String): Unique task identifier.
- `agent` (AgentType): The agent to execute.
- `status` (TaskStatus): Current execution status.
- `error` (String?): Error message if failed.
- `result` (Map<String, dynamic>?): The raw investigation output.

**Example:**
```dart
final task = TriageTask(
  id: 'task-1',
  agent: AgentType.codeAnalysis,
)
  ..status = TaskStatus.running
  ..error = null;
```

### `InvestigationResult`
The structured findings produced by an AI agent.
- `agentId` (String): Identifier of the agent that produced this result.
- `issueNumber` (int): The associated issue number.
- `confidence` (double): Confidence score (0.0 to 1.0).
- `summary` (String): High-level summary of findings.
- `evidence` (List<String>): Supporting evidence for the conclusion.
- `recommendedLabels` (List<String>): Labels the agent recommends applying.
- `suggestedComment` (String?): Text for a potential automated comment.
- `suggestClose` (bool): Whether the agent recommends closing the issue.
- `closeReason` (String?): Reason for closure (e.g., "completed").
- `relatedEntities` (List<RelatedEntity>): Other issues, PRs, or commits found.
- `turnsUsed` (int): Number of LLM interaction turns.
- `toolCallsMade` (int): Number of tools invoked.
- `durationMs` (int): Execution duration in milliseconds.

**Example:**
```dart
final result = InvestigationResult(
  agentId: 'code_analysis',
  issueNumber: 42,
  confidence: 0.95,
  summary: 'Fix merged in PR #43.',
  evidence: ['Commit abc1234 references this issue.'],
  recommendedLabels: ['bug', 'resolved'],
  suggestClose: true,
  closeReason: 'completed',
);
```

### `RelatedEntity`
A reference to another artifact found during investigation.
- `type` (String): Entity type ('pr', 'issue', 'commit', 'file').
- `id` (String): Identifier of the entity.
- `description` (String): Brief context.
- `relevance` (double): Relevance score (0.0 to 1.0).

**Example:**
```dart
final entity = RelatedEntity(
  type: 'pr',
  id: '43',
  description: 'Fixes startup crash',
  relevance: 0.9,
);
```

### `TriageDecision`
The final, aggregated decision across all agents.
- `issueNumber` (int): The issue being decided upon.
- `aggregateConfidence` (double): Weighted average confidence from agents.
- `riskLevel` (RiskLevel): Assessed risk of the automated action.
- `rationale` (String): Explanation of the decision.
- `actions` (List<TriageAction>): Concrete GitHub actions to perform.
- `investigationResults` (List<InvestigationResult>): The underlying agent results.

**Example:**
```dart
final decision = TriageDecision(
  issueNumber: 42,
  aggregateConfidence: 0.92,
  riskLevel: RiskLevel.high,
  rationale: 'Multiple agents confirmed the fix.',
  actions: [],
);
```

### `TriageAction`
A concrete operation to execute against the GitHub API.
- `type` (ActionType): The type of action to perform.
- `description` (String): Human-readable intent.
- `parameters` (Map<String, dynamic>): Arguments for the action (e.g., label names, comment body).
- `executed` (bool): Whether the action has been performed.
- `verified` (bool): Whether the action's success was confirmed.
- `error` (String?): Any execution errors.

**Example:**
```dart
final action = TriageAction(
  type: ActionType.label,
  description: 'Apply resolution labels',
  parameters: {'labels': ['resolved']},
)
  ..executed = false
  ..verified = false;
```

### `LinkSpec`
A cross-reference to establish between two entities.
- `sourceType` (String): Type of the source (e.g., 'issue').
- `sourceId` (String): Identifier of the source.
- `targetType` (String): Type of the target (e.g., 'pr', 'changelog').
- `targetId` (String): Identifier of the target.
- `description` (String): Context for the link.
- `applied` (bool): Whether the link has been created.

**Example:**
```dart
final link = LinkSpec(
  sourceType: 'issue',
  sourceId: '101',
  targetType: 'pr',
  targetId: '102',
  description: 'Resolved by PR #102',
)..applied = false;
```

## 4. Setup and Execution

To execute triage operations programmatically, initialize the configuration and MCP settings:

```dart
import 'package:runtime_ci_tooling/src/triage/utils/config.dart';
import 'package:runtime_ci_tooling/src/triage/utils/mcp_config.dart' as mcp;

void setupTriage(String repoRoot) {
  reloadConfig();
  mcp.ensureMcpConfigured(repoRoot);
}
```

Then invoke individual phases as required:

```dart
import 'package:runtime_ci_tooling/src/triage/phases/plan.dart' as plan_phase;
import 'package:runtime_ci_tooling/src/triage/phases/investigate.dart' as investigate_phase;

Future<void> runTriage(String repoRoot, String runDir) async {
  final plan = await plan_phase.planAutoTriage(repoRoot, runDir: runDir);
  if (plan.issues.isNotEmpty) {
    final results = await investigate_phase.investigate(plan, repoRoot, runDir: runDir);
    // Continue to act, verify, and link...
  }
}
```
