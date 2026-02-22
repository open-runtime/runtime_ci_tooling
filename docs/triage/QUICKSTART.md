# Issue Triage Engine - Quickstart

## 1. Overview
The **Issue Triage Engine** is an automated, AI-powered pipeline for GitHub issue triage. It coordinates an ensemble of specialized Gemini agents (`code_analysis`, `pr_correlation`, `duplicate`, `sentiment`, `changelog`) to investigate open issues. The pipeline operates in 6 distinct phases—Plan, Investigate, Act, Verify, Link, and Cross-Repo Link.

## 2. Import
```dart
// Models
import 'package:runtime_ci_tooling/src/triage/models/game_plan.dart';
import 'package:runtime_ci_tooling/src/triage/models/investigation_result.dart';
import 'package:runtime_ci_tooling/src/triage/models/triage_decision.dart';

// Pipeline Phases
import 'package:runtime_ci_tooling/src/triage/phases/plan.dart' as plan_phase;
import 'package:runtime_ci_tooling/src/triage/phases/investigate.dart' as investigate_phase;
import 'package:runtime_ci_tooling/src/triage/phases/act.dart' as act_phase;
import 'package:runtime_ci_tooling/src/triage/phases/verify.dart' as verify_phase;
import 'package:runtime_ci_tooling/src/triage/phases/link.dart' as link_phase;
import 'package:runtime_ci_tooling/src/triage/phases/cross_repo_link.dart' as cross_repo_phase;

// Pre/Post Release & Utils
import 'package:runtime_ci_tooling/src/triage/phases/pre_release.dart' as pre_release_phase;
import 'package:runtime_ci_tooling/src/triage/phases/post_release.dart' as post_release_phase;
import 'package:runtime_ci_tooling/src/triage/utils/config.dart';
import 'package:runtime_ci_tooling/src/triage/utils/run_context.dart';
```

## 3. Data Models and Enums

The Triage Engine relies on several core data models. You can construct or inspect them as follows:

### Enums
- `TaskStatus`: `pending`, `running`, `completed`, `failed`, `skipped`
- `AgentType`: `codeAnalysis`, `prCorrelation`, `duplicate`, `sentiment`, `changelog`
- `RiskLevel`: `low`, `medium`, `high`
- `ActionType`: `label`, `comment`, `close`, `linkPr`, `linkIssue`, `none`

### Core Models

#### TriageTask & IssuePlan
Defines an investigation task and the overall plan for a GitHub issue.
```dart
// Construct a single task within the game plan
final task = TriageTask(
  id: 'issue-42-code',
  agent: AgentType.codeAnalysis,
)
  ..status = TaskStatus.pending
  ..error = null; // Optional error string
  
// Define the issue plan
final issuePlan = IssuePlan(
  number: 42,
  title: 'Bug: Application crashes on startup',
  author: 'johndoe',
  tasks: [task],
)
  ..existingLabels = ['bug']
  ..decision = null; // Map containing the final decision
```

#### LinkSpec & GamePlan
A `GamePlan` orchestrates the entire pipeline, containing multiple issues and links.
```dart
final linkSpec = LinkSpec(
  sourceType: 'issue',
  sourceId: '42',
  targetType: 'pr',
  targetId: '43',
  description: 'Related PR: fixes crash',
)..applied = false;

final gamePlan = GamePlan(
  planId: 'triage-2026-02-22',
  createdAt: DateTime.now(),
  issues: [issuePlan],
)..linksToCreate.add(linkSpec);
```

#### InvestigationResult & RelatedEntity
Results produced by agents such as `code_analysis` or `duplicate`.
```dart
final relatedEntity = RelatedEntity(
  type: 'commit',
  id: 'sha123',
  description: 'Relevant commit',
)..relevance = 0.8;

final result = InvestigationResult(
  agentId: 'code_analysis',
  issueNumber: 42,
  confidence: 0.95,
  summary: 'Fix is clearly merged and tests pass.',
)
  ..evidence.add('Commit sha123 matches issue')
  ..recommendedLabels.add('bug')
  ..suggestedComment = 'This appears to be fixed'
  ..suggestClose = true
  ..closeReason = 'completed'
  ..relatedEntities.add(relatedEntity)
  ..turnsUsed = 2
  ..toolCallsMade = 3
  ..durationMs = 1500;
```

#### TriageAction & TriageDecision
The final aggregated decisions based on the investigation results.
```dart
final action = TriageAction(
  type: ActionType.label,
  description: 'Add needs-investigation label',
)
  ..parameters.addAll({'labels': ['needs-investigation']})
  ..executed = false
  ..verified = false;

final decision = TriageDecision(
  issueNumber: 42,
  aggregateConfidence: 0.85,
  riskLevel: RiskLevel.medium,
  rationale: 'High confidence from code analysis.',
  actions: [action],
)..investigationResults.add(result);
```

#### VerificationCheck & VerificationReport (Phase 4 Verify)
```dart
final check = verify_phase.VerificationCheck(
  name: 'label_bug',
  passed: true,
  message: 'Label "bug" applied',
);

final verification = verify_phase.IssueVerification(
  issueNumber: 42,
  passed: true,
  checks: [check],
);

final report = verify_phase.VerificationReport(
  verifications: [verification],
  timestamp: DateTime.now(),
);
```

## 4. Setup and Run Context

Before executing triage operations, ensure that the `TriageConfig` is loaded and that you have a valid `RunContext`.

