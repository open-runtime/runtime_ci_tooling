# Issue Triage Engine API Reference

This documentation covers the classes, enums, and functions used by the Issue Triage Engine module.

## 1. Classes

### `TriageAction`
A concrete action to take on a GitHub issue.
- **Fields**:
  - `type` (`ActionType`): The type of action to take.
  - `description` (`String`): Description of the action.
  - `parameters` (`Map<String, dynamic>`): Action-specific parameters.
  - `executed` (`bool`): Tracks if the action was executed.
  - `verified` (`bool`): Tracks if the action was verified successfully.
  - `error` (`String?`): Any error that occurred during execution.
- **Methods**:
  - `toJson()`: Converts the instance to a JSON map.
- **Constructors**:
  - `TriageAction({required ActionType type, required String description, Map<String, dynamic> parameters = const {}, bool executed = false, bool verified = false, String? error})`
  - `TriageAction.fromJson(Map<String, dynamic> json)`: Factory constructor.
- **Example**:
  ```dart
  import 'package:runtime_ci_tooling/src/triage/models/triage_decision.dart';

  final action = TriageAction(
    type: ActionType.label,
    description: 'Apply needs-investigation label',
    parameters: {'labels': ['needs-investigation']},
  )
    ..executed = false
    ..verified = false;
  ```

### `TriageDecision`
The aggregated triage decision for a single issue.
- **Fields**:
  - `issueNumber` (`int`): The GitHub issue number.
  - `aggregateConfidence` (`double`): Overall confidence score for the decision.
  - `riskLevel` (`RiskLevel`): Associated risk level based on confidence.
  - `rationale` (`String`): Explanation of the decision.
  - `actions` (`List<TriageAction>`): Concrete actions recommended for the issue.
  - `investigationResults` (`List<InvestigationResult>`): Results from the triage agents.
- **Methods**:
  - `toJson()`: Converts the instance to a JSON map.
- **Constructors**:
  - `TriageDecision({required int issueNumber, required double aggregateConfidence, required RiskLevel riskLevel, required String rationale, required List<TriageAction> actions, List<InvestigationResult> investigationResults = const []})`
  - `TriageDecision.fromJson(Map<String, dynamic> json)`: Factory constructor.
  - `TriageDecision.fromResults({required int issueNumber, required List<InvestigationResult> results})`: Factory constructor that aggregates agent results.
- **Example**:
  ```dart
  import 'package:runtime_ci_tooling/src/triage/models/triage_decision.dart';

  final decision = TriageDecision(
    issueNumber: 42,
    aggregateConfidence: 0.85,
    riskLevel: RiskLevel.medium,
    rationale: 'Multiple agents confirmed the fix.',
    actions: [
      TriageAction(
        type: ActionType.comment,
        description: 'Post findings comment',
      )
    ],
  );
  ```

### `TriageTask`
A single investigation or action task within the game plan.
- **Fields**:
  - `id` (`String`): Unique identifier for the task.
  - `agent` (`AgentType`): The agent assigned to the task.
  - `status` (`TaskStatus`): Current execution status.
  - `error` (`String?`): Error encountered during task execution.
  - `result` (`Map<String, dynamic>?`): Unstructured output result of the task.
- **Methods**:
  - `toJson()`: Converts the instance to a JSON map.
- **Constructors**:
  - `TriageTask({required String id, required AgentType agent, TaskStatus status = TaskStatus.pending, String? error, Map<String, dynamic>? result})`
  - `TriageTask.fromJson(Map<String, dynamic> json)`: Factory constructor.
- **Example**:
  ```dart
  import 'package:runtime_ci_tooling/src/triage/models/game_plan.dart';

  final task = TriageTask(
    id: 'issue-42-code',
    agent: AgentType.codeAnalysis,
  )
    ..status = TaskStatus.running
    ..error = null
    ..result = {'confidence': 0.9};
  ```

### `IssuePlan`
The triage plan for a single GitHub issue.
- **Fields**:
  - `number` (`int`): The GitHub issue number.
  - `title` (`String`): The issue title.
  - `author` (`String`): The issue author username.
  - `existingLabels` (`List<String>`): Labels already applied to the issue.
  - `tasks` (`List<TriageTask>`): The agent tasks planned for this issue.
  - `decision` (`Map<String, dynamic>?`): The finalized triage decision map.
  - `investigationComplete` (`bool`): Getter indicating if all tasks are complete or failed.
