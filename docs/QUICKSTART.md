# QUICKSTART: Issue Triage Engine

## 1. Overview
The **Issue Triage Engine** is a robust, AI-powered 6-phase pipeline designed to automatically triage, analyze, and resolve GitHub issues. It leverages Gemini to distribute issue investigation across specialized agents (Code Analysis, PR Correlation, Duplicate Detection, Sentiment, and Changelog). The engine provides both a programmatic API organized by lifecycle phases (Plan, Investigate, Act, Verify, Link, Pre/Post Release) and a comprehensive CLI utility for automating repository maintenance.

## 2. Import

```dart
// Data Models
import 'package:runtime_ci_tooling/src/triage/models/game_plan.dart';
import 'package:runtime_ci_tooling/src/triage/models/investigation_result.dart';
import 'package:runtime_ci_tooling/src/triage/models/triage_decision.dart';

// Triage Pipeline Phases
import 'package:runtime_ci_tooling/src/triage/phases/plan.dart' as plan_phase;
import 'package:runtime_ci_tooling/src/triage/phases/investigate.dart' as investigate_phase;
import 'package:runtime_ci_tooling/src/triage/phases/act.dart' as act_phase;
import 'package:runtime_ci_tooling/src/triage/phases/verify.dart' as verify_phase;
import 'package:runtime_ci_tooling/src/triage/phases/link.dart' as link_phase;
import 'package:runtime_ci_tooling/src/triage/phases/cross_repo_link.dart' as cross_repo_phase;
import 'package:runtime_ci_tooling/src/triage/phases/pre_release.dart' as pre_release_phase;
import 'package:runtime_ci_tooling/src/triage/phases/post_release.dart' as post_release_phase;

// Utilities and Configuration
import 'package:runtime_ci_tooling/src/triage/utils/config.dart';
import 'package:runtime_ci_tooling/src/triage/utils/gemini_runner.dart';
import 'package:runtime_ci_tooling/src/triage/utils/run_context.dart';
import 'package:runtime_ci_tooling/src/triage/utils/mcp_config.dart' as mcp;
import 'package:runtime_ci_tooling/src/triage/utils/json_schemas.dart';
```

## 3. Setup and Core Data Models

Before running the triage pipeline, you need to configure the module. The engine relies heavily on `TriageConfig` (loaded automatically from `.runtime_ci/config.json`) and specific data models to govern the workflow.

### TriageConfig
*   `TriageConfig.load()`: Automatically finds the config file by searching upward from the current directory.
*   **Fields**: `loadedFrom`, `isConfigured`, `repoName`, `repoOwner`, `triagedLabel`, `changelogPath`, `releaseNotesPath`, `gcpProject`, `sentryOrganization`, `sentryProjects`, `sentryScanOnPreRelease`, `sentryRecentErrorsHours`, `preReleaseScanSentry`, `preReleaseScanGithub`, `postReleaseCloseOwnRepo`, `postReleaseCloseCrossRepo`, `postReleaseCommentCrossRepo`, `postReleaseLinkSentry`, `crossRepoEnabled`, `crossRepoRepos`, `typeLabels`, `priorityLabels`, `areaLabels`, `autoCloseThreshold`, `suggestCloseThreshold`, `commentThreshold`, `enabledAgents`, `flashModel`, `proModel`, `maxTurns`, `maxConcurrent`, `maxRetries`, `geminiApiKeyEnv`, `githubTokenEnvNames`, `gcpSecretName`.

### Core Enumerations
*   `TaskStatus`: `pending`, `running`, `completed`, `failed`, `skipped`
*   `AgentType`: `codeAnalysis`, `prCorrelation`, `duplicate`, `sentiment`, `changelog`
*   `RiskLevel`: `low`, `medium`, `high`
*   `ActionType`: `label`, `comment`, `close`, `linkPr`, `linkIssue`, `none`

### Core Classes & Fields
*   **`TriageDecision`**: Final decision derived from investigation.
    *   Fields: `issueNumber`, `aggregateConfidence`, `riskLevel`, `rationale`, `actions`, `investigationResults`.
*   **`TriageAction`**: An action pending or executed on an issue.
    *   Fields: `type`, `description`, `parameters`, `executed`, `verified`, `error`.
*   **`GamePlan`**: Top-level orchestration plan containing tasks to execute.
    *   Fields: `planId`, `createdAt`, `issues`, `linksToCreate`.
