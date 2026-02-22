// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'archive_run_options.dart';

// **************************************************************************
// CliGenerator
// **************************************************************************

ArchiveRunOptions _$parseArchiveRunOptionsResult(ArgResults result) =>
    ArchiveRunOptions(runDir: result['run-dir'] as String?);

ArgParser _$populateArchiveRunOptionsParser(ArgParser parser) =>
    parser..addOption('run-dir', help: 'Directory containing the CI run to archive');

final _$parserForArchiveRunOptions = _$populateArchiveRunOptionsParser(ArgParser());

ArchiveRunOptions parseArchiveRunOptions(List<String> args) {
  final result = _$parserForArchiveRunOptions.parse(args);
  return _$parseArchiveRunOptionsResult(result);
}
