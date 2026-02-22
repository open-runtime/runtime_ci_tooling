import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../../triage/utils/config.dart';
import '../../triage/utils/run_context.dart';
import '../utils/logger.dart';

/// Scan the current repo and generate `.runtime_ci/config.json` plus
/// optional scaffolding (CHANGELOG.md, .gitignore entries).
///
/// This command runs BEFORE repo root detection -- it uses CWD directly,
/// since it bootstraps the config that repo root detection depends on.
class InitCommand extends Command<void> {
  @override
  final String name = 'init';

  @override
  final String description = 'Scan repo and generate .runtime_ci/config.json + scaffold workflows.';

  @override
  Future<void> run() async {
    // Init uses CWD directly (no repo root detection -- it creates the config).
    final repoRoot = Directory.current.path;

    Logger.header('Initialize Runtime CI Tooling');

    final configDir = Directory('$repoRoot/$kRuntimeCiDir');
    final configFile = File('$repoRoot/$kConfigFileName');

    final configExists = configFile.existsSync();
    var repaired = 0;

    // -- 1. Auto-detect package name from pubspec.yaml --
    String packageName = 'unknown';
    String packageVersion = '0.0.0';
    final pubspecFile = File('$repoRoot/pubspec.yaml');
    if (pubspecFile.existsSync()) {
      final content = pubspecFile.readAsStringSync();
      final nameMatch = RegExp(r'^name:\s*(\S+)', multiLine: true).firstMatch(content);
      if (nameMatch != null) packageName = nameMatch.group(1)!;
      final versionMatch = RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(content);
      if (versionMatch != null) packageVersion = versionMatch.group(1)!;
      Logger.success('Detected package: $packageName v$packageVersion');
    } else {
      Logger.warn('No pubspec.yaml found at repo root. Using defaults.');
    }

    // -- 2. Auto-detect GitHub owner/org via gh CLI --
    String repoOwner = 'unknown';
    try {
      final ghResult = Process.runSync('gh', [
        'repo',
        'view',
        '--json',
        'owner',
        '-q',
        '.owner.login',
      ], workingDirectory: repoRoot);
      if (ghResult.exitCode == 0) {
        final owner = (ghResult.stdout as String).trim();
        if (owner.isNotEmpty) {
          repoOwner = owner;
          Logger.success('Detected GitHub owner: $repoOwner');
        }
      }
    } catch (_) {}
    if (repoOwner == 'unknown') {
      // Fallback: try parsing git remote
      try {
        final gitResult = Process.runSync('git', ['remote', 'get-url', 'origin'], workingDirectory: repoRoot);
        if (gitResult.exitCode == 0) {
          final url = (gitResult.stdout as String).trim();
          final match = RegExp(r'github\.com[:/]([^/]+)/').firstMatch(url);
          if (match != null) {
            repoOwner = match.group(1)!;
            Logger.success('Detected GitHub owner from remote: $repoOwner');
          }
        }
      } catch (_) {}
    }

    // -- 3. Scan for existing files --
    final hasGithub = Directory('$repoRoot/.github').existsSync();
    final hasGemini = Directory('$repoRoot/.gemini').existsSync();

    // -- 4. Auto-generate area labels from lib/ directory structure --
    final areaLabels = <String>['area/core', 'area/ci-cd', 'area/docs'];
    final libDir = Directory('$repoRoot/lib');
    if (libDir.existsSync()) {
      for (final entity in libDir.listSync()) {
        if (entity is Directory) {
          final dirName = entity.path.split('/').last;
          if (dirName != 'src' && !dirName.startsWith('.')) {
            areaLabels.add('area/$dirName');
          }
        }
      }
      // Also scan lib/src/ one level deep
      final srcDir = Directory('$repoRoot/lib/src');
      if (srcDir.existsSync()) {
        for (final entity in srcDir.listSync()) {
          if (entity is Directory) {
            final dirName = entity.path.split('/').last;
            if (!dirName.startsWith('.')) {
              final label = 'area/$dirName';
              if (!areaLabels.contains(label)) areaLabels.add(label);
            }
          }
        }
      }
    }

    // -- 5. Write .runtime_ci/config.json (skip if already exists) --
    if (!configExists) {
      configDir.createSync(recursive: true);
      final configData = {
        'repository': {
          'name': packageName,
          'owner': repoOwner,
          'triaged_label': 'triaged',
          'changelog_path': 'CHANGELOG.md',
          'release_notes_path': '$kReleaseNotesDir',
        },
        'gcp': {'project': ''},
        'sentry': {
          'organization': '',
          'projects': <String>[],
          'scan_on_pre_release': false,
          'recent_errors_hours': 168,
        },
        'release': {
          'pre_release_scan_sentry': false,
          'pre_release_scan_github': true,
          'post_release_close_own_repo': true,
          'post_release_close_cross_repo': false,
          'post_release_comment_cross_repo': true,
          'post_release_link_sentry': false,
        },
        'cross_repo': {
          'enabled': false,
          'orgs': [repoOwner],
          'repos': <Map<String, String>>[],
          'discovery': {
            'enabled': true,
            'search_orgs': [repoOwner],
          },
        },
        'labels': {
          'type': ['bug', 'feature-request', 'enhancement', 'documentation', 'question'],
          'priority': ['P0-critical', 'P1-high', 'P2-medium', 'P3-low'],
          'area': areaLabels,
        },
        'thresholds': {'auto_close': 0.9, 'suggest_close': 0.7, 'comment': 0.5},
        'agents': {
          'enabled': ['code_analysis', 'pr_correlation', 'duplicate', 'sentiment', 'changelog'],
          'conditional': {
            'changelog': {'require_file': 'CHANGELOG.md'},
          },
        },
        'gemini': {
          'flash_model': 'gemini-3-flash-preview',
          'pro_model': 'gemini-3-1-pro-preview',
          'max_turns': 100,
          'max_concurrent': 4,
          'max_retries': 3,
        },
        'secrets': {
          'gemini_api_key_env': 'GEMINI_API_KEY',
          'github_token_env': ['GH_TOKEN', 'GITHUB_TOKEN', 'GITHUB_PAT'],
          'sentry_token_env': 'SENTRY_ACCESS_TOKEN',
          'gcp_secret_name': '',
        },
      };

      configFile.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(configData)}\n');
      Logger.success('Created $kConfigFileName');
    } else {
      Logger.info('$kConfigFileName already exists (kept as-is)');
    }

