import 'dart:io';

import 'package:args/command_runner.dart';

import '../../triage/utils/config.dart';
import '../utils/logger.dart';
import '../utils/repo_utils.dart';

/// Run dart test.
class TestCommand extends Command<void> {
  @override
  final String name = 'test';

  @override
  final String description = 'Run dart test.';

  @override
  Future<void> run() async {
    final repoRoot = RepoUtils.findRepoRoot();
    if (repoRoot == null) {
      Logger.error('Could not find ${config.repoName} repo root.');
      exit(1);
    }

    Logger.header('Running dart test');

    final result = Process.runSync(
      Platform.resolvedExecutable,
      ['test'],
      workingDirectory: repoRoot,
    );

    final stdout = (result.stdout as String).trim();
    if (stdout.isNotEmpty) print(stdout);

    final stderr = (result.stderr as String).trim();
    if (stderr.isNotEmpty) Logger.error(stderr);

    if (result.exitCode != 0) {
      Logger.error('Tests failed with exit code ${result.exitCode}');
      exit(result.exitCode);
    }

    Logger.success('All tests passed');
  }
}
