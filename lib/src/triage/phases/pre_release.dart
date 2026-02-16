// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import '../utils/config.dart';
import '../utils/gemini_runner.dart';
import '../utils/json_schemas.dart';

/// Pre-Release Triage Phase
///
/// Runs BEFORE the Gemini explorer/composer stages in the release pipeline.
/// Scans GitHub issues and Sentry errors, correlates them with the git diff,
/// and produces an issue_manifest.json that feeds INTO changelog/release notes.
///
/// Usage:
///   Called via triage_cli.dart --pre-release --prev-tag <tag> --version <ver>

// ═══════════════════════════════════════════════════════════════════════════════
// Public API
// ═══════════════════════════════════════════════════════════════════════════════

/// Scan issues and produce an issue manifest for the upcoming release.
///
/// Returns the path to the generated issue_manifest.json.
Future<String> preReleaseTriage({
  required String prevTag,
  required String newVersion,
  required String repoRoot,
  required String runDir,
  bool verbose = false,
}) async {
  print('PRE-RELEASE TRIAGE: Scanning for issues addressed by v$newVersion');
  final stopwatch = Stopwatch()..start();

  final manifest = <String, dynamic>{
    'version': newVersion,
    'prev_tag': prevTag,
    'github_issues': <Map<String, dynamic>>[],
    'sentry_issues': <Map<String, dynamic>>[],
    'cross_repo_issues': <Map<String, dynamic>>[],
    'generated_at': DateTime.now().toIso8601String(),
  };

  // Step 1: Get changed files and commit messages for keyword extraction
  final changedFiles = _runSync('git diff --name-only $prevTag..HEAD', repoRoot);
  final commitMessages = _runSync('git log $prevTag..HEAD --format="%s" --no-merges', repoRoot);

  print('  Changed files: ${changedFiles.split('\n').where((l) => l.isNotEmpty).length}');
  print('  Commits: ${commitMessages.split('\n').where((l) => l.isNotEmpty).length}');

  // Step 2: Search own-repo GitHub issues
  if (config.preReleaseScanGithub) {
    print('  Scanning GitHub issues in ${config.repoOwner}/${config.repoName}...');
    final ghIssues = await _searchGithubIssues(
      owner: config.repoOwner,
      repo: config.repoName,
      changedFiles: changedFiles,
      commitMessages: commitMessages,
      repoRoot: repoRoot,
    );
    (manifest['github_issues'] as List).addAll(ghIssues);
    print('    Found ${ghIssues.length} potentially related issues');
  }

  // Step 3: Search cross-repo issues
  if (config.crossRepoEnabled && config.preReleaseScanGithub) {
    for (final crossRepo in config.crossRepoRepos) {
      print('  Scanning cross-repo issues in ${crossRepo.fullName}...');
      final crossIssues = await _searchGithubIssues(
        owner: crossRepo.owner,
        repo: crossRepo.repo,
        changedFiles: changedFiles,
        commitMessages: commitMessages,
        repoRoot: repoRoot,
      );
      for (final issue in crossIssues) {
        issue['repo'] = crossRepo.fullName;
      }
      (manifest['cross_repo_issues'] as List).addAll(crossIssues);
      print('    Found ${crossIssues.length} potentially related issues');
    }
  }

  // Step 4: Scan Sentry errors (if configured)
  if (config.preReleaseScanSentry && config.sentryOrganization.isNotEmpty) {
    print('  Scanning Sentry errors...');
    final sentryIssues = await _scanSentryErrors(
      changedFiles: changedFiles,
      repoRoot: repoRoot,
      runDir: runDir,
      verbose: verbose,
    );
    (manifest['sentry_issues'] as List).addAll(sentryIssues);
    print('    Found ${sentryIssues.length} potentially related Sentry errors');
  }

  // Step 5: Run Gemini correlation agent to assess confidence scores
  final totalIssues =
      (manifest['github_issues'] as List).length +
      (manifest['sentry_issues'] as List).length +
      (manifest['cross_repo_issues'] as List).length;

  if (totalIssues > 0) {
    print('  Running Gemini Pro to correlate $totalIssues issues with diff...');
    await _correlateWithGemini(
      manifest: manifest,
      prevTag: prevTag,
      repoRoot: repoRoot,
      runDir: runDir,
      verbose: verbose,
    );
  }

  // Generate summary
  final ghCount = (manifest['github_issues'] as List).length;
  final sentryCount = (manifest['sentry_issues'] as List).length;
  final crossCount = (manifest['cross_repo_issues'] as List).length;
  manifest['summary'] =
      'This release likely addresses $ghCount GitHub issues, '
      '$crossCount cross-repo issues, and $sentryCount Sentry errors';

  // Save manifest
  final manifestPath = '$runDir/issue_manifest.json';
  writeJson(manifestPath, manifest);

  stopwatch.stop();
  print('  Manifest saved: $manifestPath');
  print('  Duration: ${stopwatch.elapsed.inSeconds}s');
  print('  Summary: ${manifest['summary']}');

  return manifestPath;
}

