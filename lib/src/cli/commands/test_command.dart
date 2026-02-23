import 'dart:async';
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

    // Skip gracefully if no test/ directory exists
    final testDir = Directory('$repoRoot/test');
    if (!testDir.existsSync()) {
      Logger.success('No test/ directory found — skipping tests');
      return;
    }

    // Use Process.start for streaming output instead of Process.runSync.
    // This ensures real-time output in CI (runSync buffers everything until
    // exit, so a hanging test produces zero output).
    final process = await Process.start(
      Platform.resolvedExecutable,
      ['test', '--exclude-tags', 'gcp,integration'],
      workingDirectory: repoRoot,
      mode: ProcessStartMode.inheritStdio,
    );

    // Process-level timeout: kill the test process if it exceeds 20 minutes.
    // Individual test timeouts should catch hangs, but this is a safety net
    // for cases where the test process itself doesn't exit (e.g., leaked
    // isolates, open sockets keeping the event loop alive).
    const processTimeout = Duration(minutes: 20);
    final exitCode = await process.exitCode.timeout(
      processTimeout,
      onTimeout: () {
        Logger.error('Test process exceeded ${processTimeout.inMinutes}-minute timeout — killing.');
        process.kill(ProcessSignal.sigkill);
        return -1;
      },
    );

    if (exitCode != 0) {
      Logger.error('Tests failed with exit code $exitCode');
      exit(exitCode);
    }

    Logger.success('All tests passed');
  }
}
