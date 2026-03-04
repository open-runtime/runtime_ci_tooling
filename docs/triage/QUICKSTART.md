# Issue Triage Engine Quickstart

## 1. Overview
The **Issue Triage Engine** is an AI-powered pipeline that automatically investigates, labels, cross-links, and closes GitHub issues. It utilizes multiple specialized Gemini agents working in parallel to process issues, build a `GamePlan`, produce an `InvestigationResult`, and ultimately formulate a `TriageDecision` with actionable, idempotent tasks executed through the GitHub and Sentry MCP servers.

## 2. Import

To use the Triage Engine modules programmatically, import the required phases, models, and utilities:

```dart
import 'package:runtime_ci_tooling/src/triage/models/game_plan.dart';
import 'package:runtime_ci_tooling/src/triage/models/investigation_result.dart';
import 'package:runtime_ci_tooling/src/triage/models/triage_decision.dart';
import 'package:runtime_ci_tooling/src/triage/phases/act.dart' as act_phase;
import 'package:runtime_ci_tooling/src/triage/phases/investigate.dart' as investigate_phase;
import 'package:runtime_ci_tooling/src/triage/phases/plan.dart' as plan_phase;
import 'package:runtime_ci_tooling/src/triage/phases/post_release.dart' as post_release_phase;
import 'package:runtime_ci_tooling/src/triage/phases/pre_release.dart' as pre_release_phase;
import 'package:runtime_ci_tooling/src/triage/utils/config.dart';
import 'package:runtime_ci_tooling/src/triage/utils/mcp_config.dart' as mcp;
```

## 3. Setup

The Triage Engine is configuration-driven. Before running operations, ensure that the global `config` singleton is loaded and MCP servers (GitHub, Sentry) are configured.

```dart
import 'package:runtime_ci_tooling/src/triage/utils/config.dart';
import 'package:runtime_ci_tooling/src/triage/utils/mcp_config.dart' as mcp;

void setupTriage(String repoRoot) {
  // Load the TriageConfig singleton from `.runtime_ci/config.json`
  reloadConfig();

  // Ensures .gemini/settings.json exists with the required MCP configurations
  mcp.ensureMcpConfigured(repoRoot);

  // Validate API Key based on the config
  final geminiKey = config.resolveGeminiApiKey();
  if (geminiKey == null || geminiKey.isEmpty) {
    throw StateError('GEMINI_API_KEY environment variable is missing.');
  }
}
```

## 4. Common Operations

### Triaging a Single Issue

This process creates a `GamePlan`, executes `investigate` via parallel agents, and then uses `act` to apply the resulting `TriageDecision`.

```dart
import 'package:runtime_ci_tooling/src/triage/models/game_plan.dart';
import 'package:runtime_ci_tooling/src/triage/models/investigation_result.dart';
import 'package:runtime_ci_tooling/src/triage/models/triage_decision.dart';
import 'package:runtime_ci_tooling/src/triage/phases/act.dart' as act_phase;
import 'package:runtime_ci_tooling/src/triage/phases/investigate.dart' as investigate_phase;
import 'package:runtime_ci_tooling/src/triage/phases/plan.dart' as plan_phase;

Future<void> triageSingleIssue(int issueNumber, String repoRoot, String runDir) async {
  // Phase 1: Create a GamePlan for the specific issue
  GamePlan gamePlan = await plan_phase.planSingleIssue(
    issueNumber, 
    repoRoot, 
    runDir: runDir,
  );

  // Phase 2: Investigate using configured agents
  Map<int, List<InvestigationResult>> results = await investigate_phase.investigate(
    gamePlan, 
    repoRoot, 
    runDir: runDir,
  );

  // Phase 3: Act on the results (comments, applies labels, closes issue if confident)
  List<TriageDecision> decisions = await act_phase.act(
    gamePlan, 
    results, 
    repoRoot, 
    runDir: runDir,
  );
}
```

### Auto-Triaging All Open Issues

This searches for all open issues without the `config.triagedLabel` and evaluates them in bulk.