```dart
// 1. Initialize global configuration
reloadConfig();

// 2. Define your repository root
final String repoRoot = '/path/to/your/repo';

// 3. Create a unique, run-scoped directory for audit trails using RunContext
final runContext = RunContext.create(repoRoot, 'triage_single', args: ['42']);
final String runDir = runContext.runDir;
```

## 5. Pipeline Execution

### Triaging a Single Issue

The engine follows a strict multi-phase pipeline.

```dart
// 1. PLAN: Fetch issue data and scaffold the GamePlan
GamePlan gamePlan = await plan_phase.planSingleIssue(42, repoRoot, runDir: runDir);

// 2. INVESTIGATE: Dispatch Gemini tasks in parallel
Map<int, List<InvestigationResult>> results = await investigate_phase.investigate(
  gamePlan, 
  repoRoot, 
  runDir: runDir,
  verbose: true,
);

// 3. ACT: Apply decisions (labels, comments, closes)
List<TriageDecision> decisions = await act_phase.act(
  gamePlan, 
  results, 
  repoRoot, 
  runDir: runDir
);

// 4. VERIFY: Confirm via GitHub API that actions were successful
verify_phase.VerificationReport verificationReport = await verify_phase.verify(
  gamePlan, 
  decisions, 
  repoRoot, 
  runDir: runDir
);

// 5. LINK & CROSS-REPO LINK: Bidirectional traceability mapping
await link_phase.link(gamePlan, decisions, repoRoot, runDir: runDir);

if (config.crossRepoEnabled) {
  await cross_repo_phase.crossRepoLink(gamePlan, decisions, repoRoot, runDir: runDir);
}

// Finalize the run context
runContext.finalize(exitCode: 0);
```

### Auto-Triaging All Open Issues

To process all open issues that do not possess the configured `triagedLabel`.

```dart
final runContext = RunContext.create(repoRoot, 'triage_auto');
final String runDir = runContext.runDir;

// Scaffolds a GamePlan for all open untriaged issues
GamePlan autoPlan = await plan_phase.planAutoTriage(repoRoot, runDir: runDir);

if (autoPlan.issues.isNotEmpty) {
  Map<int, List<InvestigationResult>> autoResults = await investigate_phase.investigate(
    autoPlan, 
    repoRoot, 
    runDir: runDir
  );
  
  List<TriageDecision> decisions = await act_phase.act(autoPlan, autoResults, repoRoot, runDir: runDir);
  await verify_phase.verify(autoPlan, decisions, repoRoot, runDir: runDir);
  await link_phase.link(autoPlan, decisions, repoRoot, runDir: runDir);
  
  if (config.crossRepoEnabled) {
    await cross_repo_phase.crossRepoLink(autoPlan, decisions, repoRoot, runDir: runDir);
  }
}

runContext.finalize(exitCode: 0);
```

### Pre-Release and Post-Release Triage

Used during CI/CD to correlate git diffs with issues and close loops.

```dart
// PRE-RELEASE: Scans GitHub/Sentry errors & correlates with git diff.
// Produces an issue_manifest.json and writes artifacts to the RunContext.
String manifestPath = await pre_release_phase.preReleaseTriage(
  prevTag: 'v1.0.0',
  newVersion: '1.0.1',
  repoRoot: repoRoot,
  runDir: runDir,
  verbose: true,
);

// POST-RELEASE: Adds comments, closes resolved issues, links Sentry traces.
await post_release_phase.postReleaseTriage(
  newVersion: '1.0.1',
  releaseTag: 'v1.0.1',
  releaseUrl: 'https://github.com/owner/repo/releases/tag/v1.0.1',
  manifestPath: manifestPath,
  repoRoot: repoRoot,
  runDir: runDir,
);
```

## 6. Configuration and Utilities

The `TriageConfig` singleton (`config`) manages thresholds and pipeline settings loaded from `.runtime_ci/config.json`.

*   **Repository Information**: Requires `repository.name` and `repository.owner`.
*   **Thresholds**: 
    *   `config.autoCloseThreshold` (default: `0.9`)
    *   `config.suggestCloseThreshold` (default: `0.7`)
    *   `config.commentThreshold` (default: `0.5`)
*   **Agents**: Defaults to running `code_analysis`, `pr_correlation`, `duplicate`, `sentiment`, and `changelog` (AgentType enum).
*   **Cross-Repo Settings**: Controlled by `config.crossRepoEnabled` and list of `CrossRepoEntry` via `config.crossRepoRepos`.

### Related Utilities

*   **`GeminiRunner` (`utils/gemini_runner.dart`)**: 
    Executes a batch of `GeminiTask` objects with retry logic, rate limiting, and exponential backoff, returning a list of `GeminiResult` objects.
*   **`RunContext` (`utils/run_context.dart`)**: 
    Creates timestamped directories ensuring full, reproducible audit trails for all operations. Provides methods like `savePrompt`, `saveResponse`, and `finalize`.
*   **`mcp_config.dart` (`utils/mcp_config.dart`)**: 
    Provides `ensureMcpConfigured` to verify required MCP servers (GitHub, Sentry) are configured in the workspace's `.gemini/settings.json`.
*   **`json_schemas.dart` (`utils/json_schemas.dart`)**: 
    Exposes validation utilities like `validateGamePlan` and `validateInvestigationResult` which return a `ValidationResult`.
