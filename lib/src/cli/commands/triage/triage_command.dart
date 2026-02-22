import 'package:args/command_runner.dart';

import 'triage_auto_command.dart';
import 'triage_post_release_command.dart';
import 'triage_pre_release_command.dart';
import 'triage_resume_command.dart';
import 'triage_single_command.dart';
import 'triage_status_command.dart';

/// Triage command group with subcommands.
///
/// Supports both explicit subcommands and shorthand:
///   manage_cicd triage single 42
///   manage_cicd triage 42          (auto-detects positional number)
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

  @override
  Future<void> run() async {
    // Support shorthand: `triage 42` → delegates to `triage single 42`
    final rest = argResults!.rest;
    if (rest.isNotEmpty) {
      final issueNumber = int.tryParse(rest.first);
      if (issueNumber != null) {
        // Delegate to TriageSingleCommand logic
        await TriageSingleCommand.runSingle(issueNumber, globalResults);
        return;
      }
    }

    // No subcommand matched, no positional number → print usage
    printUsage();
  }
}
