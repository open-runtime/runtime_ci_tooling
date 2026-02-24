# Issue Triage Engine: Quickstart

## 1. Overview
The **Issue Triage Engine** is an AI-powered pipeline that autonomously analyzes GitHub issues, detects duplicates, assesses community sentiment, and correlates issues with code changes, pull requests, and Sentry errors. It provides a robust 6-phase triage pipeline (Plan, Investigate, Act, Verify, Link, Cross-Repo) and dedicated workflows for Release Triage (Pre-Release and Post-Release).

It is designed to significantly reduce manual issue triage time by autonomously applying labels, linking related artifacts, suggesting closures, or automatically closing high-confidence issues based on configured thresholds.

## 2. Import

To use the Triage Engine modules programmatically, use the following imports based on the internal structure:

```dart
// Core models
import 'package:runtime_ci_tooling/src/triage/models/game_plan.dart';
import 'package:runtime_ci_tooling/src/triage/models/triage_decision.dart';
import 'package:runtime_ci_tooling/src/triage/models/investigation_result.dart';

// Pipeline phases
import 'package:runtime_ci_tooling/src/triage/phases/plan.dart' as plan_phase;
import 'package:runtime_ci_tooling/src/triage/phases/investigate.dart' as investigate_phase;
import 'package:runtime_ci_tooling/src/triage/phases/act.dart' as act_phase;
import 'package:runtime_ci_tooling/src/triage/phases/verify.dart' as verify_phase;
import 'package:runtime_ci_tooling/src/triage/phases/link.dart' as link_phase;
import 'package:runtime_ci_tooling/src/triage/phases/cross_repo_link.dart' as cross_repo_phase;

// Release modes
import 'package:runtime_ci_tooling/src/triage/phases/pre_release.dart' as pre_release_phase;
import 'package:runtime_ci_tooling/src/triage/phases/post_release.dart' as post_release_phase;

// Utilities
import 'package:runtime_ci_tooling/src/triage/utils/config.dart';
import 'package:runtime_ci_tooling/src/triage/utils/run_context.dart';
import 'package:runtime_ci_tooling/src/triage/utils/gemini_runner.dart';
import 'package:runtime_ci_tooling/src/triage/utils/json_schemas.dart';
import 'package:runtime_ci_tooling/src/triage/utils/mcp_config.dart' as mcp;
```

## 3. Setup

The triage engine is strictly configured via a repository's `.runtime_ci/config.json` file. The `config` singleton lazily loads configuration by searching upward from the current working directory. You also need to configure a local run directory to store the audit trail and JSON artifacts.

```dart
import 'dart:io';
import 'package:runtime_ci_tooling/src/triage/utils/config.dart';

void main() {
  // 1. Force reload configuration from .runtime_ci/config.json
  reloadConfig();
  
  if (!config.isConfigured) {
    print('Please create .runtime_ci/config.json with repository.name and repository.owner');
    exit(1);
  }

  // 2. Set up a run directory for the audit trail
  final repoRoot = Directory.current.path;
  final runDir = '$repoRoot/.runtime_ci/runs/triage_quickstart_${DateTime.now().millisecondsSinceEpoch}';
  Directory(runDir).createSync(recursive: true);
  
  print('Running triage for: ${config.repoOwner}/${config.repoName}');
}
```

*Note: You must ensure that both `GEMINI_API_KEY` and `GH_TOKEN` (or `GITHUB_TOKEN`) are set in your environment.*

## 4. Models and Enums

The data structures orchestrating the engine reflect a structured approach to problem resolution. They use `camelCase` naming conventions for field access in Dart. 

### Core Enums
*   `TaskStatus`: The lifecycle of a task (`pending`, `running`, `completed`, `failed`, `skipped`).
*   `AgentType`: The type of AI agent (`codeAnalysis`, `prCorrelation`, `duplicate`, `sentiment`, `changelog`).
*   `RiskLevel`: Assigned to an issue post-investigation (`low`, `medium`, `high`).
*   `ActionType`: The GitHub action to execute (`label`, `comment`, `close`, `linkPr`, `linkIssue`, `none`).

