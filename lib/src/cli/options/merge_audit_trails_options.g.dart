// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'merge_audit_trails_options.dart';

// **************************************************************************
// CliGenerator
// **************************************************************************

MergeAuditTrailsOptions _$parseMergeAuditTrailsOptionsResult(ArgResults result) =>
    MergeAuditTrailsOptions(incomingDir: result['incoming-dir'] as String?, outputDir: result['output-dir'] as String?);

ArgParser _$populateMergeAuditTrailsOptionsParser(ArgParser parser) => parser
  ..addOption('incoming-dir', help: 'Directory containing incoming audit trail artifacts')
  ..addOption('output-dir', help: 'Output directory for merged audit trails');

final _$parserForMergeAuditTrailsOptions = _$populateMergeAuditTrailsOptionsParser(ArgParser());

MergeAuditTrailsOptions parseMergeAuditTrailsOptions(List<String> args) {
  final result = _$parserForMergeAuditTrailsOptions.parse(args);
  return _$parseMergeAuditTrailsOptionsResult(result);
}
