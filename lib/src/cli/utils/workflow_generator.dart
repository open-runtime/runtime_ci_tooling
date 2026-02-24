import 'dart:convert';
import 'dart:io';

import 'package:mustache_template/mustache_template.dart';
import 'package:path/path.dart' as p;

import 'logger.dart';
import 'template_resolver.dart';

class _PlatformDefinition {
  final String osFamily; // linux | macos | windows
  final String arch; // x64 | arm64
  final String runner; // default `runs-on:` label

  const _PlatformDefinition({required this.osFamily, required this.arch, required this.runner});
}

/// Maps platform identifiers to their default runner label + metadata.
///
/// Consumers can override the runner label per platform via:
///   `ci.runner_overrides: { "<platformId>": "<runs-on label>" }`
const _platformDefinitions = <String, _PlatformDefinition>{
  // Linux — org-managed runners
  'ubuntu': _PlatformDefinition(osFamily: 'linux', arch: 'x64', runner: 'runtime-ubuntu-24.04-x64-256gb-64core'),
  'ubuntu-x64': _PlatformDefinition(osFamily: 'linux', arch: 'x64', runner: 'runtime-ubuntu-24.04-x64-256gb-64core'),
  'ubuntu-arm64': _PlatformDefinition(
    osFamily: 'linux',
    arch: 'arm64',
    runner: 'runtime-ubuntu-24.04-arm64-208gb-64core',
  ),

  // macOS — standard GitHub-hosted runners (no org-managed equivalents)
  'macos': _PlatformDefinition(osFamily: 'macos', arch: 'arm64', runner: 'macos-latest'),
  'macos-arm64': _PlatformDefinition(osFamily: 'macos', arch: 'arm64', runner: 'macos-latest'),
  'macos-x64': _PlatformDefinition(osFamily: 'macos', arch: 'x64', runner: 'macos-15-large'),

  // Windows — org-managed runners
  'windows': _PlatformDefinition(osFamily: 'windows', arch: 'x64', runner: 'runtime-windows-2025-x64-256gb-64core'),
  'windows-x64': _PlatformDefinition(osFamily: 'windows', arch: 'x64', runner: 'runtime-windows-2025-x64-256gb-64core'),
  'windows-arm64': _PlatformDefinition(
    osFamily: 'windows',
    arch: 'arm64',
    runner: 'runtime-windows-11-arm64-208gb-64core',
  ),
};

const Set<String> _knownFeatureKeys = {
  'proto',
  'lfs',
  'format_check',
  'analysis_cache',
  'managed_analyze',
  'managed_test',
  'build_runner',
};

/// Renders CI workflow YAML from a Mustache skeleton template and config.json.
///
/// The skeleton uses `<% %>` delimiters (set via `{{=<% %>=}}` at the top)
/// to avoid conflict with GitHub Actions' `${{ }}` syntax.
///
/// User-preservable sections are delimited by:
///   `# --- BEGIN USER: <name> ---`
///   `# --- END USER: <name> ---`
/// and are extracted from the existing deployed file and re-inserted
/// after rendering.
class WorkflowGenerator {
  final Map<String, dynamic> ciConfig;
  final String toolingVersion;

  WorkflowGenerator({required this.ciConfig, required this.toolingVersion});

  /// Load the CI config section from a repo's config.json.
  ///
  /// Returns null if the config.json doesn't exist or has no `ci` section.
  /// Throws [StateError] if the file exists but contains malformed JSON.
  static Map<String, dynamic>? loadCiConfig(String repoRoot) {
    final configPath = '$repoRoot/.runtime_ci/config.json';
    final file = File(configPath);
    if (!file.existsSync()) return null;
    final Map<String, dynamic> config;
    try {
      config = json.decode(file.readAsStringSync()) as Map<String, dynamic>;
    } on FormatException catch (e) {
      throw StateError('Malformed JSON in $configPath: $e');
    }
    final ci = config['ci'];
    if (ci == null) return null;
    if (ci is! Map<String, dynamic>) {
      throw StateError('Expected "ci" in $configPath to be an object, got ${ci.runtimeType}');
    }
    return ci;
  }

