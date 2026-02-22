import 'dart:io';

import 'package:args/command_runner.dart';

import '../../triage/utils/config.dart';
import '../../triage/utils/run_context.dart';
import '../manage_cicd_cli.dart';
import '../options/version_options.dart';
import '../utils/logger.dart';
import '../utils/process_runner.dart';
import '../utils/repo_utils.dart';
import '../utils/version_detection.dart';

/// Determine the next SemVer version from commit history.
class VersionCommand extends Command<void> {
  @override
  final String name = 'version';

  @override
  final String description = 'Show the next SemVer version (no side effects).';

  VersionCommand() {
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

    // Save version bump rationale if Gemini produced one
    final rationaleFile = File('$repoRoot/$kCicdRunsDir/version_analysis/version_bump_rationale.md');
    if (rationaleFile.existsSync()) {
      final bumpDir = Directory('$repoRoot/$kVersionBumpsDir');
      bumpDir.createSync(recursive: true);
      final targetPath = '${bumpDir.path}/v$newVersion.md';
      rationaleFile.copySync(targetPath);
      Logger.success('Version bump rationale saved to $kVersionBumpsDir/v$newVersion.md');
    }
  }
}
