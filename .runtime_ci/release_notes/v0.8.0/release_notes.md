# runtime_ci_tooling v0.8.0

> This minor release introduces the `update` command, enabling consumers to intelligently sync their repositories with the latest CI templates, workflows, and configurations. It features smart update strategies and three-way hash tracking to ensure local customizations are safely preserved.

## Highlights

- **Intelligent Template Updating** — New `update` command to effortlessly sync upstream CI configurations and templates.
- **Smart Update Strategies** — Intelligent handling of files based on their category (overwritable, cautious, mergeable, and regeneratable).
- **Three-Way Hash Tracking** — Detects local consumer customizations via `template_versions.json` to prevent accidental overwrites.

## What's New

### Intelligent `update` Command
The new `update` CLI command allows consumers to sync their project templates, GitHub workflows, and CI configs with the latest versions provided by `runtime_ci_tooling`. Instead of a blind overwrite, the tooling tracks versions and local edits to apply updates safely.

```bash
# Run the intelligent update
dart run runtime_ci_tooling:manage_cicd update
```

You can target specific components or force overwrites using the provided flags:

```bash
# Only update GitHub workflow files
dart run runtime_ci_tooling:manage_cicd update --workflows

# Only merge new keys into .runtime_ci/config.json
dart run runtime_ci_tooling:manage_cicd update --config

# Write .bak backups before overwriting any files
dart run runtime_ci_tooling:manage_cicd update --backup

# Overwrite all files regardless of local customizations
dart run runtime_ci_tooling:manage_cicd update --force
```

## Bug Fixes

- Fixed code formatting in `update_options.g.dart`

## Issues Addressed

No linked issues for this release.
## Upgrade

```bash
dart pub upgrade runtime_ci_tooling
```

## Contributors

Thanks to everyone who contributed to this release:
- @tsavo-at-pieces
## Full Changelog

[v0.7.1...v0.8.0](https://github.com/open-runtime/runtime_ci_tooling/compare/v0.7.1...v0.8.0)