```dart
import 'package:runtime_ci_tooling/src/triage/models/game_plan.dart';
import 'package:runtime_ci_tooling/src/triage/phases/act.dart' as act_phase;
import 'package:runtime_ci_tooling/src/triage/phases/investigate.dart' as investigate_phase;
import 'package:runtime_ci_tooling/src/triage/phases/plan.dart' as plan_phase;

Future<void> runAutoTriage(String repoRoot, String runDir) async {
  // Phase 1: Discovers all untriaged issues
  GamePlan gamePlan = await plan_phase.planAutoTriage(repoRoot, runDir: runDir);

  if (gamePlan.issues.isNotEmpty) {
    // Phase 2: Parallel Investigation
    final results = await investigate_phase.investigate(gamePlan, repoRoot, runDir: runDir);
    
    // Phase 3: Act
    await act_phase.act(gamePlan, results, repoRoot, runDir: runDir);
  }
}
```

### Pre-Release Triage

Used immediately before a release to scan all resolved GitHub and Sentry issues against code changes, generating an `issue_manifest.json`.

```dart
import 'package:runtime_ci_tooling/src/triage/phases/pre_release.dart' as pre_release_phase;

Future<void> runPreReleaseTriage(String repoRoot, String runDir) async {
  final manifestPath = await pre_release_phase.preReleaseTriage(
    prevTag: 'v1.0.0',
    newVersion: '1.1.0',
    repoRoot: repoRoot,
    runDir: runDir,
  );
  print('Pre-Release Manifest created at: $manifestPath');
}
```

### Post-Release Triage

Used after a release has been cut. Cross-references the `issue_manifest.json` to post GitHub comments with release links, close confident issues, and update linked issues.

```dart
import 'package:runtime_ci_tooling/src/triage/phases/post_release.dart' as post_release_phase;

Future<void> runPostReleaseTriage(String repoRoot, String runDir, String manifestPath) async {
  await post_release_phase.postReleaseTriage(
    newVersion: '1.1.0',
    releaseTag: 'v1.1.0',
    releaseUrl: 'https://github.com/open-runtime/repo/releases/tag/v1.1.0',
    manifestPath: manifestPath,
    repoRoot: repoRoot,
    runDir: runDir,
  );
}
```

## 5. Configuration

All configuration is driven by the `.runtime_ci/config.json` file in the repository root. This is abstracted via the `TriageConfig` singleton class (exposed as `config`).

### Environment Variables
* `GEMINI_API_KEY`: Required for Gemini CLI orchestration. (Configurable via `secrets.gemini_api_key_env`).
* `GH_TOKEN`, `GITHUB_TOKEN`, or `GITHUB_PAT`: Required for the GitHub MCP server.

### Key Config Variables (`config`)
* `config.repoOwner` / `config.repoName`: The target organization and repository name.
* `config.enabledAgents`: List of agents that will execute in Phase 2 (`code_analysis`, `pr_correlation`, `duplicate`, `sentiment`, `changelog`).
* `config.autoCloseThreshold`: The confidence threshold needed to automatically close an issue (default `0.9`).
* `config.suggestCloseThreshold`: The confidence threshold needed to comment a suggestion to close an issue (default `0.7`).
* `config.commentThreshold`: The confidence threshold to link related PRs/issues (default `0.5`).

## 6. Related Modules
* **GeminiRunner (`utils/gemini_runner.dart`)**: Exposes `executeBatch` for executing `GeminiTask`s in parallel, applying automatic retry backoffs, and limiting concurrency.
* **RunContext (`utils/run_context.dart`)**: Automatically manages local, isolated disk structures (`.runtime_ci/runs/`) to store the audit trail, JSON artifacts, and system prompts of each triage attempt.

## 7. Data Models and Enums

The Triage Engine utilizes several core data models to track the state of issues, investigation tasks, and the final action plan. Field names in these classes strictly adhere to Dart `camelCase` conventions.

### Enums

The engine leverages standard enums to categorize agent types, execution statuses, and action intents.

