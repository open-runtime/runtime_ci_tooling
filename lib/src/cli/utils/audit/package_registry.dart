import 'dart:io';

import 'package:yaml/yaml.dart';

import '../logger.dart';

/// A single entry from the external workspace packages registry.
///
/// Each entry describes a git-sourced dependency with enough information to
/// fully validate and reconstruct its pubspec declaration.
class RegistryEntry {
  /// GitHub organization or user (e.g., `open-runtime`, `pieces-app`).
  final String githubOrg;

  /// GitHub repository name (e.g., `encrypt`, `grpc-dart`).
  final String githubRepo;

  /// Version constraint string (e.g., `^6.0.0`).
  final String version;

  /// Git tag pattern for releases (e.g., `v{{version}}`).
  final String tagPattern;

  /// Local clone path relative to the monorepo root.
  final String localPath;

  /// The Dart package name if it differs from the YAML key.
  ///
  /// For example, the key `named_locks` has `package_name: runtime_named_locks`.
  /// When [packageName] is non-null, the dependency in pubspec.yaml uses this
  /// name rather than the registry key.
  final String? packageName;

  /// Path inside the git repo for multi-package repositories.
  ///
  /// When present, the git dep should include `path:` in the git block.
  /// For example, `custom_lint` lives at `packages/custom_lint` inside the
  /// `dart_custom_lint` repo.
  final String? gitPath;

  const RegistryEntry({
    required this.githubOrg,
    required this.githubRepo,
    required this.version,
    required this.tagPattern,
    required this.localPath,
    this.packageName,
    this.gitPath,
  });

  /// The expected SSH git URL for this package.
  String get expectedGitUrl => 'git@github.com:$githubOrg/$githubRepo.git';

  @override
  String toString() => 'RegistryEntry($githubOrg/$githubRepo $version)';
}

/// Loads the external workspace packages YAML and provides O(1) lookup by
/// dependency name.
///
/// The registry is the source of truth for which GitHub org, repo, version,
/// and tag_pattern each git-sourced dependency should use. Any pubspec.yaml
/// can be validated against it.
class PackageRegistry {
  /// All entries keyed by the dependency name that appears in pubspec.yaml.
  ///
  /// For most packages the key in the YAML file IS the dependency name. When
  /// a `package_name` override is present, the entry is indexed under BOTH
  /// the YAML key and the `package_name` so that lookups work regardless of
  /// which name a pubspec uses.
  final Map<String, RegistryEntry> _entries;

  PackageRegistry._(this._entries);

  /// Load the registry from an [external_workspace_packages.yaml] file.
  ///
  /// Throws if the file does not exist or cannot be parsed.
  factory PackageRegistry.load(String yamlPath) {
    final result = loadFromFile(yamlPath);
    if (result == null) {
      throw StateError('Failed to load package registry from $yamlPath');
    }
    return result;
  }

  /// Load the registry from an [external_workspace_packages.yaml] file.
  ///
  /// Returns `null` if the file does not exist or cannot be parsed.
  static PackageRegistry? loadFromFile(String yamlPath) {
    final file = File(yamlPath);
    if (!file.existsSync()) {
      Logger.error('Registry file not found: $yamlPath');
      return null;
    }

    final String content;
    try {
      content = file.readAsStringSync();
    } on FileSystemException catch (e) {
      Logger.error('Failed to read registry file: $e');
      return null;
    }

    return loadFromString(content);
  }

  /// Load the registry from a raw YAML string.
  ///
  /// Useful for testing without touching the file system.
  static PackageRegistry? loadFromString(String yamlContent) {
    final YamlMap doc;
    try {
      doc = loadYaml(yamlContent) as YamlMap;
    } on YamlException catch (e) {
      Logger.error('Failed to parse registry YAML: $e');
      return null;
    }

    final packages = doc['packages'] as YamlMap?;
    if (packages == null) {
      Logger.error('Registry YAML missing "packages" key');
      return null;
    }

    final entries = <String, RegistryEntry>{};
    for (final key in packages.keys) {
      final name = key as String;
      final map = packages[name] as YamlMap;

      final githubOrg = map['github_org'] as String?;
      final githubRepo = map['github_repo'] as String?;
      final version = map['version'] as String?;
      final tagPattern = map['tag_pattern'] as String?;
      final localPath = map['local_path'] as String?;

      if (githubOrg == null || githubRepo == null || version == null || tagPattern == null || localPath == null) {
        Logger.warn(
          'Skipping registry entry "$name": missing required fields '
          '(github_org, github_repo, version, tag_pattern, local_path)',
        );
        continue;
      }

      final packageName = map['package_name'] as String?;
      final gitPath = map['git_path'] as String?;

      final entry = RegistryEntry(
        githubOrg: githubOrg,
        githubRepo: githubRepo,
        version: version,
        tagPattern: tagPattern,
        localPath: localPath,
        packageName: packageName,
        gitPath: gitPath,
      );

      // Index under the YAML key (which is what most pubspec deps use).
      entries[name] = entry;

      // If the package has an override name, also index under that so
      // pubspec deps using the Dart package name can find the entry.
      if (packageName != null) {
        entries[packageName] = entry;
      }
    }

    Logger.info('Loaded package registry: ${entries.length} entries');
    return PackageRegistry._(entries);
  }

  /// Look up a registry entry by dependency name.
  ///
  /// Returns `null` when the name is not a registered git-sourced package
  /// (i.e., it's a pub.dev dependency or workspace-internal package).
  RegistryEntry? lookup(String packageName) => _entries[packageName];

  /// All registered dependency names.
  Iterable<String> get names => _entries.keys;

  /// All entries as an unmodifiable map.
  Map<String, RegistryEntry> get entries => Map<String, RegistryEntry>.unmodifiable(_entries);

  /// Total number of unique entries (may be > number of YAML keys when
  /// `package_name` overrides exist).
  int get length => _entries.length;
}
