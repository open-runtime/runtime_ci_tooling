// ignore_for_file: avoid_print

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../manage_cicd_cli.dart';
import '../utils/audit/audit_finding.dart';
import '../utils/audit/package_registry.dart';
import '../utils/audit/pubspec_auditor.dart';
import '../utils/logger.dart';

/// Audit a pubspec.yaml against the package registry for dependency issues.
///
/// Loads the external workspace packages registry and validates that all
/// dependencies in the target pubspec.yaml conform to expected git URLs,
/// version constraints, tag patterns, and organizational ownership.
class AuditCommand extends Command<void> {
  @override
  final String name = 'audit';

  @override
  final String description = 'Audit a pubspec.yaml against the package registry for dependency issues.';

  AuditCommand() {
    argParser
      ..addOption(
        'path',
        help:
            'Path to a specific pubspec.yaml file. '
            'Defaults to pubspec.yaml in the current directory.',
      )
      ..addOption(
        'registry',
        help:
            'Path to external_workspace_packages.yaml. '
            'Defaults to configs/external_workspace_packages.yaml '
            'relative to the auto-detected monorepo root.',
      )
      ..addFlag('fix', defaultsTo: false, help: 'Automatically fix found issues in-place.')
      ..addOption(
        'severity',
        defaultsTo: 'error',
        allowed: ['error', 'warning', 'info'],
        help: 'Minimum severity to report.',
      );
  }

