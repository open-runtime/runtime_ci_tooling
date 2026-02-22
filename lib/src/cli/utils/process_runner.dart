import 'dart:io';

import 'logger.dart';

/// Utilities for running external processes.
abstract final class CiProcessRunner {
  /// Check whether a command is available on the system PATH.
  static bool commandExists(String command) {
    try {
      final which = Platform.isWindows ? 'where' : 'which';
      final result = Process.runSync(which, [command]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Run a shell command synchronously and return trimmed stdout.
  static String runSync(String command, String workingDirectory,
      {bool verbose = false}) {
    if (verbose) Logger.info('[CMD] $command');
    final result = Process.runSync('sh', ['-c', command],
        workingDirectory: workingDirectory);
    final output = (result.stdout as String).trim();
    if (verbose && output.isNotEmpty) Logger.info('  $output');
    return output;
  }

  /// Execute a command. Set [fatal] to true to exit on failure.
  static void exec(String executable, List<String> args,
      {String? cwd, bool fatal = false, bool verbose = false}) {
    if (verbose) Logger.info('  \$ $executable ${args.join(" ")}');
    final result =
        Process.runSync(executable, args, workingDirectory: cwd);
    if (result.exitCode != 0) {
      Logger.error(
          '  Command failed (exit ${result.exitCode}): ${result.stderr}');
      if (fatal) exit(result.exitCode);
    }
  }
}
