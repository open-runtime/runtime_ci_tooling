# Usage Guide -- `runtime_ci_tooling`

Comprehensive reference for every command, feature, and integration provided by the
`runtime_ci_tooling` package. This guide covers both CLI executables, the programmatic
API, the Gemini-powered triage pipeline, release automation, and documentation generation.

---

## Table of Contents

- [Overview](#overview)
- [CLI Executables](#cli-executables)
- [manage\_cicd Commands](#manage_cicd-commands)
  - [setup](#setup)
  - [init](#init)
  - [validate](#validate)
  - [status](#status)
  - [version](#version)
  - [determine-version](#determine-version)
  - [explore](#explore)
  - [compose](#compose)
  - [release-notes](#release-notes)
  - [documentation](#documentation)
  - [autodoc](#autodoc)
  - [release](#release)
  - [create-release](#create-release)
  - [test](#test)
  - [analyze](#analyze)
  - [verify-protos](#verify-protos)
  - [triage](#triage)
  - [pre-release-triage](#pre-release-triage)
  - [post-release-triage](#post-release-triage)
  - [archive-run](#archive-run)
  - [merge-audit-trails](#merge-audit-trails)
  - [configure-mcp](#configure-mcp)
- [triage\_cli Commands](#triage_cli-commands)
  - [Single Issue Triage](#single-issue-triage)
  - [Auto Triage](#auto-triage)
  - [Resume Interrupted Run](#resume-interrupted-run)
  - [Triage Status](#triage-status)
  - [Pre-Release Mode](#pre-release-mode)
  - [Post-Release Mode](#post-release-mode)
- [Triage Pipeline Deep Dive](#triage-pipeline-deep-dive)
  - [Phase 1: Plan](#phase-1-plan)
  - [Phase 2: Investigate](#phase-2-investigate)
  - [Phase 3: Act](#phase-3-act)
  - [Phase 4: Verify](#phase-4-verify)
  - [Phase 5: Link](#phase-5-link)
  - [Phase 5b: Cross-Repo Link](#phase-5b-cross-repo-link)
  - [Investigation Agents](#investigation-agents)
  - [Confidence Scoring and Decision Logic](#confidence-scoring-and-decision-logic)
- [Release Pipeline Deep Dive](#release-pipeline-deep-dive)
  - [Version Detection](#version-detection)
  - [Stage 1: Explore](#stage-1-explore)
  - [Stage 2: Compose](#stage-2-compose)
  - [Stage 3: Release Notes](#stage-3-release-notes)
  - [GitHub Release Creation](#github-release-creation)
  - [Contributor Verification](#contributor-verification)
- [Autodoc System](#autodoc-system)
- [Audit Trail System](#audit-trail-system)
- [Programmatic API](#programmatic-api)
- [GitHub Actions Integration](#github-actions-integration)
  - [CI Workflow](#ci-workflow)
  - [Release Workflow](#release-workflow)
  - [Issue Triage Workflow](#issue-triage-workflow)
- [Gemini CLI Commands](#gemini-cli-commands)
- [Global Flags](#global-flags)
- [Environment Variables](#environment-variables)
- [Files and Directories Reference](#files-and-directories-reference)

---

## Overview

`runtime_ci_tooling` provides two CLI executables and a Dart library for automating
CI/CD operations in Dart/Flutter repositories:

| Component | Purpose |
|---|---|
| `manage_cicd` | CI/CD management: setup, release automation, changelog, docs, testing |
| `triage_cli` | AI-powered issue triage with multi-phase pipeline |
| Library API | Programmatic access to config, runners, models, and phases |

All AI-powered features use **Gemini CLI** as the execution engine and **gracefully
degrade** when Gemini is unavailable -- non-AI commands continue to work.

---

## CLI Executables

### Running commands

```bash
# Via dart run (recommended)
dart run runtime_ci_tooling:manage_cicd <command> [flags]
dart run runtime_ci_tooling:triage_cli <args> [flags]

# Via compiled executables (after `dart pub global activate`)
manage_cicd <command> [flags]
triage_cli <args> [flags]
```

---

## manage_cicd Commands

### setup

Install all prerequisite tools automatically.

```bash
dart run runtime_ci_tooling:manage_cicd setup
dart run runtime_ci_tooling:manage_cicd setup --dry-run
```

**What it does:**
1. Checks each required tool (`git`, `gh`, `node`, `npm`, `jq`) -- installs if missing
2. Checks each optional tool (`tree`, `gemini`) -- installs if missing
3. Verifies Gemini CLI version
4. Checks for `GEMINI_API_KEY` and `GH_TOKEN`/`GITHUB_TOKEN` environment variables
5. Runs `dart pub get`

**Flags:**
- `--dry-run` -- Show what would be installed without executing

---

### init

Bootstrap a new repository for runtime CI tooling.

```bash
dart run runtime_ci_tooling:manage_cicd init
```

**What it does:**
1. Auto-detects package name and version from `pubspec.yaml`
2. Auto-detects GitHub owner via `gh repo view` or git remote URL
3. Scans `lib/` and `lib/src/` to auto-generate area labels
4. Creates `.runtime_ci/config.json` with detected values
5. Creates a starter `CHANGELOG.md` if none exists
6. Adds `.runtime_ci/runs/` to `.gitignore`

---

### validate

Validate all CI/CD configuration files exist and are well-formed.

```bash
dart run runtime_ci_tooling:manage_cicd validate
```

**Validates these files:**

| File | Validation |
|---|---|
| `.github/workflows/*.yaml` | YAML parsing |
| `.gemini/settings.json` | JSON parsing |
| `.gemini/commands/*.toml` | Contains `prompt` and `description` keys |
| `GEMINI.md`, `CHANGELOG.md` | Exists and non-empty |
| `lib/src/prompts/*.dart` | Passes `dart analyze` |

Exits with code 1 if any file fails validation.

---

### status

Show comprehensive CI/CD configuration and tool status.

```bash
dart run runtime_ci_tooling:manage_cicd status
```

**Displays:**
- Existence of all config files
- Installation status and versions of required/optional tools
- `GEMINI_API_KEY` status (set/not set, character count)
- GitHub token status
- Configured MCP servers from `.gemini/settings.json`
- Stage 1 artifact status (existence + byte size)
- Package version and latest git tag

---

### version

Display current, previous, and next version information (read-only).

```bash
dart run runtime_ci_tooling:manage_cicd version
```

**Output:**
- Current version from `pubspec.yaml`
- Previous version from latest `v*` git tag
- Detected next version (uses Gemini analysis if available, otherwise regex heuristic)

---

### determine-version

Determine the version bump with Gemini analysis. Outputs JSON for CI consumption.

```bash
# Local use
dart run runtime_ci_tooling:manage_cicd determine-version

# In GitHub Actions (writes to $GITHUB_OUTPUT)
dart run runtime_ci_tooling:manage_cicd determine-version --output-github-actions
```

**Output (stdout):**

```json
{
  "prev_tag": "v0.1.0",
  "current_version": "0.1.0",
  "new_version": "0.2.0",
  "should_release": true
}
```

**Flags:**
- `--output-github-actions` -- Also write `prev_tag`, `new_version`, `should_release` to `$GITHUB_OUTPUT`
- `--prev-tag <tag>` -- Override previous tag detection
- `--version <ver>` -- Override next version

**Version detection algorithm:**

1. **Pass 1 -- Regex heuristic** (always runs):
   - `BREAKING CHANGE` or `type!:` in commit messages -> `major`
   - `feat:` or `feat(scope):` -> `minor`
   - All commits are `chore/style/ci/docs/test/build` -> `none`
   - Everything else -> `patch`

2. **Pass 2 -- Gemini analysis** (overrides regex if available):
   - Gemini reads commits, changed files, diff stats
   - Writes `version_bump.json` with bump type and `version_bump_rationale.md`

---

### explore

**Stage 1 Explorer Agent** -- Analyzes commits and PRs since the last release to produce
structured JSON artifacts.

```bash
dart run runtime_ci_tooling:manage_cicd explore
dart run runtime_ci_tooling:manage_cicd explore --prev-tag v0.1.0 --version 0.2.0
```

**Gemini model:** `gemini-3.1-pro-preview`

**What it produces (3 JSON artifacts):**

| Artifact | Contents |
|---|---|
| `commit_analysis.json` | Categorized commits (added/changed/deprecated/removed/fixed/security) with PR references and SHAs |
| `pr_data.json` | PR metadata (number, title, author, labels, summary, linked commits) |
| `breaking_changes.json` | Breaking changes with affected APIs and migration guidance |

**Artifacts are saved to:**
- `/tmp/` (for CI artifact upload)
- `.runtime_ci/runs/<run_id>/explore/` (audit trail)

**Gemini tools allowed:** `run_shell_command(git)`, `run_shell_command(gh)`

**Graceful degradation:** If Gemini is unavailable, the command skips without error.

---

### compose

**Stage 2 Changelog Composer** -- Updates `CHANGELOG.md` and `README.md` using Gemini.

```bash
dart run runtime_ci_tooling:manage_cicd compose
dart run runtime_ci_tooling:manage_cicd compose --prev-tag v0.1.0 --version 0.2.0
```

**Gemini model:** `gemini-3.1-pro-preview`

**What it does:**
1. Loads Stage 1 artifacts (`commit_analysis.json`, `pr_data.json`, `breaking_changes.json`)
2. Loads `issue_manifest.json` from pre-release triage (if available)
3. Generates a composer prompt and pipes to Gemini with the above as `@` file includes
4. Gemini updates `CHANGELOG.md` following Keep a Changelog format
5. Post-processes: adds reference-style links at the bottom

**Keep a Changelog section ordering:**
Breaking Changes > Added > Changed > Deprecated > Removed > Fixed > Security

**Prerequisites:** Run `explore` first (or provide artifacts in `/tmp/`).

---

### release-notes

**Stage 3 Release Notes Author** -- Generates rich narrative release notes for the
GitHub Release page.

```bash
dart run runtime_ci_tooling:manage_cicd release-notes
dart run runtime_ci_tooling:manage_cicd release-notes --prev-tag v0.1.0 --version 0.2.0
```

**Gemini model:** `gemini-3.1-pro-preview`

**What it produces (4 files per version):**

| File | Purpose |
|---|---|
| `release_notes.md` | Main GitHub Release body (Markdown) |
| `migration_guide.md` | Per-breaking-change migration guide with real code examples |
| `linked_issues.json` | Structured JSON of all referenced issues and PRs |
| `highlights.md` | 3-5 bullet summary for announcements |

**Output varies by bump type:**
- **Patch**: Minimal -- bug fix list, upgrade command
- **Minor**: Moderate -- highlights, "What's New" with usage examples
- **Major**: Comprehensive -- executive summary, breaking changes table with before/after code, full migration guide

**Anti-hallucination safeguards:**
- Contributors section is replaced with verified GitHub data (see [Contributor Verification](#contributor-verification))
- Issues section is replaced with verified data from `issue_manifest.json`
- Fabricated issue references (`(#N)`) not in the manifest are stripped

**Files saved to:**
- `.runtime_ci/release_notes/v<version>/`
- `/tmp/release_notes_body.md` and `/tmp/migration_guide.md`

---

### documentation

Run Gemini-powered documentation updates to `README.md`.

```bash
dart run runtime_ci_tooling:manage_cicd documentation --prev-tag v0.1.0 --version 0.2.0
```

**Gemini model:** `gemini-3.1-pro-preview`

**What it does:**
- Updates version references in README
- Adds new modules/features to the README
- Documents new scripts and dependency changes
- Preserves the existing README structure

---

### autodoc

Config-driven documentation generation for proto/code modules using a two-pass
Gemini pipeline.

```bash
# Generate docs for all changed modules
dart run runtime_ci_tooling:manage_cicd autodoc

# Force regeneration of all modules
dart run runtime_ci_tooling:manage_cicd autodoc --force

# Generate for a specific module only
dart run runtime_ci_tooling:manage_cicd autodoc --module sendgrid

# Preview what would be generated
dart run runtime_ci_tooling:manage_cicd autodoc --dry-run

# Verify autodoc.json exists
dart run runtime_ci_tooling:manage_cicd autodoc --init
```

**Configuration:** Reads `.runtime_ci/autodoc.json` for module definitions.

**Two-pass pipeline per module per doc type:**
1. **Pass 1 (Author)**: Gemini Pro generates documentation from source analysis
2. **Pass 2 (Reviewer)**: Gemini Pro fact-checks, corrects naming conventions, fills gaps

**Doc types generated per module:**

| Doc Type | Output File | Contents |
|---|---|---|
| `quickstart` | `QUICKSTART.md` | Setup, imports, common operations, error handling |
| `api_reference` | `API_REFERENCE.md` | All messages, services, RPCs, enums with Dart usage |
| `examples` | `EXAMPLES.md` | Copy-paste-ready code examples |
| `migration` | `MIGRATION.md` | Breaking changes, upgrade steps, before/after code |

**Change detection:** Computes SHA256 hash of source files; skips unchanged modules
(unless `--force`).

**Concurrency:** Up to 4 module/doc-type combinations in parallel (configurable).

---

### release

Run the full local release pipeline.

```bash
dart run runtime_ci_tooling:manage_cicd release
```

**Equivalent to running sequentially:**
1. `version` -- detect version info
2. `explore` -- Stage 1 Explorer
3. `compose` -- Stage 2 Composer

Prints next steps after completion (review CHANGELOG, commit, push).

---

### create-release

Create a GitHub Release: commit artifacts, tag, and publish.

```bash
dart run runtime_ci_tooling:manage_cicd create-release \
  --version 0.2.0 \
  --prev-tag v0.1.0 \
  --artifacts-dir composed-artifacts \
  --repo pieces-app/unified_monorepo
```

**Flags:**
- `--version <ver>` -- **Required.** The version being released
- `--prev-tag <tag>` -- Previous git tag
- `--artifacts-dir <dir>` -- Directory containing CI artifacts (CHANGELOG.md, README.md)
- `--repo <owner/repo>` -- Override repository slug

**What it does:**
1. Copies `CHANGELOG.md` and `README.md` from artifacts directory
2. Bumps `version:` in `pubspec.yaml`
3. Assembles `.runtime_ci/release_notes/v<version>/` with all release artifacts
4. Gathers verified contributors from GitHub API
5. Builds a rich commit message with changelog entry, file summary, and `[skip ci]`
6. Commits, pushes to `origin main`
7. Creates annotated git tag `v<version>`
8. Pushes the tag
9. Creates GitHub Release via `gh release create`

---

### test

Run `dart test` excluding GCP-tagged tests.

```bash
dart run runtime_ci_tooling:manage_cicd test
```

Runs `dart test --exclude-tags gcp`, parses output for pass/fail/skip counts,
and writes a GitHub Actions step summary.

---

### analyze

Run `dart analyze` with error-only failure (warnings are non-blocking).

```bash
dart run runtime_ci_tooling:manage_cicd analyze
```

Unlike `dart analyze --fatal-infos`, this only exits with code 1 if **errors** are
found. Warnings and info-level lints are logged but don't block CI. This is important
for codebases with generated protobuf code that produces many info-level diagnostics.

---

### verify-protos

Verify proto source files and generated Dart files exist.

```bash
dart run runtime_ci_tooling:manage_cicd verify-protos
```

Counts `.proto` files in `proto/src/` and generated files (`.pb.dart`, `.pbenum.dart`,
`.pbjson.dart`, `.pbgrpc.dart`) in `lib/`. Exits with code 1 if either count is zero.

---

### triage

Delegate to the triage CLI for issue triage operations.

```bash
# Triage a single issue
dart run runtime_ci_tooling:manage_cicd triage 42

# Auto-triage all open untriaged issues
dart run runtime_ci_tooling:manage_cicd triage --auto

# Show triage status
dart run runtime_ci_tooling:manage_cicd triage --status
```

Forwards `--dry-run` and `--verbose` flags. See [triage_cli Commands](#triage_cli-commands)
for full documentation.

---

### pre-release-triage

Scan GitHub issues and Sentry errors before a release.

```bash
dart run runtime_ci_tooling:manage_cicd pre-release-triage \
  --prev-tag v0.1.0 --version 0.2.0
```

Produces `issue_manifest.json` which feeds into changelog and release notes generation.
See [Phase: Pre-Release](#pre-release-mode) for details.

---

### post-release-triage

Close the loop after a release is published.

```bash
dart run runtime_ci_tooling:manage_cicd post-release-triage \
  --version 0.2.0 \
  --release-tag v0.2.0 \
  --release-url https://github.com/org/repo/releases/tag/v0.2.0
```

**Flags:**
- `--version <ver>` -- **Required.** Version that was released
- `--release-tag <tag>` -- Git tag (defaults to `v<version>`)
- `--release-url <url>` -- GitHub Release URL
- `--manifest <path>` -- Explicit path to `issue_manifest.json`

Comments on and closes issues linked to the release. See [Post-Release Mode](#post-release-mode)
for details.

---

### archive-run

Archive `.runtime_ci/runs/` to `.runtime_ci/audit/v<version>/` for permanent storage.

```bash
dart run runtime_ci_tooling:manage_cicd archive-run --version 0.2.0
dart run runtime_ci_tooling:manage_cicd archive-run --version 0.2.0 --run-dir .runtime_ci/runs/run_2026-02-16_12345
```

The audit directory IS committed to git (unlike the runs directory). Important
artifacts are selectively copied; raw prompts and large Gemini responses are excluded.

---

### merge-audit-trails

Merge CI/CD audit trail artifacts from multiple GitHub Actions jobs into a single
run directory.

```bash
dart run runtime_ci_tooling:manage_cicd merge-audit-trails
dart run runtime_ci_tooling:manage_cicd merge-audit-trails \
  --incoming-dir .runtime_ci/runs_incoming \
  --output-dir .runtime_ci/runs
```

**Flags:**
- `--incoming-dir <dir>` -- Staging directory (default: `.runtime_ci/runs_incoming`)
- `--output-dir <dir>` -- Target runs directory (default: `.runtime_ci/runs`)

Used in CI to consolidate artifacts from parallel jobs before archiving.

---

### configure-mcp

Set up MCP (Model Context Protocol) servers in `.gemini/settings.json`.

```bash
dart run runtime_ci_tooling:manage_cicd configure-mcp
```

Configures:
- **GitHub MCP Server** (Docker-based) with 22 included tools and 2 excluded tools
- **Sentry MCP Server** (remote URL: `https://mcp.sentry.dev/mcp`)

Reads GitHub token from `GH_TOKEN`, `GITHUB_TOKEN`, or `GITHUB_PAT` environment variables.

---

## triage_cli Commands

The triage CLI runs a multi-phase AI-powered pipeline for issue investigation and
automated action.

### Single Issue Triage

```bash
dart run runtime_ci_tooling:triage_cli 42
dart run runtime_ci_tooling:triage_cli 42 --verbose
dart run runtime_ci_tooling:triage_cli 42 --dry-run
```

Runs the full 6-phase pipeline on issue #42:
Plan -> Investigate -> Act -> Verify -> Link -> Cross-Repo Link

With `--dry-run`, only Phase 1 (Plan) and Phase 2 (Investigate) run -- no GitHub
mutations occur.

### Auto Triage

```bash
dart run runtime_ci_tooling:triage_cli --auto
dart run runtime_ci_tooling:triage_cli --auto --force --verbose
```

Discovers all open issues that lack the `triaged` label and runs the full pipeline
on each.

### Resume Interrupted Run

```bash
dart run runtime_ci_tooling:triage_cli --resume triage_2026-02-16T10-30-00_12345
```

Resumes a pipeline that was interrupted. Reads `checkpoint.json` from the specified
run directory, loads cached results, and continues from the failed phase.

If a run fails, the CLI prints the resume command:

```
To resume this run: dart run runtime_ci_tooling:triage_cli --resume <run_id>
```

### Triage Status

```bash
dart run runtime_ci_tooling:triage_cli --status
```

Shows:
- Triage configuration summary
- Lock file state
- Recent run history
- MCP server status

### Pre-Release Mode

```bash
dart run runtime_ci_tooling:triage_cli --pre-release \
  --prev-tag v0.1.0 --version 0.2.0
```

Scans for issues related to upcoming release. See [Pre-Release Triage](#phase-pre-release-triage).

### Post-Release Mode

```bash
dart run runtime_ci_tooling:triage_cli --post-release \
  --version 0.2.0 --release-tag v0.2.0 \
  --release-url https://github.com/org/repo/releases/tag/v0.2.0
```

Closes the loop on issues after release. See [Post-Release Triage](#phase-post-release-triage).

### All triage_cli Flags

| Flag | Description |
|---|---|
| `<issue_number>` | Triage a single issue by number |
| `--auto` | Auto-discover and triage all open untriaged issues |
| `--pre-release` | Run pre-release issue scanning (requires `--prev-tag`, `--version`) |
| `--post-release` | Run post-release issue closure (requires `--version`, `--release-tag`) |
| `--resume <run_id>` | Resume an interrupted pipeline run |
| `--status` | Show triage configuration and recent run status |
| `--dry-run` | Run Plan + Investigate only; skip mutations |
| `--verbose` / `-v` | Show detailed Gemini CLI output |
| `--force` | Override an existing lock file |
| `--prev-tag <tag>` | Previous release tag |
| `--version <ver>` | Version string |
| `--release-tag <tag>` | Git tag of the release |
| `--release-url <url>` | GitHub Release URL |
| `--manifest <path>` | Path to `issue_manifest.json` |

---

## Triage Pipeline Deep Dive

The triage pipeline is a 6-phase process that uses parallel Gemini AI agents to
investigate GitHub issues and take automated actions.

### Phase 1: Plan

**Purpose:** Discover issues and build a `GamePlan` data structure.

**Single issue mode:**
- Fetches issue via `gh issue view <N> --json number,title,body,author,labels,state,comments`
- Creates a plan with 5 investigation tasks (one per agent)

**Auto mode:**
- Lists all open issues via `gh issue list --state open --limit 100`
- Filters out issues with the `triaged` label
- Creates investigation tasks for each remaining issue

**Output:** `GamePlan` saved to `$runDir/triage_game_plan.json`

### Phase 2: Investigate

**Purpose:** Dispatch parallel Gemini AI agents to investigate each issue.

For each issue, up to 5 agents run in parallel (configurable concurrency, default 4):

| Agent | ID | Specialty |
|---|---|---|
| Code Analysis | `code_analysis` | Searches codebase for fixes, related commits, new tests |
| PR Correlation | `pr_correlation` | Finds PRs that address the issue |
| Duplicate Detection | `duplicate` | Finds duplicate or related issues |
| Sentiment Analysis | `sentiment` | Analyzes discussion thread for consensus |
| Changelog Check | `changelog` | Checks if issue is mentioned in releases |

Each agent writes a JSON result with:
- `confidence` (0.0 - 1.0)
- `summary` (one-sentence finding)
- `evidence[]` (supporting details)
- `recommended_labels[]`
- `suggested_comment`
- `suggest_close` and `close_reason`
- `related_entities[]` (PRs, issues, commits with relevance scores)

**Retry logic:** Exponential backoff with jitter (500ms initial, 30s max, 3 retries)
for rate limits and transient errors.

### Phase 3: Act

**Purpose:** Translate investigation results into GitHub actions based on confidence
thresholds.

**Decision algorithm:**
1. Compute weighted average confidence across all agents
2. Apply agreement boost: +5% per additional agent with > 70% confidence
3. Clamp to [0.0, 1.0]

| Aggregate Confidence | Risk Level | Actions Taken |
|---|---|---|
| >= 90% (`auto_close`) | High | Apply labels + detailed comment + auto-close issue |
| >= 70% (`suggest_close`) | Medium | Apply labels + comment suggesting closure |
| >= 50% (`comment`) | Low | Apply labels + informational comment |
| < 50% | Low | Apply `needs-investigation` label only |

**Idempotency guards:**
- Labels: checks existing labels before applying; creates label if it doesn't exist
- Comments: checks for hidden HTML signature `<!-- triage-bot:$runId:$issueNumber -->`
- Closing: checks issue state before attempting close
- PR/Issue linking: checks for existing link comments

### Phase 4: Verify

**Purpose:** Re-read every triaged issue from GitHub to confirm actions were applied.

**Checks per issue:**
- Each applied label is present
- Close state matches expected state
- At least one comment was posted
- The `triaged` label is present

**Output:** `VerificationReport` with pass/fail per issue.

### Phase 5: Link

**Purpose:** Create bidirectional references between issues and related artifacts.

**Links created:**
- Issue <-> PR (relevance >= 0.6): "Linked by triage: PR #N" comments
- Issue <-> Issue (relevance >= 0.7): "Related: #N" comments
- Issue <-> CHANGELOG: recorded if `#<issueNumber>` appears in `CHANGELOG.md`
- Issue <-> Release Notes: scans `release_notes/` directories; updates `linked_issues.json`

### Phase 5b: Cross-Repo Link

**Purpose:** Search dependent repositories for related open issues and post
cross-reference comments.

Only runs if `cross_repo.enabled` is true in config.

**How it works:**
1. Extract search terms from issue title (removes noise words, takes top 5)
2. Search each cross-repo via `gh search issues`
3. Post "## Cross-Repository Reference" comments linking back to the source issue
4. Comments include hidden signatures for idempotency

### Investigation Agents

#### Code Analysis Agent

- **Gemini model:** `gemini-3.1-pro-preview`
- **Tools:** `git`, `gh`
- **Investigates:** Related commits, code fixes, test additions, behavior changes

**Confidence scale:**

| Range | Meaning |
|---|---|
| 0.9 - 1.0 | Fix clearly merged, tests pass |
| 0.7 - 0.8 | Strong evidence but not 100% confirmed |
| 0.5 - 0.6 | Related changes found, unclear if they fix the issue |
| 0.0 - 0.4 | No evidence of a fix |

#### PR Correlation Agent

- **Gemini model:** `gemini-3.1-pro-preview`
- **Tools:** `git`, `gh`
- **Investigates:** PRs referencing the issue, merged PRs with matching content

**Confidence scale:**

| Range | Meaning |
|---|---|
| 0.9 - 1.0 | Merged PR explicitly fixes this issue |
| 0.7 - 0.8 | Merged PR likely addresses this issue |
| 0.5 - 0.6 | Open PRs or loosely related merged PRs |
| 0.0 - 0.4 | No related PRs |

#### Duplicate Detection Agent

- **Gemini model:** `gemini-3.1-pro-preview`
- **Tools:** `gh` only
- **Investigates:** Similar titles, same root cause, same error messages, same component

**Confidence scale:**

| Range | Meaning |
|---|---|
| 0.9 - 1.0 | Exact duplicate (same problem, same root cause) |
| 0.7 - 0.8 | Very similar (same area, different manifestation) |
| 0.5 - 0.6 | Related but distinct |
| 0.0 - 0.4 | No duplicates found (set to 0.0) |

#### Sentiment Analysis Agent

- **Gemini model:** `gemini-3.1-pro-preview`
- **Tools:** `gh` only
- **Investigates:** Discussion consensus, blockers, activity, maintainer input, reporter satisfaction

**Confidence scale:**

| Range | Meaning |
|---|---|
| 0.9 - 1.0 | Author explicitly confirmed resolved |
| 0.7 - 0.8 | Maintainer confirmed or multiple users verified |
| 0.5 - 0.6 | Positive signals but no explicit confirmation |
| 0.3 - 0.4 | Stale (> 90 days no activity) |
| 0.0 - 0.2 | Active discussion, issue unresolved |

**Recommended labels:** `stale` (> 90 days), `needs-response` (unanswered question), `confirmed`

#### Changelog Agent

- **Gemini model:** `gemini-3.1-pro-preview`
- **Tools:** `git`, `gh`
- **File includes:** `CHANGELOG.md` (via `@include`)
- **Investigates:** Issue references in changelogs, release notes, git tags

**Confidence scale:**

| Range | Meaning |
|---|---|
| 0.9 - 1.0 | Explicitly referenced in released changelog |
| 0.7 - 0.8 | Related commits in a release but not explicitly mentioned |
| 0.5 - 0.6 | Fix commits exist but unreleased |
| 0.0 - 0.4 | No mention in any release artifacts |

### Confidence Scoring and Decision Logic

The `TriageDecision.fromResults()` algorithm:

```
avgConfidence = mean(all agent confidence scores)
highConfCount = count(agents with confidence >= 0.7)
agreementBoost = max(0, 0.05 * (highConfCount - 1))
aggregateConfidence = clamp(avgConfidence + agreementBoost, 0.0, 1.0)
```

Example with 5 agents at [0.9, 0.8, 0.7, 0.3, 0.1]:
- Mean = 0.56
- High-confidence agents (>= 0.7) = 3
- Agreement boost = 0.05 * (3 - 1) = 0.10
- Aggregate = 0.66 (medium risk, suggest-close bracket)

---

## Release Pipeline Deep Dive

### Version Detection

The two-pass version detection system determines the appropriate semver bump:

**Pass 1 (always runs) -- Regex heuristic on commit messages:**

| Pattern | Bump |
|---|---|
| `BREAKING CHANGE` or `type!:` | `major` |
| `feat:` or `feat(scope):` | `minor` |
| Only `chore/style/ci/docs/test/build` | `none` |
| Everything else | `patch` |

**Pass 2 (Gemini override if available):**
- Gemini reads full commit history, changed files, diff stats
- Writes `version_bump.json` (`{"bump": "major|minor|patch|none"}`)
- Writes `version_bump_rationale.md` explaining the decision

**Safety guards:**
- Version never goes backward from `pubspec.yaml`
- If bump is `none`, returns current version unchanged
- Derives from previous tag (not pubspec) to avoid stale-version collisions

### Stage 1: Explore

See [explore command](#explore). The Explorer Agent produces 3 JSON artifacts that
flow to subsequent stages.

### Stage 2: Compose

See [compose command](#compose). The Composer Agent updates `CHANGELOG.md` using
Stage 1 artifacts and the issue manifest.

### Stage 3: Release Notes

See [release-notes command](#release-notes). The Release Notes Author produces
4 files with verified contributor data and anti-hallucination safeguards.

### GitHub Release Creation

See [create-release command](#create-release). Assembles all artifacts, commits
with `[skip ci]`, tags, and creates the GitHub Release.

### Contributor Verification

The release pipeline verifies contributors through the GitHub API:

1. Get unique commit SHAs per author email via `git log`
2. Resolve each SHA to a verified GitHub login:
   `gh api repos/<repo>/commits/<sha> --jq '.author.login'`
3. Exclude bots
4. Write verified `contributors.json`

This prevents Gemini from hallucinating contributor names. The `_postProcessReleaseNotes`
function replaces any Gemini-generated Contributors section with verified data.

---

## Autodoc System

The autodoc system generates documentation for code modules using a config-driven,
two-pass Gemini pipeline. Configuration lives in `.runtime_ci/autodoc.json`.

### autodoc.json schema

```json
{
  "modules": [
    {
      "id": "module-name",
      "name": "Human-Readable Name",
      "source_dir": "proto/src/module",
      "lib_dir": "lib/src/module",
      "doc_dir": "docs/module",
      "doc_types": ["quickstart", "api_reference", "examples", "migration"],
      "hash": "sha256-of-source-files"
    }
  ]
}
```

### Two-pass pipeline

For each changed module and each doc type:

1. **Pass 1 (Author):** Gemini Pro analyzes source files and generates documentation
2. **Pass 2 (Reviewer):** Gemini Pro fact-checks the output, corrects Dart naming
   conventions (e.g., `snake_case` -> `camelCase`), and fills gaps

### Doc types

| Type | Output File | What It Contains |
|---|---|---|
| `quickstart` | `QUICKSTART.md` | Overview, imports, setup, common operations, error handling |
| `api_reference` | `API_REFERENCE.md` | All messages, services, RPCs, enums with Dart usage examples |
| `examples` | `EXAMPLES.md` | Copy-paste-ready code examples for all major use cases |
| `migration` | `MIGRATION.md` | Breaking changes, upgrade steps, before/after code |

---

## Audit Trail System

Every CI/CD operation creates an audit trail for traceability.

### Two-tier storage

| Tier | Path | Gitignored | Purpose |
|---|---|---|---|
| Run trails | `.runtime_ci/runs/` | Yes | Full local audit trail (prompts, raw responses) |
| Release audits | `.runtime_ci/audit/v<version>/` | No | Curated per-release artifacts (committed) |

### Run directory structure

```
.runtime_ci/runs/
  run_2026-02-16T10-30-00_12345/
    meta.json                    # Run metadata (command, args, timing)
    explore/
      prompt.txt                 # Gemini prompt sent
      gemini_response.json       # Raw Gemini response
      commit_analysis.json       # Stage 1 artifact
      pr_data.json
      breaking_changes.json
    compose/
      prompt.txt
      gemini_response.json
    version_analysis/
      version_bump.json
      version_bump_rationale.md
    triage/
      issue_manifest.json
    agents/
      issue-42-code/
        prompt.txt
        response.json
```

### RunContext API

```dart
import 'package:runtime_ci_tooling/runtime_ci_tooling.dart';

// Create a new run
final ctx = RunContext.create('/path/to/repo', 'explore');

// Save artifacts
ctx.savePrompt('explore', promptText);
ctx.saveResponse('explore', geminiOutput);
ctx.saveJsonArtifact('explore', 'commit_analysis.json', data);

// Check artifacts
if (ctx.hasArtifact('explore', 'commit_analysis.json')) {
  final content = ctx.readArtifact('explore', 'commit_analysis.json');
}

// Finalize
ctx.finalize(exitCode: 0);

// Archive for release
ctx.archiveForRelease('0.2.0');

// Find latest run
final latestDir = RunContext.findLatestRun('/path/to/repo', command: 'explore');
```

---

## Programmatic API

The package exports a full Dart API for use in other packages:

```dart
import 'package:runtime_ci_tooling/runtime_ci_tooling.dart';
```

### Configuration

```dart
// Singleton config loaded from .runtime_ci/config.json
final cfg = config;
print(cfg.repoName);           // Package name
print(cfg.repoOwner);          // GitHub org
print(cfg.autoCloseThreshold); // 0.9
print(cfg.enabledAgents);      // ['code_analysis', ...]
print(cfg.proModel);           // 'gemini-3.1-pro-preview'

// Reload after modifications
reloadConfig();

// Resolve secrets
final apiKey = config.resolveGeminiApiKey();
final ghToken = config.resolveGithubToken();
```

### Gemini Runner

```dart
import 'package:runtime_ci_tooling/runtime_ci_tooling.dart';

final runner = GeminiRunner(
  maxConcurrent: 4,
  maxRetries: 3,
  verbose: true,
);

final tasks = [
  GeminiTask(
    id: 'analysis-1',
    prompt: 'Analyze this code...',
    model: kDefaultProModel,
    allowedTools: ['run_shell_command(git)', 'run_shell_command(gh)'],
    workingDirectory: '/path/to/repo',
  ),
  GeminiTask(
    id: 'analysis-2',
    prompt: 'Check for duplicates...',
    model: kDefaultFlashModel,
  ),
];

final results = await runner.executeBatch(tasks);
for (final result in results) {
  if (result.success) {
    print('${result.taskId}: ${result.response}');
  } else {
    print('${result.taskId} failed: ${result.errorMessage}');
  }
}
```

### Models

```dart
// Create a game plan
final plan = GamePlan.forIssues([
  {'number': 42, 'title': 'Bug report', 'author': {'login': 'user1'}, 'labels': []},
]);
print(plan.toJsonString());

// Parse investigation results
final result = InvestigationResult.fromJson(jsonData);
print(result.confidence);
print(result.relatedEntities);

// Make a triage decision
final decision = TriageDecision.fromResults(42, results);
print(decision.aggregateConfidence);
print(decision.riskLevel);    // RiskLevel.high/medium/low
print(decision.actions);       // List<TriageAction>
```

### JSON Utilities

```dart
final validation = validateGamePlan('path/to/game_plan.json');
if (!validation.valid) {
  print(validation.errors);
}

writeJson('output.json', {'key': 'value'});
final data = readJson('input.json');
```

### MCP Configuration

```dart
final githubConfig = buildGitHubMcpConfig(token: 'ghp_...');
final sentryConfig = buildSentryMcpConfig();
final updated = ensureMcpConfigured('/path/to/repo');
final serverStatus = await validateMcpServers('/path/to/repo');
```

### Repo Utilities

```dart
final repoRoot = findRepoRoot('my_package');
final isGenerated = isGeneratedFile('lib/src/model.pb.dart'); // true
```

### Tool Installers

```dart
final available = await ensureSmithyCli();
final exists = await commandExists('git');
```

---

## GitHub Actions Integration

### CI Workflow

**Triggers:** Push to `main`, pull requests targeting `main`

**Jobs:**
1. `pre-check` -- Skip bot commits (author `github-actions[bot]` or `[skip ci]`)
2. `analyze-and-test` -- Verify protos, run analysis, run tests

**Key steps:**
```yaml
- run: dart run runtime_ci_tooling:manage_cicd verify-protos
- run: dart run runtime_ci_tooling:manage_cicd analyze
- run: dart run runtime_ci_tooling:manage_cicd test
```

### Release Workflow

**Trigger:** `workflow_run` on CI completion (main branch only)

**8-job pipeline:**

| # | Job | Purpose | Output |
|---|---|---|---|
| 1 | `pre-check` | Bot loop prevention | `should_run` flag |
| 2 | `determine-version` | Gemini-powered version bump analysis | `prev_tag`, `new_version`, `should_release` |
| 3 | `pre-release-triage` | Scan issues and Sentry errors | `issue_manifest.json` |
| 4 | `explore-changes` | Stage 1 Explorer Agent | 3 JSON artifacts |
| 5 | `compose-artifacts` | Stage 2 Composer + docs + autodoc | `CHANGELOG.md`, `README.md`, docs |
| 6 | `release-notes` | Stage 3 Release Notes Author | `release_notes.md`, `migration_guide.md` |
| 7 | `create-release` | Commit, tag, publish GitHub Release | GitHub Release |
| 8 | `post-release-triage` | Close/comment on resolved issues | Issue updates |

**Artifact flow between jobs:**
- Each job uploads artifacts via `actions/upload-artifact`
- Downstream jobs download them via `actions/download-artifact`
- If a Gemini-powered job skips (no API key), it produces empty/fallback artifacts

### Issue Triage Workflow

**Triggers:**
- `issues: [opened, reopened]` -- Auto-triage new issues
- `issue_comment: [created]` -- Re-triage when comment contains `@gemini-cli`

**Concurrency:** Per-issue (`triage-${{ github.event.issue.number }}`)

**Safety:** Skips if actor is `github-actions[bot]` to prevent infinite loops.

**Key step:**
```yaml
- run: dart run runtime_ci_tooling:triage_cli ${{ github.event.issue.number }}
```

---

## Gemini CLI Commands

For interactive use outside the automated pipeline:

### `/triage <issue_number>`

Quick single-issue triage via Gemini CLI interactive mode.

```bash
gemini
> /triage 42
```

### `/changelog <version>`

Generate a changelog entry interactively.

```bash
gemini
> /changelog 0.2.0
```

### `/release-notes <version>`

Generate release notes interactively.

```bash
gemini
> /release-notes 0.2.0
```

These commands use Gemini's `!{...}` shell expansion to fetch live repository data.

---

## Global Flags

These flags apply to all `manage_cicd` commands:

| Flag | Description |
|---|---|
| `--dry-run` | Show what would be done without executing |
| `--verbose` / `-v` | Show detailed command output (logs every shell command) |
| `--prev-tag <tag>` | Override automatic previous git tag detection |
| `--version <ver>` | Override automatic next version detection |
| `--help` / `-h` | Show usage help |

---

## Environment Variables

### Required

| Variable | Purpose |
|---|---|
| `GEMINI_API_KEY` | Gemini AI API authentication |
| `GH_TOKEN` or `GITHUB_TOKEN` | GitHub API authentication |

### Optional

| Variable | Purpose |
|---|---|
| `GITHUB_PAT` | Alternative GitHub token |
| `SENTRY_ACCESS_TOKEN` | Sentry MCP integration |
| `GITHUB_REPOSITORY` | `owner/repo` slug (auto-set in GitHub Actions) |
| `GITHUB_OUTPUT` | GitHub Actions output file |
| `GITHUB_STEP_SUMMARY` | GitHub Actions step summary file |
| `GITHUB_SERVER_URL` | GitHub server base URL |
| `GITHUB_SHA` | Current commit SHA |
| `GITHUB_RUN_ID` | Current workflow run ID |
| `CI` | Detect CI environment |

---

## Files and Directories Reference

### Created by `init`

| Path | Purpose | Gitignored |
|---|---|---|
| `.runtime_ci/config.json` | Repository CI/CD configuration | No |
| `CHANGELOG.md` | Keep a Changelog file | No |

### Created by `configure-mcp`

| Path | Purpose | Gitignored |
|---|---|---|
| `.gemini/settings.json` | Gemini CLI settings + MCP servers | No |

### Created at runtime

| Path | Purpose | Gitignored |
|---|---|---|
| `.runtime_ci/runs/` | Audit trail (prompts, responses, artifacts) | **Yes** |
| `.runtime_ci/audit/v<version>/` | Curated release audit snapshots | No |
| `.runtime_ci/release_notes/v<version>/` | Release notes artifacts | No |
| `.runtime_ci/version_bumps/v<version>.md` | Version bump rationale | No |
| `.runtime_ci/autodoc.json` | Autodoc module configuration + hashes | No |
| `/tmp/commit_analysis.json` | Stage 1 artifact (CI) | N/A |
| `/tmp/pr_data.json` | Stage 1 artifact (CI) | N/A |
| `/tmp/breaking_changes.json` | Stage 1 artifact (CI) | N/A |
| `/tmp/release_notes_body.md` | Release notes body (CI) | N/A |
| `/tmp/migration_guide.md` | Migration guide (CI) | N/A |
| `/tmp/triage.lock` | Global triage lock file | N/A |

### Templates (in package)

| Path | Purpose |
|---|---|
| `templates/config.json` | Config template with placeholders |
| `templates/gemini/settings.template.json` | Gemini CLI settings template |
| `templates/gemini/commands/*.toml` | Gemini CLI custom command templates |
| `templates/github/workflows/*.template.yaml` | GitHub Actions workflow templates |