```dart
import 'package:runtime_ci_tooling/src/triage/models/game_plan.dart';

// TaskStatus controls the lifecycle of each TriageTask
TaskStatus status = TaskStatus.pending;
// Possible values: TaskStatus.pending, TaskStatus.running, TaskStatus.completed, TaskStatus.failed, TaskStatus.skipped

// AgentType identifies the specific AI agent
AgentType agent = AgentType.codeAnalysis;
// Possible values: AgentType.codeAnalysis, AgentType.prCorrelation, AgentType.duplicate, AgentType.sentiment, AgentType.changelog

// RiskLevel identifies the confidence/risk profile of a TriageDecision
RiskLevel risk = RiskLevel.low;
// Possible values: RiskLevel.low, RiskLevel.medium, RiskLevel.high

// ActionType categorizes a specific TriageAction
ActionType action = ActionType.label;
// Possible values: ActionType.label, ActionType.comment, ActionType.close, ActionType.linkPr, ActionType.linkIssue, ActionType.none
```

### GamePlan and TriageTask Models

The `GamePlan` encapsulates the full scope of a triage run, organizing multiple `IssuePlan` objects. Each `IssuePlan` contains a list of `TriageTask` items assigned to different agents.

```dart
import 'package:runtime_ci_tooling/src/triage/models/game_plan.dart';

// Constructing a TriageTask using standard camelCase fields and optional mutable cascades
final task = TriageTask(
  id: 'issue-42-code',
  agent: AgentType.codeAnalysis,
)
  ..status = TaskStatus.running
  ..error = null;

// Constructing an IssuePlan
final issuePlan = IssuePlan(
  number: 42,
  title: 'Fix null pointer exception in auth service',
  author: 'dev123',
  existingLabels: ['bug', 'p1'],
  tasks: [task],
)
  ..decision = null;

// Creating a GamePlan
final plan = GamePlan(
  planId: 'triage-2023-10-27-run1',
  createdAt: DateTime.now(),
  issues: [issuePlan],
)
  ..linksToCreate.add(
    LinkSpec(
      sourceType: 'issue',
      sourceId: '42',
      targetType: 'pr',
      targetId: '99',
      description: 'Fix PR for auth service',
    )..applied = false,
  );
```

### InvestigationResult

After processing an issue, an agent returns an `InvestigationResult`. This captures the confidence score, findings summary, and any related entities (like pull requests or other issues) discovered during execution.

```dart
import 'package:runtime_ci_tooling/src/triage/models/investigation_result.dart';

// Related entities link an issue to PRs or commits
final entity = RelatedEntity(
  type: 'pr',
  id: '101',
  description: 'Added null check in auth service',
  relevance: 0.95,
);

// The InvestigationResult structure holds all agent findings
final result = InvestigationResult(
  agentId: 'code_analysis',
  issueNumber: 42,
  confidence: 0.95,
  summary: 'Code fix is merged and covered by tests.',
  evidence: ['Found commit abc1234 referencing #42'],
  recommendedLabels: ['status: fixed'],
  suggestedComment: 'This has been addressed in recent commits.',
  suggestClose: true,
  closeReason: 'completed',
  relatedEntities: [entity],
  turnsUsed: 3,
  toolCallsMade: 5,
  durationMs: 12000,
);
```

### TriageDecision and TriageAction

The results from multiple agents are aggregated into a single `TriageDecision`. This decision yields a list of `TriageAction` objects (e.g., adding a label or posting a comment).

```dart
import 'package:runtime_ci_tooling/src/triage/models/triage_decision.dart';

// Constructing a TriageAction with mutable fields tracked via cascade
final action = TriageAction(
  type: ActionType.label,
  description: 'Add needs-investigation label',
  parameters: {'labels': ['needs-investigation']},
)
  ..executed = false
  ..verified = false
  ..error = null;

// TriageDecision aggregates results and prescribes actions
final decision = TriageDecision(
  issueNumber: 42,
  aggregateConfidence: 0.95,
  riskLevel: RiskLevel.high,
  rationale: 'Multiple agents agree the issue is resolved via PR #101.',
  actions: [action],
  investigationResults: [result], // Reusing the InvestigationResult from above
);
```
