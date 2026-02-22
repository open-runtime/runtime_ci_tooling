import 'package:build_cli_annotations/build_cli_annotations.dart';

part 'create_release_options.g.dart';

/// CLI options for the create-release command.
@CliOptions()
class CreateReleaseOptions {
  /// Directory containing downloaded CI artifacts.
  @CliOption(help: 'Directory containing downloaded CI artifacts')
  final String? artifactsDir;

  /// GitHub repository slug (owner/repo).
  @CliOption(help: 'GitHub repository slug owner/repo')
  final String? repo;

  const CreateReleaseOptions({
    this.artifactsDir,
    this.repo,
  });

  factory CreateReleaseOptions.fromArgResults(ArgResults results) {
    return _$parseCreateReleaseOptionsResult(results);
  }
}

extension CreateReleaseOptionsArgParser on CreateReleaseOptions {
  static void populateParser(ArgParser parser) {
    _$populateCreateReleaseOptionsParser(parser);
  }
}
