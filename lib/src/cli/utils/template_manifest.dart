import 'dart:convert';
import 'dart:io';

import '../../triage/utils/run_context.dart';

/// Represents one template entry from manifest.json.
class TemplateEntry {
  final String id;
  final String? source;
  final String destination;
  final String category;
  final String description;

  TemplateEntry({
    required this.id,
    required this.source,
    required this.destination,
    required this.category,
    required this.description,
  });

  factory TemplateEntry.fromJson(Map<String, dynamic> json) {
    return TemplateEntry(
      id: json['id'] as String,
      source: json['source'] as String?,
      destination: json['destination'] as String,
      category: json['category'] as String,
      description: json['description'] as String? ?? '',
    );
  }
}

/// Tracks which template versions a consumer repo has installed.
///
/// Stored at `.runtime_ci/template_versions.json` in the consumer repo.
class TemplateVersionTracker {
  static const String kTrackingFile = '$kRuntimeCiDir/template_versions.json';

  final Map<String, dynamic> _data;

  TemplateVersionTracker._(this._data);

  /// Load from disk, or create empty tracker.
  factory TemplateVersionTracker.load(String repoRoot) {
    final file = File('$repoRoot/$kTrackingFile');
    if (file.existsSync()) {
      try {
        return TemplateVersionTracker._(json.decode(file.readAsStringSync()) as Map<String, dynamic>);
      } catch (_) {
        return TemplateVersionTracker._({});
      }
    }
    return TemplateVersionTracker._({});
  }

  /// Get the tooling version that was last used to update.
  String? get lastToolingVersion => _data['tooling_version'] as String?;

  /// Get the hash of a template as it was when last installed.
  String? getInstalledHash(String templateId) {
    final templates = _data['templates'] as Map<String, dynamic>? ?? {};
    final entry = templates[templateId] as Map<String, dynamic>?;
    return entry?['hash'] as String?;
  }

  /// Get the hash of a consumer's file at the time it was last installed.
  String? getConsumerHash(String templateId) {
    final templates = _data['templates'] as Map<String, dynamic>? ?? {};
    final entry = templates[templateId] as Map<String, dynamic>?;
    return entry?['consumer_hash'] as String?;
  }

  /// Record that a template was installed/updated.
  void recordUpdate(
    String templateId, {
    required String templateHash,
    required String consumerFileHash,
    required String toolingVersion,
  }) {
    _data['tooling_version'] = toolingVersion;
    _data['updated_at'] = DateTime.now().toUtc().toIso8601String();
    final templates = _data.putIfAbsent('templates', () => <String, dynamic>{}) as Map<String, dynamic>;
    templates[templateId] = {
      'hash': templateHash,
      'consumer_hash': consumerFileHash,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  /// Save to disk.
  void save(String repoRoot) {
    final file = File('$repoRoot/$kTrackingFile');
    Directory(file.parent.path).createSync(recursive: true);
    file.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(_data)}\n');
  }
}

/// Compute SHA256 hash of a file's contents.
String computeFileHash(String filePath) {
  final file = File(filePath);
  if (!file.existsSync()) return '';
  // Try shasum (macOS) first, then sha256sum (Linux)
  final macResult = Process.runSync('sh', ['-c', 'shasum -a 256 "$filePath" | cut -d" " -f1']);
  if (macResult.exitCode == 0) {
    final hash = (macResult.stdout as String).trim();
    if (hash.isNotEmpty) return hash;
  }
  final linuxResult = Process.runSync('sh', ['-c', 'sha256sum "$filePath" | cut -d" " -f1']);
  if (linuxResult.exitCode == 0) {
    return (linuxResult.stdout as String).trim();
  }
  return '';
}
