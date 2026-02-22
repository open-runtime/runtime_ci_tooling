import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../../triage/utils/config.dart';
import '../../triage/utils/run_context.dart';
import '../manage_cicd_cli.dart';
import '../options/version_options.dart';
import '../utils/file_utils.dart';
import '../utils/gemini_utils.dart';
import '../utils/logger.dart';
import '../utils/process_runner.dart';
import '../utils/prompt_resolver.dart';
import '../utils/repo_utils.dart';
import '../utils/step_summary.dart';
import '../utils/version_detection.dart';

const String _kGeminiProModel = 'gemini-3-1-pro-preview';

/// Run Stage 1 Explorer Agent locally.
/// Gracefully skips if Gemini is unavailable.
class ExploreCommand extends Command<void> {
  @override
  final String name = 'explore';

  @override
  final String description = 'Run Stage 1 Explorer Agent (Gemini 3 Pro Preview).';

  ExploreCommand() {
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

    // Generate prompt via Dart template
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

    // Write prompt to file for piping
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

    // Save raw response to audit trail
    if (rawStdout.isNotEmpty) {
      ctx.saveResponse('explore', rawStdout);
    }

    // Try to parse JSON response from stdout regardless of exit code
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

    // Validate artifacts
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

    // Write step summary
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
}
