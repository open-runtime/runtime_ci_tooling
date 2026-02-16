/// Entry point for `dart run scripts/manage_cicd.dart` in this repo.
///
/// Delegates directly to the package's own implementation.
/// Configuration is loaded from `runtime.ci.config.json` at the repo root.
import '../lib/src/cli/manage_cicd.dart' as cicd;

Future<void> main(List<String> args) => cicd.main(args);
