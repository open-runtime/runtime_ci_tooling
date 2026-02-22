import 'dart:convert';
import 'dart:io';

import '../../triage/utils/config.dart';
import '../../triage/utils/run_context.dart';
import 'logger.dart';
import 'process_runner.dart';

/// Utilities for release management.
abstract final class ReleaseUtils {
  /// Build a rich, detailed commit message for the automated release commit.
  static String buildReleaseCommitMessage({
    required String repoRoot,
    required String version,
    required String prevTag,
    required Directory releaseDir,
    bool verbose = false,
  }) {
    final buf = StringBuffer();

    // Line 1: Subject line with bot prefix and [skip ci]
    buf.writeln('bot(release): v$version [skip ci]');
    buf.writeln();

    // Summary from changelog entry if available
    final changelogEntry = File('${releaseDir.path}/changelog_entry.md');
    if (changelogEntry.existsSync()) {
      final entry = changelogEntry.readAsStringSync().trim();
      if (entry.isNotEmpty) {
        buf.writeln('## Changelog');
        buf.writeln();
        buf.writeln(entry.length > 2000 ? '${entry.substring(0, 2000)}...' : entry);
        buf.writeln();
      }
    }

    // Staged file summary
    final stagedResult = Process.runSync('git', ['diff', '--cached', '--stat'], workingDirectory: repoRoot);
    final stagedStat = (stagedResult.stdout as String).trim();
    if (stagedStat.isNotEmpty) {
      buf.writeln('## Files Modified');
      buf.writeln();
      buf.writeln('```');
      buf.writeln(stagedStat);
      buf.writeln('```');
      buf.writeln();
    }

    // Version bump detail
    final bumpRationale = File('$repoRoot/$kVersionBumpsDir/v$version.md');
    if (bumpRationale.existsSync()) {
      final rationale = bumpRationale.readAsStringSync().trim();
      if (rationale.isNotEmpty) {
        buf.writeln('## Version Bump Rationale');
        buf.writeln();
        buf.writeln(rationale.length > 1000 ? '${rationale.substring(0, 1000)}...' : rationale);
        buf.writeln();
      }
    }

    // Contributors (verified @username from GitHub API)
    final contribFile = File('${releaseDir.path}/contributors.json');
    if (contribFile.existsSync()) {
      try {
        final contribs = json.decode(contribFile.readAsStringSync()) as List;
        if (contribs.isNotEmpty) {
          buf.writeln('## Contributors');
          buf.writeln();
          for (final c in contribs) {
            final entry = c as Map;
            final username = entry['username'] as String? ?? '';
            if (username.isNotEmpty) {
              buf.writeln('- @$username');
            }
          }
          buf.writeln();
        }
      } catch (_) {
        // Skip if parse fails
      }
    }

    // Commit range
    final commitCount = CiProcessRunner.runSync(
      'git rev-list --count "$prevTag"..HEAD 2>/dev/null',
      repoRoot,
      verbose: verbose,
    );
    buf.writeln('---');
    buf.writeln('Automated release by CI/CD pipeline (Gemini CLI + GitHub Actions)');
    buf.writeln('Commits since $prevTag: $commitCount');
    buf.writeln('Generated: ${DateTime.now().toUtc().toIso8601String()}');

    return buf.toString();
  }

