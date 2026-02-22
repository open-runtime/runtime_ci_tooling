# Issue Triage Engine API Reference

## 1. Classes

### CrossRepoEntry
Represents a configured cross-repository entry.
- **Fields**:
  - `String owner`
  - `String repo`
  - `String relationship`
  - `String fullName`

**Example:**
```dart
import 'package:runtime_ci_tooling/src/triage/utils/config.dart';

final entry = CrossRepoEntry(
  owner: 'google',
  repo: 'dart',
  relationship: 'dependency',
);
print(entry.fullName); // google/dart
```

### GamePlan
The top-level game plan that orchestrates the entire triage pipeline.
- **Fields**:
  - `String planId`
  - `DateTime createdAt`
  - `List<IssuePlan> issues`
  - `List<LinkSpec> linksToCreate`
- **Methods**:
  - `Map<String, dynamic> toJson()` -- Serializes to JSON.
  - `String toJsonString()` -- Serializes to formatted JSON string.
- **Constructors**:
  - `factory GamePlan.fromJson(Map<String, dynamic> json)`
  - `factory GamePlan.forIssues(List<Map<String, dynamic>> issueData)`

**Example:**
```dart
import 'package:runtime_ci_tooling/src/triage/models/game_plan.dart';

final plan = GamePlan.forIssues([
  {
    'number': 123,
    'title': 'Bug in parser',
    'author': 'johndoe',
    'labels': ['bug'],
  }
]);

// You can modify the plan using cascades:
plan..linksToCreate.add(LinkSpec(
  sourceType: 'issue',
  sourceId: '123',
  targetType: 'pr',
  targetId: '456',
  description: 'Fixes parser bug',
));

print(plan.toJsonString());
```

### GeminiResult
The structured result from a Gemini CLI invocation.
- **Fields**:
  - `String taskId`
  - `String? response`
  - `Map<String, dynamic>? stats`
  - `Map<String, dynamic>? error`
  - `int attempts`
  - `int durationMs`
  - `bool success`
  - `int toolCalls`
  - `int turnsUsed`
  - `String errorMessage`

### GeminiRunner
Manages parallel Gemini CLI execution with retry and rate limiting.
- **Fields**:
  - `int maxConcurrent`
  - `int maxRetries`
  - `Duration initialBackoff`
  - `Duration maxBackoff`
  - `bool verbose`
- **Methods**:
  - `Future<List<GeminiResult>> executeBatch(List<GeminiTask> tasks)` -- Execute a batch of tasks in parallel with concurrency limiting.

### GeminiTask
A single task to execute via Gemini CLI.
- **Fields**:
  - `String id`
  - `String prompt`
  - `String model`
  - `int maxTurns`
  - `List<String> allowedTools`
  - `List<String> fileIncludes`
  - `String? workingDirectory`
  - `bool sandbox`
  - `String? auditDir`

### InvestigationResult
Data class for investigation agent results.
- **Fields**:
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
- **Methods**:
  - `Map<String, dynamic> toJson()`
- **Constructors**:
  - `factory InvestigationResult.fromJson(Map<String, dynamic> json)`
  - `factory InvestigationResult.failed({required String agentId, required int issueNumber, required String error})`

**Example:**
```dart
import 'package:runtime_ci_tooling/src/triage/models/investigation_result.dart';

final result = InvestigationResult(
  agentId: 'code_analysis',
  issueNumber: 42,
  confidence: 0.95,
  summary: 'Issue is fixed in recent commit.',
  suggestClose: true,
  closeReason: 'completed',
)..evidence.add('Found fix in commit 1234abc')
 ..recommendedLabels.add('fixed');
```

### IssuePlan
The triage plan for a single GitHub issue.
- **Fields**:
  - `int number`
  - `String title`
  - `String author`
  - `List<String> existingLabels`
  - `List<TriageTask> tasks`
  - `Map<String, dynamic>? decision`
  - `bool investigationComplete`
- **Methods**:
  - `Map<String, dynamic> toJson()`
