// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

/// Manages a run-scoped audit trail directory for CI/CD operations.
///
/// Every CLI command creates a RunContext that writes all prompts, raw Gemini
/// responses, and structured artifacts to a timestamped directory under
/// `.runtime_ci/runs/` in the repo root.
///
/// Two-tier design:
///   - `.runtime_ci/runs/` (gitignored): Full audit trail for local development
///   - `.runtime_ci/audit/vX.X.X/` (committed): Important artifacts per release

// ═══════════════════════════════════════════════════════════════════════════════
// Constants
// ═══════════════════════════════════════════════════════════════════════════════

/// Root directory for all runtime CI artifacts.
const String kRuntimeCiDir = '.runtime_ci';

/// Gitignored run audit trails.
const String kCicdRunsDir = '$kRuntimeCiDir/runs';

/// Committed per-release audit snapshots.
const String kCicdAuditDir = '$kRuntimeCiDir/audit';

/// Release notes output directory.
const String kReleaseNotesDir = '$kRuntimeCiDir/release_notes';

/// Version bump rationale directory.
const String kVersionBumpsDir = '$kRuntimeCiDir/version_bumps';

// ═══════════════════════════════════════════════════════════════════════════════
// RunContext
// ═══════════════════════════════════════════════════════════════════════════════

class RunContext {
  final String repoRoot;
  final String runDir;
  final String command;
  final DateTime startedAt;
  final List<String> args;

  RunContext._({
    required this.repoRoot,
    required this.runDir,
    required this.command,
    required this.startedAt,
    this.args = const [],
  });

  /// Create a new run context with a timestamped directory.
  factory RunContext.create(String repoRoot, String command, {List<String> args = const []}) {
    final now = DateTime.now();
    final timestamp = now.toIso8601String().replaceAll(':', '-').replaceAll('.', '-').substring(0, 19);
    final runId = 'run_${timestamp}_${pid}';
    final runDir = '$repoRoot/$kCicdRunsDir/$runId';

    final ctx = RunContext._(repoRoot: repoRoot, runDir: runDir, command: command, startedAt: now, args: args);

    Directory(runDir).createSync(recursive: true);
    ctx._writeMeta();

    return ctx;
  }