  /// Render the CI workflow from the skeleton template.
  ///
  /// If [existingContent] is provided, user sections are preserved from it.
  String render({String? existingContent}) {
    final skeletonPath = TemplateResolver.resolveTemplatePath('github/workflows/ci.skeleton.yaml');
    final skeletonFile = File(skeletonPath);
    if (!skeletonFile.existsSync()) {
      throw StateError('CI skeleton template not found at $skeletonPath');
    }

    final skeleton = skeletonFile.readAsStringSync();
    final context = _buildContext();
    final template = Template(skeleton, htmlEscapeValues: false);
    var rendered = template.renderString(context);

    // Re-insert user sections from existing file
    if (existingContent != null) {
      rendered = _preserveUserSections(rendered, existingContent);
    }

    return rendered;
  }

  /// Build the Mustache rendering context from the CI config.
  Map<String, dynamic> _buildContext() {
    final features = ciConfig['features'] as Map<String, dynamic>? ?? {};
    final secretsRaw = ciConfig['secrets'];
    final secrets = secretsRaw is Map<String, dynamic> ? secretsRaw : <String, dynamic>{};
    final subPackages = ciConfig['sub_packages'] as List? ?? [];

    // Build secrets list for env block (skip non-string values)
    final secretsList = <Map<String, String>>[];
    for (final entry in secrets.entries) {
      if (entry.value is String) {
        secretsList.add({'env_name': entry.key, 'secret_name': entry.value as String});
      }
    }

    // Platform support
    final platformsRaw = ciConfig['platforms'] as List? ?? ['ubuntu'];
    final platforms = <String>[];
    for (final p in platformsRaw) {
      if (p is String && _platformDefinitions.containsKey(p)) {
        platforms.add(p);
      }
    }
    if (platforms.isEmpty) platforms.add('ubuntu');
    final isMultiPlatform = platforms.length > 1;

    final runnerOverridesRaw = ciConfig['runner_overrides'];
    final runnerOverrides = runnerOverridesRaw is Map<String, dynamic> ? runnerOverridesRaw : <String, dynamic>{};
    String resolveRunner(String platformId) {
      final override = runnerOverrides[platformId];
      if (override is String && override.trim().isNotEmpty) {
        return override.trim();
      }
      return _platformDefinitions[platformId]!.runner;
    }

    // For multi-platform, use a matrix.include list of objects. This allows us to
    // carry architecture metadata and makes cache keys stable across x64/arm64.
    final platformMatrix = platforms.map((platformId) {
      final def = _platformDefinitions[platformId]!;
      return <String, String>{
        'platform_id': platformId,
        'runner': resolveRunner(platformId),
        'os_family': def.osFamily,
        'arch': def.arch,
      };
    }).toList();

    return {
      'tooling_version': toolingVersion,
      'dart_sdk': ciConfig['dart_sdk'] ?? '3.9.2',
      'line_length': '${ciConfig['line_length'] ?? 120}',
      'pat_secret': ciConfig['personal_access_token_secret'] as String? ?? 'GITHUB_TOKEN',

      // Feature flags
      'proto': features['proto'] == true,
      'lfs': features['lfs'] == true,
      'format_check': features['format_check'] == true,
      'analysis_cache': features['analysis_cache'] == true,
      'managed_analyze': features['managed_analyze'] == true,
      'managed_test': features['managed_test'] == true,
      'build_runner': features['build_runner'] == true,

      // Secrets / env
      'has_secrets': secretsList.isNotEmpty,
      'secrets_list': secretsList,

      // Sub-packages (filter out invalid entries)
      'sub_packages': subPackages
          .whereType<Map<String, dynamic>>()
          .where((sp) => sp['name'] != null && sp['path'] != null)
          .map((sp) => {'name': sp['name'], 'path': sp['path']})
          .toList(),

      // Platform support
      'multi_platform': isMultiPlatform,
      'single_platform': !isMultiPlatform,
      'runner': isMultiPlatform ? '' : resolveRunner(platforms.first),
      'platform_matrix_json': json.encode(platformMatrix),
    };
  }

