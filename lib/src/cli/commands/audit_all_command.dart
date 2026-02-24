// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../manage_cicd_cli.dart';
import '../utils/audit/audit_finding.dart';
import '../utils/audit/package_registry.dart';
import '../utils/audit/pubspec_auditor.dart';
import '../utils/logger.dart';

/// Recursively audit all pubspec.yaml files under a directory against the
/// package registry.
///
/// Discovers every `pubspec.yaml` in the tree, loads the shared package
/// registry once, and runs the auditor against each pubspec with configurable
/// concurrency. Produces a per-file summary and aggregated totals.
class AuditAllCommand extends Command<void> {
  @override
  final String name = 'audit-all';

  @override
  final String description = 'Recursively audit all pubspec.yaml files under a directory against the package registry.';

  AuditAllCommand() {
    argParser
      ..addOption('path', help: 'Root directory to scan. Defaults to current working directory.')
      ..addOption(
        'registry',
        help:
            'Path to external_workspace_packages.yaml. '
            'Auto-detected from monorepo root when omitted.',
      )
      ..addFlag('fix', defaultsTo: false, help: 'Automatically fix found issues in-place.')
      ..addOption(
        'severity',
        defaultsTo: 'error',
        allowed: ['error', 'warning', 'info'],
        help: 'Minimum severity to report.',
      )
      ..addOption('concurrency', defaultsTo: '4', help: 'Max concurrent audit operations.')
      ..addMultiOption(
        'exclude',
        defaultsTo: ['.dart_tool', 'build', 'node_modules', '.git'],
        help: 'Directory names to exclude from scan.',
      );
  }

