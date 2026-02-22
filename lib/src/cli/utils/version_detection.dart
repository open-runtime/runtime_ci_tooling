import 'dart:convert';
import 'dart:io';

import '../../triage/utils/config.dart';
import '../../triage/utils/run_context.dart';
import 'logger.dart';
import 'process_runner.dart';

/// Constants used by version detection.
const String kGeminiModel = 'gemini-3-flash-preview';
const String kGeminiProModel = 'gemini-3.1-pro-preview';

/// Version detection and semantic versioning utilities.
abstract final class VersionDetection {
  /// Detect the previous release tag from git history.
  static String detectPrevTag(String repoRoot, {bool verbose = false}) {
    final result = CiProcessRunner.runSync(
      "git tag -l 'v*' --sort=-version:refname | head -1",
      repoRoot,
      verbose: verbose,
    );
    if (result.isEmpty) {
      // No tags yet -- use the first commit
      return CiProcessRunner.runSync('git rev-list --max-parents=0 HEAD | head -1', repoRoot, verbose: verbose);
    }
    return result;
  }

  /// Detect the next semantic version based on commit history analysis.
  static String detectNextVersion(String repoRoot, String prevTag, {bool verbose = false}) {
    final currentVersion = CiProcessRunner.runSync(
      "awk '/^version:/{print \$2}' pubspec.yaml",
      repoRoot,
      verbose: verbose,
    );

    // Derive bump base from prevTag (not pubspec.yaml) to avoid stale-version
    // collisions.
    final tagVersion = prevTag.startsWith('v') ? prevTag.substring(1) : prevTag;
    final parts = tagVersion.split('.');
    if (parts.length != 3 || parts.any((p) => int.tryParse(p) == null)) {
      // prevTag is not a semver tag -- fall back to pubspec
      final pubParts = currentVersion.split('.');
      if (pubParts.length != 3) return currentVersion;
      parts
        ..clear()
        ..addAll(pubParts);
    }

    var major = int.tryParse(parts[0]) ?? 0;
    var minor = int.tryParse(parts[1]) ?? 0;
    var patch = int.tryParse(parts[2]) ?? 0;

    // ── Pass 1: Fast regex heuristic ──
    final commits = CiProcessRunner.runSync(
      'git log "$prevTag"..HEAD --pretty=format:"%s%n%b" 2>/dev/null',
      repoRoot,
      verbose: verbose,
    );
    var bump = 'patch';
    if (RegExp(r'(BREAKING CHANGE|^[a-z]+(\(.+\))?!:)', multiLine: true).hasMatch(commits)) {
      bump = 'major';
    } else if (RegExp(r'^feat(\(.+\))?:', multiLine: true).hasMatch(commits)) {
      bump = 'minor';
    }

    Logger.info('  Regex heuristic: $bump');

    // ── Pass 2: Gemini analysis (overrides regex if available) ──
    if (CiProcessRunner.commandExists('gemini') && Platform.environment['GEMINI_API_KEY'] != null) {
      final commitCount = CiProcessRunner.runSync(
        'git rev-list --count "$prevTag"..HEAD 2>/dev/null',
        repoRoot,
        verbose: verbose,
      );
      final changedFiles = CiProcessRunner.runSync(
        'git diff --name-only "$prevTag"..HEAD 2>/dev/null | head -30',
        repoRoot,
        verbose: verbose,
      );
      final diffStat = CiProcessRunner.runSync(
        'git diff --stat "$prevTag"..HEAD 2>/dev/null | tail -5',
        repoRoot,
        verbose: verbose,
      );
      final existingTags = CiProcessRunner.runSync(
        "git tag -l 'v*' --sort=-version:refname | head -10",
        repoRoot,
        verbose: verbose,
      );
      final commitSummary = commits.split('\n').take(50).join('\n');

      final versionAnalysisDir = Directory('$repoRoot/$kCicdRunsDir/version_analysis');
      versionAnalysisDir.createSync(recursive: true);
      final bumpJsonPath = '${versionAnalysisDir.path}/version_bump.json';
      final prompt =
          'You are a semantic versioning expert analyzing the ${config.repoName} '
          'Dart package.\n\n'
          'Current version (pubspec.yaml): $currentVersion\n'
          'Previous release tag: $prevTag\n'
          'Existing tags:\n$existingTags\n\n'
          'Commits since last release: $commitCount\n\n'
          'Commit messages:\n$commitSummary\n\n'
          'Changed files:\n$changedFiles\n\n'
          'Diff statistics:\n$diffStat\n\n'
          '## Instructions\n\n'
          '1. Run `git diff $prevTag..HEAD` to see the full diff\n'
          '2. Examine changed files for API surface changes\n'
          '3. Check if any public APIs were broken, removed, or changed incompatibly\n'
          '4. Assess the overall scope\n\n'
          '## Write TWO files:\n\n'
          '### File 1: .runtime_ci/runs/version_analysis/version_bump.json\n'
          '```json\n{"bump": "major|minor|patch|none"}\n```\n\n'
          '### File 2: .runtime_ci/runs/version_analysis/version_bump_rationale.md\n'
          'A markdown document explaining the decision with:\n'
          '- **Decision**: major/minor/patch/none and why\n'
          '- **Key Changes**: Bullet list of significant changes\n'
          '- **Breaking Changes** (if any)\n'
          '- **New Features** (if any)\n'
          '- **References**: Relevant PRs and commits\n\n'
          'Rules:\n'
          '- MAJOR: Breaking changes to public APIs, removed functions, changed signatures\n'
          '- MINOR: New features, new proto messages, new exports, additive API changes\n'
          '- PATCH: Bug fixes, chore/maintenance, CI changes, style, docs, build config, '
          'test improvements, dependency updates, refactors, performance improvements — '
          'anything that reaches this pipeline has already passed pre-check filtering '
          'of bot commits, so every commit warrants at least a patch release.\n'
          '- NONE: Do not use. Every commit that reaches this analysis requires a release.\n\n'
          'IMPORTANT: The next version will be computed by bumping from the '
          'previous tag ($prevTag), NOT from the pubspec.yaml version. '
          'Your job is ONLY to decide the bump type.\n';

      final promptPath = '${versionAnalysisDir.path}/prompt.txt';
      File(promptPath).writeAsStringSync(prompt);
      final geminiResult = CiProcessRunner.runSync(
        'cat $promptPath | gemini '
        '-o json --yolo '
        '-m $kGeminiProModel '
        "--allowed-tools 'run_shell_command(git),run_shell_command(gh)' "
        '2>/dev/null',
        repoRoot,
        verbose: verbose,
      );

      // Save Gemini response for audit trail (strip MCP/warning prefix)
      if (geminiResult.isNotEmpty) {
        final jsonStart = geminiResult.indexOf('{');
        final cleaned = jsonStart > 0 ? geminiResult.substring(jsonStart) : geminiResult;
        File('${versionAnalysisDir.path}/gemini_response.json').writeAsStringSync(cleaned);
      }

      if (geminiResult.isNotEmpty && File(bumpJsonPath).existsSync()) {
        try {
          final bumpData = json.decode(File(bumpJsonPath).readAsStringSync()) as Map<String, dynamic>;
          final rawBump = (bumpData['bump'] as String?)?.trim().toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
          if (rawBump == 'major' || rawBump == 'minor' || rawBump == 'patch' || rawBump == 'none') {
            Logger.info('  Gemini analysis: $rawBump (overriding regex: $bump)');
            bump = rawBump!;
          } else {
            Logger.info('  Gemini returned unexpected: "$rawBump", using regex: $bump');
          }
        } catch (e) {
          Logger.info('  Gemini parse error: $e, using regex: $bump');
        }
      } else {
        Logger.info('  Gemini unavailable, using regex: $bump');
      }
    } else {
      Logger.info('  Gemini not available for version analysis, using regex heuristic');
    }

    // If no release is needed, return the current version unchanged
    if (bump == 'none') {
      Logger.info('  No release needed (bump=none)');
      return currentVersion;
    }

    // Apply the bump
    switch (bump) {
      case 'major':
        major++;
        minor = 0;
        patch = 0;
      case 'minor':
        minor++;
        patch = 0;
      case 'patch':
        patch++;
    }

    final nextVersion = '$major.$minor.$patch';

    // Guard: ensure version never goes backward
    if (compareVersions(nextVersion, currentVersion) < 0) {
      Logger.warn('Version regression detected: $nextVersion < $currentVersion. Using $currentVersion.');
      return currentVersion;
    }

    Logger.info('  Bump type: $bump (from $prevTag) -> $nextVersion');
    return nextVersion;
  }

  /// Compare two semver versions. Returns negative if a < b, 0 if equal,
  /// positive if a > b.
  static int compareVersions(String a, String b) {
    final aParts = a.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final bParts = b.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    for (var i = 0; i < 3; i++) {
      final av = i < aParts.length ? aParts[i] : 0;
      final bv = i < bParts.length ? bParts[i] : 0;
      if (av != bv) return av - bv;
    }
    return 0;
  }
}
