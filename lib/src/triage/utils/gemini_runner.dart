// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Parallel Gemini CLI executor with retry logic and rate limiting.
///
/// Manages a pool of concurrent Gemini CLI processes, retries on transient
/// failures with exponential backoff, and returns structured results.
///
/// Uses Future.wait for parallel execution and basic concurrency control
/// instead of external packages (to avoid adding heavy dependencies to a
/// script-only tool).

// ═══════════════════════════════════════════════════════════════════════════════
// Constants
// ═══════════════════════════════════════════════════════════════════════════════

const String kDefaultFlashModel = 'gemini-3-flash-preview';
const String kDefaultProModel = 'gemini-3-1-pro-preview';
const int kDefaultMaxTurns = 100;
const int kDefaultMaxConcurrent = 4;
const int kDefaultMaxRetries = 3;
const Duration kDefaultInitialBackoff = Duration(milliseconds: 500);
const Duration kDefaultMaxBackoff = Duration(seconds: 30);

// ═══════════════════════════════════════════════════════════════════════════════
// GeminiResult
// ═══════════════════════════════════════════════════════════════════════════════

/// The structured result from a Gemini CLI invocation.
class GeminiResult {
  final String taskId;
  final String? response;
  final Map<String, dynamic>? stats;
  final Map<String, dynamic>? error;
  final int attempts;
  final int durationMs;
  final bool success;

  GeminiResult({
    required this.taskId,
    this.response,
    this.stats,
    this.error,
    this.attempts = 1,
    this.durationMs = 0,
    required this.success,
  });

  /// Total tool calls made (actual Gemini CLI JSON path: stats.tools.totalCalls)
  int get toolCalls => (stats?['tools']?['totalCalls'] as int?) ?? 0;

  /// No turn count in Gemini CLI output -- use tool calls as proxy
  int get turnsUsed => toolCalls;
  String get errorMessage => error?['message'] as String? ?? 'Unknown error';
}

// ═══════════════════════════════════════════════════════════════════════════════
// GeminiTask
// ═══════════════════════════════════════════════════════════════════════════════

/// A single task to execute via Gemini CLI.
class GeminiTask {
  final String id;
  final String prompt;
  final String model;
  final int maxTurns;
  final List<String> allowedTools;
  final List<String> fileIncludes;
  final String? workingDirectory;
  final bool sandbox;

  /// Optional audit directory -- if set, prompts and responses are saved here.
  final String? auditDir;

