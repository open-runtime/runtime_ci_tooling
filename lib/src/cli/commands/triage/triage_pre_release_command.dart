import 'dart:io';

import 'package:args/command_runner.dart';

import '../../../triage/phases/pre_release.dart' as pre_release_phase;
import '../../../triage/utils/config.dart';
import '../../manage_cicd_cli.dart';
import '../../options/triage_options.dart';
import '../../options/version_options.dart';
import '../../utils/logger.dart';
import '../../utils/repo_utils.dart';
import 'triage_utils.dart';

/// Pre-release triage: scan issues/Sentry, correlate with diff, produce manifest.
class TriagePreReleaseCommand extends Command<void> {
  @override
  final String name = 'pre-release';

  @override
  final String description = 'Scan issues for upcoming release (requires --prev-tag and --version).';

  TriagePreReleaseCommand() {
    VersionOptionsArgParser.populateParser(argParser);
    TriageOptionsArgParser.populateParser(argParser);
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
    final triageOpts = TriageOptions.fromArgResults(argResults!);

    if (versionOpts.prevTag == null || versionOpts.version == null) {
      Logger.error('pre-release requires --prev-tag <tag> and --version <ver>');
      exit(1);
    }

    reloadConfig();

    if (!acquireTriageLock(triageOpts.force)) {
      exit(1);
    }

    try {
      final runDir = createTriageRunDir(repoRoot);

      final manifestPath = await pre_release_phase.preReleaseTriage(
        prevTag: versionOpts.prevTag!,
        newVersion: versionOpts.version!,
        repoRoot: repoRoot,
        runDir: runDir,
        verbose: global.verbose,
      );

      Logger.header('Pre-Release Triage Complete');
      Logger.info('  Manifest: $manifestPath');
      Logger.info('  Run dir: $runDir');
    } catch (e) {
      Logger.error('Pre-release triage failed: $e');
      exit(1);
    } finally {
      releaseTriageLock();
    }
  }
}
