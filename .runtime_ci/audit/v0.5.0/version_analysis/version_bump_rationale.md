# Version Bump Rationale

## Decision: MINOR

The `templates/github/workflows/ci.template.yaml` file has been updated with a new feature and a bug fix. Since this package distributes these templates for use in consumer CI pipelines, these changes constitute a functional update to the provided tooling.

## Key Changes

*   **New Feature:** Added `SENDGRID_EMAIL_VALIDATION_API_KEY` to the CI workflow template. This enables consumers to use SendGrid's email validation service in their CI pipelines.
*   **Bug Fix:** Enabled Git LFS (`lfs: true`) in the CI checkout step. This fixes an issue where tests relying on LFS-tracked assets (images, audio, PDF) would fail in CI because the assets were not downloaded.
*   **Documentation:** Added comprehensive `SETUP.md` and `USAGE.md` guides.

## Breaking Changes

None. The changes to the template are additive (new env var) or fixative (LFS support). Existing CI workflows generated from previous templates will continue to work, though users may want to update to benefit from the fixes.

## References

*   `feat: add SendGrid Email Validation API key to CI template`
*   `fix: add lfs: true to CI checkout so test assets are downloaded`
*   `Add comprehensive SETUP.md and USAGE.md documentation`