- **Methods**:
  - `toJson()`: Converts the instance to a JSON map.
- **Constructors**:
  - `IssuePlan({required int number, required String title, required String author, List<String> existingLabels = const [], required List<TriageTask> tasks, Map<String, dynamic>? decision})`
  - `IssuePlan.fromJson(Map<String, dynamic> json)`: Factory constructor.
- **Example**:
  ```dart
  import 'package:runtime_ci_tooling/src/triage/models/game_plan.dart';

  final issuePlan = IssuePlan(
    number: 42,
    title: 'Bug in authentication',
    author: 'johndoe',
    existingLabels: ['bug'],
    tasks: [
      TriageTask(id: 'task-1', agent: AgentType.codeAnalysis),
    ],
  )..decision = {'risk_level': 'low'};
  ```

### `LinkSpec`
A link to create between two entities (issue, PR, changelog, release notes).
- **Fields**:
  - `sourceType` (`String`): The entity source type (e.g., "issue", "pr").
  - `sourceId` (`String`): The ID of the source entity.
  - `targetType` (`String`): The entity target type.
  - `targetId` (`String`): The ID of the target entity.
  - `description` (`String`): Description of the relationship.
  - `applied` (`bool`): Whether the link has been successfully applied.
- **Methods**:
  - `toJson()`: Converts the instance to a JSON map.
- **Constructors**:
  - `LinkSpec({required String sourceType, required String sourceId, required String targetType, required String targetId, required String description, bool applied = false})`
  - `LinkSpec.fromJson(Map<String, dynamic> json)`: Factory constructor.
- **Example**:
  ```dart
  import 'package:runtime_ci_tooling/src/triage/models/game_plan.dart';

  final link = LinkSpec(
    sourceType: 'issue',
    sourceId: '42',
    targetType: 'pr',
    targetId: '43',
    description: 'Related PR',
  )..applied = true;
  ```

### `GamePlan`
The top-level game plan that orchestrates the entire triage pipeline.
- **Fields**:
  - `planId` (`String`): Unique identifier for the game plan.
  - `createdAt` (`DateTime`): Creation timestamp.
  - `issues` (`List<IssuePlan>`): The list of individual issue plans.
  - `linksToCreate` (`List<LinkSpec>`): Deferred cross-links to be applied.
- **Methods**:
  - `toJson()`: Converts the instance to a JSON map.
  - `toJsonString()`: Returns pretty-printed JSON structure.
- **Constructors**:
  - `GamePlan({required String planId, required DateTime createdAt, required List<IssuePlan> issues, List<LinkSpec> linksToCreate = const []})`
  - `GamePlan.fromJson(Map<String, dynamic> json)`: Factory constructor.
  - `GamePlan.forIssues(List<Map<String, dynamic>> issueData)`: Factory constructor creating default tasks.
- **Example**:
  ```dart
  import 'package:runtime_ci_tooling/src/triage/models/game_plan.dart';

  final gamePlan = GamePlan(
    planId: 'triage-123456789',
    createdAt: DateTime.now(),
    issues: [
      IssuePlan(
        number: 42,
        title: 'Fix login issue',
        author: 'janedoe',
        tasks: [],
      ),
    ],
  );
  ```

### `InvestigationResult`
Data class for investigation agent results.
- **Fields**:
  - `agentId` (`String`): Identifier for the agent.
  - `issueNumber` (`int`): GitHub issue number being investigated.
  - `confidence` (`double`): Level of certainty calculated by the agent.
  - `summary` (`String`): Description/summary of findings.
  - `evidence` (`List<String>`): Points of evidence gathered.
  - `recommendedLabels` (`List<String>`): Labels suggested by the agent.
  - `suggestedComment` (`String?`): Optional comment text suggested.
  - `suggestClose` (`bool`): Whether the agent recommends closing.
  - `closeReason` (`String?`): Reason provided if suggestClose is true.
  - `relatedEntities` (`List<RelatedEntity>`): Connected entities discovered.
  - `turnsUsed` (`int`): Total conversational turns utilized.
  - `toolCallsMade` (`int`): Total tool calls made during investigation.
  - `durationMs` (`int`): Execution duration in milliseconds.