  @override
  Future<void> run() async {
    final global = ManageCicdCli.parseGlobalOptions(globalResults);
    final dryRun = global.dryRun;
    final verbose = global.verbose;

    final fix = argResults!['fix'] as bool;
    final minSeverity = _parseSeverity(argResults!['severity'] as String);

    // ── Resolve pubspec path ──────────────────────────────────────────────
    final pubspecPath = _resolvePubspecPath(argResults!['path'] as String?);
    if (pubspecPath == null) {
      Logger.error(
        'Could not find pubspec.yaml. '
        'Specify --path or run from a directory containing pubspec.yaml.',
      );
      exit(1);
    }

    // ── Resolve registry path ─────────────────────────────────────────────
    final registryPath = _resolveRegistryPath(explicit: argResults!['registry'] as String?, pubspecPath: pubspecPath);
    if (registryPath == null) {
      Logger.error(
        'Could not find external_workspace_packages.yaml. '
        'Specify --registry or run from within the monorepo.',
      );
      exit(1);
    }

    // ── Load registry and create auditor ──────────────────────────────────
    Logger.header('audit: Scanning pubspec.yaml');

    final PackageRegistry registry;
    try {
      registry = PackageRegistry.load(registryPath);
    } catch (e) {
      Logger.error('Failed to load registry at $registryPath: $e');
      exit(1);
    }

    final auditor = PubspecAuditor(registry: registry);

    Logger.info('');
    Logger.info(
      '  Auditing $pubspecPath against registry '
      '(${registry.entries.length} packages)...',
    );

    // ── Run audit ─────────────────────────────────────────────────────────
    final allFindings = auditor.auditPubspec(pubspecPath);

    // Filter by minimum severity.
    final findings = allFindings.where((f) => f.severity.index <= minSeverity.index).toList();

    if (findings.isEmpty) {
      Logger.info('');
      Logger.success('  No issues found.');
      return;
    }

    // ── Print findings grouped by severity ────────────────────────────────
    _printFindings(findings, verbose: verbose);

    // ── Fix mode ──────────────────────────────────────────────────────────
    if (fix) {
      final fixableFindings = allFindings.where((f) => f.severity.index <= minSeverity.index).toList();

      if (dryRun) {
        Logger.info('');
        Logger.warn(
          '  [DRY-RUN] Would fix ${fixableFindings.length} finding(s) '
          'in $pubspecPath',
        );
      } else {
        Logger.info('');
        Logger.info('  Applying fixes...');
        final fixed = auditor.fixPubspec(pubspecPath, fixableFindings);
        if (fixed) {
          Logger.success('  Fixes applied to $pubspecPath');

          // Re-audit to check remaining issues.
          final remaining = auditor.auditPubspec(pubspecPath);
          final remainingErrors = remaining.where((f) => f.severity == AuditSeverity.error).toList();
          if (remainingErrors.isEmpty) {
            Logger.success('  All errors resolved.');
            return;
          } else {
            Logger.warn('  ${remainingErrors.length} error(s) remain after fixes.');
            _printFindings(remaining, verbose: verbose);
          }
        } else {
          Logger.warn('  No fixes were applied (nothing fixable).');
        }
      }
    }

    // ── Exit code ─────────────────────────────────────────────────────────
    final errorCount = findings.where((f) => f.severity == AuditSeverity.error).length;
    if (errorCount > 0) {
      exit(1);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Resolve the target pubspec.yaml path.
  String? _resolvePubspecPath(String? explicit) {
    if (explicit != null) {
      final file = File(explicit);
      if (file.existsSync()) return p.canonicalize(file.path);
      // Allow passing a directory — look for pubspec.yaml inside it.
      final inDir = File(p.join(explicit, 'pubspec.yaml'));
      if (inDir.existsSync()) return p.canonicalize(inDir.path);
      return null;
    }

    final defaultPath = p.join(Directory.current.path, 'pubspec.yaml');
    if (File(defaultPath).existsSync()) return p.canonicalize(defaultPath);
    return null;
  }

  /// Resolve the registry YAML path.
  ///
  /// If not provided explicitly, walk up from the pubspec's parent directory
  /// looking for `configs/external_workspace_packages.yaml` — the standard
  /// monorepo root detection pattern.
  String? _resolveRegistryPath({required String? explicit, required String pubspecPath}) {
    if (explicit != null) {
      final file = File(explicit);
      if (file.existsSync()) return p.canonicalize(file.path);
      return null;
    }

    // Auto-detect: walk up from pubspec's directory.
    var current = Directory(p.dirname(pubspecPath));
    while (true) {
      final candidate = File(p.join(current.path, 'configs', 'external_workspace_packages.yaml'));
      if (candidate.existsSync()) return p.canonicalize(candidate.path);

      final parent = current.parent;
      if (parent.path == current.path) break; // Reached filesystem root.
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

  /// Print findings grouped by severity using appropriate Logger methods.
  void _printFindings(List<AuditFinding> findings, {required bool verbose}) {
    final errors = findings.where((f) => f.severity == AuditSeverity.error).toList();
    final warnings = findings.where((f) => f.severity == AuditSeverity.warning).toList();
    final infos = findings.where((f) => f.severity == AuditSeverity.info).toList();

    Logger.info('');

    if (errors.isNotEmpty) {
      Logger.error('  ERRORS (${errors.length}):');
      for (final finding in errors) {
        _printFinding(finding, verbose: verbose, printer: Logger.error);
      }
    }

    if (warnings.isNotEmpty) {
      Logger.warn('  WARNINGS (${warnings.length}):');
      for (final finding in warnings) {
        _printFinding(finding, verbose: verbose, printer: Logger.warn);
      }
    }

    if (infos.isNotEmpty) {
      Logger.info('  INFO (${infos.length}):');
      for (final finding in infos) {
        _printFinding(finding, verbose: verbose, printer: Logger.info);
      }
    }

    // Summary line.
    final parts = <String>[];
    if (errors.isNotEmpty) parts.add('${errors.length} error(s)');
    if (warnings.isNotEmpty) parts.add('${warnings.length} warning(s)');
    if (infos.isNotEmpty) parts.add('${infos.length} info');

    final pubspecPath = findings.isNotEmpty ? findings.first.pubspecPath : 'pubspec.yaml';

    Logger.info('');
    Logger.info('  Summary: ${parts.join(', ')} in $pubspecPath');
  }

  /// Print a single finding with optional verbose detail.
  void _printFinding(AuditFinding finding, {required bool verbose, required void Function(String) printer}) {
    printer('    ${finding.dependencyName}: ${finding.message}');
    if (finding.currentValue != null) {
      printer('      Current:  ${finding.currentValue}');
    }
    if (finding.expectedValue != null) {
      printer('      Expected: ${finding.expectedValue}');
    }
    if (verbose) {
      printer('      Category: ${finding.category.name}');
      printer('      File:     ${finding.pubspecPath}');
    }
    printer('');
  }
}
