// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'version_options.dart';

// **************************************************************************
// CliGenerator
// **************************************************************************

VersionOptions _$parseVersionOptionsResult(ArgResults result) => VersionOptions(
  prevTag: result['prev-tag'] as String?,
  version: result['version'] as String?,
);

ArgParser _$populateVersionOptionsParser(ArgParser parser) => parser
  ..addOption('prev-tag', help: 'Override previous tag detection')
  ..addOption('version', help: 'Override version (skip auto-detection)');

final _$parserForVersionOptions = _$populateVersionOptionsParser(ArgParser());

VersionOptions parseVersionOptions(List<String> args) {
  final result = _$parserForVersionOptions.parse(args);
  return _$parseVersionOptionsResult(result);
}
