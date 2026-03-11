# Quickstart: Issue Triage Engine

## 1. Overview
The Issue Triage Engine automates the lifecycle of GitHub issues by using parallel AI agents to analyze code, detect duplicates, correlate pull requests, and determine community sentiment. It provides a modular 6-phase pipeline (Plan, Investigate, Act, Verify, Link, Cross-Repo) capable of single-issue analysis, bulk auto-triage, and managing pre/post-release documentation traceability.

## 2. Import
There is no central barrel file for the triage engine, so you should import the specific phases, models, and utilities you need:

```dart
// Phases
import 'package:runtime_ci_tooling/src/triage/phases/plan.dart';
import 'package:runtime_ci_tooling/src/triage/phases/investigate.dart';
import 'package:runtime_ci_tooling/src/triage/phases/act.dart';
import 'package:runtime_ci_tooling/src/triage/phases/verify.dart';
import 'package:runtime_ci_tooling/src/triage/phases/link.dart';
import 'package:runtime_ci_tooling/src/triage/phases/cross_repo_link.dart';
import 'package:runtime_ci_tooling/src/triage/phases/pre_release.dart';
import 'package:runtime_ci_tooling/src/triage/phases/post_release.dart';

// Models & Utils
import 'package:runtime_ci_tooling/src/triage/models/game_plan.dart';
import 'package:runtime_ci_tooling/src/triage/models/investigation_result.dart';
import 'package:runtime_ci_tooling/src/triage/models/triage_decision.dart';
import 'package:runtime_ci_tooling/src/triage/utils/config.dart';
import 'package:runtime_ci_tooling/src/triage/utils/gemini_runner.dart';
import 'package:runtime_ci_tooling/src/triage/utils/run_context.dart';
import 'package:runtime_ci_tooling/src/triage/utils/mcp_config.dart' as mcp;
```

## 3. Setup
The module relies heavily on `.runtime_ci/config.json` for repository identity and MCP settings in `.gemini/settings.json`. Before running the triage pipeline, ensure configuration and MCP servers are set up:

```dart
void setupTriage(String repoRoot) {
  // Reload the singleton TriageConfig from .runtime_ci/config.json
  reloadConfig();
  
  // Ensure GitHub and Sentry MCP servers are configured in .gemini/settings.json
  mcp.ensureMcpConfigured(repoRoot);
}
```

## 4. Core Models & Enums

The triage pipeline is driven by a series of structured data models.

### GamePlan and IssuePlan
The `GamePlan` orchestrates the pipeline, containing multiple `IssuePlan` objects. Each `IssuePlan` contains a list of `TriageTask` objects to be executed by specific agents.

```dart
void constructGamePlan() {
  // Use the builder pattern (cascade notation) to construct complex objects
  final gamePlan = GamePlan.forIssues([
    {
      'number': 123,
      'title': 'Bug: App crashes on startup',
      'author': 'octocat',
      'labels': ['bug'],
    }
  ])
    ..linksToCreate.add(LinkSpec(
      sourceType: 'issue',
      sourceId: '123',
      targetType: 'pr',
      targetId: '456',
      description: 'Fixes startup crash',
    ));

  final issuePlan = gamePlan.issues.first;
  
  // Enums: TaskStatus.pending, running, completed, failed, skipped
  // Enums: AgentType.codeAnalysis, prCorrelation, duplicate, sentiment, changelog
  for (final task in issuePlan.tasks) {
    print('Task ${task.id} uses agent ${task.agent.name} with status ${task.status.name}');
  }
}
```

### InvestigationResult and TriageDecision
Agents return an `InvestigationResult`. These are aggregated into a `TriageDecision` to determine actions.

```dart
void processResults() {
  final result = InvestigationResult(
    agentId: 'code_analysis',
    issueNumber: 123,
    confidence: 0.85,
    summary: 'Found fix in recent commits',
    evidence: ['Commit abcdef mentions #123'],
    recommendedLabels: ['bug', 'needs-verification'],
    suggestClose: true,
  )
    // Cascade to add related entities
    ..relatedEntities.add(RelatedEntity(
      type: 'commit',
      id: 'abcdef',
      description: 'Fix crash',
      relevance: 0.9,
    ));

  final decision = TriageDecision.fromResults(
    issueNumber: 123,
    results: [result],
  );

  // Enums: RiskLevel.low, medium, high
  print('Risk Level: ${decision.riskLevel.name}'); 
  
  // Enums: ActionType.label, comment, close, linkPr, linkIssue, none
  for (final action in decision.actions) {
    print('Action: ${action.type.name} - ${action.description}');
  }
}
```

