// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

/// Centralized, config-driven loader for the runtime CI tooling pipeline.
///
/// Any repository that places a `.runtime_ci/config.json` file at its root
/// opts into the shared CI/CD infrastructure. The config loader searches
/// upward from CWD for this file, making it work whether scripts are
/// invoked from the repo root or a subdirectory.
///
/// Discovery order (first match wins):
///   1. `.runtime_ci/config.json`           (canonical)
///   2. `runtime.ci.config.json`            (legacy flat-file)
///   3. `scripts/triage/triage_config.json`  (legacy compat)
///   4. `triage_config.json`                (legacy compat)
///
/// Required fields (no hardcoded defaults):
///   - `repository.name`   -- Dart package name / GitHub repo name
///   - `repository.owner`  -- GitHub org or user

// ═══════════════════════════════════════════════════════════════════════════════
// Constants
// ═══════════════════════════════════════════════════════════════════════════════

/// The canonical config file path (relative to repo root).
/// Any repo that has this file is considered to have opted into the runtime CI tooling.
const String kConfigFileName = '.runtime_ci/config.json';

/// Legacy config file names (searched as fallbacks for backward compatibility).
const List<String> kLegacyConfigPaths = [
  'runtime.ci.config.json',
  'scripts/triage/triage_config.json',
  'triage_config.json',
];

// ═══════════════════════════════════════════════════════════════════════════════
// Singleton Config
// ═══════════════════════════════════════════════════════════════════════════════

TriageConfig? _instance;

/// Get the singleton config instance. Loads from disk on first access.
TriageConfig get config {
  _instance ??= TriageConfig.load();
  return _instance!;
}

/// Reload config from disk (useful after modifications).
void reloadConfig() => _instance = TriageConfig.load();

// ═══════════════════════════════════════════════════════════════════════════════
// TriageConfig
// ═══════════════════════════════════════════════════════════════════════════════

class TriageConfig {
  final Map<String, dynamic> _data;

  /// The resolved path to the config file that was loaded (null if defaults).
  final String? loadedFrom;

  TriageConfig._(this._data, {this.loadedFrom});

  /// Load config by searching upward from CWD for `runtime.ci.config.json`
  /// (or legacy fallbacks). Returns an empty config with defaults if no
  /// config file is found.
  factory TriageConfig.load() {
    final configPath = _findConfigFile();
    if (configPath == null) {
      print('Warning: $kConfigFileName not found (searched upward from CWD), using defaults');
      return TriageConfig._({});
    }

    try {
      final content = File(configPath).readAsStringSync();
      final data = json.decode(content) as Map<String, dynamic>;

      // Nudge toward canonical location if loaded from a legacy path
      if (!configPath.endsWith(kConfigFileName)) {
        print('Hint: Move config to $kConfigFileName for the canonical location.');
      }

      return TriageConfig._(data, loadedFrom: configPath);
    } catch (e) {
      print('Warning: Could not parse $configPath: $e');
      return TriageConfig._({});
    }
  }

  /// Whether this repo has opted into the CI tooling by having a config file.
  bool get isConfigured => loadedFrom != null;

  // ═══════════════════════════════════════════════════════════════════════════
  // Repository (REQUIRED -- no hardcoded package-specific defaults)
  // ═══════════════════════════════════════════════════════════════════════════

  String get repoName {
    final name = _str(['repository', 'name'], '');
    if (name.isEmpty) {
      throw StateError(
        'repository.name is required in $kConfigFileName. '
        'See the template at shared/runtime_ci_tooling/templates/$kConfigFileName.',
      );
    }
    return name;
  }

  String get repoOwner {
    final owner = _str(['repository', 'owner'], '');
    if (owner.isEmpty) {
      throw StateError(
        'repository.owner is required in $kConfigFileName. '
        'See the template at shared/runtime_ci_tooling/templates/$kConfigFileName.',
      );
    }
    return owner;
  }

  String get triagedLabel => _str(['repository', 'triaged_label'], 'triaged');
  String get changelogPath => _str(['repository', 'changelog_path'], 'CHANGELOG.md');
  String get releaseNotesPath => _str(['repository', 'release_notes_path'], 'release_notes');

  // ═══════════════════════════════════════════════════════════════════════════
  // GCP
  // ═══════════════════════════════════════════════════════════════════════════

  /// GCP project ID for Secret Manager and other cloud resources.
  /// Read from the per-repo config rather than a secret, since it's
  /// not sensitive and varies per repo.
  String get gcpProject => _str(['gcp', 'project'], '');

