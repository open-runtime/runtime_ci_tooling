**Decision**: minor - The recent commit introduces a new feature to the workflow generation system, enabling multi-platform CI support. This is an additive API change that extends the tool's capabilities without breaking existing public APIs or workflows.

**Key Changes**:
- Added parsing and validation for the new `ci.platforms` array in configuration.
- Extended `WorkflowGenerator` to populate new platform-related template variables (`multi_platform`, `single_platform`, `runner`, `platform_matrix_json`).
- Updated `ci.skeleton.yaml` to conditionally render either a single combined `analyze-and-test` job (for backward compatibility) or separate `analyze` and multi-platform `test` matrix jobs.
- Added mapping of platform identifiers (e.g., `ubuntu`, `macos`, `windows`) to their corresponding GitHub Actions runners.

**Breaking Changes**:
- None.

**New Features**:
- Support for configurable platform matrices via the `ci.platforms` array in `config.json`.

**References**:
- Commit: feat: add multi-platform CI workflow generation
