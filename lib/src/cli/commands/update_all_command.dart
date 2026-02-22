// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../../triage/utils/config.dart' show kConfigFileName;
import '../manage_cicd_cli.dart';
import '../options/update_all_options.dart';
import '../utils/logger.dart';

/// Batch-update all packages under a root directory.
///
/// Discovers packages that have opted into `runtime_ci_tooling` (identified by
/// the presence of `.runtime_ci/config.json`) and runs `manage_cicd update`
/// on each via a subprocess, forwarding passthrough flags like `--force`,
/// `--workflows`, `--backup`, etc.
class UpdateAllCommand extends Command<void> {
  @override
  final String name = 'update-all';

  @override
  final String description = 'Discover and update all runtime_ci_tooling packages under a root directory.';

  UpdateAllCommand() {
    UpdateAllOptionsArgParser.populateParser(argParser);
  }

  @override
  Future<void> run() async {
    final opts = UpdateAllOptions.fromArgResults(argResults!);
    final global = ManageCicdCli.parseGlobalOptions(globalResults);
    final dryRun = global.dryRun;
    final verbose = global.verbose;

    // Resolve scan root.
    final scanRoot = opts.scanRoot ?? Directory.current.path;
    final rootDir = Directory(scanRoot);
    if (!rootDir.existsSync()) {
      Logger.error('Scan root does not exist: $scanRoot');
      exit(1);
    }

    Logger.header('update-all: Discovering packages');
    Logger.info('Scan root: ${rootDir.path}');

    // Discovery: find all directories containing .runtime_ci/config.json.
    final packages = _discoverPackages(rootDir);

    if (packages.isEmpty) {
      Logger.warn('No packages with $kConfigFileName found under ${rootDir.path}');
      return;
    }

    Logger.info('Found ${packages.length} package(s):');
    for (final pkg in packages) {
      Logger.info('  - ${p.relative(pkg.path, from: rootDir.path)}');
    }

    if (dryRun) {
      Logger.header('[DRY-RUN] Would update ${packages.length} package(s)');
      for (var i = 0; i < packages.length; i++) {
        final pkg = packages[i];
        final args = _buildSubprocessArgs(global: global, opts: opts);
        Logger.info('  [${i + 1}/${packages.length}] dart run runtime_ci_tooling:manage_cicd ${args.join(" ")}');
        Logger.info('    in: ${pkg.path}');
      }
      return;
    }

    // Execute updates with worker pool concurrency.
    Logger.header('Updating ${packages.length} package(s)');

    final results = <_UpdateResult>[];
    final concurrency = opts.concurrency.clamp(1, packages.length);

    var index = 0;
    Future<void> worker() async {
      while (true) {
        if (index >= packages.length) break;
        final currentIndex = index;
        index++;
        final pkg = packages[currentIndex];
        final result = await _updatePackage(
          pkg: pkg,
          index: currentIndex,
          total: packages.length,
          rootDir: rootDir,
          global: global,
          opts: opts,
          verbose: verbose,
        );
        results.add(result);
      }
    }

    final workers = <Future<void>>[];
    for (var i = 0; i < concurrency; i++) {
      workers.add(worker());
    }
    await Future.wait(workers);

    // Sort results by original package order for deterministic output.
    results.sort((a, b) => a.index.compareTo(b.index));

    // Summary.
    Logger.header('Summary');
    final succeeded = results.where((r) => r.success).length;
    final failed = results.where((r) => !r.success).length;

    for (final result in results) {
      final relative = p.relative(result.packagePath, from: rootDir.path);
      if (result.success) {
        Logger.success('  OK   $relative (${result.duration.inMilliseconds}ms)');
      } else {
        Logger.error('  FAIL $relative (${result.duration.inMilliseconds}ms)');
      }
    }

    Logger.info('');
    if (failed == 0) {
      Logger.success('Updated $succeeded/${packages.length} package(s) successfully.');
    } else {
      Logger.warn('Updated $succeeded/${packages.length} package(s). $failed failed.');
    }
  }

