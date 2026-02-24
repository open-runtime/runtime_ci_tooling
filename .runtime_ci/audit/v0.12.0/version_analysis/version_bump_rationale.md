# Version Bump Rationale

- **Decision**: minor
  The changes introduce new additive features (`feat:` commit) and functional improvements without modifying or breaking any public API surfaces.

- **Key Changes**:
  - Replaced the strict `format_check` step in generated CI templates (`ci.skeleton.yaml`) with a new `auto-format` job. The job now runs `dart format` and commits/pushes the changes back to the repository automatically.
  - Enhanced `TemplateResolver` to correctly locate the package template directories when the application is globally activated (i.e., executed as a global binary).
  - Updated the `update-all` command logic to favor the globally activated `manage_cicd` binary over `dart run` in order to side-step `resolution: workspace` errors in monorepo structures.
  - Updated generated CI template hashes in `template_versions.json`.

- **Breaking Changes**:
  - None. Existing configuration and tools remain compatible.

- **New Features**:
  - Automated formatting and commit capability in generated CI workflows (`ci.skeleton.yaml`).
  - Native fallback support for globally activated `manage_cicd` CLI execution.

- **References**:
  - Commit: `feat: add auto-format CI job that commits formatting before analyze/test`
  - Commit: `fix: support global activation in update-all and template resolution`