### GamePlan
The overarching blueprint created during the `plan` phase.
*   `planId` (String): Unique identifier.
*   `createdAt` (DateTime): Plan creation time.
*   `issues` (List<IssuePlan>): The list of issues to process.
*   `linksToCreate` (List<LinkSpec>): Bidirectional links queued for creation.

### IssuePlan
A single issue's blueprint.
*   `number` (int): The GitHub issue number.
*   `title` (String): Issue title.
*   `author` (String): Author's username.
*   `existingLabels` (List<String>): Labels already applied.
*   `tasks` (List<TriageTask>): The AI tasks (one for each enabled agent) designated for this issue.
*   `decision` (Map<String, dynamic>?): Populated post-act.

### TriageTask
*   `id` (String): Unique ID (e.g., `issue-42-code`).
*   `agent` (AgentType): The agent to run.
*   `status` (TaskStatus): Execution status.
*   `error` (String?): Present if the task failed.
*   `result` (Map<String, dynamic>?): The raw output from the agent.

### InvestigationResult
The structured findings from an individual agent.
*   `agentId` (String): ID of the executing agent.
*   `issueNumber` (int): Associated issue number.
*   `confidence` (double): 0.0-1.0 confidence score of the finding.
*   `summary` (String): Concise summary of findings.
*   `evidence` (List<String>): Key evidence lines.
*   `recommendedLabels` (List<String>): Labels the agent suggests adding.
*   `suggestedComment` (String?): Proposed comment body.
*   `suggestClose` (bool): Whether the agent recommends closing the issue.
*   `closeReason` (String?): Reason for closure (`completed` or `not_planned`).
*   `relatedEntities` (List<RelatedEntity>): Links to PRs, issues, or commits.
*   `turnsUsed` (int), `toolCallsMade` (int), `durationMs` (int): Metrics.

### RelatedEntity
A reference to a related object discovered by an agent.
*   `type` (String): E.g., `'pr'`, `'issue'`, `'commit'`, `'file'`.
*   `id` (String): The ID (PR number, commit SHA, etc.).
*   `description` (String): Brief explanation.
*   `relevance` (double): Confidence score for the relationship.

### TriageDecision
The aggregated outcome after all agents conclude.
*   `issueNumber` (int)
*   `aggregateConfidence` (double): Weighted and agreement-boosted score across all agents.
*   `riskLevel` (RiskLevel): The calculated risk of the decision.
*   `rationale` (String): A generated explanation of the aggregate confidence.
*   `actions` (List<TriageAction>): The specific actions queued.
*   `investigationResults` (List<InvestigationResult>): The raw results feeding this decision.

### TriageAction
A concrete action to take on the repository.
*   `type` (ActionType): The action type.
*   `description` (String): Human-readable intent.
*   `parameters` (Map<String, dynamic>): Data required for the action (e.g., `labels`, `body`, `state`).
*   `executed` (bool): True if successfully applied.
*   `verified` (bool): True if verified in the Verification phase.
*   `error` (String?): Populate if action execution failed.

### LinkSpec
A definition of a bidirectional relationship.
*   `sourceType` (String), `sourceId` (String): The origin.
*   `targetType` (String), `targetId` (String): The destination.
*   `description` (String): Explanatory text.
*   `applied` (bool): True if cross-linking succeeded.

**Builder Example:**
```dart
final issuePlan = IssuePlan(
  number: 101,
  title: 'Bug with builder',
  author: 'developer123',
  tasks: [
    TriageTask(
      id: 'issue-101-sentiment',
      agent: AgentType.sentiment,
      status: TaskStatus.pending,
    ),
  ],
);

final result = InvestigationResult(
  agentId: 'sentiment',
  issueNumber: 101,
  confidence: 0.85,
  summary: 'User confirmed the issue is fixed',
  suggestClose: true,
  closeReason: 'completed',
  relatedEntities: [
    RelatedEntity(
      type: 'issue',
      id: '42',
      description: 'Duplicate root cause',
      relevance: 0.95,
    )
  ],
);
```

## 5. Common Operations

### Example 1: Standard Triage Pipeline (Single Issue)

