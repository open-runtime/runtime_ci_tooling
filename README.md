# runtime_ci_tooling

Shared CI/CD automation tooling for open-runtime or pieces-app packages. Provides a reusable triage pipeline, Gemini CLI integration, audit trail management, release automation, and GitHub Actions workflow utilities.

## Features

- **Gemini-Powered Triage**: Automated issue analysis, labeling, and response generation.
- **Release Automation**: Automated versioning, changelog generation, and release notes authoring.
- **Documentation Generation**: Automated documentation maintenance using Gemini, including API references, migration guides, quickstarts, and examples.
- **Audit Trails**: Comprehensive logging of CI/CD actions and decisions.
- **MCP Integration**: Configuration for Model Context Protocol servers (GitHub, Sentry).
- **Cross-Platform**: Utilities for tool installation and environment setup.
- **Template Updating**: Keep local configurations and CI workflows in sync with upstream changes.
- **Typed CLI Options**: Uses `build_cli` to generate typed and structured command-line options.

## Installation

Add `runtime_ci_tooling` to your `dev_dependencies`:

```yaml
dev_dependencies:
  runtime_ci_tooling: ^0.8.0
```

Or run:

```bash
dart pub add dev:runtime_ci_tooling
```

## Configuration

The tooling expects configuration to be present in the `.runtime_ci/` directory.
You can generate a default configuration and scaffold workflows using:

```bash
dart run scripts/manage_cicd.dart init
```

This will create:
- `.runtime_ci/config.json`
- `.runtime_ci/autodoc.json`
- `.github/workflows/` (if requested)

## Usage

As of version **v0.7.0**, tools are available as script wrappers in `scripts/` instead of `bin/` executables, and CLI options are strictly typed.

### Manage CI/CD

The main entry point for CI/CD operations.

```bash
dart run scripts/manage_cicd.dart <command> [options]
```

**Common Commands:**
- `setup`: Install prerequisites (Node.js, Gemini CLI, gh, jq).
- `validate`: Validate configuration files.
- `init`: Initialize configuration (`config.json`, `autodoc.json`) and workflows.
- `update`: Update templates, configs, and workflows from runtime_ci_tooling.
- `release`: Run the full local release pipeline.
- `triage <N>`: Run issue triage for a single issue.
- `explore`: Run Stage 1 Explorer Agent.
- `compose`: Run Stage 2 Changelog Composer.
- `release-notes`: Run Stage 3 Release Notes Author.
- `autodoc`: Generate/update module documentation.
- `status`: Show current CI/CD configuration status.

Run `dart run scripts/manage_cicd.dart --help` for full usage details.

### Triage CLI

Specialized tool for issue triage and release management interactions.

```bash
dart run scripts/triage_cli.dart <command> [options]
```

**Usage Examples:**
- **Single Issue**: `dart run scripts/triage_cli.dart <issue_number>`
- **Auto Triage**: `dart run scripts/triage_cli.dart --auto`
- **Pre-Release Scan**: `dart run scripts/triage_cli.dart --pre-release --prev-tag v0.7.1 --version 0.8.0`
- **Post-Release Loop**: `dart run scripts/triage_cli.dart --post-release --version 0.8.0 --release-tag v0.8.0`

Run `dart run scripts/triage_cli.dart --help` for full usage details.

### Documentation Generators

Specialized scripts are provided in `scripts/prompts/` to generate documentation for Dart source modules.

**Usage Examples:**
- **Migration Guide**: `dart run scripts/prompts/autodoc_migration_prompt.dart <module_name> <source_dir> [prev_hash]`
- **API Reference**: `dart run scripts/prompts/autodoc_api_reference_prompt.dart <module_name> <source_dir> [lib_dir]`
- **Quickstart Guide**: `dart run scripts/prompts/autodoc_quickstart_prompt.dart <module_name> <source_dir> [lib_dir]`
- **Examples**: `dart run scripts/prompts/autodoc_examples_prompt.dart <module_name> <source_dir> [lib_dir]`

## Versioning

This package adheres to [Semantic Versioning](https://semver.org/).
