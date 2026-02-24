import 'dart:io';

import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import '../logger.dart';
import 'audit_finding.dart';
import 'package_registry.dart';

/// RegExp matching SSH-format GitHub URLs: `git@github.com:org/repo.git`.
final _sshUrlPattern = RegExp(r'^git@github\.com:([^/]+)/([^/]+)\.git$');

/// RegExp matching HTTPS-format GitHub URLs so we can detect and flag them.
final _httpsUrlPattern = RegExp(r'^https?://github\.com/([^/]+)/([^/]+?)(?:\.git)?$');

bool _constraintsEquivalent(String left, String right) {
  final a = left.trim();
  final b = right.trim();
  if (a == b) return true;
  try {
    final ca = VersionConstraint.parse(a);
    final cb = VersionConstraint.parse(b);
    // Treat equivalent ranges as "matching" even if rendered differently.
    return ca.allowsAll(cb) && cb.allowsAll(ca);
  } catch (_) {
    // Fall back to a whitespace-insensitive compare.
    return a.replaceAll(RegExp(r'\s+'), '') == b.replaceAll(RegExp(r'\s+'), '');
  }
}

/// Audits pubspec.yaml dependency declarations against a [PackageRegistry].
///
/// For every dependency that matches a registry entry, the auditor checks:
///
/// 1. **bare_dependency** -- plain version string with no git source
/// 2. **wrong_org** -- git URL points to wrong GitHub org
/// 3. **wrong_repo** -- git URL points to wrong repo name
/// 4. **missing_tag_pattern** -- no `tag_pattern` in git block
/// 5. **wrong_tag_pattern** -- `tag_pattern` differs from registry
/// 6. **stale_version** -- version constraint differs from registry
/// 7. **wrong_url_format** -- git URL uses HTTPS instead of SSH
///
/// Dependencies that do not appear in the registry (pub.dev, workspace-
/// internal, path deps) are silently skipped.
class PubspecAuditor {
  /// The package registry to validate against.
  final PackageRegistry registry;

  const PubspecAuditor({required this.registry});

  // ---------------------------------------------------------------------------
  // Audit
  // ---------------------------------------------------------------------------

  /// Audit a single pubspec.yaml file and return all findings.
  ///
  /// Returns an empty list when the pubspec is fully compliant.
  List<AuditFinding> auditPubspec(String pubspecPath) {
    final file = File(pubspecPath);
    if (!file.existsSync()) {
      Logger.error('Pubspec not found: $pubspecPath');
      return [
        AuditFinding(
          pubspecPath: pubspecPath,
          dependencyName: '<file>',
          severity: AuditSeverity.error,
          category: AuditCategory.bareDependency,
          message: 'Pubspec file does not exist',
        ),
      ];
    }

    final String content;
    try {
      content = file.readAsStringSync();
    } on FileSystemException catch (e) {
      Logger.error('Failed to read pubspec: $e');
      return [];
    }

    final YamlMap doc;
    try {
      doc = loadYaml(content) as YamlMap;
    } on YamlException catch (e) {
      Logger.error('Failed to parse pubspec YAML at $pubspecPath: $e');
      return [];
    }

    final findings = <AuditFinding>[];

    // Audit both `dependencies` and `dev_dependencies` sections.
    final deps = doc['dependencies'] as YamlMap?;
    if (deps != null) {
      findings.addAll(_auditDependencyMap(pubspecPath, deps));
    }

    final devDeps = doc['dev_dependencies'] as YamlMap?;
    if (devDeps != null) {
      findings.addAll(_auditDependencyMap(pubspecPath, devDeps));
    }

    return findings;
  }

  /// Walk a dependency map and check each entry that exists in the registry.
  List<AuditFinding> _auditDependencyMap(String pubspecPath, YamlMap deps) {
    final findings = <AuditFinding>[];

    for (final key in deps.keys) {
      final name = key as String;
      final entry = registry.lookup(name);
      if (entry == null) continue; // Not a registry package -- skip.

      final value = deps[name];
      findings.addAll(_auditDependency(pubspecPath, name, value, entry));
    }

    return findings;
  }

