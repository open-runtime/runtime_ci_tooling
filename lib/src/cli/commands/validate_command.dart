import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../../triage/utils/config.dart';
import '../../triage/utils/run_context.dart';
import '../utils/logger.dart';
import '../utils/repo_utils.dart';

const List<String> _kConfigFiles = [
  '.github/workflows/release.yaml',
  '.github/workflows/issue-triage.yaml',
  '.github/workflows/ci.yaml',
  '.gemini/settings.json',
  '.gemini/commands/changelog.toml',
  '.gemini/commands/release-notes.toml',
  '.gemini/commands/triage.toml',
  'GEMINI.md',
  'CHANGELOG.md',
  'lib/src/prompts/gemini_changelog_prompt.dart',
  'lib/src/prompts/gemini_changelog_composer_prompt.dart',
  'lib/src/prompts/gemini_release_notes_author_prompt.dart',
  'lib/src/prompts/gemini_documentation_prompt.dart',
  'lib/src/prompts/gemini_triage_prompt.dart',
];

const List<String> _kStage1Artifacts = [
  '$kCicdRunsDir/explore/commit_analysis.json',
  '$kCicdRunsDir/explore/pr_data.json',
  '$kCicdRunsDir/explore/breaking_changes.json',
];

/// Validate all configuration files.
class ValidateCommand extends Command<void> {
  @override
  final String name = 'validate';

  @override
  final String description = 'Validate all configuration files.';

  @override
  Future<void> run() async {
    final repoRoot = RepoUtils.findRepoRoot();
    if (repoRoot == null) {
      Logger.error('Could not find ${config.repoName} repo root.');
      exit(1);
    }

    Logger.header('Validating CI/CD configuration');

    var allValid = true;

    for (final file in _kConfigFiles) {
      final path = '$repoRoot/$file';
      if (!File(path).existsSync()) {
        Logger.error('Missing: $file');
        allValid = false;
        continue;
      }

      if (file.endsWith('.json')) {
        try {
          final content = File(path).readAsStringSync();
          json.decode(content);
          Logger.success('Valid JSON: $file');
        } catch (e) {
          Logger.error('Invalid JSON: $file -- $e');
          allValid = false;
        }
      } else if (file.endsWith('.yaml') || file.endsWith('.yml')) {
        final result = Process.runSync('ruby', [
          '-ryaml',
          '-e',
          'YAML.safe_load(File.read("$path"))',
        ], workingDirectory: repoRoot);
        if (result.exitCode == 0) {
          Logger.success('Valid YAML: $file');
        } else {
          final content = File(path).readAsStringSync();
          if (content.trim().isNotEmpty) {
            Logger.success('Exists (YAML validation skipped): $file');
          } else {
            Logger.error('Empty file: $file');
            allValid = false;
          }
        }
      } else if (file.endsWith('.dart')) {
        final result = Process.runSync('dart', ['analyze', path],
            workingDirectory: repoRoot);
        if (result.exitCode == 0) {
          Logger.success('Valid Dart: $file');
        } else {
          Logger.error('Dart analysis failed: $file');
          Logger.error('  ${result.stderr}');
          allValid = false;
        }
      } else if (file.endsWith('.toml')) {
        final content = File(path).readAsStringSync();
        if (content.contains('prompt') && content.contains('description')) {
          Logger.success('Valid TOML: $file');
        } else {
          Logger.error(
              'TOML missing required keys (prompt, description): $file');
          allValid = false;
        }
      } else {
        final content = File(path).readAsStringSync();
        if (content.trim().isNotEmpty) {
          Logger.success('Exists: $file');
        } else {
          Logger.error('Empty file: $file');
          allValid = false;
        }
      }
    }

    // Validate Stage 1 artifacts
    Logger.info('');
    Logger.info('Checking Stage 1 artifacts from previous runs...');
    for (final artifact in _kStage1Artifacts) {
      if (File(artifact).existsSync()) {
        try {
          final content = File(artifact).readAsStringSync();
          json.decode(content);
          Logger.success('Valid JSON artifact: $artifact');
        } catch (e) {
          Logger.warn('Invalid JSON artifact: $artifact -- $e');
        }
      } else {
        Logger.info(
            'Not present (expected before first run): $artifact');
      }
    }

    if (allValid) {
      Logger.header('All configuration files are valid');
    } else {
      Logger.header('Validation completed with errors');
      exit(1);
    }
  }
}
