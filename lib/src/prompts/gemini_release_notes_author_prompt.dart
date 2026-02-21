// ignore_for_file: avoid_print

import 'dart:io';

import '_ci_config.dart';

/// Stage 3 Release Notes Author prompt generator.
///
/// Produces rich, narrative release notes distinct from the CHANGELOG.
/// The CHANGELOG (Stage 2) is concise and literal. This stage produces
/// detailed, user-friendly release documentation with:
/// - Executive summary and highlights
/// - Breaking changes with before/after code examples and migration guides
/// - Feature descriptions with real source code references
/// - Linked GitHub issues and Sentry errors
/// - Upgrade instructions
///
/// Usage:
///   dart run scripts/prompts/gemini_release_notes_author_prompt.dart <prev_tag> <new_version> [<bump_type>]

void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln(
      'Usage: dart run scripts/prompts/gemini_release_notes_author_prompt.dart <prev_tag> <new_version> [patch|minor|major]',
    );
    exit(1);
  }

  final prevTag = args[0];
  final newVersion = args[1];
  final bumpType = args.length > 2 ? args[2] : _inferBumpType(prevTag, newVersion);

  final pkg = CiConfig.current.packageName;
  final owner = CiConfig.current.repoOwner;

  final today = DateTime.now().toIso8601String().substring(0, 10);
  final ghContributors = _runSync('git log $prevTag..HEAD --format="%an" --no-merges | sort -u');
  final totalCommits = _runSync('git rev-list --count $prevTag..HEAD');
  final totalFiles = _runSync('git diff --name-only $prevTag..HEAD | wc -l');
  final diffStat = _truncate(_runSync('git diff --stat $prevTag..HEAD'), 10000);
  final recentCommits = _truncate(_runSync('git log $prevTag..HEAD --oneline --no-merges'), 5000);

  // Check which data sources are available
  final hasCommitAnalysis =
      _fileExists('/tmp/commit_analysis.json') || _fileExists('.cicd_runs/explore/commit_analysis.json');
  final hasPrData = _fileExists('/tmp/pr_data.json') || _fileExists('.cicd_runs/explore/pr_data.json');
  final hasBreakingChanges =
      _fileExists('/tmp/breaking_changes.json') || _fileExists('.cicd_runs/explore/breaking_changes.json');
  final hasIssueManifest =
      _fileExists('/tmp/issue_manifest.json') || _fileExists('.cicd_runs/triage/issue_manifest.json');
  final hasChangelog = _fileExists('CHANGELOG.md');
  final hasVersionBump = _fileExists('version_bumps/v$newVersion.md');

  print('''
You are a Release Notes Author for the $pkg Dart package.
Your job is to write RICH, DETAILED, USER-FRIENDLY release notes that will appear
on the GitHub Release page. These are DIFFERENT from the CHANGELOG -- the CHANGELOG
is a concise list; your release notes tell the STORY of this release.

## Release Context
- **Package**: $pkg
- **Version**: v$newVersion (${bumpType.toUpperCase()} release)
- **Previous**: $prevTag
- **Date**: $today
- **Commits**: $totalCommits
- **Files changed**: $totalFiles
- **Contributors**: $ghContributors

## Diff Summary
```
$diffStat
```

## Recent Commits
```
$recentCommits
```

## Available Data Sources (provided via @includes or accessible via tools)
${hasCommitAnalysis ? '- commit_analysis.json -- Structured commit categories from Stage 1 Explorer' : '- commit_analysis.json: NOT AVAILABLE -- use git log directly'}
${hasPrData ? '- pr_data.json -- PR metadata with summaries from Stage 1 Explorer' : '- pr_data.json: NOT AVAILABLE -- use gh pr list directly'}
${hasBreakingChanges ? '- breaking_changes.json -- Breaking changes with affected APIs from Stage 1' : '- breaking_changes.json: NOT AVAILABLE'}
${hasIssueManifest ? '- issue_manifest.json -- GitHub issues and Sentry errors linked to this release' : '- issue_manifest.json: NOT AVAILABLE'}
${hasChangelog ? '- CHANGELOG.md -- The concise changelog entry (already written by Stage 2)' : '- CHANGELOG.md: NOT AVAILABLE'}
${hasVersionBump ? '- version_bumps/v$newVersion.md -- Version bump rationale' : ''}

## Your Tools

You have access to git and gh (GitHub CLI). USE THEM to:
- `git diff $prevTag..HEAD -- <file>` to see exact changes in specific files
- `git show <sha>` to read specific commits
- `cat <filepath>` to read source code files for before/after examples
- `gh issue view <N>` to get full issue details
- `gh pr view <N>` to get full PR details and discussions

## Output Instructions

Write the following files. Create directories as needed.

### 1. release_notes/v$newVersion/release_notes.md

This is the MAIN output -- what users see on the GitHub Release page.

${_releaseNotesTemplate(bumpType, newVersion, prevTag, today, pkg, owner)}

### 2. release_notes/v$newVersion/migration_guide.md (if breaking changes exist)

For EACH breaking change:

```markdown
# Migration Guide: v$prevTag → v$newVersion

## Table of Contents
- [Change Name](#change-name)

---

## Change Name

### Summary
One sentence: what changed.

### Background
Why this change was made (1-2 sentences).

### Migration

**Before:**
```dart
// Show the ACTUAL old code from git diff, not made-up examples
```

**After:**
```dart
// Show the ACTUAL new code from the source files
```

### References
- Issue: [#N](https://github.com/$owner/$pkg/issues/N)
- PR: [#N](https://github.com/$owner/$pkg/pull/N)
```

Use `git diff $prevTag..HEAD` and `cat` to find the REAL before/after code.
Do NOT make up code examples -- use the actual source code from the repository.

### 3. release_notes/v$newVersion/linked_issues.json

```json
{
  "version": "$newVersion",
  "github_issues": [
    {
      "number": 123,
      "title": "Issue title",
      "status": "fixed",
      "confidence": 0.95,
      "referenced_in": ["release_notes", "changelog"]
    }
  ],
  "sentry_issues": [],
  "prs_referenced": [
    {"number": 1, "title": "PR title", "author": "username"}
  ]
}
```

### 4. release_notes/v$newVersion/highlights.md

3-5 bullet points summarizing the most impactful changes. This is for
announcements and social media. Keep each bullet to ONE sentence.

## CRITICAL: Anti-Hallucination Rules

These rules are NON-NEGOTIABLE. Violating them produces incorrect release notes.

### Contributors
- The build system will REPLACE the Contributors section with verified data.
- Write a placeholder: "## Contributors\n\n(auto-generated from verified commit data)"
- Do NOT guess or look up GitHub usernames. Do NOT use @mentions.
- The verified contributors are provided in contributors.json (@include).

### Issues
- ONLY reference GitHub issues that appear in issue_manifest.json (@include).
- If issue_manifest.json is empty or has no github_issues, write:
  "## Issues Addressed\n\nNo linked issues for this release."
- Do NOT invent issue numbers. Do NOT use (#N) format unless the number
  appears in issue_manifest.json.
- Do NOT run `gh issue list` or `gh issue view` to find issues yourself.

### PRs
- You MAY reference PR numbers if you find them via `git log` or `gh pr list`.
- But do NOT fabricate PR numbers. If unsure, omit the reference.

## Quality Standards

- **Real code, not fabricated**: Use git diff and cat to show actual changes
- **Professional prose**: Clear, accessible, no unnecessary jargon
- **Actionable migration guides**: Step-by-step, with before/after code
- **Proportional detail**: Patch releases get 1 page; major releases get full docs
- **Publishable as-is**: No human editing should be needed
- **No hallucinations**: Every fact must be verified from git history or provided data
''');
}

