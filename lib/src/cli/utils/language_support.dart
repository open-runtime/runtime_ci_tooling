/// Language abstraction layer for multi-language CI toolchain operations.
///
/// Each language (Dart, Flutter, TypeScript) implements [LanguageSupport] to
/// provide the correct commands for test, analyze, format, dependency install,
/// code generation, and CI setup actions. This allows the rest of the tooling
/// to be language-agnostic while still producing correct shell commands and
/// GitHub Actions workflow fragments.
///
/// Use [resolveLanguage] or [resolveLanguageFromConfig] to obtain the
/// appropriate implementation.

/// Abstract interface for language-specific toolchain operations.
///
/// Each language (Dart, TypeScript, Flutter, etc.) implements this to provide
/// the correct commands for test, analyze, format, and CI setup.
abstract class LanguageSupport {
  /// Language identifier used in config (e.g., `"dart"`, `"typescript"`, `"flutter"`).
  String get id;

  /// Human-readable display name (e.g., `"Dart"`, `"TypeScript"`, `"Flutter"`).
  String get displayName;

  /// Package manifest filename (e.g., `"pubspec.yaml"`, `"package.json"`).
  String get manifestFile;

  /// Command to install dependencies.
  List<String> dependencyInstallCommand();

  /// Command to run the test suite.
  ///
  /// When [ci] is true, the command should produce machine-readable output
  /// (e.g., JSON reporter). [reporter] overrides the default reporter name.
  /// [excludeTags] lists test tags to skip (e.g., `["gcp", "integration"]`).
  List<String> testCommand({bool ci = false, String? reporter, List<String>? excludeTags});

  /// Command to run static analysis.
  ///
  /// When [fatalWarnings] is true, warnings cause a non-zero exit code.
  List<String> analyzeCommand({bool fatalWarnings = false});

  /// Format check command (CI mode -- check only, no write).
  ///
  /// Returns a non-zero exit code if files are not formatted. [lineLength]
  /// overrides the default line length for the formatter.
  List<String> formatCheckCommand({int? lineLength});

  /// Format fix command (auto-format, write changes).
  ///
  /// Reformats all files in-place. [lineLength] overrides the default line
  /// length for the formatter.
  List<String> formatFixCommand({int? lineLength});

  /// GitHub Actions setup action name, version, and inputs.
  ///
  /// [config] is the `ci` section of the repo's `config.json`, used to
  /// extract SDK version and other language-specific settings.
  ({String action, String version, Map<String, String> inputs}) ciSetupAction(Map<String, dynamic> config);

  /// Additional CI setup steps required before the main setup action.
  ///
  /// For example, TypeScript needs `pnpm/action-setup` before `actions/setup-node`.
  /// Returns an empty list if no additional steps are needed.
  List<({String action, String? version, Map<String, String> inputs})> ciAdditionalSetupActions(
    Map<String, dynamic> config,
  );

  /// Absolute cache paths for CI dependency caching.
  ///
  /// These are passed to `actions/cache` as `path:` entries.
  List<String> ciCachePaths();

  /// Glob patterns for files that should be hashed to form the CI cache key.
  ///
  /// For example, `**/pubspec.lock` for Dart or `**/pnpm-lock.yaml` for
  /// TypeScript.
  List<String> ciCacheKeyFiles();

  /// Glob patterns that match source files for this language.
  ///
  /// Used for change detection and file filtering (e.g., `**/*.dart`).
  List<String> filePatterns();

  /// Code generation command, or `null` if this language has no codegen step.
  ///
  /// For Dart, this is `build_runner`. For TypeScript, this is typically `null`.
  List<String>? codegenCommand();

  /// Whether this language has a managed test runner in ci_tooling.
  ///
  /// When `true`, the CI workflow delegates test execution to `manage_cicd test`
  /// rather than invoking the test command directly.
  bool get hasManagedTestRunner;
}

// ── Dart ──────────────────────────────────────────────────────────────────────

/// Language support for pure Dart packages.
///
/// Uses `dart test`, `dart analyze`, `dart format`, and `dart-lang/setup-dart`
/// for CI. Code generation uses `build_runner`.
class DartLanguageSupport implements LanguageSupport {
  @override
  String get id => 'dart';

  @override
  String get displayName => 'Dart';

  @override
  String get manifestFile => 'pubspec.yaml';

  @override
  List<String> dependencyInstallCommand() => ['dart', 'pub', 'get'];

  @override
  List<String> testCommand({bool ci = false, String? reporter, List<String>? excludeTags}) {
    final args = <String>['dart', 'test'];
    if (excludeTags != null && excludeTags.isNotEmpty) {
      args.addAll(['--exclude-tags', excludeTags.join(',')]);
    }
    args.add('--chain-stack-traces');
    if (ci) {
      args.addAll(['--reporter', reporter ?? 'json']);
    } else {
      args.addAll(['--reporter', reporter ?? 'expanded']);
    }
    return args;
  }

