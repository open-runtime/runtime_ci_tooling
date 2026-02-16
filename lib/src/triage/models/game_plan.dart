// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io' show pid;

/// Data classes for the triage game plan.
///
/// The game plan is a JSON structure produced by Phase 1 (Plan) that controls
/// all subsequent phases. It specifies which issues to triage, which agents
/// to run, and tracks task status throughout the pipeline.

// ═══════════════════════════════════════════════════════════════════════════════
// Enums
// ═══════════════════════════════════════════════════════════════════════════════

enum TaskStatus { pending, running, completed, failed, skipped }

enum AgentType { codeAnalysis, prCorrelation, duplicate, sentiment, changelog }

enum RiskLevel { low, medium, high }

enum ActionType { label, comment, close, linkPr, linkIssue, none }

// ═══════════════════════════════════════════════════════════════════════════════
// TriageTask
// ═══════════════════════════════════════════════════════════════════════════════

/// A single investigation or action task within the game plan.
class TriageTask {
  final String id;
  final AgentType agent;
  TaskStatus status;
  String? error;
  Map<String, dynamic>? result;

  TriageTask({required this.id, required this.agent, this.status = TaskStatus.pending, this.error, this.result});

  factory TriageTask.fromJson(Map<String, dynamic> json) => TriageTask(
    id: json['id'] as String,
    agent: AgentType.values.firstWhere((e) => e.name == json['agent'], orElse: () => AgentType.codeAnalysis),
    status: TaskStatus.values.firstWhere((e) => e.name == json['status'], orElse: () => TaskStatus.pending),
    error: json['error'] as String?,
    result: json['result'] as Map<String, dynamic>?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'agent': agent.name,
    'status': status.name,
    if (error != null) 'error': error,
    if (result != null) 'result': result,
  };
}

// ═══════════════════════════════════════════════════════════════════════════════
// IssuePlan
// ═══════════════════════════════════════════════════════════════════════════════

/// The triage plan for a single GitHub issue.
class IssuePlan {
  final int number;
  final String title;
  final String author;
  final List<String> existingLabels;
  final List<TriageTask> tasks;
  Map<String, dynamic>? decision;

  IssuePlan({
    required this.number,
    required this.title,
    required this.author,
    this.existingLabels = const [],
    required this.tasks,
    this.decision,
  });

  factory IssuePlan.fromJson(Map<String, dynamic> json) => IssuePlan(
    number: json['number'] as int,
    title: json['title'] as String,
    author: json['author'] as String? ?? 'unknown',
    existingLabels: (json['existing_labels'] as List<dynamic>?)?.cast<String>() ?? [],
    tasks: (json['tasks'] as List<dynamic>).map((t) => TriageTask.fromJson(t as Map<String, dynamic>)).toList(),
    decision: json['decision'] as Map<String, dynamic>?,
  );

  Map<String, dynamic> toJson() => {
    'number': number,
    'title': title,
    'author': author,
    'existing_labels': existingLabels,
    'tasks': tasks.map((t) => t.toJson()).toList(),
    'decision': decision,
  };

  /// Whether all investigation tasks have completed (successfully or with failure).
  bool get investigationComplete =>
      tasks.every((t) => t.status == TaskStatus.completed || t.status == TaskStatus.failed);
}

// ═══════════════════════════════════════════════════════════════════════════════
// LinkSpec
// ═══════════════════════════════════════════════════════════════════════════════

/// A link to create between two entities (issue, PR, changelog, release notes).
class LinkSpec {
  final String sourceType; // 'issue', 'pr', 'changelog', 'release_notes'
  final String sourceId;
  final String targetType;
  final String targetId;
  final String description;
  bool applied;

  LinkSpec({
    required this.sourceType,
    required this.sourceId,
    required this.targetType,
    required this.targetId,
    required this.description,
    this.applied = false,
  });

  factory LinkSpec.fromJson(Map<String, dynamic> json) => LinkSpec(
    sourceType: json['source_type'] as String,
    sourceId: json['source_id'] as String,
    targetType: json['target_type'] as String,
    targetId: json['target_id'] as String,
    description: json['description'] as String,
    applied: json['applied'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'source_type': sourceType,
    'source_id': sourceId,
    'target_type': targetType,
    'target_id': targetId,
    'description': description,
    'applied': applied,
  };
}

// ═══════════════════════════════════════════════════════════════════════════════
// GamePlan
// ═══════════════════════════════════════════════════════════════════════════════

/// The top-level game plan that orchestrates the entire triage pipeline.
class GamePlan {
  final String planId;
  final DateTime createdAt;
  final List<IssuePlan> issues;
  final List<LinkSpec> linksToCreate;

  GamePlan({required this.planId, required this.createdAt, required this.issues, this.linksToCreate = const []});

  factory GamePlan.fromJson(Map<String, dynamic> json) => GamePlan(
    planId: json['plan_id'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    issues: (json['issues'] as List<dynamic>).map((i) => IssuePlan.fromJson(i as Map<String, dynamic>)).toList(),
    linksToCreate:
        (json['links_to_create'] as List<dynamic>?)
            ?.map((l) => LinkSpec.fromJson(l as Map<String, dynamic>))
            .toList() ??
        [],
  );

  Map<String, dynamic> toJson() => {
    'plan_id': planId,
    'created_at': createdAt.toIso8601String(),
    'issues': issues.map((i) => i.toJson()).toList(),
    'links_to_create': linksToCreate.map((l) => l.toJson()).toList(),
  };

  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());

  /// Creates a default game plan for a list of issue numbers/titles.
  factory GamePlan.forIssues(List<Map<String, dynamic>> issueData) {
    final now = DateTime.now();
    return GamePlan(
      planId: 'triage-${now.toIso8601String().substring(0, 10)}-${pid}_${now.millisecondsSinceEpoch}',
      createdAt: now,
      issues: issueData.map((data) {
        final number = data['number'] as int;
        return IssuePlan(
          number: number,
          title: data['title'] as String? ?? '',
          author: data['author'] as String? ?? 'unknown',
          existingLabels: (data['labels'] as List<dynamic>?)?.cast<String>() ?? [],
          tasks: [
            TriageTask(id: 'issue-$number-code', agent: AgentType.codeAnalysis),
            TriageTask(id: 'issue-$number-prs', agent: AgentType.prCorrelation),
            TriageTask(id: 'issue-$number-dupes', agent: AgentType.duplicate),
            TriageTask(id: 'issue-$number-sentiment', agent: AgentType.sentiment),
            TriageTask(id: 'issue-$number-changelog', agent: AgentType.changelog),
          ],
        );
      }).toList(),
    );
  }
}
