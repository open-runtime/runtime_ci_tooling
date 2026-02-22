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
import '../utils/repo_utils.dart';
import '../utils/version_detection.dart';

const String _kGeminiProModel = 'gemini-3-pro-preview';

/// Run documentation update via Gemini.
/// Gracefully skips if Gemini is unavailable.
class DocumentationCommand extends Command<void> {
  @override
  final String name = 'documentation';

  @override
  final String description = 'Run documentation update via Gemini 3 Pro Preview.';

  DocumentationCommand() {
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

    Logger.header('Documentation Update (Gemini 3 Pro Preview)');

    if (!GeminiUtils.geminiAvailable(warnOnly: true)) {
      Logger.warn('Skipping documentation update (Gemini unavailable).');
      return;
    }

    final ctx = RunContext.create(repoRoot, 'documentation');
    final prevTag = versionOpts.prevTag ?? VersionDetection.detectPrevTag(repoRoot, verbose: global.verbose);
    final newVersion =
        versionOpts.version ?? VersionDetection.detectNextVersion(repoRoot, prevTag, verbose: global.verbose);

    final docScript = PromptResolver.promptScript('gemini_documentation_prompt.dart');
    Logger.info('Generating documentation update prompt from $docScript...');
    if (!File(docScript).existsSync()) {
      Logger.error('Prompt script not found: $docScript');
      exit(1);
    }
    final prompt = CiProcessRunner.runSync(
      'dart run $docScript "$prevTag" "$newVersion"',
      repoRoot,
      verbose: global.verbose,
    );
    if (prompt.isEmpty) {
      Logger.error('Documentation prompt generator produced empty output.');
      exit(1);
    }
    ctx.savePrompt('documentation', prompt);

    if (global.dryRun) {
      Logger.info('[DRY-RUN] Would run Gemini for documentation update (${prompt.length} chars)');
      return;
    }

    final promptPath = ctx.artifactPath('documentation', 'prompt.txt');

    // Build @ includes
    final includes = <String>[];
    if (File('/tmp/commit_analysis.json').existsSync()) {
      includes.add('@/tmp/commit_analysis.json');
    } else if (File('$repoRoot/$kCicdRunsDir/explore/commit_analysis.json').existsSync()) {
      includes.add('@$repoRoot/$kCicdRunsDir/explore/commit_analysis.json');
    }
    includes.add('@README.md');

    Logger.info('Running Gemini 3 Pro for documentation updates...');
    final result = Process.runSync(
      'sh',
      [
        '-c',
        'cat $promptPath | gemini '
            '-o json --yolo '
            '-m $_kGeminiProModel '
            "--allowed-tools 'run_shell_command(git),run_shell_command(gh),run_shell_command(cat),run_shell_command(head)' "
            '${includes.join(" ")}',
      ],
      workingDirectory: repoRoot,
      environment: {...Platform.environment},
    );

    ctx.saveResponse('documentation', result.stdout as String);

    if (result.exitCode != 0) {
      Logger.warn('Documentation update failed: ${result.stderr}');
    } else {
      try {
        final jsonStr = GeminiUtils.extractJson(result.stdout as String);
        json.decode(jsonStr);
        Logger.success('Documentation update completed');
      } catch (e) {
        Logger.warn('Could not parse Gemini response: $e');
      }
    }
  }
}
