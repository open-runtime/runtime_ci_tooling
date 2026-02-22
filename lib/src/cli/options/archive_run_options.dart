import 'package:build_cli_annotations/build_cli_annotations.dart';

part 'archive_run_options.g.dart';

/// CLI options for the archive-run command.
@CliOptions()
class ArchiveRunOptions {
  /// Directory containing the CI run to archive.
  @CliOption(help: 'Directory containing the CI run to archive')
  final String? runDir;

  const ArchiveRunOptions({
    this.runDir,
  });

  factory ArchiveRunOptions.fromArgResults(ArgResults results) {
    return _$parseArchiveRunOptionsResult(results);
  }
}

extension ArchiveRunOptionsArgParser on ArchiveRunOptions {
  static void populateParser(ArgParser parser) {
    _$populateArchiveRunOptionsParser(parser);
  }
}
