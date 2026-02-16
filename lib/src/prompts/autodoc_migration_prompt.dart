// ignore_for_file: avoid_print

import 'dart:io';

/// Autodoc: MIGRATION.md generator for a proto module.
///
/// Usage:
///   dart run scripts/prompts/autodoc_migration_prompt.dart <module_name> <source_dir> <prev_hash>

void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln('Usage: autodoc_migration_prompt.dart <module_name> <source_dir> [prev_hash]');
    exit(1);
  }

  final moduleName = args[0];
  final sourceDir = args[1];
  final prevHash = args.length > 2 ? args[2] : '';

  // Get diff of proto files
  String protoDiff;
  if (prevHash.isNotEmpty) {
    protoDiff = _truncate(_runSync('git diff $prevHash..HEAD -- $sourceDir'), 30000);
  } else {
    // No previous hash, show recent changes
    protoDiff = _truncate(_runSync('git log --oneline -20 -- $sourceDir'), 5000);
  }

  // Get list of changed files
  final changedFiles = prevHash.isNotEmpty
      ? _runSync('git diff --name-only $prevHash..HEAD -- $sourceDir')
      : _runSync('git log --oneline --name-only -10 -- $sourceDir | grep ".proto"');

  // Get added/removed messages and fields
  final addedMessages = prevHash.isNotEmpty
      ? _runSync('git diff $prevHash..HEAD -- $sourceDir | grep "^+" | grep "message\\|field\\|rpc\\|enum" | head -20')
      : '';
  final removedMessages = prevHash.isNotEmpty
      ? _runSync('git diff $prevHash..HEAD -- $sourceDir | grep "^-" | grep "message\\|field\\|rpc\\|enum" | head -20')
      : '';

  print('''
You are writing a migration guide for the **$moduleName** module
of the runtime_isomorphic_library Dart package.

## Proto Changes
```diff
$protoDiff
```

## Changed Files
```
$changedFiles
```

${addedMessages.isNotEmpty ? '## Added Definitions\n```\n$addedMessages\n```' : ''}
${removedMessages.isNotEmpty ? '## Removed Definitions\n```\n$removedMessages\n```' : ''}

## Instructions

Generate a MIGRATION.md that helps developers update their code:

### 1. Breaking Changes
For each breaking change (removed/renamed messages, fields, services, enums):
- What was removed/renamed
- The replacement (if any)
- Before/after code example

### 2. New Features
For each new message/service/field added:
- What it does
- Basic usage example

### 3. Deprecated Items
Anything marked deprecated and its replacement timeline.

### 4. Upgrade Steps
Step-by-step guide:
1. Update dependency
2. Fix breaking changes (with find-and-replace patterns)
3. Adopt new features (optional)

## Rules
- Use ONLY real names from the proto diff
- Before/after code must be valid Dart
- If there are no breaking changes, say so clearly
- Keep it actionable and concise

Generate the complete MIGRATION.md content and write it to the file path
specified by the build system.
''');
}

String _runSync(String command) {
  try {
    final result = Process.runSync('sh', ['-c', command], workingDirectory: Directory.current.path);
    if (result.exitCode == 0) return (result.stdout as String).trim();
    return '';
  } catch (_) {
    return '';
  }
}

String _truncate(String input, int maxChars) {
  if (input.length <= maxChars) return input;
  return '${input.substring(0, maxChars)}\n\n... [TRUNCATED]\n';
}
