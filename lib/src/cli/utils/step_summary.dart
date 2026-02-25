import 'dart:io';

import '../../triage/utils/config.dart';
import 'logger.dart';
import 'repo_utils.dart';

/// Step summary utilities for GitHub Actions.
abstract final class StepSummary {
  /// Maximum safe size for $GITHUB_STEP_SUMMARY (1 MiB minus 4 KiB buffer).
  static const int _maxSummaryBytes = (1024 * 1024) - (4 * 1024);

  /// Write a markdown summary to $GITHUB_STEP_SUMMARY (visible in Actions UI).
  /// No-op when running locally (env var not set).
  /// Skips appending if the file would exceed the 1 MiB GitHub limit.
  static void write(String markdown) {
    final summaryFile = Platform.environment['GITHUB_STEP_SUMMARY'];
    if (summaryFile == null || summaryFile.trim().isEmpty) return;
    if (RepoUtils.isSymlinkPath(summaryFile)) {
      Logger.warn('Refusing to write step summary through symlink: $summaryFile');
      return;
    }
    final file = File(summaryFile);
    final currentSize = file.existsSync() ? file.lengthSync() : 0;
    if (currentSize + markdown.length > _maxSummaryBytes) {
      Logger.warn('Step summary approaching 1 MiB limit — skipping append');
      return;
    }
    try {
      RepoUtils.writeFileSafely(summaryFile, markdown, mode: FileMode.append);
    } on FileSystemException catch (e) {
      Logger.warn('Could not write step summary: $e');
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
    final safeTitle = escapeHtml(title);
    return '\n<details$openAttr>\n<summary>$safeTitle</summary>\n\n$content\n\n</details>\n';
  }

  /// Escape HTML special characters for safe embedding in GitHub markdown.
  static String escapeHtml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}