  /// Load an existing run context from a run directory.
  factory RunContext.load(String repoRoot, String runDirPath) {
    final metaFile = File('$runDirPath/meta.json');
    if (!metaFile.existsSync()) {
      throw StateError('No meta.json found in $runDirPath');
    }
    final meta = json.decode(metaFile.readAsStringSync()) as Map<String, dynamic>;
    return RunContext._(
      repoRoot: repoRoot,
      runDir: runDirPath,
      command: meta['command'] as String? ?? 'unknown',
      startedAt: DateTime.parse(meta['started_at'] as String),
      args: (meta['args'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Directory Management
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get or create a subdirectory within the run directory.
  String subdir(String name) {
    final dir = '$runDir/$name';
    Directory(dir).createSync(recursive: true);
    return dir;
  }

  /// Get the run ID (directory name).
  String get runId => runDir.split('/').last;

  // ═══════════════════════════════════════════════════════════════════════════
  // Save Methods
  // ═══════════════════════════════════════════════════════════════════════════

  /// Save a prompt sent to Gemini CLI.
  void savePrompt(String phase, String prompt) {
    File('${subdir(phase)}/prompt.txt').writeAsStringSync(prompt);
  }

  /// Save the raw response from Gemini CLI (full stdout including warnings).
  void saveResponse(String phase, String rawResponse) {
    File('${subdir(phase)}/gemini_response.json').writeAsStringSync(rawResponse);
  }

  /// Save a structured artifact (JSON, markdown, etc.).
  void saveArtifact(String phase, String filename, String content) {
    File('${subdir(phase)}/$filename').writeAsStringSync(content);
  }

  /// Save a JSON artifact.
  void saveJsonArtifact(String phase, String filename, Map<String, dynamic> data) {
    File('${subdir(phase)}/$filename').writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(data)}\n');
  }

  /// Get the path for an artifact file (may not exist yet).
  String artifactPath(String phase, String filename) {
    return '${subdir(phase)}/$filename';
  }

  /// Read an artifact file, returning null if it doesn't exist.
  String? readArtifact(String phase, String filename) {
    final file = File('${subdir(phase)}/$filename');
    return file.existsSync() ? file.readAsStringSync() : null;
  }

  /// Check if an artifact exists.
  bool hasArtifact(String phase, String filename) {
    return File('${subdir(phase)}/$filename').existsSync();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Finalization
  // ═══════════════════════════════════════════════════════════════════════════

  /// Update the meta.json with completion info.
  void finalize({int? exitCode}) {
    final metaFile = File('$runDir/meta.json');
    Map<String, dynamic> meta;
    try {
      meta = json.decode(metaFile.readAsStringSync()) as Map<String, dynamic>;
    } catch (_) {
      meta = {};
    }

    meta['completed_at'] = DateTime.now().toIso8601String();
    meta['duration_seconds'] = DateTime.now().difference(startedAt).inSeconds;
    if (exitCode != null) meta['exit_code'] = exitCode;

    // List all generated artifacts
    final artifacts = <String>[];
    _listFilesRecursive(Directory(runDir), artifacts, runDir);
    meta['artifacts'] = artifacts;

    metaFile.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(meta)}\n');
  }

  /// Archive important artifacts to cicd_audit/vX.X.X/ for permanent storage.
  ///
  /// Copies only the important files (no raw prompts or large Gemini responses).
  /// Handles both RunContext-managed phases (explore/, compose/, etc.) and
  /// direct-write directories (version_analysis/ from determine-version).
  void archiveForRelease(String version) {
    final auditDir = '$repoRoot/$kCicdAuditDir/v$version';
    Directory(auditDir).createSync(recursive: true);

    // Copy meta.json
    _copyIfExists('$runDir/meta.json', '$auditDir/meta.json');

    // Copy version artifacts (RunContext-managed)
    _copyDirFiltered('$runDir/version', '$auditDir/version', exclude: {'gemini_response.json'});

    // Copy version_analysis artifacts (direct writes from determine-version).
    // These are placed under version_analysis/ by the merge step when
    // determine-version doesn't use RunContext.
    _copyDirFiltered(
      '$runDir/version_analysis',
      '$auditDir/version_analysis',
      exclude: {'gemini_response.json', 'prompt.txt'},
    );

    // Copy explore artifacts (structured data only, not raw response)
    _copyDirFiltered('$runDir/explore', '$auditDir/explore', exclude: {'gemini_response.json', 'prompt.txt'});

    // Copy compose artifacts (release notes body only)
    _copyDirFiltered('$runDir/compose', '$auditDir/compose', exclude: {'gemini_response.json', 'prompt.txt'});

    // Copy pre-release-triage artifacts
    _copyDirFiltered(
      '$runDir/pre-release-triage',
      '$auditDir/pre-release-triage',
      exclude: {'gemini_response.json', 'prompt.txt'},
    );

    // Copy triage artifacts (decisions and reports only)
    final triageDir = '$runDir/triage';
    if (Directory(triageDir).existsSync()) {
      final auditTriageDir = '$auditDir/triage';
      Directory(auditTriageDir).createSync(recursive: true);
      for (final name in ['issue_manifest.json', 'decisions.json', 'post_release_report.json', 'game_plan.json']) {
        _copyIfExists('$triageDir/$name', '$auditTriageDir/$name');
      }
    }

    print('Archived audit trail to $kRuntimeCiDir/audit/v$version/');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Static Helpers
  // ═══════════════════════════════════════════════════════════════════════════

  /// Find the most recent run directory for a given command.
  static String? findLatestRun(String repoRoot, {String? command}) {
    final runsDir = Directory('$repoRoot/$kCicdRunsDir');
    if (!runsDir.existsSync()) return null;

    final runs = runsDir.listSync().whereType<Directory>().toList()..sort((a, b) => b.path.compareTo(a.path));

    for (final run in runs) {
      if (command != null) {
        final metaFile = File('${run.path}/meta.json');
        if (metaFile.existsSync()) {
          try {
            final meta = json.decode(metaFile.readAsStringSync()) as Map<String, dynamic>;
            if (meta['command'] == command) return run.path;
          } catch (_) {}
        }
      } else {
        return run.path;
      }
    }
    return null;
  }

  /// List all run directories.
  static List<Directory> listRuns(String repoRoot) {
    final runsDir = Directory('$repoRoot/$kCicdRunsDir');
    if (!runsDir.existsSync()) return [];
    return runsDir.listSync().whereType<Directory>().toList()..sort((a, b) => b.path.compareTo(a.path));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Internal
  // ═══════════════════════════════════════════════════════════════════════════

  void _writeMeta() {
    final meta = {
      'command': command,
      'args': args,
      'started_at': startedAt.toIso8601String(),
      'pid': pid,
      'platform': Platform.operatingSystem,
      'dart_version': Platform.version.split(' ').first,
      'repo_root': repoRoot,
      'run_dir': runDir,
      'ci': Platform.environment.containsKey('CI'),
    };
    File('$runDir/meta.json').writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(meta)}\n');
  }

  void _listFilesRecursive(Directory dir, List<String> files, String basePath) {
    for (final entity in dir.listSync()) {
      if (entity is File) {
        files.add(entity.path.substring(basePath.length + 1));
      } else if (entity is Directory) {
        _listFilesRecursive(entity, files, basePath);
      }
    }
  }

  void _copyIfExists(String src, String dst) {
    final srcFile = File(src);
    if (srcFile.existsSync()) {
      Directory(File(dst).parent.path).createSync(recursive: true);
      srcFile.copySync(dst);
    }
  }

  void _copyDirFiltered(String srcDir, String dstDir, {Set<String> exclude = const {}}) {
    final src = Directory(srcDir);
    if (!src.existsSync()) return;

    Directory(dstDir).createSync(recursive: true);
    for (final entity in src.listSync()) {
      if (entity is File) {
        final name = entity.path.split('/').last;
        if (!exclude.contains(name)) {
          entity.copySync('$dstDir/$name');
        }
      }
    }
  }
}
