// ignore_for_file: avoid_print

import 'dart:io';

/// Stage 1 Explorer Agent prompt generator.
///
/// Generates the changelog analysis prompt with interpolated context including
/// project tree, commit messages, diff statistics, and version info. The output
/// is piped to Gemini CLI for autonomous exploration.
///
/// Usage:
///   dart run scripts/prompts/gemini_changelog_prompt.dart <prev_tag> <new_version>
///
/// Example:
///   dart run scripts/prompts/gemini_changelog_prompt.dart v0.0.1 0.0.2 | \
///     gemini -o json --yolo -s -m gemini-3-flash-preview ...

void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln('Usage: dart run scripts/prompts/gemini_changelog_prompt.dart <prev_tag> <new_version>');
    exit(1);
  }

  final prevTag = args[0];
  final newVersion = args[1];

  // Gather context via shell commands
  final tree = _runSync('tree lib/ -L 2 --dirsfirst -I "*.pb.dart|*.pbenum.dart|*.pbjson.dart|*.pbgrpc.dart"');
  final protoTree = _runSync('tree proto/src/ -L 3 --dirsfirst');
  final commitLog = _truncate(_runSync('git log $prevTag..HEAD --format="%h | %s | %an | %aI" --no-merges'), 50000);
  final commitBodies = _truncate(_runSync('git log $prevTag..HEAD --format="--- %h %s ---%n%b" --no-merges'), 50000);
  final diffStat = _truncate(_runSync('git diff --stat $prevTag..HEAD'), 20000);
  final changedFiles = _truncate(_runSync('git diff --name-only $prevTag..HEAD'), 20000);
  final commitCount = _runSync('git rev-list --count $prevTag..HEAD');

  print('''
You are a Stage 1 Explorer Agent analyzing the runtime_isomorphic_library Dart package
for release v$newVersion (previous: $prevTag).

Your job is to DEEPLY explore this repository and write structured JSON artifacts to .cicd_runs/explore/.
You have access to git and gh (GitHub CLI) tools. Use them extensively.

## Project Structure (lib/)
```
$tree
```

## Proto Structure (proto/src/)
```
$protoTree
```

## $commitCount Commits since $prevTag
```
$commitLog
```

## Commit Messages with Bodies
```
$commitBodies
```

## Diff Statistics
```
$diffStat
```

## Changed Files
```
$changedFiles
```

## Issue Manifest (Pre-Release Triage)

If .cicd_runs/triage/issue_manifest.json exists, READ IT. It contains GitHub issues and Sentry errors
that this release likely addresses, with confidence scores. Use this to:
- Include issue references (#N) in the commit_analysis.json categories
- Mark issues as "fixed" in the appropriate category
- Note any Sentry errors that are resolved

## Exploration Instructions

You MUST autonomously explore and gather data. Do all of the following:

1. Run `git diff $prevTag..HEAD` to see the FULL diff (do NOT truncate or summarize)
2. Run `gh pr list --state merged --json number,title,body,labels,author --limit 100` for merged PR context
3. For each merged PR, run `gh pr view <number> --json title,body,labels,author,commits` to get full details
4. For breaking or significant commits, run `git show <sha>` to understand the change deeply
5. Run `gh pr list --state merged --json number,author --jq '.[].author.login' | sort -u` for unique contributors
6. Look at any changed test files to understand what new behavior is being tested
7. If .cicd_runs/triage/issue_manifest.json exists, read it and cross-reference issues with your findings

## Output Requirements

Write EXACTLY these JSON files (create the directories if needed):

### .cicd_runs/explore/commit_analysis.json
```json
{
  "version": "$newVersion",
  "previous_version": "$prevTag",
  "total_commits": <number>,
  "categories": {
    "added": [
      {"description": "Human-readable description of what was added", "pr": "#N", "commits": ["sha1", "sha2"]}
    ],
    "changed": [
      {"description": "What was changed and why", "pr": "#N", "commits": ["sha1"]}
    ],
    "deprecated": [],
    "removed": [],
    "fixed": [
      {"description": "What bug was fixed", "pr": "#N", "commits": ["sha1"]}
    ],
    "security": []
  }
}
```

### .cicd_runs/explore/pr_data.json
```json
{
  "pull_requests": [
    {
      "number": 123,
      "title": "PR title",
      "author": "github-username",
      "labels": ["label1", "label2"],
      "summary": "1-2 sentence summary of the PR's purpose and impact",
      "commits": ["sha1", "sha2"]
    }
  ]
}
```

### .cicd_runs/explore/breaking_changes.json
```json
{
  "has_breaking_changes": false,
  "changes": [
    {
      "description": "What broke and why",
      "affected_apis": ["ClassName.methodName"],
      "migration_guide": "Step-by-step migration instructions",
      "pr": "#N"
    }
  ]
}
```

IMPORTANT:
- Write valid JSON only. Validate before writing.
- Include EVERY commit and PR, not just a sample.
- Be thorough -- investigate deeply, do not summarize prematurely.
- If there are no items for a category, use an empty array [].
''');
}

/// Runs a shell command synchronously and returns stdout, or a fallback message on error.
String _runSync(String command) {
  try {
    final result = Process.runSync('sh', ['-c', command], workingDirectory: Directory.current.path);
    if (result.exitCode == 0) {
      return (result.stdout as String).trim();
    }
    return '(command failed: $command)';
  } catch (e) {
    return '(command unavailable: $command)';
  }
}

/// Truncate output to [maxChars] to prevent E2BIG when prompts are passed
/// to Gemini CLI. Large initial diffs can exceed Linux ARG_MAX.
String _truncate(String input, int maxChars) {
  if (input.length <= maxChars) return input;
  return '${input.substring(0, maxChars)}\n\n... [TRUNCATED: ${input.length - maxChars} chars omitted. Use git/gh tools to explore the full diff.]\n';
}
