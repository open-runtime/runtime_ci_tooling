import 'package:build_cli_annotations/build_cli_annotations.dart';

part 'update_options.g.dart';

/// CLI options for the update command.
@CliOptions()
class UpdateOptions {
  /// Overwrite all files regardless of local customizations.
  @CliOption(help: 'Overwrite all files regardless of local customizations')
  final bool force;

  /// Only update template files (.gemini/ commands and settings).
  @CliOption(help: 'Only update template files (.gemini/ commands and settings)')
  final bool templates;

  /// Only merge new keys into .runtime_ci/config.json.
  @CliOption(help: 'Only merge new keys into .runtime_ci/config.json')
  final bool config;

  /// Only update GitHub workflow files.
  @CliOption(help: 'Only update GitHub workflow files (.github/workflows/)')
  final bool workflows;

  /// Only re-scan and update .runtime_ci/autodoc.json modules.
  @CliOption(help: 'Re-scan lib/src/ and update autodoc.json modules')
  final bool autodoc;

  /// Write a backup of each file before overwriting.
  @CliOption(help: 'Write .bak backup before overwriting files')
  final bool backup;

  const UpdateOptions({
    this.force = false,
    this.templates = false,
    this.config = false,
    this.workflows = false,
    this.autodoc = false,
    this.backup = false,
  });

  factory UpdateOptions.fromArgResults(ArgResults results) {
    return _$parseUpdateOptionsResult(results);
  }
}

extension UpdateOptionsArgParser on UpdateOptions {
  static void populateParser(ArgParser parser) {
    _$populateUpdateOptionsParser(parser);
  }

  /// Returns true if no specific filter flags are set (update everything).
  bool get updateAll => !templates && !config && !workflows && !autodoc;
}