  GeminiTask({
    required this.id,
    required this.prompt,
    this.model = kDefaultFlashModel,
    this.maxTurns = kDefaultMaxTurns,
    this.allowedTools = const ['run_shell_command(git)', 'run_shell_command(gh)'],
    this.fileIncludes = const [],
    this.workingDirectory,
    this.sandbox = false, // Disabled: -s causes E2BIG on re-launch
    this.auditDir,
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// GeminiRunner
// ═══════════════════════════════════════════════════════════════════════════════

/// Manages parallel Gemini CLI execution with retry and rate limiting.
class GeminiRunner {
  final int maxConcurrent;
  final int maxRetries;
  final Duration initialBackoff;
  final Duration maxBackoff;
  final bool verbose;

  int _activeCount = 0;
  final _queue = <Completer<void>>[];

  GeminiRunner({
    this.maxConcurrent = kDefaultMaxConcurrent,
    this.maxRetries = kDefaultMaxRetries,
    this.initialBackoff = kDefaultInitialBackoff,
    this.maxBackoff = kDefaultMaxBackoff,
    this.verbose = false,
  });

  /// Execute a batch of tasks in parallel with concurrency limiting.
  ///
  /// Returns results in the same order as tasks. Failed tasks return
  /// GeminiResult with success=false rather than throwing.
  Future<List<GeminiResult>> executeBatch(List<GeminiTask> tasks) async {
    _log('Executing batch of ${tasks.length} tasks (max $maxConcurrent concurrent)');

    final futures = tasks.map((task) => _executeWithConcurrencyLimit(task));
    final results = await Future.wait(futures);

    final succeeded = results.where((r) => r.success).length;
    final failed = results.where((r) => !r.success).length;
    _log('Batch complete: $succeeded succeeded, $failed failed');

    return results;
  }

  /// Execute a single task with concurrency limiting.
  Future<GeminiResult> _executeWithConcurrencyLimit(GeminiTask task) async {
    // Wait for a slot in the concurrency pool
    while (_activeCount >= maxConcurrent) {
      final completer = Completer<void>();
      _queue.add(completer);
      await completer.future;
    }

    _activeCount++;
    try {
      return await _executeWithRetry(task);
    } finally {
      _activeCount--;
      // Release next waiting task
      if (_queue.isNotEmpty) {
        _queue.removeAt(0).complete();
      }
    }
  }

  /// Execute a single task with exponential backoff retry.
  Future<GeminiResult> _executeWithRetry(GeminiTask task) async {
    final stopwatch = Stopwatch()..start();

    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      _log('  [${task.id}] Attempt $attempt/$maxRetries');

      try {
        final result = await _executeOnce(task);

        if (result.success) {
          stopwatch.stop();
          return GeminiResult(
            taskId: task.id,
            response: result.response,
            stats: result.stats,
            error: result.error,
            attempts: attempt,
            durationMs: stopwatch.elapsedMilliseconds,
            success: true,
          );
        }

        // Check if error is retryable
        final errorType = result.error?['type'] as String? ?? '';
        if (_isRetryable(errorType) && attempt < maxRetries) {
          final delay = _backoffDelay(attempt);
          _log('  [${task.id}] Retryable error ($errorType), waiting ${delay.inMilliseconds}ms');
          await Future.delayed(delay);
          continue;
        }

        // Non-retryable or out of retries
        stopwatch.stop();
        return GeminiResult(
          taskId: task.id,
          response: result.response,
          stats: result.stats,
          error: result.error,
          attempts: attempt,
          durationMs: stopwatch.elapsedMilliseconds,
          success: false,
        );
      } catch (e) {
        if (attempt < maxRetries) {
          final delay = _backoffDelay(attempt);
          _log('  [${task.id}] Exception: $e, retrying in ${delay.inMilliseconds}ms');
          await Future.delayed(delay);
          continue;
        }

        stopwatch.stop();
        return GeminiResult(
          taskId: task.id,
          error: {'type': 'ProcessException', 'message': '$e'},
          attempts: attempt,
          durationMs: stopwatch.elapsedMilliseconds,
          success: false,
        );
      }
    }

    // Should not reach here, but safety net
    stopwatch.stop();
    return GeminiResult(
      taskId: task.id,
      error: {'type': 'ExhaustedRetries', 'message': 'All $maxRetries attempts failed'},
      attempts: maxRetries,
      durationMs: stopwatch.elapsedMilliseconds,
      success: false,
    );
  }

  /// Execute a single Gemini CLI invocation.
  ///
  /// Uses the correct Gemini CLI v0.24+ syntax:
  ///   - Stdin piping for prompt (positional args, -p deprecated)
  ///   - --yolo for auto-approve (--approval-mode also works)
  ///   - -o json for JSON output
  ///   - -s for sandbox
  ///   - --allowed-tools 'tool1,tool2' (comma-separated string)
  ///   - No --max-turns flag (use model.maxSessionTurns in settings.json)
  Future<GeminiResult> _executeOnce(GeminiTask task) async {
    // Determine where to write the prompt file
    final promptDir = task.auditDir ?? '/tmp';
    final promptFile = File('$promptDir/gemini_prompt_${task.id}.txt');
    await promptFile.writeAsString(task.prompt);

    // Save prompt to audit trail if audit dir is set
    if (task.auditDir != null) {
      final agentsDir = Directory('${task.auditDir}/agents');
      agentsDir.createSync(recursive: true);
      File('${agentsDir.path}/${task.id}_prompt.txt').writeAsStringSync(task.prompt);
    }

    // Build command using correct Gemini CLI v0.24+ syntax
    final toolsArg = task.allowedTools.join(',');

    final parts = <String>['cat ${promptFile.path} | gemini', '-o json', '--yolo', '-m ${task.model}'];
    if (task.sandbox) parts.add('-s');
    if (toolsArg.isNotEmpty) parts.add("--allowed-tools '$toolsArg'");
    for (final include in task.fileIncludes) {
      parts.add('@$include');
    }

    final command = parts.join(' ');

    final result = await Process.run(
      'sh',
      ['-c', command],
      workingDirectory: task.workingDirectory ?? Directory.current.path,
      environment: Platform.environment,
    );

    // Clean up prompt file
    try {
      await promptFile.delete();
    } catch (_) {}

    if (result.exitCode != 0) {
      return GeminiResult(
        taskId: task.id,
        error: {'type': 'ProcessError', 'message': 'Exit code ${result.exitCode}: ${(result.stderr as String).trim()}'},
        success: false,
      );
    }

    // Save raw response to audit trail
    final rawStdout = result.stdout as String;
    if (task.auditDir != null) {
      final agentsDir = Directory('${task.auditDir}/agents');
      agentsDir.createSync(recursive: true);
      File('${agentsDir.path}/${task.id}_response.json').writeAsStringSync(rawStdout);
    }

    // Parse JSON response -- Gemini CLI may output warning lines before JSON
    try {
      final stdout = rawStdout;
      final jsonStart = stdout.indexOf('{');
      if (jsonStart < 0) {
        return GeminiResult(
          taskId: task.id,
          error: {'type': 'NoJsonOutput', 'message': 'No JSON found in Gemini output'},
          success: false,
        );
      }

      final jsonStr = stdout.substring(jsonStart);
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;

      return GeminiResult(
        taskId: task.id,
        response: json['response'] as String?,
        stats: json['stats'] as Map<String, dynamic>?,
        success: true,
      );
    } catch (e) {
      return GeminiResult(
        taskId: task.id,
        error: {'type': 'JsonParseError', 'message': 'Failed to parse Gemini JSON output: $e'},
        success: false,
      );
    }
  }

  /// Compute exponential backoff delay with jitter.
  Duration _backoffDelay(int attempt) {
    final baseMs = initialBackoff.inMilliseconds * (1 << (attempt - 1));
    final jitterMs = (baseMs * 0.25 * (DateTime.now().millisecond % 100) / 100).round();
    final totalMs = (baseMs + jitterMs).clamp(0, maxBackoff.inMilliseconds);
    return Duration(milliseconds: totalMs);
  }

  /// Whether an error type is retryable.
  bool _isRetryable(String errorType) {
    return const {
      'RateLimitError',
      'ServiceUnavailable',
      'InternalError',
      'TimeoutError',
      'ProcessError',
    }.contains(errorType);
  }

  void _log(String msg) {
    if (verbose) print(msg);
  }
}
