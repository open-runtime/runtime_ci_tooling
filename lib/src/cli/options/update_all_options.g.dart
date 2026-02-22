// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_all_options.dart';

// **************************************************************************
// CliGenerator
// **************************************************************************

UpdateAllOptions _$parseUpdateAllOptionsResult(ArgResults result) => UpdateAllOptions(
  scanRoot: result['scan-root'] as String?,
  concurrency: int.parse(result['concurrency'] as String),
  force: result['force'] as bool,
  workflows: result['workflows'] as bool,
  templates: result['templates'] as bool,
  config: result['config'] as bool,
  autodoc: result['autodoc'] as bool,
  backup: result['backup'] as bool,
);

ArgParser _$populateUpdateAllOptionsParser(ArgParser parser) => parser
  ..addOption('scan-root', help: 'Root directory to scan for packages (default: cwd)')
  ..addOption('concurrency', help: 'Max concurrent update processes', defaultsTo: '4')
  ..addFlag('force', help: 'Overwrite all files regardless of local customizations')
  ..addFlag('workflows', help: 'Only update GitHub workflow files (.github/workflows/)')
  ..addFlag('templates', help: 'Only update template files (.gemini/ commands and settings)')
  ..addFlag('config', help: 'Only merge new keys into .runtime_ci/config.json')
  ..addFlag('autodoc', help: 'Re-scan lib/src/ and update autodoc.json modules')
  ..addFlag('backup', help: 'Write .bak backup before overwriting files');

final _$parserForUpdateAllOptions = _$populateUpdateAllOptionsParser(ArgParser());

UpdateAllOptions parseUpdateAllOptions(List<String> args) {
  final result = _$parserForUpdateAllOptions.parse(args);
  return _$parseUpdateAllOptionsResult(result);
}
