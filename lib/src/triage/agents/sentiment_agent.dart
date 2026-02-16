// ignore_for_file: avoid_print

import '../models/game_plan.dart';
import '../utils/gemini_runner.dart';

/// Comment Sentiment Agent
///
/// Analyzes the discussion thread on an issue to understand stakeholder
/// sentiment, detect consensus, identify blockers, and assess whether
/// the community considers the issue resolved.

const String kAgentId = 'sentiment';

/// Builds a Gemini task for comment sentiment analysis.
GeminiTask buildTask(IssuePlan issue, String repoRoot) {
  return GeminiTask(
    id: 'issue-${issue.number}-sentiment',
    model: kDefaultProModel,
    workingDirectory: repoRoot,
    allowedTools: ['run_shell_command(gh)'],
    prompt:
        '''
You are a Comment Sentiment Agent analyzing the discussion on GitHub issue #${issue.number}.

## Issue Details
- **Title**: ${issue.title}
- **Author**: @${issue.author}

## Investigation Instructions

1. Read the full issue with comments:
   `gh issue view ${issue.number} --json body,comments --jq "{body: .body, comments: [.comments[] | {author: .author.login, body: .body, createdAt: .createdAt}]}"`
2. Analyze the discussion thread for:
   - **Consensus**: Do commenters agree the issue is resolved, still open, or stale?
   - **Blockers**: Are there unresolved questions or dependencies?
   - **Activity**: When was the last comment? Is the issue stale (>90 days no activity)?
   - **Maintainer input**: Have repository maintainers commented? What did they say?
   - **Reporter satisfaction**: Did the original author indicate their problem was solved?
3. Determine overall sentiment: positive (likely resolved), negative (still broken), neutral (unclear)

## Required Output

Write a JSON file to .cicd_runs/triage_results/issue_${issue.number}_$kAgentId.json:
```json
{
  "agent_id": "$kAgentId",
  "issue_number": ${issue.number},
  "confidence": 0.0,
  "summary": "Discussion sentiment: positive/negative/neutral. N comments, last activity DATE.",
  "evidence": ["Author confirmed fix works", "Maintainer suggested closing"],
  "recommended_labels": ["stale"],
  "suggested_comment": null,
  "suggest_close": false,
  "close_reason": null,
  "related_entities": []
}
```

Confidence scoring (for resolution):
- 0.9-1.0: Author explicitly confirmed the issue is resolved
- 0.7-0.8: Maintainer said it's fixed or multiple users confirmed a workaround
- 0.5-0.6: Some positive signals but no explicit confirmation
- 0.3-0.4: Issue is stale with no recent activity (>90 days)
- 0.0-0.2: Active discussion indicates the issue is still unresolved

Recommended labels:
- Add "stale" if no activity in >90 days
- Add "needs-response" if a maintainer asked a question with no reply
- Add "confirmed" if the reporter confirmed the bug exists

IMPORTANT: Write VALID JSON only.
''',
  );
}