  // ═══════════════════════════════════════════════════════════════════════════
  // Sentry
  // ═══════════════════════════════════════════════════════════════════════════

  String get sentryOrganization => _str(['sentry', 'organization'], '');
  List<String> get sentryProjects => _strList(['sentry', 'projects'], []);
  bool get sentryScanOnPreRelease => _bool(['sentry', 'scan_on_pre_release'], true);
  int get sentryRecentErrorsHours => _int(['sentry', 'recent_errors_hours'], 168);

  // ═══════════════════════════════════════════════════════════════════════════
  // Release
  // ═══════════════════════════════════════════════════════════════════════════

  bool get preReleaseScanSentry => _bool(['release', 'pre_release_scan_sentry'], true);
  bool get preReleaseScanGithub => _bool(['release', 'pre_release_scan_github'], true);
  bool get postReleaseCloseOwnRepo => _bool(['release', 'post_release_close_own_repo'], true);
  bool get postReleaseCloseCrossRepo => _bool(['release', 'post_release_close_cross_repo'], false);
  bool get postReleaseCommentCrossRepo => _bool(['release', 'post_release_comment_cross_repo'], true);
  bool get postReleaseLinkSentry => _bool(['release', 'post_release_link_sentry'], true);

  // ═══════════════════════════════════════════════════════════════════════════
  // Cross-Repo
  // ═══════════════════════════════════════════════════════════════════════════

  bool get crossRepoEnabled => _bool(['cross_repo', 'enabled'], true);

