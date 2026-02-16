// ignore_for_file: avoid_print

import 'dart:io';

/// Issue Triage prompt generator.
///
/// Generates a prompt for Gemini Pro to analyze a GitHub issue and perform
/// comprehensive triage: type classification, priority assignment, duplicate
/// detection, area classification, and helpful comment generation.
///
/// Usage:
///   dart run scripts/prompts/gemini_triage_prompt.dart \
///     <issue_number> <issue_title> <issue_author> <existing_labels> \
///     <issue_body> <open_issues_list>
///
/// Arguments are passed from the GitHub Actions workflow where they are
/// extracted from the GitHub API via gh cli.

void main(List<String> args) {
  if (args.length < 6) {
    stderr.writeln(
      'Usage: dart run scripts/prompts/gemini_triage_prompt.dart '
      '<issue_number> <issue_title> <issue_author> <existing_labels> '
      '<issue_body> <open_issues_list>',
    );
    exit(1);
  }

  final issueNumber = args[0];
  final issueTitle = args[1];
  final issueAuthor = args[2];
  final existingLabels = args[3];
  final issueBody = args[4];
  final openIssues = args[5];

  // Gather project context
  final libTree = _runSync('tree lib/ -L 2 --dirsfirst -d');
  final protoTree = _runSync('tree proto/src/ -L 2 --dirsfirst -d');

  print('''
You are an Issue Triage Agent for the runtime_isomorphic_library Dart package.

Analyze the following GitHub issue and perform comprehensive triage. You have access
to the gh (GitHub CLI) tool to read additional issue context or apply labels/comments.

## Issue Details
- **Number**: #$issueNumber
- **Title**: $issueTitle
- **Author**: @$issueAuthor
- **Existing Labels**: $existingLabels

### Issue Body
$issueBody

## Package Structure (for area classification)
### Library Modules
```
$libTree
```

### Proto Domains
```
$protoTree
```

## Existing Open Issues (for duplicate detection)
```
$openIssues
```

## Triage Tasks

Perform ALL of the following analyses:

### 1. Type Classification
Determine the issue type. Choose exactly ONE:
- `bug` -- Something is broken or behaving incorrectly
- `feature-request` -- Request for new functionality
- `enhancement` -- Improvement to existing functionality
- `documentation` -- Documentation is missing, incorrect, or unclear
- `question` -- The author is asking a question, not reporting a problem

### 2. Priority Assignment
Assess priority based on impact, urgency, and scope. Choose exactly ONE:
- `P0-critical` -- Security vulnerability, data loss, complete feature broken, blocks all users
- `P1-high` -- Major feature broken, significant user impact, no workaround available
- `P2-medium` -- Minor feature broken, workaround exists, limited user impact
- `P3-low` -- Cosmetic issues, minor improvements, documentation requests

### 3. Area Classification
Identify which area of the codebase this affects. Choose ONE or MORE:
- `area/proto` -- Protocol buffer definitions or generated code
- `area/ml-models` -- Machine learning model integrations (GPT, Claude, Gemini, etc.)
- `area/core` -- Core runtime functionality
- `area/provisioning` -- Provisioning and deployment
- `area/grpc` -- gRPC transport layer
- `area/crypto` -- Encryption and cryptography
- `area/googleapis` -- Google API integrations
- `area/ci-cd` -- CI/CD, build, and tooling
- `area/docs` -- Documentation

### 4. Duplicate Detection
Compare this issue against the existing open issues listed above.
If you find potential duplicates:
- HIGH confidence: The issue describes the same problem with the same root cause
- MEDIUM confidence: The issue is related but might be a different manifestation
- LOW confidence: Loosely related topics

### 5. Helpful Comment
Draft a comment for the issue that:
- Thanks the reporter
- Confirms the classification (type, priority, area)
- If duplicates found, links to them with explanation
- If bug: asks for reproduction steps if not provided
- If feature request: acknowledges the request and explains the next steps
- Is professional, concise, and welcoming

## Actions to Take

Use the gh CLI to apply your triage decisions:

1. Apply type label:
   `gh issue edit $issueNumber --add-label "<type>"`

2. Apply priority label:
   `gh issue edit $issueNumber --add-label "<priority>"`

3. Apply area label(s):
   `gh issue edit $issueNumber --add-label "<area>"`

4. If potential duplicate found (HIGH confidence):
   `gh issue edit $issueNumber --add-label "potential-duplicate"`

5. Post the helpful comment:
   `gh issue comment $issueNumber --body "<your comment>"`

Also write a summary of your triage decisions to .cicd_runs/triage/triage_result.json:
```json
{
  "issue_number": $issueNumber,
  "type": "<type-label>",
  "priority": "<priority-label>",
  "area": "<primary-area>",
  "duplicate_of": null,
  "comment": "<the comment you posted>"
}
```
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
