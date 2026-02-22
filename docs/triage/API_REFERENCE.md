# Issue Triage Engine API Reference

## 1. Classes

### Triage Models

- **TriageAction** -- A concrete action to take on a GitHub issue.
  - Fields: `type` (ActionType), `description` (String), `parameters` (Map<String, dynamic>), `executed` (bool), `verified` (bool), `error` (String?)
  - Methods: `TriageAction.fromJson(Map<String, dynamic> json)`, `toJson() -> Map<String, dynamic>`

  ```dart
  import 'package:runtime_ci_tooling/src/triage/models/triage_decision.dart';
  import 'package:runtime_ci_tooling/src/triage/models/game_plan.dart';

  final action = TriageAction(
    type: ActionType.label,
    description: 'Add needs-investigation label',
    parameters: {'labels': ['needs-investigation']},
  );
  ```

- **TriageDecision** -- The aggregated triage decision for a single issue.
  - Fields: `issueNumber` (int), `aggregateConfidence` (double), `riskLevel` (RiskLevel), `rationale` (String), `actions` (List<TriageAction>), `investigationResults` (List<InvestigationResult>)
  - Factory Constructors: `TriageDecision.fromResults({required int issueNumber, required List<InvestigationResult> results})`
  - Methods: `TriageDecision.fromJson(Map<String, dynamic> json)`, `toJson() -> Map<String, dynamic>`

  ```dart
  import 'package:runtime_ci_tooling/src/triage/models/triage_decision.dart';

  final decision = TriageDecision.fromResults(
    issueNumber: 123,
    results: [/* list of InvestigationResult */],
  );
  ```

- **TriageTask** -- A single investigation or action task within the game plan.
  - Fields: `id` (String), `agent` (AgentType), `status` (TaskStatus), `error` (String?), `result` (Map<String, dynamic>?)
  - Methods: `TriageTask.fromJson(Map<String, dynamic> json)`, `toJson() -> Map<String, dynamic>`

- **IssuePlan** -- The triage plan for a single GitHub issue.
  - Fields: `number` (int), `title` (String), `author` (String), `existingLabels` (List<String>), `tasks` (List<TriageTask>), `decision` (Map<String, dynamic>?)
  - Getters: `investigationComplete` (bool)
  - Methods: `IssuePlan.fromJson(Map<String, dynamic> json)`, `toJson() -> Map<String, dynamic>`

- **LinkSpec** -- A link to create between two entities (issue, PR, changelog, release notes).
  - Fields: `sourceType` (String), `sourceId` (String), `targetType` (String), `targetId` (String), `description` (String), `applied` (bool)
  - Methods: `LinkSpec.fromJson(Map<String, dynamic> json)`, `toJson() -> Map<String, dynamic>`

- **GamePlan** -- The top-level game plan that orchestrates the entire triage pipeline.
  - Fields: `planId` (String), `createdAt` (DateTime), `issues` (List<IssuePlan>), `linksToCreate` (List<LinkSpec>)
  - Factory Constructors: `GamePlan.forIssues(List<Map<String, dynamic>> issueData)`
  - Methods: `GamePlan.fromJson(Map<String, dynamic> json)`, `toJson() -> Map<String, dynamic>`, `toJsonString() -> String`

  ```dart
  import 'package:runtime_ci_tooling/src/triage/models/game_plan.dart';

  final plan = GamePlan.forIssues([
    {
      'number': 42,
      'title': 'Bug: App crashes on startup',
      'author': 'user123',
      'labels': ['bug']
    }
  ]);
  ```

- **InvestigationResult** -- Data class for investigation agent results.
  - Fields: `agentId` (String), `issueNumber` (int), `confidence` (double), `summary` (String), `evidence` (List<String>), `recommendedLabels` (List<String>), `suggestedComment` (String?), `suggestClose` (bool), `closeReason` (String?), `relatedEntities` (List<RelatedEntity>), `turnsUsed` (int), `toolCallsMade` (int), `durationMs` (int)
  - Factory Constructors: `InvestigationResult.failed({required String agentId, required int issueNumber, required String error})`
  - Methods: `InvestigationResult.fromJson(Map<String, dynamic> json)`, `toJson() -> Map<String, dynamic>`

- **RelatedEntity** -- A reference to a related entity (PR, issue, commit, file) found during investigation.
  - Fields: `type` (String), `id` (String), `description` (String), `relevance` (double)
  - Methods: `RelatedEntity.fromJson(Map<String, dynamic> json)`, `toJson() -> Map<String, dynamic>`

### Verification Models

- **VerificationCheck** -- Represents a single verification check on a triage action.
  - Fields: `name` (String), `passed` (bool), `message` (String)
  - Methods: `toJson() -> Map<String, dynamic>`