- **Constructors**:
  - `factory IssuePlan.fromJson(Map<String, dynamic> json)`

### IssueVerification
Verification status of a specific issue.
- **Fields**:
  - `int issueNumber`
  - `bool passed`
  - `List<VerificationCheck> checks`
- **Methods**:
  - `Map<String, dynamic> toJson()`

### LinkSpec
A link to create between two entities (issue, PR, changelog, release notes).
- **Fields**:
  - `String sourceType`
  - `String sourceId`
  - `String targetType`
  - `String targetId`
  - `String description`
  - `bool applied`
- **Methods**:
  - `Map<String, dynamic> toJson()`
- **Constructors**:
  - `factory LinkSpec.fromJson(Map<String, dynamic> json)`

### RelatedEntity
A reference to a related entity (PR, issue, commit, file) found during investigation.
- **Fields**:
  - `String type`
  - `String id`
  - `String description`
  - `double relevance`
- **Methods**:
  - `Map<String, dynamic> toJson()`
- **Constructors**:
  - `factory RelatedEntity.fromJson(Map<String, dynamic> json)`

### RunContext
Manages a run-scoped audit trail directory for CI/CD operations.
- **Fields**:
  - `String repoRoot`
  - `String runDir`
  - `String command`
  - `DateTime startedAt`
  - `List<String> args`
  - `String runId`
- **Methods**:
  - `String subdir(String name)` -- Get or create a subdirectory within the run directory.
  - `void savePrompt(String phase, String prompt)` -- Save a prompt sent to Gemini CLI.
  - `void saveResponse(String phase, String rawResponse)` -- Save the response from Gemini CLI.
  - `void saveArtifact(String phase, String filename, String content)` -- Save a structured artifact.
  - `void saveJsonArtifact(String phase, String filename, Map<String, dynamic> data)` -- Save a JSON artifact.
  - `String artifactPath(String phase, String filename)` -- Get the path for an artifact file.
  - `String? readArtifact(String phase, String filename)` -- Read an artifact file.
  - `bool hasArtifact(String phase, String filename)` -- Check if an artifact exists.
  - `void finalize({int? exitCode})` -- Update the meta.json with completion info.
  - `void archiveForRelease(String version)` -- Archive important artifacts to cicd_audit for permanent storage.
  - `static String? findLatestRun(String repoRoot, {String? command})` -- Find the most recent run directory for a given command.
  - `static List<Directory> listRuns(String repoRoot)` -- List all run directories.
- **Constructors**:
  - `factory RunContext.create(String repoRoot, String command, {List<String> args = const []})`
  - `factory RunContext.load(String repoRoot, String runDirPath)`

### TriageAction
A concrete action to take on a GitHub issue.
- **Fields**:
  - `ActionType type`
  - `String description`
  - `Map<String, dynamic> parameters`
  - `bool executed`
  - `bool verified`
  - `String? error`
- **Methods**:
  - `Map<String, dynamic> toJson()`
- **Constructors**:
  - `factory TriageAction.fromJson(Map<String, dynamic> json)`

### TriageConfig
Centralized, config-driven loader for the runtime CI tooling pipeline.
- **Fields**:
  - `String? loadedFrom`
  - `bool isConfigured`
  - `String repoName`
  - `String repoOwner`
  - `String triagedLabel`
  - `String changelogPath`
  - `String releaseNotesPath`
  - `String gcpProject`
  - `String sentryOrganization`
  - `List<String> sentryProjects`
  - `bool sentryScanOnPreRelease`
  - `int sentryRecentErrorsHours`
  - `bool preReleaseScanSentry`
  - `bool preReleaseScanGithub`
  - `bool postReleaseCloseOwnRepo`
  - `bool postReleaseCloseCrossRepo`
  - `bool postReleaseCommentCrossRepo`
  - `bool postReleaseLinkSentry`
  - `bool crossRepoEnabled`
  - `List<CrossRepoEntry> crossRepoRepos`
  - `List<String> typeLabels`
  - `List<String> priorityLabels`
  - `List<String> areaLabels`
  - `double autoCloseThreshold`
  - `double suggestCloseThreshold`
  - `double commentThreshold`
  - `List<String> enabledAgents`
  - `String flashModel`
  - `String proModel`
  - `int maxTurns`
  - `int maxConcurrent`
  - `int maxRetries`
  - `String geminiApiKeyEnv`
  - `List<String> githubTokenEnvNames`
  - `String gcpSecretName`