- **Methods**:
  - `toJson()`: Converts the instance to a JSON map.
- **Constructors**:
  - `InvestigationResult({required String agentId, required int issueNumber, required double confidence, required String summary, List<String> evidence = const [], List<String> recommendedLabels = const [], String? suggestedComment, bool suggestClose = false, String? closeReason, List<RelatedEntity> relatedEntities = const [], int turnsUsed = 0, int toolCallsMade = 0, int durationMs = 0})`
  - `InvestigationResult.fromJson(Map<String, dynamic> json)`: Factory constructor.
  - `InvestigationResult.failed({required String agentId, required int issueNumber, required String error})`: Factory constructor for failures.
- **Example**:
  ```dart
  import 'package:runtime_ci_tooling/src/triage/models/investigation_result.dart';

  final result = InvestigationResult(
    agentId: 'code_analysis',
    issueNumber: 42,
    confidence: 0.95,
    summary: 'Fix is clearly merged, tests pass.',
    evidence: ['Found commit #abcd123'],
    recommendedLabels: ['released'],
    suggestClose: true,
    closeReason: 'completed',
    relatedEntities: [
      RelatedEntity(
        type: 'commit',
        id: 'abcd123',
        description: 'Fix login error',
        relevance: 1.0,
      ),
    ],
  );
  ```

### `RelatedEntity`
A reference to a related entity (PR, issue, commit, file) found during investigation.
- **Fields**:
  - `type` (`String`): Entity type ("pr", "issue", "commit", "file").
  - `id` (`String`): Entity identifier.
  - `description` (`String`): Brief description.
  - `relevance` (`double`): Relevance score (0.0 - 1.0).
- **Methods**:
  - `toJson()`: Converts the instance to a JSON map.
- **Constructors**:
  - `RelatedEntity({required String type, required String id, required String description, double relevance = 0.5})`
  - `RelatedEntity.fromJson(Map<String, dynamic> json)`: Factory constructor.
- **Example**:
  ```dart
  import 'package:runtime_ci_tooling/src/triage/models/investigation_result.dart';

  final entity = RelatedEntity(
    type: 'pr',
    id: '100',
    description: 'Adds missing auth header',
    relevance: 0.85,
  );
  ```

### `RunContext`
Manages a run-scoped audit trail directory for CI/CD operations.
- **Fields**:
  - `repoRoot` (`String`): Repository root directory.
  - `runDir` (`String`): Isolated directory for the context run.
  - `command` (`String`): Executing command triggering the run.
  - `startedAt` (`DateTime`): Launch timestamp.
  - `args` (`List<String>`): Provided CLI arguments.
  - `runId` (`String`): Getter fetching the run ID (directory name).
- **Methods**:
  - `subdir(String name)`: Gets or creates a subdirectory within the run directory.
  - `savePrompt(String phase, String prompt)`: Saves a prompt sent to Gemini CLI.
  - `saveResponse(String phase, String rawResponse)`: Saves Gemini CLI response.
  - `saveArtifact(String phase, String filename, String content)`: Saves a structured artifact.
  - `saveJsonArtifact(String phase, String filename, Map<String, dynamic> data)`: Saves a JSON artifact.
  - `artifactPath(String phase, String filename)`: Gets the path for an artifact file.
  - `readArtifact(String phase, String filename)`: Reads an artifact file.
  - `hasArtifact(String phase, String filename)`: Checks if an artifact exists.
  - `finalize({int? exitCode})`: Updates meta.json with completion info.
  - `archiveForRelease(String version)`: Archives important artifacts to `cicd_audit`.
- **Constructors**:
  - `RunContext.create(String repoRoot, String command, {List<String> args = const []})`: Factory constructor.
  - `RunContext.load(String repoRoot, String runDirPath)`: Factory constructor.
- **Static Methods**:
  - `findLatestRun(String repoRoot, {String? command})`: Finds the most recent run directory.
  - `listRuns(String repoRoot)`: Lists all run directories.
- **Example**:
  ```dart
  import 'package:runtime_ci_tooling/src/triage/utils/run_context.dart';

  final context = RunContext.create('/path/to/repo', 'triage_cli', args: ['--auto']);
  context.savePrompt('explore', 'Analyze this issue...');
  context.saveResponse('explore', '{"confidence": 0.9}');
  context.finalize(exitCode: 0);
  ```