- **IssueVerification** -- Represents the verification result for a single issue.
  - Fields: `issueNumber` (int), `passed` (bool), `checks` (List<VerificationCheck>)
  - Methods: `toJson() -> Map<String, dynamic>`

- **VerificationReport** -- Represents the entire verification report across all decisions.
  - Fields: `verifications` (List<IssueVerification>), `timestamp` (DateTime)
  - Getters: `allPassed` (bool)
  - Methods: `toJson() -> Map<String, dynamic>`

### Configuration & Tooling Models

- **RunContext** -- Manages a run-scoped audit trail directory for CI/CD operations.
  - Fields: `repoRoot` (String), `runDir` (String), `command` (String), `startedAt` (DateTime), `args` (List<String>)
  - Getters: `runId` (String)
  - Factory Constructors: `RunContext.create(String repoRoot, String command, {List<String> args})`, `RunContext.load(String repoRoot, String runDirPath)`
  - Methods: `subdir(String name) -> String`, `savePrompt(String phase, String prompt)`, `saveResponse(String phase, String rawResponse)`, `saveArtifact(String phase, String filename, String content)`, `saveJsonArtifact(String phase, String filename, Map<String, dynamic> data)`, `artifactPath(String phase, String filename) -> String`, `readArtifact(String phase, String filename) -> String?`, `hasArtifact(String phase, String filename) -> bool`, `finalize({int? exitCode})`, `archiveForRelease(String version)`
  - Static Methods: `findLatestRun(String repoRoot, {String? command}) -> String?`, `listRuns(String repoRoot) -> List<Directory>`

- **ValidationResult** -- Result of a JSON validation.
  - Fields: `valid` (bool), `path` (String), `errors` (List<String>)

- **TriageConfig** -- Centralized, config-driven loader for the runtime CI tooling pipeline.
  - Fields: `loadedFrom` (String?)
  - Getters: `isConfigured` (bool), `repoName` (String), `repoOwner` (String), `triagedLabel` (String), `changelogPath` (String), `releaseNotesPath` (String), `gcpProject` (String), `sentryOrganization` (String), `sentryProjects` (List<String>), `sentryScanOnPreRelease` (bool), `sentryRecentErrorsHours` (int), `preReleaseScanSentry` (bool), `preReleaseScanGithub` (bool), `postReleaseCloseOwnRepo` (bool), `postReleaseCloseCrossRepo` (bool), `postReleaseCommentCrossRepo` (bool), `postReleaseLinkSentry` (bool), `crossRepoEnabled` (bool), `crossRepoRepos` (List<CrossRepoEntry>), `typeLabels` (List<String>), `priorityLabels` (List<String>), `areaLabels` (List<String>), `autoCloseThreshold` (double), `suggestCloseThreshold` (double), `commentThreshold` (double), `enabledAgents` (List<String>), `flashModel` (String), `proModel` (String), `maxTurns` (int), `maxConcurrent` (int), `maxRetries` (int), `geminiApiKeyEnv` (String), `githubTokenEnvNames` (List<String>), `gcpSecretName` (String)
  - Factory Constructors: `TriageConfig.load()`
  - Methods: `shouldRunAgent(String agentName, String repoRoot) -> bool`, `resolveGeminiApiKey() -> String?`, `resolveGithubToken() -> String?`

- **CrossRepoEntry** -- Represents a configured cross-repository entry.
  - Fields: `owner` (String), `repo` (String), `relationship` (String)
  - Getters: `fullName` (String)

### Gemini Executor Models

- **GeminiResult** -- The structured result from a Gemini CLI invocation.
  - Fields: `taskId` (String), `response` (String?), `stats` (Map<String, dynamic>?), `error` (Map<String, dynamic>?), `attempts` (int), `durationMs` (int), `success` (bool)
  - Getters: `toolCalls` (int), `turnsUsed` (int), `errorMessage` (String)

- **GeminiTask** -- A single task to execute via Gemini CLI.
  - Fields: `id` (String), `prompt` (String), `model` (String), `maxTurns` (int), `allowedTools` (List<String>), `fileIncludes` (List<String>), `workingDirectory` (String?), `sandbox` (bool), `auditDir` (String?)

  ```dart
  import 'package:runtime_ci_tooling/src/triage/utils/gemini_runner.dart';

  final task = GeminiTask(
    id: 'issue-123-code',
    prompt: 'Analyze issue #123...',
    model: 'gemini-3.1-pro-preview',
    allowedTools: ['run_shell_command(git)'],
  );
  ```