  @override
  List<String> analyzeCommand({bool fatalWarnings = false}) => [
    'dart',
    'analyze',
    if (fatalWarnings) '--fatal-warnings' else '--no-fatal-warnings',
  ];

  @override
  List<String> formatCheckCommand({int? lineLength}) => [
    'dart',
    'format',
    '--set-exit-if-changed',
    if (lineLength != null) ...['--line-length', '$lineLength'],
    '.',
  ];

  @override
  List<String> formatFixCommand({int? lineLength}) => [
    'dart',
    'format',
    if (lineLength != null) ...['--line-length', '$lineLength'],
    '.',
  ];

  @override
  ({String action, String version, Map<String, String> inputs}) ciSetupAction(Map<String, dynamic> config) {
    final sdk = _resolveDartSdk(config);
    return (action: 'dart-lang/setup-dart', version: 'v1.7.1', inputs: {'sdk': sdk});
  }

  @override
  List<({String action, String? version, Map<String, String> inputs})> ciAdditionalSetupActions(
    Map<String, dynamic> config,
  ) => const [];

  @override
  List<String> ciCachePaths() => ['~/.pub-cache'];

  @override
  List<String> ciCacheKeyFiles() => ['**/pubspec.lock'];

  @override
  List<String> filePatterns() => ['**/*.dart', '**/pubspec.yaml'];

  @override
  List<String>? codegenCommand() => ['dart', 'run', 'build_runner', 'build', '--delete-conflicting-outputs'];

  @override
  bool get hasManagedTestRunner => true;

  /// Resolve the Dart SDK version from the CI config.
  ///
  /// Checks `ci.dart.sdk` first (new nested format), then falls back to
  /// `ci.dart_sdk` (legacy flat format) for backward compatibility.
  String _resolveDartSdk(Map<String, dynamic> config) {
    // New nested format: ci.dart.sdk
    final dartSection = config['dart'];
    if (dartSection is Map<String, dynamic>) {
      final sdk = dartSection['sdk'];
      if (sdk is String && sdk.trim().isNotEmpty) return sdk.trim();
    }
    // Legacy flat format: ci.dart_sdk
    final legacySdk = config['dart_sdk'];
    if (legacySdk is String && legacySdk.trim().isNotEmpty) {
      return legacySdk.trim();
    }
    return 'stable';
  }
}

// ── Flutter ───────────────────────────────────────────────────────────────────

/// Language support for Flutter packages.
///
/// Extends [DartLanguageSupport] and overrides test, analyze, and CI setup
/// to use `flutter test`, `flutter analyze`, and `subosito/flutter-action`.
/// Format commands remain the same (`dart format`).
class FlutterLanguageSupport extends DartLanguageSupport {
  @override
  String get id => 'flutter';

  @override
  String get displayName => 'Flutter';

  @override
  List<String> dependencyInstallCommand() => ['flutter', 'pub', 'get'];

  @override
  List<String> testCommand({bool ci = false, String? reporter, List<String>? excludeTags}) {
    final args = <String>['flutter', 'test'];
    if (excludeTags != null && excludeTags.isNotEmpty) {
      args.addAll(['--exclude-tags', excludeTags.join(',')]);
    }
    args.add('--chain-stack-traces');
    if (ci) {
      args.addAll(['--reporter', reporter ?? 'json']);
    } else {
      args.addAll(['--reporter', reporter ?? 'expanded']);
    }
    return args;
  }

  @override
  List<String> analyzeCommand({bool fatalWarnings = false}) => [
    'flutter',
    'analyze',
    if (fatalWarnings) '--fatal-warnings' else '--no-fatal-warnings',
  ];

  @override
  ({String action, String version, Map<String, String> inputs}) ciSetupAction(Map<String, dynamic> config) {
    final channel = _resolveFlutterChannel(config);
    return (action: 'subosito/flutter-action', version: 'v2', inputs: {'channel': channel});
  }

  @override
  List<String>? codegenCommand() => ['flutter', 'pub', 'run', 'build_runner', 'build', '--delete-conflicting-outputs'];

  /// Resolve the Flutter channel from the CI config.
  ///
  /// Checks `ci.flutter.channel` first, then falls back to `ci.dart_sdk`
  /// (which often contains a channel name like `"stable"`).
  String _resolveFlutterChannel(Map<String, dynamic> config) {
    final flutterSection = config['flutter'];
    if (flutterSection is Map<String, dynamic>) {
      final channel = flutterSection['channel'];
      if (channel is String && channel.trim().isNotEmpty) {
        return channel.trim();
      }
    }
    // Fall back to dart_sdk if it looks like a channel name
    final dartSdk = config['dart_sdk'];
    if (dartSdk is String) {
      final trimmed = dartSdk.trim();
      if (trimmed == 'stable' || trimmed == 'beta' || trimmed == 'dev') {
        return trimmed;
      }
    }
    return 'stable';
  }
}

