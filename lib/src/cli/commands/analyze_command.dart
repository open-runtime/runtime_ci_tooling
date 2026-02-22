import 'dart:io';

import 'package:args/command_runner.dart';

import '../../triage/utils/config.dart';
import '../utils/logger.dart';
import '../utils/repo_utils.dart';

/// Run dart analyze.
class AnalyzeCommand extends Command<void> {
  @override
  final String name = 'analyze';

  @override
  final String description = 'Run dart analyze (fail on errors only).';

  @override
  Future<void> run() async {
    final repoRoot = RepoUtils.findRepoRoot();
    if (repoRoot == null) {
      Logger.error('Could not find ${config.repoName} repo root.');
      exit(1);
    }

    Logger.header('Running dart analyze');

    final result = Process.runSync(
      Platform.resolvedExecutable,
      ['analyze', '--fatal-infos=false', '--fatal-warnings=false'],
      workingDirectory: repoRoot,
    );

    final stdout = (result.stdout as String).trim();
    if (stdout.isNotEmpty) print(stdout);

    final stderr = (result.stderr as String).trim();
    if (stderr.isNotEmpty) Logger.error(stderr);

    if (result.exitCode != 0) {
      Logger.error('Analysis failed with exit code ${result.exitCode}');
      exit(result.exitCode);
    }

    Logger.success('Analysis complete');
  }
}
