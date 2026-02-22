import 'dart:convert';
import 'dart:io';

import 'package:mustache_template/mustache_template.dart';

import 'logger.dart';
import 'template_resolver.dart';

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

  WorkflowGenerator({
    required this.ciConfig,
    required this.toolingVersion,
  });

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
      throw StateError(
        'Expected "ci" in $configPath to be an object, got ${ci.runtimeType}',
      );
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
        secretsList.add({
          'env_name': entry.key,
          'secret_name': entry.value as String,
        });
      }
    }

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

      // Secrets / env
      'has_secrets': secretsList.isNotEmpty,
      'secrets_list': secretsList,

      // Sub-packages (filter out invalid entries)
      'sub_packages': subPackages
          .whereType<Map<String, dynamic>>()
          .where((sp) => sp['name'] != null && sp['path'] != null)
          .map((sp) => {'name': sp['name'], 'path': sp['path']})
          .toList(),
    };
  }

  /// Extract user sections from the existing file and re-insert them
  /// into the rendered output.
  ///
  /// User sections are delimited by:
  ///   `# --- BEGIN USER: <name> ---`
  ///   `# --- END USER: <name> ---`
  String _preserveUserSections(String rendered, String existing) {
    final sectionPattern = RegExp(
      r'# --- BEGIN USER: (\S+) ---\n(.*?)# --- END USER: \1 ---',
      dotAll: true,
    );

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
    }
    final features = ciConfig['features'];
    if (features == null) {
      errors.add('ci.features is required');
    } else if (features is! Map) {
      errors.add('ci.features must be an object, got ${features.runtimeType}');
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
    return errors;
  }

  /// Log a summary of what will be generated.
  void logConfig() {
    final features = ciConfig['features'] as Map<String, dynamic>? ?? {};
    final secrets = ciConfig['secrets'] as Map<String, dynamic>? ?? {};
    final subPackages = ciConfig['sub_packages'] as List? ?? [];

    Logger.info('  Dart SDK: ${ciConfig['dart_sdk']}');
    Logger.info('  PAT secret: ${ciConfig['personal_access_token_secret']}');

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
