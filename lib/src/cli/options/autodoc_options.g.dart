// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'autodoc_options.dart';

// **************************************************************************
// CliGenerator
// **************************************************************************

AutodocOptions _$parseAutodocOptionsResult(ArgResults result) => AutodocOptions(
  init: result['init'] as bool,
  force: result['force'] as bool,
  module: result['module'] as String?,
);

ArgParser _$populateAutodocOptionsParser(ArgParser parser) => parser
  ..addFlag('init', help: 'Scan repo and create initial autodoc.json')
  ..addFlag('force', help: 'Regenerate all docs regardless of hash')
  ..addOption('module', help: 'Only generate for a specific module');

final _$parserForAutodocOptions = _$populateAutodocOptionsParser(ArgParser());

AutodocOptions parseAutodocOptions(List<String> args) {
  final result = _$parserForAutodocOptions.parse(args);
  return _$parseAutodocOptionsResult(result);
}
