- **Decision**: patch
  - The commits since the last release only contain minor documentation updates, string changes in CLI output/comments, and regeneration of CI workflows. There are no breaking changes or new features introduced. According to the semantic versioning rules, documentation updates, chore/maintenance tasks, and CI changes warrant a patch bump.

- **Key Changes**:
  - Updated string literals, CLI descriptions, and documentation to consistently reference "Gemini 3.1 Pro Preview".
  - Regenerated `.github/workflows/ci.yaml` to match the current v0.16.0 tooling version and fix a golden file test.
  - Updated timestamps and hashes in `.runtime_ci/template_versions.json`.

- **Breaking Changes**: None

- **New Features**: None

- **References**:
  - PR #41: fix: add Preview suffix to all Gemini 3.1 Pro references and regenerate CI workflow
  - PR #40: fix: update all Gemini model references from 3.0/unversioned to 3.1 Pro
