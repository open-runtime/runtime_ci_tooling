// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import '../utils/config.dart';
import '../utils/gemini_runner.dart';
import '../utils/json_schemas.dart';

/// Post-Release Triage Phase
///
/// Runs AFTER the GitHub Release is created. Uses the issue_manifest.json
/// from pre-release triage to:
///   - Comment on own-repo issues with release link
///   - Close high-confidence own-repo issues
///   - Comment on cross-repo issues (recommend closure, never close)
///   - Link Sentry issues to the release via MCP
///   - Update release_notes/vX.X.X/linked_issues.json

// ═══════════════════════════════════════════════════════════════════════════════
// Public API
// ═══════════════════════════════════════════════════════════════════════════════

/// Run post-release actions based on the pre-release issue manifest.
Future<void> postReleaseTriage({
  required String newVersion,
  required String releaseTag,
  required String releaseUrl,
  required String manifestPath,
  required String repoRoot,
  required String runDir,
  bool verbose = false,
}) async {
  print('POST-RELEASE TRIAGE: Closing the loop for v$newVersion');
  final stopwatch = Stopwatch()..start();

  // Load the issue manifest from pre-release
  final manifestFile = File(manifestPath);
  if (!manifestFile.existsSync()) {
    print('  Warning: No issue manifest found at $manifestPath');
    print('  Skipping post-release triage (run pre-release first)');
    return;
  }

  Map<String, dynamic> manifest;
  try {
    manifest = json.decode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
  } catch (e) {
    print('  Error: Could not parse manifest: $e');
    return;
  }

  final ghIssues = (manifest['github_issues'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
  final crossIssues = (manifest['cross_repo_issues'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
  final sentryIssues = (manifest['sentry_issues'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

  print(
    '  Issues to process: ${ghIssues.length} own-repo, ${crossIssues.length} cross-repo, ${sentryIssues.length} Sentry',
  );

  final actionsTaken = <Map<String, dynamic>>[];

  // Step 1: Own-repo GitHub issues
  if (config.postReleaseCloseOwnRepo || true) {
    for (final issue in ghIssues) {
      final number = issue['number'] as int;
      final confidence = (issue['confidence'] as num?)?.toDouble() ?? 0.0;
      final title = issue['title'] as String? ?? '';

      if (confidence < config.commentThreshold) continue;

      final actions = await _processOwnRepoIssue(
        issueNumber: number,
        title: title,
        confidence: confidence,
        newVersion: newVersion,
        releaseTag: releaseTag,
        releaseUrl: releaseUrl,
        repoRoot: repoRoot,
        runDir: runDir,
      );
      actionsTaken.addAll(actions);
    }
  }

  // Step 2: Cross-repo GitHub issues
  if (config.postReleaseCommentCrossRepo) {
    for (final issue in crossIssues) {
      final number = issue['number'] as int;
      final confidence = (issue['confidence'] as num?)?.toDouble() ?? 0.0;
      final repo = issue['repo'] as String? ?? '';
      final title = issue['title'] as String? ?? '';

      if (confidence < config.commentThreshold || repo.isEmpty) continue;

      final action = await _processCrossRepoIssue(
        issueNumber: number,
        repo: repo,
        title: title,
        confidence: confidence,
        newVersion: newVersion,
        releaseTag: releaseTag,
        repoRoot: repoRoot,
        runDir: runDir,
      );
      if (action != null) actionsTaken.add(action);
    }
  }

  // Step 3: Sentry issues
  if (config.postReleaseLinkSentry && sentryIssues.isNotEmpty) {
    await _linkSentryIssues(
      sentryIssues: sentryIssues,
      newVersion: newVersion,
      releaseTag: releaseTag,
      repoRoot: repoRoot,
      runDir: runDir,
      verbose: verbose,
    );
  }

  // Step 4: Update release_notes/vX.X.X/linked_issues.json
  _updateLinkedIssues(
    ghIssues: ghIssues,
    crossIssues: crossIssues,
    sentryIssues: sentryIssues,
    newVersion: newVersion,
    repoRoot: repoRoot,
  );

  // Save post-release report
  writeJson('$runDir/post_release_report.json', {
    'version': newVersion,
    'release_tag': releaseTag,
    'actions_taken': actionsTaken,
    'timestamp': DateTime.now().toIso8601String(),
  });

  stopwatch.stop();
  print('  Actions taken: ${actionsTaken.length}');
  print('  Duration: ${stopwatch.elapsed.inSeconds}s');
}

// ═══════════════════════════════════════════════════════════════════════════════
// Own-Repo Issue Processing
// ═══════════════════════════════════════════════════════════════════════════════

Future<List<Map<String, dynamic>>> _processOwnRepoIssue({
  required int issueNumber,
  required String title,
  required double confidence,
  required String newVersion,
  required String releaseTag,
  required String releaseUrl,
  required String repoRoot,
  required String runDir,
}) async {
  final actions = <Map<String, dynamic>>[];
  final runId = runDir.split('/').last;
  final signature = '<!-- post-release:$runId:$issueNumber -->';

  // Check if we already commented (idempotency)
  if (await _hasExistingComment(issueNumber, signature, repoRoot: repoRoot)) {
    print('    #$issueNumber: already processed, skipping');
    return actions;
  }

  // Check if issue is still open
  final state = await _getIssueState(issueNumber, repoRoot);
  if (state == 'CLOSED') {
    print('    #$issueNumber: already closed, skipping');
    return actions;
  }

  // Build the release comment
  final comment = StringBuffer()
    ..writeln('## Release Update: v$newVersion')
    ..writeln()
    ..writeln(
      'This issue appears to be addressed in '
      '**[v$newVersion](https://github.com/${config.repoOwner}/${config.repoName}/releases/tag/$releaseTag)** '
      '(${(confidence * 100).toStringAsFixed(0)}% confidence).',
    )
    ..writeln()
    ..writeln('**Resources:**')
    ..writeln('- [Release Notes](https://github.com/${config.repoOwner}/${config.repoName}/releases/tag/$releaseTag)')
    ..writeln(
      '- [CHANGELOG](https://github.com/${config.repoOwner}/${config.repoName}/blob/main/${config.changelogPath})',
    )
    ..writeln(
      '- [Release Notes Folder](https://github.com/${config.repoOwner}/${config.repoName}/tree/main/${config.releaseNotesPath}/v$newVersion/)',
    );

  if (confidence >= config.autoCloseThreshold) {
    comment
      ..writeln()
      ..writeln('This issue is being **automatically closed** as the fix has been verified with high confidence.')
      ..writeln('If this was closed in error, please reopen.');
  } else if (confidence >= config.suggestCloseThreshold) {
    comment
      ..writeln()
      ..writeln('We recommend reviewing and closing this issue if the fix is confirmed.');
  }

  comment.writeln();
  comment.writeln(signature);

  // Post comment
  await _postComment(issueNumber, comment.toString(), repoRoot: repoRoot);
  actions.add({'type': 'comment', 'issue': issueNumber, 'repo': '${config.repoOwner}/${config.repoName}'});
  print('    #$issueNumber: commented (${(confidence * 100).toStringAsFixed(0)}% confidence)');

  // Close if high confidence
  if (confidence >= config.autoCloseThreshold && config.postReleaseCloseOwnRepo) {
    await _closeIssue(issueNumber, repoRoot);
    actions.add({'type': 'close', 'issue': issueNumber, 'repo': '${config.repoOwner}/${config.repoName}'});
    print('    #$issueNumber: CLOSED (${(confidence * 100).toStringAsFixed(0)}% confidence)');
  }

  return actions;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Cross-Repo Issue Processing
// ═══════════════════════════════════════════════════════════════════════════════

Future<Map<String, dynamic>?> _processCrossRepoIssue({
  required int issueNumber,
  required String repo,
  required String title,
  required double confidence,
  required String newVersion,
  required String releaseTag,
  required String repoRoot,
  required String runDir,
}) async {
  final runId = runDir.split('/').last;
  final signature = '<!-- cross-repo-release:$runId:$issueNumber -->';

  // Check if we already commented (idempotency)
  if (await _hasExistingComment(issueNumber, signature, repo: repo, repoRoot: repoRoot)) {
    print('    $repo#$issueNumber: already processed, skipping');
    return null;
  }

  final comment = StringBuffer()
    ..writeln('## Cross-Repository Release Notification')
    ..writeln()
    ..writeln(
      'A potentially related fix has been released in '
      '**[${config.repoOwner}/${config.repoName} v$newVersion]'
      '(https://github.com/${config.repoOwner}/${config.repoName}/releases/tag/$releaseTag)** '
      '(${(confidence * 100).toStringAsFixed(0)}% confidence).',
    )
    ..writeln();

  if (confidence >= config.autoCloseThreshold) {
    comment.writeln(
      '**Recommendation:** This fix appears highly relevant. '
      'Consider closing this issue after verifying the fix by updating your '
      '`${config.repoName}` dependency to v$newVersion or later.',
    );
  } else if (confidence >= config.suggestCloseThreshold) {
    comment.writeln(
      '**Note:** This may be related. Please review the release notes '
      'and test whether updating your `${config.repoName}` dependency resolves this issue.',
    );
  } else {
    comment.writeln('This release contains changes that may be related to this issue.');
  }

  comment.writeln();
  comment.writeln(signature);

  // Post comment (NEVER close cross-repo issues)
  await _postComment(issueNumber, comment.toString(), repo: repo, repoRoot: repoRoot);
  print('    $repo#$issueNumber: commented (${(confidence * 100).toStringAsFixed(0)}% confidence)');

  return {'type': 'cross_repo_comment', 'issue': issueNumber, 'repo': repo};
}

// ═══════════════════════════════════════════════════════════════════════════════
// Sentry Linking
// ═══════════════════════════════════════════════════════════════════════════════

Future<void> _linkSentryIssues({
  required List<Map<String, dynamic>> sentryIssues,
  required String newVersion,
  required String releaseTag,
  required String repoRoot,
  required String runDir,
  bool verbose = false,
}) async {
  print('  Linking ${sentryIssues.length} Sentry issues to release...');

  final issueIds = sentryIssues.map((i) => '${i['id']} (${i['project']})').join(', ');

  final prompt =
      '''
You have access to the Sentry MCP server. For each of the following Sentry issues,
add a comment or note linking them to the release.

Sentry issues: $issueIds
Release: ${config.repoOwner}/${config.repoName} v$newVersion
Release tag: $releaseTag

For each issue, use Sentry MCP tools to add a note that this issue may be addressed
in release v$newVersion. If the Sentry MCP doesn't support adding notes directly,
report which issues you couldn't link.

Do not close or resolve any Sentry issues.
''';

  final runner = GeminiRunner(maxConcurrent: 1, maxRetries: 2, verbose: verbose);
  final task = GeminiTask(
    id: 'sentry-link',
    prompt: prompt,
    model: config.proModel,
    maxTurns: 30,
    workingDirectory: repoRoot,
  );

  await runner.executeBatch([task]);
  print('    Sentry linking complete');
}

// ═══════════════════════════════════════════════════════════════════════════════
// Linked Issues Update
// ═══════════════════════════════════════════════════════════════════════════════

void _updateLinkedIssues({
  required List<Map<String, dynamic>> ghIssues,
  required List<Map<String, dynamic>> crossIssues,
  required List<Map<String, dynamic>> sentryIssues,
  required String newVersion,
  required String repoRoot,
}) {
  final releaseDir = '$repoRoot/${config.releaseNotesPath}/v$newVersion';
  final linkedFile = File('$releaseDir/linked_issues.json');

  final data = <String, dynamic>{
    'version': newVersion,
    'updated_at': DateTime.now().toIso8601String(),
    'github_issues': ghIssues
        .where((i) => ((i['confidence'] as num?)?.toDouble() ?? 0.0) >= config.commentThreshold)
        .map(
          (i) => {'number': i['number'], 'title': i['title'], 'confidence': i['confidence'], 'category': i['category']},
        )
        .toList(),
    'cross_repo_issues': crossIssues
        .where((i) => ((i['confidence'] as num?)?.toDouble() ?? 0.0) >= config.commentThreshold)
        .map((i) => {'number': i['number'], 'repo': i['repo'], 'title': i['title'], 'confidence': i['confidence']})
        .toList(),
    'sentry_issues': sentryIssues
        .where((i) => ((i['confidence'] as num?)?.toDouble() ?? 0.0) >= config.commentThreshold)
        .map((i) => {'id': i['id'], 'project': i['project'], 'title': i['title'], 'confidence': i['confidence']})
        .toList(),
  };

  if (Directory(releaseDir).existsSync()) {
    writeJson(linkedFile.path, data);
    print('  Updated ${linkedFile.path}');
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// GitHub Helpers
// ═══════════════════════════════════════════════════════════════════════════════

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

Future<bool> _hasExistingComment(int issueNumber, String signature, {String? repo, required String repoRoot}) async {
  try {
    final args = ['issue', 'view', '$issueNumber', '--json', 'comments', '--jq', '.comments[].body'];
    if (repo != null) args.addAll(['--repo', repo]);
    final result = await Process.run('gh', args, workingDirectory: repoRoot);
    return (result.stdout as String).contains(signature);
  } catch (_) {
    return false;
  }
}

Future<void> _postComment(int issueNumber, String body, {String? repo, required String repoRoot}) async {
  final args = ['issue', 'comment', '$issueNumber', '--body', body];
  if (repo != null) args.addAll(['--repo', repo]);
  await Process.run('gh', args, workingDirectory: repoRoot);
}

Future<void> _closeIssue(int issueNumber, String repoRoot) async {
  await Process.run('gh', ['issue', 'close', '$issueNumber'], workingDirectory: repoRoot);
}
