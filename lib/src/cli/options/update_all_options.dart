import 'package:build_cli_annotations/build_cli_annotations.dart';

part 'update_all_options.g.dart';

/// CLI options for the update-all command.
@CliOptions()
class UpdateAllOptions {
  /// Root directory to scan for packages (default: cwd).
  @CliOption(help: 'Root directory to scan for packages (default: cwd)')
  final String? scanRoot;

  /// Max concurrent update processes.
  @CliOption(help: 'Max concurrent update processes', defaultsTo: '4')
  final int concurrency;

  /// Overwrite all files regardless of local customizations.
  @CliOption(help: 'Overwrite all files regardless of local customizations')
  final bool force;

  /// Only update GitHub workflow files.
  @CliOption(help: 'Only update GitHub workflow files (.github/workflows/)')
  final bool workflows;

  /// Only update template files (.gemini/ commands and settings).
  @CliOption(help: 'Only update template files (.gemini/ commands and settings)')
  final bool templates;

  /// Only merge new keys into .runtime_ci/config.json.
  @CliOption(help: 'Only merge new keys into .runtime_ci/config.json')
  final bool config;

  /// Only re-scan and update .runtime_ci/autodoc.json modules.
  @CliOption(help: 'Re-scan lib/src/ and update autodoc.json modules')
  final bool autodoc;

  /// Write a backup of each file before overwriting.
  @CliOption(help: 'Write .bak backup before overwriting files')
  final bool backup;

  const UpdateAllOptions({
    this.scanRoot,
    this.concurrency = 4,
    this.force = false,
    this.workflows = false,
    this.templates = false,
    this.config = false,
    this.autodoc = false,
    this.backup = false,
  });

  factory UpdateAllOptions.fromArgResults(ArgResults results) {
    return _$parseUpdateAllOptionsResult(results);
  }
}

extension UpdateAllOptionsArgParser on UpdateAllOptions {
  static void populateParser(ArgParser parser) {
    _$populateUpdateAllOptionsParser(parser);
  }
}
