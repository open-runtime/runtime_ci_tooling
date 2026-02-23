import 'package:args/command_runner.dart';

import 'triage_auto_command.dart';
import 'triage_post_release_command.dart';
import 'triage_pre_release_command.dart';
import 'triage_resume_command.dart';
import 'triage_single_command.dart';
import 'triage_status_command.dart';

/// Triage command group with subcommands.
///
/// Supports both explicit subcommands and shorthand (rewritten upstream):
///   manage_cicd triage single 42
///   manage_cicd triage 42          (rewritten to `single 42` by ManageCicdCli.run)
///   manage_cicd triage auto
///   manage_cicd triage status
///   manage_cicd triage resume <run_id>
///   manage_cicd triage pre-release --prev-tag <tag> --version <ver>
///   manage_cicd triage post-release --version <ver> --release-tag <tag>
class TriageCommand extends Command<void> {
  @override
  final String name = 'triage';

  @override
  final String description = 'Issue triage pipeline with AI-powered investigation.';

  TriageCommand() {
    addSubcommand(TriageSingleCommand());
    addSubcommand(TriageAutoCommand());
    addSubcommand(TriageStatusCommand());
    addSubcommand(TriageResumeCommand());
    addSubcommand(TriagePreReleaseCommand());
    addSubcommand(TriagePostReleaseCommand());
  }

  // NOTE: `run()` is never called on branch commands (commands with
  // subcommands) — the `args` package throws UsageException for unrecognised
  // subcommand names before reaching run(). The `triage <number>` shorthand
  // is handled by ManageCicdCli.run() and triage_cli.dart's _translateArgs().
}
