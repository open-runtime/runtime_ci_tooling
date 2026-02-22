import 'dart:io';

import '../../triage/utils/config.dart';

/// Step summary utilities for GitHub Actions.
abstract final class StepSummary {
  /// Write a markdown summary to $GITHUB_STEP_SUMMARY (visible in Actions UI).
  /// No-op when running locally (env var not set).
  static void write(String markdown) {
    final summaryFile = Platform.environment['GITHUB_STEP_SUMMARY'];
    if (summaryFile != null) {
      File(summaryFile).writeAsStringSync(markdown, mode: FileMode.append);
    }
  }

  /// Build a link to the current workflow run's artifacts page.
  static String artifactLink([String label = 'View all artifacts']) {
    final server = Platform.environment['GITHUB_SERVER_URL'] ?? 'https://github.com';
    final repo = Platform.environment['GITHUB_REPOSITORY'];
    final runId = Platform.environment['GITHUB_RUN_ID'];
    if (repo == null || runId == null) return '';
    return '[$label]($server/$repo/actions/runs/$runId)';
  }

  /// Build a GitHub compare link between two refs.
  static String compareLink(String prevTag, String newTag, [String? label]) {
    final server = Platform.environment['GITHUB_SERVER_URL'] ?? 'https://github.com';
    final repo = Platform.environment['GITHUB_REPOSITORY'] ?? '${config.repoOwner}/${config.repoName}';
    final text = label ?? '$prevTag...$newTag';
    return '[$text]($server/$repo/compare/$prevTag...$newTag)';
  }

  /// Build a link to a file/path in the repository.
  static String ghLink(String label, String path) {
    final server = Platform.environment['GITHUB_SERVER_URL'] ?? 'https://github.com';
    final repo = Platform.environment['GITHUB_REPOSITORY'] ?? '${config.repoOwner}/${config.repoName}';
    final sha = Platform.environment['GITHUB_SHA'] ?? 'main';
    return '[$label]($server/$repo/blob/$sha/$path)';
  }

  /// Build a link to a GitHub Release by tag.
  static String releaseLink(String tag) {
    final server = Platform.environment['GITHUB_SERVER_URL'] ?? 'https://github.com';
    final repo = Platform.environment['GITHUB_REPOSITORY'] ?? '${config.repoOwner}/${config.repoName}';
    return '[v$tag]($server/$repo/releases/tag/$tag)';
  }

  /// Wrap content in a collapsible <details> block for step summaries.
  static String collapsible(String title, String content, {bool open = false}) {
    if (content.trim().isEmpty) return '';
    final openAttr = open ? ' open' : '';
    return '\n<details$openAttr>\n<summary>$title</summary>\n\n$content\n\n</details>\n';
  }
}
