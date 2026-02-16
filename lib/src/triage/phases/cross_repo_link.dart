// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import '../models/game_plan.dart';
import '../models/triage_decision.dart';
import '../utils/config.dart';
import '../utils/json_schemas.dart';

/// Phase 5b: CROSS-REPO LINK
///
/// After the standard linking phase, searches for related issues in configured
/// dependent repositories and posts cross-references.
///
/// Configuration: triage_config.json -> cross_repo.repos
///
/// For each triaged issue:
///   1. Extract key terms from issue title
///   2. Search each cross-repo for related issues via gh search
///   3. Post cross-reference comments on related issues

// ═══════════════════════════════════════════════════════════════════════════════
// Public API
// ═══════════════════════════════════════════════════════════════════════════════

/// Search and link related issues across configured dependent repos.
Future<void> crossRepoLink(
  GamePlan plan,
  List<TriageDecision> decisions,
  String repoRoot, {
  required String runDir,
}) async {
  if (!config.crossRepoEnabled) {
    print('Phase 5b [CROSS-REPO]: Disabled in config');
    return;
  }

  final repos = config.crossRepoRepos;
  if (repos.isEmpty) {
    print('Phase 5b [CROSS-REPO]: No cross-repo targets configured');
    return;
  }

  print('Phase 5b [CROSS-REPO]: Searching ${repos.length} dependent repos');

  final crossLinks = <Map<String, dynamic>>[];

  for (final decision in decisions) {
    final issueNumber = decision.issueNumber;
    final issuePlan = plan.issues.firstWhere((i) => i.number == issueNumber, orElse: () => plan.issues.first);

    // Extract search terms from issue title
    final searchTerms = _extractSearchTerms(issuePlan.title);
    if (searchTerms.isEmpty) continue;

    print('  Issue #$issueNumber: searching for "$searchTerms"');

    for (final repo in repos) {
      try {
        final relatedIssues = await _searchRepo(repo.owner, repo.repo, searchTerms, repoRoot);

        for (final related in relatedIssues) {
          final relatedNumber = related['number'] as int;
          final relatedTitle = related['title'] as String;

          // Check if cross-link already exists
          final alreadyLinked = await _hasExistingComment(
            repo.owner,
            repo.repo,
            relatedNumber,
            '${config.repoOwner}/${config.repoName}#$issueNumber',
            repoRoot,
          );

          if (!alreadyLinked) {
            // Post cross-reference comment on the dependent repo's issue
            final comment = StringBuffer()
              ..writeln('## Cross-Repository Reference')
              ..writeln()
              ..writeln(
                'Related issue in **${config.repoOwner}/${config.repoName}**: '
                '[#$issueNumber](https://github.com/${config.repoOwner}/${config.repoName}/issues/$issueNumber)',
              )
              ..writeln()
              ..writeln('**${issuePlan.title}**')
              ..writeln()
              ..writeln(
                'Confidence: ${(decision.aggregateConfidence * 100).toStringAsFixed(0)}% | '
                'Risk: ${decision.riskLevel.name}',
              )
              ..writeln()
              ..writeln('<!-- cross-repo-triage:${config.repoOwner}/${config.repoName}#$issueNumber -->');

            await _postCrossRepoComment(repo.owner, repo.repo, relatedNumber, comment.toString(), repoRoot);

            crossLinks.add({
              'source_repo': '${config.repoOwner}/${config.repoName}',
              'source_issue': issueNumber,
              'target_repo': repo.fullName,
              'target_issue': relatedNumber,
              'target_title': relatedTitle,
            });

            print('    Linked to ${repo.fullName}#$relatedNumber: $relatedTitle');
          }
        }
      } catch (e) {
        print('    Warning: Could not search ${repo.fullName}: $e');
      }
    }
  }

  // Save cross-repo link report
  writeJson('$runDir/triage_cross_repo_links.json', {
    'links': crossLinks,
    'timestamp': DateTime.now().toIso8601String(),
    'repos_searched': repos.map((r) => r.fullName).toList(),
  });

  print('  Cross-repo links created: ${crossLinks.length}');
}

// ═══════════════════════════════════════════════════════════════════════════════
// Internal
// ═══════════════════════════════════════════════════════════════════════════════

/// Extract meaningful search terms from an issue title.
String _extractSearchTerms(String title) {
  // Remove common noise words and keep meaningful terms
  final noiseWords = {
    'the',
    'a',
    'an',
    'is',
    'are',
    'was',
    'were',
    'be',
    'been',
    'has',
    'have',
    'had',
    'do',
    'does',
    'did',
    'will',
    'would',
    'could',
    'should',
    'may',
    'might',
    'can',
    'to',
    'of',
    'in',
    'on',
    'at',
    'for',
    'with',
    'by',
    'from',
    'and',
    'or',
    'but',
    'not',
    'no',
    'if',
    'when',
    'how',
    'what',
    'why',
    'this',
    'that',
    'it',
    'its',
    'we',
    'our',
    'they',
    'their',
  };

  final words = title
      .replaceAll(RegExp(r'[^\w\s]'), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.length > 2)
      .where((w) => !noiseWords.contains(w.toLowerCase()))
      .take(5)
      .toList();

  return words.join(' ');
}

/// Search a target repo for issues matching search terms.
Future<List<Map<String, dynamic>>> _searchRepo(String owner, String repo, String query, String repoRoot) async {
  final result = await Process.run('gh', [
    'search',
    'issues',
    '--repo',
    '$owner/$repo',
    '--state',
    'open',
    '--limit',
    '5',
    '--json',
    'number,title',
    query,
  ], workingDirectory: repoRoot);

  if (result.exitCode != 0) return [];

  try {
    final output = (result.stdout as String).trim();
    if (output.isEmpty || output == '[]') return [];
    final decoded = json.decode(output);
    if (decoded is List) {
      return decoded.cast<Map<String, dynamic>>();
    }
    return [];
  } catch (_) {
    return [];
  }
}

/// Check if a cross-reference comment already exists on a target repo issue.
Future<bool> _hasExistingComment(String owner, String repo, int issueNumber, String searchText, String repoRoot) async {
  try {
    final result = await Process.run('gh', [
      'issue',
      'view',
      '$issueNumber',
      '--repo',
      '$owner/$repo',
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

/// Post a comment on an issue in a target repo.
Future<void> _postCrossRepoComment(String owner, String repo, int issueNumber, String body, String repoRoot) async {
  await Process.run('gh', [
    'issue',
    'comment',
    '$issueNumber',
    '--repo',
    '$owner/$repo',
    '--body',
    body,
  ], workingDirectory: repoRoot);
}
