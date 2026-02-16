# Migration Guide: v0.3.0 → v0.4.0

## Table of Contents
- [Script Usage](#script-usage)

---

## Script Usage

### Summary
The `scripts/` directory wrappers have been removed in favor of `bin/` executables.

### Background
We have moved to standard Dart executables in `bin/` to allow direct usage via `dart run runtime_ci_tooling:<command>` and to remove the need for generated wrapper scripts.

### Migration

**Before:**
```bash
dart scripts/manage_cicd.dart
dart scripts/triage/triage_cli.dart
```

**After:**
```bash
dart run runtime_ci_tooling:manage_cicd
dart run runtime_ci_tooling:triage_cli
```

### References
- Commit: [53149d9](https://github.com/open-runtime/runtime_ci_tooling/commit/53149d9)
