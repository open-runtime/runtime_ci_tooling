**Decision**: minor

This bump is required because a new feature (`update` command) was added to the public CLI interface without modifying or breaking any existing public API contracts.

**Key Changes**:
- Added `dart run runtime_ci_tooling:manage_cicd update` command for syncing templates to consumer repositories.
- Implemented smart update strategies based on file category: overwritable, cautious, mergeable, and regeneratable.
- Added three-way hash tracking via `template_versions.json` to detect and handle local consumer customizations.
- Fixed code formatting in `update_options.g.dart`.

**Breaking Changes**:
- None.

**New Features**:
- The `update` CLI command allowing consumers to sync templates, GitHub workflows, and CI configuration intelligently.

**References**:
- PR / Commit: `feat: add update command for syncing templates to consumer repos`
- Commit: `chore: fix formatting in update_options.g.dart`