### `ValidationResult`
JSON validation utilities for triage pipeline artifacts.
- **Fields**:
  - `valid` (`bool`): Validation status.
  - `path` (`String`): Evaluated file path.
  - `errors` (`List<String>`): Encountered errors.
- **Methods**:
  - `toString()`: Prints valid/invalid string message representation.
- **Constructors**:
  - `ValidationResult({required bool valid, required String path, List<String> errors = const []})`
- **Example**:
  ```dart
  import 'package:runtime_ci_tooling/src/triage/utils/json_schemas.dart';

  final result = ValidationResult(
    valid: false,
    path: '/tmp/game_plan.json',
    errors: ['Missing required keys: plan_id'],
  );
  print(result.toString()); // Invalid: /tmp/game_plan.json -- Missing required keys: plan_id
  ```

### `TriageConfig`
Centralized, config-driven loader for the runtime CI tooling pipeline.
- **Fields & Getters**:
  - `loadedFrom` (`String?`): Resolved path to loaded config file.
  - `isConfigured` (`bool`): Whether this repo has opted into the CI tooling.
  - `repoName` (`String`): Dart package name / GitHub repo name.
  - `repoOwner` (`String`): GitHub org or user.
  - `triagedLabel` (`String`): Triage label string.
  - `changelogPath` (`String`): Path to CHANGELOG.md.
  - `releaseNotesPath` (`String`): Target directory for release notes.
  - `gcpProject` (`String`): GCP project identifier.
  - `sentryOrganization` (`String`): Associated Sentry org.
  - `sentryProjects` (`List<String>`): Listed Sentry projects.
  - `sentryScanOnPreRelease` (`bool`): Sentry scan flag.
  - `sentryRecentErrorsHours` (`int`): Sentry error time span parameter.
  - `preReleaseScanSentry` (`bool`): Feature flag.
  - `preReleaseScanGithub` (`bool`): Feature flag.
  - `postReleaseCloseOwnRepo` (`bool`): Feature flag.
  - `postReleaseCloseCrossRepo` (`bool`): Feature flag.
  - `postReleaseCommentCrossRepo` (`bool`): Feature flag.
  - `postReleaseLinkSentry` (`bool`): Feature flag.
  - `crossRepoEnabled` (`bool`): Feature flag.
  - `crossRepoRepos` (`List<CrossRepoEntry>`): Configured dependent repos.
  - `typeLabels`, `priorityLabels`, `areaLabels` (`List<String>`): Label schemas.
  - `autoCloseThreshold`, `suggestCloseThreshold`, `commentThreshold` (`double`): Automated pipeline confidence thresholds.
  - `enabledAgents` (`List<String>`): Permitted agent strings.
  - `flashModel`, `proModel` (`String`): Configured Gemini model targets.
  - `maxTurns`, `maxConcurrent`, `maxRetries` (`int`): Execution scaling constraints.
  - `geminiApiKeyEnv`, `gcpSecretName` (`String`): Key locators.
  - `githubTokenEnvNames` (`List<String>`): Configured possible token variable titles.
- **Methods**:
  - `shouldRunAgent(String agentName, String repoRoot)`: Checks if an agent condition applies.
  - `resolveGeminiApiKey()`: Gets key via env or GCP.
  - `resolveGithubToken()`: Gets token via env or GCP.
- **Constructors**:
  - `TriageConfig.load()`: Factory constructor.
- **Example**:
  ```dart
  import 'package:runtime_ci_tooling/src/triage/utils/config.dart';

  final conf = TriageConfig.load();
  print(conf.repoName);
  print(conf.autoCloseThreshold);
  ```

### `CrossRepoEntry`
Data model defining dependent cross-repository.
- **Fields**:
  - `owner` (`String`): GitHub repo owner.
  - `repo` (`String`): Target GitHub repository.
  - `relationship` (`String`): Structural connection descriptor.
  - `fullName` (`String`): Getter returning `$owner/$repo`.
- **Constructors**:
  - `CrossRepoEntry({required String owner, required String repo, required String relationship})`