// ═══════════════════════════════════════════════════════════════════════════════
// GitHub Issue Scanning
// ═══════════════════════════════════════════════════════════════════════════════

/// Search GitHub issues that may be related to changed files/commits.
Future<List<Map<String, dynamic>>> _searchGithubIssues({
  required String owner,
  required String repo,
  required String changedFiles,
  required String commitMessages,
  required String repoRoot,
}) async {
  final results = <Map<String, dynamic>>[];

  // Extract search keywords from changed files and commits
  final keywords = _extractKeywords(changedFiles, commitMessages);

  for (final keyword in keywords.take(10)) {
    try {
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
        'number,title,body',
        keyword,
      ], workingDirectory: repoRoot);

      if (result.exitCode == 0) {
        final output = (result.stdout as String).trim();
        if (output.isNotEmpty && output != '[]') {
          try {
            final issues = json.decode(output) as List<dynamic>;
            for (final issue in issues) {
              final number = (issue as Map<String, dynamic>)['number'] as int;
              // Deduplicate
              if (!results.any((r) => r['number'] == number)) {
                results.add({
                  'number': number,
                  'title': issue['title'] as String? ?? '',
                  'repo': '$owner/$repo',
                  'confidence': 0.0, // Will be set by Gemini correlation
                  'evidence': 'Matched keyword: $keyword',
                  'category': 'unknown',
                });
              }
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  // Also search for issues directly referenced in commit messages (#N)
  final issueRefs = RegExp(r'#(\d+)').allMatches(commitMessages);
  for (final match in issueRefs) {
    final number = int.parse(match.group(1)!);
    if (!results.any((r) => r['number'] == number)) {
      // Verify the issue exists
      final result = await Process.run('gh', [
        'issue',
        'view',
        '$number',
        '--repo',
        '$owner/$repo',
        '--json',
        'number,title,state',
      ], workingDirectory: repoRoot);
      if (result.exitCode == 0) {
        try {
          final issue = json.decode(result.stdout as String) as Map<String, dynamic>;
          results.add({
            'number': number,
            'title': issue['title'] as String? ?? '',
            'repo': '$owner/$repo',
            'confidence': 0.8, // High confidence -- directly referenced
            'evidence': 'Directly referenced in commit message',
            'category': 'referenced',
          });
        } catch (_) {}
      }
    }
  }

  return results;
}

/// Extract search keywords from changed files and commit messages.
List<String> _extractKeywords(String changedFiles, String commitMessages) {
  final keywords = <String>{};

  // Extract meaningful file path components
  for (final line in changedFiles.split('\n').where((l) => l.isNotEmpty)) {
    final parts = line.split('/');
    // Add the filename without extension
    final fileName = parts.last.replaceAll(RegExp(r'\.\w+$'), '');
    if (fileName.length > 3) keywords.add(fileName);

    // Add parent directory names
    for (final part in parts) {
      if (part.length > 3 && !{'lib', 'src', 'scripts', 'test', 'proto'}.contains(part)) {
        keywords.add(part);
      }
    }
  }

  // Extract key terms from commit messages (skip conventional commit prefixes)
  for (final line in commitMessages.split('\n').where((l) => l.isNotEmpty)) {
    final cleaned = line.replaceAll(RegExp(r'^(feat|fix|docs|chore|refactor|test|perf)(\(.+\))?:\s*'), '');
    final words = cleaned
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 4)
        .where(
          (w) => !{'should', 'could', 'would', 'there', 'their', 'about', 'which', 'these'}.contains(w.toLowerCase()),
        )
        .take(3);
    keywords.addAll(words);
  }

  return keywords.toList();
}

// ═══════════════════════════════════════════════════════════════════════════════
// Sentry Scanning
// ═══════════════════════════════════════════════════════════════════════════════

/// Scan Sentry for recent errors that may be fixed by this release.
Future<List<Map<String, dynamic>>> _scanSentryErrors({
  required String changedFiles,
  required String repoRoot,
  required String runDir,
  bool verbose = false,
}) async {
  // Use Gemini with Sentry MCP to query recent errors
  final hours = config.sentryRecentErrorsHours;
  final org = config.sentryOrganization;
  final projects = config.sentryProjects;

  if (org.isEmpty) return [];

  final projectList = projects.isNotEmpty ? projects.join(', ') : 'all projects';

  final prompt =
      '''
You have access to the Sentry MCP server. Query Sentry for recent errors.

Organization: $org
Projects: $projectList
Time range: last $hours hours

Changed files in this release:
$changedFiles

Instructions:
1. Use the Sentry MCP tools to search for recent unresolved issues
2. For each Sentry issue, check if any of the changed files appear in the stack trace
3. Write a JSON file to $runDir/sentry_scan_results.json with this format:
```json
[
  {
    "id": "PROJECT-123",
    "title": "Error title",
    "project": "project-slug",
    "confidence": 0.7,
    "evidence": "Stack trace references changed_file.dart"
  }
]
```

Only include issues where changed files appear in the stack trace or error message.
Write valid JSON only.
''';

  final runner = GeminiRunner(maxConcurrent: 1, maxRetries: 2, verbose: verbose);
  final task = GeminiTask(
    id: 'sentry-scan',
    prompt: prompt,
    model: config.proModel,
    maxTurns: config.maxTurns,
    workingDirectory: repoRoot,
  );

  final results = await runner.executeBatch([task]);
  if (results.first.success) {
    // Try to read the results file
    final resultsFile = File('$runDir/sentry_scan_results.json');
    if (resultsFile.existsSync()) {
      try {
        final data = json.decode(resultsFile.readAsStringSync());
        if (data is List) {
          return data.cast<Map<String, dynamic>>();
        }
      } catch (_) {}
    }
  }

  return [];
}

// ═══════════════════════════════════════════════════════════════════════════════
// Gemini Correlation
// ═══════════════════════════════════════════════════════════════════════════════

/// Use Gemini Pro to assess confidence scores for issue-to-diff correlations.
Future<void> _correlateWithGemini({
  required Map<String, dynamic> manifest,
  required String prevTag,
  required String repoRoot,
  required String runDir,
  bool verbose = false,
}) async {
  final manifestJson = const JsonEncoder.withIndent('  ').convert(manifest);

  final prompt =
      '''
You are a release correlation agent. Analyze whether code changes in this release
actually fix or address the listed issues.

For each issue in the manifest below, you must:
1. Run `git diff $prevTag..HEAD` to see what changed
2. Read the issue descriptions to understand what they report
3. Assess whether the diff actually fixes the issue
4. Assign a confidence score (0.0-1.0) and a category

Confidence guide:
- 0.9-1.0: The diff clearly and directly fixes this exact issue
- 0.7-0.8: The diff very likely addresses this issue
- 0.5-0.6: The diff is related but may not fully fix it
- 0.0-0.4: Weak or no connection between the diff and this issue

Categories: "fixed", "improved", "related", "unrelated"

Current issue manifest:
$manifestJson

Write the UPDATED manifest (with confidence scores and categories filled in)
to $runDir/issue_manifest.json. Keep the same JSON structure, just update
the "confidence", "evidence", and "category" fields for each issue.

Remove any issues with confidence < 0.3 (clearly unrelated).
Write valid JSON only.
''';

  final runner = GeminiRunner(maxConcurrent: 1, maxRetries: 2, verbose: verbose);
  final task = GeminiTask(
    id: 'correlation',
    prompt: prompt,
    model: config.proModel,
    maxTurns: config.maxTurns,
    workingDirectory: repoRoot,
    allowedTools: ['run_shell_command(git)', 'run_shell_command(gh)'],
  );

  final results = await runner.executeBatch([task]);

  // If Gemini wrote an updated manifest, it replaces our initial one.
  // If not, the initial manifest (with 0.0 confidence) remains.
  if (results.first.success) {
    final updatedFile = File('$runDir/issue_manifest.json');
    if (updatedFile.existsSync()) {
      try {
        final updated = json.decode(updatedFile.readAsStringSync()) as Map<String, dynamic>;
        // Merge updated data back into our manifest
        if (updated.containsKey('github_issues')) {
          manifest['github_issues'] = updated['github_issues'];
        }
        if (updated.containsKey('sentry_issues')) {
          manifest['sentry_issues'] = updated['sentry_issues'];
        }
        if (updated.containsKey('cross_repo_issues')) {
          manifest['cross_repo_issues'] = updated['cross_repo_issues'];
        }
      } catch (e) {
        print('  Warning: Could not parse Gemini correlation output: $e');
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Utilities
// ═══════════════════════════════════════════════════════════════════════════════

String _runSync(String command, String workingDirectory) {
  final result = Process.runSync('sh', ['-c', command], workingDirectory: workingDirectory);
  return (result.stdout as String).trim();
}
