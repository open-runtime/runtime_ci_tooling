# Version Bump Rationale

**Decision**: patch

The recent commits are purely CI configuration/maintenance and bug fixes, specifically addressing how the release command handles fallback merges during a non-fast-forward push scenario. This constitutes internal infrastructure maintenance rather than a new feature or breaking change.

## Key Changes
- Fixed a bug where a fallback merge in the `create-release` command could trigger a new CI/release run, potentially cancelling the active release pipeline. A `[skip ci]` marker was added to the fallback merge commit message.
- Minor chore updates to commit messages.

## Breaking Changes
None.

## New Features
None.

## References
- `chore(ci): trigger CI after skip-token commit message`
- `fix(ci): prevent release self-cancellation on fallback merge`
