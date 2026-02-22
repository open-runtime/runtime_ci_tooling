import 'package:build_cli_annotations/build_cli_annotations.dart';

part 'post_release_triage_options.g.dart';

/// CLI options for the post-release-triage command.
@CliOptions()
class PostReleaseTriageOptions {
  /// Git tag for the release (e.g. v0.6.0).
  @CliOption(help: 'Git tag for the release')
  final String? releaseTag;

  /// URL of the GitHub release page.
  @CliOption(help: 'URL of the GitHub release page')
  final String? releaseUrl;

  /// Path to issue_manifest.json.
  @CliOption(help: 'Path to issue_manifest.json')
  final String? manifest;

  const PostReleaseTriageOptions({this.releaseTag, this.releaseUrl, this.manifest});

  factory PostReleaseTriageOptions.fromArgResults(ArgResults results) {
    return _$parsePostReleaseTriageOptionsResult(results);
  }
}

extension PostReleaseTriageOptionsArgParser on PostReleaseTriageOptions {
  static void populateParser(ArgParser parser) {
    _$populatePostReleaseTriageOptionsParser(parser);
  }
}
