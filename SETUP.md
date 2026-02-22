# Setup Guide -- `runtime_ci_tooling`

Complete setup instructions for integrating `runtime_ci_tooling` into any Dart/Flutter
repository. This package provides Gemini-powered CI/CD automation including issue triage,
release pipeline orchestration, changelog generation, and documentation updates.

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [System Requirements](#system-requirements)
- [Step 1: Add the Dependency](#step-1-add-the-dependency)
- [Step 2: Initialize Configuration](#step-2-initialize-configuration)
- [Step 3: Install Required Tools](#step-3-install-required-tools)
- [Step 4: Set Up Environment Variables](#step-4-set-up-environment-variables)
- [Step 5: Configure MCP Servers](#step-5-configure-mcp-servers)
- [Step 6: Scaffold GitHub Actions Workflows](#step-6-scaffold-github-actions-workflows)
- [Step 7: Configure Gemini CLI](#step-7-configure-gemini-cli)
- [Step 8: Validate the Setup](#step-8-validate-the-setup)
- [Configuration Reference](#configuration-reference)
- [Monorepo vs Standalone Setup](#monorepo-vs-standalone-setup)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

| Prerequisite | Minimum Version | Purpose |
|---|---|---|
| Dart SDK | `^3.9.0` | Runtime for the CLI tools |
| Git | Any recent | Version control, tag/commit analysis |
| GitHub CLI (`gh`) | Any recent | GitHub API interactions (issues, PRs, releases) |
| Node.js + npm | Node 18+ | Required by Gemini CLI |
| jq | Any | JSON processing in prompts |
| Gemini CLI | Latest (`@google/gemini-cli`) | AI agent execution engine |
| tree (optional) | Any | Directory structure in prompts |

---

## System Requirements

The package supports **macOS**, **Linux**, and **Windows**. The `setup` command will
auto-install missing tools using platform-appropriate package managers:

| Tool | macOS | Linux | Windows |
|---|---|---|---|
| Node.js/npm | `brew install node` | `apt install nodejs npm` | `winget install OpenJS.NodeJS` |
| Gemini CLI | `npm install -g @google/gemini-cli@latest` | Same | Same |
| GitHub CLI | `brew install gh` | Official apt repo | `winget install GitHub.cli` |
| jq | `brew install jq` | `apt install jq` | `winget install jqlang.jq` |
| tree | `brew install tree` | `apt install tree` | Built-in (limited) |

---

## Step 1: Add the Dependency

### Option A: Git dependency (recommended for external repos)

Add to your `pubspec.yaml`:

```yaml
dependencies:
  runtime_ci_tooling:
    git:
      url: https://github.com/pieces-app/unified_monorepo.git
      path: shared/runtime_ci_tooling
```

### Option B: Path dependency (for the unified monorepo)

If your package lives in the same monorepo:

```yaml
dependencies:
  runtime_ci_tooling:
    path: ../runtime_ci_tooling
```

### Option C: Workspace resolution (Dart 3.9+ workspaces)

Add `resolution: workspace` to the package's `pubspec.yaml` and ensure the root
workspace includes this package. The root `pubspec.yaml` should list:

```yaml
workspace:
  - shared/runtime_ci_tooling
  - shared/your_package
```

Then run:

```bash
dart pub get
```

---

## Step 2: Initialize Configuration

Run the `init` command from your repository root:

```bash
dart run runtime_ci_tooling:manage_cicd init
```

This auto-detects your environment and creates:

| File | Purpose |
|---|---|
| `.runtime_ci/config.json` | Repository-specific CI/CD configuration |
| `CHANGELOG.md` | Starter changelog (if not present) |
| `.gitignore` entry | Adds `.runtime_ci/runs/` to gitignore |

The `init` command will:
1. Auto-detect your package name and version from `pubspec.yaml`
2. Auto-detect the GitHub owner via `gh repo view` or git remote URL
3. Scan `lib/` and `lib/src/` to auto-generate area labels
4. Print a summary and next steps

### Manual configuration

If `init` cannot auto-detect everything, edit `.runtime_ci/config.json` directly.
The minimum required configuration is:

```json
{
  "repository": {
    "name": "your_package_name",
    "owner": "your_github_org"
  }
}
```

See [Configuration Reference](#configuration-reference) for all options.

---

## Step 3: Install Required Tools

Run the automated setup:

```bash
dart run runtime_ci_tooling:manage_cicd setup
```

This checks and installs (if missing):
- **Required**: `git`, `gh`, `node`, `npm`, `jq`
- **Optional**: `tree`, `gemini`

Use `--dry-run` to preview what would be installed without making changes:

```bash
dart run runtime_ci_tooling:manage_cicd setup --dry-run
```

### Manual Gemini CLI installation

If automatic installation fails:

```bash
npm install -g @google/gemini-cli@latest
```

Verify:

```bash
gemini --version
```

---

## Step 4: Set Up Environment Variables

### Required environment variables

| Variable | Purpose | How to Obtain |
|---|---|---|
| `GEMINI_API_KEY` | Authenticates with Gemini AI | [Google AI Studio](https://aistudio.google.com/apikey) |
| `GH_TOKEN` or `GITHUB_TOKEN` | Authenticates with GitHub API | `gh auth token` or create a [Personal Access Token](https://github.com/settings/tokens) |

### Setting locally

Add to your shell profile (`~/.zshrc`, `~/.bashrc`, etc.):

```bash
export GEMINI_API_KEY="your-gemini-api-key"
export GH_TOKEN="your-github-token"
```

### Setting in GitHub Actions

Add these as repository or organization secrets:

1. Go to your repo > Settings > Secrets and variables > Actions
2. Add `GEMINI_API_KEY` as a repository secret
3. `GITHUB_TOKEN` is automatically available in GitHub Actions

### Optional environment variables

| Variable | Purpose |
|---|---|
| `GITHUB_PAT` | Alternative GitHub token name |
| `SENTRY_ACCESS_TOKEN` | Sentry MCP integration for error scanning |

### GCP Secret Manager fallback

If you use Google Cloud, configure the `secrets` section in `.runtime_ci/config.json`:

```json
{
  "secrets": {
    "gcp_secret_name": "your-secret-name"
  },
  "gcp": {
    "project": "your-gcp-project-id"
  }
}
```

The CLI will fall back to GCP Secret Manager if environment variables are not set.

---

## Step 5: Configure MCP Servers

MCP (Model Context Protocol) servers give Gemini access to GitHub and Sentry APIs.
Run:

```bash
dart run runtime_ci_tooling:manage_cicd configure-mcp
```

This creates/updates `.gemini/settings.json` with:
- **GitHub MCP Server** (Docker-based): Provides issue, PR, search, and repository tools
- **Sentry MCP Server** (remote URL): Provides error tracking integration

### GitHub MCP tools enabled for triage

The following 13 tools are allowlisted for triage operations:

```
issue_read, issue_write, search_issues, search_code,
list_issues, list_pull_requests, pull_request_read,
get_file_contents, get_commit, list_commits,
search_pull_requests, add_issue_comment, get_me
```

### Blocked tools (safety)

These tools are always blocked:

```
delete_repository, fork_repository, create_repository
```

---

## Step 6: Scaffold GitHub Actions Workflows

The package includes templates for three GitHub Actions workflows. Copy them from
the templates directory:

```bash
# From your repository root:
mkdir -p .github/workflows

# CI workflow
cp shared/runtime_ci_tooling/templates/github/workflows/ci.template.yaml \
   .github/workflows/ci.yaml

# Release pipeline
cp shared/runtime_ci_tooling/templates/github/workflows/release.template.yaml \
   .github/workflows/release.yaml

# Issue triage
cp shared/runtime_ci_tooling/templates/github/workflows/issue-triage.template.yaml \
   .github/workflows/issue-triage.yaml
```

### Customize the workflows

Edit each workflow to replace placeholder values:

1. **`ci.yaml`**: Update secret names, Dart SDK version, any package-specific test commands
2. **`release.yaml`**: Update secret names, artifact paths, the `--repo` flag in `create-release`
3. **`issue-triage.yaml`**: Update secret names, ensure `issues: write` permission

### Required GitHub Actions secrets

| Secret | Used By | Purpose |
|---|---|---|
| `GEMINI_API_KEY` | All Gemini-powered steps | AI model access |
| Personal Access Token | Release pipeline | Push commits with `[skip ci]`, create tags |
| `GITHUB_TOKEN` | Built-in | Default GitHub API access |

> **Important**: The release workflow requires a Personal Access Token (not
> `GITHUB_TOKEN`) to push commits that trigger subsequent workflows.

---

## Step 7: Configure Gemini CLI

### Settings file

The `configure-mcp` command (Step 5) creates `.gemini/settings.json`. You can also
use the template:

```bash
cp shared/runtime_ci_tooling/templates/gemini/settings.template.json \
   .gemini/settings.json
```

### Custom commands

Copy the Gemini CLI custom commands for interactive use:

```bash
mkdir -p .gemini/commands

cp shared/runtime_ci_tooling/templates/gemini/commands/triage.toml \
   .gemini/commands/triage.toml

cp shared/runtime_ci_tooling/templates/gemini/commands/changelog.toml \
   .gemini/commands/changelog.toml

cp shared/runtime_ci_tooling/templates/gemini/commands/release-notes.toml \
   .gemini/commands/release-notes.toml
```

These enable interactive Gemini CLI commands:
- `/triage <issue_number>` -- Triage a single issue interactively
- `/changelog <version>` -- Generate changelog entry
- `/release-notes <version>` -- Generate release notes

### Allowed shell commands

The Gemini CLI settings restrict which shell commands Gemini can execute:

**Allowed**: `git`, `gh`, `tree`, `find`, `wc`, `sort`, `uniq`, `head`, `tail`,
`cat`, `jq`, `dart`, `grep`, `ls`, `echo`, `tee`

**Blocked**: `rm`, `sudo`, `curl`, `wget`, `chmod`, `chown`, `mv`, `kill`,
`pkill`, `npm`, `pip`

---

## Step 8: Validate the Setup

Run the validation and status commands to confirm everything is configured:

```bash
# Validate all config files exist and are well-formed
dart run runtime_ci_tooling:manage_cicd validate

# Show comprehensive status of tools, config, and artifacts
dart run runtime_ci_tooling:manage_cicd status
```

The `validate` command checks:
- JSON files parse correctly
- YAML files are well-formed
- TOML files contain required `prompt` and `description` keys
- Dart files pass `dart analyze`
- Markdown files exist and are non-empty

The `status` command shows:
- Installation status of all required/optional tools
- Environment variable status (set/not set)
- Configured MCP servers
- Stage 1 artifact status
- Package version and latest git tag

---

## Configuration Reference

The `.runtime_ci/config.json` file controls all behavior. Here is the complete schema:

```json
{
  "repository": {
    "name": "REQUIRED -- Dart package name / GitHub repo name",
    "owner": "REQUIRED -- GitHub org or username",
    "triaged_label": "triaged",
    "changelog_path": "CHANGELOG.md",
    "release_notes_path": "release_notes"
  },
  "gcp": {
    "project": "your-gcp-project-id"
  },
  "sentry": {
    "organization": "sentry-org-slug",
    "projects": ["project-slug-1"],
    "scan_on_pre_release": true,
    "recent_errors_hours": 168
  },
  "release": {
    "pre_release_scan_sentry": true,
    "pre_release_scan_github": true,
    "post_release_close_own_repo": true,
    "post_release_close_cross_repo": false,
    "post_release_comment_cross_repo": true,
    "post_release_link_sentry": true
  },
  "cross_repo": {
    "enabled": true,
    "repos": [
      {
        "owner": "your-org",
        "repo": "dependent-repo",
        "relationship": "dependency"
      }
    ]
  },
  "labels": {
    "type": ["bug", "feature-request", "enhancement", "documentation", "question"],
    "priority": ["P0-critical", "P1-high", "P2-medium", "P3-low"],
    "area": ["area/core", "area/api"]
  },
  "thresholds": {
    "auto_close": 0.9,
    "suggest_close": 0.7,
    "comment": 0.5
  },
  "agents": {
    "enabled": [
      "code_analysis",
      "pr_correlation",
      "duplicate",
      "sentiment",
      "changelog"
    ],
    "conditional": {
      "changelog": {
        "require_file": "CHANGELOG.md"
      }
    }
  },
  "gemini": {
    "flash_model": "gemini-3-flash-preview",
    "pro_model": "gemini-3.1-pro-preview",
    "max_turns": 100,
    "max_concurrent": 4,
    "max_retries": 3
  },
  "secrets": {
    "gemini_api_key_env": "GEMINI_API_KEY",
    "github_token_env": ["GH_TOKEN", "GITHUB_TOKEN", "GITHUB_PAT"],
    "gcp_secret_name": "your-secret-in-gcp"
  }
}
```

### Configuration sections explained

#### `repository` (required)

| Key | Type | Default | Description |
|---|---|---|---|
| `name` | `String` | -- | **Required.** Dart package name matching `pubspec.yaml` |
| `owner` | `String` | -- | **Required.** GitHub organization or username |
| `triaged_label` | `String` | `"triaged"` | Label applied to issues after triage |
| `changelog_path` | `String` | `"CHANGELOG.md"` | Path to the CHANGELOG file |
| `release_notes_path` | `String` | `"release_notes"` | Directory for release notes artifacts |

#### `thresholds`

Controls automated triage actions based on aggregated agent confidence:

| Key | Default | Behavior |
|---|---|---|
| `auto_close` | `0.9` | Issues at or above this confidence are automatically closed |
| `suggest_close` | `0.7` | Issues at this level get a "likely resolved" comment suggesting closure |
| `comment` | `0.5` | Issues at this level get an informational comment with findings |

Issues below the `comment` threshold receive only a `needs-investigation` label.

#### `agents`

| Key | Default | Description |
|---|---|---|
| `enabled` | All 5 agents | Which investigation agents to run during triage |
| `conditional.<name>.require_file` | -- | Only run this agent if the specified file exists in the repo |

Available agents: `code_analysis`, `pr_correlation`, `duplicate`, `sentiment`, `changelog`

#### `gemini`

| Key | Default | Description |
|---|---|---|
| `flash_model` | `"gemini-3-flash-preview"` | Fast model for agent investigations |
| `pro_model` | `"gemini-3.1-pro-preview"` | Powerful model for complex analysis (explore, compose, release notes) |
| `max_turns` | `100` | Maximum conversation turns per Gemini invocation |
| `max_concurrent` | `4` | Maximum parallel Gemini processes |
| `max_retries` | `3` | Retry count with exponential backoff |

#### `cross_repo`

| Key | Default | Description |
|---|---|---|
| `enabled` | `true` | Enable cross-repository issue discovery and linking |
| `repos` | `[]` | List of dependent repositories to scan |

Each repo entry: `{ "owner": "...", "repo": "...", "relationship": "dependency|consumer|..." }`

---

## Monorepo vs Standalone Setup

### Inside the unified monorepo

If your package is in the `unified_monorepo`, use workspace resolution:

```yaml
# In your package's pubspec.yaml
dependencies:
  runtime_ci_tooling:
    # Resolved via workspace
resolution: workspace
```

The root `pubspec.yaml` must include both packages in the `workspace:` list.

### Standalone repository

For independent repositories, use a git dependency and ensure `resolution: workspace`
is **not** set in `runtime_ci_tooling`'s pubspec (it's intentionally omitted for
standalone compatibility).

---

## Troubleshooting

### "Could not find repo root"

The CLI walks upward from CWD looking for a `pubspec.yaml` whose `name:` field matches
`config.repoName`. Ensure:
1. You're running from within your project directory
2. `.runtime_ci/config.json` has the correct `repository.name`
3. Your `pubspec.yaml` has a matching `name:` field

### "Gemini CLI not found"

```bash
npm install -g @google/gemini-cli@latest
gemini --version
```

### "No GEMINI_API_KEY"

The CLI checks `$GEMINI_API_KEY` environment variable first, then falls back to GCP
Secret Manager. Set it:

```bash
export GEMINI_API_KEY="your-key-from-aistudio"
```

### Gemini commands gracefully skip

If Gemini CLI or the API key is not available, AI-powered commands (`explore`,
`compose`, `release-notes`, `triage`, `documentation`, `autodoc`) will **gracefully
skip** rather than fail. This allows the CI pipeline to continue without AI features.

### Lock file conflict

The triage CLI uses a global lock at `/tmp/triage.lock`. If a previous run crashed:

```bash
# Force override the lock
dart run runtime_ci_tooling:triage_cli --auto --force
```

The lock automatically cleans up stale locks from dead processes.

### Stage 1 artifacts not found

The `compose` and `release-notes` stages look for artifacts in two locations:
1. `/tmp/` (populated by CI artifact downloads)
2. `.runtime_ci/runs/explore/` (populated by local `explore` runs)

Run `explore` before `compose` or `release-notes`:

```bash
dart run runtime_ci_tooling:manage_cicd explore --prev-tag v0.1.0 --version 0.2.0
dart run runtime_ci_tooling:manage_cicd compose --prev-tag v0.1.0 --version 0.2.0
```

### Config file discovery

The config loader searches upward from CWD checking these paths at each level:

1. `.runtime_ci/config.json` (canonical)
2. `runtime.ci.config.json` (legacy)
3. `scripts/triage/triage_config.json` (legacy)
4. `triage_config.json` (legacy)

Use the canonical path for new setups.
