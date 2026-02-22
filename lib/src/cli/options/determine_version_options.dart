import 'package:build_cli_annotations/build_cli_annotations.dart';

part 'determine_version_options.g.dart';

/// CLI options for the determine-version command.
@CliOptions()
class DetermineVersionOptions {
  /// Write version outputs to \$GITHUB_OUTPUT for GitHub Actions.
  @CliOption(help: 'Write version outputs to \$GITHUB_OUTPUT for GitHub Actions')
  final bool outputGithubActions;

  const DetermineVersionOptions({
    this.outputGithubActions = false,
  });

  factory DetermineVersionOptions.fromArgResults(ArgResults results) {
    return _$parseDetermineVersionOptionsResult(results);
  }
}

extension DetermineVersionOptionsArgParser on DetermineVersionOptions {
  static void populateParser(ArgParser parser) {
    _$populateDetermineVersionOptionsParser(parser);
  }
}
