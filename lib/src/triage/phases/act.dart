// ignore_for_file: avoid_print

import 'dart:io';

import '../models/game_plan.dart';
import '../models/investigation_result.dart';
import '../models/triage_decision.dart';
import '../utils/config.dart';
import '../utils/json_schemas.dart';

/// Phase 3: ACT
///
/// Applies triage decisions based on investigation results.
/// Confidence thresholds are loaded from triage_config.json.
///
/// Idempotency guards:
///   - Checks issue state before acting (skips closed issues)
///   - Checks existing labels before applying duplicates
///   - Checks existing comments for bot signatures before posting duplicates
///   - Each auto-comment includes a hidden signature for dedup

// ═══════════════════════════════════════════════════════════════════════════════
// Constants
// ═══════════════════════════════════════════════════════════════════════════════

/// Hidden HTML comment signature embedded in every auto-posted comment.
/// Format: <!-- triage-bot:$runId:$issueNumber -->
String _botSignature(String runDir, int issueNumber) {
  final runId = runDir.split('/').last;
  return '<!-- triage-bot:$runId:$issueNumber -->';
}

// ═══════════════════════════════════════════════════════════════════════════════
// Public API
// ═══════════════════════════════════════════════════════════════════════════════

/// Apply triage decisions for all issues in the game plan.
Future<List<TriageDecision>> act(
  GamePlan plan,
  Map<int, List<InvestigationResult>> investigationResults,
  String repoRoot, {
  required String runDir,
}) async {
  print('Phase 3 [ACT]: Applying triage decisions for ${plan.issues.length} issue(s)');

  final decisions = <TriageDecision>[];

  for (final issue in plan.issues) {
    // Idempotency: check if issue is still open before acting
    final state = await _getIssueState(issue.number, repoRoot);
    if (state == 'CLOSED') {
      print('  Issue #${issue.number}: already closed, skipping');
      continue;
    }

    final results = investigationResults[issue.number] ?? [];
    final decision = TriageDecision.fromResults(issueNumber: issue.number, results: results);

    print(
      '  Issue #${issue.number}: '
      '${decision.riskLevel.name} risk, '
      '${(decision.aggregateConfidence * 100).toStringAsFixed(0)}% confidence, '
      '${decision.actions.length} actions',
    );

    // Execute each action with idempotency checks
    for (final action in decision.actions) {
      await _executeAction(action, issue.number, repoRoot, runDir);
    }

    // Add the triaged label (idempotent -- checks first)
    await _applyLabelIdempotent(issue.number, config.triagedLabel, repoRoot);

    // Store the decision in the game plan
    issue.decision = decision.toJson();
    decisions.add(decision);
  }

  // Save decisions to run directory
  writeJson('$runDir/triage_game_plan.json', plan.toJson());
  writeJson('$runDir/triage_decisions.json', {
    'decisions': decisions.map((d) => d.toJson()).toList(),
    'timestamp': DateTime.now().toIso8601String(),
  });

  return decisions;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Action Execution (with idempotency)
// ═══════════════════════════════════════════════════════════════════════════════

Future<void> _executeAction(TriageAction action, int issueNumber, String repoRoot, String runDir) async {
  try {
    switch (action.type) {
      case ActionType.label:
        final labels = (action.parameters['labels'] as List<dynamic>?)?.cast<String>() ?? [];
        for (final label in labels) {
          await _applyLabelIdempotent(issueNumber, label, repoRoot);
        }
        action.executed = true;

      case ActionType.comment:
        final body = action.parameters['body'] as String? ?? '';
        if (body.isNotEmpty) {
          final signature = _botSignature(runDir, issueNumber);
          // Idempotency: check if we already posted this comment
          if (await _hasExistingComment(issueNumber, signature, repoRoot)) {
            print('    Skipping duplicate comment for #$issueNumber');
          } else {
            await _postComment(issueNumber, '$body\n\n$signature', repoRoot);
          }
        }
        action.executed = true;

      case ActionType.close:
        // Idempotency: check current state first
        final state = await _getIssueState(issueNumber, repoRoot);
        if (state == 'CLOSED') {
          print('    Issue #$issueNumber already closed');
        } else {
          final stateReason = action.parameters['state_reason'] as String? ?? 'completed';
          await _closeIssue(issueNumber, stateReason, repoRoot);
        }
        action.executed = true;

      case ActionType.linkPr:
        final prNumber = action.parameters['pr_number'] as String? ?? '';
        if (prNumber.isNotEmpty) {
          final linkText = 'Related PR: #$prNumber';
          if (!await _hasExistingComment(issueNumber, linkText, repoRoot)) {
            await _postComment(issueNumber, linkText, repoRoot);
          }
        }
        action.executed = true;

      case ActionType.linkIssue:
        final relatedIssue = action.parameters['issue_number'] as String? ?? '';
        if (relatedIssue.isNotEmpty) {
          final linkText = 'Related issue: #$relatedIssue';
          if (!await _hasExistingComment(issueNumber, linkText, repoRoot)) {
            await _postComment(issueNumber, linkText, repoRoot);
          }
        }
        action.executed = true;

      case ActionType.none:
        action.executed = true;
    }
  } catch (e) {
    action.error = '$e';
    print('    Warning: Action failed for #$issueNumber (${action.type.name}): $e');
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// GitHub Operations (with idempotency)
// ═══════════════════════════════════════════════════════════════════════════════

/// Get the current state of an issue ('OPEN' or 'CLOSED').
Future<String> _getIssueState(int issueNumber, String repoRoot) async {
  try {
    final result = await Process.run('gh', [
      'issue',
      'view',
      '$issueNumber',
      '--json',
      'state',
      '--jq',
      '.state',
    ], workingDirectory: repoRoot);
    return (result.stdout as String).trim().toUpperCase();
  } catch (_) {
    return 'UNKNOWN';
  }
}

/// Apply a label only if it's not already present on the issue.
Future<void> _applyLabelIdempotent(int issueNumber, String label, String repoRoot) async {
  // Check if label is already applied
  final existing = await _getIssueLabels(issueNumber, repoRoot);
  if (existing.contains(label)) return;

  final result = await Process.run('gh', [
    'issue',
    'edit',
    '$issueNumber',
    '--add-label',
    label,
  ], workingDirectory: repoRoot);

  if (result.exitCode != 0) {
    // Label might not exist in the repo -- create it first
    await Process.run('gh', ['label', 'create', label, '--force'], workingDirectory: repoRoot);
    // Retry the label application
    await Process.run('gh', ['issue', 'edit', '$issueNumber', '--add-label', label], workingDirectory: repoRoot);
  }
}

/// Get existing labels on an issue.
Future<Set<String>> _getIssueLabels(int issueNumber, String repoRoot) async {
  try {
    final result = await Process.run('gh', [
      'issue',
      'view',
      '$issueNumber',
      '--json',
      'labels',
      '--jq',
      '[.labels[].name] | join("\\n")',
    ], workingDirectory: repoRoot);
    if (result.exitCode == 0) {
      return (result.stdout as String).trim().split('\n').where((l) => l.isNotEmpty).toSet();
    }
  } catch (_) {}
  return {};
}

/// Check if a comment containing the given text already exists on the issue.
Future<bool> _hasExistingComment(int issueNumber, String searchText, String repoRoot) async {
  try {
    final result = await Process.run('gh', [
      'issue',
      'view',
      '$issueNumber',
      '--json',
      'comments',
      '--jq',
      '.comments[].body',
    ], workingDirectory: repoRoot);
    if (result.exitCode == 0) {
      return (result.stdout as String).contains(searchText);
    }
  } catch (_) {}
  return false;
}

Future<void> _postComment(int issueNumber, String body, String repoRoot) async {
  await Process.run('gh', ['issue', 'comment', '$issueNumber', '--body', body], workingDirectory: repoRoot);
}

Future<void> _closeIssue(int issueNumber, String reason, String repoRoot) async {
  final args = ['issue', 'close', '$issueNumber'];
  if (reason == 'not_planned') {
    args.addAll(['--reason', 'not planned']);
  }
  await Process.run('gh', args, workingDirectory: repoRoot);
}