    // -- 6. Ensure CHANGELOG.md exists --
    final changelogFile = File('$repoRoot/CHANGELOG.md');
    final hadChangelog = changelogFile.existsSync();
    if (!hadChangelog) {
      changelogFile.writeAsStringSync(
        '# Changelog\n\n'
        'All notable changes to this project will be documented in this file.\n\n'
        'The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),\n'
        'and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).\n',
      );
      Logger.success('Created starter CHANGELOG.md');
      repaired++;
    }

    // -- 7. Ensure .runtime_ci/runs/ is in .gitignore --
    final gitignoreFile = File('$repoRoot/.gitignore');
    if (gitignoreFile.existsSync()) {
      final content = gitignoreFile.readAsStringSync();
      if (!content.contains('.runtime_ci/runs/')) {
        gitignoreFile.writeAsStringSync('$content\n# Runtime CI audit trails (local only)\n.runtime_ci/runs/\n');
        Logger.success('Added .runtime_ci/runs/ to .gitignore');
        repaired++;
      }
    } else {
      gitignoreFile.writeAsStringSync('# Runtime CI audit trails (local only)\n.runtime_ci/runs/\n');
      Logger.success('Created .gitignore with .runtime_ci/runs/');
      repaired++;
    }

    // -- 8. Summary --
    print('');
    Logger.header(configExists ? 'Init Repair Complete' : 'Init Complete');
    if (configExists && repaired == 0) {
      Logger.info('All items present — nothing to repair.');
    } else if (configExists) {
      Logger.info('Repaired $repaired missing item${repaired == 1 ? '' : 's'}.');
    }
    Logger.info('  Config:    $kConfigFileName${configExists ? " (existing)" : ""}');
    Logger.info('  Package:   $packageName');
    Logger.info('  Owner:     $repoOwner');
    Logger.info('  Areas:     ${areaLabels.join(", ")}');
    Logger.info('  Changelog: ${hadChangelog ? "found" : "created"}');
    Logger.info('  .github/:  ${hasGithub ? "exists (not overwritten)" : "not found"}');
    Logger.info('  .gemini/:  ${hasGemini ? "exists (not overwritten)" : "not found"}');
    print('');
    if (!configExists) {
      Logger.info('Next steps:');
      Logger.info('  1. Review .runtime_ci/config.json and customize area labels, cross-repo, etc.');
      Logger.info('  2. Add runtime_ci_tooling as a dev_dependency in pubspec.yaml');
      Logger.info('  3. Run: dart run runtime_ci_tooling:manage_cicd setup');
      Logger.info('  4. Run: dart run runtime_ci_tooling:manage_cicd status');
    }
  }
}