  /// Audit a single dependency against its registry entry.
  List<AuditFinding> _auditDependency(String pubspecPath, String depName, Object? value, RegistryEntry entry) {
    final findings = <AuditFinding>[];

    // --- Path dependency -- skip entirely (workspace-local override) ---------
    if (value is YamlMap && value.containsKey('path')) {
      return findings;
    }

    // --- Bare dependency (just a version string or `any`) --------------------
    if (value is String) {
      findings.add(
        AuditFinding(
          pubspecPath: pubspecPath,
          dependencyName: depName,
          severity: AuditSeverity.error,
          category: AuditCategory.bareDependency,
          message: 'Bare dependency -- should use git source with tag_pattern',
          currentValue: value,
          expectedValue: entry.expectedGitUrl,
        ),
      );

      // Also flag stale version if the bare constraint doesn't match.
      if (!_constraintsEquivalent(value, entry.version)) {
        findings.add(
          AuditFinding(
            pubspecPath: pubspecPath,
            dependencyName: depName,
            severity: AuditSeverity.warning,
            category: AuditCategory.staleVersion,
            message: 'Version constraint does not match registry',
            currentValue: value,
            expectedValue: entry.version,
          ),
        );
      }

      return findings;
    }

    // --- Null value (workspace member ref, e.g. `runtime_native_io_core:`) ---
    if (value == null) {
      // A null value means the dep relies on workspace resolution or has no
      // constraints at all. We still flag it as bare if it's in the registry.
      findings.add(
        AuditFinding(
          pubspecPath: pubspecPath,
          dependencyName: depName,
          severity: AuditSeverity.error,
          category: AuditCategory.bareDependency,
          message:
              'Empty dependency (no source, no version) -- should use git '
              'source with tag_pattern',
          currentValue: null,
          expectedValue: entry.expectedGitUrl,
        ),
      );
      return findings;
    }

    // --- Map dependency (expected for git deps) ------------------------------
    if (value is! YamlMap) {
      Logger.warn(
        'Unexpected dependency type for "$depName" in $pubspecPath: '
        '${value.runtimeType}',
      );
      return findings;
    }

    final depMap = value;

    // Check for git block.
    final gitBlock = depMap['git'];

    if (gitBlock == null) {
      // Has a map (possibly with `version:` or `sdk:` or `hosted:`) but no
      // `git:` block. If it doesn't have `path:` (already handled above),
      // treat it as bare.
      if (!depMap.containsKey('path')) {
        findings.add(
          AuditFinding(
            pubspecPath: pubspecPath,
            dependencyName: depName,
            severity: AuditSeverity.error,
            category: AuditCategory.bareDependency,
            message:
                'Dependency has no git source -- should use git source '
                'with tag_pattern',
            currentValue: depMap.toString(),
            expectedValue: entry.expectedGitUrl,
          ),
        );
      }
      return findings;
    }

    // The git block can be either a string (shorthand URL) or a YamlMap.
    String? gitUrl;
    String? tagPattern;
    String? ref;

    if (gitBlock is String) {
      gitUrl = gitBlock;
    } else if (gitBlock is YamlMap) {
      gitUrl = gitBlock['url'] as String?;
      tagPattern = gitBlock['tag_pattern'] as String?;
      ref = gitBlock['ref'] as String?;
    }

    // --- Rule 7: wrong_url_format (HTTPS instead of SSH) --------------------
    if (gitUrl != null && !_sshUrlPattern.hasMatch(gitUrl)) {
      findings.add(
        AuditFinding(
          pubspecPath: pubspecPath,
          dependencyName: depName,
          severity: AuditSeverity.error,
          category: AuditCategory.wrongUrlFormat,
          message: 'Git URL is not SSH format',
          currentValue: gitUrl,
          expectedValue: entry.expectedGitUrl,
        ),
      );
    }

    // Parse org/repo from the git URL for org/repo checks.
    final sshMatch = gitUrl != null ? _sshUrlPattern.firstMatch(gitUrl) : null;
    final httpsMatch = gitUrl != null ? _httpsUrlPattern.firstMatch(gitUrl) : null;
    final urlOrg = sshMatch?.group(1) ?? httpsMatch?.group(1);
    final urlRepo = sshMatch?.group(2) ?? httpsMatch?.group(2);

    // --- Rule 2: wrong_org ---------------------------------------------------
    if (urlOrg != null && urlOrg != entry.githubOrg) {
      findings.add(
        AuditFinding(
          pubspecPath: pubspecPath,
          dependencyName: depName,
          severity: AuditSeverity.error,
          category: AuditCategory.wrongOrg,
          message: 'Git URL org does not match registry',
          currentValue: urlOrg,
          expectedValue: entry.githubOrg,
        ),
      );
    }

    // --- Rule 3: wrong_repo --------------------------------------------------
    if (urlRepo != null && urlRepo != entry.githubRepo) {
      // Strip trailing `.git` from parsed HTTPS repos for comparison.
      final cleanedRepo = urlRepo.replaceAll(RegExp(r'\.git$'), '');
      if (cleanedRepo != entry.githubRepo) {
        findings.add(
          AuditFinding(
            pubspecPath: pubspecPath,
            dependencyName: depName,
            severity: AuditSeverity.error,
            category: AuditCategory.wrongRepo,
            message: 'Git URL repo does not match registry',
            currentValue: urlRepo,
            expectedValue: entry.githubRepo,
          ),
        );
      }
    }

    // --- Rule 4 & 5: missing/wrong tag_pattern -------------------------------
    if (tagPattern == null) {
      // Legacy format might use `ref` instead of `tag_pattern`.
      if (ref != null) {
        findings.add(
          AuditFinding(
            pubspecPath: pubspecPath,
            dependencyName: depName,
            severity: AuditSeverity.warning,
            category: AuditCategory.missingTagPattern,
            message: 'Git dep uses legacy "ref" instead of "tag_pattern"',
            currentValue: 'ref: $ref',
            expectedValue: 'tag_pattern: ${entry.tagPattern}',
          ),
        );
      } else {
        findings.add(
          AuditFinding(
            pubspecPath: pubspecPath,
            dependencyName: depName,
            severity: AuditSeverity.error,
            category: AuditCategory.missingTagPattern,
            message: 'Git dep is missing "tag_pattern" field',
            currentValue: null,
            expectedValue: entry.tagPattern,
          ),
        );
      }
    } else if (tagPattern != entry.tagPattern) {
      findings.add(
        AuditFinding(
          pubspecPath: pubspecPath,
          dependencyName: depName,
          severity: AuditSeverity.error,
          category: AuditCategory.wrongTagPattern,
          message: 'tag_pattern does not match registry',
          currentValue: tagPattern,
          expectedValue: entry.tagPattern,
        ),
      );
    }

    // --- Rule 6: stale_version -----------------------------------------------
    final versionValue = depMap['version']?.toString();
    if (versionValue != null && !_constraintsEquivalent(versionValue, entry.version)) {
      findings.add(
        AuditFinding(
          pubspecPath: pubspecPath,
          dependencyName: depName,
          severity: AuditSeverity.warning,
          category: AuditCategory.staleVersion,
          message: 'Version constraint does not match registry',
          currentValue: versionValue,
          expectedValue: entry.version,
        ),
      );
    } else if (versionValue == null || versionValue.trim().isEmpty) {
      findings.add(
        AuditFinding(
          pubspecPath: pubspecPath,
          dependencyName: depName,
          severity: AuditSeverity.error,
          category: AuditCategory.staleVersion,
          message:
              'No version constraint specified -- should have version: '
              '${entry.version}',
          currentValue: null,
          expectedValue: entry.version,
        ),
      );
    }

    // NOTE: We do not validate `git_path` presence here because not all
    // pubspecs currently use it for multi-package repos. The fix logic will
    // add it when creating new git dep blocks from bare deps.

    return findings;
  }

