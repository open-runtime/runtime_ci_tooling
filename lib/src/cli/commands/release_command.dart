import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../../triage/utils/config.dart';
import '../../triage/utils/run_context.dart';
import '../manage_cicd_cli.dart';
import '../options/global_options.dart';
import '../options/version_options.dart';
import '../utils/file_utils.dart';
import '../utils/gemini_utils.dart';
import '../utils/logger.dart';
import '../utils/process_runner.dart';
import '../utils/prompt_resolver.dart';
import '../utils/release_utils.dart';
import '../utils/repo_utils.dart';
import '../utils/step_summary.dart';
import '../utils/version_detection.dart';

const String _kGeminiProModel = 'gemini-3-pro-preview';

/// Run the full release pipeline locally (version + explore + compose).
class ReleaseCommand extends Command<void> {
  @override
  final String name = 'release';

  @override
  final String description = 'Run the full local release pipeline.';

  ReleaseCommand() {
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

    Logger.header('Full Release Pipeline');

    // Step 1: Version
    await _runVersion(repoRoot, global, versionOpts);

    // Step 2: Explore
    await _runExplore(repoRoot, global, versionOpts);

    // Step 3: Compose
    await _runCompose(repoRoot, global, versionOpts);

    Logger.header('Release pipeline complete');
    Logger.info('Next steps:');
    Logger.info('  1. Review CHANGELOG.md changes');
    Logger.info('  2. Review /tmp/release_notes_body.md');
    Logger.info('  3. Commit and push to main to trigger CI/CD');
  }

  /// Inline version detection (from _runVersion).
  Future<void> _runVersion(String repoRoot, GlobalOptions global, VersionOptions versionOpts) async {
    Logger.header('Version Detection');

    final prevTag = versionOpts.prevTag ?? VersionDetection.detectPrevTag(repoRoot, verbose: global.verbose);
    final newVersion =
        versionOpts.version ?? VersionDetection.detectNextVersion(repoRoot, prevTag, verbose: global.verbose);
    final currentVersion = CiProcessRunner.runSync(
      "awk '/^version:/{print \$2}' pubspec.yaml",
      repoRoot,
      verbose: global.verbose,
    );

    Logger.info('Current version (pubspec.yaml): $currentVersion');
    Logger.info('Previous tag: $prevTag');
    Logger.info('Next version: $newVersion');

    final rationaleFile = File('$repoRoot/$kCicdRunsDir/version_analysis/version_bump_rationale.md');
    if (rationaleFile.existsSync()) {
      final bumpDir = Directory('$repoRoot/$kVersionBumpsDir');
      bumpDir.createSync(recursive: true);
      final targetPath = '${bumpDir.path}/v$newVersion.md';
      rationaleFile.copySync(targetPath);
      Logger.success('Version bump rationale saved to $kVersionBumpsDir/v$newVersion.md');
    }
  }