- **GeminiRunner** -- Manages parallel Gemini CLI execution with retry and rate limiting.
  - Fields: `maxConcurrent` (int), `maxRetries` (int), `initialBackoff` (Duration), `maxBackoff` (Duration), `verbose` (bool)
  - Methods: `executeBatch(List<GeminiTask> tasks) -> Future<List<GeminiResult>>`

  ```dart
  import 'package:runtime_ci_tooling/src/triage/utils/gemini_runner.dart';

  final runner = GeminiRunner(maxConcurrent: 2, maxRetries: 3);
  final results = await runner.executeBatch([task1, task2]);
  ```

## 2. Enums

- **TaskStatus** -- Represents the status of a triage task.
  - `pending`, `running`, `completed`, `failed`, `skipped`

- **AgentType** -- Identifies the specific investigation agent type.
  - `codeAnalysis`, `prCorrelation`, `duplicate`, `sentiment`, `changelog`

- **RiskLevel** -- Assessed risk level based on the confidence of investigation results.
  - `low`, `medium`, `high`

- **ActionType** -- A concrete action to perform on a GitHub issue.
  - `label`, `comment`, `close`, `linkPr`, `linkIssue`, `none`

## 3. Top-Level Functions

### General Configuration & Utilities

- **reloadConfig() -> void**
  - Reload config from disk (useful after modifications).
- **validateJsonFile(String path, List<String> requiredKeys) -> ValidationResult**
  - Validates that a JSON file exists, is valid JSON, and contains required keys.
- **validateGamePlan(String path) -> ValidationResult**
  - Validates a game plan JSON structure.
- **validateInvestigationResult(String path) -> ValidationResult**
  - Validates an investigation result JSON structure.
- **writeJson(String path, Map<String, dynamic> data) -> void**
  - Writes a JSON object to a file with pretty formatting.
- **readJson(String path) -> Map<String, dynamic>?**
  - Reads and parses a JSON file, returning null on error.

### MCP Configuration Utilities

- **buildGitHubMcpConfig({String? token}) -> Map<String, dynamic>**
  - Builds the GitHub MCP server configuration for `.gemini/settings.json`.
- **buildSentryMcpConfig() -> Map<String, dynamic>**
  - Builds the Sentry MCP server configuration (remote, OAuth-based).
- **readSettings(String repoRoot) -> Map<String, dynamic>**
  - Reads the current `.gemini/settings.json` file.
- **writeSettings(String repoRoot, Map<String, dynamic> settings) -> void**
  - Writes updated settings to `.gemini/settings.json`.
- **ensureMcpConfigured(String repoRoot) -> bool**
  - Ensures MCP servers are configured in `.gemini/settings.json`.
- **validateMcpServers(String repoRoot) -> Future<Map<String, bool>>**
  - Validates that required MCP servers are configured and accessible.

### Pipeline Phases

- **planSingleIssue(int issueNumber, String repoRoot, {required String runDir}) -> Future<GamePlan>**
  - Creates a game plan for a single issue.
- **planAutoTriage(String repoRoot, {required String runDir}) -> Future<GamePlan>**
  - Creates a game plan for all open untriaged issues (auto mode).
- **loadPlan({String? runDir}) -> GamePlan?**
  - Loads an existing game plan from a run directory.
- **investigate(GamePlan plan, String repoRoot, {required String runDir, bool verbose = false}) -> Future<Map<int, List<InvestigationResult>>>**
  - Run investigation agents for every issue in the game plan.
- **act(GamePlan plan, Map<int, List<InvestigationResult>> investigationResults, String repoRoot, {required String runDir}) -> Future<List<TriageDecision>>**
  - Apply triage decisions for all issues in the game plan.
- **verify(GamePlan plan, List<TriageDecision> decisions, String repoRoot, {required String runDir}) -> Future<VerificationReport>**
  - Verify that all triage actions were applied correctly.
- **link(GamePlan plan, List<TriageDecision> decisions, String repoRoot, {required String runDir}) -> Future<void>**
  - Cross-link all triaged issues to related artifacts.
- **crossRepoLink(GamePlan plan, List<TriageDecision> decisions, String repoRoot, {required String runDir}) -> Future<void>**
  - Search and link related issues across configured dependent repos.
- **preReleaseTriage({required String prevTag, required String newVersion, required String repoRoot, required String runDir, bool verbose = false}) -> Future<String>**
  - Scan issues and produce an issue manifest for the upcoming release.
- **postReleaseTriage({required String newVersion, required String releaseTag, required String releaseUrl, required String manifestPath, required String repoRoot, required String runDir, bool verbose = false}) -> Future<void>**
  - Run post-release actions based on the pre-release issue manifest.

### Agents

Each agent has a corresponding `buildTask` function to generate its `GeminiTask`:

- **buildTask(IssuePlan issue, String repoRoot, {String? resultsDir}) -> GeminiTask**
  - Implemented in `changelog_agent.dart`, `code_analysis_agent.dart`, `duplicate_agent.dart`, `pr_correlation_agent.dart`, and `sentiment_agent.dart`.