## 5. Triage Agents

The engine uses 5 distinct AI agents (defined in `lib/src/triage/agents/`):
- **Code Analysis Agent** (`AgentType.codeAnalysis`): Maps issues to source code and tests.
- **PR Correlation Agent** (`AgentType.prCorrelation`): Finds related Pull Requests.
- **Duplicate Agent** (`AgentType.duplicate`): Finds related or duplicate issues.
- **Sentiment Agent** (`AgentType.sentiment`): Gauges community consensus and blockers.
- **Changelog Agent** (`AgentType.changelog`): Checks if fixes have reached a release.

## 6. Utilities

`GeminiRunner` handles parallel execution of Gemini tasks, while `RunContext` manages the timestamped audit trails.

```dart
Future<void> utilsExample(String repoRoot) async {
  // RunContext manages a timestamped audit trail directory
  final context = RunContext.create(repoRoot, 'triage');
  context.saveArtifact('plan', 'plan.json', '{"plan": "data"}');

  // GeminiRunner executes parallel AI tasks
  final runner = GeminiRunner(
    maxConcurrent: 2,
    maxRetries: 3,
    verbose: true,
  );

  final task = GeminiTask(
    id: 'test-task',
    prompt: 'Summarize this issue...',
    model: 'gemini-3.1-pro-preview',
  );

  final results = await runner.executeBatch([task]);
  if (results.first.success) {
    print('Response: ${results.first.response}');
  }
}
```

## 7. Common Operations

### Auto-Triage All Open Issues
This performs a full sweep of untriaged issues, investigates them in parallel, and applies labels, comments, or closes them based on confidence thresholds.

```dart
Future<void> runAutoTriage(String repoRoot, String runDir) async {
  // Phase 1: Discover all untriaged open issues
  final plan = await planAutoTriage(repoRoot, runDir: runDir);
  
  if (plan.issues.isEmpty) return;

  // Phase 2: Run Gemini AI agents (Code Analysis, PR Correlation, etc.)
  final results = await investigate(plan, repoRoot, runDir: runDir);
  
  // Phase 3: Execute decisions (apply labels, post comments, close issues)
  final decisions = await act(plan, results, repoRoot, runDir: runDir);
}
```

### Complete Single-Issue Pipeline
If you want to run the entire 6-phase pipeline (including verification and linking) on a specific issue:

```dart
Future<void> runSingleIssueTriage(int issueNumber, String repoRoot, String runDir) async {
  final plan = await planSingleIssue(issueNumber, repoRoot, runDir: runDir);
  final results = await investigate(plan, repoRoot, runDir: runDir);
  final decisions = await act(plan, results, repoRoot, runDir: runDir);
  
  // Phase 4: Confirm GitHub state reflects actions taken
  await verify(plan, decisions, repoRoot, runDir: runDir);
  
  // Phase 5 & 5b: Create bidirectional links to artifacts and related cross-repo issues
  await link(plan, decisions, repoRoot, runDir: runDir);
  await crossRepoLink(plan, decisions, repoRoot, runDir: runDir);
}
```

### Pre-Release & Post-Release Triage
Scans recent git diffs and commits, queries GitHub and Sentry, and produces an issue manifest. After release, updates the issues.

```dart
Future<void> generateReleaseManifest(String repoRoot, String runDir) async {
  // Pre-Release
  final manifestPath = await preReleaseTriage(
    prevTag: 'v1.0.0',
    newVersion: '1.1.0',
    repoRoot: repoRoot,
    runDir: runDir,
    verbose: true,
  );
  print('Generated issue_manifest.json at: $manifestPath');
  
  // Post-Release
  await postReleaseTriage(
    newVersion: '1.1.0',
    releaseTag: 'v1.1.0',
    releaseUrl: 'https://github.com/owner/repo/releases/tag/v1.1.0',
    manifestPath: manifestPath,
    repoRoot: repoRoot,
    runDir: runDir,
  );
}
```

## 8. Configuration
The Triage Engine requires the following configurations:
- **`GEMINI_API_KEY` Environment Variable**: Needed by the `GeminiRunner` to authenticate against Gemini models.
- **`GH_TOKEN` / `GITHUB_TOKEN` / `GITHUB_PAT` Environment Variable**: Needed by the GitHub CLI and GitHub MCP server to interact with issues and pull requests.
- **`.runtime_ci/config.json`**: The global configuration file describing `repository.owner`, `repository.name`, `cross_repo`, Sentry organizations, and AI agent thresholds.
- **`.gemini/settings.json`**: Updated automatically by `ensureMcpConfigured` to define MCP server executables and endpoints.
