// ignore_for_file: avoid_print

import 'dart:io';

/// Stage 2 Documentation Update prompt generator.
///
/// Generates a prompt that instructs Gemini Pro to analyze proto/API changes
/// and update README.md sections accordingly. Focuses on keeping documentation
/// in sync with the codebase without restructuring existing content.
///
/// Usage:
///   dart run scripts/prompts/gemini_documentation_prompt.dart <prev_tag> <new_version>
///
/// Example:
///   dart run scripts/prompts/gemini_documentation_prompt.dart v0.0.1 0.0.2 | \
///     gemini -o json --yolo -s -m gemini-3-pro-preview \
///     @.cicd_runs/explore/commit_analysis.json @README.md ...

void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln('Usage: dart run scripts/prompts/gemini_documentation_prompt.dart <prev_tag> <new_version>');
    exit(1);
  }

  final prevTag = args[0];
  final newVersion = args[1];

  // Gather context about what changed
  final libTree = _runSync('tree lib/ -L 3 --dirsfirst -I "*.pb.dart|*.pbenum.dart|*.pbjson.dart|*.pbgrpc.dart"');
  final protoTree = _runSync('tree proto/src/ -L 3 --dirsfirst');
  final changedProtos = _truncate(_runSync('git diff --name-only $prevTag..HEAD -- proto/'), 20000);
  final changedLib = _truncate(_runSync('git diff --name-only $prevTag..HEAD -- lib/'), 20000);
  final changedScripts = _truncate(_runSync('git diff --name-only $prevTag..HEAD -- scripts/'), 20000);
  final newFiles = _truncate(_runSync('git diff --name-only --diff-filter=A $prevTag..HEAD'), 20000);
  final deletedFiles = _truncate(_runSync('git diff --name-only --diff-filter=D $prevTag..HEAD'), 20000);
  final pubspecDiff = _runSync('git diff $prevTag..HEAD -- pubspec.yaml');
  final scriptNames = _runSync('ls scripts/*.dart 2>/dev/null');

  print('''
You are a Documentation Update Agent for the runtime_isomorphic_library Dart package.

Your job is to update README.md to reflect changes in version v$newVersion.
The commit analysis JSON is provided via @include for understanding what changed.

## Current Library Structure
```
$libTree
```

## Proto Source Structure
```
$protoTree
```

## Changed Proto Files (since $prevTag)
```
$changedProtos
```

## Changed Library Files (since $prevTag)
```
$changedLib
```

## Changed Scripts (since $prevTag)
```
$changedScripts
```

## New Files Added
```
$newFiles
```

## Deleted Files
```
$deletedFiles
```

## pubspec.yaml Changes
```
$pubspecDiff
```

## Available CLI Scripts
```
$scriptNames
```

## Documentation Update Instructions

1. Read the current README.md (provided via @include)
2. Read .cicd_runs/explore/commit_analysis.json (provided via @include) to understand categorized changes

3. Make TARGETED updates to README.md:
   - Update any version references from the old version to v$newVersion
   - If new proto domains were added (new directories in proto/src/), add them to the
     relevant README section listing supported APIs/protocols
   - If new ML model parents were added (lib/machine_learning/parents/), document them
   - If new scripts were added to scripts/, document their usage
   - If dependencies changed (pubspec.yaml diff), update any dependency documentation
   - If new features were added per the commit analysis, consider adding them to
     the features/capabilities section

4. Do NOT:
   - Restructure the README layout
   - Remove existing content
   - Create new files
   - Modify proto source files
   - Add content that isn't supported by actual code changes

5. If NO documentation updates are needed, leave README.md unchanged.

Write the updated README.md directly to ./README.md (overwrite only if there are actual changes).
''');
}

/// Runs a shell command synchronously and returns stdout, or a fallback message on error.
String _runSync(String command) {
  try {
    final result = Process.runSync('sh', ['-c', command], workingDirectory: Directory.current.path);
    if (result.exitCode == 0) {
      return (result.stdout as String).trim();
    }
    return '(no changes)';
  } catch (e) {
    return '(unavailable)';
  }
}

/// Truncate to prevent E2BIG when prompts exceed Linux ARG_MAX.
String _truncate(String input, int maxChars) {
  if (input.length <= maxChars) return input;
  return '${input.substring(0, maxChars)}\n\n... [TRUNCATED: ${input.length - maxChars} chars omitted. Use git/gh tools to explore the full diff.]\n';
}
