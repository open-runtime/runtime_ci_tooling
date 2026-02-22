import 'dart:io';

import 'package:args/command_runner.dart';

import '../../triage/utils/config.dart';
import '../../triage/utils/run_context.dart';
import '../manage_cicd_cli.dart';
import '../options/archive_run_options.dart';
import '../options/version_options.dart';
import '../utils/logger.dart';
import '../utils/repo_utils.dart';

/// Archive a CI/CD run to .runtime_ci/audit/vX.X.X/ for permanent storage.
///
/// This step is non-critical -- the release succeeds even if archiving fails.
/// All failure paths return gracefully (exit 0) to avoid GitHub Actions error
/// annotations from continue-on-error steps.
class ArchiveRunCommand extends Command<void> {
  @override
  final String name = 'archive-run';

  @override
  final String description =
      'Archive .runtime_ci/runs/ to .runtime_ci/audit/vX.X.X/ for permanent storage.';

  ArchiveRunCommand() {
    ArchiveRunOptionsArgParser.populateParser(argParser);
    VersionOptionsArgParser.populateParser(argParser);
  }

  @override
  Future<void> run() async {
    final repoRoot = RepoUtils.findRepoRoot();
    if (repoRoot == null) {
      Logger.error('Could not find ${config.repoName} repo root.');
      exit(1);
    }
    // ignore: unused_local_variable -- parsed for consistency with other commands
    final global = ManageCicdCli.parseGlobalOptions(globalResults);
    final arOpts = ArchiveRunOptions.fromArgResults(argResults!);
    final versionOpts = VersionOptions.fromArgResults(argResults!);

    Logger.header('Archive Run');

    final version = versionOpts.version;
    if (version == null) {
      Logger.warn('--version not provided for archive-run — skipping.');
      return;
    }

    // Find the run directory
    var runDirPath = arOpts.runDir;

    if (runDirPath == null) {
      runDirPath = RunContext.findLatestRun(repoRoot);
      if (runDirPath == null) {
        Logger.warn(
            'No $kCicdRunsDir/ directory found — nothing to archive.');
        Logger.info(
            'This is expected if audit trail artifacts were not transferred between jobs.');
        return;
      }
      Logger.info('Using latest run: $runDirPath');
    }

    try {
      final ctx = RunContext.load(repoRoot, runDirPath);
      ctx.archiveForRelease(version);
      Logger.success('Archived to $kCicdAuditDir/v$version/');
    } catch (e) {
      Logger.warn('Archive failed: $e — continuing without archive.');
    }
  }
}
