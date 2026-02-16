// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

/// JSON validation utilities for triage pipeline artifacts.
///
/// Validates game plans, investigation results, and triage decisions
/// against expected schemas before they are consumed by downstream phases.

/// Validates that a JSON file exists, is valid JSON, and contains required keys.
///
/// Returns a validation result with success status and any error messages.
ValidationResult validateJsonFile(String path, List<String> requiredKeys) {
  final file = File(path);

  if (!file.existsSync()) {
    return ValidationResult(valid: false, path: path, errors: ['File does not exist: $path']);
  }

  final content = file.readAsStringSync();
  if (content.trim().isEmpty) {
    return ValidationResult(valid: false, path: path, errors: ['File is empty: $path']);
  }

  Map<String, dynamic> json;
  try {
    json = jsonDecode(content) as Map<String, dynamic>;
  } catch (e) {
    return ValidationResult(valid: false, path: path, errors: ['Invalid JSON: $e']);
  }

  final missingKeys = <String>[];
  for (final key in requiredKeys) {
    if (!json.containsKey(key)) {
      missingKeys.add(key);
    }
  }

  if (missingKeys.isNotEmpty) {
    return ValidationResult(valid: false, path: path, errors: ['Missing required keys: ${missingKeys.join(", ")}']);
  }

  return ValidationResult(valid: true, path: path);
}

/// Validates a game plan JSON structure.
ValidationResult validateGamePlan(String path) {
  return validateJsonFile(path, ['plan_id', 'created_at', 'issues']);
}

/// Validates an investigation result JSON structure.
ValidationResult validateInvestigationResult(String path) {
  return validateJsonFile(path, ['agent_id', 'issue_number', 'confidence', 'summary']);
}

/// Writes a JSON object to a file with pretty formatting.
void writeJson(String path, Map<String, dynamic> data) {
  File(path).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(data)}\n');
}

/// Reads and parses a JSON file, returning null on error.
Map<String, dynamic>? readJson(String path) {
  try {
    return jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ValidationResult
// ═══════════════════════════════════════════════════════════════════════════════

class ValidationResult {
  final bool valid;
  final String path;
  final List<String> errors;

  ValidationResult({required this.valid, required this.path, this.errors = const []});

  @override
  String toString() => valid ? 'Valid: $path' : 'Invalid: $path -- ${errors.join("; ")}';
}