  /// Inline explore stage (from _runExplore).
  Future<void> _runExplore(String repoRoot, GlobalOptions global, VersionOptions versionOpts) async {
    Logger.header('Stage 1: Explorer Agent (Gemini 3 Pro Preview)');

    if (!GeminiUtils.geminiAvailable(warnOnly: true)) {
      Logger.warn('Skipping explore stage (Gemini unavailable). No changelog data will be generated.');
      return;
    }

    final ctx = RunContext.create(repoRoot, 'explore');
    final prevTag = versionOpts.prevTag ?? VersionDetection.detectPrevTag(repoRoot, verbose: global.verbose);
    final newVersion =
        versionOpts.version ?? VersionDetection.detectNextVersion(repoRoot, prevTag, verbose: global.verbose);

    Logger.info('Previous tag: $prevTag');
    Logger.info('New version: $newVersion');
    Logger.info('Run dir: ${ctx.runDir}');

    final promptScriptPath = PromptResolver.promptScript('gemini_changelog_prompt.dart');
    Logger.info('Generating explorer prompt from $promptScriptPath...');
    if (!File(promptScriptPath).existsSync()) {
      Logger.error('Prompt script not found: $promptScriptPath');
      Logger.error('Ensure runtime_ci_tooling is properly installed (dart pub get).');
      exit(1);
    }
    final prompt = CiProcessRunner.runSync(
      'dart run $promptScriptPath "$prevTag" "$newVersion"',
      repoRoot,
      verbose: global.verbose,
    );
    if (prompt.isEmpty) {
      Logger.error('Prompt generator produced empty output. Check $promptScriptPath');
      exit(1);
    }
    ctx.savePrompt('explore', prompt);

    if (global.dryRun) {
      Logger.info('[DRY-RUN] Would run Gemini CLI with explorer prompt (${prompt.length} chars)');
      return;
    }

    final promptPath = ctx.artifactPath('explore', 'prompt.txt');

    Logger.info('Running Gemini 3 Pro Preview...');
    final result = Process.runSync(
      'sh',
      [
        '-c',
        'cat $promptPath | gemini '
            '-o json --yolo '
            '-m $_kGeminiProModel '
            "--allowed-tools 'run_shell_command(git),run_shell_command(gh)'",
      ],
      workingDirectory: repoRoot,
      environment: {...Platform.environment},
    );

    final rawStdout = result.stdout as String;
    final rawStderr = (result.stderr as String).trim();

    if (result.exitCode != 0) {
      Logger.warn('Gemini CLI exited with code ${result.exitCode}');
      if (rawStderr.isNotEmpty) {
        Logger.warn('  stderr: ${rawStderr.split('\n').first}');
      }
    }

    if (rawStdout.isNotEmpty) {
      ctx.saveResponse('explore', rawStdout);
    }

    bool geminiSucceeded = false;
    try {
      if (rawStdout.contains('{')) {
        final jsonStr = GeminiUtils.extractJson(rawStdout);
        final response = json.decode(jsonStr) as Map<String, dynamic>;
        final stats = response['stats'] as Map<String, dynamic>?;
        geminiSucceeded = true;
        Logger.success('Stage 1 completed.');
        if (stats != null) {
          Logger.info('  Tool calls: ${stats['tools']?['totalCalls']}');
        }
      } else if (result.exitCode != 0) {
        Logger.warn('Gemini CLI produced no JSON output. Using fallback artifacts.');
      }
    } catch (e) {
      Logger.warn('Could not parse Gemini response as JSON: $e');
    }

    ctx.finalize(exitCode: geminiSucceeded ? 0 : result.exitCode);

    Logger.info('');
    Logger.info('Validating Stage 1 artifacts...');
    final artifactNames = ['commit_analysis.json', 'pr_data.json', 'breaking_changes.json'];
    for (final name in artifactNames) {
      final ctxPath = '${ctx.runDir}/explore/$name';
      final tmpPath = '/tmp/$name';

      File? source;
      if (File(ctxPath).existsSync()) {
        source = File(ctxPath);
      } else if (File('$repoRoot/$kCicdRunsDir/explore/$name').existsSync()) {
        source = File('$repoRoot/$kCicdRunsDir/explore/$name');
      }

      if (source != null) {
        try {
          final content = source.readAsStringSync();
          json.decode(content);
          Logger.success('Valid: ${source.path} (${source.lengthSync()} bytes)');
          source.copySync(tmpPath);
        } catch (e) {
          Logger.warn('Invalid JSON: ${source.path} -- $e');
          File(tmpPath).writeAsStringSync('{}');
        }
      } else {
        Logger.warn('Missing: $name (Gemini may not have generated this artifact)');
        File(tmpPath).writeAsStringSync('{}');
      }
    }

    Logger.success('Stage 1 complete. Artifacts available in /tmp/ for upload.');

    final commitJson = FileUtils.readFileOr('/tmp/commit_analysis.json');
    final prJson = FileUtils.readFileOr('/tmp/pr_data.json');
    final breakingJson = FileUtils.readFileOr('/tmp/breaking_changes.json');

    StepSummary.write('''
## Stage 1: Explorer Agent Complete

| Field | Value |
|-------|-------|
| Version | **v$newVersion** |
| Previous tag | ${StepSummary.compareLink(prevTag, 'HEAD', '`$prevTag...HEAD`')} |
| Gemini model | `$_kGeminiProModel` |

${StepSummary.collapsible('commit_analysis.json', '```json\n$commitJson\n```')}
${StepSummary.collapsible('pr_data.json', '```json\n$prJson\n```')}
${StepSummary.collapsible('breaking_changes.json', '```json\n$breakingJson\n```')}

${StepSummary.artifactLink()}
''');
  }

  /// Inline compose stage (from _runCompose).
  Future<void> _runCompose(String repoRoot, GlobalOptions global, VersionOptions versionOpts) async {
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

    final includes = <String>[];
    final artifactNames = ['commit_analysis.json', 'pr_data.json', 'breaking_changes.json'];
    for (final name in artifactNames) {
      if (File('/tmp/$name').existsSync()) {
        includes.add('@/tmp/$name');
      } else if (File('$repoRoot/$kCicdRunsDir/explore/$name').existsSync()) {
        includes.add('@$repoRoot/$kCicdRunsDir/explore/$name');
      }
    }
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