  List<CrossRepoEntry> get crossRepoRepos {
    final repos = _list(['cross_repo', 'repos'], <dynamic>[]);
    return repos
        .whereType<Map<String, dynamic>>()
        .map(
          (r) => CrossRepoEntry(
            owner: r['owner'] as String? ?? '',
            repo: r['repo'] as String? ?? '',
            relationship: r['relationship'] as String? ?? 'related',
          ),
        )
        .where((r) => r.owner.isNotEmpty && r.repo.isNotEmpty)
        .toList();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Labels (REQUIRED -- no hardcoded package-specific area labels)
  // ═══════════════════════════════════════════════════════════════════════════

  List<String> get typeLabels =>
      _strList(['labels', 'type'], ['bug', 'feature-request', 'enhancement', 'documentation', 'question']);
  List<String> get priorityLabels =>
      _strList(['labels', 'priority'], ['P0-critical', 'P1-high', 'P2-medium', 'P3-low']);
  List<String> get areaLabels => _strList(['labels', 'area'], []);

  // ═══════════════════════════════════════════════════════════════════════════
  // Thresholds
  // ═══════════════════════════════════════════════════════════════════════════

  double get autoCloseThreshold => _double(['thresholds', 'auto_close'], 0.9);
  double get suggestCloseThreshold => _double(['thresholds', 'suggest_close'], 0.7);
  double get commentThreshold => _double(['thresholds', 'comment'], 0.5);

  // ═══════════════════════════════════════════════════════════════════════════
  // Agents
  // ═══════════════════════════════════════════════════════════════════════════

  List<String> get enabledAgents =>
      _strList(['agents', 'enabled'], ['code_analysis', 'pr_correlation', 'duplicate', 'sentiment', 'changelog']);

  /// Check if a conditional agent should run based on file existence.
  bool shouldRunAgent(String agentName, String repoRoot) {
    if (!enabledAgents.contains(agentName)) return false;

    final conditional = _map(['agents', 'conditional', agentName], null);
    if (conditional == null) return true;

    final requireFile = conditional['require_file'] as String?;
    if (requireFile != null) {
      return File('$repoRoot/$requireFile').existsSync();
    }

    return true;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Gemini
  // ═══════════════════════════════════════════════════════════════════════════

  String get flashModel => _str(['gemini', 'flash_model'], 'gemini-3-flash-preview');
  String get proModel => _str(['gemini', 'pro_model'], 'gemini-3-1-pro-preview');
  int get maxTurns => _int(['gemini', 'max_turns'], 100);
  int get maxConcurrent => _int(['gemini', 'max_concurrent'], 4);
  int get maxRetries => _int(['gemini', 'max_retries'], 3);

  // ═══════════════════════════════════════════════════════════════════════════
  // Secrets
  // ═══════════════════════════════════════════════════════════════════════════

  String get geminiApiKeyEnv => _str(['secrets', 'gemini_api_key_env'], 'GEMINI_API_KEY');

  List<String> get githubTokenEnvNames =>
      _strList(['secrets', 'github_token_env'], ['GH_TOKEN', 'GITHUB_TOKEN', 'GITHUB_PAT']);

  String get gcpSecretName => _str(['secrets', 'gcp_secret_name'], '');

  /// Resolve the Gemini API key from env vars or GCP Secret Manager.
  String? resolveGeminiApiKey() => _resolveSecret(geminiApiKeyEnv, gcpSecretName: gcpSecretName);

  /// Resolve a GitHub token from any of the configured env var names.
  String? resolveGithubToken() {
    for (final envName in githubTokenEnvNames) {
      final value = Platform.environment[envName];
      if (value != null && value.isNotEmpty) return value;
    }
    return _resolveFromGcp(gcpSecretName);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Internal Accessors
  // ═══════════════════════════════════════════════════════════════════════════

  dynamic _navigate(List<String> path) {
    dynamic current = _data;
    for (final key in path) {
      if (current is Map<String, dynamic>) {
        current = current[key];
      } else {
        return null;
      }
    }
    return current;
  }

  String _str(List<String> path, String defaultValue) {
    final value = _navigate(path);
    return value is String ? value : defaultValue;
  }

  int _int(List<String> path, int defaultValue) {
    final value = _navigate(path);
    return value is int ? value : defaultValue;
  }

  double _double(List<String> path, double defaultValue) {
    final value = _navigate(path);
    return value is num ? value.toDouble() : defaultValue;
  }

  bool _bool(List<String> path, bool defaultValue) {
    final value = _navigate(path);
    return value is bool ? value : defaultValue;
  }

  List<dynamic> _list(List<String> path, List<dynamic> defaultValue) {
    final value = _navigate(path);
    return value is List ? value : defaultValue;
  }

  List<String> _strList(List<String> path, List<String> defaultValue) {
    final value = _navigate(path);
    if (value is List) return value.cast<String>();
    return defaultValue;
  }

  Map<String, dynamic>? _map(List<String> path, Map<String, dynamic>? defaultValue) {
    final value = _navigate(path);
    return value is Map<String, dynamic> ? value : defaultValue;
  }

  /// Try environment variable first, then GCP Secret Manager.
  String? _resolveSecret(String envName, {String? gcpSecretName}) {
    final envValue = Platform.environment[envName];
    if (envValue != null && envValue.isNotEmpty) return envValue;
    return _resolveFromGcp(gcpSecretName);
  }

  /// Try to fetch a secret from GCP Secret Manager.
  /// Uses `gcp.project` from config if set, otherwise relies on gcloud default project.
  String? _resolveFromGcp(String? secretName) {
    if (secretName == null || secretName.isEmpty) return null;
    try {
      final args = ['secrets', 'versions', 'access', 'latest', '--secret=$secretName'];
      if (gcpProject.isNotEmpty) args.add('--project=$gcpProject');
      final result = Process.runSync('gcloud', args);
      if (result.exitCode == 0) {
        return (result.stdout as String).trim();
      }
    } catch (_) {}
    return null;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CrossRepoEntry
// ═══════════════════════════════════════════════════════════════════════════════

class CrossRepoEntry {
  final String owner;
  final String repo;
  final String relationship;

  CrossRepoEntry({required this.owner, required this.repo, required this.relationship});

  String get fullName => '$owner/$repo';
}

// ═══════════════════════════════════════════════════════════════════════════════
// Config File Discovery
// ═══════════════════════════════════════════════════════════════════════════════

/// Searches upward from CWD for the CI config file.
///
/// At each directory level, checks (in order):
///   1. `.runtime_ci/config.json`           -- canonical location
///   2. `runtime.ci.config.json`            -- legacy flat-file
///   3. `scripts/triage/triage_config.json` -- legacy nested location
///   4. `triage_config.json`               -- legacy root location
///
/// Returns the first match, or null if nothing is found within 10 levels.
String? _findConfigFile() {
  var dir = Directory.current;
  for (var i = 0; i < 10; i++) {
    // Canonical: .runtime_ci/config.json at this level
    final canonical = File('${dir.path}/$kConfigFileName');
    if (canonical.existsSync()) return canonical.path;

    // Legacy fallbacks
    for (final legacy in kLegacyConfigPaths) {
      final legacyFile = File('${dir.path}/$legacy');
      if (legacyFile.existsSync()) return legacyFile.path;
    }

    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return null;
}