String _releaseNotesTemplate(String bumpType, String version, String prevTag, String today, String pkg, String owner) {
  if (bumpType == 'patch') {
    return '''
Structure for PATCH release notes:

```markdown
# $pkg v$version

> Bug fix release — $today

## Bug Fixes

- **Fix description** — explain what was broken and how it's fixed. ([#PR](link))

## Upgrade

```bash
dart pub upgrade $pkg
```

## Full Changelog

[$prevTag...v$version](https://github.com/$owner/$pkg/compare/$prevTag...v$version)
```
''';
  }

  if (bumpType == 'major') {
    return '''
Structure for MAJOR release notes (comprehensive):

```markdown
# $pkg v$version

> Brief 2-3 sentence executive summary of this major release.

## Highlights

- **Highlight 1** — most impactful change
- **Highlight 2** — second most impactful
- **Highlight 3** — third most impactful

## Breaking Changes

> **N breaking changes** in this release.
> See the full [Migration Guide](migration_guide.md) for step-by-step instructions.

| Change | Quick Fix |
|--------|-----------|
| Description of breaking change | `dart fix --apply` or manual step |

### Breaking Change 1: Title

**What changed:** Description.

**Before:**
```dart
// Old API usage (from git diff)
```

**After:**
```dart
// New API usage (from source code)
```

**Migration:** Step-by-step instructions.

## What's New

### Feature Name
Description with context about why it was added and how to use it.
```dart
// Usage example from source code or tests
```

## Bug Fixes

- **Fix title** — what was broken, how it's fixed ([#PR](link), fixes [#ISSUE](link))

## Issues Addressed

- [#N](link) — Issue title (status: fixed/addressed)

## Deprecations

- `OldApi.method()` is deprecated — use `NewApi.method()` instead. Will be removed in vX.X.X.

## Upgrade

```bash
dart pub upgrade $pkg
dart fix --apply  # Automated fixes for breaking changes
```

Then follow the [Migration Guide](migration_guide.md) for any remaining manual changes.

## Contributors

Thanks to everyone who contributed to this release:
- @username1
- @username2

## Full Changelog

[$prevTag...v$version](https://github.com/$owner/$pkg/compare/$prevTag...v$version)
```
''';
  }

  // Default: minor release
  return '''
Structure for MINOR release notes:

```markdown
# $pkg v$version

> Brief 2-3 sentence summary of this release.

## Highlights

- **Highlight 1** — most impactful new feature or improvement
- **Highlight 2** — second most impactful
- **Highlight 3** — if applicable

## What's New

### Feature Name
Description with context. Include a brief usage example if the API is user-facing.
```dart
// Usage example from source code or tests
```

## Bug Fixes

- **Fix title** — what was broken, how it's fixed ([#PR](link))

## Issues Addressed

- [#N](link) — Issue title

## Deprecations (if any)

- `OldApi` is deprecated — use `NewApi` instead. Will be removed in vX.X.X.

## Upgrade

```bash
dart pub upgrade $pkg
```

## Contributors

Thanks to everyone who contributed:
- @username

## Full Changelog

[$prevTag...v$version](https://github.com/$owner/$pkg/compare/$prevTag...v$version)
```
''';
}

String _inferBumpType(String prevTag, String newVersion) {
  final prev = prevTag.replaceAll(RegExp(r'^v'), '').split('.');
  final next = newVersion.replaceAll(RegExp(r'^v'), '').split('.');
  if (prev.length < 3 || next.length < 3) return 'minor';
  if (int.tryParse(next[0]) != int.tryParse(prev[0])) return 'major';
  if (int.tryParse(next[1]) != int.tryParse(prev[1])) return 'minor';
  return 'patch';
}

bool _fileExists(String path) => File(path).existsSync();

String _runSync(String command) {
  try {
    final result = Process.runSync('sh', ['-c', command], workingDirectory: Directory.current.path);
    if (result.exitCode == 0) return (result.stdout as String).trim();
    return '(unavailable)';
  } catch (_) {
    return '(unavailable)';
  }
}

String _truncate(String input, int maxChars) {
  if (input.length <= maxChars) return input;
  return '${input.substring(0, maxChars)}\n\n... [TRUNCATED: ${input.length - maxChars} chars omitted. Use git/gh tools for full details.]\n';
}
