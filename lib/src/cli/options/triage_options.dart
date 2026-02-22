import 'package:build_cli_annotations/build_cli_annotations.dart';

part 'triage_options.g.dart';

/// CLI options shared by triage subcommands that acquire a lock.
@CliOptions()
class TriageOptions {
  /// Override an existing lock.
  @CliOption(help: 'Override an existing triage lock')
  final bool force;

  const TriageOptions({this.force = false});

  /// Parse triage options from ArgResults.
  factory TriageOptions.fromArgResults(ArgResults results) {
    return _$parseTriageOptionsResult(results);
  }
}

/// Extension to provide helper method for populating argument parsers.
extension TriageOptionsArgParser on TriageOptions {
  /// Populates the given ArgParser with triage options.
  static void populateParser(ArgParser parser) {
    _$populateTriageOptionsParser(parser);
  }
}
