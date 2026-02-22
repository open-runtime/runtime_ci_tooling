// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'triage_cli_options.dart';

// **************************************************************************
// CliGenerator
// **************************************************************************

TriageCliOptions _$parseTriageCliOptionsResult(ArgResults result) =>
    TriageCliOptions(
      dryRun: result['dry-run'] as bool,
      verbose: result['verbose'] as bool,
      auto: result['auto'] as bool,
      status: result['status'] as bool,
      force: result['force'] as bool,
      preRelease: result['pre-release'] as bool,
      postRelease: result['post-release'] as bool,
      resume: result['resume'] as String?,
      prevTag: result['prev-tag'] as String?,
      version: result['version'] as String?,
      releaseTag: result['release-tag'] as String?,
      releaseUrl: result['release-url'] as String?,
      manifest: result['manifest'] as String?,
    );

ArgParser _$populateTriageCliOptionsParser(ArgParser parser) => parser
  ..addFlag('dry-run', help: 'Show what would be done without executing')
  ..addFlag('verbose', abbr: 'v', help: 'Show detailed command output')
  ..addFlag('auto', help: 'Run in auto mode (automatically select issues)')
  ..addFlag('status', help: 'Show triage status without running')
  ..addFlag('force', help: 'Force re-run even if already completed')
  ..addFlag(
    'pre-release',
    help: 'Pre-release mode (prepare changelog before release)',
  )
  ..addFlag(
    'post-release',
    help: 'Post-release mode (update after release is published)',
  )
  ..addOption('resume', help: 'Resume from a checkpoint')
  ..addOption('prev-tag', help: 'Override previous tag detection')
  ..addOption('version', help: 'Override version (skip auto-detection)')
  ..addOption('release-tag', help: 'The release tag (e.g., v1.0.0)')
  ..addOption('release-url', help: 'URL to the release page')
  ..addOption('manifest', help: 'Path to manifest file');

final _$parserForTriageCliOptions = _$populateTriageCliOptionsParser(
  ArgParser(),
);

TriageCliOptions parseTriageCliOptions(List<String> args) {
  final result = _$parserForTriageCliOptions.parse(args);
  return _$parseTriageCliOptionsResult(result);
}