- **Example**:
  ```dart
  import 'package:runtime_ci_tooling/src/triage/utils/config.dart';

  final entry = CrossRepoEntry(
    owner: 'open-runtime',
    repo: 'dart-runtime',
    relationship: 'dependency',
  );
  print(entry.fullName); // open-runtime/dart-runtime
  ```

### `GeminiResult`
Structured outcome block resulting from an isolated Gemini process.
- **Fields**:
  - `taskId` (`String`): Targeted invocation ID.
  - `response` (`String?`): Evaluated JSON-safe return payload.
  - `stats`, `error` (`Map<String, dynamic>?`): Operational metadata mappings.
  - `attempts`, `durationMs` (`int`): Exec cycle diagnostics.
  - `success` (`bool`): Execution validity.
  - `toolCalls`, `turnsUsed` (`int`): Computed run properties.
  - `errorMessage` (`String`): Fetched exception data string.
- **Constructors**:
  - `GeminiResult({required String taskId, String? response, Map<String, dynamic>? stats, Map<String, dynamic>? error, int attempts = 1, int durationMs = 0, required bool success})`
- **Example**:
  ```dart
  import 'package:runtime_ci_tooling/src/triage/utils/gemini_runner.dart';

  final result = GeminiResult(
    taskId: 'task-1',
    response: '{"status": "ok"}',
    stats: {'tools': {'totalCalls': 2}},
    success: true,
    attempts: 1,
    durationMs: 1500,
  );
  ```

### `GeminiTask`
Representation mapping of individual agent job inputs for batch dispatch.
- **Fields**:
  - `id`, `prompt`, `model` (`String`): Fundamental text identifiers/inputs.
  - `maxTurns` (`int`): Interaction allowance.
  - `allowedTools`, `fileIncludes` (`List<String>`): Sandboxed inclusions/entitlements.
  - `workingDirectory`, `auditDir` (`String?`): Path boundaries.
  - `sandbox` (`bool`): Strict system toggle.
- **Constructors**:
  - `GeminiTask({required String id, required String prompt, String model = kDefaultFlashModel, int maxTurns = kDefaultMaxTurns, List<String> allowedTools = const ["run_shell_command(git)", "run_shell_command(gh)"], List<String> fileIncludes = const [], String? workingDirectory, bool sandbox = false, String? auditDir})`
- **Example**:
  ```dart
  import 'package:runtime_ci_tooling/src/triage/utils/gemini_runner.dart';

  final task = GeminiTask(
    id: 'issue-42-code',
    prompt: 'Analyze this issue...',
    model: 'gemini-3.1-pro-preview',
    maxTurns: 50,
    allowedTools: ['run_shell_command(git)'],
  );
  ```

### `GeminiRunner`
Manages parallel Gemini CLI execution with retries and load-balancing parameters.
- **Fields**:
  - `maxConcurrent`, `maxRetries` (`int`): Parallel pool limiters.
  - `initialBackoff`, `maxBackoff` (`Duration`): Stalling thresholds.
  - `verbose` (`bool`): Diagnostic stream flag.
- **Methods**:
  - `executeBatch(List<GeminiTask> tasks)` -> `Future<List<GeminiResult>>`: Executes a batch of tasks sequentially matching the configured scaling allowances.
- **Constructors**:
  - `GeminiRunner({int maxConcurrent = kDefaultMaxConcurrent, int maxRetries = kDefaultMaxRetries, Duration initialBackoff = kDefaultInitialBackoff, Duration maxBackoff = kDefaultMaxBackoff, bool verbose = false})`
- **Example**:
  ```dart
  import 'package:runtime_ci_tooling/src/triage/utils/gemini_runner.dart';

  final runner = GeminiRunner(
    maxConcurrent: 2,
    maxRetries: 3,
    verbose: true,
  );
  // final results = await runner.executeBatch([task1, task2]);
  ```

### `VerificationCheck`
Encapsulates individual verification node testing parameters and outcomes.
- **Fields**:
  - `name` (`String`): Identification string matching the rule validated.
  - `passed` (`bool`): Logic resolution.
  - `message` (`String`): Contextual info resulting from resolution.
- **Methods**:
  - `toJson()`: Outputs internal JSON map instance.
- **Constructors**:
  - `VerificationCheck({required String name, required bool passed, required String message})`