  /// Recursively scan for directories containing [kConfigFileName].
  List<Directory> _discoverPackages(Directory root) {
    final packages = <Directory>[];
    _scanDirectory(root, packages);
    packages.sort((a, b) => a.path.compareTo(b.path));
    return packages;
  }

  void _scanDirectory(Directory dir, List<Directory> results) {
    final configFile = File(p.join(dir.path, kConfigFileName));
    if (configFile.existsSync()) {
      results.add(dir);
      // Don't recurse into packages that already have a config —
      // nested configs are not expected in this tooling.
      return;
    }

    List<FileSystemEntity> children;
    try {
      children = dir.listSync(followLinks: false);
    } catch (_) {
      return;
    }

    for (final child in children) {
      if (child is Directory) {
        final name = p.basename(child.path);
        // Skip hidden directories and common non-package directories.
        if (name.startsWith('.') || name == 'build' || name == 'node_modules') {
          continue;
        }
        _scanDirectory(child, results);
      }
    }
  }

  /// Build the subprocess argument list for `manage_cicd update`.
  List<String> _buildSubprocessArgs({required dynamic global, required UpdateAllOptions opts}) {
    final args = <String>[];

    // Global flags (before the command name).
    final globalArgs = <String>[];
    if (global.verbose) globalArgs.add('--verbose');

    // Update command flags.
    final updateArgs = <String>['update'];
    if (opts.force) updateArgs.add('--force');
    if (opts.workflows) updateArgs.add('--workflows');
    if (opts.templates) updateArgs.add('--templates');
    if (opts.config) updateArgs.add('--config');
    if (opts.autodoc) updateArgs.add('--autodoc');
    if (opts.backup) updateArgs.add('--backup');

    args.addAll(globalArgs);
    args.addAll(updateArgs);
    return args;
  }

  Future<_UpdateResult> _updatePackage({
    required Directory pkg,
    required int index,
    required int total,
    required Directory rootDir,
    required dynamic global,
    required UpdateAllOptions opts,
    required bool verbose,
  }) async {
    final relative = p.relative(pkg.path, from: rootDir.path);
    final label = '[${index + 1}/$total]';
    Logger.info('$label Updating $relative...');

    final args = _buildSubprocessArgs(global: global, opts: opts);
    final sw = Stopwatch()..start();

    try {
      final result = await Process.run(
        'dart',
        ['run', 'runtime_ci_tooling:manage_cicd', ...args],
        workingDirectory: pkg.path,
      ).timeout(const Duration(minutes: 5), onTimeout: () => ProcessResult(0, 124, '', 'Timed out after 5 minutes'));

      sw.stop();

      if (result.exitCode == 0) {
        Logger.success('$label $relative OK (${sw.elapsedMilliseconds}ms)');
        if (verbose) {
          final stdout = (result.stdout as String).trim();
          if (stdout.isNotEmpty) Logger.info(stdout);
        }
        return _UpdateResult(index: index, packagePath: pkg.path, success: true, duration: sw.elapsed);
      } else {
        Logger.error('$label $relative FAILED (exit ${result.exitCode})');
        final stdout = (result.stdout as String).trim();
        final stderr = (result.stderr as String).trim();
        if (stdout.isNotEmpty) Logger.info(stdout);
        if (stderr.isNotEmpty) Logger.error(stderr);
        return _UpdateResult(index: index, packagePath: pkg.path, success: false, duration: sw.elapsed);
      }
    } catch (e) {
      sw.stop();
      Logger.error('$label $relative ERROR: $e');
      return _UpdateResult(index: index, packagePath: pkg.path, success: false, duration: sw.elapsed);
    }
  }
}

class _UpdateResult {
  final int index;
  final String packagePath;
  final bool success;
  final Duration duration;

  const _UpdateResult({required this.index, required this.packagePath, required this.success, required this.duration});
}
