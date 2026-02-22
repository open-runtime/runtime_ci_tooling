import 'package:build_cli_annotations/build_cli_annotations.dart';

part 'merge_audit_trails_options.g.dart';

/// CLI options for the merge-audit-trails command.
@CliOptions()
class MergeAuditTrailsOptions {
  /// Directory containing incoming audit trail artifacts.
  @CliOption(help: 'Directory containing incoming audit trail artifacts')
  final String? incomingDir;

  /// Output directory for merged audit trails.
  @CliOption(help: 'Output directory for merged audit trails')
  final String? outputDir;

  const MergeAuditTrailsOptions({
    this.incomingDir,
    this.outputDir,
  });

  factory MergeAuditTrailsOptions.fromArgResults(ArgResults results) {
    return _$parseMergeAuditTrailsOptionsResult(results);
  }
}

extension MergeAuditTrailsOptionsArgParser on MergeAuditTrailsOptions {
  static void populateParser(ArgParser parser) {
    _$populateMergeAuditTrailsOptionsParser(parser);
  }
}
