# Version Bump Rationale

**Decision**: minor

**Reasoning**: 
The commit history since the `v0.12.1` release introduces significant new functionality (`feat`), specifically multi-package support for CLI commands and multi-platform CI matrix generation capabilities. These are additive changes and do not introduce breaking API changes. Therefore, a MINOR version bump is appropriate.

**Key Changes**:
- Added multi-package support for CLI commands, allowing operations to cascade over sub-packages.
- Added multi-platform CI matrix generation capabilities including configurable `platforms` and `runner_overrides`.
- Increased testing timeouts for CI workflows from 20 to 30 minutes to mitigate pipeline instability.
- Removed debug leftovers in `post_release.dart`.
- Fixed redundant path normalization when dealing with sub-packages.
- Added GitHub organization safety guard (`_kAllowedOrgs`) to all triage action scripts to prevent unintended changes to upstream/unauthorized repositories.
- Enforced `--repo` flag on `gh` commands across all GitHub operations to avoid ambiguities originating from local git remotes in forked repositories.
- Fixed git diff fallbacks when operating without previous tags.

**Breaking Changes**:
- None.

**New Features**:
- Multi-package cascading for repository automation.
- Multi-platform CI matrix workflow generation.
- Organizational allowlisting to safeguard triage bot behaviors on non-allowlisted repositories.

**References**:
- PR #18: `feat/multi-package-support`
- Commits adding `multi-platform CI matrix generation`
- Bug fixes to CI and code robustness
