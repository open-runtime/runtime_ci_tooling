// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import '../agents/code_analysis_agent.dart' as code_agent;
import '../agents/pr_correlation_agent.dart' as pr_agent;
import '../agents/duplicate_agent.dart' as dupe_agent;
import '../agents/sentiment_agent.dart' as sentiment_agent;
import '../agents/changelog_agent.dart' as changelog_agent;
import '../models/game_plan.dart';
import '../models/investigation_result.dart';
import '../utils/config.dart';
import '../utils/gemini_runner.dart';
import '../utils/json_schemas.dart';

/// Phase 2: INVESTIGATE
///
/// Dispatches investigation agents in parallel via GeminiRunner.executeBatch.
/// Writes results to run-scoped directories.
///
/// Idempotency: skips tasks that are already completed from a previous run.
/// Conditional: only runs agents that are enabled in triage_config.json.

// ═══════════════════════════════════════════════════════════════════════════════
// Public API
// ═══════════════════════════════════════════════════════════════════════════════

/// Run investigation agents for every issue in the game plan.
Future<Map<int, List<InvestigationResult>>> investigate(
  GamePlan plan,
  String repoRoot, {
  required String runDir,
  bool verbose = false,
}) async {
  final resultsDir = '$runDir/results';
  Directory(resultsDir).createSync(recursive: true);

  // Count enabled agents per issue
  final enabledAgents = config.enabledAgents;
  final agentsPerIssue = enabledAgents.length;

  print(
    'Phase 2 [INVESTIGATE]: Running ${plan.issues.length} issue(s) '
    'x $agentsPerIssue agents = ${plan.issues.length * agentsPerIssue} tasks',
  );

  // Build tasks, skipping already-completed ones
  final allTasks = <GeminiTask>[];
  final taskIssueMap = <String, int>{};
  var skippedCount = 0;

  for (final issue in plan.issues) {
    final tasks = _buildTasksForIssue(issue, repoRoot, resultsDir);
    for (final task in tasks) {
      // Skip if already completed from a previous run (resume support)
      final matchingPlanTask = issue.tasks.where((t) => t.id == task.id).firstOrNull;
      if (matchingPlanTask?.status == TaskStatus.completed) {
        skippedCount++;
        continue;
      }

      allTasks.add(task);
      taskIssueMap[task.id] = issue.number;
      matchingPlanTask?.status = TaskStatus.running;
    }
  }

  if (skippedCount > 0) {
    print('  Skipped $skippedCount already-completed tasks (resume mode)');
  }

  if (allTasks.isEmpty) {
    print('  All tasks already completed. Loading cached results.');
    return _loadAllResults(plan, resultsDir);
  }

  // Execute tasks in parallel
  final runner = GeminiRunner(maxConcurrent: config.maxConcurrent, maxRetries: config.maxRetries, verbose: verbose);

  print('  Dispatching ${allTasks.length} agent tasks (max ${config.maxConcurrent} concurrent)...');
  final geminiResults = await runner.executeBatch(allTasks);

  // Process results
  final results = <int, List<InvestigationResult>>{};

  for (var i = 0; i < allTasks.length; i++) {
    final task = allTasks[i];
    final geminiResult = geminiResults[i];
    final issueNumber = taskIssueMap[task.id]!;

    results.putIfAbsent(issueNumber, () => []);

    final resultFile = '$resultsDir/${task.id}.json';
    final investigationResult = _readAgentResult(resultFile, task.id, issueNumber, geminiResult);
    results[issueNumber]!.add(investigationResult);

    // Update task in game plan
    final issuePlan = plan.issues.firstWhere((i) => i.number == issueNumber, orElse: () => plan.issues.first);
    final taskPlan = issuePlan.tasks.firstWhere((t) => t.id == task.id, orElse: () => issuePlan.tasks.first);
    taskPlan.status = geminiResult.success ? TaskStatus.completed : TaskStatus.failed;
    taskPlan.error = geminiResult.success ? null : geminiResult.errorMessage;
    taskPlan.result = investigationResult.toJson();
  }

  // Merge in any cached results from resumed tasks
  for (final issue in plan.issues) {
    results.putIfAbsent(issue.number, () => []);
    for (final task in issue.tasks) {
      if (task.status == TaskStatus.completed && task.result != null) {
        // Only add if not already in results from this run
        final alreadyPresent = results[issue.number]!.any((r) => r.agentId == task.result!['agent_id']);
        if (!alreadyPresent) {
          results[issue.number]!.add(InvestigationResult.fromJson(task.result!));
        }
      }
    }
  }

  // Save updated game plan
  writeJson('$runDir/triage_game_plan.json', plan.toJson());

  // Print summary
  for (final entry in results.entries) {
    final issueResults = entry.value;
    final avgConf = issueResults.isEmpty
        ? 0.0
        : issueResults.map((r) => r.confidence).reduce((a, b) => a + b) / issueResults.length;
    print(
      '  Issue #${entry.key}: ${issueResults.length} results, '
      'avg confidence: ${(avgConf * 100).toStringAsFixed(0)}%',
    );
  }

  return results;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Internal
// ═══════════════════════════════════════════════════════════════════════════════

/// Build agent tasks for a single issue, respecting enabled agents and conditions.
List<GeminiTask> _buildTasksForIssue(IssuePlan issue, String repoRoot, String resultsDir) {
  final tasks = <GeminiTask>[];

  if (config.shouldRunAgent('code_analysis', repoRoot)) {
    tasks.add(code_agent.buildTask(issue, repoRoot));
  }
  if (config.shouldRunAgent('pr_correlation', repoRoot)) {
    tasks.add(pr_agent.buildTask(issue, repoRoot));
  }
  if (config.shouldRunAgent('duplicate', repoRoot)) {
    tasks.add(dupe_agent.buildTask(issue, repoRoot));
  }
  if (config.shouldRunAgent('sentiment', repoRoot)) {
    tasks.add(sentiment_agent.buildTask(issue, repoRoot));
  }
  if (config.shouldRunAgent('changelog', repoRoot)) {
    tasks.add(changelog_agent.buildTask(issue, repoRoot));
  }

  return tasks;
}

/// Load all cached results from a run directory (for resume).
Map<int, List<InvestigationResult>> _loadAllResults(GamePlan plan, String resultsDir) {
  final results = <int, List<InvestigationResult>>{};
  for (final issue in plan.issues) {
    results[issue.number] = [];
    for (final task in issue.tasks) {
      if (task.result != null) {
        results[issue.number]!.add(InvestigationResult.fromJson(task.result!));
      }
    }
  }
  return results;
}

/// Read an agent's result file, falling back to Gemini response parsing.
InvestigationResult _readAgentResult(String filePath, String taskId, int issueNumber, GeminiResult geminiResult) {
  // Try reading the file the agent was instructed to write
  if (File(filePath).existsSync()) {
    try {
      final data = json.decode(File(filePath).readAsStringSync()) as Map<String, dynamic>;
      final result = InvestigationResult.fromJson(data);
      return InvestigationResult(
        agentId: result.agentId,
        issueNumber: result.issueNumber,
        confidence: result.confidence,
        summary: result.summary,
        evidence: result.evidence,
        recommendedLabels: result.recommendedLabels,
        suggestedComment: result.suggestedComment,
        suggestClose: result.suggestClose,
        closeReason: result.closeReason,
        relatedEntities: result.relatedEntities,
        turnsUsed: geminiResult.turnsUsed,
        toolCallsMade: geminiResult.toolCalls,
        durationMs: geminiResult.durationMs,
      );
    } catch (e) {
      print('  Warning: Could not parse $filePath: $e');
    }
  }

  // Fallback: try to extract JSON from Gemini response text
  if (geminiResult.response != null) {
    try {
      final responseText = geminiResult.response!;
      final jsonMatch = RegExp(r'\{[\s\S]*"agent_id"[\s\S]*\}').firstMatch(responseText);
      if (jsonMatch != null) {
        final data = json.decode(jsonMatch.group(0)!) as Map<String, dynamic>;
        return InvestigationResult.fromJson(data);
      }
    } catch (_) {}
  }

  return InvestigationResult.failed(
    agentId: taskId,
    issueNumber: issueNumber,
    error: geminiResult.success ? 'No result file written' : geminiResult.errorMessage,
  );
}
