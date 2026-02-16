// ignore_for_file: avoid_print

import '../models/game_plan.dart';
import '../utils/gemini_runner.dart';

/// Code Analysis Agent
///
/// Investigates whether an issue has been fixed in source code by searching
/// for relevant commits, code changes, and test additions since the issue
/// was opened. Uses Gemini 3 Pro for deep code reasoning.

const String kAgentId = 'code_analysis';

/// Builds a Gemini task for code analysis investigation.
GeminiTask buildTask(IssuePlan issue, String repoRoot) {
  return GeminiTask(
    id: 'issue-${issue.number}-code',
    model: kDefaultProModel,
    workingDirectory: repoRoot,
    allowedTools: ['run_shell_command(git)', 'run_shell_command(gh)'],
    prompt:
        '''
You are a Code Analysis Agent investigating GitHub issue #${issue.number}.

## Issue Details
- **Title**: ${issue.title}
- **Author**: @${issue.author}
- **Existing Labels**: ${issue.existingLabels.join(', ')}

## Investigation Instructions

1. Run `gh issue view ${issue.number} --json body --jq ".body"` to read the full issue description
2. Search the codebase for code related to the issue:
   - `git log --oneline --all --grep="${issue.title.split(' ').take(3).join(' ')}"` to find related commits
   - `git log --oneline -20` to see recent changes
3. If the issue describes a bug, search for fixes:
   - Look for commits mentioning "#${issue.number}" or keywords from the title
   - Run `git diff` on relevant files to see if the described problem has been addressed
4. Check test files for new tests related to this issue
5. Examine whether the described behavior has been changed in recent code

## Required Output

Write a JSON file to .cicd_runs/triage_results/issue_${issue.number}_$kAgentId.json with this EXACT structure:
```json
{
  "agent_id": "$kAgentId",
  "issue_number": ${issue.number},
  "confidence": 0.0,
  "summary": "One-sentence summary of findings",
  "evidence": ["Evidence item 1", "Evidence item 2"],
  "recommended_labels": ["label1"],
  "suggested_comment": "Comment text or null",
  "suggest_close": false,
  "close_reason": null,
  "related_entities": [
    {"type": "commit", "id": "sha123", "description": "Relevant commit", "relevance": 0.8}
  ]
}
```

Confidence scoring guide:
- 0.9-1.0: Fix is clearly merged, tests pass, behavior changed as described
- 0.7-0.8: Strong evidence of a fix but not 100% confirmed
- 0.5-0.6: Related changes found but unclear if they address this specific issue
- 0.0-0.4: No evidence of a fix found

IMPORTANT: Write VALID JSON only. Validate before writing.
''',
  );
}