  // ---------------------------------------------------------------------------
  // Fix
  // ---------------------------------------------------------------------------

  /// Apply fixes for the given [findings] to the pubspec at [pubspecPath].
  ///
  /// Returns `true` if the file was modified, `false` otherwise.
  ///
  /// The fixer uses [YamlEditor] so comments and formatting are preserved
  /// as much as possible.
  bool fixPubspec(String pubspecPath, List<AuditFinding> findings) {
    if (findings.isEmpty) return false;

    final file = File(pubspecPath);
    if (!file.existsSync()) {
      Logger.error('Cannot fix -- pubspec not found: $pubspecPath');
      return false;
    }

    final original = file.readAsStringSync();
    final editor = YamlEditor(original);

    // Track which deps we've already fully rewritten so we don't try to
    // patch individual fields on top of a wholesale replacement.
    final rewritten = <String>{};

    // Group findings by dependency name for efficient processing.
    final byDep = <String, List<AuditFinding>>{};
    for (final f in findings) {
      byDep.putIfAbsent(f.dependencyName, () => []).add(f);
    }

    // Parse the current doc to determine which section each dep lives in.
    final doc = loadYaml(original) as YamlMap;

    for (final depName in byDep.keys) {
      final depFindings = byDep[depName]!;
      final entry = registry.lookup(depName);
      if (entry == null) continue;

      // Determine the section path (`dependencies` or `dev_dependencies`).
      final sectionKey = _findSectionKey(doc, depName);
      if (sectionKey == null) {
        Logger.warn(
          'Could not locate "$depName" in dependencies or '
          'dev_dependencies of $pubspecPath -- skipping fix',
        );
        continue;
      }

      final categories = depFindings.map((f) => f.category).toSet();

      // If the dep is bare (no git source at all), do a full rewrite.
      if (categories.contains(AuditCategory.bareDependency)) {
        _rewriteToFullGitDep(editor, sectionKey, depName, entry);
        rewritten.add(depName);
        continue;
      }

      // Otherwise, patch individual fields.
      if (rewritten.contains(depName)) continue;

      if (categories.contains(AuditCategory.wrongUrlFormat) ||
          categories.contains(AuditCategory.wrongOrg) ||
          categories.contains(AuditCategory.wrongRepo)) {
        _tryUpdate(editor, [sectionKey, depName, 'git', 'url'], entry.expectedGitUrl);
      }

      if (categories.contains(AuditCategory.missingTagPattern) || categories.contains(AuditCategory.wrongTagPattern)) {
        // If the dep has a legacy `ref` field, remove it first.
        _tryRemove(editor, [sectionKey, depName, 'git', 'ref']);
        _tryUpdate(editor, [sectionKey, depName, 'git', 'tag_pattern'], entry.tagPattern);
      }

      if (categories.contains(AuditCategory.staleVersion)) {
        _tryUpdate(editor, [sectionKey, depName, 'version'], entry.version);
      }
    }

    final updated = editor.toString();
    if (updated == original) return false;

    // Guard against producing an invalid pubspec.yaml.
    try {
      loadYaml(updated);
    } on YamlException catch (e) {
      Logger.error('Refusing to write invalid YAML for $pubspecPath: $e');
      return false;
    }

    _writeBackup(pubspecPath, original);
    file.writeAsStringSync(updated);
    return true;
  }