- **Example**:
  ```dart
  import 'package:runtime_ci_tooling/src/triage/phases/verify.dart';

  final check = VerificationCheck(
    name: 'label_needs-investigation',
    passed: true,
    message: 'Label "needs-investigation" applied',
  );
  ```

### `IssueVerification`
Groups verification sequences applied per individual issue number.
- **Fields**:
  - `issueNumber` (`int`): Linked issue identifier.
  - `passed` (`bool`): Master aggregation indicator for children checks.
  - `checks` (`List<VerificationCheck>`): Node sequences validated.
- **Methods**:
  - `toJson()`: Outputs internal JSON map instance.
- **Constructors**:
  - `IssueVerification({required int issueNumber, required bool passed, required List<VerificationCheck> checks})`
- **Example**:
  ```dart
  import 'package:runtime_ci_tooling/src/triage/phases/verify.dart';

  final verification = IssueVerification(
    issueNumber: 42,
    passed: true,
    checks: [
      VerificationCheck(name: 'state_closed', passed: true, message: 'Issue correctly closed')
    ],
  );
  ```

### `VerificationReport`
Wrapper class encapsulating a verification pass structure.
- **Fields**:
  - `verifications` (`List<IssueVerification>`): Output check groups mappings.
  - `timestamp` (`DateTime`): Process time mapping point.
  - `allPassed` (`bool`): Master flag computed checking nested evaluations.
- **Methods**:
  - `toJson()`: Outputs internal JSON map instance.
- **Constructors**:
  - `VerificationReport({required List<IssueVerification> verifications, required DateTime timestamp})`
- **Example**:
  ```dart
  import 'package:runtime_ci_tooling/src/triage/phases/verify.dart';

  final report = VerificationReport(
    verifications: [],
    timestamp: DateTime.now(),
  );
  ```

## 2. Enums

### `TaskStatus`
Represents the status state progression of an active triage task.
- `pending`: Awaiting processor block.
- `running`: Currently in an active resolution phase.
- `completed`: Task validated and evaluated fully.
- `failed`: Task aborted or exception encountered internally.
- `skipped`: Task omitted programmatically.

### `AgentType`
Categorical mappings representing specific AI triage specializations.
- `codeAnalysis`: Analyzes codebase patches relative to issues.
- `prCorrelation`: Targets issue relations referencing available Pull Requests.
- `duplicate`: Cross-references duplicate reports mapping identical symptoms.
- `sentiment`: Targets user intention patterns parsing comment dialogue sequences.
- `changelog`: Evaluates documented completion inside version/changelog metrics.

### `RiskLevel`
Classifies execution severity impacts derived mechanically from agent confidence points.
- `low`: Confidence under comment/close limits. Defaults to simple labels.
- `medium`: Matches mid-tier limit parameters. Action is bounded strictly to suggestions.
- `high`: Overwhelming validation points resulting in active/hard state closing impacts.

### `ActionType`
Discrete physical mechanisms permitted programmatically mapping over targeted GitHub instances.
- `label`: Adjusts applied GH taxonomy values.
- `comment`: Appends GH discussions explicitly.
- `close`: Forces GH standard resolution triggers.
- `linkPr`: Commits specific linkage back mapping PR sources natively.
- `linkIssue`: Commits cross-issue linking paths implicitly.
- `none`: Nullifier indicator preventing operational consequences.


## 3. Extensions

*(No public extensions defined in the provided source code)*


## 4. Top-Level Functions

### `kCloseThreshold`
`double get kCloseThreshold`
- **Description**: Returns the `config.autoCloseThreshold` value dynamically.
- **Parameters**: None.
- **Returns**: `double`

### `kSuggestCloseThreshold`
`double get kSuggestCloseThreshold`
- **Description**: Returns the `config.suggestCloseThreshold` value dynamically.
- **Parameters**: None.
- **Returns**: `double`

### `kCommentThreshold`
`double get kCommentThreshold`
- **Description**: Returns the `config.commentThreshold` value dynamically.
- **Parameters**: None.
- **Returns**: `double`

### `config`
`TriageConfig get config`
- **Description**: Gets the singleton `TriageConfig` instance. Loads from disk on first access.
- **Parameters**: None.
- **Returns**: `TriageConfig`

### `reloadConfig`
`void reloadConfig()`
- **Description**: Reloads configuration mappings from disk.
- **Parameters**: None.
- **Returns**: `void`

