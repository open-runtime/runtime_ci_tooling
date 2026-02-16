// ignore_for_file: avoid_print

import '../utils/config.dart';
import 'game_plan.dart';
import 'investigation_result.dart';

/// Confidence thresholds loaded from triage_config.json.
/// Fallback to defaults if config is not available.
double get kCloseThreshold => config.autoCloseThreshold;
double get kSuggestCloseThreshold => config.suggestCloseThreshold;
double get kCommentThreshold => config.commentThreshold;

/// Data class for triage decisions.
///
/// Aggregates investigation results from multiple agents into a final
/// decision with a risk level and set of actions to take.

// ═══════════════════════════════════════════════════════════════════════════════
// TriageAction
// ═══════════════════════════════════════════════════════════════════════════════

/// A concrete action to take on a GitHub issue.
class TriageAction {
  final ActionType type;
  final String description;
  final Map<String, dynamic> parameters;
  bool executed;
  bool verified;
  String? error;

  TriageAction({
    required this.type,
    required this.description,
    this.parameters = const {},
    this.executed = false,
    this.verified = false,
    this.error,
  });

  factory TriageAction.fromJson(Map<String, dynamic> json) => TriageAction(
    type: ActionType.values.firstWhere((e) => e.name == json['type'], orElse: () => ActionType.none),
    description: json['description'] as String? ?? '',
    parameters: json['parameters'] as Map<String, dynamic>? ?? {},
    executed: json['executed'] as bool? ?? false,
    verified: json['verified'] as bool? ?? false,
    error: json['error'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'description': description,
    'parameters': parameters,
    'executed': executed,
    'verified': verified,
    if (error != null) 'error': error,
  };
}

// ═══════════════════════════════════════════════════════════════════════════════
// TriageDecision
// ═══════════════════════════════════════════════════════════════════════════════

/// The aggregated triage decision for a single issue.
class TriageDecision {
  final int issueNumber;
  final double aggregateConfidence;
  final RiskLevel riskLevel;
  final String rationale;
  final List<TriageAction> actions;
  final List<InvestigationResult> investigationResults;

  TriageDecision({
    required this.issueNumber,
    required this.aggregateConfidence,
    required this.riskLevel,
    required this.rationale,
    required this.actions,
    this.investigationResults = const [],
  });

  factory TriageDecision.fromJson(Map<String, dynamic> json) => TriageDecision(
    issueNumber: json['issue_number'] as int,
    aggregateConfidence: (json['aggregate_confidence'] as num?)?.toDouble() ?? 0.0,
    riskLevel: RiskLevel.values.firstWhere((e) => e.name == json['risk_level'], orElse: () => RiskLevel.low),
    rationale: json['rationale'] as String? ?? '',
    actions:
        (json['actions'] as List<dynamic>?)?.map((a) => TriageAction.fromJson(a as Map<String, dynamic>)).toList() ??
        [],
  );

  Map<String, dynamic> toJson() => {
    'issue_number': issueNumber,
    'aggregate_confidence': aggregateConfidence,
    'risk_level': riskLevel.name,
    'rationale': rationale,
    'actions': actions.map((a) => a.toJson()).toList(),
  };

