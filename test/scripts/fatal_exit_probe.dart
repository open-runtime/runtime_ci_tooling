// Probe script for testing CiProcessRunner.exec with fatal=true.
// Run: dart run test/scripts/fatal_exit_probe.dart
// Expected: exits with code 1 (or 7 on Windows when using exit 7).
import 'dart:io';

import 'package:runtime_ci_tooling/src/cli/utils/process_runner.dart';

Future<void> main() async {
  if (Platform.isWindows) {
    await CiProcessRunner.exec('cmd', ['/c', 'exit', '7'], fatal: true);
  } else {
    await CiProcessRunner.exec('false', [], fatal: true);
  }
}
