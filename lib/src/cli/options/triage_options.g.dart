// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'triage_options.dart';

// **************************************************************************
// CliGenerator
// **************************************************************************

TriageOptions _$parseTriageOptionsResult(ArgResults result) =>
    TriageOptions(force: result['force'] as bool);

ArgParser _$populateTriageOptionsParser(ArgParser parser) =>
    parser..addFlag('force', help: 'Override an existing triage lock');

final _$parserForTriageOptions = _$populateTriageOptionsParser(ArgParser());

TriageOptions parseTriageOptions(List<String> args) {
  final result = _$parserForTriageOptions.parse(args);
  return _$parseTriageOptionsResult(result);
}
