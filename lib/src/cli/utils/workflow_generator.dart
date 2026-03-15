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
  'web_test',
};

const Set<String> _knownWebTestKeys = {'concurrency', 'paths'};

/// Safe identifier for env vars and GitHub secrets (e.g. API_KEY, GITHUB_TOKEN).
/// Must start with uppercase letter, then uppercase letters, digits, underscores only.
bool _isSafeSecretIdentifier(String s) {
  return RegExp(r'^[A-Z][A-Z0-9_]*$').hasMatch(s);
}

/// Runner label must not contain newlines, control chars, or YAML-injection chars.
/// Allows alphanumeric, underscore, hyphen, dot (e.g. ubuntu-latest, runtime-ubuntu-24.04-x64).
bool _isSafeRunnerLabel(String s) {
  if (s.contains(RegExp(r'[\r\n\t\x00-\x1f]'))) return false;
  if (RegExp('[{}:\[\]#@|>&*"\'\\\$]').hasMatch(s)) return false;
  return RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(s);
}

/// GitHub org segment used in git URL rewrites (e.g. open-runtime).
///
/// Keep this conservative: no slashes, no whitespace, no control chars.
bool _isSafeGitOrgSegment(String s) {
  if (s.contains(RegExp(r'[\r\n\t\x00-\x1f]'))) return false;
  return RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(s);
}

/// Sub-package names are rendered into YAML and shell-facing messages.
/// Keep them to a conservative character set.
bool _isSafeSubPackageName(String s) {
  if (s.contains(RegExp(r'[\r\n\t\x00-\x1f]'))) return false;
  return RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(s);
}

/// Resolves shared step partials for CI workflow generation.
/// Partials live in templates/github/workflows/partials/ and eliminate
/// duplicated step definitions across jobs (single_platform, multi_platform, web_test).
Template? _resolvePartial(String name) {
  final path = TemplateResolver.resolveTemplatePath('github/workflows/partials/$name.mustache');
  final file = File(path);
  if (!file.existsSync()) return null;
  final source = file.readAsStringSync();
  return Template(source, htmlEscapeValues: false, name: 'partial:$name');
}