### `validateJsonFile`
`ValidationResult validateJsonFile(String path, List<String> requiredKeys)`
- **Description**: Validates that a JSON file exists, is valid JSON, and contains required keys.
- **Parameters**: 
  - `path` (`String`)
  - `requiredKeys` (`List<String>`)
- **Returns**: `ValidationResult`

### `validateGamePlan`
`ValidationResult validateGamePlan(String path)`
- **Description**: Validates a game plan JSON structure against base schema checks.
- **Parameters**: 
  - `path` (`String`)
- **Returns**: `ValidationResult`

### `validateInvestigationResult`
`ValidationResult validateInvestigationResult(String path)`
- **Description**: Validates an investigation result JSON mapping against specific schema keys.
- **Parameters**: 
  - `path` (`String`)
- **Returns**: `ValidationResult`

### `writeJson`
`void writeJson(String path, Map<String, dynamic> data)`
- **Description**: Writes a JSON object mapping to a file with pretty formatting.
- **Parameters**: 
  - `path` (`String`)
  - `data` (`Map<String, dynamic>`)
- **Returns**: `void`

### `readJson`
`Map<String, dynamic>? readJson(String path)`
- **Description**: Reads and parses a specified JSON file safely.
- **Parameters**: 
  - `path` (`String`)
- **Returns**: `Map<String, dynamic>?`

### `buildGitHubMcpConfig`
`Map<String, dynamic> buildGitHubMcpConfig({String? token})`
- **Description**: Builds the GitHub MCP server configuration bindings for `.gemini/settings.json`.
- **Parameters**: 
  - `token` (`String?`)
- **Returns**: `Map<String, dynamic>`

### `buildSentryMcpConfig`
`Map<String, dynamic> buildSentryMcpConfig()`
- **Description**: Builds the Sentry MCP server configuration object.
- **Parameters**: None.
- **Returns**: `Map<String, dynamic>`

### `readSettings`
`Map<String, dynamic> readSettings(String repoRoot)`
- **Description**: Reads the current runtime/Gemini settings mapping configurations.
- **Parameters**: 
  - `repoRoot` (`String`)
- **Returns**: `Map<String, dynamic>`

### `writeSettings`
`void writeSettings(String repoRoot, Map<String, dynamic> settings)`
- **Description**: Writes updated configurations mapping back physically.
- **Parameters**: 
  - `repoRoot` (`String`)
  - `settings` (`Map<String, dynamic>`)
- **Returns**: `void`

### `ensureMcpConfigured`
`bool ensureMcpConfigured(String repoRoot)`
- **Description**: Ensures the necessary MCP server environments map correctly into active definitions.
- **Parameters**: 
  - `repoRoot` (`String`)
- **Returns**: `bool`

### `validateMcpServers`
`Future<Map<String, bool>> validateMcpServers(String repoRoot)`
- **Description**: Validates that required external MCP server dependencies map dynamically safely and exist natively.
- **Parameters**: 
  - `repoRoot` (`String`)
- **Returns**: `Future<Map<String, bool>>`

### `act`
`Future<List<TriageDecision>> act(GamePlan plan, Map<int, List<InvestigationResult>> investigationResults, String repoRoot, {required String runDir})`
- **Description**: Phase 3 execution processing engine. Enforces safe-actuating idempotency guards to trigger actionable consequences via gh commands.
- **Parameters**: 
  - `plan` (`GamePlan`)
  - `investigationResults` (`Map<int, List<InvestigationResult>>`)
  - `repoRoot` (`String`)
  - `runDir` (`String` - Named/Required)
- **Returns**: `Future<List<TriageDecision>>`

### `crossRepoLink`
`Future<void> crossRepoLink(GamePlan plan, List<TriageDecision> decisions, String repoRoot, {required String runDir})`
- **Description**: Phase 5b engine searching contextual cross-reference mappings across bound repository trees matching title metrics.
- **Parameters**: 
  - `plan` (`GamePlan`)
  - `decisions` (`List<TriageDecision>`)
  - `repoRoot` (`String`)
  - `runDir` (`String` - Named/Required)
- **Returns**: `Future<void>`