// ── TypeScript ────────────────────────────────────────────────────────────────

/// Language support for TypeScript/Node.js packages.
///
/// Uses `pnpm` as the package manager, `vitest` for testing, `tsc` for
/// analysis, and `prettier` for formatting. CI setup uses
/// `actions/setup-node` with `pnpm/action-setup` as a prerequisite.
class TypeScriptLanguageSupport implements LanguageSupport {
  @override
  String get id => 'typescript';

  @override
  String get displayName => 'TypeScript';

  @override
  String get manifestFile => 'package.json';

  @override
  List<String> dependencyInstallCommand() => ['pnpm', 'install', '--frozen-lockfile'];

  @override
  List<String> testCommand({bool ci = false, String? reporter, List<String>? excludeTags}) {
    if (ci) {
      return ['pnpm', 'vitest', 'run', '--reporter', reporter ?? 'json'];
    }
    return ['pnpm', 'test'];
  }

  @override
  List<String> analyzeCommand({bool fatalWarnings = false}) => ['pnpm', 'tsc', '--noEmit'];

  @override
  List<String> formatCheckCommand({int? lineLength}) => ['pnpm', 'prettier', '--check', '.'];

  @override
  List<String> formatFixCommand({int? lineLength}) => ['pnpm', 'prettier', '--write', '.'];

  @override
  ({String action, String version, Map<String, String> inputs}) ciSetupAction(Map<String, dynamic> config) {
    final nodeVersion = _resolveNodeVersion(config);
    return (action: 'actions/setup-node', version: 'v4', inputs: {'node-version': nodeVersion});
  }

  @override
  List<({String action, String? version, Map<String, String> inputs})> ciAdditionalSetupActions(
    Map<String, dynamic> config,
  ) {
    final pnpmVersion = _resolvePnpmVersion(config);
    return [
      (action: 'pnpm/action-setup', version: 'v4', inputs: {if (pnpmVersion != null) 'version': pnpmVersion}),
    ];
  }

  @override
  List<String> ciCachePaths() => ['~/.local/share/pnpm/store'];

  @override
  List<String> ciCacheKeyFiles() => ['**/pnpm-lock.yaml'];

  @override
  List<String> filePatterns() => ['**/*.ts', '**/*.tsx', '**/package.json'];

  @override
  List<String>? codegenCommand() => null;

  @override
  bool get hasManagedTestRunner => false;

  /// Resolve the Node.js version from the CI config.
  ///
  /// Checks `ci.typescript.node_version` for the version string.
  String _resolveNodeVersion(Map<String, dynamic> config) {
    final tsSection = config['typescript'];
    if (tsSection is Map<String, dynamic>) {
      final version = tsSection['node_version'];
      if (version is String && version.trim().isNotEmpty) {
        return version.trim();
      }
    }
    return 'lts/*';
  }

  /// Resolve the pnpm version from the CI config, or `null` to use the default.
  ///
  /// Checks `ci.typescript.pnpm_version`.
  String? _resolvePnpmVersion(Map<String, dynamic> config) {
    final tsSection = config['typescript'];
    if (tsSection is Map<String, dynamic>) {
      final version = tsSection['pnpm_version'];
      if (version is String && version.trim().isNotEmpty) {
        return version.trim();
      }
    }
    return null;
  }
}

// ── Factory ───────────────────────────────────────────────────────────────────

/// Resolve the appropriate [LanguageSupport] from a language identifier string.
///
/// Supported values: `"dart"`, `"flutter"`, `"typescript"`.
///
/// Throws [UnsupportedError] if the language is not recognized.
LanguageSupport resolveLanguage(String language) {
  return switch (language) {
    'dart' => DartLanguageSupport(),
    'flutter' => FlutterLanguageSupport(),
    'typescript' => TypeScriptLanguageSupport(),
    _ => throw UnsupportedError(
      'Unsupported language: $language. '
      'Supported: dart, flutter, typescript',
    ),
  };
}

/// Resolve language from a repo's CI config map.
///
/// Reads `ci.language` and falls back to `"dart"` for backward compatibility
/// with existing Dart-only repos.
LanguageSupport resolveLanguageFromConfig(Map<String, dynamic> config) {
  final language = (config['ci'] as Map<String, dynamic>?)?['language'] as String? ?? 'dart';
  return resolveLanguage(language);
}
