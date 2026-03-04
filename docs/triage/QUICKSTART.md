# Issue Triage Engine Quickstart

## 1. Overview
The Issue Triage Engine is an AI-powered pipeline that automatically investigates, categorizes, links, and acts upon GitHub issues and Sentry errors. It utilizes specialized Gemini agents (Code Analysis, PR Correlation, Duplicate Detection, Sentiment, and Changelog) to process issues through a structured multi-phase pipeline (`plan`, `investigate`, `act`, `verify`, `link`). It supports both day-to-day auto-triaging and comprehensive pre/post-release correlation mapping.

## 2. Import
Import the required phases, utilities, and models from the `src/triage` directory:

```dart
// Models
import 'package:runtime_ci_tooling/src/triage/models/game_plan.dart';
import 'package:runtime_ci_tooling/src/triage/models/triage_decision.dart';
import 'package:runtime_ci_tooling/src/triage/models/investigation_result.dart';

// Utilities
import 'package:runtime_ci_tooling/src/triage/utils/config.dart';
import 'package:runtime_ci_tooling/src/triage/utils/run_context.dart';
import 'package:runtime_ci_tooling/src/triage/utils/mcp_config.dart' as mcp;

// Phases
import 'package:runtime_ci_tooling/src/triage/phases/plan.dart' as plan_phase;
import 'package:runtime_ci_tooling/src/triage/phases/investigate.dart' as investigate_phase;
import 'package:runtime_ci_tooling/src/triage/phases/act.dart' as act_phase;
import 'package:runtime_ci_tooling/src/triage/phases/verify.dart' as verify_phase;
import 'package:runtime_ci_tooling/src/triage/phases/link.dart' as link_phase;
import 'package:runtime_ci_tooling/src/triage/phases/cross_repo_link.dart' as cross_repo_phase;
```

## 3. Setup
Before executing the triage pipeline, you need to load the configuration, ensure MCP servers are configured properly, and create a `RunContext` to manage the audit trail directory.

```dart
// 1. Reload configuration from .runtime_ci/config.json
reloadConfig();

// 2. Ensure GitHub and Sentry MCP servers are configured in .gemini/settings.json
mcp.ensureMcpConfigured(repoRoot);

// 3. Create a RunContext to manage the scoped audit trail directory
final runContext = RunContext.create(repoRoot, 'my_triage_command');
final runDir = runContext.runDir;
```

## 4. Common Operations

### Running a Full Triage Pipeline for a Single Issue
Execute the standard 5-phase pipeline on a specific issue.

```dart
// Phase 1: Create a GamePlan for a specific issue number
final GamePlan gamePlan = await plan_phase.planSingleIssue(42, repoRoot, runDir: runDir);

// Phase 2: Run parallel Gemini agents to investigate the issue
final Map<int, List<InvestigationResult>> results = await investigate_phase.investigate(
  gamePlan, 
  repoRoot, 
  runDir: runDir,
);

// Phase 3: Apply labels, comments, and close actions based on confidence thresholds
final List<TriageDecision> decisions = await act_phase.act(
  gamePlan, 
  results, 
  repoRoot, 
  runDir: runDir,
);

// Phase 4: Verify actions were successfully applied to GitHub
final VerificationReport report = await verify_phase.verify(
  gamePlan, 
  decisions, 
  repoRoot, 
  runDir: runDir,
);

// Phase 5: Create bidirectional links to PRs, release notes, and changelogs
await link_phase.link(gamePlan, decisions, repoRoot, runDir: runDir);

// Phase 5b: Cross-repo linking
await cross_repo_phase.crossRepoLink(gamePlan, decisions, repoRoot, runDir: runDir);
```

### Auto-Triaging All Open Issues
Discover all open, untriaged issues in the repository and batch process them.

```dart
// Generates a GamePlan containing all untriaged issues
final GamePlan autoPlan = await plan_phase.planAutoTriage(repoRoot, runDir: runDir);

if (autoPlan.issues.isNotEmpty) {
  final results = await investigate_phase.investigate(autoPlan, repoRoot, runDir: runDir);
  final decisions = await act_phase.act(autoPlan, results, repoRoot, runDir: runDir);
  await verify_phase.verify(autoPlan, decisions, repoRoot, runDir: runDir);
  await link_phase.link(autoPlan, decisions, repoRoot, runDir: runDir);
  await cross_repo_phase.crossRepoLink(autoPlan, decisions, repoRoot, runDir: runDir);
}
```

### Generating a Pre-Release Issue Manifest
Scan for issues addressed between a previous tag and the current `HEAD` to feed into changelog generation.

