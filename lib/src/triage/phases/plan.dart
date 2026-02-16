// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import '../models/game_plan.dart';
import '../utils/config.dart';
import '../utils/json_schemas.dart';

/// Phase 1: PLAN
///
/// Discovers issues to triage and produces a game_plan.json that controls
/// all subsequent phases. Supports both single-issue and auto-discovery modes.
/// Uses triage_config.json for label configuration and repo identity.

// ═══════════════════════════════════════════════════════════════════════════════
// Public API
// ═══════════════════════════════════════════════════════════════════════════════

/// Creates a game plan for a single issue.
Future<GamePlan> planSingleIssue(int issueNumber, String repoRoot, {required String runDir}) async {
  print('Phase 1 [PLAN]: Building game plan for issue #$issueNumber');

  final issueData = await _fetchIssueData(issueNumber, repoRoot);
  if (issueData == null) {
    throw StateError('Could not fetch issue #$issueNumber. Is gh authenticated?');
  }

  final plan = GamePlan.forIssues([issueData]);
  _savePlan(plan, runDir);

  print('  Game plan created: ${plan.planId}');
  print('  Tasks: ${plan.issues.fold<int>(0, (sum, i) => sum + i.tasks.length)}');

  return plan;
}

/// Creates a game plan for all open untriaged issues (auto mode).
Future<GamePlan> planAutoTriage(String repoRoot, {required String runDir}) async {
  print('Phase 1 [PLAN]: Discovering open issues for auto-triage');

  final issues = await _discoverOpenIssues(repoRoot);

  if (issues.isEmpty) {
    print('  No untriaged issues found.');
    return GamePlan(
      planId: 'triage-empty-${DateTime.now().millisecondsSinceEpoch}',
      createdAt: DateTime.now(),
      issues: [],
    );
  }

  print('  Found ${issues.length} untriaged issues');

  final plan = GamePlan.forIssues(issues);
  _savePlan(plan, runDir);

  print('  Game plan created: ${plan.planId}');
  print('  Total tasks: ${plan.issues.fold<int>(0, (sum, i) => sum + i.tasks.length)}');

  return plan;
}

/// Loads an existing game plan from a run directory.
GamePlan? loadPlan({String? runDir}) {
  final path = runDir != null ? '$runDir/triage_game_plan.json' : '/tmp/triage_game_plan.json';
  final file = File(path);
  if (!file.existsSync()) return null;

  final validation = validateGamePlan(file.path);
  if (!validation.valid) {
    print('Warning: Invalid game plan: ${validation.errors.join(", ")}');
    return null;
  }

  return GamePlan.fromJson(json.decode(file.readAsStringSync()) as Map<String, dynamic>);
}

// ═══════════════════════════════════════════════════════════════════════════════
// Internal
// ═══════════════════════════════════════════════════════════════════════════════

Future<Map<String, dynamic>?> _fetchIssueData(int issueNumber, String repoRoot) async {
  final result = await Process.run('gh', [
    'issue',
    'view',
    '$issueNumber',
    '--json',
    'number,title,body,author,labels,state,comments',
  ], workingDirectory: repoRoot);

  if (result.exitCode != 0) {
    final stderr = (result.stderr as String).trim();
    if (stderr.contains('authentication') || stderr.contains('auth')) {
      print('  Error: GitHub CLI authentication failed. Run "gh auth login" first.');
    } else {
      print('  Error fetching issue #$issueNumber: $stderr');
    }
    return null;
  }

  try {
    final data = json.decode(result.stdout as String) as Map<String, dynamic>;
    return {
      'number': data['number'],
      'title': data['title'],
      'author': (data['author'] as Map<String, dynamic>?)?['login'] ?? 'unknown',
      'labels':
          (data['labels'] as List<dynamic>?)?.map((l) => (l as Map<String, dynamic>)['name'] as String).toList() ?? [],
    };
  } catch (e) {
    print('  Error parsing issue #$issueNumber: $e');
    return null;
  }
}

Future<List<Map<String, dynamic>>> _discoverOpenIssues(String repoRoot) async {
  final result = await Process.run('gh', [
    'issue',
    'list',
    '--state',
    'open',
    '--limit',
    '100',
    '--json',
    'number,title,author,labels',
  ], workingDirectory: repoRoot);

  if (result.exitCode != 0) {
    final stderr = (result.stderr as String).trim();
    if (stderr.contains('authentication') || stderr.contains('auth')) {
      print('  Error: GitHub CLI authentication failed. Run "gh auth login" first.');
    } else {
      print('  Error listing issues: $stderr');
    }
    return [];
  }

  try {
    final issues = json.decode(result.stdout as String) as List<dynamic>;
    final triagedLabel = config.triagedLabel;

    return issues
        .cast<Map<String, dynamic>>()
        .where((issue) {
          final labels =
              (issue['labels'] as List<dynamic>?)?.map((l) => (l as Map<String, dynamic>)['name'] as String).toList() ??
              [];
          return !labels.contains(triagedLabel);
        })
        .map(
          (issue) => {
            'number': issue['number'] as int,
            'title': issue['title'] as String? ?? '',
            'author': (issue['author'] as Map<String, dynamic>?)?['login'] as String? ?? 'unknown',
            'labels':
                (issue['labels'] as List<dynamic>?)
                    ?.map((l) => (l as Map<String, dynamic>)['name'] as String)
                    .toList() ??
                <String>[],
          },
        )
        .toList();
  } catch (e) {
    print('  Error parsing issues: $e');
    return [];
  }
}

void _savePlan(GamePlan plan, String runDir) {
  writeJson('$runDir/triage_game_plan.json', plan.toJson());
}
