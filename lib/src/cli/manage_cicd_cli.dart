import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import 'commands/analyze_command.dart';
import 'commands/archive_run_command.dart';
import 'commands/autodoc_command.dart';
import 'commands/compose_command.dart';
import 'commands/configure_mcp_command.dart';
import 'commands/create_release_command.dart';
import 'commands/determine_version_command.dart';
import 'commands/documentation_command.dart';
import 'commands/explore_command.dart';
import 'commands/init_command.dart';
import 'commands/merge_audit_trails_command.dart';
import 'commands/release_command.dart';
import 'commands/release_notes_command.dart';
import 'commands/setup_command.dart';
import 'commands/status_command.dart';
import 'commands/test_command.dart';
import 'commands/triage/triage_command.dart';
import 'commands/validate_command.dart';
import 'commands/verify_protos_command.dart';
import 'commands/version_command.dart';
import 'options/global_options.dart';

export 'package:args/command_runner.dart' show UsageException;

/// CLI entry point for CI/CD Automation.
///
/// Provides commands for managing the full CI/CD lifecycle:
/// - setup, validate, status: Infrastructure management
/// - explore, compose, release-notes, documentation: Gemini-powered release pipeline
/// - triage: Issue triage with subcommands (auto, single, pre-release, etc.)
/// - determine-version, create-release: CI/CD pipeline steps
/// - test, analyze, verify-protos: Code quality
class ManageCicdCli extends CommandRunner<void> {
  ManageCicdCli()
      : super(
          'manage_cicd',
          'CI/CD Automation CLI\n\n'
              'Cross-platform tooling for managing AI-powered release pipelines '
              'locally and in CI.',
        ) {
    GlobalOptionsArgParser.populateParser(argParser);
    _addCommands();
  }

  void _addCommands() {
    addCommand(AnalyzeCommand());
    addCommand(ArchiveRunCommand());
    addCommand(AutodocCommand());
    addCommand(ComposeCommand());
    addCommand(ConfigureMcpCommand());
    addCommand(CreateReleaseCommand());
    addCommand(DetermineVersionCommand());
    addCommand(DocumentationCommand());
    addCommand(ExploreCommand());
    addCommand(InitCommand());
    addCommand(MergeAuditTrailsCommand());
    addCommand(ReleaseCommand());
    addCommand(ReleaseNotesCommand());
    addCommand(SetupCommand());
    addCommand(StatusCommand());
    addCommand(TestCommand());
    addCommand(TriageCommand());
    addCommand(ValidateCommand());
    addCommand(VerifyProtosCommand());
    addCommand(VersionCommand());
  }

  /// Parse global options from ArgResults using build_cli generated code.
  static GlobalOptions parseGlobalOptions(ArgResults? results) {
    if (results == null) {
      return const GlobalOptions();
    }
    return GlobalOptions.fromArgResults(results);
  }

  /// Returns true if verbose mode is enabled.
  static bool isVerbose(ArgResults? results) {
    return parseGlobalOptions(results).verbose;
  }

  /// Returns true if dry-run mode is enabled.
  static bool isDryRun(ArgResults? results) {
    return parseGlobalOptions(results).dryRun;
  }
}
