/// Entry point for `dart run scripts/triage/triage_cli.dart` in this repo.
///
/// Delegates directly to the package's own implementation.
/// Configuration is loaded from `runtime.ci.config.json` at the repo root.
import '../../lib/src/triage/triage_cli.dart' as triage;

Future<void> main(List<String> args) => triage.main(args);
