# Issue Triage Engine Quickstart

## 1. Overview
The Issue Triage Engine is an AI-powered pipeline that automates the assessment, labeling, and closure of GitHub issues. Using parallel Gemini agents (`codeAnalysis`, `duplicate`, `prCorrelation`, `sentiment`, and `changelog`), it investigates open issues against codebase diffs and PRs, computes confidence scores, and takes programmatic actions (like closing issues or cross-linking to Sentry errors). 

It exposes a 6-phase triage pipeline (`Plan`, `Investigate`, `Act`, `Verify`, `Link`, `Cross-Repo Link`) alongside specific hooks for pre- and post-release automation.

## 2. Import
Import the pipeline phases, models, and utilities from the `src/triage` library:

```dart
import 'package:runtime_ci_tooling/src/triage/models/game_plan.dart';
import 'package:runtime_ci_tooling/src/triage/models/triage_decision.dart';
import 'package:runtime_ci_tooling/src/triage/utils/config.dart';
import 'package:runtime_ci_tooling/src/triage/utils/mcp_config.dart' as mcp;

// Phases
import 'package:runtime_ci_tooling/src/triage/phases/plan.dart' as plan_phase;
import 'package:runtime_ci_tooling/src/triage/phases/investigate.dart' as investigate_phase;
import 'package:runtime_ci_tooling/src/triage/phases/act.dart' as act_phase;
import 'package:runtime_ci_tooling/src/triage/phases/verify.dart' as verify_phase;
import 'package:runtime_ci_tooling/src/triage/phases/link.dart' as link_phase;
import 'package:runtime_ci_tooling/src/triage/phases/cross_repo_link.dart' as cross_repo_phase;
import 'package:runtime_ci_tooling/src/triage/phases/pre_release.dart' as pre_release_phase;
import 'package:runtime_ci_tooling/src/triage/phases/post_release.dart' as post_release_phase;
```

## 3. Setup
The engine relies on `.runtime_ci/config.json` for repository configuration and `.gemini/settings.json` for MCP tool access. Ensure these are configured before invoking the pipeline.

```dart
Future<void> setupTriage(String repoRoot) async {
  // 1. Reload configuration from .runtime_ci/config.json
  reloadConfig();
  
  // 2. Ensure GitHub and Sentry MCP servers are initialized in settings.json
  mcp.ensureMcpConfigured(repoRoot);
  
  // 3. Validate MCP status (Docker, etc.)
  final status = await mcp.validateMcpServers(repoRoot);
  print('GitHub MCP Configured: ${status['github']}');
}
```

## 4. Common Operations

### Standard Triage Pipeline (Single Issue)
Orchestrate the core phases to investigate and automatically label/comment on an issue.

```dart
Future<void> triageIssue(int issueNumber, String repoRoot, String runDir) async {
  // Phase 1: Build the GamePlan
  final gamePlan = await plan_phase.planSingleIssue(
    issueNumber, 
    repoRoot, 
    runDir: runDir,
  );

  // Phase 2: Run Gemini agents in parallel
  final results = await investigate_phase.investigate(
    gamePlan, 
    repoRoot, 
    runDir: runDir, 
    verbose: true,
  );

  // Phase 3: Execute decisions (apply labels, close issues based on confidence)
  final decisions = await act_phase.act(
    gamePlan, 
    results, 
    repoRoot, 
    runDir: runDir,
  );

  // Phase 4: Verify
  final report = await verify_phase.verify(
    gamePlan,
    decisions,
    repoRoot,
    runDir: runDir,
  );

  // Phase 5: Link
  await link_phase.link(gamePlan, decisions, repoRoot, runDir: runDir);

  // Phase 5b: Cross-Repo Link
  await cross_repo_phase.crossRepoLink(gamePlan, decisions, repoRoot, runDir: runDir);
}
```

### Auto-Triage All Untriaged Issues
Discovers all open issues lacking the configured `triagedLabel` and processes them in batch.

```dart
Future<void> runAutoTriage(String repoRoot, String runDir) async {
  final gamePlan = await plan_phase.planAutoTriage(repoRoot, runDir: runDir);
  if (gamePlan.issues.isEmpty) return;

  final results = await investigate_phase.investigate(gamePlan, repoRoot, runDir: runDir);
  final decisions = await act_phase.act(gamePlan, results, repoRoot, runDir: runDir);
  
  await verify_phase.verify(gamePlan, decisions, repoRoot, runDir: runDir);
  await link_phase.link(gamePlan, decisions, repoRoot, runDir: runDir);
  await cross_repo_phase.crossRepoLink(gamePlan, decisions, repoRoot, runDir: runDir);
}
```

### Pre-Release Triage
Scan recent GitHub issues and Sentry errors, correlating them with the git diff before a release.

```dart
Future<void> scanForRelease(String repoRoot, String runDir) async {
  final manifestPath = await pre_release_phase.preReleaseTriage(
    prevTag: 'v1.0.0',
    newVersion: '1.1.0',
    repoRoot: repoRoot,
    runDir: runDir,
  );
  print('Issue manifest generated at: $manifestPath');
}
```