  void _writeBackup(String pubspecPath, String originalContent) {
    // Keep the backup next to the file so developers can revert quickly.
    // Use a stable name, but avoid overwriting an existing backup.
    final base = '$pubspecPath.runtime_ci_tooling.bak';
    var backupPath = base;
    if (File(base).existsSync()) {
      final ts = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
      backupPath = '$pubspecPath.runtime_ci_tooling.$ts.bak';
    }

    try {
      File(backupPath).writeAsStringSync(originalContent);
      Logger.info('  Backup written: $backupPath');
    } catch (e) {
      Logger.warn('  Could not write backup for $pubspecPath: $e');
    }
  }

  /// Rewrite a dependency to the full git format using registry values.
  void _rewriteToFullGitDep(YamlEditor editor, String sectionKey, String depName, RegistryEntry entry) {
    final gitBlock = <String, Object>{'url': entry.expectedGitUrl, 'tag_pattern': entry.tagPattern};

    // Include `path:` if the registry specifies a git_path (multi-package
    // repos like dart_custom_lint).
    if (entry.gitPath != null) {
      gitBlock['path'] = entry.gitPath!;
    }

    final newValue = <String, Object>{'git': gitBlock, 'version': entry.version};

    _tryUpdate(editor, [sectionKey, depName], newValue);
  }

  /// Safely attempt a [YamlEditor.update]; log and swallow errors.
  void _tryUpdate(YamlEditor editor, List<Object> path, Object value) {
    try {
      editor.update(path, value);
    } on Exception catch (e) {
      Logger.warn('yaml_edit: failed to update $path -- $e');
    }
  }

  /// Safely attempt a [YamlEditor.remove]; log and swallow errors.
  void _tryRemove(YamlEditor editor, List<Object> path) {
    try {
      editor.remove(path);
    } on Exception catch (_) {
      // The key may not exist -- that's fine.
    }
  }

  /// Determine whether [depName] lives under `dependencies` or
  /// `dev_dependencies` in the parsed YAML document.
  String? _findSectionKey(YamlMap doc, String depName) {
    final deps = doc['dependencies'] as YamlMap?;
    if (deps != null && deps.containsKey(depName)) return 'dependencies';

    final devDeps = doc['dev_dependencies'] as YamlMap?;
    if (devDeps != null && devDeps.containsKey(depName)) {
      return 'dev_dependencies';
    }

    return null;
  }
}
