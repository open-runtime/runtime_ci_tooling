import 'dart:io';

import 'logger.dart';

/// Utilities for running external processes.
abstract final class CiProcessRunner {
  /// Patterns that look like tokens/secrets — redact before logging.
  static final _secretPatterns = [
    // GitHub PATs (classic and fine-grained)
    RegExp(r'ghp_[A-Za-z0-9]{36,}'),
    RegExp(r'github_pat_[A-Za-z0-9_]{80,}'),
    // Generic long hex/base64 strings that follow "token" or auth keywords
    RegExp(r'(?<=token[=: ])[A-Za-z0-9_\-]{20,}', caseSensitive: false),
    RegExp(r'(?<=bearer )[A-Za-z0-9_\-\.]{20,}', caseSensitive: false),
    // URLs with embedded credentials (https://user:TOKEN@host)
    RegExp(r'(?<=:)[A-Za-z0-9_\-]{20,}(?=@github\.com)'),
  ];

  /// Redact secrets from a string before logging.
  static String _redact(String input) {
    var result = input;
    for (final pattern in _secretPatterns) {
      result = result.replaceAll(pattern, '***REDACTED***');
    }
    return result;
  }

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
  static String runSync(String command, String workingDirectory, {bool verbose = false}) {
    if (verbose) Logger.info('[CMD] ${_redact(command)}');
    final result = Process.runSync('sh', ['-c', command], workingDirectory: workingDirectory);
    final output = (result.stdout as String).trim();
    if (verbose && output.isNotEmpty) Logger.info('  $output');
    return output;
  }

  /// Execute a command. Set [fatal] to true to exit on failure.
  static void exec(String executable, List<String> args, {String? cwd, bool fatal = false, bool verbose = false}) {
    if (verbose) Logger.info('  \$ ${_redact('$executable ${args.join(" ")}')}');
    final result = Process.runSync(executable, args, workingDirectory: cwd);
    if (result.exitCode != 0) {
      Logger.error('  Command failed (exit ${result.exitCode}): ${result.stderr}');
      if (fatal) exit(result.exitCode);
    }
  }
}