  @override
  Future<void> run() async {
    final global = ManageCicdCli.parseGlobalOptions(globalResults);
    final dryRun = global.dryRun;
    final verbose = global.verbose;

    final scanRoot = argResults!['path'] as String? ?? Directory.current.path;
    final registryPath = argResults!['registry'] as String?;
    final fix = argResults!['fix'] as bool;
    final severityFilter = _parseSeverity(argResults!['severity'] as String);
    final concurrency = int.tryParse(argResults!['concurrency'] as String) ?? 4;
    final excludeDirs = (argResults!['exclude'] as List<String>).toSet();

    // ── 1. Resolve scan root ──────────────────────────────────────────────
    final rootDir = Directory(scanRoot);
    if (!rootDir.existsSync()) {
      Logger.error('Scan root does not exist: $scanRoot');
      exit(1);
    }

    Logger.header('audit-all: Scanning ${rootDir.path}');

    // ── 2. Resolve registry ───────────────────────────────────────────────
    final resolvedRegistry = registryPath ?? _autoDetectRegistry(scanRoot);
    if (resolvedRegistry == null) {
      Logger.error(
        'Could not auto-detect external_workspace_packages.yaml. '
        'Specify --registry explicitly.',
      );
      exit(1);
    }

    if (!File(resolvedRegistry).existsSync()) {
      Logger.error('Registry file not found: $resolvedRegistry');
      exit(1);
    }

    if (verbose) {
      Logger.info('Registry: $resolvedRegistry');
    }

    // ── 3. Discover pubspec.yaml files ────────────────────────────────────
    final pubspecs = _discoverPubspecs(rootDir, excludeDirs);

    if (pubspecs.isEmpty) {
      Logger.warn('No pubspec.yaml files found under ${rootDir.path}');
      return;
    }

    Logger.info('Found ${pubspecs.length} pubspec.yaml files\n');

    // ── 4. Load registry & create auditor ─────────────────────────────────
    final registry = PackageRegistry.load(resolvedRegistry);
    final auditor = PubspecAuditor(registry: registry);

    // ── 5. Audit with worker pool ─────────────────────────────────────────
    final effectiveConcurrency = concurrency.clamp(1, pubspecs.length);
    final results = <_AuditResult>[];
    var index = 0;

    Future<void> worker() async {
      while (true) {
        if (index >= pubspecs.length) break;
        final currentIndex = index;
        index++;

        final pubspecPath = pubspecs[currentIndex];
        final allFindings = auditor.auditPubspec(pubspecPath);

        // Filter by minimum severity.
        final filtered = allFindings.where((f) => f.severity.index <= severityFilter.index).toList();

        results.add(
          _AuditResult(index: currentIndex, pubspecPath: pubspecPath, findings: filtered, allFindings: allFindings),
        );
      }
    }

    final workers = <Future<void>>[];
    for (var i = 0; i < effectiveConcurrency; i++) {
      workers.add(worker());
    }
    await Future.wait(workers);

    // Sort by original discovery order.
    results.sort((a, b) => a.index.compareTo(b.index));

    // ── 6. Per-pubspec status lines ───────────────────────────────────────
    final total = pubspecs.length;
    final pubspecsWithFindings = <_AuditResult>[];

    for (final result in results) {
      final relative = p.relative(result.pubspecPath, from: rootDir.path);
      final label = '[${result.index + 1}/$total]';

      if (result.findings.isEmpty) {
        Logger.success('$label $relative ${'.' * _dots(relative, label, total)} OK');
      } else {
        final errors = result.findings.where((f) => f.severity == AuditSeverity.error).length;
        final warnings = result.findings.where((f) => f.severity == AuditSeverity.warning).length;
        final infos = result.findings.where((f) => f.severity == AuditSeverity.info).length;

        final parts = <String>[];
        if (errors > 0) parts.add('$errors error${errors == 1 ? '' : 's'}');
        if (warnings > 0) parts.add('$warnings warning${warnings == 1 ? '' : 's'}');
        if (infos > 0) parts.add('$infos info');

        Logger.warn('$label $relative ${'.' * _dots(relative, label, total)} ${parts.join(', ')}');
        pubspecsWithFindings.add(result);
      }
    }

    // ── 7. Detailed findings ──────────────────────────────────────────────
    if (pubspecsWithFindings.isNotEmpty) {
      Logger.header('DETAILS (pubspecs with findings):');

      for (final result in pubspecsWithFindings) {
        final relative = p.relative(result.pubspecPath, from: rootDir.path);
        Logger.info('\n  $relative:');

        for (final finding in result.findings) {
          final severityTag = finding.severity.name.toUpperCase();
          final pad = severityTag.length < 5 ? ' ' * (5 - severityTag.length) : '';

          switch (finding.severity) {
            case AuditSeverity.error:
              Logger.error('    $severityTag$pad ${finding.dependencyName}: ${finding.message}');
            case AuditSeverity.warning:
              Logger.warn('    $severityTag$pad ${finding.dependencyName}: ${finding.message}');
            case AuditSeverity.info:
              Logger.info('    $severityTag$pad ${finding.dependencyName}: ${finding.message}');
          }
        }
      }
    }

    // ── 8. Fix pass ───────────────────────────────────────────────────────
    var fixedCount = 0;
    if (fix && !dryRun && pubspecsWithFindings.isNotEmpty) {
      Logger.header('Applying fixes...');

      for (final result in pubspecsWithFindings) {
        final relative = p.relative(result.pubspecPath, from: rootDir.path);
        // Fix should apply to the full set of findings, even if the report
        // is filtered to errors only (otherwise warnings never get fixed).
        final didFix = auditor.fixPubspec(result.pubspecPath, result.allFindings);
        if (didFix) {
          fixedCount++;
          Logger.success('  Fixed: $relative');
        } else {
          Logger.warn('  No auto-fix available: $relative');
        }
      }
    } else if (fix && dryRun && pubspecsWithFindings.isNotEmpty) {
      Logger.header('[DRY-RUN] Would fix ${pubspecsWithFindings.length} pubspec(s)');
      for (final result in pubspecsWithFindings) {
        final relative = p.relative(result.pubspecPath, from: rootDir.path);
        Logger.info('  $relative');
      }
    }

    // ── 9. Summary ────────────────────────────────────────────────────────
    final totalErrors = results.fold<int>(
      0,
      (sum, r) => sum + r.findings.where((f) => f.severity == AuditSeverity.error).length,
    );
    final totalWarnings = results.fold<int>(
      0,
      (sum, r) => sum + r.findings.where((f) => f.severity == AuditSeverity.warning).length,
    );
    final totalInfos = results.fold<int>(
      0,
      (sum, r) => sum + r.findings.where((f) => f.severity == AuditSeverity.info).length,
    );
    final cleanCount = results.where((r) => r.findings.isEmpty).length;
    final issueCount = results.where((r) => r.findings.isNotEmpty).length;

    Logger.header('Summary');
    Logger.info('  ${pubspecs.length} pubspecs scanned');
    Logger.info('  $cleanCount clean');

    if (issueCount > 0) {
      final parts = <String>[];
      if (totalErrors > 0) parts.add('$totalErrors error${totalErrors == 1 ? '' : 's'}');
      if (totalWarnings > 0) {
        parts.add('$totalWarnings warning${totalWarnings == 1 ? '' : 's'}');
      }
      if (totalInfos > 0) parts.add('$totalInfos info');
      Logger.warn('  $issueCount with issues (${parts.join(', ')})');
    }

    if (fixedCount > 0) {
      Logger.success('  $fixedCount pubspec(s) fixed');
    }

    // ── 10. Exit code ─────────────────────────────────────────────────────
    if (totalErrors > 0) {
      exit(1);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Recursively discover `pubspec.yaml` files, respecting exclusions.
  List<String> _discoverPubspecs(Directory root, Set<String> excludeDirs) {
    final results = <String>[];
    _scanForPubspecs(root, results, excludeDirs);
    results.sort();
    return results;
  }

  void _scanForPubspecs(Directory dir, List<String> results, Set<String> excludeDirs) {
    List<FileSystemEntity> children;
    try {
      children = dir.listSync(followLinks: false);
    } catch (_) {
      return;
    }

    for (final child in children) {
      if (child is File) {
        final name = p.basename(child.path);
        if (name == 'pubspec.yaml') {
          results.add(child.path);
        }
        // Skip pubspec_overrides.yaml — not relevant for audit.
      } else if (child is Directory) {
        final name = p.basename(child.path);
        // Skip hidden directories and explicitly excluded names.
        if (name.startsWith('.') || excludeDirs.contains(name)) {
          continue;
        }
        _scanForPubspecs(child, results, excludeDirs);
      }
    }
  }

  /// Walk up from [startPath] looking for `configs/external_workspace_packages.yaml`.
  String? _autoDetectRegistry(String startPath) {
    var current = p.canonicalize(startPath);
    while (true) {
      final candidate = p.join(current, 'configs', 'external_workspace_packages.yaml');
      if (File(candidate).existsSync()) {
        return candidate;
      }
      final parent = p.dirname(current);
      if (parent == current) break;
      current = parent;
    }
    return null;
  }

  /// Parse a severity string into an [AuditSeverity].
  AuditSeverity _parseSeverity(String value) {
    switch (value) {
      case 'error':
        return AuditSeverity.error;
      case 'warning':
        return AuditSeverity.warning;
      case 'info':
        return AuditSeverity.info;
      default:
        return AuditSeverity.error;
    }
  }

  /// Compute number of dots for alignment in status output.
  int _dots(String relative, String label, int total) {
    // Target ~80 chars wide. Adjust padding for the label and path.
    const lineWidth = 80;
    final used = label.length + 1 + relative.length + 1;
    final remaining = lineWidth - used;
    return remaining > 2 ? remaining : 2;
  }
}

class _AuditResult {
  final int index;
  final String pubspecPath;
  final List<AuditFinding> findings;
  final List<AuditFinding> allFindings;

  const _AuditResult({
    required this.index,
    required this.pubspecPath,
    required this.findings,
    required this.allFindings,
  });
}
