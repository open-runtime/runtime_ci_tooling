import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../../triage/utils/config.dart';
import '../../triage/utils/run_context.dart';
import '../manage_cicd_cli.dart';
import '../options/version_options.dart';
import '../utils/gemini_utils.dart';
import '../utils/logger.dart';
import '../utils/process_runner.dart';
import '../utils/prompt_resolver.dart';
import '../utils/release_utils.dart';
import '../utils/repo_utils.dart';
import '../utils/step_summary.dart';
import '../utils/version_detection.dart';

const String _kGeminiProModel = 'gemini-3-pro-preview';

/// Stage 2: Changelog Composer.
///
/// Updates CHANGELOG.md and README.md only. Release notes are handled
/// separately by Stage 3 (release-notes command).
/// Gracefully skips if Gemini is unavailable.
class ComposeCommand extends Command<void> {
  @override
  final String name = 'compose';

  @override
  final String description = 'Run Stage 2 Changelog Composer (Gemini Pro).';

  ComposeCommand() {
    VersionOptionsArgParser.populateParser(argParser);
  }

  @override
  Future<void> run() async {
    final repoRoot = RepoUtils.findRepoRoot();
    if (repoRoot == null) {
      Logger.error('Could not find ${config.repoName} repo root.');
      exit(1);
    }
    final global = ManageCicdCli.parseGlobalOptions(globalResults);
    final versionOpts = VersionOptions.fromArgResults(argResults!);

    Logger.header('Stage 2: Changelog Composer (Gemini Pro)');

    if (!GeminiUtils.geminiAvailable(warnOnly: true)) {
      Logger.warn('Skipping changelog composition (Gemini unavailable).');
      return;
    }

    final ctx = RunContext.create(repoRoot, 'compose');
    final prevTag = versionOpts.prevTag ?? VersionDetection.detectPrevTag(repoRoot, verbose: global.verbose);
    final newVersion =
        versionOpts.version ?? VersionDetection.detectNextVersion(repoRoot, prevTag, verbose: global.verbose);

    Logger.info('Previous tag: $prevTag');
    Logger.info('New version: $newVersion');
    Logger.info('Run dir: ${ctx.runDir}');

    // Generate prompt via Dart template
    final composerScript = PromptResolver.promptScript('gemini_changelog_composer_prompt.dart');
    Logger.info('Generating composer prompt from $composerScript...');
    if (!File(composerScript).existsSync()) {
      Logger.error('Prompt script not found: $composerScript');
      exit(1);
    }
    final prompt = CiProcessRunner.runSync(
      'dart run $composerScript "$prevTag" "$newVersion"',
      repoRoot,
      verbose: global.verbose,
    );
    if (prompt.isEmpty) {
      Logger.error('Composer prompt generator produced empty output.');
      exit(1);
    }
    ctx.savePrompt('compose', prompt);

    if (global.dryRun) {
      Logger.info('[DRY-RUN] Would run Gemini CLI with composer prompt (${prompt.length} chars)');
      return;
    }

    final promptPath = ctx.artifactPath('compose', 'prompt.txt');

    // Build the @ includes for file context.
    final includes = <String>[];
    final artifactNames = ['commit_analysis.json', 'pr_data.json', 'breaking_changes.json'];
    for (final name in artifactNames) {
      if (File('/tmp/$name').existsSync()) {
        includes.add('@/tmp/$name');
      } else if (File('$repoRoot/$kCicdRunsDir/explore/$name').existsSync()) {
        includes.add('@$repoRoot/$kCicdRunsDir/explore/$name');
      }
    }
    // Issue manifest from pre-release-triage
    if (File('/tmp/issue_manifest.json').existsSync()) {
      includes.add('@/tmp/issue_manifest.json');
    }
    final changelogFile = File('$repoRoot/CHANGELOG.md');
    if (!changelogFile.existsSync()) {
      changelogFile.writeAsStringSync(
        '# Changelog\n\n'
        'All notable changes to this project will be documented in this file.\n\n'
        'The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),\n'
        'and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).\n',
      );
      Logger.info('Created starter CHANGELOG.md for compose stage');
    }
    includes.add('@CHANGELOG.md');
    includes.add('@README.md');

    Logger.info('Running Gemini 3 Pro for CHANGELOG composition...');
    Logger.info('File context: ${includes.join(", ")}');

    final result = Process.runSync(
      'sh',
      [
        '-c',
        'cat $promptPath | gemini '
            '-o json --yolo '
            '-m $_kGeminiProModel '
            "--allowed-tools 'run_shell_command(git),run_shell_command(gh)' "
            '${includes.join(" ")}',
      ],
      workingDirectory: repoRoot,
      environment: {...Platform.environment},
    );

    // Handle non-zero exit gracefully
    final rawCompose = result.stdout as String;
    final composeStderr = (result.stderr as String).trim();

    if (result.exitCode != 0) {
      Logger.warn('Gemini CLI exited with code ${result.exitCode}');
      if (composeStderr.isNotEmpty) {
        Logger.warn('  stderr: ${composeStderr.split('\n').first}');
      }
    }

    if (rawCompose.isNotEmpty) {
      ctx.saveResponse('compose', rawCompose);
    }

    try {
      if (rawCompose.contains('{')) {
        final jsonStr = GeminiUtils.extractJson(rawCompose);
        final response = json.decode(jsonStr) as Map<String, dynamic>;
        final stats = response['stats'] as Map<String, dynamic>?;
        Logger.success('Stage 2 completed.');
        if (stats != null) {
          Logger.info('  Tool calls: ${stats['tools']?['totalCalls']}');
          Logger.info('  Duration: ${stats['session']?['duration']}ms');
        }
      } else if (result.exitCode != 0) {
        Logger.warn('Gemini CLI produced no JSON output for compose stage.');
      }
    } catch (e) {
      Logger.warn('Could not parse Gemini response as JSON: $e');
    }

    // Verify CHANGELOG was updated
    String changelogContent = '';
    try {
      if (File('$repoRoot/CHANGELOG.md').existsSync()) {
        changelogContent = File('$repoRoot/CHANGELOG.md').readAsStringSync();
        if (changelogContent.contains('## [$newVersion]')) {
          Logger.success('CHANGELOG.md updated with v$newVersion entry');
        } else {
          Logger.warn('CHANGELOG.md exists but does not contain a [$newVersion] entry');
        }
      }
    } catch (e) {
      Logger.warn('Could not read CHANGELOG.md (encoding error): $e');
      try {
        final bytes = File('$repoRoot/CHANGELOG.md').readAsBytesSync();
        changelogContent = String.fromCharCodes(bytes.where((b) => b < 128));
        Logger.info('Read CHANGELOG.md with ASCII fallback (${changelogContent.length} chars)');
      } catch (_) {
        changelogContent = '';
      }
    }

    // Post-process: add Keep a Changelog reference-style links at the bottom.
    if (changelogContent.isNotEmpty) {
      ReleaseUtils.addChangelogReferenceLinks(repoRoot, changelogContent);
    }

    final clEntryMatch = RegExp(
      r'## \[' + RegExp.escape(newVersion) + r'\].*?(?=## \[|\Z)',
      dotAll: true,
    ).firstMatch(changelogContent);
    final clEntry = clEntryMatch?.group(0)?.trim() ?? '(no entry found)';

    StepSummary.write('''
## Stage 2: Changelog Composer Complete

| Field | Value |
|-------|-------|
| Version | **v$newVersion** |
| CHANGELOG.md | ${changelogContent.contains('## [$newVersion]') ? 'Updated' : 'Not updated'} |
| Gemini model | `$_kGeminiProModel` |

${StepSummary.collapsible('CHANGELOG Entry', '```markdown\n$clEntry\n```', open: true)}

**Next**: Stage 3 (Release Notes Author) generates rich release notes.

${StepSummary.artifactLink()} | ${StepSummary.ghLink('CHANGELOG.md', 'CHANGELOG.md')}
''');

    ctx.finalize();
  }
}
