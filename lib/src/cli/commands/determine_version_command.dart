import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../../triage/utils/config.dart';
import '../../triage/utils/run_context.dart';
import '../manage_cicd_cli.dart';
import '../options/determine_version_options.dart';
import '../options/version_options.dart';
import '../utils/file_utils.dart';
import '../utils/logger.dart';
import '../utils/process_runner.dart';
import '../utils/repo_utils.dart';
import '../utils/step_summary.dart';
import '../utils/version_detection.dart';

/// Determine version bump with Gemini analysis and output for CI.
///
/// Replaces the 130+ lines of inline bash in release.yaml.
/// Outputs JSON to stdout. With --output-github-actions, also writes to
/// \$GITHUB_OUTPUT.
class DetermineVersionCommand extends Command<void> {
  @override
  final String name = 'determine-version';

  @override
  final String description = 'Determine SemVer bump via Gemini + regex (CI: --output-github-actions).';

  DetermineVersionCommand() {
    DetermineVersionOptionsArgParser.populateParser(argParser);
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
    final dvOpts = DetermineVersionOptions.fromArgResults(argResults!);
    final versionOpts = VersionOptions.fromArgResults(argResults!);

    Logger.header('Determine Version');

    final outputGha = dvOpts.outputGithubActions;

    final prevTag = versionOpts.prevTag ?? VersionDetection.detectPrevTag(repoRoot, verbose: global.verbose);
    final newVersion =
        versionOpts.version ?? VersionDetection.detectNextVersion(repoRoot, prevTag, verbose: global.verbose);
    final currentVersion = CiProcessRunner.runSync(
      "awk '/^version:/{print \$2}' pubspec.yaml",
      repoRoot,
      verbose: global.verbose,
    );

    // Determine if we should release
    var shouldRelease = newVersion != currentVersion;

    // Safety net: if the tag already exists, skip release regardless
    if (shouldRelease) {
      final tagCheck = Process.runSync('git', ['rev-parse', 'v$newVersion'], workingDirectory: repoRoot);
      if (tagCheck.exitCode == 0) {
        Logger.warn('Tag v$newVersion already exists. Skipping release.');
        shouldRelease = false;
      }
    }

    Logger.info('Current version: $currentVersion');
    Logger.info('Previous tag: $prevTag');
    Logger.info('New version: $newVersion');
    Logger.info('Should release: $shouldRelease');

    // Save version bump rationale if Gemini produced one
    if (shouldRelease) {
      final rationaleFile = File('$repoRoot/$kCicdRunsDir/version_analysis/version_bump_rationale.md');
      final bumpDir = Directory('$repoRoot/$kVersionBumpsDir');
      bumpDir.createSync(recursive: true);
      final targetPath = '${bumpDir.path}/v$newVersion.md';

      if (rationaleFile.existsSync()) {
        rationaleFile.copySync(targetPath);
        Logger.success('Version bump rationale saved to $kVersionBumpsDir/v$newVersion.md');
      } else {
        // Generate basic rationale
        final commitCount = CiProcessRunner.runSync(
          'git rev-list --count "$prevTag"..HEAD 2>/dev/null',
          repoRoot,
          verbose: global.verbose,
        );
        final commits = CiProcessRunner.runSync(
          'git log "$prevTag"..HEAD --oneline --no-merges 2>/dev/null | head -20',
          repoRoot,
          verbose: global.verbose,
        );
        File(targetPath).writeAsStringSync(
          '# Version Bump: v$newVersion\n\n'
          '**Date**: ${DateTime.now().toUtc().toIso8601String()}\n'
          '**Previous**: $prevTag\n'
          '**Commits**: $commitCount\n\n'
          '## Commits\n\n$commits\n',
        );
        Logger.success('Basic version rationale saved to $kVersionBumpsDir/v$newVersion.md');
      }
    }

    // Output JSON to stdout
    final result = json.encode({
      'prev_tag': prevTag,
      'current_version': currentVersion,
      'new_version': newVersion,
      'should_release': shouldRelease,
    });
    print(result);

    // Write to $GITHUB_OUTPUT if in CI
    if (outputGha) {
      final ghOutput = Platform.environment['GITHUB_OUTPUT'];
      if (ghOutput != null && ghOutput.isNotEmpty) {
        final file = File(ghOutput);
        file.writeAsStringSync(
          'prev_tag=$prevTag\n'
          'new_version=$newVersion\n'
          'should_release=$shouldRelease\n',
          mode: FileMode.append,
        );
        Logger.success('Wrote outputs to \$GITHUB_OUTPUT');
      }
    }

    // Derive bump type from version comparison
    final currentParts = currentVersion.split('.');
    final newParts = newVersion.split('.');
    String bumpType = 'unknown';
    if (currentParts.length >= 3 && newParts.length >= 3) {
      if (int.tryParse(newParts[0]) != int.tryParse(currentParts[0])) {
        bumpType = 'major';
      } else if (int.tryParse(newParts[1]) != int.tryParse(currentParts[1])) {
        bumpType = 'minor';
      } else {
        bumpType = 'patch';
      }
    }

    // Read version bump rationale for summary
    final rationaleContent = FileUtils.readFileOr('$repoRoot/$kVersionBumpsDir/v$newVersion.md');

    StepSummary.write('''
## Version Determination

| Field | Value |
|-------|-------|
| Previous tag | `$prevTag` |
| Current version | `$currentVersion` |
| New version | **`$newVersion`** |
| Bump type | `$bumpType` |
| Should release | $shouldRelease |
| Method | ${CiProcessRunner.commandExists('gemini') && Platform.environment['GEMINI_API_KEY'] != null ? 'Gemini analysis' : 'Regex heuristic'} |
| Commits | ${StepSummary.compareLink(prevTag, 'HEAD', 'View diff')} |

${StepSummary.collapsible('Version Bump Rationale', rationaleContent, open: true)}

${StepSummary.artifactLink()}
''');
  }
}
