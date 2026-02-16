# runtime_ci_tooling v0.5.0

> This minor release introduces comprehensive documentation and enhanced CI templates for better email validation and LFS support.

## Highlights

- **Comprehensive Documentation** — Added `SETUP.md` and `USAGE.md` guides.
- **Enhanced CI Templates** — Added SendGrid Email Validation API key support.
- **Improved LFS Support** — Enabled Git LFS checkout in CI workflows.

## What's New

### Comprehensive Documentation
We've added detailed `SETUP.md` and `USAGE.md` files to the repository root, providing step-by-step instructions for getting started and utilizing the `runtime_ci_tooling` package effectively.

### CI Template Enhancements
The `templates/github/workflows/ci.template.yaml` has been updated to include the `SENDGRID_EMAIL_VALIDATION_API_KEY` secret. This allows CI workflows to validate email addresses using the SendGrid validation API.

```yaml
# templates/github/workflows/ci.template.yaml

# In the `env` section:
SENDGRID_EMAIL_VALIDATION_API_KEY: ${{ secrets.OPEN_RUNTIME_SENDGRID_EMAIL_VALIDATIONS_API_KEY }}
```

## Bug Fixes

- **Fixed LFS Checkout in CI** — Tests relying on Git LFS assets were previously failing in CI because the assets were not downloaded during checkout. We've updated the `checkout` step to include `lfs: true`. ([#a3996c9](https://github.com/open-runtime/runtime_ci_tooling/commit/a3996c9))

## Issues Addressed

No linked issues for this release.
## Deprecations

None.

## Upgrade

```bash
dart pub upgrade runtime_ci_tooling
```

## Contributors

Thanks to everyone who contributed to this release:
- @tsavo-at-pieces
## Full Changelog

[v0.4.1...v0.5.0](https://github.com/open-runtime/runtime_ci_tooling/compare/v0.4.1...v0.5.0)
