import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../../triage/utils/config.dart';
import '../../triage/utils/run_context.dart';
import '../utils/autodoc_scaffold.dart';
import '../utils/hook_installer.dart';
import '../utils/language_support.dart';
import '../utils/logger.dart';

/// Scan the current repo and generate `.runtime_ci/config.json`,
/// `.runtime_ci/autodoc.json`, plus optional scaffolding (CHANGELOG.md,
/// .gitignore entries).
///
/// This command runs BEFORE repo root detection -- it uses CWD directly,
/// since it bootstraps the config that repo root detection depends on.
class InitCommand extends Command<void> {
  InitCommand() {
    argParser.addOption(
      'language',
      abbr: 'l',
      help: 'Project language (auto-detected if not specified)',
      allowed: ['dart', 'flutter', 'typescript'],
    );
  }

  @override
  final String name = 'init';

  @override
  final String description = 'Scan repo and generate .runtime_ci/config.json + autodoc.json + scaffold workflows.';

  @override
  Future<void> run() async {
    // Init uses CWD directly (no repo root detection -- it creates the config).
    final repoRoot = Directory.current.path;

    Logger.header('Initialize Runtime CI Tooling');

    final configDir = Directory('$repoRoot/$kRuntimeCiDir');
    final configFile = File('$repoRoot/$kConfigFileName');

    final configExists = configFile.existsSync();
    var repaired = 0;

    // -- 1. Detect project language --
    final languageOverride = argResults?['language'] as String?;
    final detectedLanguage = languageOverride ?? _detectLanguage(repoRoot);
    final language = resolveLanguage(detectedLanguage);
    if (languageOverride != null) {
      Logger.success('Using specified language: ${language.displayName}');
    } else {
      Logger.success('Auto-detected language: ${language.displayName}');
    }

    // -- 2. Auto-detect package name from manifest --
    String packageName = 'unknown';
    String packageVersion = '0.0.0';
    final pubspecFile = File('$repoRoot/pubspec.yaml');
    final packageJsonFile = File('$repoRoot/package.json');
    if (pubspecFile.existsSync()) {
      final content = pubspecFile.readAsStringSync();
      final nameMatch = RegExp(r'^name:\s*(\S+)', multiLine: true).firstMatch(content);
      if (nameMatch != null) packageName = nameMatch.group(1)!;
      final versionMatch = RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(content);
      if (versionMatch != null) packageVersion = versionMatch.group(1)!;
      Logger.success('Detected package: $packageName v$packageVersion');
    } else if (packageJsonFile.existsSync()) {
      try {
        final content = packageJsonFile.readAsStringSync();
        final data = json.decode(content) as Map<String, dynamic>;
        final name = data['name'] as String?;
        if (name != null && name.isNotEmpty) packageName = name;
        final version = data['version'] as String?;
        if (version != null && version.isNotEmpty) packageVersion = version;
        Logger.success('Detected package: $packageName v$packageVersion');
      } catch (e) {
        Logger.warn('Could not parse package.json: $e');
      }
    } else {
      Logger.warn('No ${language.manifestFile} found at repo root. Using defaults.');
    }

    // -- 3. Auto-detect GitHub owner/org via gh CLI --
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
    } catch (e) {
      Logger.warn('Could not detect GitHub owner via gh CLI: $e');
    }
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
      } catch (e) {
        Logger.warn('Could not detect GitHub owner from git remote: $e');
      }
    }

    // -- 4. Scan for existing files --
    final hasGithub = Directory('$repoRoot/.github').existsSync();
    final hasGemini = Directory('$repoRoot/.gemini').existsSync();

    // -- 5. Auto-generate area labels from lib/ directory structure --
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

    // -- 6. Write .runtime_ci/config.json (skip if already exists) --
    if (!configExists) {
      configDir.createSync(recursive: true);
      final ciSection = _buildCiSection(detectedLanguage);
      final configData = {
        'repository': {
          'name': packageName,
          'owner': repoOwner,
          'triaged_label': 'triaged',
          'changelog_path': 'CHANGELOG.md',
          'release_notes_path': '$kReleaseNotesDir',
        },
        'ci': ciSection,
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
          'pro_model': 'gemini-3.1-pro-preview',
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

    // -- 7. Generate .runtime_ci/autodoc.json (skip if already exists) --
    final autodocFile = File('$repoRoot/$kRuntimeCiDir/autodoc.json');
    final autodocExists = autodocFile.existsSync();
    if (!autodocExists) {
      final created = scaffoldAutodocJson(repoRoot);
      if (created) {
        Logger.success('Created $kRuntimeCiDir/autodoc.json');
      } else {
        Logger.warn('No lib/ directory found -- skipping autodoc.json');
      }
    } else {
      Logger.info('$kRuntimeCiDir/autodoc.json already exists (kept as-is)');
    }

    // -- 8. Ensure CHANGELOG.md exists --
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

    // -- 9. Install git pre-commit hook --
    final hookInstalled = HookInstaller.install(repoRoot);
    if (hookInstalled) repaired++;

    // -- 10. Ensure .runtime_ci/runs/ is in .gitignore --
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

    // -- 11. Summary --
    print('');
    Logger.header(configExists && autodocExists ? 'Init Repair Complete' : 'Init Complete');
    if (configExists && autodocExists && repaired == 0) {
      Logger.info('All items present — nothing to repair.');
    } else if (configExists && autodocExists) {
      Logger.info('Repaired $repaired missing item${repaired == 1 ? '' : 's'}.');
    }
    Logger.info('  Config:    $kConfigFileName${configExists ? " (existing)" : ""}');
    Logger.info('  Autodoc:   $kRuntimeCiDir/autodoc.json${autodocExists ? " (existing)" : ""}');
    Logger.info('  Language:  ${language.displayName}${languageOverride != null ? " (override)" : " (auto)"}');
    Logger.info('  Package:   $packageName');
    Logger.info('  Owner:     $repoOwner');
    Logger.info('  Areas:     ${areaLabels.join(", ")}');
    Logger.info('  Changelog: ${hadChangelog ? "found" : "created"}');
    Logger.info('  Hook:      ${hookInstalled ? "installed .git/hooks/pre-commit" : "skipped (no .git/hooks)"}');
    Logger.info('  .github/:  ${hasGithub ? "exists (not overwritten)" : "not found"}');
    Logger.info('  .gemini/:  ${hasGemini ? "exists (not overwritten)" : "not found"}');
    print('');
    if (!configExists) {
      Logger.info('Next steps:');
      Logger.info('  1. Review .runtime_ci/config.json and customize area labels, cross-repo, etc.');
      if (detectedLanguage == 'typescript') {
        Logger.info('  2. Run: npx runtime-ci-tooling setup');
      } else {
        Logger.info('  2. Add runtime_ci_tooling as a dev_dependency in pubspec.yaml');
        Logger.info('  3. Run: dart run runtime_ci_tooling:manage_cicd setup');
        Logger.info('  4. Run: dart run runtime_ci_tooling:manage_cicd status');
      }
    }
  }

  /// Auto-detect the project language from manifest files at [repoRoot].
  ///
  /// Detection order:
  ///   1. `package.json` exists → `"typescript"`
  ///   2. `pubspec.yaml` exists and contains `sdk: flutter` → `"flutter"`
  ///   3. `pubspec.yaml` exists → `"dart"`
  ///   4. Fallback → `"dart"`
  String _detectLanguage(String repoRoot) {
    final packageJson = File('$repoRoot/package.json');
    if (packageJson.existsSync()) return 'typescript';

    final pubspec = File('$repoRoot/pubspec.yaml');
    if (pubspec.existsSync()) {
      final content = pubspec.readAsStringSync();
      // Match `sdk: flutter` in the dependencies or environment section.
      if (RegExp(r'sdk:\s*flutter').hasMatch(content)) return 'flutter';
      return 'dart';
    }

    return 'dart';
  }

  /// Build the `ci` section of the config based on the detected [language].
  Map<String, dynamic> _buildCiSection(String language) {
    final base = <String, dynamic>{
      'language': language,
      'personal_access_token_secret': 'GITHUB_TOKEN',
      'artifact_retention_days': 7,
      'features': {'lfs': false, 'format_check': true},
      'secrets': <String, dynamic>{},
    };

    switch (language) {
      case 'typescript':
        base['typescript'] = {'node_version': '22', 'package_manager': 'pnpm'};
        base['features'] = {
          ...(base['features'] as Map<String, dynamic>),
          'analysis_cache': false,
          'managed_analyze': false,
          'managed_test': false,
        };
      case 'flutter':
        base['dart_sdk'] = '3.9.2';
        base['line_length'] = 120;
        base['features'] = {
          ...(base['features'] as Map<String, dynamic>),
          'proto': false,
          'analysis_cache': true,
          'managed_analyze': true,
          'managed_test': true,
          'build_runner': false,
          'web_test': false,
        };
        base['sub_packages'] = <String>[];
      case 'dart':
      default:
        base['dart_sdk'] = '3.9.2';
        base['line_length'] = 120;
        base['features'] = {
          ...(base['features'] as Map<String, dynamic>),
          'proto': false,
          'analysis_cache': true,
          'managed_analyze': true,
          'managed_test': true,
          'build_runner': false,
          'web_test': false,
        };
        base['sub_packages'] = <String>[];
    }

    return base;
  }
}