```dart
import 'package:runtime_ci_tooling/src/triage/phases/pre_release.dart' as pre_release_phase;

final String manifestPath = await pre_release_phase.preReleaseTriage(
  prevTag: 'v1.0.0',
  newVersion: '1.1.0',
  repoRoot: repoRoot,
  runDir: runDir,
  verbose: true,
);
// Produces issue_manifest.json containing correlated GitHub and Sentry issues
```

### Executing Post-Release Actions
Close the loop after a release by commenting on issues, closing resolved ones, and linking Sentry errors.

```dart
import 'package:runtime_ci_tooling/src/triage/phases/post_release.dart' as post_release_phase;

await post_release_phase.postReleaseTriage(
  newVersion: '1.1.0',
  releaseTag: 'v1.1.0',
  releaseUrl: 'https://github.com/owner/repo/releases/tag/v1.1.0',
  manifestPath: manifestPath, // Passed from preReleaseTriage
  repoRoot: repoRoot,
  runDir: runDir,
);
```

## 5. Configuration
The engine relies on a `.runtime_ci/config.json` file at the repository root. The `TriageConfig` loader requires these keys at minimum:
- `repository.name` (e.g., `"runtime_ci_tooling"`)
- `repository.owner` (e.g., `"open-runtime"`)

**Environment Variables Required:**
- `GEMINI_API_KEY`: A valid Google Gemini API key.
- `GH_TOKEN`, `GITHUB_TOKEN`, or `GITHUB_PAT`: A GitHub Personal Access Token to authenticate the GitHub CLI and MCP server.

## 6. Data Models and Enums
Below is a reference of all the core entities and enums used in the Triage pipeline. Construct them using proper camelCase field names.

### Enums
- **`TaskStatus`**: `pending`, `running`, `completed`, `failed`, `skipped`
- **`AgentType`**: `codeAnalysis`, `prCorrelation`, `duplicate`, `sentiment`, `changelog`
- **`RiskLevel`**: `low`, `medium`, `high`
- **`ActionType`**: `label`, `comment`, `close`, `linkPr`, `linkIssue`, `none`

### Models

**`GamePlan`**
Orchestrates the entire triage pipeline.
```dart
final plan = GamePlan(
  planId: 'triage-123',
  createdAt: DateTime.now(),
  issues: [
    IssuePlan(
      number: 42,
      title: 'Bug with feature X',
      author: 'johndoe',
      tasks: [
        TriageTask(id: 'issue-42-code', agent: AgentType.codeAnalysis),
      ],
    )
    ..decision = null // populated later
  ],
)..linksToCreate.add(LinkSpec(
  sourceType: 'issue',
  sourceId: '42',
  targetType: 'pr',
  targetId: '43',
  description: 'Related PR',
));
```

**`IssuePlan`**
The triage plan for a single GitHub issue. Fields include `number`, `title`, `author`, `existingLabels`, `tasks`, and `decision`.

**`TriageTask`**
A single investigation task. Fields: `id`, `agent`, `status`, `error`, and `result`.

**`LinkSpec`**
A cross-link between two entities. Fields: `sourceType`, `sourceId`, `targetType`, `targetId`, `description`, and `applied`.

**`InvestigationResult`**
The output from a Gemini agent.
```dart
final result = InvestigationResult(
  agentId: 'code_analysis',
  issueNumber: 42,
  confidence: 0.85,
  summary: 'Code fix was found in main',
)
  ..evidence.add('Found commit 123 fixing the bug')
  ..recommendedLabels.add('bug')
  ..relatedEntities.add(
    RelatedEntity(
      type: 'commit',
      id: 'sha123',
      description: 'Fix crash in auth',
      relevance: 0.9,
    ),
  );
```

**`TriageDecision`**
The aggregated decision formulated from `InvestigationResult`s.
```dart
final decision = TriageDecision(
  issueNumber: 42,
  aggregateConfidence: 0.85,
  riskLevel: RiskLevel.medium,
  rationale: 'High confidence from code analysis agent',
  actions: [
    TriageAction(
      type: ActionType.label,
      description: 'Apply bug label',
      parameters: {'labels': ['bug']},
    )
  ],
)..investigationResults.addAll(results);
```

**`TriageAction`**
A concrete action to perform on GitHub. Fields: `type` (ActionType), `description`, `parameters`, `executed`, `verified`, and `error`.

**`RelatedEntity`**
A reference to a relevant artifact. Fields: `type`, `id`, `description`, and `relevance`.

## 7. Related Modules
- **Models**: `GamePlan`, `IssuePlan`, `InvestigationResult`, `TriageDecision` (`lib/src/triage/models/`)
- **Agents**: `code_analysis_agent.dart`, `changelog_agent.dart`, `duplicate_agent.dart`, `pr_correlation_agent.dart`, `sentiment_agent.dart` (`lib/src/triage/agents/`)
- **CLI Entrypoint**: `lib/src/triage/triage_cli.dart`
