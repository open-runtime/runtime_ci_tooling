# Issue Triage Engine Quickstart

## 1. Overview
The **Issue Triage Engine** is an autonomous, AI-powered pipeline that discovers, investigates, and acts upon GitHub issues. Using multiple Gemini-based specialized agents (`code_analysis`, `pr_correlation`, `duplicate`, `sentiment`, and `changelog`), it investigates issues against the repository's codebase and artifacts. It determines confidence scores and risk levels, then automatically applies labels, posts informative comments, cross-links artifacts, and closes issues that are confidently resolved. 

It provides robust CLI workflows (`plan`, `investigate`, `act`, `verify`, `link`, `pre_release`, and `post_release`) alongside comprehensive data models (`GamePlan`, `TriageDecision`, `InvestigationResult`) for integrating AI-driven triage into your CI/CD pipelines.

## 2. Import

To use the Triage Engine programmatically, import the required phases, models, and utilities based on the library structure:

```dart
// Models and Core Logic
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
import 'package:runtime_ci_tooling/src/triage/phases/pre_release.dart' as pre_release_phase;
import 'package:runtime_ci_tooling/src/triage/phases/post_release.dart' as post_release_phase;

// Configuration and Context Utilities
import 'package:runtime_ci_tooling/src/triage/utils/config.dart';
import 'package:runtime_ci_tooling/src/triage/utils/mcp_config.dart' as mcp;
import 'package:runtime_ci_tooling/src/triage/utils/gemini_runner.dart';
import 'package:runtime_ci_tooling/src/triage/utils/run_context.dart';
```

## 3. Setup

The engine relies on centralized configuration from `.runtime_ci/config.json` and uses MCP configuration in `.gemini/settings.json`.

```dart
void setupTriage(String repoRoot) {
  // Load configuration (auto-discovered from .runtime_ci/config.json)
  reloadConfig();
  print('Configured for repo: ${config.repoOwner}/${config.repoName}');

  // Ensure MCP servers (GitHub, Sentry) are configured for the Gemini Runner
  mcp.ensureMcpConfigured(repoRoot);

  // Validate the GEMINI_API_KEY is present
  final apiKey = config.resolveGeminiApiKey();
  if (apiKey == null || apiKey.isEmpty) {
    throw StateError('Set the ${config.geminiApiKeyEnv} environment variable.');
  }
}
```

## 4. Common Operations

### 4.1. Planning the Triage (Phase 1)
You can target a single issue or auto-discover all open, untriaged issues.

```dart
final String runDir = '.cicd_runs/my_triage_run';

// Plan for a single issue:
GamePlan singlePlan = await plan_phase.planSingleIssue(
  42, 
  repoRoot, 
  runDir: runDir,
);

// OR Auto-discover untriaged issues:
GamePlan autoPlan = await plan_phase.planAutoTriage(
  repoRoot, 
  runDir: runDir,
);
```

### 4.2. Investigating Issues (Phase 2)
The engine executes tasks in parallel using `GeminiRunner`.

```dart
Map<int, List<InvestigationResult>> results = await investigate_phase.investigate(
  singlePlan, 
  repoRoot, 
  runDir: runDir, 
  verbose: true,
);
```

### 4.3. Acting and Verifying (Phases 3 & 4)
Using the investigation results, the engine makes `TriageDecision`s to add labels, comments, or close the issue.

```dart
// Act on the decisions (comments, closing issues)
List<TriageDecision> decisions = await act_phase.act(
  singlePlan, 
  results, 
  repoRoot, 
  runDir: runDir,
);

// Verify the actions were successfully applied to GitHub
verify_phase.VerificationReport report = await verify_phase.verify(
  singlePlan, 
  decisions, 
  repoRoot, 
  runDir: runDir,
);
```

### 4.4. Pre-Release Manifest Generation
Before publishing a new release, scan GitHub and Sentry for resolved issues to include in the changelog.

