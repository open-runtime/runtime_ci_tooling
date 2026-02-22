import 'package:build_cli_annotations/build_cli_annotations.dart';

part 'global_options.g.dart';

/// Global CLI options available to all commands.
///
/// These options are specified before the command name and affect
/// the overall behavior of the tool.
@CliOptions()
class GlobalOptions {
  /// Show what would be done without executing.
  @CliOption(help: 'Show what would be done without executing')
  final bool dryRun;

  /// Show detailed command output.
  @CliOption(abbr: 'v', help: 'Show detailed command output')
  final bool verbose;

  const GlobalOptions({
    this.dryRun = false,
    this.verbose = false,
  });

  /// Parse global options from ArgResults.
  factory GlobalOptions.fromArgResults(ArgResults results) {
    return _$parseGlobalOptionsResult(results);
  }
}

/// Extension to provide helper method for populating argument parsers.
extension GlobalOptionsArgParser on GlobalOptions {
  /// Populates the given ArgParser with global options.
  static void populateParser(ArgParser parser) {
    _$populateGlobalOptionsParser(parser);
  }
}
