import 'dart:io';

import 'logger.dart';
import 'process_runner.dart';

/// Utilities for Gemini CLI integration.
abstract final class GeminiUtils {
  /// Returns true if Gemini CLI and API key are both available.
  /// When [warnOnly] is true, logs a warning instead of exiting.
  static bool geminiAvailable({bool warnOnly = false}) {
    if (!CiProcessRunner.commandExists('gemini')) {
      if (warnOnly) {
        Logger.warn(
            'Gemini CLI not installed — skipping Gemini-powered step.');
        return false;
      }
      Logger.error(
          'Gemini CLI is not installed. Run: dart run runtime_ci_tooling:manage_cicd setup');
      exit(1);
    }
    final key = Platform.environment['GEMINI_API_KEY'];
    if (key == null || key.isEmpty) {
      if (warnOnly) {
        Logger.warn('GEMINI_API_KEY not set — skipping Gemini-powered step.');
        return false;
      }
      Logger.error('GEMINI_API_KEY is not set.');
      exit(1);
    }
    return true;
  }

  /// Require Gemini CLI to be installed (exit if not).
  static void requireGeminiCli() {
    if (!CiProcessRunner.commandExists('gemini')) {
      Logger.error(
          'Gemini CLI is not installed. Run: dart run runtime_ci_tooling:manage_cicd setup');
      exit(1);
    }
  }

  /// Require GEMINI_API_KEY to be set (exit if not).
  static void requireApiKey() {
    final key = Platform.environment['GEMINI_API_KEY'];
    if (key == null || key.isEmpty) {
      Logger.error('GEMINI_API_KEY is not set.');
      Logger.error(
          'Set it via: export GEMINI_API_KEY=<your-key-from-aistudio.google.com>');
      exit(1);
    }
  }

  /// Extract JSON from Gemini CLI output.
  ///
  /// Gemini CLI v0.24+ may output warning/error lines (MCP discovery,
  /// deprecation) to stdout before the JSON object. This finds the first
  /// '{' and extracts from there.
  static String extractJson(String rawOutput) {
    final jsonStart = rawOutput.indexOf('{');
    if (jsonStart < 0) {
      throw FormatException('No JSON object found in Gemini output');
    }
    return rawOutput.substring(jsonStart);
  }
}
