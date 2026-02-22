// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_release_options.dart';

// **************************************************************************
// CliGenerator
// **************************************************************************

CreateReleaseOptions _$parseCreateReleaseOptionsResult(ArgResults result) =>
    CreateReleaseOptions(
      artifactsDir: result['artifacts-dir'] as String?,
      repo: result['repo'] as String?,
    );

ArgParser _$populateCreateReleaseOptionsParser(ArgParser parser) => parser
  ..addOption(
    'artifacts-dir',
    help: 'Directory containing downloaded CI artifacts',
  )
  ..addOption('repo', help: 'GitHub repository slug owner/repo');

final _$parserForCreateReleaseOptions = _$populateCreateReleaseOptionsParser(
  ArgParser(),
);

CreateReleaseOptions parseCreateReleaseOptions(List<String> args) {
  final result = _$parserForCreateReleaseOptions.parse(args);
  return _$parseCreateReleaseOptionsResult(result);
}
