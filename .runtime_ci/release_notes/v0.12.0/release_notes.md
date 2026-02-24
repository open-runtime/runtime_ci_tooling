# runtime_ci_tooling v0.12.0

> This minor release introduces automatic CI formatting commits and robust support for global activation within monorepo environments.

## Highlights

- **Auto-Formatting CI Job** — Replaced the strict formatting check with a new CI job that automatically formats code and pushes the changes back to your branch.
- **Monorepo Update Resilience** — The `update-all` command now preferentially uses the globally activated binary to bypass `resolution: workspace` errors.
- **Global Activation Support** — Enhanced `TemplateResolver` to correctly locate internal template directories when executing as a globally activated binary.

## What's New

### Auto-Format CI Job
The generated CI workflow (`ci.skeleton.yaml`) now includes a dedicated `auto-format` job. Instead of failing your CI pipeline when code isn't formatted perfectly, this job runs `dart format` and seamlessly commits the changes back to your PR or branch using the `bot(format)` commit message.

```yaml
      - name: Commit and push formatting
        id: format-push
        run: |
          if ! git diff --quiet; then
            git config user.name "github-actions[bot]"
            git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
            git add -A
            git commit -m "bot(format): apply dart format --line-length <%line_length%> [skip ci]"
            if git push; then
              echo "sha=$(git rev-parse HEAD)" >> "$GITHUB_OUTPUT"
              echo "::notice::Formatting changes committed and pushed."
            else
              echo "::warning::Could not push formatting changes (branch may be protected or this is a fork PR)."
            fi
          else
            echo "::notice::Code is already formatted."
          fi
```

### Resilient `update-all` Command
For projects using Dart workspaces, running `dart run runtime_ci_tooling:manage_cicd` within a sub-package could fail due to `resolution: workspace` restrictions. The `update-all` command now detects if you have `manage_cicd` activated globally and will use it preferentially:

```dart
    // Prefer the globally activated `manage_cicd` binary over `dart run`
    // to avoid `resolution: workspace` issues in monorepo environments.
    final useGlobalBinary = _isGloballyActivated();
    if (useGlobalBinary) {
      Logger.info('Using globally activated manage_cicd binary');
    }
```

### Globally Activated Template Resolution
If you activate `runtime_ci_tooling` globally (`dart pub global activate`), the tool can now natively traverse `Platform.script` ancestor directories to resolve the `templates/` directory. This allows you to run `manage_cicd` from anywhere on your machine without path resolution failures.

## Bug Fixes

- **Template Resolution for Global Activation** — Fixed template resolution to walk `Platform.script` ancestors to reliably locate template resources when running `manage_cicd` as a globally activated binary.

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

[v0.11.3...v0.12.0](https://github.com/open-runtime/runtime_ci_tooling/compare/v0.11.3...v0.12.0)
