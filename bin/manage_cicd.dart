import 'dart:io';

import 'package:runtime_ci_tooling/src/cli/manage_cicd_cli.dart';

Future<void> main(List<String> args) async {
  final cli = ManageCicdCli();
  try {
    await cli.run(args);
  } on UsageException catch (e) {
    stderr.writeln(e);
    exit(64);
  }
}
