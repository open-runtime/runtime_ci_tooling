import 'dart:io';

/// Flush stdout and stderr before exiting so final messages are not lost.
/// Ignores flush errors (e.g. when running under dart test with captured streams).
Future<Never> exitWithCode(int code) async {
  try {
    await stdout.flush();
  } catch (_) {}
  try {
    await stderr.flush();
  } catch (_) {}
  exit(code);
}
