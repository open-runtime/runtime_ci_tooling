// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'manage_cicd_options.dart';

// **************************************************************************
// CliGenerator
// **************************************************************************

ManageCicdOptions _$parseManageCicdOptionsResult(ArgResults result) =>
    ManageCicdOptions(
      dryRun: result['dry-run'] as bool,
      verbose: result['verbose'] as bool,
      prevTag: result['prev-tag'] as String?,
      version: result['version'] as String?,
      outputGithubActions: result['output-github-actions'] as bool,
      artifactsDir: result['artifacts-dir'] as String?,
      repo: result['repo'] as String?,
      releaseTag: result['release-tag'] as String?,
      releaseUrl: result['release-url'] as String?,
      manifest: result['manifest'] as String?,
    );

ArgParser _$populateManageCicdOptionsParser(ArgParser parser) => parser
  ..addFlag('dry-run', help: 'Show what would be done without executing')
  ..addFlag('verbose', abbr: 'v', help: 'Show detailed command output')
  ..addOption('prev-tag', help: 'Override previous tag detection')
  ..addOption('version', help: 'Override version (skip auto-detection)')
  ..addFlag(
    'output-github-actions',
    help: r'Write version outputs to $GITHUB_OUTPUT for GitHub Actions',
  )
  ..addOption(
    'artifacts-dir',
    help: 'Directory containing downloaded CI artifacts (create-release)',
  )
  ..addOption(
    'repo',
    help: 'GitHub repository slug owner/repo (create-release)',
  )
  ..addOption(
    'release-tag',
    help: 'Git tag for the release (post-release-triage)',
  )
  ..addOption(
    'release-url',
    help: 'URL of the GitHub release page (post-release-triage)',
  )
  ..addOption(
    'manifest',
    help: 'Path to issue_manifest.json (post-release-triage)',
  );

final _$parserForManageCicdOptions = _$populateManageCicdOptionsParser(
  ArgParser(),
);

ManageCicdOptions parseManageCicdOptions(List<String> args) {
  final result = _$parserForManageCicdOptions.parse(args);
  return _$parseManageCicdOptionsResult(result);
}
