# Quickstart: Issue Triage Engine

## 1. Overview
The Issue Triage Engine is a 6-phase AI-powered pipeline that autonomously investigates, categorizes, and manages GitHub issues. It uses Gemini AI agents to analyze code, find duplicate issues, correlate pull requests, assess comment sentiment, and cross-link related artifacts across repositories. It also provides specialized pre-release and post-release workflows to close the loop on resolved issues.

## 2. Import
To use the triage phases and models in your Dart code, import the necessary files from the `src/triage` directory:

```dart
import 'package:runtime_ci_tooling/src/triage/models/game_plan.dart';
import 'package:runtime_ci_tooling/src/triage/models/investigation_result.dart';
import 'package:runtime_ci_tooling/src/triage/models/triage_decision.dart';
import 'package:runtime_ci_tooling/src/triage/phases/act.dart' as act_phase;
import 'package:runtime_ci_tooling/src/triage/phases/cross_repo_link.dart' as cross_repo_phase;
import 'package:runtime_ci_tooling/src/triage/phases/investigate.dart' as investigate_phase;
import 'package:runtime_ci_tooling/src/triage/phases/link.dart' as link_phase;
import 'package:runtime_ci_tooling/src/triage/phases/plan.dart' as plan_phase;
import 'package:runtime_ci_tooling/src/triage/phases/post_release.dart' as post_release_phase;
import 'package:runtime_ci_tooling/src/triage/phases/pre_release.dart' as pre_release_phase;
import 'package:runtime_ci_tooling/src/triage/phases/verify.dart' as verify_phase;
import 'package:runtime_ci_tooling/src/triage/utils/config.dart';
import 'package:runtime_ci_tooling/src/triage/utils/mcp_config.dart' as mcp;
import 'package:runtime_ci_tooling/src/triage/utils/run_context.dart';
```

## 3. Setup
Before running the triage pipeline, you should ensure MCP is configured and your `TriageConfig` is loaded.

```dart
final String repoRoot = '/path/to/your/repo';

// Reload config from `.runtime_ci/config.json`
reloadConfig();

// Ensure GitHub and Sentry MCP servers are configured in `.gemini/settings.json`
mcp.ensureMcpConfigured(repoRoot);

// Create a new RunContext for the current execution
final runContext = RunContext.create(repoRoot, 'triage');
final String runDir = runContext.runDir;
```

## 4. Models and Enums

The Triage Engine uses several data classes to represent its plans, tasks, and results.

### Enums

#### `TaskStatus`
Status of an investigation task.
- `pending`: Task is queued.
- `running`: Task is currently executing.
- `completed`: Task finished successfully.
- `failed`: Task failed to complete.
- `skipped`: Task was skipped.

#### `AgentType`
Types of investigation agents.
- `codeAnalysis`: Analyzes source code for fixes.
- `prCorrelation`: Finds related pull requests.
- `duplicate`: Detects duplicate issues.
- `sentiment`: Analyzes issue discussion sentiment.
- `changelog`: Checks for release and changelog mentions.

#### `RiskLevel`
Confidence-based risk assessment.
- `low`: Low confidence, needs human review.
- `medium`: Medium confidence, suggest closure.
- `high`: High confidence, auto-close.

#### `ActionType`
Actions that can be taken on an issue.
- `label`: Apply labels.
- `comment`: Post a comment.
- `close`: Close the issue.
- `linkPr`: Link a related PR.
- `linkIssue`: Link a related issue.
- `none`: No action.

### Message Types (Data Classes)

#### `TriageTask`
A single investigation or action task within the game plan.
```dart
// Construct using cascade notation for mutable fields
final task = TriageTask(
  id: 'issue-123-code',
  agent: AgentType.codeAnalysis,
  status: TaskStatus.pending,
)
  ..error = null
  ..result = null;
```

#### `IssuePlan`
The triage plan for a single GitHub issue.
```dart
final issuePlan = IssuePlan(
  number: 123,
  title: 'Bug in authentication',
  author: 'johndoe',
  existingLabels: ['bug'],
  tasks: [
    TriageTask(id: 'issue-123-code', agent: AgentType.codeAnalysis),
  ],
)..decision = null;
```

#### `LinkSpec`
A link to create between two entities.
```dart
final linkSpec = LinkSpec(
  sourceType: 'issue',
  sourceId: '123',
  targetType: 'pr',
  targetId: '456',
  description: 'Related PR',
)..applied = false;
```

#### `GamePlan`
The top-level game plan orchestrating the triage pipeline.
```dart
final plan = GamePlan(
  planId: 'triage-2023-10-25',
  createdAt: DateTime.now(),
  issues: [issuePlan],
  linksToCreate: [linkSpec],
);
```

#### `RelatedEntity`
A reference to a related entity (PR, issue, commit, file).
```dart
final relatedEntity = RelatedEntity(
  type: 'pr',
  id: '456',
  description: 'Fixes authentication bug',
  relevance: 0.9,
);
```

#### `InvestigationResult`
Results from an investigation agent.
```dart
final result = InvestigationResult(
  agentId: 'code_analysis',
  issueNumber: 123,
  confidence: 0.95,
  summary: 'Fix is clearly merged and tests pass',
  evidence: ['Found commit xyz123 fixing the bug'],
  recommendedLabels: ['bug', 'triaged'],
  suggestedComment: 'This has been fixed.',
  suggestClose: true,
  closeReason: 'completed',
  relatedEntities: [relatedEntity],
  turnsUsed: 2,
  toolCallsMade: 3,
  durationMs: 4500,
);
```

