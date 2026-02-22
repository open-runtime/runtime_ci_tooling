# Quickstart: Issue Triage Engine

## 1. Overview
The Issue Triage Engine is an AI-powered pipeline that automatically investigates, categorizes, and links GitHub issues. It utilizes multiple parallel Gemini agents (`code_analysis`, `pr_correlation`, `duplicate`, `sentiment`, `changelog`) to evaluate confidence scores and safely execute actions such as applying labels, posting summaries, closing issues, and generating cross-repository links.

## 2. Import
When using the Triage module programmatically, import the required phases and models from the `src/triage/` directory:

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
```

## 3. Setup
Before executing the pipeline, ensure the GitHub CLI (`gh`) is authenticated, environment variables are set, and your repository contains a `.runtime_ci/config.json` configuration file.

```dart
import 'package:runtime_ci_tooling/src/triage/utils/config.dart';
import 'package:runtime_ci_tooling/src/triage/utils/mcp_config.dart' as mcp;

void setupTriage(String repoRoot) {
  // 1. Reload configuration from .runtime_ci/config.json
  reloadConfig();
  
  // 2. Ensure Model Context Protocol (MCP) servers (GitHub, Sentry) are configured in .gemini/settings.json
  mcp.ensureMcpConfigured(repoRoot);
  
  // 3. Verify secrets are accessible
  final geminiKey = config.resolveGeminiApiKey();
  if (geminiKey == null) throw StateError('GEMINI_API_KEY is not set.');
}
```

## 4. Core Models and Enums

The Triage Engine relies on robust data models to represent the investigation pipeline. (Note: These are standard Dart classes, not Protobuf messages, but they support cascading for mutable state.)

### Enums
- **TaskStatus**: `pending`, `running`, `completed`, `failed`, `skipped`
- **AgentType**: `codeAnalysis`, `prCorrelation`, `duplicate`, `sentiment`, `changelog`
- **RiskLevel**: `low`, `medium`, `high`
- **ActionType**: `label`, `comment`, `close`, `linkPr`, `linkIssue`, `none`

### GamePlan & IssuePlan
The top-level `GamePlan` orchestrates the entire triage pipeline. It contains multiple `IssuePlan` objects.
- `String planId`
- `DateTime createdAt`
- `List<IssuePlan> issues`
- `List<LinkSpec> linksToCreate`

```dart
final plan = GamePlan(
  planId: 'triage-run-123',
  createdAt: DateTime.now(),
  issues: [
    IssuePlan(
      number: 42,
      title: 'Fix null pointer',
      author: 'johndoe',
      tasks: [
        TriageTask(
          id: 'task-1', 
          agent: AgentType.codeAnalysis
        )..status = TaskStatus.pending,
      ],
    )
  ],
);
```

### TriageTask
A single investigation or action task within the game plan.
- `String id`
- `AgentType agent`
- `TaskStatus status` (mutable)
- `String? error` (mutable)
- `Map<String, dynamic>? result` (mutable)

### InvestigationResult
Data class for investigation agent results. 
- `String agentId`
- `int issueNumber`
- `double confidence`
- `String summary`
- `List<String> evidence`
- `List<String> recommendedLabels`
- `String? suggestedComment`
- `bool suggestClose`
- `String? closeReason`
- `List<RelatedEntity> relatedEntities`
- `int turnsUsed`
- `int toolCallsMade`
- `int durationMs`

```dart
final result = InvestigationResult(
  agentId: 'code_analysis',
  issueNumber: 42,
  confidence: 0.95,
  summary: 'PR merged fixing the issue.',
  evidence: ['Found commit 12345'],
  recommendedLabels: ['bug'],
  suggestClose: true,
  closeReason: 'completed',
  relatedEntities: [
    RelatedEntity(
      type: 'pr',
      id: '100',
      description: 'Fix null pointer exception',
      relevance: 1.0,
    )
  ],
);
```

### TriageDecision & TriageAction
The aggregated triage decision for a single issue. Contains multiple `TriageAction`s.
- `int issueNumber`
- `double aggregateConfidence`
- `RiskLevel riskLevel`
- `String rationale`
- `List<TriageAction> actions`
- `List<InvestigationResult> investigationResults`

```dart
final decision = TriageDecision(
  issueNumber: 42,
  aggregateConfidence: 0.85,
  riskLevel: RiskLevel.medium,
  rationale: 'High confidence from code_analysis agent.',
  actions: [
    TriageAction(
      type: ActionType.comment,
      description: 'Post findings comment',
      parameters: {'body': 'The issue seems to be resolved.'},
    )
      ..executed = false
      ..verified = false
  ],
);
```

### LinkSpec
A link to create between two entities (issue, PR, changelog, release notes).
- `String sourceType`
- `String sourceId`
- `String targetType`
- `String targetId`
- `String description`
- `bool applied` (mutable)

## 5. Common Operations

### Executing the Standard Triage Pipeline
The standard triage pipeline runs in 5 distinct phases: Plan, Investigate, Act, Verify, and Link.

```dart
Future<void> runFullTriage(int issueNumber, String repoRoot, String runDir) async {
  // Phase 1: PLAN - Discover the issue and build a GamePlan
  GamePlan gamePlan = await plan_phase.planSingleIssue(
    issueNumber, 
    repoRoot, 
    runDir: runDir
  );

  // Phase 2: INVESTIGATE - Execute parallel Gemini agents
  Map<int, List<InvestigationResult>> results = await investigate_phase.investigate(
    gamePlan, 
    repoRoot, 
    runDir: runDir, 
    verbose: true
  );

  // Phase 3: ACT - Apply triage decisions (labels, comments, close)
  List<TriageDecision> decisions = await act_phase.act(
    gamePlan, 
    results, 
    repoRoot, 
    runDir: runDir
  );

  // Phase 4: VERIFY - Confirm GitHub state reflects intended actions
  verify_phase.VerificationReport report = await verify_phase.verify(
    gamePlan, 
    decisions, 
    repoRoot, 
    runDir: runDir
  );

  // Phase 5: LINK - Form cross-references and updates
  await link_phase.link(gamePlan, decisions, repoRoot, runDir: runDir);
  
  // Phase 5b: CROSS-REPO - Post updates to dependent repositories
  if (config.crossRepoEnabled) {
    await cross_repo_phase.crossRepoLink(gamePlan, decisions, repoRoot, runDir: runDir);
  }
}
```

### Auto-Triaging Multiple Issues
To auto-discover and triage all open, un-triaged issues in the repository:

```dart
Future<void> autoTriageOpenIssues(String repoRoot, String runDir) async {
  // Discovers open issues missing the configured 'triaged' label
  GamePlan gamePlan = await plan_phase.planAutoTriage(repoRoot, runDir: runDir);
  
  if (gamePlan.issues.isEmpty) return;
  
  Map<int, List<InvestigationResult>> results = await investigate_phase.investigate(
    gamePlan, 
    repoRoot, 
    runDir: runDir
  );
  
  await act_phase.act(gamePlan, results, repoRoot, runDir: runDir);
}
```

### Running Pre-Release Triage
Generates an `issue_manifest.json` mapping commits to GitHub/Sentry issues before generating a changelog.

```dart
Future<void> runPreRelease(String repoRoot, String runDir) async {
  String manifestPath = await pre_release_phase.preReleaseTriage(
    prevTag: 'v1.0.0',
    newVersion: '1.1.0',
    repoRoot: repoRoot,
    runDir: runDir,
  );
  print('Issue manifest saved to: $manifestPath');
}
```

### Running Post-Release Triage
Executes actions *after* a GitHub Release is published, such as closing issues automatically.

```dart
Future<void> runPostRelease(String repoRoot, String runDir, String manifestPath) async {
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

## 6. Configuration
The Triage Engine is highly configurable via the canonical `.runtime_ci/config.json` file. 

**Required Keys**:
- `repository.name`
- `repository.owner`

**Environment Variables**:
- `GEMINI_API_KEY`: API key for Gemini execution. (Configurable via `secrets.gemini_api_key_env`).
- `GH_TOKEN` / `GITHUB_TOKEN` / `GITHUB_PAT`: Personal access token for GitHub operations.

**Confidence Thresholds**:
Configure the thresholds determining automated action risk levels:
- `thresholds.auto_close` (default: 0.9): Automatically close the issue.
- `thresholds.suggest_close` (default: 0.7): Recommend human closure.
- `thresholds.comment` (default: 0.5): Post informational findings.

## 7. Related Modules
- `RunContext` (`utils/run_context.dart`): Used to manage run-scoped audit trail directories for artifacts (`.cicd_runs` / `.cicd_audit`).
- `GeminiRunner` (`utils/gemini_runner.dart`): The parallel execution core responsible for managing the local Gemini CLI agent interactions and rate limiting.
- `McpConfig` (`utils/mcp_config.dart`): The Model Context Protocol integration linking the agents with real-time GitHub/Sentry context safely via `.gemini/settings.json`.