/// Renders CI workflow YAML from a Mustache skeleton template and config.json.
///
/// The skeleton uses `<% %>` delimiters (set via `{{=<% %>=}}` at the top)
/// to avoid conflict with GitHub Actions' `${{ }}` syntax.
///
/// Shared step blocks are defined once in partials/ and included via
/// `{{> partial_name}}` to avoid duplication.
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

  /// Validates a single sub-package entry. Returns null if valid, otherwise error message.
  /// Mutates [seenNames] and [seenPaths] only when valid. Used by [SubPackageUtils.loadSubPackages].
  static String? validateSubPackageEntry(Map<String, dynamic> sp, Set<String> seenNames, Set<String> seenPaths) {
    final name = sp['name'];
    final pathValue = sp['path'];

    if (name is! String || name.trim().isEmpty) return 'name must be a non-empty string';
    if (name != name.trim()) return 'name must not have leading/trailing whitespace';
    if (!_isSafeSubPackageName(name)) return 'name contains unsupported characters: "$name"';

    if (pathValue is! String || pathValue.trim().isEmpty) return 'path must be a non-empty string';
    if (pathValue != pathValue.trim()) return 'path must not have leading/trailing whitespace';
    if (pathValue.contains(RegExp(r'[\r\n\t]'))) return 'path must not contain newlines/tabs';
    if (p.isAbsolute(pathValue) || pathValue.startsWith('~')) {
      return 'path must be a relative repo path';
    }
    if (pathValue.contains('\\')) return 'path must use forward slashes (/)';
    final normalized = p.posix.normalize(pathValue);
    if (normalized.startsWith('..') || normalized.contains('/../')) {
      return 'path must not traverse outside the repo';
    }
    if (normalized == '.') return 'path must not be repo root (".")';
    if (normalized.startsWith('-')) {
      return 'path must not start with "-" (reserved for CLI options)';
    }
    if (RegExp(r'[^A-Za-z0-9_./-]').hasMatch(pathValue)) {
      return 'path contains unsupported characters: "$pathValue"';
    }
    if (!seenNames.add(name)) return 'duplicate name "$name"';
    if (!seenPaths.add(normalized)) return 'duplicate path "$normalized"';
    return null;
  }

  /// Returns the web_test config map if present and valid; otherwise null.
  static Map<String, dynamic>? _getWebTestConfig(Map<String, dynamic> ciConfig) {
    final raw = ciConfig['web_test'];
    return raw is Map<String, dynamic> ? raw : null;
  }

  /// Load the full config.json from a repo's `.runtime_ci/` directory.
  ///
  /// Returns null if the config.json doesn't exist.
  /// Throws [StateError] if the file exists but contains malformed JSON.
  static Map<String, dynamic>? loadFullConfig(String repoRoot) {
    final configPath = '$repoRoot/.runtime_ci/config.json';
    final file = File(configPath);
    if (!file.existsSync()) return null;
    try {
      return json.decode(file.readAsStringSync()) as Map<String, dynamic>;
    } on FormatException catch (e) {
      throw StateError('Malformed JSON in $configPath: $e');
    }
  }

  /// Load the CI config section from a repo's config.json.
  ///
  /// Returns null if the config.json doesn't exist or has no `ci` section.
  /// Throws [StateError] if the file exists but contains malformed JSON.
  static Map<String, dynamic>? loadCiConfig(String repoRoot) {
    final fullConfig = loadFullConfig(repoRoot);
    if (fullConfig == null) return null;
    final ci = fullConfig['ci'];
    if (ci == null) return null;
    if (ci is! Map<String, dynamic>) {
      final configPath = '$repoRoot/.runtime_ci/config.json';
      throw StateError('Expected "ci" in $configPath to be an object, got ${ci.runtimeType}');
    }
    return ci;
  }

  /// Render the CI workflow from the skeleton template.
  ///
  /// If [existingContent] is provided, user sections are preserved from it.
  ///
  /// Throws [StateError] if the config is invalid. Always validates before
  /// rendering to prevent interpolation of unsafe values into shell commands.
  String render({String? existingContent}) {
    final errors = validate(ciConfig);
    if (errors.isNotEmpty) {
      throw StateError('Cannot render with invalid config:\n  ${errors.join('\n  ')}');
    }

    final skeletonPath = TemplateResolver.resolveTemplatePath('github/workflows/ci.skeleton.yaml');
    final skeletonFile = File(skeletonPath);
    if (!skeletonFile.existsSync()) {
      throw StateError('CI skeleton template not found at $skeletonPath');
    }

    final skeleton = skeletonFile.readAsStringSync();
    final context = _buildContext();
    final template = Template(skeleton, htmlEscapeValues: false, partialResolver: _resolvePartial);
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
    final gitOrgs = _resolveGitOrgs(ciConfig);

    // Language detection — defaults to 'dart' for backward compatibility.
    final language = (ciConfig['language'] as String?)?.trim().toLowerCase() ?? 'dart';
    final isDart = language == 'dart' || language == 'flutter';
    final isTypescript = language == 'typescript';
    final isFlutter = language == 'flutter';
    final nodeVersion = ciConfig['typescript'] is Map<String, dynamic>
        ? ((ciConfig['typescript'] as Map<String, dynamic>)['node_version']?.toString() ?? '22')
        : '22';

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
      'dart_sdk': isDart ? ciConfig['dart_sdk'] as String : '',
      'line_length': _resolveLineLength(ciConfig['line_length']),
      'pat_secret': ciConfig['personal_access_token_secret'] as String? ?? 'GITHUB_TOKEN',

      // Artifact retention defaults to 7 days unless explicitly configured.
      'artifact_retention_days': _resolveArtifactRetentionDays(ciConfig['artifact_retention_days']),

      // Language flags
      'is_dart': isDart,
      'is_typescript': isTypescript,
      'is_flutter': isFlutter,
      'node_version': nodeVersion,

      // Feature flags
      'proto': features['proto'] == true,
      'lfs': features['lfs'] == true,
      'format_check': features['format_check'] == true,
      'analysis_cache': features['analysis_cache'] == true,
      'managed_analyze': features['managed_analyze'] == true,
      'managed_test': features['managed_test'] == true,
      'build_runner': features['build_runner'] == true,
      'web_test': features['web_test'] == true,

      // Web test config (only computed when web_test is true)
      'web_test_concurrency': features['web_test'] == true ? _resolveWebTestConcurrency(ciConfig) : '1',
      'web_test_paths': features['web_test'] == true ? _resolveWebTestPaths(ciConfig) : '',
      'web_test_has_paths': features['web_test'] == true && _resolveWebTestHasPaths(ciConfig),

      // Secrets / env
      'has_secrets': secretsList.isNotEmpty,
      'secrets_list': secretsList,
      'git_orgs': gitOrgs.map((org) => {'org': org}).toList(),

      // Sub-packages (filter out invalid entries)
      'sub_packages': subPackages
          .whereType<Map<String, dynamic>>()
          .where((sp) => sp['name'] != null && sp['path'] != null)
          .map((sp) => {'name': (sp['name'] as String).trim(), 'path': (sp['path'] as String).trim()})
          .toList(),

      // Platform support
      'multi_platform': isMultiPlatform,
      'single_platform': !isMultiPlatform,
      'runner': isMultiPlatform ? '' : resolveRunner(platforms.first),
      'single_platform_id': isMultiPlatform ? '' : platforms.first,
      'platform_matrix_json': json.encode(platformMatrix),
    };
  }

  static String _resolveWebTestConcurrency(Map<String, dynamic> ciConfig) {
    final webTestConfig = _getWebTestConfig(ciConfig);
    if (webTestConfig != null) {
      final concurrency = webTestConfig['concurrency'];
      if (concurrency is int && concurrency > 0 && concurrency <= 32) {
        return '$concurrency';
      }
    }
    return '1';
  }

  static String _resolveLineLength(dynamic raw) {
    if (raw is int) return '$raw';
    if (raw is String) {
      final parsed = int.tryParse(raw.trim());
      if (parsed != null) return '$parsed';
    }
    return '120';
  }

  static List<String> _resolveGitOrgs(Map<String, dynamic> ciConfig) {
    final raw = ciConfig['git_orgs'];
    final resolved = <String>[];
    if (raw is List) {
      for (final value in raw) {
        if (value is! String) continue;
        final org = value.trim();
        if (org.isEmpty) continue;
        if (!_isSafeGitOrgSegment(org)) continue;
        if (resolved.contains(org)) continue;
        resolved.add(org);
      }
    }
    if (resolved.isEmpty) {
      return const ['open-runtime', 'pieces-app'];
    }
    return resolved;
  }

  static String _resolveArtifactRetentionDays(dynamic raw) {
    if (raw is int && raw >= 1 && raw <= 90) return '$raw';
    if (raw is String) {
      final parsed = int.tryParse(raw.trim());
      if (parsed != null && parsed >= 1 && parsed <= 90) return '$parsed';
    }
    return '7';
  }

  /// Shared filter: extracts valid, normalized web test paths from config.
  static List<String> _filteredWebTestPaths(Map<String, dynamic> ciConfig) {
    final webTestConfig = _getWebTestConfig(ciConfig);
    if (webTestConfig != null) {
      final paths = webTestConfig['paths'];
      if (paths is List && paths.isNotEmpty) {
        return paths.whereType<String>().where((s) => s.trim().isNotEmpty).map((s) => p.posix.normalize(s)).toList();
      }
    }
    return const [];
  }

  static String _resolveWebTestPaths(Map<String, dynamic> ciConfig) {
    final filtered = _filteredWebTestPaths(ciConfig);
    if (filtered.isEmpty) return '';
    // Shell-quote each path for defense-in-depth (validation already blocks
    // dangerous characters, but quoting prevents breakage from future changes).
    return filtered.map(_shellQuote).join(' ');
  }

  static String _shellQuote(String value) {
    return "'${value.replaceAll("'", "'\"'\"'")}'";
  }

  static bool _resolveWebTestHasPaths(Map<String, dynamic> ciConfig) {
    return _filteredWebTestPaths(ciConfig).isNotEmpty;
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

    // Language validation
    final languageRaw = ciConfig['language'];
    const validLanguages = {'dart', 'flutter', 'typescript'};
    String language = 'dart';
    if (languageRaw != null) {
      if (languageRaw is! String) {
        errors.add('ci.language must be a string, got ${languageRaw.runtimeType}');
      } else {
        language = languageRaw.trim().toLowerCase();
        if (!validLanguages.contains(language)) {
          errors.add('ci.language must be one of ${validLanguages.join(', ')}, got "$languageRaw"');
          language = 'dart'; // Fall back to dart for remaining validation
        }
      }
    }
    final isDartLanguage = language == 'dart' || language == 'flutter';
    final isTypescriptLanguage = language == 'typescript';

    // dart_sdk is required for Dart/Flutter, not for TypeScript
    final sdk = ciConfig['dart_sdk'];
    if (isDartLanguage) {
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
    }

    // TypeScript-specific validation
    if (isTypescriptLanguage) {
      final tsConfig = ciConfig['typescript'];
      if (tsConfig != null && tsConfig is! Map<String, dynamic>) {
        errors.add('ci.typescript must be an object, got ${tsConfig.runtimeType}');
      } else if (tsConfig is Map<String, dynamic>) {
        final nodeVersion = tsConfig['node_version'];
        if (nodeVersion != null && nodeVersion is! String && nodeVersion is! int) {
          errors.add('ci.typescript.node_version must be a string or int, got ${nodeVersion.runtimeType}');
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
    } else if (secrets is Map) {
      for (final entry in secrets.entries) {
        final key = entry.key;
        final value = entry.value;
        if (key is! String) {
          errors.add('ci.secrets keys must be strings, got ${key.runtimeType}');
          continue;
        }
        if (!_isSafeSecretIdentifier(key)) {
          errors.add('ci.secrets key "$key" must be a safe identifier (e.g. API_KEY, GITHUB_TOKEN)');
        }
        if (value is String) {
          if (!_isSafeSecretIdentifier(value)) {
            errors.add('ci.secrets["$key"] value "$value" must be a safe secret name (e.g. MY_SECRET)');
          }
        }
      }
    }
    final pat = ciConfig['personal_access_token_secret'];
    if (pat != null && (pat is! String || pat.isEmpty)) {
      errors.add('ci.personal_access_token_secret must be a non-empty string');
    } else if (pat is String && !_isSafeSecretIdentifier(pat)) {
      errors.add('ci.personal_access_token_secret "$pat" must be a safe identifier (e.g. GITHUB_TOKEN)');
    }
    final gitOrgs = ciConfig['git_orgs'];
    if (gitOrgs != null) {
      if (gitOrgs is! List) {
        errors.add('ci.git_orgs must be an array, got ${gitOrgs.runtimeType}');
      } else if (gitOrgs.isEmpty) {
        errors.add('ci.git_orgs must not be empty when provided');
      } else {
        final seen = <String>{};
        for (var i = 0; i < gitOrgs.length; i++) {
          final org = gitOrgs[i];
          if (org is! String || org.trim().isEmpty) {
            errors.add('ci.git_orgs[$i] must be a non-empty string');
            continue;
          }
          if (org != org.trim()) {
            errors.add('ci.git_orgs[$i] must not have leading/trailing whitespace');
            continue;
          }
          if (!_isSafeGitOrgSegment(org)) {
            errors.add('ci.git_orgs[$i] contains unsupported characters: "$org"');
            continue;
          }
          if (!seen.add(org)) {
            errors.add('ci.git_orgs contains duplicate org "$org"');
          }
        }
      }
    }
    final lineLength = ciConfig['line_length'];
    if (lineLength != null && lineLength is! int && lineLength is! String) {
      errors.add('ci.line_length must be a number or string, got ${lineLength.runtimeType}');
    } else if (lineLength is int) {
      if (lineLength < 1 || lineLength > 10000) {
        errors.add('ci.line_length must be between 1 and 10000, got $lineLength');
      }
    } else if (lineLength is String) {
      final trimmed = lineLength.trim();
      if (trimmed.isEmpty) {
        errors.add('ci.line_length string must not be empty or whitespace-only');
      } else if (trimmed != lineLength) {
        errors.add('ci.line_length must not have leading/trailing whitespace');
      } else if (lineLength.contains(RegExp(r'[\r\n\t\x00-\x1f]'))) {
        errors.add('ci.line_length must not contain newlines or control characters');
      } else if (!RegExp(r'^\d+$').hasMatch(lineLength)) {
        errors.add('ci.line_length string must be digits only (e.g. 120), got "$lineLength"');
      } else {
        final parsed = int.parse(lineLength);
        if (parsed < 1 || parsed > 10000) {
          errors.add('ci.line_length must be between 1 and 10000, got $lineLength');
        }
      }
    }
    final artifactRetention = ciConfig['artifact_retention_days'];
    if (artifactRetention != null && artifactRetention is! int && artifactRetention is! String) {
      errors.add('ci.artifact_retention_days must be a number or string, got ${artifactRetention.runtimeType}');
    } else if (artifactRetention is int) {
      if (artifactRetention < 1 || artifactRetention > 90) {
        errors.add('ci.artifact_retention_days must be between 1 and 90, got $artifactRetention');
      }
    } else if (artifactRetention is String) {
      final trimmed = artifactRetention.trim();
      if (trimmed.isEmpty) {
        errors.add('ci.artifact_retention_days string must not be empty or whitespace-only');
      } else if (trimmed != artifactRetention) {
        errors.add('ci.artifact_retention_days must not have leading/trailing whitespace');
      } else if (artifactRetention.contains(RegExp(r'[\r\n\t\x00-\x1f]'))) {
        errors.add('ci.artifact_retention_days must not contain newlines or control characters');
      } else if (!RegExp(r'^\d+$').hasMatch(artifactRetention)) {
        errors.add('ci.artifact_retention_days string must be digits only (e.g. 7), got "$artifactRetention"');
      } else {
        final parsed = int.parse(artifactRetention);
        if (parsed < 1 || parsed > 90) {
          errors.add('ci.artifact_retention_days must be between 1 and 90, got $artifactRetention');
        }
      }
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
          } else if (name != name.trim()) {
            errors.add('ci.sub_packages[].name must not have leading/trailing whitespace');
          } else if (!_isSafeSubPackageName(name)) {
            errors.add('ci.sub_packages[].name contains unsupported characters: "$name"');
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
          if (normalized == '.') {
            errors.add('ci.sub_packages["${name is String ? name : '?'}"].path must not be repo root (".")');
            continue;
          }
          if (normalized.startsWith('-')) {
            errors.add(
              'ci.sub_packages["${name is String ? name : '?'}"].path must not start with "-" (reserved for CLI options)',
            );
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
          } else if (value != value.trim()) {
            errors.add('ci.runner_overrides["$key"] must not have leading/trailing whitespace');
          } else if (!_isSafeRunnerLabel(value.trim())) {
            errors.add('ci.runner_overrides["$key"] must not contain newlines, control chars, or unsafe YAML chars');
          }
        }
      }
    }

    final webTestConfig = ciConfig['web_test'];
    if (webTestConfig != null) {
      if (webTestConfig is! Map) {
        errors.add('ci.web_test must be an object, got ${webTestConfig.runtimeType}');
      } else {
        // Detect unknown keys inside web_test config
        for (final key in webTestConfig.keys) {
          if (key is String && !_knownWebTestKeys.contains(key)) {
            errors.add('ci.web_test contains unknown key "$key" (typo?)');
          }
        }

        final concurrency = webTestConfig['concurrency'];
        if (concurrency != null) {
          if (concurrency is! int) {
            errors.add('ci.web_test.concurrency must be an integer, got ${concurrency.runtimeType}');
          } else if (concurrency < 1 || concurrency > 32) {
            errors.add('ci.web_test.concurrency must be between 1 and 32, got $concurrency');
          }
        }

        final paths = webTestConfig['paths'];
        if (paths != null) {
          if (paths is! List) {
            errors.add('ci.web_test.paths must be an array, got ${paths.runtimeType}');
          } else {
            final seenPaths = <String>{};
            for (var i = 0; i < paths.length; i++) {
              final pathValue = paths[i];
              if (pathValue is! String || pathValue.trim().isEmpty) {
                errors.add('ci.web_test.paths[$i] must be a non-empty string');
                continue;
              }
              if (pathValue != pathValue.trim()) {
                errors.add('ci.web_test.paths[$i] must not have leading/trailing whitespace');
                continue;
              }
              if (pathValue.contains(RegExp(r'[\r\n\t]'))) {
                errors.add('ci.web_test.paths[$i] must not contain newlines/tabs');
                continue;
              }
              if (p.isAbsolute(pathValue) || pathValue.startsWith('~')) {
                errors.add('ci.web_test.paths[$i] must be a relative repo path');
                continue;
              }
              if (pathValue.contains('\\')) {
                errors.add('ci.web_test.paths[$i] must use forward slashes (/)');
                continue;
              }
              final normalized = p.posix.normalize(pathValue);
              if (normalized.startsWith('..') || normalized.contains('/../')) {
                errors.add('ci.web_test.paths[$i] must not traverse outside the repo');
                continue;
              }
              if (normalized == '.') {
                errors.add('ci.web_test.paths[$i] must not be repo root (".")');
                continue;
              }
              if (normalized.startsWith('-')) {
                errors.add('ci.web_test.paths[$i] must not start with "-" (reserved for CLI options)');
                continue;
              }
              if (RegExp(r'[^A-Za-z0-9_./-]').hasMatch(pathValue)) {
                errors.add('ci.web_test.paths[$i] contains unsupported characters: "$pathValue"');
                continue;
              }
              if (!seenPaths.add(normalized)) {
                errors.add('ci.web_test.paths contains duplicate path "$normalized"');
              }
            }
          }
        }
      }
    }

    // Cross-validate: both mismatch directions
    // Direction 1: config present but feature disabled (below)
    // Direction 2: feature enabled but config wrong type — handled by web_test block above
    if (features is Map) {
      final webTestEnabled = features['web_test'] == true;
      if (!webTestEnabled && webTestConfig is Map && webTestConfig.isNotEmpty) {
        errors.add('ci.web_test config is present but ci.features.web_test is not enabled (dead config?)');
      }
    }

    return errors;
  }

  /// Log a summary of what will be generated.
  void logConfig() {
    final features = ciConfig['features'] as Map<String, dynamic>? ?? {};
    final secrets = ciConfig['secrets'] as Map<String, dynamic>? ?? {};
    final subPackages = ciConfig['sub_packages'] as List? ?? [];

    final language = (ciConfig['language'] as String?)?.trim().toLowerCase() ?? 'dart';
    final platforms = ciConfig['platforms'] as List? ?? ['ubuntu'];

    Logger.info('  Language: $language');
    if (language == 'dart' || language == 'flutter') {
      Logger.info('  Dart SDK: ${ciConfig['dart_sdk']}');
    }
    if (language == 'typescript') {
      final tsConfig = ciConfig['typescript'] is Map<String, dynamic>
          ? ciConfig['typescript'] as Map<String, dynamic>
          : <String, dynamic>{};
      Logger.info('  Node version: ${tsConfig['node_version'] ?? '22'}');
    }
    Logger.info('  PAT secret: ${ciConfig['personal_access_token_secret']}');
    Logger.info('  Platforms: ${platforms.join(', ')}');
    Logger.info('  Artifact retention days: ${_resolveArtifactRetentionDays(ciConfig['artifact_retention_days'])}');

    final enabledFeatures = features.entries.where((e) => e.value == true).map((e) => e.key).toList();
    if (enabledFeatures.isNotEmpty) {
      Logger.info('  Features: ${enabledFeatures.join(', ')}');
    } else {
      Logger.info('  Features: (none)');
    }

    if (features['web_test'] == true) {
      final wtConfig = ciConfig['web_test'];
      final wtMap = wtConfig is Map<String, dynamic> ? wtConfig : <String, dynamic>{};
      final concurrency = wtMap['concurrency'] is int ? wtMap['concurrency'] : 1;
      final webPaths = wtMap['paths'] is List ? wtMap['paths'] as List : [];
      Logger.info('  Web test: concurrency=$concurrency, paths=${webPaths.isEmpty ? "(all)" : webPaths.join(", ")}');
    }

    if (secrets.isNotEmpty) {
      Logger.info('  Secrets: ${secrets.length} env var(s)');
    }
    if (subPackages.isNotEmpty) {
      Logger.info('  Sub-packages: ${subPackages.length}');
    }
  }
}