*   **`IssuePlan`**: The plan isolated for a single issue.
    *   Fields: `number`, `title`, `author`, `existingLabels`, `tasks`, `decision`, `investigationComplete`.
*   **`TriageTask`**: Tracks execution state for a specific agent.
    *   Fields: `id`, `agent`, `status`, `error`, `result`.
*   **`LinkSpec`**: Data for cross-linking issues/PRs.
    *   Fields: `sourceType`, `sourceId`, `targetType`, `targetId`, `description`, `applied`.
*   **`InvestigationResult`**: Outcome of a single agent's execution.
    *   Fields: `agentId`, `issueNumber`, `confidence`, `summary`, `evidence`, `recommendedLabels`, `suggestedComment`, `suggestClose`, `closeReason`, `relatedEntities`, `turnsUsed`, `toolCallsMade`, `durationMs`.
*   **`RelatedEntity`**: Used inside `InvestigationResult`.
    *   Fields: `type`, `id`, `description`, `relevance`.
*   **`RunContext`**: Handles run-scoped audit trails for execution artifacts.
    *   Fields: `repoRoot`, `runDir`, `command`, `startedAt`, `args`.
*   **`GeminiRunner`**: Manages execution and retries for Gemini AI calls.
    *   Fields: `maxConcurrent`, `maxRetries`, `initialBackoff`, `maxBackoff`, `verbose`.
*   **`GeminiTask`**: A task dispatched to the runner.
    *   Fields: `id`, `prompt`, `model`, `maxTurns`, `allowedTools`, `fileIncludes`, `workingDirectory`, `sandbox`, `auditDir`.
*   **`GeminiResult`**: Response from `GeminiRunner`.
    *   Fields: `taskId`, `response`, `stats`, `error`, `attempts`, `durationMs`, `success`, `toolCalls`, `turnsUsed`, `errorMessage`.
*   **`VerificationReport`**: Collection of results from the verification phase.
    *   Fields: `verifications`, `timestamp`, `allPassed`.
*   **`IssueVerification`**: Verification details for an individual issue.
    *   Fields: `issueNumber`, `passed`, `checks`.
*   **`VerificationCheck`**: Single check in `IssueVerification`.
    *   Fields: `name`, `passed`, `message`.
*   **`ValidationResult`**: Output of `validateJsonFile`, `validateGamePlan`, or `validateInvestigationResult`.
    *   Fields: `valid`, `path`, `errors`.
*   **`CrossRepoEntry`**: Remote repository to sync triaged issues with.
    *   Fields: `owner`, `repo`, `relationship`, `fullName`.

## 4. Common Operations

### Example 1: Constructing Data Models
Use standard Dart constructors and cascade notation (`..`) where applicable to construct the underlying data models.

```dart
// A single investigation or action task within the game plan.
final task = TriageTask(
  id: 'issue-42-code',
  agent: AgentType.codeAnalysis,
)
  // Current state of the task
  ..status = TaskStatus.running
  // Error string if the task failed
  ..error = null;

// The triage plan for a single GitHub issue.
final issuePlan = IssuePlan(
  number: 42,
  title: 'Fix null pointer exception in parser',
  author: 'johndoe',
  tasks: [task],
);

// The top-level game plan that orchestrates the entire triage pipeline.
final gamePlan = GamePlan(
  planId: 'triage-12345',
  createdAt: DateTime.now(),
  issues: [issuePlan],
);
```

### Example 2: Triaging a Single Issue Manually
This demonstrates chaining all standard phases to investigate and act on a single issue.

```dart
Future<void> manualTriagePipeline(String repoRoot, int issueNumber) async {
  // Ensure MCP is configured
  mcp.ensureMcpConfigured(repoRoot);

  final runDir = "$repoRoot/.cicd_runs/manual_triage_run";
  
  // Phase 1: Plan
  final GamePlan gamePlan = await plan_phase.planSingleIssue(issueNumber, repoRoot, runDir: runDir);
  if (gamePlan.issues.isEmpty) return;

  // Phase 2: Investigate (parallel agent execution)
  final Map<int, List<InvestigationResult>> results = await investigate_phase.investigate(
    gamePlan, repoRoot, runDir: runDir, verbose: true,
  );

  // Phase 3: Act (execute actions & add triage labels)
  final List<TriageDecision> decisions = await act_phase.act(
    gamePlan, results, repoRoot, runDir: runDir,
  );

  // Phase 4: Verify (check execution success)
  final VerificationReport report = await verify_phase.verify(
    gamePlan, decisions, repoRoot, runDir: runDir,
  );

  // Phase 5 & 5b: Link and Cross-Repo Link
  await link_phase.link(gamePlan, decisions, repoRoot, runDir: runDir);
  await cross_repo_phase.crossRepoLink(gamePlan, decisions, repoRoot, runDir: runDir);

  print('Triage Complete for #$issueNumber. All Passed: ${report.allPassed}');
}
```

