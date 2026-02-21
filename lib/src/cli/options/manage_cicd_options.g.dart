// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'manage_cicd_options.dart';

// **************************************************************************
// CliGenerator
// **************************************************************************

ManageCicdOptions _$parseManageCicdOptionsResult(ArgResults result) => ManageCicdOptions(
  dryRun: result['dry-run'] as bool,
  verbose: result['verbose'] as bool,
  prevTag: result['prev-tag'] as String?,
  version: result['version'] as String?,
  outputGithubActions: result['output-github-actions'] as bool,
);

ArgParser _$populateManageCicdOptionsParser(ArgParser parser) => parser
  ..addFlag('dry-run', help: 'Show what would be done without executing')
  ..addFlag('verbose', abbr: 'v', help: 'Show detailed command output')
  ..addOption('prev-tag', help: 'Override previous tag detection')
  ..addOption('version', help: 'Override version (skip auto-detection)')
  ..addFlag('output-github-actions', help: 'Write version outputs to \$GITHUB_OUTPUT for GitHub Actions');

final _$parserForManageCicdOptions = _$populateManageCicdOptionsParser(ArgParser());

ManageCicdOptions parseManageCicdOptions(List<String> args) {
  final result = _$parserForManageCicdOptions.parse(args);
  return _$parseManageCicdOptionsResult(result);
}
