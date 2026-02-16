// ignore_for_file: avoid_print

import '../models/game_plan.dart';
import '../utils/gemini_runner.dart';

/// Duplicate Detection Agent
///
/// Detects duplicate or closely related issues by comparing the issue
/// content against other open and recently closed issues.

const String kAgentId = 'duplicate';

/// Builds a Gemini task for duplicate detection.
GeminiTask buildTask(IssuePlan issue, String repoRoot) {
  return GeminiTask(
    id: 'issue-${issue.number}-dupes',
    model: kDefaultProModel,
    workingDirectory: repoRoot,
    allowedTools: ['run_shell_command(gh)'],
    prompt:
        '''
You are a Duplicate Detection Agent for GitHub issue #${issue.number}.

## Issue Details
- **Title**: ${issue.title}
- **Author**: @${issue.author}

## Investigation Instructions

1. Read the full issue: `gh issue view ${issue.number} --json body --jq ".body"`
2. List open issues: `gh issue list --state open --limit 100 --json number,title,labels`
3. List recently closed issues: `gh issue list --state closed --limit 50 --json number,title,labels`
4. Compare issue #${issue.number} against ALL other issues for:
   - Same or very similar titles
   - Same root cause described in the body
   - Same error messages or symptoms
   - Same affected component/area
5. For potential duplicates, read their full body: `gh issue view <number> --json body --jq ".body"`

## Required Output

Write a JSON file to .cicd_runs/triage_results/issue_${issue.number}_$kAgentId.json:
```json
{
  "agent_id": "$kAgentId",
  "issue_number": ${issue.number},
  "confidence": 0.0,
  "summary": "No duplicates found / Found N potential duplicates",
  "evidence": ["#X: Similar title and description", "#Y: Same error message"],
  "recommended_labels": ["potential-duplicate"],
  "suggested_comment": "This issue appears to be a duplicate of #X",
  "suggest_close": false,
  "close_reason": "duplicate",
  "related_entities": [
    {"type": "issue", "id": "123", "description": "Duplicate: same root cause", "relevance": 0.9}
  ]
}
```

Confidence scoring:
- 0.9-1.0: Exact duplicate -- same problem, same root cause, other issue is still open
- 0.7-0.8: Very similar -- same area and symptoms but might be a different manifestation
- 0.5-0.6: Related but distinct issues in the same area
- 0.0-0.4: No duplicates or related issues found

If no duplicates found, set confidence to 0.0 and leave related_entities empty.
IMPORTANT: Write VALID JSON only.
''',
  );
}
