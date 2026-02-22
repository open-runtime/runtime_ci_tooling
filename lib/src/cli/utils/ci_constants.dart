import 'dart:io';

import '../../triage/utils/run_context.dart';

/// Staging directory for CI artifacts.
///
/// In CI, GitHub Actions downloads artifacts to `/tmp/`. Locally,
/// `Directory.systemTemp` is used (which maps to `/tmp` on Linux
/// and `/var/folders/…` on macOS).
///
/// Override via `CI_STAGING_DIR` environment variable.
String get kStagingDir => Platform.environment['CI_STAGING_DIR'] ?? Directory.systemTemp.path;

/// Configuration files expected in a repo using runtime_ci_tooling.
const List<String> kCiConfigFiles = [
  '.github/workflows/release.yaml',
  '.github/workflows/issue-triage.yaml',
  '.github/workflows/ci.yaml',
  '.gemini/settings.json',
  '.gemini/commands/changelog.toml',
  '.gemini/commands/release-notes.toml',
  '.gemini/commands/triage.toml',
  'GEMINI.md',
  'CHANGELOG.md',
  'lib/src/prompts/gemini_changelog_prompt.dart',
  'lib/src/prompts/gemini_changelog_composer_prompt.dart',
  'lib/src/prompts/gemini_release_notes_author_prompt.dart',
  'lib/src/prompts/gemini_documentation_prompt.dart',
  'lib/src/prompts/gemini_triage_prompt.dart',
];

/// Stage 1 JSON artifacts produced by the explore phase.
const List<String> kStage1Artifacts = [
  '$kCicdRunsDir/explore/commit_analysis.json',
  '$kCicdRunsDir/explore/pr_data.json',
  '$kCicdRunsDir/explore/breaking_changes.json',
];
