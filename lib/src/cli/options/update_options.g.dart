// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_options.dart';

// **************************************************************************
// CliGenerator
// **************************************************************************

UpdateOptions _$parseUpdateOptionsResult(ArgResults result) => UpdateOptions(
  force: result['force'] as bool,
  templates: result['templates'] as bool,
  config: result['config'] as bool,
  workflows: result['workflows'] as bool,
  autodoc: result['autodoc'] as bool,
  backup: result['backup'] as bool,
);

ArgParser _$populateUpdateOptionsParser(ArgParser parser) => parser
  ..addFlag('force', help: 'Overwrite all files regardless of local customizations')
  ..addFlag('templates', help: 'Only update template files (.gemini/ commands and settings)')
  ..addFlag('config', help: 'Only merge new keys into .runtime_ci/config.json')
  ..addFlag('workflows', help: 'Only update GitHub workflow files (.github/workflows/)')
  ..addFlag('autodoc', help: 'Re-scan lib/src/ and update autodoc.json modules')
  ..addFlag('backup', help: 'Write .bak backup before overwriting files');

final _$parserForUpdateOptions = _$populateUpdateOptionsParser(ArgParser());

UpdateOptions parseUpdateOptions(List<String> args) {
  final result = _$parserForUpdateOptions.parse(args);
  return _$parseUpdateOptionsResult(result);
}
