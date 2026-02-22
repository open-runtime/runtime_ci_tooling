import 'dart:convert';
import 'dart:io';

import '../../utils/logger.dart';
import '../../../triage/models/game_plan.dart';
import '../../../triage/models/investigation_result.dart';
import '../../../triage/models/triage_decision.dart';

/// Lock file remains in /tmp (not repo-scoped -- prevents concurrent triage globally).
const String kLockFilePath = '/tmp/triage.lock';

/// Acquire a file-based lock. Returns true if acquired, false if another run is active.
bool acquireTriageLock(bool force) {
  final lockFile = File(kLockFilePath);

  if (lockFile.existsSync()) {
    try {
      final lockData =
          json.decode(lockFile.readAsStringSync()) as Map<String, dynamic>;
      final lockPid = lockData['pid'] as int;

      try {
        Process.killPid(lockPid, ProcessSignal.sigusr1);
        // Process exists -- another triage is running
        if (!force) {
          Logger.error(
              'Triage already running (PID: $lockPid, started: ${lockData['started']}).');
          Logger.error(
              'Use --force to override, or wait for it to finish.');
          return false;
        }
        Logger.warn(
            'Warning: Overriding existing lock (PID: $lockPid) with --force');
      } catch (_) {
        // Process doesn't exist -- stale lock, safe to clean up
        Logger.info('Cleaned up stale lock from PID $lockPid');
      }
    } catch (_) {
      // Can't parse lock file -- just remove it
    }
    lockFile.deleteSync();
  }

  // Write our lock
  lockFile.writeAsStringSync(
      json.encode({'pid': pid, 'started': DateTime.now().toIso8601String()}));
  return true;
}

/// Release the file-based lock.
void releaseTriageLock() {
  try {
    final lockFile = File(kLockFilePath);
    if (lockFile.existsSync()) {
      lockFile.deleteSync();
    }
  } catch (_) {}
}

/// Create a unique run directory for this triage session.
String createTriageRunDir(String repoRoot) {
  final timestamp = DateTime.now()
      .toIso8601String()
      .replaceAll(':', '-')
      .replaceAll('.', '-')
      .substring(0, 19);
  final runId = 'triage_${timestamp}_$pid';
  final runDir = Directory('$repoRoot/.cicd_runs/$runId');
  runDir.createSync(recursive: true);
  Directory('${runDir.path}/results').createSync();
  Directory('${runDir.path}/triage').createSync();
  return runDir.path;
}

/// Save a checkpoint so the run can be resumed later.
void saveCheckpoint(String runDir, GamePlan plan, String lastPhase) {
  final checkpointFile = File('$runDir/checkpoint.json');
  checkpointFile.writeAsStringSync(
    json.encode({
      'last_completed_phase': lastPhase,
      'game_plan': plan.toJson(),
      'saved_at': DateTime.now().toIso8601String(),
    }),
  );
  Logger.info('Checkpoint saved to $runDir/checkpoint.json');
  Logger.info(
      'Resume with: manage_cicd triage resume ${runDir.split('/').last}');
}

/// Load cached investigation results from a game plan.
Map<int, List<InvestigationResult>> loadCachedResults(
    String runDir, GamePlan plan) {
  final results = <int, List<InvestigationResult>>{};
  for (final issue in plan.issues) {
    results[issue.number] = [];
    for (final task in issue.tasks) {
      if (task.result != null) {
        results[issue.number]!.add(InvestigationResult.fromJson(task.result!));
      }
    }
  }
  return results;
}

/// Load cached triage decisions from a run directory.
List<TriageDecision> loadCachedDecisions(String runDir) {
  final decisionsFile = File('$runDir/triage_decisions.json');
  if (!decisionsFile.existsSync()) return [];
  try {
    final data = json.decode(decisionsFile.readAsStringSync())
        as Map<String, dynamic>;
    return (data['decisions'] as List<dynamic>)
        .map((d) => TriageDecision.fromJson(d as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
}

/// Search recent triage runs for the latest issue_manifest.json.
String? findLatestManifest(String repoRoot) {
  final runsDir = Directory('$repoRoot/.cicd_runs');
  if (!runsDir.existsSync()) return null;

  final runs = runsDir.listSync().whereType<Directory>().toList()
    ..sort((a, b) => b.path.compareTo(a.path));

  for (final run in runs) {
    final manifest = File('${run.path}/issue_manifest.json');
    if (manifest.existsSync()) return manifest.path;
  }
  return null;
}
