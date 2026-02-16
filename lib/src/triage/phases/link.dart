// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import '../models/game_plan.dart';
import '../models/investigation_result.dart';
import '../models/triage_decision.dart';
import '../utils/json_schemas.dart';

/// Phase 5: LINK
///
/// Creates bidirectional references between issues, PRs, changelogs,
/// release notes, and documentation. Ensures comprehensive traceability.

// ═══════════════════════════════════════════════════════════════════════════════
// Public API
// ═══════════════════════════════════════════════════════════════════════════════

/// Cross-link all triaged issues to related artifacts.
Future<void> link(GamePlan plan, List<TriageDecision> decisions, String repoRoot, {required String runDir}) async {
  print('Phase 5 [LINK]: Cross-linking ${decisions.length} issue(s)');

  final linksCreated = <LinkSpec>[];

  for (final decision in decisions) {
    final issueNumber = decision.issueNumber;

    // Collect all related entities from investigation results
    final relatedPrs = <RelatedEntity>[];
    final relatedIssues = <RelatedEntity>[];

    for (final result in decision.investigationResults) {
      for (final entity in result.relatedEntities) {
        if (entity.type == 'pr') relatedPrs.add(entity);
        if (entity.type == 'issue') relatedIssues.add(entity);
      }
    }

    // Link issue -> PRs (comment on issue)
    for (final pr in relatedPrs.where((p) => p.relevance >= 0.6)) {
      final link = LinkSpec(
        sourceType: 'issue',
        sourceId: '$issueNumber',
        targetType: 'pr',
        targetId: pr.id,
        description: 'Related PR: ${pr.description}',
      );

      // Only link if not already linked (check existing comments)
      final alreadyLinked = await _isAlreadyLinked(issueNumber, 'PR #${pr.id}', repoRoot);
      if (!alreadyLinked) {
        await _postComment(issueNumber, 'Linked by triage: PR #${pr.id} -- ${pr.description}', repoRoot);
        link.applied = true;
      } else {
        link.applied = true; // Already linked
      }
      linksCreated.add(link);
    }

    // Link issue -> related issues
    for (final related in relatedIssues.where((i) => i.relevance >= 0.7)) {
      final link = LinkSpec(
        sourceType: 'issue',
        sourceId: '$issueNumber',
        targetType: 'issue',
        targetId: related.id,
        description: 'Related issue: ${related.description}',
      );

      final alreadyLinked = await _isAlreadyLinked(issueNumber, '#${related.id}', repoRoot);
      if (!alreadyLinked) {
        await _postComment(issueNumber, 'Related: #${related.id} -- ${related.description}', repoRoot);
        link.applied = true;
      } else {
        link.applied = true;
      }
      linksCreated.add(link);
    }

    // Link issue -> changelog (check if issue appears in CHANGELOG.md)
    final changelogFile = File('$repoRoot/CHANGELOG.md');
    if (changelogFile.existsSync()) {
      final changelogContent = changelogFile.readAsStringSync();
      if (changelogContent.contains('#$issueNumber')) {
        linksCreated.add(
          LinkSpec(
            sourceType: 'issue',
            sourceId: '$issueNumber',
            targetType: 'changelog',
            targetId: 'CHANGELOG.md',
            description: 'Issue referenced in CHANGELOG.md',
            applied: true,
          ),
        );
      }
    }

    // Link issue -> release notes (check release_notes/ folder)
    final releaseNotesDir = Directory('$repoRoot/release_notes');
    if (releaseNotesDir.existsSync()) {
      for (final versionDir in releaseNotesDir.listSync().whereType<Directory>()) {
        final releaseNotesFile = File('${versionDir.path}/release_notes.md');
        if (releaseNotesFile.existsSync()) {
          final content = releaseNotesFile.readAsStringSync();
          if (content.contains('#$issueNumber')) {
            final version = versionDir.path.split('/').last;
            linksCreated.add(
              LinkSpec(
                sourceType: 'issue',
                sourceId: '$issueNumber',
                targetType: 'release_notes',
                targetId: version,
                description: 'Issue referenced in release notes $version',
                applied: true,
              ),
            );
          }
        }

        // Also update linked_issues.json in the release notes folder
        final linkedIssuesFile = File('${versionDir.path}/linked_issues.json');
        _addToLinkedIssues(linkedIssuesFile, issueNumber, decision);
      }
    }
  }

  // Save link report
  plan.linksToCreate.addAll(linksCreated);
  writeJson('$runDir/triage_game_plan.json', plan.toJson());
  writeJson('$runDir/triage_links.json', {
    'links_created': linksCreated.map((l) => l.toJson()).toList(),
    'timestamp': DateTime.now().toIso8601String(),
  });

  final applied = linksCreated.where((l) => l.applied).length;
  print('  Links: $applied/${linksCreated.length} applied');
}

// ═══════════════════════════════════════════════════════════════════════════════
// Internal
// ═══════════════════════════════════════════════════════════════════════════════

/// Check if a link reference already exists in issue comments.
Future<bool> _isAlreadyLinked(int issueNumber, String searchText, String repoRoot) async {
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

/// Add an issue to the linked_issues.json file in a release notes folder.
void _addToLinkedIssues(File file, int issueNumber, TriageDecision decision) {
  Map<String, dynamic> data;
  if (file.existsSync()) {
    try {
      data = json.decode(file.readAsStringSync()) as Map<String, dynamic>;
    } catch (_) {
      data = {'issues': <dynamic>[]};
    }
  } else {
    data = {'issues': <dynamic>[]};
  }

  final issues = data['issues'] as List<dynamic>;
  final alreadyPresent = issues.any((i) => (i as Map<String, dynamic>)['number'] == issueNumber);

  if (!alreadyPresent) {
    issues.add({
      'number': issueNumber,
      'confidence': decision.aggregateConfidence,
      'risk_level': decision.riskLevel.name,
      'linked_at': DateTime.now().toIso8601String(),
    });
    data['issues'] = issues;
    writeJson(file.path, data);
  }
}
