import 'dart:convert';
import 'dart:io';

/// Reads package name and repo owner from `.runtime_ci/config.json`.
///
/// Falls back to `runtime_isomorphic_library` / `open-runtime` when
/// config is unavailable — e.g. when running locally outside a
/// properly initialised repo.
class CiConfig {
  CiConfig._({required this.packageName, required this.repoOwner});

  final String packageName;
  final String repoOwner;

  static CiConfig? _instance;

  /// Singleton that reads the config once and caches it.
  static CiConfig get current => _instance ??= _load();

  static CiConfig _load() {
    const fallbackName = 'runtime_isomorphic_library';
    const fallbackOwner = 'open-runtime';

    // Walk upward from CWD to find .runtime_ci/config.json (up to 5 levels).
    var dir = Directory.current;
    for (var i = 0; i < 5; i++) {
      final configFile = File('${dir.path}/.runtime_ci/config.json');
      if (configFile.existsSync()) {
        try {
          final json_ =
              json.decode(configFile.readAsStringSync()) as Map<String, dynamic>;
          final repo = json_['repository'] as Map<String, dynamic>? ?? {};
          return CiConfig._(
            packageName: (repo['name'] as String?) ?? fallbackName,
            repoOwner: (repo['owner'] as String?) ?? fallbackOwner,
          );
        } catch (_) {
          break;
        }
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }

    return CiConfig._(packageName: fallbackName, repoOwner: fallbackOwner);
  }
}
