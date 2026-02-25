# runtime_ci_tooling

Shared CI/CD automation tooling for open-runtime or pieces-app packages. Provides a reusable triage pipeline, Gemini CLI integration, audit trail management, release automation, and GitHub Actions workflow utilities.

## Features

- **Gemini-Powered Triage**: Automated issue analysis, labeling, and response generation.
- **Release Automation**: Automated versioning, changelog generation, and release notes authoring. Support for sibling dependency conversion and per-package tag creation for multi-package releases.
- **Documentation Generation**: Automated documentation maintenance using Gemini (with parallel execution and automatic retries), including API references, migration guides, quickstarts, and examples. Writes directly to module-scoped paths.
- **Dependency Auditing**: Audit tools (`audit` and `audit-all`) for `pubspec.yaml` dependency validation against a central workspace registry.
- **Audit Trails**: Comprehensive logging of CI/CD actions and decisions.
- **MCP Integration**: Configuration for Model Context Protocol servers (GitHub, Sentry).
- **Multi-Package Support**: Support for `analyze`, `test`, `autodoc`, `changelog`, and `release` commands across multiple packages in a single repository.
- **Multi-Platform CI**: Multi-platform CI workflow generation supporting configurable platform matrices via `config.json`'s `ci.platforms` array and `ci.runner_overrides` config.
- **CI Codegen**: Support for `build_runner` feature flag to generate `.g.dart` files directly in CI, eliminating environment drift.
- **Cross-Platform**: Utilities for tool installation and environment setup.
- **Auto-Formatting CI**: CI workflow templates include an auto-format job that automatically commits dart formatting changes before analysis and testing.
- **Template Updating**: Keep local configurations and CI workflows in sync with upstream changes.
- **Global Activation Support**: Can be globally activated (`dart pub global activate runtime_ci_tooling`) to bypass workspace resolution issues, fully supported with path-agnostic template resolution.
- **Secure Execution & Logging**: Safe subprocess execution with automatic credential redaction and verbose operation logging.
- **Typed CLI Options**: Uses `build_cli` to generate typed and structured command-line options.

## Installation

Add `runtime_ci_tooling` to your `dev_dependencies`:

```yaml
dev_dependencies:
  runtime_ci_tooling: ^0.14.1
```

Or run:

```bash
dart pub add dev:runtime_ci_tooling
```

You can also install this globally:

```bash
dart pub global activate runtime_ci_tooling
```

## Configuration

The tooling expects configuration to be present in the `.runtime_ci/` directory.
You can generate a default configuration and scaffold workflows using:

```bash
dart run bin/manage_cicd.dart init
```

This will create:
- `.runtime_ci/config.json`
- `.runtime_ci/autodoc.json`
- `.github/workflows/` (if requested)

## Usage

As of version **v0.14.0**, tools are available as executables in `bin/` (and globally), and CLI options are strictly typed.

### Manage CI/CD

The main entry point for CI/CD operations.

```bash
dart run bin/manage_cicd.dart <command> [options]
```

**Common Commands:**
- `setup`: Install prerequisites (Node.js, Gemini CLI, gh, jq).
- `validate`: Validate configuration files.
- `init`: Initialize configuration (`config.json`, `autodoc.json`) and workflows.
- `update`: Update templates, configs, and workflows from runtime_ci_tooling.
- `update-all`: Discover and update all runtime_ci_tooling packages under a root directory.
- `consumers`: Discover runtime_ci_tooling consumers and sync latest release data.
- `release`: Run the full local release pipeline.
- `audit`: Validate `pubspec.yaml` dependencies against a workspace registry.
- `audit-all`: Discover and run the audit process across all packages.
- `triage <N>`: Run issue triage for a single issue.
- `explore`: Run Stage 1 Explorer Agent.
- `compose`: Run Stage 2 Changelog Composer.
- `release-notes`: Run Stage 3 Release Notes Author.
- `autodoc`: Generate/update module documentation. Use `--init` to automatically scaffold `autodoc.json` based on the `lib/src/` structure.
- `status`: Show current CI/CD configuration status.

Run `dart run bin/manage_cicd.dart --help` for full usage details.

### Triage CLI

Specialized tool for issue triage and release management interactions.

```bash
dart run bin/triage_cli.dart <command> [options]
```

**Usage Examples:**
- **Single Issue**: `dart run bin/triage_cli.dart <issue_number>`
- **Auto Triage**: `dart run bin/triage_cli.dart --auto`
- **Pre-Release Scan**: `dart run bin/triage_cli.dart --pre-release --prev-tag v0.14.0 --version 0.14.1`
- **Post-Release Loop**: `dart run bin/triage_cli.dart --post-release --version 0.14.1 --release-tag v0.14.1`

Run `dart run bin/triage_cli.dart --help` for full usage details.

### Documentation Generators

Specialized scripts are provided in `scripts/prompts/` to generate documentation for Dart source modules.

**Usage Examples:**
- **Migration Guide**: `dart run scripts/prompts/autodoc_migration_prompt.dart <module_name> <source_dir> [prev_hash]`
- **API Reference**: `dart run scripts/prompts/autodoc_api_reference_prompt.dart <module_name> <source_dir> [lib_dir]`
- **Quickstart Guide**: `dart run scripts/prompts/autodoc_quickstart_prompt.dart <module_name> <source_dir> [lib_dir]`
- **Examples**: `dart run scripts/prompts/autodoc_examples_prompt.dart <module_name> <source_dir> [lib_dir]`

## Versioning

This package adheres to [Semantic Versioning](https://semver.org/).
