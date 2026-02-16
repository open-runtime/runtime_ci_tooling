// ignore_for_file: avoid_print

/// Data class for investigation agent results.
///
/// Each agent returns an InvestigationResult with a confidence score,
/// findings summary, evidence, and recommended actions.

// ═══════════════════════════════════════════════════════════════════════════════
// InvestigationResult
// ═══════════════════════════════════════════════════════════════════════════════

class InvestigationResult {
  final String agentId;
  final int issueNumber;
  final double confidence;
  final String summary;
  final List<String> evidence;
  final List<String> recommendedLabels;
  final String? suggestedComment;
  final bool suggestClose;
  final String? closeReason;
  final List<RelatedEntity> relatedEntities;
  final int turnsUsed;
  final int toolCallsMade;
  final int durationMs;

  InvestigationResult({
    required this.agentId,
    required this.issueNumber,
    required this.confidence,
    required this.summary,
    this.evidence = const [],
    this.recommendedLabels = const [],
    this.suggestedComment,
    this.suggestClose = false,
    this.closeReason,
    this.relatedEntities = const [],
    this.turnsUsed = 0,
    this.toolCallsMade = 0,
    this.durationMs = 0,
  });

  factory InvestigationResult.fromJson(Map<String, dynamic> json) => InvestigationResult(
    agentId: json['agent_id'] as String? ?? 'unknown',
    issueNumber: json['issue_number'] as int? ?? 0,
    confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
    summary: json['summary'] as String? ?? '',
    evidence: (json['evidence'] as List<dynamic>?)?.cast<String>() ?? [],
    recommendedLabels: (json['recommended_labels'] as List<dynamic>?)?.cast<String>() ?? [],
    suggestedComment: json['suggested_comment'] as String?,
    suggestClose: json['suggest_close'] as bool? ?? false,
    closeReason: json['close_reason'] as String?,
    relatedEntities:
        (json['related_entities'] as List<dynamic>?)
            ?.map((e) => RelatedEntity.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
    turnsUsed: json['turns_used'] as int? ?? 0,
    toolCallsMade: json['tool_calls_made'] as int? ?? 0,
    durationMs: json['duration_ms'] as int? ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'agent_id': agentId,
    'issue_number': issueNumber,
    'confidence': confidence,
    'summary': summary,
    'evidence': evidence,
    'recommended_labels': recommendedLabels,
    if (suggestedComment != null) 'suggested_comment': suggestedComment,
    'suggest_close': suggestClose,
    if (closeReason != null) 'close_reason': closeReason,
    'related_entities': relatedEntities.map((e) => e.toJson()).toList(),
    'turns_used': turnsUsed,
    'tool_calls_made': toolCallsMade,
    'duration_ms': durationMs,
  };

  /// Creates a failed result when an agent errors out.
  factory InvestigationResult.failed({required String agentId, required int issueNumber, required String error}) =>
      InvestigationResult(
        agentId: agentId,
        issueNumber: issueNumber,
        confidence: 0.0,
        summary: 'Investigation failed: $error',
      );
}

// ═══════════════════════════════════════════════════════════════════════════════
// RelatedEntity
// ═══════════════════════════════════════════════════════════════════════════════

/// A reference to a related entity (PR, issue, commit, file) found during investigation.
class RelatedEntity {
  final String type; // 'pr', 'issue', 'commit', 'file'
  final String id; // PR number, issue number, commit SHA, file path
  final String description;
  final double relevance; // 0.0-1.0

  RelatedEntity({required this.type, required this.id, required this.description, this.relevance = 0.5});

  factory RelatedEntity.fromJson(Map<String, dynamic> json) => RelatedEntity(
    type: json['type'] as String? ?? 'unknown',
    id: json['id'] as String? ?? '',
    description: json['description'] as String? ?? '',
    relevance: (json['relevance'] as num?)?.toDouble() ?? 0.5,
  );

  Map<String, dynamic> toJson() => {'type': type, 'id': id, 'description': description, 'relevance': relevance};
}