### `investigate`
`Future<Map<int, List<InvestigationResult>>> investigate(GamePlan plan, String repoRoot, {required String runDir, bool verbose = false})`
- **Description**: Phase 2 core engine dispatching dynamic investigation AI task bindings over Gemini processes scaling concurrently.
- **Parameters**: 
  - `plan` (`GamePlan`)
  - `repoRoot` (`String`)
  - `runDir` (`String` - Named/Required)
  - `verbose` (`bool` - Named/Optional)
- **Returns**: `Future<Map<int, List<InvestigationResult>>>`

### `link`
`Future<void> link(GamePlan plan, List<TriageDecision> decisions, String repoRoot, {required String runDir})`
- **Description**: Phase 5 processing logic managing hard associations inside the source repository (binding code bases to PR, issues and notes).
- **Parameters**: 
  - `plan` (`GamePlan`)
  - `decisions` (`List<TriageDecision>`)
  - `repoRoot` (`String`)
  - `runDir` (`String` - Named/Required)
- **Returns**: `Future<void>`

### `planSingleIssue`
`Future<GamePlan> planSingleIssue(int issueNumber, String repoRoot, {required String runDir})`
- **Description**: Phase 1 specific issue engine constructor returning the raw task mappings.
- **Parameters**: 
  - `issueNumber` (`int`)
  - `repoRoot` (`String`)
  - `runDir` (`String` - Named/Required)
- **Returns**: `Future<GamePlan>`

### `planAutoTriage`
`Future<GamePlan> planAutoTriage(String repoRoot, {required String runDir})`
- **Description**: Phase 1 expansive constructor spanning untriaged/missing-label GH collections returning the broad master plan.
- **Parameters**: 
  - `repoRoot` (`String`)
  - `runDir` (`String` - Named/Required)
- **Returns**: `Future<GamePlan>`

### `loadPlan`
`GamePlan? loadPlan({String? runDir})`
- **Description**: Ingests contextual JSON data from disk converting back into mapped structured class constraints.
- **Parameters**: 
  - `runDir` (`String?` - Named/Optional)
- **Returns**: `GamePlan?`

### `postReleaseTriage`
`Future<void> postReleaseTriage({required String newVersion, required String releaseTag, required String releaseUrl, required String manifestPath, required String repoRoot, required String runDir, bool verbose = false})`
- **Description**: Operational dispatch handling end-of-lifecycle state updates. Closes confidence-verified nodes dynamically and generates linked_issues associations.
- **Parameters**: 
  - `newVersion`, `releaseTag`, `releaseUrl`, `manifestPath`, `repoRoot`, `runDir` (`String` - Named/Required)
  - `verbose` (`bool` - Named/Optional)
- **Returns**: `Future<void>`

### `preReleaseTriage`
`Future<String> preReleaseTriage({required String prevTag, required String newVersion, required String repoRoot, required String runDir, bool verbose = false})`
- **Description**: Diff validation runner identifying contextual links correlating Sentry metrics and GitHub references before producing validation bounds internally. 
- **Parameters**: 
  - `prevTag`, `newVersion`, `repoRoot`, `runDir` (`String` - Named/Required)
  - `verbose` (`bool` - Named/Optional)
- **Returns**: `Future<String>`

### `verify`
`Future<VerificationReport> verify(GamePlan plan, List<TriageDecision> decisions, String repoRoot, {required String runDir})`
- **Description**: Phase 4 runtime guard validating GH execution mappings via direct state re-reads enforcing idempotency integrity checking structurally.
- **Parameters**: 
  - `plan` (`GamePlan`)
  - `decisions` (`List<TriageDecision>`)
  - `repoRoot` (`String`)
  - `runDir` (`String` - Named/Required)
- **Returns**: `Future<VerificationReport>`

### `buildTask` (Agents)
`GeminiTask buildTask(IssuePlan issue, String repoRoot, {String? resultsDir})`
- **Description**: Generates the contextually distinct `GeminiTask` mapping containing prompt constraints targeted locally per agent type. (Available inside `code_analysis_agent.dart`, `pr_correlation_agent.dart`, `duplicate_agent.dart`, `sentiment_agent.dart`, `changelog_agent.dart`).
- **Parameters**: 
  - `issue` (`IssuePlan`)
  - `repoRoot` (`String`)
  - `resultsDir` (`String?` - Named/Optional)
- **Returns**: `GeminiTask`