```dart
String manifestPath = await pre_release_phase.preReleaseTriage(
  prevTag: 'v1.0.0',
  newVersion: '1.1.0',
  repoRoot: repoRoot,
  runDir: runDir,
  verbose: false,
);
print('Manifest saved to: $manifestPath');
```

## 5. Model Construction Examples

Here is how you might construct the data models manually (e.g., for testing or custom workflows), using the cascade operator (`..`) for mutable properties. Note that field names in Dart strictly use `camelCase` (e.g., `issueNumber`, `agentId`).

```dart
// Constructing a TriageTask using cascade for mutable fields
final task = TriageTask(
  id: 'issue-42-code',
  agent: AgentType.codeAnalysis,
)
  ..status = TaskStatus.running
  ..error = null;

// Constructing an InvestigationResult
final result = InvestigationResult(
  agentId: 'code_analysis',
  issueNumber: 42,
  confidence: 0.95,
  summary: 'Fix is clearly merged, tests pass.',
  evidence: ['Commit sha123 addresses the issue'],
  recommendedLabels: ['bug', 'resolved'],
  suggestedComment: 'This was fixed in sha123.',
  suggestClose: true,
  closeReason: 'completed',
  relatedEntities: [
    RelatedEntity(
      type: 'commit',
      id: 'sha123',
      description: 'Relevant commit',
      relevance: 0.9,
    ),
  ],
  turnsUsed: 2,
  toolCallsMade: 3,
  durationMs: 4500,
);

// Constructing an IssuePlan with cascade for its mutable decision map
final issuePlan = IssuePlan(
  number: 42,
  title: 'Fix null pointer exception',
  author: 'dev123',
  existingLabels: ['bug'],
  tasks: [task],
)..decision = {
  'issue_number': 42,
  'aggregate_confidence': 0.95,
  'risk_level': 'high',
};

// Constructing a TriageAction with cascade
final action = TriageAction(
  type: ActionType.close,
  description: 'Auto-close with high confidence',
  parameters: {'state': 'closed', 'state_reason': 'completed'},
)
  ..executed = true
  ..verified = false;

// Constructing a LinkSpec
final link = LinkSpec(
  sourceType: 'issue',
  sourceId: '42',
  targetType: 'pr',
  targetId: '43',
  description: 'Related PR: fixes #42',
)..applied = true;
```

## 6. Configuration

The module relies heavily on settings defined in your `.runtime_ci/config.json` (or legacy `runtime.ci.config.json`). 

### Key Environment Variables
- `GEMINI_API_KEY` (Can be overridden via `secrets.gemini_api_key_env` in config).
- `GH_TOKEN` / `GITHUB_TOKEN` / `GITHUB_PAT` (Required for GitHub CLI and MCP operations).

### Essential Config.json Properties
```json
{
  "repository": {
    "name": "my_project",
    "owner": "my_org",
    "triaged_label": "triaged",
    "changelog_path": "CHANGELOG.md"
  },
  "thresholds": {
    "auto_close": 0.9,
    "suggest_close": 0.7,
    "comment": 0.5
  },
  "agents": {
    "enabled": ["code_analysis", "pr_correlation", "duplicate", "sentiment", "changelog"]
  },
  "release": {
    "pre_release_scan_github": true,
    "pre_release_scan_sentry": true
  }
}
```

## 7. Data Models Reference

To correctly interact with the pipeline, you must be familiar with its comprehensive suite of Dart models.

### Enums
- `TaskStatus`: Defines the state of an investigation (`pending`, `running`, `completed`, `failed`, `skipped`).
- `AgentType`: The type of investigator (`codeAnalysis`, `prCorrelation`, `duplicate`, `sentiment`, `changelog`).
- `RiskLevel`: The computed risk of acting on an issue (`low`, `medium`, `high`).
- `ActionType`: Defines the GitHub operations (`label`, `comment`, `close`, `linkPr`, `linkIssue`, `none`).

### Core Models

