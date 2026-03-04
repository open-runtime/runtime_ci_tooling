import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'exit_util.dart';
import 'logger.dart';

/// Maximum bytes to capture per stdout/stderr stream for timeout runs.
const int _kMaxOutputBytes = 32 * 1024; // 32KB

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

  /// Execute a command. Set [fatal] to true to exit on failure (flushes stdout/stderr before exiting).
  static Future<void> exec(
    String executable,
    List<String> args, {
    String? cwd,
    bool fatal = false,
    bool verbose = false,
  }) async {
    if (verbose) Logger.info('  \$ ${_redact('$executable ${args.join(" ")}')}');
    final result = Process.runSync(executable, args, workingDirectory: cwd);
    if (result.exitCode != 0) {
      final stderr = _redact((result.stderr as String).trim());
      Logger.error('  Command failed (exit ${result.exitCode}): $stderr');
      if (fatal) await exitWithCode(result.exitCode);
    }
  }

  /// Runs [executable] with [arguments] and [timeout]. On timeout, kills the
  /// process (TERM then KILL on Unix; single kill on Windows) and returns a
  /// [ProcessResult] with [timeoutExitCode] and stderr containing [timeoutMessage].
  /// Captures stdout/stderr with bounded buffers ([_kMaxOutputBytes] per stream).
  static Future<ProcessResult> runWithTimeout(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Duration timeout = const Duration(minutes: 5),
    int timeoutExitCode = 124,
    String timeoutMessage = 'Timed out',
  }) async {
    final process = await Process.start(executable, arguments, workingDirectory: workingDirectory);
    final stdoutBuf = StringBuffer();
    final stderrBuf = StringBuffer();
    final stdoutBytes = <int>[0];
    final stderrBytes = <int>[0];
    final stdoutTruncated = <bool>[false];
    final stderrTruncated = <bool>[false];
    const truncationSuffix = '\n\n... (output truncated).';
    final truncationBytes = utf8.encode(truncationSuffix).length;

    void capWrite(StringBuffer buf, String data, int maxBytes, List<bool> truncated, List<int> byteCount) {
      if (truncated[0]) return;
      final dataBytes = utf8.encode(data).length;
      if (byteCount[0] + dataBytes <= maxBytes) {
        buf.write(data);
        byteCount[0] += dataBytes;
      } else {
        final remainingTotal = maxBytes - byteCount[0];
        if (remainingTotal <= truncationBytes) {
          truncated[0] = true;
          return;
        }
        final payloadBudget = remainingTotal - truncationBytes;
        final bytes = utf8.encode(data);
        final toTake = bytes.length > payloadBudget ? payloadBudget : bytes.length;
        if (toTake > 0) {
          buf.write(utf8.decode(bytes.take(toTake).toList(), allowMalformed: true));
          byteCount[0] += toTake;
        }
        buf.write(truncationSuffix);
        byteCount[0] += truncationBytes;
        truncated[0] = true;
      }
    }

    final stdoutSub = process.stdout
        .transform(Utf8Decoder(allowMalformed: true))
        .listen((data) => capWrite(stdoutBuf, data, _kMaxOutputBytes, stdoutTruncated, stdoutBytes));
    final stderrSub = process.stderr
        .transform(Utf8Decoder(allowMalformed: true))
        .listen((data) => capWrite(stderrBuf, data, _kMaxOutputBytes, stderrTruncated, stderrBytes));
    final stdoutDone = stdoutSub.asFuture<void>();
    final stderrDone = stderrSub.asFuture<void>();

    var exitCode = timeoutExitCode;
    var timedOut = false;
    try {
      exitCode = await process.exitCode.timeout(timeout);
    } on TimeoutException {
      timedOut = true;
      await killAndAwaitExit(process);
    }

    try {
      await Future.wait([stdoutDone, stderrDone]).timeout(const Duration(seconds: 30));
    } catch (_) {
      // Best-effort drain complete.
    } finally {
      try {
        await Future.wait([stdoutSub.cancel(), stderrSub.cancel()]);
      } catch (_) {}
    }

    if (timedOut) {
      return ProcessResult(process.pid, timeoutExitCode, stdoutBuf.toString(), timeoutMessage);
    }

    return ProcessResult(process.pid, exitCode, stdoutBuf.toString(), stderrBuf.toString());
  }

  /// Kills [process] and awaits exit. On Unix: SIGTERM first, wait up to 5s;
  /// if still alive, SIGKILL and await. On Windows: single kill, then await.
  static Future<void> killAndAwaitExit(Process process) async {
    if (Platform.isWindows) {
      process.kill();
      try {
        await process.exitCode.timeout(const Duration(seconds: 10));
      } on TimeoutException {
        // Best-effort on Windows; caller has already timed out.
      }
      return;
    }
    process.kill(ProcessSignal.sigterm);
    try {
      await process.exitCode.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
      await process.exitCode;
    }
  }
}