### Post-Release Triage
Close the loop by commenting on related issues, automatically closing high-confidence fixes, and linking Sentry issues.

```dart
Future<void> closeReleaseLoop(String repoRoot, String runDir, String manifestPath) async {
  await post_release_phase.postReleaseTriage(
    newVersion: '1.1.0',
    releaseTag: 'v1.1.0',
    releaseUrl: 'https://github.com/owner/repo/releases/tag/v1.1.0',
    manifestPath: manifestPath,
    repoRoot: repoRoot,
    runDir: runDir,
  );
}
```

## 5. Configuration
Configuration is managed through `TriageConfig` (accessed globally via `config`) and loaded from `.runtime_ci/config.json`. Key settings include:

*   **Repository Defaults**: `repository.name`, `repository.owner`, `repository.triaged_label`.
*   **Confidence Thresholds**: `thresholds.auto_close` (default: 0.9), `thresholds.suggest_close` (default: 0.7), `thresholds.comment` (default: 0.5).
*   **Enabled Agents**: `agents.enabled` (e.g., `codeAnalysis`, `duplicate`).
*   **Sentry & Cross-Repo**: `sentry.organization`, `sentry.projects`, and `cross_repo.repos` to hook into dependent repositories.

## 6. Related Modules
*   **`utils/gemini_runner.dart`**: Provides the `GeminiRunner` and `GeminiTask` classes used by the investigation phases to execute concurrent, rate-limited CLI prompts with retries.
*   **`utils/run_context.dart`**: Provides `RunContext` for managing timestamped audit trails and artifacts across CI/CD operations (e.g., `.runtime_ci/runs/`).
*   **`utils/json_schemas.dart`**: Handlers like `validateGamePlan` and `validateInvestigationResult` to strictly ensure AI outputs conform to expected schema signatures before acting.

## 7. Data Models (Messages & Enums)

The Issue Triage Engine uses strongly-typed Dart data models (acting as messages). In Dart, all JSON properties formatted in snake_case are accessed as **camelCase** fields. Note: The examples below use the Dart cascade notation (`..`) to illustrate the builder pattern.

### Enums

#### `TaskStatus`
Tracks the lifecycle of an individual agent task.
*   `TaskStatus.pending`
*   `TaskStatus.running`
*   `TaskStatus.completed`
*   `TaskStatus.failed`
*   `TaskStatus.skipped`

#### `AgentType`
Identifies the specific AI agent performing the investigation.
*   `AgentType.codeAnalysis`
*   `AgentType.prCorrelation`
*   `AgentType.duplicate`
*   `AgentType.sentiment`
*   `AgentType.changelog`

#### `RiskLevel`
Determines the confidence and risk associated with automatically acting on an issue.
*   `RiskLevel.low`
*   `RiskLevel.medium`
*   `RiskLevel.high`

#### `ActionType`
Specifies the programmatic action to take on a GitHub issue.
*   `ActionType.label`
*   `ActionType.comment`
*   `ActionType.close`
*   `ActionType.linkPr`
*   `ActionType.linkIssue`
*   `ActionType.none`

### Messages

#### `TriageTask`
Represents a single investigation or action task within the game plan.
*   `String id`
*   `AgentType agent`
*   `TaskStatus status`
*   `String? error`
*   `Map<String, dynamic>? result`

**Example:**
```dart
final task = TriageTask(
  id: 'issue-123-code',
  agent: AgentType.codeAnalysis,
)
  ..status = TaskStatus.completed
  ..error = null
  ..result = {'confidence': 0.9};
```

#### `IssuePlan`
The triage plan for a single GitHub issue.
*   `int number`
*   `String title`
*   `String author`
*   `List<String> existingLabels`
*   `List<TriageTask> tasks`
*   `Map<String, dynamic>? decision`
*   `bool investigationComplete` (getter)

**Example:**
```dart
final plan = IssuePlan(
  number: 123,
  title: 'Fix memory leak',
  author: 'octocat',
  existingLabels: ['bug'],
  tasks: [task],
)..decision = {'risk_level': 'high'};
```

#### `LinkSpec`
A link to create between two entities (issue, PR, changelog, release notes).
*   `String sourceType`
*   `String sourceId`
*   `String targetType`
*   `String targetId`
*   `String description`
*   `bool applied`

**Example:**
```dart
final link = LinkSpec(
  sourceType: 'issue',
  sourceId: '123',
  targetType: 'pr',
  targetId: '456',
  description: 'Fixes #123',
)..applied = false;
```

#### `GamePlan`
The top-level game plan that orchestrates the entire triage pipeline.
*   `String planId`
*   `DateTime createdAt`
*   `List<IssuePlan> issues`
*   `List<LinkSpec> linksToCreate`