#### `TriageDecision`
Aggregates the final verdict for an issue.
- `issueNumber` (int)
- `aggregateConfidence` (double)
- `riskLevel` (RiskLevel)
- `rationale` (String)
- `actions` (List<TriageAction>)
- `investigationResults` (List<InvestigationResult>)

#### `GamePlan`
Tracks the global state of a triage run.
- `planId` (String)
- `createdAt` (DateTime)
- `issues` (List<IssuePlan>)
- `linksToCreate` (List<LinkSpec>)

#### `IssuePlan`
Represents an individual issue within the `GamePlan`.
- `number` (int)
- `title` (String)
- `author` (String)
- `existingLabels` (List<String>)
- `tasks` (List<TriageTask>)
- `decision` (Map<String, dynamic>?)
- `investigationComplete` (bool) [Getter]

#### `TriageTask`
A single task delegated to an agent.
- `id` (String)
- `agent` (AgentType)
- `status` (TaskStatus)
- `error` (String?)
- `result` (Map<String, dynamic>?)

#### `InvestigationResult`
The specific findings returned by a Gemini agent.
- `agentId` (String)
- `issueNumber` (int)
- `confidence` (double)
- `summary` (String)
- `evidence` (List<String>)
- `recommendedLabels` (List<String>)
- `suggestedComment` (String?)
- `suggestClose` (bool)
- `closeReason` (String?)
- `relatedEntities` (List<RelatedEntity>)
- `turnsUsed` (int)
- `toolCallsMade` (int)
- `durationMs` (int)

#### `RelatedEntity`
Connects an issue to related pull requests, commits, or files.
- `type` (String) - e.g., 'pr', 'issue', 'commit', 'file'
- `id` (String)
- `description` (String)
- `relevance` (double)

#### `TriageAction`
A concrete step to be taken during the ACT phase.
- `type` (ActionType)
- `description` (String)
- `parameters` (Map<String, dynamic>)
- `executed` (bool)
- `verified` (bool)
- `error` (String?)

#### `LinkSpec`
Instructs the LINK phase to connect two distinct repository artifacts.
- `sourceType` (String)
- `sourceId` (String)
- `targetType` (String)
- `targetId` (String)
- `description` (String)
- `applied` (bool)

#### `VerificationReport`
Captures the verification status of all applied triage decisions.
- `verifications` (List<IssueVerification>)
- `timestamp` (DateTime)
- `allPassed` (bool) [Getter]

#### `IssueVerification`
Verification results for a specific issue.
- `issueNumber` (int)
- `passed` (bool)
- `checks` (List<VerificationCheck>)

#### `VerificationCheck`
A single validation check performed on an issue's state (e.g., was a label added).
- `name` (String)
- `passed` (bool)
- `message` (String)

#### `GeminiRunner` & `GeminiTask` & `GeminiResult`
Controls the concurrent execution of large language models for triage tasks.
- **`GeminiRunner`**: Manages execution batching, rate-limiting, and backoffs (`maxConcurrent`, `maxRetries`).
- **`GeminiTask`**: Configures a specific invocation (`id`, `prompt`, `model`, `maxTurns`, `allowedTools`, `fileIncludes`).
- **`GeminiResult`**: Contains the results of a runner task (`taskId`, `response`, `stats`, `error`, `success`, `attempts`).

#### `ValidationResult`
Captures the output of JSON schema validations.
- `valid` (bool)
- `path` (String)
- `errors` (List<String>)

#### `RunContext`
Manages a run-scoped audit trail directory.
- `repoRoot` (String)
- `runDir` (String)
- `command` (String)
- `startedAt` (DateTime)
- `args` (List<String>)

## 8. Related Modules
- **`triage_cli.dart`**: The executable command line tool that orchestrates these phases.
- **`mcp_config.dart`**: Ensures integration with the Sentry and GitHub Model Context Protocol servers.
- **`json_schemas.dart`**: Used extensively to validate all artifact input/output passing through the pipeline.
- **`config.dart`**: The core `TriageConfig` singleton.
