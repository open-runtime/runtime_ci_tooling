# runtime_ci_tooling v0.11.0

> This minor release introduces multi-platform CI support to the workflow generation system, allowing you to easily configure test matrices across Ubuntu, macOS, and Windows.

## Highlights

- **Multi-Platform CI Support** — Generate CI workflows that run your tests across multiple operating systems with a single configuration array.
- **Backward Compatible** — Single-platform projects continue to use the streamlined, combined analyze-and-test job format without changes.

## What's New

### Multi-Platform Workflow Generation
You can now define a `ci.platforms` array in your `config.json` to automatically generate a multi-platform CI matrix. When multiple platforms are detected, the workflow generator will intelligently split the CI pipeline into a single `analyze` job (on Ubuntu) and a matrixed `test` job across your selected environments.

Supported platform identifiers include:
```dart
const _platformRunners = <String, String>{
  'ubuntu': 'ubuntu-latest',
  'macos': 'macos-latest',
  'macos-arm64': 'macos-latest',
  'macos-x64': 'macos-13',
  'windows': 'windows-latest',
};
```

If multiple platforms are provided, the generated GitHub Actions test job will use a matrix strategy automatically populated by the generator:
```yaml
  test:
    needs: [pre-check, analyze]
    if: needs.pre-check.outputs.should_run == 'true'
    runs-on: ${{ matrix.os }}
    strategy:
      fail-fast: false
      matrix:
        os: <%platform_matrix_json%>
```

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

[v0.10.0...v0.11.0](https://github.com/open-runtime/runtime_ci_tooling/compare/v0.10.0...v0.11.0)