**Example:**
```dart
final gamePlan = GamePlan(
  planId: 'triage-2026-02-24',
  createdAt: DateTime.now(),
  issues: [plan],
  linksToCreate: [link],
);
```

#### `InvestigationResult`
Data class for investigation agent results containing confidence scores and recommended actions.
*   `String agentId`
*   `int issueNumber`
*   `double confidence`
*   `String summary`
*   `List<String> evidence`
*   `List<String> recommendedLabels`
*   `String? suggestedComment`
*   `bool suggestClose`
*   `String? closeReason`
*   `List<RelatedEntity> relatedEntities`
*   `int turnsUsed`
*   `int toolCallsMade`
*   `int durationMs`

**Example:**
```dart
final result = InvestigationResult(
  agentId: 'code_analysis',
  issueNumber: 123,
  confidence: 0.95,
  summary: 'Fix merged in PR #456',
  evidence: ['Found commit fixing the issue'],
  recommendedLabels: ['bug', 'resolved'],
  suggestClose: true,
  closeReason: 'completed',
  relatedEntities: [entity],
  turnsUsed: 2,
  toolCallsMade: 3,
  durationMs: 1500,
);
```

#### `RelatedEntity`
A reference to a related entity (PR, issue, commit, file) found during investigation.
*   `String type`
*   `String id`
*   `String description`
*   `double relevance`

**Example:**
```dart
final entity = RelatedEntity(
  type: 'pr',
  id: '456',
  description: 'PR fixing memory leak',
  relevance: 0.95,
);
```

#### `TriageAction`
A concrete action to take on a GitHub issue.
*   `ActionType type`
*   `String description`
*   `Map<String, dynamic> parameters`
*   `bool executed`
*   `bool verified`
*   `String? error`

**Example:**
```dart
final action = TriageAction(
  type: ActionType.close,
  description: 'Close issue',
  parameters: {'state_reason': 'completed'},
)
  ..executed = true
  ..verified = true
  ..error = null;
```

#### `TriageDecision`
The aggregated triage decision for a single issue.
*   `int issueNumber`
*   `double aggregateConfidence`
*   `RiskLevel riskLevel`
*   `String rationale`
*   `List<TriageAction> actions`
*   `List<InvestigationResult> investigationResults`

**Example:**
```dart
final decision = TriageDecision(
  issueNumber: 123,
  aggregateConfidence: 0.95,
  riskLevel: RiskLevel.high,
  rationale: 'High confidence from code analysis agent',
  actions: [action],
  investigationResults: [result],
);
```

## 8. Services (Public API RPCs)

The `Issue Triage Engine` provides several core functions (acting as service RPCs) that operate on these messages. All service methods are asynchronous and use camelCase formatting for arguments.

### `planSingleIssue`
Creates a game plan for a single issue.
*   **Parameters:** `int issueNumber`, `String repoRoot`, `{required String runDir}`
*   **Returns:** `Future<GamePlan>`

### `planAutoTriage`
Creates a game plan for all open untriaged issues.
*   **Parameters:** `String repoRoot`, `{required String runDir}`
*   **Returns:** `Future<GamePlan>`

### `investigate`
Dispatches investigation agents in parallel and updates the game plan.
*   **Parameters:** `GamePlan plan`, `String repoRoot`, `{required String runDir, bool verbose = false}`
*   **Returns:** `Future<Map<int, List<InvestigationResult>>>`

### `act`
Applies triage decisions based on investigation results (labels, comments, closure).
*   **Parameters:** `GamePlan plan`, `Map<int, List<InvestigationResult>> investigationResults`, `String repoRoot`, `{required String runDir}`
*   **Returns:** `Future<List<TriageDecision>>`

### `verify`
Confirms that all actions from the Act phase were applied successfully.
*   **Parameters:** `GamePlan plan`, `List<TriageDecision> decisions`, `String repoRoot`, `{required String runDir}`
*   **Returns:** `Future<VerificationReport>`

### `link`
Creates bidirectional references between issues, PRs, changelogs, and release notes.
*   **Parameters:** `GamePlan plan`, `List<TriageDecision> decisions`, `String repoRoot`, `{required String runDir}`
*   **Returns:** `Future<void>`

### `crossRepoLink`
Searches for related issues in configured dependent repositories and posts cross-references.
*   **Parameters:** `GamePlan plan`, `List<TriageDecision> decisions`, `String repoRoot`, `{required String runDir}`
*   **Returns:** `Future<void>`

### `preReleaseTriage`
Scans issues and produces an issue manifest for the upcoming release.
*   **Parameters:** `{required String prevTag, required String newVersion, required String repoRoot, required String runDir, bool verbose = false}`
*   **Returns:** `Future<String>` (path to generated manifest)

### `postReleaseTriage`
Runs after a GitHub Release to comment on, close, or link related issues across repositories and Sentry.
*   **Parameters:** `{required String newVersion, required String releaseTag, required String releaseUrl, required String manifestPath, required String repoRoot, required String runDir, bool verbose = false}`
*   **Returns:** `Future<void>`
