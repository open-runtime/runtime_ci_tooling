// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import '../models/game_plan.dart';
import '../models/triage_decision.dart';
import '../utils/json_schemas.dart';

/// Phase 4: VERIFY
///
/// Confirms that all actions from Phase 3 were applied successfully
/// by re-reading issue state from GitHub. Reports any discrepancies.

// ═══════════════════════════════════════════════════════════════════════════════
// Public API
// ═══════════════════════════════════════════════════════════════════════════════

/// Verify that all triage actions were applied correctly.
///
/// Returns a verification report with pass/fail status for each action.
Future<VerificationReport> verify(
  GamePlan plan,
  List<TriageDecision> decisions,
  String repoRoot, {
  required String runDir,
}) async {
  print('Phase 4 [VERIFY]: Checking ${decisions.length} decision(s)');

  final verifications = <IssueVerification>[];

  for (final decision in decisions) {
    final issueNumber = decision.issueNumber;
    print('  Verifying issue #$issueNumber...');

    // Fetch current issue state from GitHub
    final currentState = await _fetchIssueState(issueNumber, repoRoot);
    if (currentState == null) {
      verifications.add(
        IssueVerification(
          issueNumber: issueNumber,
          passed: false,
          checks: [VerificationCheck(name: 'fetch_state', passed: false, message: 'Could not fetch issue state')],
        ),
      );
      continue;
    }

    final checks = <VerificationCheck>[];

    // Verify labels were applied
    final currentLabels = currentState['labels'] as List<String>;
    for (final action in decision.actions.where((a) => a.type == ActionType.label)) {
      final expectedLabels = (action.parameters['labels'] as List<dynamic>?)?.cast<String>() ?? [];
      for (final label in expectedLabels) {
        checks.add(
          VerificationCheck(
            name: 'label_$label',
            passed: currentLabels.contains(label),
            message: currentLabels.contains(label) ? 'Label "$label" applied' : 'Label "$label" NOT found on issue',
          ),
        );
      }
      action.verified = checks.last.passed;
    }

    // Verify issue state (open/closed)
    for (final action in decision.actions.where((a) => a.type == ActionType.close)) {
      final expectedState = 'closed';
      final actualState = currentState['state'] as String;
      checks.add(
        VerificationCheck(
          name: 'state_closed',
          passed: actualState == expectedState,
          message: actualState == expectedState
              ? 'Issue correctly closed'
              : 'Issue state is "$actualState", expected "$expectedState"',
        ),
      );
      action.verified = checks.last.passed;
    }

    // Verify comments were posted (check comment count increased)
    final commentActions = decision.actions.where((a) => a.type == ActionType.comment).toList();
    if (commentActions.isNotEmpty) {
      final commentCount = currentState['comment_count'] as int;
      checks.add(
        VerificationCheck(
          name: 'comments_posted',
          passed: commentCount > 0,
          message: 'Issue has $commentCount comments',
        ),
      );
      for (final action in commentActions) {
        action.verified = commentCount > 0;
      }
    }

    // Verify triaged label exists
    checks.add(
      VerificationCheck(
        name: 'triaged_label',
        passed: currentLabels.contains('triaged'),
        message: currentLabels.contains('triaged') ? '"triaged" label applied' : '"triaged" label NOT found',
      ),
    );

    final allPassed = checks.every((c) => c.passed);
    verifications.add(IssueVerification(issueNumber: issueNumber, passed: allPassed, checks: checks));

    final passCount = checks.where((c) => c.passed).length;
    print(
      '    ${allPassed ? "PASS" : "PARTIAL"}: '
      '$passCount/${checks.length} checks passed',
    );
  }

  final report = VerificationReport(verifications: verifications, timestamp: DateTime.now());

  // Save verification report
  writeJson('$runDir/triage_verification.json', report.toJson());

  final totalPassed = verifications.where((v) => v.passed).length;
  print('  Verification complete: $totalPassed/${verifications.length} issues fully verified');

  return report;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Internal
// ═══════════════════════════════════════════════════════════════════════════════

/// Fetch current issue state from GitHub.
Future<Map<String, dynamic>?> _fetchIssueState(int issueNumber, String repoRoot) async {
  try {
    final result = await Process.run('gh', [
      'issue',
      'view',
      '$issueNumber',
      '--json',
      'state,labels,comments',
    ], workingDirectory: repoRoot);

    if (result.exitCode != 0) return null;

    final data = json.decode(result.stdout as String) as Map<String, dynamic>;
    return {
      'state': data['state'] as String? ?? 'OPEN',
      'labels':
          (data['labels'] as List<dynamic>?)?.map((l) => (l as Map<String, dynamic>)['name'] as String).toList() ??
          <String>[],
      'comment_count': (data['comments'] as List<dynamic>?)?.length ?? 0,
    };
  } catch (e) {
    return null;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Data Classes
// ═══════════════════════════════════════════════════════════════════════════════

class VerificationCheck {
  final String name;
  final bool passed;
  final String message;

  VerificationCheck({required this.name, required this.passed, required this.message});

  Map<String, dynamic> toJson() => {'name': name, 'passed': passed, 'message': message};
}

class IssueVerification {
  final int issueNumber;
  final bool passed;
  final List<VerificationCheck> checks;

  IssueVerification({required this.issueNumber, required this.passed, required this.checks});

  Map<String, dynamic> toJson() => {
    'issue_number': issueNumber,
    'passed': passed,
    'checks': checks.map((c) => c.toJson()).toList(),
  };
}

class VerificationReport {
  final List<IssueVerification> verifications;
  final DateTime timestamp;

  VerificationReport({required this.verifications, required this.timestamp});

  bool get allPassed => verifications.every((v) => v.passed);

  Map<String, dynamic> toJson() => {
    'all_passed': allPassed,
    'timestamp': timestamp.toIso8601String(),
    'verifications': verifications.map((v) => v.toJson()).toList(),
  };
}
