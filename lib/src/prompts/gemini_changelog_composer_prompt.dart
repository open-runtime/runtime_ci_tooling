// ignore_for_file: avoid_print

import 'dart:io';

/// Stage 2 Changelog Composer Agent prompt generator.
///
/// Focused ONLY on updating CHANGELOG.md with a concise Keep-a-Changelog entry.
/// Release notes are handled separately by Stage 3 (gemini_release_notes_author_prompt.dart).
///
/// Usage:
///   dart run scripts/prompts/gemini_changelog_composer_prompt.dart <prev_tag> <new_version>

void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln('Usage: dart run scripts/prompts/gemini_changelog_composer_prompt.dart <prev_tag> <new_version>');
    exit(1);
  }

  final prevTag = args[0];
  final newVersion = args[1];

  final today = DateTime.now().toIso8601String().substring(0, 10);
  final contributors = _runSync('git log $prevTag..HEAD --format="%an" --no-merges | sort -u');
  final totalCommits = _runSync('git rev-list --count $prevTag..HEAD');

  // Check which Stage 1 artifacts are available
  final hasCommitAnalysis =
      File('/tmp/commit_analysis.json').existsSync() || File('.cicd_runs/explore/commit_analysis.json').existsSync();
  final hasPrData = File('/tmp/pr_data.json').existsSync() || File('.cicd_runs/explore/pr_data.json').existsSync();
  final hasBreakingChanges =
      File('/tmp/breaking_changes.json').existsSync() || File('.cicd_runs/explore/breaking_changes.json').existsSync();
  final hasIssueManifest =
      File('/tmp/issue_manifest.json').existsSync() || File('.cicd_runs/triage/issue_manifest.json').existsSync();

  print('''
You are a Changelog Composer Agent for the runtime_isomorphic_library Dart package.

Your ONLY job is to update CHANGELOG.md with a new version entry following
the Keep a Changelog format. You do NOT write release notes -- that is a
separate stage.

## Release Context
- **Version**: v$newVersion
- **Previous Version**: $prevTag
- **Release Date**: $today
- **Total Commits**: $totalCommits
- **Contributors**: $contributors

## Available Data Files
${hasCommitAnalysis ? '- commit_analysis.json (provided via @include)' : '- commit_analysis.json: NOT AVAILABLE -- use git log directly'}
${hasPrData ? '- pr_data.json (provided via @include)' : '- pr_data.json: NOT AVAILABLE -- use gh pr list directly'}
${hasBreakingChanges ? '- breaking_changes.json (provided via @include)' : '- breaking_changes.json: NOT AVAILABLE'}
${hasIssueManifest ? '- issue_manifest.json (provided via @include) -- Reference resolved issues as (fixes #N)' : '- issue_manifest.json: NOT AVAILABLE'}
- CHANGELOG.md (provided via @include -- match its existing format)

## Task: Update CHANGELOG.md

Read the existing CHANGELOG.md and update it following Keep a Changelog format.

### Handling the [Unreleased] section

If the CHANGELOG contains a `## [Unreleased]` section:
1. Move any content under `## [Unreleased]` into the new version entry below
2. Replace `## [Unreleased]` with a fresh EMPTY `## [Unreleased]` section
3. Place the new version entry immediately after the empty `## [Unreleased]`

If there is no `## [Unreleased]` section, add one above the new version entry.

### New version entry format

The new entry MUST follow this structure:
```
## [$newVersion] - $today

### Breaking Changes
- **BREAKING**: Description of breaking change (#PR_NUMBER)
  - Migration: old API → new API

### Added
- Description of new feature (#PR_NUMBER)

### Changed
- Description of change (#PR_NUMBER)

### Deprecated
- Description of deprecation -- will be removed in vX.X.X

### Removed
- Description of removal

### Fixed
- Description of fix (#PR_NUMBER)

### Security
- Description of security fix
```

### Resulting structure

The final CHANGELOG.md MUST have this structure:
```
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [$newVersion] - $today

### Added
- ...

## [previous version] - previous date
...
```

### Rules
- Only include sections that have entries (omit empty sections)
- **Breaking Changes** goes FIRST if present
- Every entry should reference its PR number as (#N)
- If issue_manifest.json is available, reference resolved GitHub issues as (fixes #N)
- Write from the USER's perspective -- what changed FOR THEM
- Use action verbs: "Added", "Fixed", "Improved", "Removed"
- Be specific and concise -- one line per change
- Group related changes together within each section
- Do NOT include migration guides or code examples -- that is for release notes
- Do NOT add reference-style links at the bottom -- those are added automatically by the pipeline

Write the updated CHANGELOG.md directly to ./CHANGELOG.md (overwrite the file).
Do NOT modify README.md -- that is handled by a separate documentation stage.
''');
}

/// Runs a shell command synchronously and returns stdout, or a fallback message on error.
String _runSync(String command) {
  try {
    final result = Process.runSync('sh', ['-c', command], workingDirectory: Directory.current.path);
    if (result.exitCode == 0) {
      return (result.stdout as String).trim();
    }
    return '(unavailable)';
  } catch (e) {
    return '(unavailable)';
  }
}
