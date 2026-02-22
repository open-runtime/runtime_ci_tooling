// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'determine_version_options.dart';

// **************************************************************************
// CliGenerator
// **************************************************************************

DetermineVersionOptions _$parseDetermineVersionOptionsResult(ArgResults result) =>
    DetermineVersionOptions(outputGithubActions: result['output-github-actions'] as bool);

ArgParser _$populateDetermineVersionOptionsParser(ArgParser parser) =>
    parser..addFlag('output-github-actions', help: r'Write version outputs to $GITHUB_OUTPUT for GitHub Actions');

final _$parserForDetermineVersionOptions = _$populateDetermineVersionOptionsParser(ArgParser());

DetermineVersionOptions parseDetermineVersionOptions(List<String> args) {
  final result = _$parserForDetermineVersionOptions.parse(args);
  return _$parseDetermineVersionOptionsResult(result);
}
