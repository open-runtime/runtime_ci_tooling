// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'global_options.dart';

// **************************************************************************
// CliGenerator
// **************************************************************************

GlobalOptions _$parseGlobalOptionsResult(ArgResults result) => GlobalOptions(
  dryRun: result['dry-run'] as bool,
  verbose: result['verbose'] as bool,
);

ArgParser _$populateGlobalOptionsParser(ArgParser parser) => parser
  ..addFlag('dry-run', help: 'Show what would be done without executing')
  ..addFlag('verbose', abbr: 'v', help: 'Show detailed command output');

final _$parserForGlobalOptions = _$populateGlobalOptionsParser(ArgParser());

GlobalOptions parseGlobalOptions(List<String> args) {
  final result = _$parserForGlobalOptions.parse(args);
  return _$parseGlobalOptionsResult(result);
}
