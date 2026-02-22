import 'dart:io';

import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';

/// Backward-compatible entry point for triage CLI.
///
/// Delegates to `manage_cicd triage <args>` so that existing scripts
/// and CI workflows continue to work unchanged.
///
/// Examples (all equivalent):
///   dart run runtime_ci_tooling:triage_cli 42
///   dart run runtime_ci_tooling:manage_cicd triage single 42
///
///   dart run runtime_ci_tooling:triage_cli --auto
///   dart run runtime_ci_tooling:manage_cicd triage auto
///
///   dart run runtime_ci_tooling:triage_cli --status
///   dart run runtime_ci_tooling:manage_cicd triage status
Future<void> main(List<String> args) async {
  // Translate old-style flags to subcommand form:
  //   --auto         → triage auto
  //   --status       → triage status
  //   --pre-release  → triage pre-release
  //   --post-release → triage post-release
  //   --resume <id>  → triage resume <id>
  //   <number>       → triage single <number> (handled by TriageCommand.run)
  final translated = _translateArgs(args);

  final cli = ManageCicdCli();
  try {
    await cli.run(['triage', ...translated]);
  } on UsageException catch (e) {
    stderr.writeln(e);
    exit(64);
  }
}

/// Translate old-style triage CLI args to CommandRunner subcommand form.
List<String> _translateArgs(List<String> args) {
  final result = <String>[];
  var i = 0;

  // First pass: extract the mode flag and convert to subcommand
  String? subcommand;
  final remaining = <String>[];

  while (i < args.length) {
    final arg = args[i];
    switch (arg) {
      case '--auto':
        subcommand = 'auto';
      case '--status':
        subcommand = 'status';
      case '--pre-release':
        subcommand = 'pre-release';
      case '--post-release':
        subcommand = 'post-release';
      case '--resume':
        subcommand = 'resume';
        // The next arg is the run ID — pass it through
        if (i + 1 < args.length) {
          remaining.add(args[i + 1]);
          i++;
        }
      default:
        remaining.add(arg);
    }
    i++;
  }

  if (subcommand != null) {
    result.add(subcommand);
  }
  result.addAll(remaining);

  return result;
}
