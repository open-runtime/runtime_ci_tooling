- **Decision**: patch
  This release addresses a parsing bug where using the shorthand CLI syntax `triage <number>` would crash because the `args` package `CommandRunner` threw a `UsageException` before the branch command's `run()` method was ever invoked. By properly intercepting bare issue numbers earlier in the process (in `_translateArgs` and `ManageCicdCli.run()`), the shorthand syntax correctly resolves to the `single` subcommand again.
- **Key Changes**:
  * Fixed CLI argument parsing to correctly map `triage <number>` to `triage single <number>`.
  * Removed dead, unreachable `run()` logic from `TriageCommand` that previously attempted (and failed) to handle this shorthand.
- **Breaking Changes**: None
- **New Features**: None
- **References**:
  * Commit: fix: handle bare issue number in triage CLI (fixes CI triage failures)