#### `TriageAction`
A concrete action to take on a GitHub issue.
```dart
final action = TriageAction(
  type: ActionType.label,
  description: 'Apply triaged label',
  parameters: {'labels': ['triaged']},
)
  ..executed = false
  ..verified = false
  ..error = null;
```

#### `TriageDecision`
The aggregated triage decision for a single issue.
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

#### `VerificationCheck`
A single check verifying an action.
```dart
final check = VerificationCheck(
  name: 'state_closed',
  passed: true,
  message: 'Issue correctly closed',
);
```

#### `IssueVerification`
Verification results for all actions on a single issue.
```dart
final issueVerification = IssueVerification(
  issueNumber: 123,
  passed: true,
  checks: [check],
);
```

#### `VerificationReport`
The overall report containing all issue verifications.
```dart
final report = VerificationReport(
  verifications: [issueVerification],
  timestamp: DateTime.now(),
);
```

#### `CrossRepoEntry`
Configuration for cross-repository linkage.
```dart
final entry = CrossRepoEntry(
  owner: 'my-org',
  repo: 'dependent-repo',
  relationship: 'dependent',
);
```

## 5. Pipeline Operations (RPC Equivalents)

### Triaging a Single Issue
Execute the complete pipeline on a specific issue:

```dart
// Phase 1: Create a GamePlan for the issue
final GamePlan gamePlan = await plan_phase.planSingleIssue(
  123, 
  repoRoot, 
  runDir: runDir,
);

// Phase 2: Run all configured Gemini investigation agents in parallel
final Map<int, List<InvestigationResult>> results = await investigate_phase.investigate(
  gamePlan, 
  repoRoot, 
  runDir: runDir,
);

// Phase 3: Act (apply labels, post comments, close issues based on confidence)
final List<TriageDecision> decisions = await act_phase.act(
  gamePlan, 
  results, 
  repoRoot, 
  runDir: runDir,
);

// Phase 4: Verify that actions were successfully applied
final verify_phase.VerificationReport report = await verify_phase.verify(
  gamePlan, 
  decisions, 
  repoRoot, 
  runDir: runDir,
);

// Phase 5: Cross-link related issues and PRs
await link_phase.link(gamePlan, decisions, repoRoot, runDir: runDir);

// Phase 5b: Cross-link issues in configured dependent repositories
if (config.crossRepoEnabled) {
  await cross_repo_phase.crossRepoLink(gamePlan, decisions, repoRoot, runDir: runDir);
}
```

### Auto-Triage All Open Issues
Instead of targeting a single issue, discover and triage all open, untriaged issues:

```dart
// Discover open issues not yet marked with the `triaged` label
final GamePlan autoPlan = await plan_phase.planAutoTriage(repoRoot, runDir: runDir);

if (autoPlan.issues.isNotEmpty) {
  final autoResults = await investigate_phase.investigate(autoPlan, repoRoot, runDir: runDir);
  await act_phase.act(autoPlan, autoResults, repoRoot, runDir: runDir);
}
```

### Load Existing Plan
Load an existing game plan from a run directory:

```dart
final GamePlan? existingPlan = plan_phase.loadPlan(runDir: runDir);
```

### Pre-Release Triage
Scan for issues and Sentry errors addressed by the upcoming release, saving findings to an `issue_manifest.json`:

```dart
final String manifestPath = await pre_release_phase.preReleaseTriage(
  prevTag: 'v1.0.0',
  newVersion: '1.1.0',
  repoRoot: repoRoot,
  runDir: runDir,
  verbose: true,
);
```

### Post-Release Triage
Close the loop after publishing the release by notifying cross-repo issues, closing resolved ones, and linking Sentry errors:

```dart
await post_release_phase.postReleaseTriage(
  newVersion: '1.1.0',
  releaseTag: 'v1.1.0',
  releaseUrl: 'https://github.com/owner/repo/releases/tag/v1.1.0',
  manifestPath: '/path/to/issue_manifest.json',
  repoRoot: repoRoot,
  runDir: runDir,
);
```

## 6. Configuration
The Triage Engine relies on a `.runtime_ci/config.json` file in the root of your repository, loaded through the singleton `TriageConfig` (accessed via `config`). 

**Key Configuration Fields:**
- `repository.name` and `repository.owner`: Required details of your GitHub repo.
- `thresholds.auto_close`, `thresholds.suggest_close`, `thresholds.comment`: Confidence limits for `TriageDecision` actions.
- `agents.enabled`: Specifies which agents run (e.g., `code_analysis`, `duplicate`, `sentiment`).
- `cross_repo.repos`: List of `CrossRepoEntry` objects identifying related repositories to scan.

**Environment Variables:**
- `GEMINI_API_KEY`: Required for Gemini model access.
- `GH_TOKEN`, `GITHUB_TOKEN`, or `GITHUB_PAT`: Required for GitHub operations and the GitHub MCP server.

## 7. Related Modules
- **Gemini Runner** (`utils/gemini_runner.dart`): Executes tasks via `GeminiTask` and returns structured `GeminiResult` objects while managing retry logic, backoff, and concurrency.
- **MCP Config** (`utils/mcp_config.dart`): Configures and validates Model Context Protocol servers for tools.
- **Run Context** (`utils/run_context.dart`): Sets up sandboxed execution directories (`.runtime_ci/runs/`) and archives output artifacts using `RunContext`.