  /// Gather VERIFIED contributor usernames scoped to the release commit range.
  static List<Map<String, String>> gatherVerifiedContributors(String repoRoot, String prevTag) {
    final repo = Platform.environment['GITHUB_REPOSITORY'] ?? '${config.repoOwner}/${config.repoName}';

    // Step 1: Get one commit SHA per unique author email
    final gitResult = Process.runSync('sh', [
      '-c',
      'git log "$prevTag"..HEAD --format="%H %ae" --no-merges | sort -u -k2,2',
    ], workingDirectory: repoRoot);

    if (gitResult.exitCode != 0) {
      Logger.warn('Could not get commit authors from git log');
      return [];
    }

    final lines = (gitResult.stdout as String).trim().split('\n').where((l) => l.isNotEmpty);
    final contributors = <Map<String, String>>[];
    final seenLogins = <String>{};

    for (final line in lines) {
      final parts = line.split(' ');
      if (parts.length < 2) continue;
      final sha = parts[0];
      final email = parts[1];

      // Skip bot emails
      if (email.contains('[bot]') || email.contains('noreply.github.com') && email.contains('bot')) {
        continue;
      }

      // Step 2: Resolve SHA to verified GitHub login via commits API
      try {
        final ghResult = Process.runSync('gh', [
          'api',
          'repos/$repo/commits/$sha',
          '--jq',
          '.author.login // empty',
        ], workingDirectory: repoRoot);

        if (ghResult.exitCode == 0) {
          final login = (ghResult.stdout as String).trim();
          if (login.isNotEmpty && !login.contains('[bot]') && !seenLogins.contains(login)) {
            seenLogins.add(login);
            contributors.add({'username': login});
          }
        }
      } catch (_) {
        // API call failed for this SHA, skip
      }
    }

    if (contributors.isEmpty) {
      Logger.warn('No contributors resolved from GitHub API, falling back to git names');
      final names = (gitResult.stdout as String)
          .trim()
          .split('\n')
          .where((l) => l.isNotEmpty && !l.contains('[bot]'))
          .map((l) => l.split(' ').length > 1 ? l.split(' ')[1] : l)
          .toSet()
          .map<Map<String, String>>((email) => {'username': email.split('@').first})
          .toList();
      return names;
    }

    return contributors;
  }

  /// Build fallback release notes from CHANGELOG entry + version bump rationale.
  static String buildFallbackReleaseNotes(String repoRoot, String version, String prevTag) {
    final buf = StringBuffer();
    buf.writeln('# ${config.repoName} v$version');
    buf.writeln();

    // Try version bump rationale
    final bumpFile = File('$repoRoot/$kVersionBumpsDir/v$version.md');
    if (bumpFile.existsSync()) {
      buf.writeln(bumpFile.readAsStringSync());
      buf.writeln();
    }

    // Try CHANGELOG entry
    final changelog = File('$repoRoot/CHANGELOG.md');
    if (changelog.existsSync()) {
      final content = changelog.readAsStringSync();
      final entryMatch = RegExp(
        r'## \[' + RegExp.escape(version) + r'\].*?(?=## \[|\Z)',
        dotAll: true,
      ).firstMatch(content);
      if (entryMatch != null) {
        buf.writeln('## Changelog');
        buf.writeln();
        buf.writeln(entryMatch.group(0)!.trim());
        buf.writeln();
      }
    }

    buf.writeln('---');
    buf.writeln(
      '[Full Changelog](https://github.com/${config.repoOwner}/${config.repoName}/compare/$prevTag...v$version)',
    );

    return buf.toString();
  }

  /// Add Keep a Changelog reference-style links to the bottom of CHANGELOG.md.
  static void addChangelogReferenceLinks(String repoRoot, String content) {
    final server = Platform.environment['GITHUB_SERVER_URL'] ?? 'https://github.com';
    final repo = Platform.environment['GITHUB_REPOSITORY'] ?? '${config.repoOwner}/${config.repoName}';

    // Extract all version headers
    final versionPattern = RegExp(r'^## \[([^\]]+)\]', multiLine: true);
    final matches = versionPattern.allMatches(content).toList();

    if (matches.isEmpty) return;

    final versions = matches.map((m) => m.group(1)!).where((v) => v != 'Unreleased').toList();

    if (versions.isEmpty) return;

    // Build reference-style links
    final links = StringBuffer();
    for (var i = 0; i < versions.length; i++) {
      final version = versions[i];
      if (i + 1 < versions.length) {
        final prevVersion = versions[i + 1];
        links.writeln('[$version]: $server/$repo/compare/v$prevVersion...v$version');
      } else {
        links.writeln('[$version]: $server/$repo/releases/tag/v$version');
      }
    }

    final linksStr = links.toString().trimRight();
    if (linksStr.isEmpty) return;

    // Strip any existing reference-link block
    final existingLinksPattern = RegExp(r'\n*(\[[\w.\-]+\]: https?://[^\n]+\n?)+$');
    var cleaned = content.replaceAll(existingLinksPattern, '');
    cleaned = cleaned.trimRight();

    // Append the new links block
    final updated = '$cleaned\n\n$linksStr\n';
    File('$repoRoot/CHANGELOG.md').writeAsStringSync(updated);
    Logger.success('Added reference-style links to CHANGELOG.md');
  }
}
