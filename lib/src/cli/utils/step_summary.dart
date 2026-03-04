import 'dart:convert';
import 'dart:io';

import '../../triage/utils/config.dart';
import 'logger.dart';
import 'repo_utils.dart';

/// Step summary utilities for GitHub Actions.
abstract final class StepSummary {
  /// Maximum safe size for $GITHUB_STEP_SUMMARY (1 MiB minus 4 KiB buffer).
  static const int _maxSummaryBytes = (1024 * 1024) - (4 * 1024);
  static final RegExp _repoSlugPattern = RegExp(r'^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$');
  static final RegExp _numericPattern = RegExp(r'^\d+$');
  static final RegExp _refPattern = RegExp(r'^[A-Za-z0-9._/-]+$');

  /// Write a markdown summary to $GITHUB_STEP_SUMMARY (visible in Actions UI).
  /// No-op when running locally (env var not set).
  /// Skips appending if the file would exceed the 1 MiB GitHub limit.
  /// [environment] overrides Platform.environment (for testing).
  static void write(String markdown, {Map<String, String>? environment}) {
    final env = environment ?? Platform.environment;
    final summaryFile = env['GITHUB_STEP_SUMMARY'];
    if (summaryFile == null || summaryFile.trim().isEmpty) return;
    if (RepoUtils.isSymlinkPath(summaryFile)) {
      Logger.warn('Refusing to write step summary through symlink: $summaryFile');
      return;
    }
    final file = File(summaryFile);
    final currentSize = file.existsSync() ? file.lengthSync() : 0;
    // Use UTF-8 byte length (not markdown.length) — GitHub limit is 1 MiB.
    final markdownBytes = utf8.encode(markdown).length;
    if (currentSize + markdownBytes > _maxSummaryBytes) {
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
    final server = _safeGitHubServerUrl(Platform.environment['GITHUB_SERVER_URL']);
    final repo = _safeRepoSlug(Platform.environment['GITHUB_REPOSITORY']);
    final runId = Platform.environment['GITHUB_RUN_ID'];
    if (repo == null || runId == null) return '';
    if (!_numericPattern.hasMatch(runId)) return '';
    return '[$label]($server/$repo/actions/runs/$runId)';
  }

  /// Build a GitHub compare link between two refs.
  static String compareLink(String prevTag, String newTag, [String? label]) {
    final server = _safeGitHubServerUrl(Platform.environment['GITHUB_SERVER_URL']);
    final repo = _safeRepoSlug(Platform.environment['GITHUB_REPOSITORY']) ?? '${config.repoOwner}/${config.repoName}';
    final text = label ?? '$prevTag...$newTag';
    return '[$text]($server/$repo/compare/$prevTag...$newTag)';
  }

  /// Build a link to a file/path in the repository.
  static String ghLink(String label, String path) {
    final server = _safeGitHubServerUrl(Platform.environment['GITHUB_SERVER_URL']);
    final repo = _safeRepoSlug(Platform.environment['GITHUB_REPOSITORY']) ?? '${config.repoOwner}/${config.repoName}';
    final sha = _safeRef(Platform.environment['GITHUB_SHA']) ?? 'main';
    return '[$label]($server/$repo/blob/$sha/$path)';
  }

  /// Build a link to a GitHub Release by tag.
  static String releaseLink(String tag) {
    final server = _safeGitHubServerUrl(Platform.environment['GITHUB_SERVER_URL']);
    final repo = _safeRepoSlug(Platform.environment['GITHUB_REPOSITORY']) ?? '${config.repoOwner}/${config.repoName}';
    return '[v$tag]($server/$repo/releases/tag/$tag)';
  }

  /// Wrap content in a collapsible <details> block for step summaries.
  /// Escapes title and content to prevent HTML injection (e.g. closing tags like
  /// </details>) from breaking structure or executing unsafe HTML.
  static String collapsible(String title, String content, {bool open = false}) {
    if (content.trim().isEmpty) return '';
    final openAttr = open ? ' open' : '';
    final safeTitle = escapeHtml(title);
    // Escape content to prevent </details>, </summary>, <script>, etc. from breaking
    // the collapsible structure or injecting unsafe HTML.
    final safeContent = escapeHtml(content);
    return '\n<details$openAttr>\n<summary>$safeTitle</summary>\n\n$safeContent\n\n</details>\n';
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

  static String _safeGitHubServerUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'https://github.com';
    final parsed = Uri.tryParse(raw.trim());
    if (parsed == null || !parsed.isAbsolute) return 'https://github.com';
    if (parsed.scheme != 'https' && parsed.scheme != 'http') return 'https://github.com';
    if (parsed.host.isEmpty || parsed.userInfo.isNotEmpty) return 'https://github.com';
    final cleanPath = parsed.path.endsWith('/') ? parsed.path.substring(0, parsed.path.length - 1) : parsed.path;
    return '${parsed.scheme}://${parsed.host}${parsed.hasPort ? ':${parsed.port}' : ''}$cleanPath';
  }

  static String? _safeRepoSlug(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final trimmed = raw.trim();
    if (!_repoSlugPattern.hasMatch(trimmed)) return null;
    return trimmed;
  }

  static String? _safeRef(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final trimmed = raw.trim();
    if (!_refPattern.hasMatch(trimmed)) return null;
    return trimmed;
  }
}
