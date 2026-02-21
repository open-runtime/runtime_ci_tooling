import 'package:build_cli_annotations/build_cli_annotations.dart';

part 'manage_cicd_options.g.dart';

/// Combined CLI options for manage_cicd.dart entry point.
///
/// This is the idiomatic build_cli pattern: a single @CliOptions class
/// that combines all option groups for one CLI entry point.
@CliOptions()
class ManageCicdOptions {
  // =========================================================================
  // Global Options
  // =========================================================================

  /// Show what would be done without executing.
  @CliOption(help: 'Show what would be done without executing')
  final bool dryRun;

  /// Show detailed command output.
  @CliOption(abbr: 'v', help: 'Show detailed command output')
  final bool verbose;

  // =========================================================================
  // Version Options
  // =========================================================================

  /// Override previous tag detection.
  @CliOption(help: 'Override previous tag detection')
  final String? prevTag;

  /// Override version (skip auto-detection).
  @CliOption(help: 'Override version (skip auto-detection)')
  final String? version;

  const ManageCicdOptions({
    this.dryRun = false,
    this.verbose = false,
    this.prevTag,
    this.version,
  });
}
