import 'package:build_cli_annotations/build_cli_annotations.dart';

part 'triage_cli_options.g.dart';

/// Combined CLI options for triage_cli.dart entry point.
///
/// This is the idiomatic build_cli pattern: a single @CliOptions class
/// that combines all option groups for one CLI entry point. Each entry
/// point should have its own composite options class.
@CliOptions()
class TriageCliOptions {
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
  // Triage Options
  // =========================================================================

  /// Run in auto mode (automatically select issues).
  @CliOption(help: 'Run in auto mode (automatically select issues)')
  final bool auto;

  /// Show triage status without running.
  @CliOption(help: 'Show triage status without running')
  final bool status;

  /// Force re-run even if already completed.
  @CliOption(help: 'Force re-run even if already completed')
  final bool force;

  /// Pre-release mode (prepare changelog before release).
  @CliOption(help: 'Pre-release mode (prepare changelog before release)')
  final bool preRelease;

  /// Post-release mode (update after release is published).
  @CliOption(help: 'Post-release mode (update after release is published)')
  final bool postRelease;

  /// Resume from a checkpoint.
  @CliOption(help: 'Resume from a checkpoint')
  final String? resume;

  // =========================================================================
  // Version Options
  // =========================================================================

  /// Override previous tag detection.
  @CliOption(help: 'Override previous tag detection')
  final String? prevTag;

  /// Override version (skip auto-detection).
  @CliOption(help: 'Override version (skip auto-detection)')
  final String? version;

  // =========================================================================
  // Release Options
  // =========================================================================

  /// The release tag (e.g., v1.0.0).
  @CliOption(help: 'The release tag (e.g., v1.0.0)')
  final String? releaseTag;

  /// URL to the release page.
  @CliOption(help: 'URL to the release page')
  final String? releaseUrl;

  /// Path to manifest file.
  @CliOption(help: 'Path to manifest file')
  final String? manifest;

  const TriageCliOptions({
    this.dryRun = false,
    this.verbose = false,
    this.auto = false,
    this.status = false,
    this.force = false,
    this.preRelease = false,
    this.postRelease = false,
    this.resume,
    this.prevTag,
    this.version,
    this.releaseTag,
    this.releaseUrl,
    this.manifest,
  });
}
