import 'package:build_cli_annotations/build_cli_annotations.dart';

part 'version_options.g.dart';

/// Version-related CLI options shared by commands that work with
/// release versions (explore, compose, release-notes, etc.).
@CliOptions()
class VersionOptions {
  /// Override previous tag detection.
  @CliOption(help: 'Override previous tag detection')
  final String? prevTag;

  /// Override version (skip auto-detection).
  @CliOption(help: 'Override version (skip auto-detection)')
  final String? version;

  const VersionOptions({this.prevTag, this.version});

  /// Parse version options from ArgResults.
  factory VersionOptions.fromArgResults(ArgResults results) {
    return _$parseVersionOptionsResult(results);
  }
}

/// Extension to provide helper method for populating argument parsers.
extension VersionOptionsArgParser on VersionOptions {
  /// Populates the given ArgParser with version options.
  static void populateParser(ArgParser parser) {
    _$populateVersionOptionsParser(parser);
  }
}
