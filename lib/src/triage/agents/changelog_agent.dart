// ignore_for_file: avoid_print

import '../models/game_plan.dart';
import '../utils/gemini_runner.dart';

/// Changelog/Release Agent
///
/// Checks whether an issue is mentioned in changelogs, release notes,
/// or deployment records. Verifies if fixes have reached a release.

const String kAgentId = 'changelog';

/// Builds a Gemini task for changelog/release investigation.
GeminiTask buildTask(IssuePlan issue, String repoRoot) {
  return GeminiTask(
    id: 'issue-${issue.number}-changelog',
    model: kDefaultProModel,
    workingDirectory: repoRoot,
    allowedTools: ['run_shell_command(git)', 'run_shell_command(gh)'],
    fileIncludes: ['CHANGELOG.md'],
    prompt:
        '''
You are a Changelog/Release Agent investigating whether GitHub issue #${issue.number} is mentioned in any release artifacts.

## Issue Details
- **Title**: ${issue.title}
- **Author**: @${issue.author}

## Investigation Instructions

1. Read CHANGELOG.md (provided via @include) -- search for "#${issue.number}" or keywords from the title
2. Check release notes folder: `ls release_notes/ 2>/dev/null` -- look in each version folder
3. List git tags to see what versions have been released: `git tag --sort=-version:refname | head -20`
4. Search commit messages for issue references in released code:
   - `git log --all --oneline --grep="#${issue.number}"`
5. Check if the latest tag contains commits that reference this issue:
   - Find latest tag: `git describe --tags --abbrev=0`
   - Check: `git log <tag>..HEAD --oneline --grep="#${issue.number}"`
   - If no results, the fix (if any) is already in a release

## Required Output

Write a JSON file to .cicd_runs/triage_results/issue_${issue.number}_$kAgentId.json:
```json
{
  "agent_id": "$kAgentId",
  "issue_number": ${issue.number},
  "confidence": 0.0,
  "summary": "Issue is/is not mentioned in releases. Last release: vX.X.X",
  "evidence": ["Mentioned in CHANGELOG.md under v0.0.2", "Referenced in release_notes/v0.0.2/"],
  "recommended_labels": ["released"],
  "suggested_comment": "This issue was addressed in v0.0.2",
  "suggest_close": false,
  "close_reason": "completed",
  "related_entities": []
}
```

Confidence scoring:
- 0.9-1.0: Issue is explicitly referenced in a released changelog/release notes
- 0.7-0.8: Related commits are in a release but issue isn't explicitly mentioned
- 0.5-0.6: Fix commits exist but haven't been released yet
- 0.0-0.4: No mention in any release artifacts

If the issue is mentioned in a release, add "released" to recommended_labels.
IMPORTANT: Write VALID JSON only.
''',
  );
}
