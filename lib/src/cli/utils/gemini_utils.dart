import 'dart:io';

import 'logger.dart';
import 'process_runner.dart';

/// Exception thrown when Gemini CLI prerequisites are not met.
class GeminiPrerequisiteError implements Exception {
  final String message;
  GeminiPrerequisiteError(this.message);

  @override
  String toString() => 'GeminiPrerequisiteError: $message';
}

/// Utilities for Gemini CLI integration.
abstract final class GeminiUtils {
  /// Returns true if Gemini CLI and API key are both available.
  /// When [warnOnly] is true, logs a warning instead of throwing.
  static bool geminiAvailable({bool warnOnly = false}) {
    if (!CiProcessRunner.commandExists('gemini')) {
      if (warnOnly) {
        Logger.warn('Gemini CLI not installed — skipping Gemini-powered step.');
        return false;
      }
      throw GeminiPrerequisiteError('Gemini CLI is not installed. Run: dart run runtime_ci_tooling:manage_cicd setup');
    }
    final key = Platform.environment['GEMINI_API_KEY'];
    if (key == null || key.isEmpty) {
      if (warnOnly) {
        Logger.warn('GEMINI_API_KEY not set — skipping Gemini-powered step.');
        return false;
      }
      throw GeminiPrerequisiteError('GEMINI_API_KEY is not set.');
    }
    return true;
  }

  /// Require Gemini CLI to be installed (throws if not).
  static void requireGeminiCli() {
    if (!CiProcessRunner.commandExists('gemini')) {
      throw GeminiPrerequisiteError('Gemini CLI is not installed. Run: dart run runtime_ci_tooling:manage_cicd setup');
    }
  }

  /// Require GEMINI_API_KEY to be set (throws if not).
  static void requireApiKey() {
    final key = Platform.environment['GEMINI_API_KEY'];
    if (key == null || key.isEmpty) {
      throw GeminiPrerequisiteError(
        'GEMINI_API_KEY is not set. Set it via: export GEMINI_API_KEY=<your-key-from-aistudio.google.com>',
      );
    }
  }

  /// Extract the first balanced JSON object from raw output.
  ///
  /// Uses bracket-counting to correctly handle nested objects.
  /// Gemini CLI v0.24+ may output warning/error lines before the JSON.
  static String extractJson(String rawOutput) {
    final result = extractJsonObject(rawOutput);
    if (result == null) {
      throw FormatException('No JSON object found in Gemini output');
    }
    return result;
  }

  /// Extract the first balanced JSON object from text, or null if none found.
  static String? extractJsonObject(String text) {
    final start = text.indexOf('{');
    if (start < 0) return null;

    var depth = 0;
    var inString = false;
    var escaped = false;

    for (var i = start; i < text.length; i++) {
      final ch = text[i];
      if (escaped) {
        escaped = false;
        continue;
      }
      if (ch == r'\' && inString) {
        escaped = true;
        continue;
      }
      if (ch == '"') {
        inString = !inString;
        continue;
      }
      if (inString) continue;
      if (ch == '{') depth++;
      if (ch == '}') {
        depth--;
        if (depth == 0) return text.substring(start, i + 1);
      }
    }
    return null;
  }
}
