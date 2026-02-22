// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'post_release_triage_options.dart';

// **************************************************************************
// CliGenerator
// **************************************************************************

PostReleaseTriageOptions _$parsePostReleaseTriageOptionsResult(
  ArgResults result,
) => PostReleaseTriageOptions(
  releaseTag: result['release-tag'] as String?,
  releaseUrl: result['release-url'] as String?,
  manifest: result['manifest'] as String?,
);

ArgParser _$populatePostReleaseTriageOptionsParser(ArgParser parser) => parser
  ..addOption('release-tag', help: 'Git tag for the release')
  ..addOption('release-url', help: 'URL of the GitHub release page')
  ..addOption('manifest', help: 'Path to issue_manifest.json');

final _$parserForPostReleaseTriageOptions =
    _$populatePostReleaseTriageOptionsParser(ArgParser());

PostReleaseTriageOptions parsePostReleaseTriageOptions(List<String> args) {
  final result = _$parserForPostReleaseTriageOptions.parse(args);
  return _$parsePostReleaseTriageOptionsResult(result);
}