### Example 3: Auto-Triaging All Untriaged Open Issues
This fetches all open issues missing the `triaged` label and routes them through the pipeline.

```dart
Future<void> autoTriageAll(String repoRoot) async {
  final runDir = "$repoRoot/.cicd_runs/auto_triage_run";

  // Discover untriaged issues
  final GamePlan gamePlan = await plan_phase.planAutoTriage(repoRoot, runDir: runDir);

  if (gamePlan.issues.isNotEmpty) {
    // Run the remaining pipeline phases
    final results = await investigate_phase.investigate(gamePlan, repoRoot, runDir: runDir);
    final decisions = await act_phase.act(gamePlan, results, repoRoot, runDir: runDir);
    await verify_phase.verify(gamePlan, decisions, repoRoot, runDir: runDir);
    await link_phase.link(gamePlan, decisions, repoRoot, runDir: runDir);
  }
}
```

### Example 4: Running Pre-Release Triage
Executed before generating release notes, this scans for issues and errors that have been resolved by code changes between an older tag and `HEAD`.

```dart
Future<void> runPreReleaseScan(String repoRoot) async {
  final runDir = "$repoRoot/.cicd_runs/release_triage_run";
  
  // Analyzes git diff, commit messages, and correlates them with GitHub & Sentry issues
  final String manifestPath = await pre_release_phase.preReleaseTriage(
    prevTag: 'v1.0.0',
    newVersion: '1.1.0',
    repoRoot: repoRoot,
    runDir: runDir,
    verbose: false,
  );
  
  print('Pre-Release manifest written to: $manifestPath');
}
```

### Example 5: Running Post-Release Triage
Executed after the new release is published. This loops over the manifest generated in the pre-release step to finalize the artifacts by commenting/closing issues.

```dart
Future<void> finalizeRelease(String repoRoot, String manifestPath) async {
  final runDir = "$repoRoot/.cicd_runs/post_release_run";

  await post_release_phase.postReleaseTriage(
    newVersion: '1.1.0',
    releaseTag: 'v1.1.0',
    releaseUrl: 'https://github.com/my-org/my-repo/releases/tag/v1.1.0',
    manifestPath: manifestPath,
    repoRoot: repoRoot,
    runDir: runDir,
  );
}
```

### Example 6: Validation Utilities
Easily check structure validity.

```dart
void checkGamePlanValidity(String planPath) {
  final ValidationResult result = validateGamePlan(planPath);
  
  if (result.valid) {
    print('Game plan at ${result.path} is valid.');
  } else {
    print('Errors found in game plan: ${result.errors.join(", ")}');
  }
}
```

## 5. Configuration
The Triage pipeline relies heavily on the `TriageConfig` singleton. The config is loaded from `.runtime_ci/config.json` inside your repository.

If specific configurations are omitted, sensible defaults map to standard pipeline thresholds. Notable environment configurations:
- `GEMINI_API_KEY`: Sourced automatically via the key specified in `config.geminiApiKeyEnv`.
- `GH_TOKEN` / `GITHUB_TOKEN`: Utilized for invoking `gh` CLI commands and managing MCP permissions.

## 6. Related Modules
- **MCP Config (`mcp_config.dart`)**: Automates the instantiation of `github-mcp-server` via Docker and hooks `mcp.sentry.dev/mcp` directly into your `.gemini/settings.json`. Ensure `ensureMcpConfigured()` is called before execution.
- **Gemini Runner (`gemini_runner.dart`)**: Handles queuing and rate limits via exponential backoff.
- **RunContext (`run_context.dart`)**: Oversees `.cicd_runs` caching mechanism, enabling resumable triage sessions.