  /// Creates a decision from aggregated investigation results.
  factory TriageDecision.fromResults({required int issueNumber, required List<InvestigationResult> results}) {
    if (results.isEmpty) {
      return TriageDecision(
        issueNumber: issueNumber,
        aggregateConfidence: 0.0,
        riskLevel: RiskLevel.low,
        rationale: 'No investigation results available.',
        actions: [
          TriageAction(
            type: ActionType.label,
            description: 'Add needs-investigation label',
            parameters: {
              'labels': ['needs-investigation'],
            },
          ),
        ],
      );
    }

    // Aggregate confidence: weighted average, boosted by agreement
    final confidences = results.map((r) => r.confidence).toList();
    final avgConfidence = confidences.reduce((a, b) => a + b) / confidences.length;

    // If multiple agents agree on high confidence, boost the aggregate
    final highConfCount = confidences.where((c) => c >= 0.7).length;
    final agreementBoost = highConfCount > 1 ? 0.05 * (highConfCount - 1) : 0.0;
    final aggregateConfidence = (avgConfidence + agreementBoost).clamp(0.0, 1.0);

    // Collect all recommended labels
    final allLabels = <String>{};
    for (final r in results) {
      allLabels.addAll(r.recommendedLabels);
    }

    // Build actions based on confidence thresholds
    final actions = <TriageAction>[];

    // Always add labels
    if (allLabels.isNotEmpty) {
      actions.add(
        TriageAction(
          type: ActionType.label,
          description: 'Apply recommended labels: ${allLabels.join(", ")}',
          parameters: {'labels': allLabels.toList()},
        ),
      );
    }

    // Determine risk level and actions based on confidence
    RiskLevel riskLevel;
    if (aggregateConfidence >= kCloseThreshold) {
      riskLevel = RiskLevel.high;
      // Auto-close with comment
      final closeResult = results.firstWhere((r) => r.suggestClose, orElse: () => results.first);
      actions.add(
        TriageAction(
          type: ActionType.comment,
          description: 'Post detailed findings comment',
          parameters: {'body': _buildCloseComment(issueNumber, results, aggregateConfidence)},
        ),
      );
      actions.add(
        TriageAction(
          type: ActionType.close,
          description:
              'Auto-close with high confidence '
              '(${(aggregateConfidence * 100).toStringAsFixed(0)}%)',
          parameters: {'state': 'closed', 'state_reason': closeResult.closeReason ?? 'completed'},
        ),
      );
    } else if (aggregateConfidence >= kSuggestCloseThreshold) {
      riskLevel = RiskLevel.medium;
      actions.add(
        TriageAction(
          type: ActionType.comment,
          description: 'Post findings and suggest closure',
          parameters: {'body': _buildSuggestComment(issueNumber, results, aggregateConfidence)},
        ),
      );
    } else if (aggregateConfidence >= kCommentThreshold) {
      riskLevel = RiskLevel.low;
      actions.add(
        TriageAction(
          type: ActionType.comment,
          description: 'Post informational findings',
          parameters: {'body': _buildInfoComment(issueNumber, results, aggregateConfidence)},
        ),
      );
    } else {
      riskLevel = RiskLevel.low;
      actions.add(
        TriageAction(
          type: ActionType.label,
          description: 'Add needs-investigation label',
          parameters: {
            'labels': ['needs-investigation'],
          },
        ),
      );
    }

    // Add link actions for related PRs/issues
    for (final r in results) {
      for (final entity in r.relatedEntities) {
        if (entity.type == 'pr' && entity.relevance >= 0.6) {
          actions.add(
            TriageAction(
              type: ActionType.linkPr,
              description: 'Link to related PR #${entity.id}',
              parameters: {'pr_number': entity.id},
            ),
          );
        } else if (entity.type == 'issue' && entity.relevance >= 0.7) {
          actions.add(
            TriageAction(
              type: ActionType.linkIssue,
              description: 'Link to related issue #${entity.id}',
              parameters: {'issue_number': entity.id},
            ),
          );
        }
      }
    }

    final rationale = StringBuffer()
      ..writeln('Aggregate confidence: ${(aggregateConfidence * 100).toStringAsFixed(1)}%')
      ..writeln('Results from ${results.length} agents:');
    for (final r in results) {
      rationale.writeln('  - ${r.agentId}: ${(r.confidence * 100).toStringAsFixed(0)}% -- ${r.summary}');
    }

    return TriageDecision(
      issueNumber: issueNumber,
      aggregateConfidence: aggregateConfidence,
      riskLevel: riskLevel,
      rationale: rationale.toString(),
      actions: actions,
      investigationResults: results,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Comment Builders
// ═══════════════════════════════════════════════════════════════════════════════

String _buildCloseComment(int issueNumber, List<InvestigationResult> results, double confidence) {
  final buf = StringBuffer()
    ..writeln('## Automated Triage: Resolved')
    ..writeln()
    ..writeln(
      'Our AI-powered triage system has analyzed this issue with '
      '**${(confidence * 100).toStringAsFixed(0)}% confidence** that it has been resolved.',
    )
    ..writeln()
    ..writeln('### Investigation Summary');

  for (final r in results) {
    if (r.summary.isNotEmpty) {
      buf.writeln('- **${r.agentId}** (${(r.confidence * 100).toStringAsFixed(0)}%): ${r.summary}');
    }
  }

  final relatedPrs = results.expand((r) => r.relatedEntities).where((e) => e.type == 'pr').toList();
  if (relatedPrs.isNotEmpty) {
    buf.writeln();
    buf.writeln('### Related Pull Requests');
    for (final pr in relatedPrs) {
      buf.writeln('- #${pr.id}: ${pr.description}');
    }
  }

  buf.writeln();
  buf.writeln('If this was closed in error, please reopen and we will re-investigate.');
  return buf.toString();
}

String _buildSuggestComment(int issueNumber, List<InvestigationResult> results, double confidence) {
  final buf = StringBuffer()
    ..writeln('## Automated Triage: Likely Resolved')
    ..writeln()
    ..writeln(
      'Our analysis suggests this issue may be resolved '
      '(${(confidence * 100).toStringAsFixed(0)}% confidence), but we want a human to confirm.',
    )
    ..writeln()
    ..writeln('### Findings');

  for (final r in results) {
    if (r.summary.isNotEmpty) {
      buf.writeln('- **${r.agentId}**: ${r.summary}');
    }
  }

  buf.writeln();
  buf.writeln('Please review and close if appropriate.');
  return buf.toString();
}

String _buildInfoComment(int issueNumber, List<InvestigationResult> results, double confidence) {
  final buf = StringBuffer()
    ..writeln('## Automated Triage: Investigation Update')
    ..writeln()
    ..writeln('Our AI triage system has gathered the following information:')
    ..writeln();

  for (final r in results) {
    if (r.summary.isNotEmpty) {
      buf.writeln('- **${r.agentId}**: ${r.summary}');
    }
  }

  final relatedEntities = results.expand((r) => r.relatedEntities).toList();
  if (relatedEntities.isNotEmpty) {
    buf.writeln();
    buf.writeln('### Related');
    for (final e in relatedEntities) {
      buf.writeln('- ${e.type} #${e.id}: ${e.description}');
    }
  }

  return buf.toString();
}
