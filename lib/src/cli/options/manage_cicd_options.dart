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

  // =========================================================================
  // CI/CD Options
  // =========================================================================

  /// Write prev_tag, new_version, should_release to \$GITHUB_OUTPUT.
  @CliOption(help: 'Write version outputs to \$GITHUB_OUTPUT for GitHub Actions')
  final bool outputGithubActions;

  // =========================================================================
  // Release Options
  // =========================================================================

  /// Directory containing downloaded CI artifacts.
  @CliOption(help: 'Directory containing downloaded CI artifacts (create-release)')
  final String? artifactsDir;

  /// GitHub repository slug (owner/repo) for release creation.
  @CliOption(help: 'GitHub repository slug owner/repo (create-release)')
  final String? repo;

  // =========================================================================
  // Post-Release Options
  // =========================================================================

  /// Git tag for the release (e.g. v0.6.0).
  @CliOption(help: 'Git tag for the release (post-release-triage)')
  final String? releaseTag;

  /// URL of the GitHub release page.
  @CliOption(help: 'URL of the GitHub release page (post-release-triage)')
  final String? releaseUrl;

  /// Path to issue_manifest.json for post-release triage.
  @CliOption(help: 'Path to issue_manifest.json (post-release-triage)')
  final String? manifest;

  const ManageCicdOptions({
    this.dryRun = false,
    this.verbose = false,
    this.prevTag,
    this.version,
    this.outputGithubActions = false,
    this.artifactsDir,
    this.repo,
    this.releaseTag,
    this.releaseUrl,
    this.manifest,
  });
}
