import 'dart:io';

/// ANSI-styled console logging for CI/CD commands.
abstract final class Logger {
  static void header(String msg) => print('\n\x1B[1m$msg\x1B[0m');
  static void info(String msg) => print(msg);
  static void success(String msg) => print('\x1B[32m$msg\x1B[0m');
  static void warn(String msg) => print('\x1B[33m$msg\x1B[0m');
  static void error(String msg) => stderr.writeln('\x1B[31m$msg\x1B[0m');
}