  /// Extract user sections from the existing file and re-insert them
  /// into the rendered output.
  ///
  /// User sections are delimited by:
  ///   `# --- BEGIN USER: <name> ---`
  ///   `# --- END USER: <name> ---`
  String _preserveUserSections(String rendered, String existing) {
    // Normalize CRLF → LF so the regex matches regardless of line-ending style
    // (Windows checkouts with core.autocrlf=true produce \r\n).
    existing = existing.replaceAll('\r\n', '\n');
    rendered = rendered.replaceAll('\r\n', '\n');

    final sectionPattern = RegExp(r'# --- BEGIN USER: (\S+) ---\n(.*?)# --- END USER: \1 ---', dotAll: true);

    // Extract user content from existing file
    final userSections = <String, String>{};
    for (final match in sectionPattern.allMatches(existing)) {
      final name = match.group(1)!;
      final content = match.group(2)!;
      // Only preserve if user actually added content (not just empty)
      if (content.trim().isNotEmpty) {
        userSections[name] = content;
      }
    }

    if (userSections.isEmpty) return rendered;

    // Replace empty user sections in rendered output with preserved content
    var result = rendered;
    for (final entry in userSections.entries) {
      final emptyPattern = '# --- BEGIN USER: ${entry.key} ---\n# --- END USER: ${entry.key} ---';
      final replacement = '# --- BEGIN USER: ${entry.key} ---\n${entry.value}# --- END USER: ${entry.key} ---';
      result = result.replaceFirst(emptyPattern, replacement);
    }

    return result;
  }