- **Methods**:
  - `bool shouldRunAgent(String agentName, String repoRoot)` -- Check if a conditional agent should run.
  - `String? resolveGeminiApiKey()` -- Resolve the Gemini API key from env vars or GCP Secret Manager.
  - `String? resolveGithubToken()` -- Resolve a GitHub token from any of the configured env var names.
- **Constructors**:
  - `factory TriageConfig.load()`

### TriageDecision
The aggregated triage decision for a single issue.
- **Fields**:
  - `int issueNumber`
  - `double aggregateConfidence`
  - `RiskLevel riskLevel`
  - `String rationale`
  - `List<TriageAction> actions`
  - `List<InvestigationResult> investigationResults`
- **Methods**:
  - `Map<String, dynamic> toJson()`
- **Constructors**:
  - `factory TriageDecision.fromJson(Map<String, dynamic> json)`
  - `factory TriageDecision.fromResults({required int issueNumber, required List<InvestigationResult> results})`

### TriageTask
A single investigation or action task within the game plan.
- **Fields**:
  - `String id`
  - `AgentType agent`
  - `TaskStatus status`
  - `String? error`
  - `Map<String, dynamic>? result`
- **Methods**:
  - `Map<String, dynamic> toJson()`
- **Constructors**:
  - `factory TriageTask.fromJson(Map<String, dynamic> json)`

### ValidationResult
JSON validation result.
- **Fields**:
  - `bool valid`
  - `String path`
  - `List<String> errors`

### VerificationCheck
Represents a single verification check.
- **Fields**:
  - `String name`
  - `bool passed`
  - `String message`
- **Methods**:
  - `Map<String, dynamic> toJson()`

### VerificationReport
Report containing all verifications.
- **Fields**:
  - `List<IssueVerification> verifications`
  - `DateTime timestamp`
  - `bool allPassed`
- **Methods**:
  - `Map<String, dynamic> toJson()`

## 2. Enums

### ActionType
A concrete action to take on a GitHub issue.
- `label`: Add labels to an issue.
- `comment`: Post a comment on an issue.
- `close`: Close an issue.
- `linkPr`: Link issue to a pull request.
- `linkIssue`: Link issue to another issue.
- `none`: Take no action.


### AgentType
The specific agent assigned to an investigation task.
- `codeAnalysis`: Investigates source code.
- `prCorrelation`: Finds pull requests.
- `duplicate`: Detects duplicate issues.
- `sentiment`: Analyzes discussion thread sentiment.
- `changelog`: Checks for references in changelogs.


### RiskLevel
Estimated risk level for an issue action based on confidence score.
- `low`: Low risk.
- `medium`: Medium risk.
- `high`: High risk.

### TaskStatus
Execution state of a single investigation or action task.
- `pending`: Task is pending execution.
- `running`: Task is currently executing.
- `completed`: Task successfully finished.
- `failed`: Task failed with an error.
- `skipped`: Task execution was skipped.

## 3. Top-Level Functions

- **`get kCloseThreshold`** -- `double get kCloseThreshold`
  Confidence threshold for auto-closing issues.

- **`get kSuggestCloseThreshold`** -- `double get kSuggestCloseThreshold`
  Confidence threshold for suggesting to close issues.

- **`get kCommentThreshold`** -- `double get kCommentThreshold`
  Confidence threshold for leaving a comment.

- **`get config`** -- `TriageConfig get config`
  Gets the singleton config instance. Loads from disk on first access.

- **`reloadConfig`** -- `void reloadConfig()`
  Reloads config from disk (useful after modifications).