This runs the core pipeline: building a game plan, investigating with concurrent AI agents, applying the decision to GitHub, and verifying it.

```dart
final issueNumber = 42;

// Phase 1: Plan
GamePlan plan = await plan_phase.planSingleIssue(issueNumber, repoRoot, runDir: runDir);

// Phase 2: Investigate (Executes codeAnalysis, duplicate, prCorrelation, etc.)
Map<int, List<InvestigationResult>> results = await investigate_phase.investigate(
  plan,
  repoRoot,
  runDir: runDir,
  verbose: true,
);

// Phase 3: Act (Applies labels, comments, or closes issues based on confidence)
List<TriageDecision> decisions = await act_phase.act(
  plan, 
  results, 
  repoRoot, 
  runDir: runDir,
);

// Phase 4: Verify (Checks that GH actions successfully applied)
await verify_phase.verify(plan, decisions, repoRoot, runDir: runDir);

// Phase 5: Link (Creates bidirectional links across issues/PRs/changelogs)
await link_phase.link(plan, decisions, repoRoot, runDir: runDir);

// Phase 5b: Cross-Repo (Creates links across related repos)
if (config.crossRepoEnabled) {
  await cross_repo_phase.crossRepoLink(plan, decisions, repoRoot, runDir: runDir);
}
```

### Example 2: Auto-Triage All Open Issues

You can auto-discover all open issues that do not yet have the triaged label (defaults to `triaged`).

```dart
// Discover all untriaged issues
GamePlan autoPlan = await plan_phase.planAutoTriage(repoRoot, runDir: runDir);

if (autoPlan.issues.isNotEmpty) {
  // Investigate all discovered issues in parallel
  final results = await investigate_phase.investigate(
    autoPlan, 
    repoRoot, 
    runDir: runDir,
  );
  
  // Act on all investigated issues
  final decisions = await act_phase.act(autoPlan, results, repoRoot, runDir: runDir);
} else {
  print('No untriaged issues found.');
}
```

### Example 3: Pre-Release Correlation

Before generating a release, correlate Sentry errors and GitHub issues with the `git diff` to determine exactly what the upcoming release fixes.

```dart
String manifestPath = await pre_release_phase.preReleaseTriage(
  prevTag: 'v1.0.0',
  newVersion: '1.0.1',
  repoRoot: repoRoot,
  runDir: runDir,
  verbose: false,
);
print('Manifest generated at: $manifestPath');
```

## 6. Configuration

All triage logic is governed by `.runtime_ci/config.json`. The `TriageConfig` class handles parsing.

**Key Configuration Blocks:**

*   **Repository (`repository`):** `name` and `owner` are absolutely required.
*   **Thresholds (`thresholds`):**
    *   `auto_close` (default: 0.9) - Closes the issue automatically.
    *   `suggest_close` (default: 0.7) - Comments suggesting a human maintainer close it.
    *   `comment` (default: 0.5) - Posts an informational update.
*   **Agents (`agents.enabled`):** By default, runs `code_analysis`, `pr_correlation`, `duplicate`, `sentiment`, and `changelog`.
*   **Cross-Repo (`cross_repo`):** Allows searching and linking issues in dependent repositories explicitly listed by `owner` and `repo`.

## 7. Related Modules

*   **`GeminiRunner` (`utils/gemini_runner.dart`)**: The underlying concurrent executor for Gemini CLI. Manages exponential backoff, retry logic, tool calling formatting, and prompt tracking via `GeminiTask` and `GeminiResult`.
*   **`RunContext` (`utils/run_context.dart`)**: Handles creating timestamped run directories (`.runtime_ci/runs/run_ID`) for safe execution, robust audit trails, and checkpointing for resumability.
*   **MCP Integration (`utils/mcp_config.dart`)**: Bootstraps the Model Context Protocol (MCP) by configuring the GitHub Docker MCP server and Sentry Remote MCP server in `.gemini/settings.json`.
*   **JSON Schemas (`utils/json_schemas.dart`)**: Exposes `ValidationResult` and helper methods to ensure that structured artifacts like `game_plan.json` match expected formats.
