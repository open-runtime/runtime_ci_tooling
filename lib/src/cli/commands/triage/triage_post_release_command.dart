import 'dart:io';

import 'package:args/command_runner.dart';

import '../../../triage/phases/post_release.dart' as post_release_phase;
import '../../../triage/utils/config.dart';
import '../../manage_cicd_cli.dart';
import '../../options/post_release_triage_options.dart';
import '../../options/triage_options.dart';
import '../../options/version_options.dart';
import '../../utils/logger.dart';
import '../../utils/repo_utils.dart';
import 'triage_utils.dart';

/// Post-release triage: comment/close issues, link Sentry, update linked_issues.json.
class TriagePostReleaseCommand extends Command<void> {
  @override
  final String name = 'post-release';

  @override
  final String description =
      'Close loop after release (requires --version and --release-tag).';

  TriagePostReleaseCommand() {
    VersionOptionsArgParser.populateParser(argParser);
    PostReleaseTriageOptionsArgParser.populateParser(argParser);
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
    final releaseOpts = PostReleaseTriageOptions.fromArgResults(argResults!);
    final triageOpts = TriageOptions.fromArgResults(argResults!);

    if (versionOpts.version == null || releaseOpts.releaseTag == null) {
      Logger.error(
          'post-release requires --version <ver> and --release-tag <tag>');
      exit(1);
    }

    reloadConfig();

    if (!acquireTriageLock(triageOpts.force)) {
      exit(1);
    }

    try {
      final runDir = createTriageRunDir(repoRoot);

      // Find the manifest: explicit path, or search recent runs
      final resolvedManifest =
          releaseOpts.manifest ?? findLatestManifest(repoRoot);
      if (resolvedManifest == null) {
        Logger.error(
            'No issue_manifest.json found. Run pre-release first, or pass --manifest <path>.');
        exit(1);
      }

      final url = (releaseOpts.releaseUrl ?? '').isNotEmpty
          ? releaseOpts.releaseUrl!
          : 'https://github.com/${config.repoOwner}/${config.repoName}/releases/tag/${releaseOpts.releaseTag}';

      await post_release_phase.postReleaseTriage(
        newVersion: versionOpts.version!,
        releaseTag: releaseOpts.releaseTag!,
        releaseUrl: url,
        manifestPath: resolvedManifest,
        repoRoot: repoRoot,
        runDir: runDir,
        verbose: global.verbose,
      );

      Logger.header('Post-Release Triage Complete');
      Logger.info('  Run dir: $runDir');
    } catch (e) {
      Logger.error('Post-release triage failed: $e');
      exit(1);
    } finally {
      releaseTriageLock();
    }
  }
}