- **`validateJsonFile`** -- `ValidationResult validateJsonFile(String path, List<String> requiredKeys)`
  Validates that a JSON file exists, is valid JSON, and contains required keys.

- **`validateGamePlan`** -- `ValidationResult validateGamePlan(String path)`
  Validates a game plan JSON structure.

- **`validateInvestigationResult`** -- `ValidationResult validateInvestigationResult(String path)`
  Validates an investigation result JSON structure.

- **`writeJson`** -- `void writeJson(String path, Map<String, dynamic> data)`
  Writes a JSON object to a file with pretty formatting.

- **`readJson`** -- `Map<String, dynamic>? readJson(String path)`
  Reads and parses a JSON file, returning null on error.

- **`buildGitHubMcpConfig`** -- `Map<String, dynamic> buildGitHubMcpConfig({String? token})`
  Builds the GitHub MCP server configuration for `.gemini/settings.json`.

- **`buildSentryMcpConfig`** -- `Map<String, dynamic> buildSentryMcpConfig()`
  Builds the Sentry MCP server configuration.

- **`readSettings`** -- `Map<String, dynamic> readSettings(String repoRoot)`
  Reads the current `.gemini/settings.json` file.

- **`writeSettings`** -- `void writeSettings(String repoRoot, Map<String, dynamic> settings)`
  Writes updated settings to `.gemini/settings.json`.

- **`ensureMcpConfigured`** -- `bool ensureMcpConfigured(String repoRoot)`
  Ensures MCP servers are configured in `.gemini/settings.json`. Returns true if configuration was updated.

- **`validateMcpServers`** -- `Future<Map<String, bool>> validateMcpServers(String repoRoot)`
  Validates that required MCP servers are configured and accessible.

- **`buildTask`** -- `GeminiTask buildTask(IssuePlan issue, String repoRoot)`
  Builds a Gemini task for agent investigation (implemented by specific agents like code_analysis, duplicate, pr_correlation, sentiment, changelog).

- **`act`** -- `Future<List<TriageDecision>> act(GamePlan plan, Map<int, List<InvestigationResult>> investigationResults, String repoRoot, {required String runDir})`
  Apply triage decisions for all issues in the game plan.

- **`crossRepoLink`** -- `Future<void> crossRepoLink(GamePlan plan, List<TriageDecision> decisions, String repoRoot, {required String runDir})`
  Search and link related issues across configured dependent repos.

- **`investigate`** -- `Future<Map<int, List<InvestigationResult>>> investigate(GamePlan plan, String repoRoot, {required String runDir, bool verbose = false})`
  Run investigation agents for every issue in the game plan in parallel.

- **`link`** -- `Future<void> link(GamePlan plan, List<TriageDecision> decisions, String repoRoot, {required String runDir})`
  Cross-link all triaged issues to related artifacts.

- **`planSingleIssue`** -- `Future<GamePlan> planSingleIssue(int issueNumber, String repoRoot, {required String runDir})`
  Creates a game plan for a single issue.

- **`planAutoTriage`** -- `Future<GamePlan> planAutoTriage(String repoRoot, {required String runDir})`
  Creates a game plan for all open untriaged issues (auto mode).

- **`loadPlan`** -- `GamePlan? loadPlan({ String? runDir })`
  Loads an existing game plan from a run directory.

- **`postReleaseTriage`** -- `Future<void> postReleaseTriage({required String newVersion, required String releaseTag, required String releaseUrl, required String manifestPath, required String repoRoot, required String runDir, bool verbose = false})`
  Run post-release actions based on the pre-release issue manifest.

- **`preReleaseTriage`** -- `Future<String> preReleaseTriage({required String prevTag, required String newVersion, required String repoRoot, required String runDir, bool verbose = false})`
  Scan issues and produce an issue manifest for the upcoming release.

- **`verify`** -- `Future<VerificationReport> verify(GamePlan plan, List<TriageDecision> decisions, String repoRoot, {required String runDir})`
  Verify that all triage actions were applied correctly.
