// ignore_for_file: avoid_print

import '../models/game_plan.dart';
import '../utils/gemini_runner.dart';

/// PR Correlation Agent
///
/// Finds pull requests that may address or relate to a GitHub issue.
/// Searches PR titles, descriptions, commit messages, and linked issues.

const String kAgentId = 'pr_correlation';

/// Builds a Gemini task for PR correlation investigation.
GeminiTask buildTask(IssuePlan issue, String repoRoot) {
  return GeminiTask(
    id: 'issue-${issue.number}-prs',
    model: kDefaultProModel,
    workingDirectory: repoRoot,
    allowedTools: ['run_shell_command(git)', 'run_shell_command(gh)'],
    prompt:
        '''
You are a PR Correlation Agent investigating GitHub issue #${issue.number}.

## Issue Details
- **Title**: ${issue.title}
- **Author**: @${issue.author}

## Investigation Instructions

1. Read the full issue: `gh issue view ${issue.number} --json body,comments --jq ".body"`
2. Search for PRs that reference this issue:
   - `gh pr list --state all --limit 50 --json number,title,body,state,author,mergedAt --search "#${issue.number}"` 
   - `gh pr list --state merged --limit 30 --json number,title,body,author` and look for title/body matches
3. Search commit messages for issue references:
   - `git log --all --oneline --grep="#${issue.number}"`
   - `git log --all --oneline --grep="issue ${issue.number}"`
4. For each matching PR, check if it was merged: `gh pr view <number> --json state,mergedAt`
5. Assess whether the PR actually fixes the issue or just references it

## Required Output

Write a JSON file to .cicd_runs/triage_results/issue_${issue.number}_$kAgentId.json with this EXACT structure:
```json
{
  "agent_id": "$kAgentId",
  "issue_number": ${issue.number},
  "confidence": 0.0,
  "summary": "Found N related PRs, M merged",
  "evidence": ["PR #X: title (merged/open)", "PR #Y: title"],
  "recommended_labels": [],
  "suggested_comment": null,
  "suggest_close": false,
  "close_reason": null,
  "related_entities": [
    {"type": "pr", "id": "123", "description": "PR title", "relevance": 0.9}
  ]
}
```

Confidence scoring:
- 0.9-1.0: A merged PR explicitly fixes this issue (references #${issue.number} in title or body)
- 0.7-0.8: A merged PR likely addresses this issue based on content analysis
- 0.5-0.6: Open PRs or loosely related merged PRs found
- 0.0-0.4: No related PRs found

IMPORTANT: Write VALID JSON only.
''',
  );
}