  /// Validate that the CI config has all required fields and correct types.
  static List<String> validate(Map<String, dynamic> ciConfig) {
    final errors = <String>[];
    final sdk = ciConfig['dart_sdk'];
    if (sdk == null) {
      errors.add('ci.dart_sdk is required');
    } else if (sdk is! String) {
      errors.add('ci.dart_sdk must be a string, got ${sdk.runtimeType}');
    } else {
      final trimmed = sdk.trim();
      if (trimmed.isEmpty) {
        errors.add('ci.dart_sdk must be a non-empty string');
      } else if (trimmed != sdk) {
        errors.add('ci.dart_sdk must not have leading/trailing whitespace');
      } else if (trimmed.contains(RegExp(r'[\r\n\t]'))) {
        errors.add('ci.dart_sdk must not contain newlines/tabs');
      } else {
        // dart-lang/setup-dart accepts semver versions or channels like stable/beta/dev.
        final isChannel = trimmed == 'stable' || trimmed == 'beta' || trimmed == 'dev';
        final isSemver = RegExp(r'^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$').hasMatch(trimmed);
        if (!isChannel && !isSemver) {
          errors.add('ci.dart_sdk must be a Dart SDK channel (stable|beta|dev) or a version like 3.9.2, got "$sdk"');
        }
      }
    }
    final features = ciConfig['features'];
    if (features == null) {
      errors.add('ci.features is required');
    } else if (features is! Map) {
      errors.add('ci.features must be an object, got ${features.runtimeType}');
    } else {
      for (final entry in features.entries) {
        final key = entry.key;
        final value = entry.value;
        if (key is! String) {
          errors.add('ci.features keys must be strings, got ${key.runtimeType}');
          continue;
        }
        if (!_knownFeatureKeys.contains(key)) {
          errors.add('ci.features contains unknown key "$key" (typo?)');
        }
        if (value is! bool) {
          errors.add('ci.features["$key"] must be a bool, got ${value.runtimeType}');
        }
      }
    }
    final secrets = ciConfig['secrets'];
    if (secrets != null && secrets is! Map) {
      errors.add('ci.secrets must be an object, got ${secrets.runtimeType}');
    }
    final pat = ciConfig['personal_access_token_secret'];
    if (pat != null && (pat is! String || pat.isEmpty)) {
      errors.add('ci.personal_access_token_secret must be a non-empty string');
    }
    final lineLength = ciConfig['line_length'];
    if (lineLength != null && lineLength is! int && lineLength is! String) {
      errors.add('ci.line_length must be a number or string, got ${lineLength.runtimeType}');
    }
    final platforms = ciConfig['platforms'];
    if (platforms != null) {
      if (platforms is! List) {
        errors.add('ci.platforms must be an array, got ${platforms.runtimeType}');
      } else {
        for (final p in platforms) {
          if (p is! String || !_platformDefinitions.containsKey(p)) {
            errors.add(
              'ci.platforms contains invalid platform "$p". '
              'Valid: ${_platformDefinitions.keys.join(', ')}',
            );
          }
        }
      }
    }

    // Validate sub-packages used in generated workflows. These values are rendered
    // into YAML (e.g. working-directory), so disallow traversal/escaping.
    final subPackages = ciConfig['sub_packages'];
    if (subPackages != null) {
      if (subPackages is! List) {
        errors.add('ci.sub_packages must be an array, got ${subPackages.runtimeType}');
      } else {
        final seenNames = <String>{};
        final seenPaths = <String>{};
        for (final sp in subPackages) {
          if (sp is! Map) {
            errors.add('ci.sub_packages entries must be objects, got ${sp.runtimeType}');
            continue;
          }
          final name = sp['name'];
          final pathValue = sp['path'];
          if (name is! String || name.trim().isEmpty) {
            errors.add('ci.sub_packages[].name must be a non-empty string');
          } else if (!seenNames.add(name)) {
            errors.add('ci.sub_packages contains duplicate name "$name"');
          }
          if (pathValue is! String || pathValue.trim().isEmpty) {
            errors.add('ci.sub_packages[].path must be a non-empty string');
            continue;
          }
          if (pathValue != pathValue.trim()) {
            errors.add(
              'ci.sub_packages["${name is String ? name : '?'}"].path must not have leading/trailing whitespace',
            );
            continue;
          }
          if (pathValue.contains(RegExp(r'[\r\n\t]'))) {
            errors.add('ci.sub_packages["${name is String ? name : '?'}"].path must not contain newlines/tabs');
            continue;
          }
          if (p.isAbsolute(pathValue) || pathValue.startsWith('~')) {
            errors.add('ci.sub_packages["${name is String ? name : '?'}"].path must be a relative repo path');
            continue;
          }
          if (pathValue.contains('\\')) {
            errors.add('ci.sub_packages["${name is String ? name : '?'}"].path must use forward slashes (/)');
            continue;
          }
          final normalized = p.posix.normalize(pathValue);
          if (normalized.startsWith('..') || normalized.contains('/../')) {
            errors.add('ci.sub_packages["${name is String ? name : '?'}"].path must not traverse outside the repo');
            continue;
          }
          if (RegExp(r'[^A-Za-z0-9_./-]').hasMatch(pathValue)) {
            errors.add(
              'ci.sub_packages["${name is String ? name : '?'}"].path contains unsupported characters: "$pathValue"',
            );
            continue;
          }
          if (!seenPaths.add(normalized)) {
            errors.add('ci.sub_packages contains duplicate path "$normalized"');
          }
        }
      }
    }

    final runnerOverrides = ciConfig['runner_overrides'];
    if (runnerOverrides != null) {
      if (runnerOverrides is! Map) {
        errors.add('ci.runner_overrides must be an object, got ${runnerOverrides.runtimeType}');
      } else {
        for (final entry in runnerOverrides.entries) {
          final key = entry.key;
          final value = entry.value;
          if (key is! String || !_platformDefinitions.containsKey(key)) {
            errors.add(
              'ci.runner_overrides contains invalid platform key "$key". '
              'Valid: ${_platformDefinitions.keys.join(', ')}',
            );
            continue;
          }
          if (value is! String || value.trim().isEmpty) {
            errors.add('ci.runner_overrides["$key"] must be a non-empty string');
          }
        }
      }
    }
    return errors;
  }

  /// Log a summary of what will be generated.
  void logConfig() {
    final features = ciConfig['features'] as Map<String, dynamic>? ?? {};
    final secrets = ciConfig['secrets'] as Map<String, dynamic>? ?? {};
    final subPackages = ciConfig['sub_packages'] as List? ?? [];

    final platforms = ciConfig['platforms'] as List? ?? ['ubuntu'];

    Logger.info('  Dart SDK: ${ciConfig['dart_sdk']}');
    Logger.info('  PAT secret: ${ciConfig['personal_access_token_secret']}');
    Logger.info('  Platforms: ${platforms.join(', ')}');

    final enabledFeatures = features.entries.where((e) => e.value == true).map((e) => e.key).toList();
    if (enabledFeatures.isNotEmpty) {
      Logger.info('  Features: ${enabledFeatures.join(', ')}');
    } else {
      Logger.info('  Features: (none)');
    }

    if (secrets.isNotEmpty) {
      Logger.info('  Secrets: ${secrets.length} env var(s)');
    }
    if (subPackages.isNotEmpty) {
      Logger.info('  Sub-packages: ${subPackages.length}');
    }
  }
}
