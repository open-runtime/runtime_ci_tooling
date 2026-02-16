// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'models/game_plan.dart';
import 'models/investigation_result.dart';
import 'models/triage_decision.dart';
import 'phases/plan.dart' as plan_phase;
import 'phases/investigate.dart' as investigate_phase;
import 'phases/act.dart' as act_phase;
import 'phases/verify.dart' as verify_phase;
import 'phases/link.dart' as link_phase;
import 'phases/cross_repo_link.dart' as cross_repo_phase;
import 'phases/pre_release.dart' as pre_release_phase;
import 'phases/post_release.dart' as post_release_phase;
import 'utils/config.dart';
import 'utils/mcp_config.dart' as mcp;

/// Triage CLI entry point.
///
/// Orchestrates the 6-phase triage pipeline:
///   Phase 1: PLAN       -- Discover issues, build game plan
///   Phase 2: INVESTIGATE -- Parallel Gemini agents explore each issue
///   Phase 3: ACT         -- Apply labels, comments, close issues
///   Phase 4: VERIFY      -- Confirm all actions succeeded
///   Phase 5: LINK        -- Cross-link issues to PRs, changelogs, docs
///   Phase 5b: CROSS-REPO -- Link related issues in dependent repos
///
/// Usage:
///   dart run scripts/triage/triage_cli.dart <issue_number>
///   dart run scripts/triage/triage_cli.dart --auto
///   dart run scripts/triage/triage_cli.dart --auto --dry-run
///   dart run scripts/triage/triage_cli.dart --resume <run_id>
///   dart run scripts/triage/triage_cli.dart --status

// ═══════════════════════════════════════════════════════════════════════════════
// Constants
// ═══════════════════════════════════════════════════════════════════════════════

/// Lock file remains in /tmp (not repo-scoped -- prevents concurrent triage globally).
const String kLockFilePath = '/tmp/triage.lock';

// ═══════════════════════════════════════════════════════════════════════════════
// Main
// ═══════════════════════════════════════════════════════════════════════════════

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.contains('--help') || args.contains('-h')) {
    _printUsage();
    return;
  }

  final verbose = args.contains('--verbose') || args.contains('-v');
  final dryRun = args.contains('--dry-run');
  final autoMode = args.contains('--auto');
  final statusMode = args.contains('--status');
  final forceMode = args.contains('--force');
  final preReleaseMode = args.contains('--pre-release');
  final postReleaseMode = args.contains('--post-release');

  // Check for --resume <run_id>
  final resumeIdx = args.indexOf('--resume');
  final resumeRunId = (resumeIdx != -1 && resumeIdx + 1 < args.length) ? args[resumeIdx + 1] : null;

  // Parse named arguments
  String? _getArg(String name) {
    final idx = args.indexOf(name);
    return (idx != -1 && idx + 1 < args.length) ? args[idx + 1] : null;
  }

  final prevTagArg = _getArg('--prev-tag');
  final versionArg = _getArg('--version');
  final releaseTagArg = _getArg('--release-tag');
  final releaseUrlArg = _getArg('--release-url');
  final manifestArg = _getArg('--manifest');

  // Find repo root
  final repoRoot = _findRepoRoot();
  if (repoRoot == null) {
    _error('Could not find ${config.repoName} repo root.');
    _error('Run this script from inside the repository.');
    exit(1);
  }

  // Load config
  reloadConfig();

  // Check MCP configuration
  mcp.ensureMcpConfigured(repoRoot);

  // Check for API key (using config for env var name)
  final geminiKey = config.resolveGeminiApiKey();
  if (geminiKey == null || geminiKey.isEmpty) {
    _error('GEMINI_API_KEY is not set.');
    _error('export ${config.geminiApiKeyEnv}=<your-key-from-aistudio.google.com>');
    exit(1);
  }

  if (statusMode) {
    await _showStatus(repoRoot);
    return;
  }

  // Acquire lock (unless --force)
  if (!_acquireLock(forceMode)) {
    exit(1);
  }

  try {
    if (preReleaseMode) {
      // Pre-release triage: scan issues/Sentry, produce manifest
      if (prevTagArg == null || versionArg == null) {
        _error('--pre-release requires --prev-tag <tag> and --version <ver>');
        exit(1);
      }
      await _runPreRelease(prevTag: prevTagArg, newVersion: versionArg, repoRoot: repoRoot, verbose: verbose);
    } else if (postReleaseMode) {
      // Post-release triage: comment on issues, close confident ones
      if (versionArg == null || releaseTagArg == null) {
        _error('--post-release requires --version <ver> and --release-tag <tag>');
        exit(1);
      }
      await _runPostRelease(
        newVersion: versionArg,
        releaseTag: releaseTagArg,
        releaseUrl: releaseUrlArg ?? '',
        manifestPath: manifestArg,
        repoRoot: repoRoot,
        verbose: verbose,
      );
    } else if (resumeRunId != null) {
      await _resumeRun(resumeRunId, repoRoot, verbose: verbose, dryRun: dryRun);
    } else if (autoMode) {
      await _runAutoTriage(repoRoot, verbose: verbose, dryRun: dryRun);
    } else {
      final issueNumber = int.tryParse(args.firstWhere((a) => !a.startsWith('-'), orElse: () => ''));
      if (issueNumber == null) {
        _error('Provide an issue number, --auto, --pre-release, --post-release, or --resume <run_id>.');
        _printUsage();
        exit(1);
      }
      await _runSingleTriage(issueNumber, repoRoot, verbose: verbose, dryRun: dryRun);
    }
  } finally {
    _releaseLock();
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Locking
// ═══════════════════════════════════════════════════════════════════════════════

/// Acquire a file-based lock. Returns true if acquired, false if another run is active.
bool _acquireLock(bool force) {
  final lockFile = File(kLockFilePath);

  if (lockFile.existsSync()) {
    try {
      final lockData = json.decode(lockFile.readAsStringSync()) as Map<String, dynamic>;
      final lockPid = lockData['pid'] as int;

      // Check if the locking process is still alive
      // On Unix, sending signal 0 checks existence without killing
      try {
        Process.killPid(lockPid, ProcessSignal.sigusr1);
        // Process exists -- another triage is running
        if (!force) {
          _error('Triage already running (PID: $lockPid, started: ${lockData['started']}).');
          _error('Use --force to override, or wait for it to finish.');
          return false;
        }
        print('Warning: Overriding existing lock (PID: $lockPid) with --force');
      } catch (_) {
        // Process doesn't exist -- stale lock, safe to clean up
        print('Cleaned up stale lock from PID $lockPid');
      }
    } catch (_) {
      // Can't parse lock file -- just remove it
    }
    lockFile.deleteSync();
  }

  // Write our lock
  lockFile.writeAsStringSync(json.encode({'pid': pid, 'started': DateTime.now().toIso8601String()}));
  return true;
}

/// Release the file-based lock.
void _releaseLock() {
  try {
    final lockFile = File(kLockFilePath);
    if (lockFile.existsSync()) {
      lockFile.deleteSync();
    }
  } catch (_) {}
}

// ═══════════════════════════════════════════════════════════════════════════════
// Run Directory Management
// ═══════════════════════════════════════════════════════════════════════════════

/// Create a unique run directory for this triage session.
String _createRunDir(String repoRoot) {
  final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-').substring(0, 19);
  final runId = 'triage_${timestamp}_$pid';
  final runDir = Directory('$repoRoot/.cicd_runs/$runId');
  runDir.createSync(recursive: true);
  Directory('${runDir.path}/results').createSync();
  Directory('${runDir.path}/triage').createSync();
  return runDir.path;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Triage Pipelines
// ═══════════════════════════════════════════════════════════════════════════════

/// Run the full triage pipeline for a single issue.
Future<void> _runSingleTriage(int issueNumber, String repoRoot, {bool verbose = false, bool dryRun = false}) async {
  _header('Triage Pipeline: Issue #$issueNumber');
  final stopwatch = Stopwatch()..start();
  final runDir = _createRunDir(repoRoot);

  GamePlan? gamePlan;
  Map<int, List<InvestigationResult>>? results;
  List<TriageDecision>? decisions;

  // Phase 1: Plan
  try {
    gamePlan = await plan_phase.planSingleIssue(issueNumber, repoRoot, runDir: runDir);
  } catch (e) {
    _error('Phase 1 PLAN failed: $e');
    exit(1);
  }

  if (gamePlan.issues.isEmpty) {
    print('No issues to triage.');
    return;
  }

  // Phase 2: Investigate
  try {
    results = await investigate_phase.investigate(gamePlan, repoRoot, runDir: runDir, verbose: verbose);
  } catch (e) {
    _error('Phase 2 INVESTIGATE failed: $e');
    _saveCheckpoint(runDir, gamePlan, 'investigate');
    exit(1);
  }

  if (dryRun) {
    print('\n[DRY-RUN] Would apply actions but stopping here.');
    print('Run dir: $runDir');
    return;
  }

  // Phase 3: Act
  try {
    decisions = await act_phase.act(gamePlan, results, repoRoot, runDir: runDir);
  } catch (e) {
    _error('Phase 3 ACT failed: $e');
    _saveCheckpoint(runDir, gamePlan, 'act');
    exit(1);
  }

  // Phase 4: Verify
  try {
    await verify_phase.verify(gamePlan, decisions, repoRoot, runDir: runDir);
  } catch (e) {
    _error('Phase 4 VERIFY failed: $e');
    _saveCheckpoint(runDir, gamePlan, 'verify');
  }

  // Phase 5: Link
  try {
    await link_phase.link(gamePlan, decisions, repoRoot, runDir: runDir);
  } catch (e) {
    _error('Phase 5 LINK failed: $e');
  }

  // Phase 5b: Cross-Repo Link
  if (config.crossRepoEnabled) {
    try {
      await cross_repo_phase.crossRepoLink(gamePlan, decisions, repoRoot, runDir: runDir);
    } catch (e) {
      _error('Phase 5b CROSS-REPO failed: $e');
    }
  }

  stopwatch.stop();
  _header('Triage Complete');
  print('  Issue: #$issueNumber');
  print('  Duration: ${stopwatch.elapsed.inSeconds}s');
  print('  Run dir: $runDir');
}

/// Run the full triage pipeline for all untriaged open issues.
Future<void> _runAutoTriage(String repoRoot, {bool verbose = false, bool dryRun = false}) async {
  _header('Auto-Triage Pipeline: All Open Issues');
  final stopwatch = Stopwatch()..start();
  final runDir = _createRunDir(repoRoot);

  GamePlan? gamePlan;
  Map<int, List<InvestigationResult>>? results;
  List<TriageDecision>? decisions;

  // Phase 1: Plan
  try {
    gamePlan = await plan_phase.planAutoTriage(repoRoot, runDir: runDir);
  } catch (e) {
    _error('Phase 1 PLAN failed: $e');
    exit(1);
  }

  if (gamePlan.issues.isEmpty) {
    print('No untriaged issues found. Nothing to do.');
    return;
  }

  // Phase 2: Investigate
  try {
    results = await investigate_phase.investigate(gamePlan, repoRoot, runDir: runDir, verbose: verbose);
  } catch (e) {
    _error('Phase 2 INVESTIGATE failed: $e');
    _saveCheckpoint(runDir, gamePlan, 'investigate');
    exit(1);
  }

  if (dryRun) {
    print('\n[DRY-RUN] Would apply actions but stopping here.');
    print('Run dir: $runDir');
    return;
  }

  // Phase 3: Act
  try {
    decisions = await act_phase.act(gamePlan, results, repoRoot, runDir: runDir);
  } catch (e) {
    _error('Phase 3 ACT failed: $e');
    _saveCheckpoint(runDir, gamePlan, 'act');
    exit(1);
  }

  // Phase 4: Verify
  try {
    await verify_phase.verify(gamePlan, decisions, repoRoot, runDir: runDir);
  } catch (e) {
    _error('Phase 4 VERIFY failed: $e');
  }

  // Phase 5: Link
  try {
    await link_phase.link(gamePlan, decisions, repoRoot, runDir: runDir);
  } catch (e) {
    _error('Phase 5 LINK failed: $e');
  }

  // Phase 5b: Cross-Repo Link
  if (config.crossRepoEnabled) {
    try {
      await cross_repo_phase.crossRepoLink(gamePlan, decisions, repoRoot, runDir: runDir);
    } catch (e) {
      _error('Phase 5b CROSS-REPO failed: $e');
    }
  }

  stopwatch.stop();
  _header('Auto-Triage Complete');
  print('  Issues triaged: ${gamePlan.issues.length}');
  print('  Duration: ${stopwatch.elapsed.inSeconds}s');
  print('  Run dir: $runDir');
}

/// Resume a previously interrupted triage run.
Future<void> _resumeRun(String runId, String repoRoot, {bool verbose = false, bool dryRun = false}) async {
  final runDir = '$repoRoot/.cicd_runs/$runId';
  final checkpointFile = File('$runDir/checkpoint.json');

  if (!checkpointFile.existsSync()) {
    _error('No checkpoint found for run $runId at $runDir');
    exit(1);
  }

  _header('Resuming Triage Run: $runId');

  final checkpoint = json.decode(checkpointFile.readAsStringSync()) as Map<String, dynamic>;
  final lastPhase = checkpoint['last_completed_phase'] as String;
  final gamePlan = GamePlan.fromJson(checkpoint['game_plan'] as Map<String, dynamic>);

  print('  Last completed phase: $lastPhase');
  print('  Issues: ${gamePlan.issues.length}');

  // Determine where to resume
  var results = <int, List<InvestigationResult>>{};
  List<TriageDecision>? decisions;

  // If investigate was the last completed, load results and continue from act
  if (lastPhase == 'plan' || lastPhase == 'investigate') {
    if (lastPhase == 'plan') {
      try {
        results = await investigate_phase.investigate(gamePlan, repoRoot, runDir: runDir, verbose: verbose);
      } catch (e) {
        _error('Phase 2 INVESTIGATE failed on resume: $e');
        _saveCheckpoint(runDir, gamePlan, 'investigate');
        exit(1);
      }
    } else {
      // Load cached results
      results = _loadCachedResults(runDir, gamePlan);
    }

    if (!dryRun) {
      try {
        decisions = await act_phase.act(gamePlan, results, repoRoot, runDir: runDir);
      } catch (e) {
        _error('Phase 3 ACT failed on resume: $e');
        _saveCheckpoint(runDir, gamePlan, 'act');
        exit(1);
      }
    }
  }

  if (lastPhase == 'act' && !dryRun) {
    results = _loadCachedResults(runDir, gamePlan);
    decisions = _loadCachedDecisions(runDir);
  }

  if (decisions != null) {
    try {
      await verify_phase.verify(gamePlan, decisions, repoRoot, runDir: runDir);
    } catch (e) {
      _error('Phase 4 VERIFY failed on resume: $e');
    }

    try {
      await link_phase.link(gamePlan, decisions, repoRoot, runDir: runDir);
    } catch (e) {
      _error('Phase 5 LINK failed on resume: $e');
    }

    if (config.crossRepoEnabled) {
      try {
        await cross_repo_phase.crossRepoLink(gamePlan, decisions, repoRoot, runDir: runDir);
      } catch (e) {
        _error('Phase 5b CROSS-REPO failed on resume: $e');
      }
    }
  }

  _header('Resume Complete');
  print('  Run dir: $runDir');
}

// ═══════════════════════════════════════════════════════════════════════════════
// Checkpointing
// ═══════════════════════════════════════════════════════════════════════════════

void _saveCheckpoint(String runDir, GamePlan plan, String lastPhase) {
  final checkpointFile = File('$runDir/checkpoint.json');
  checkpointFile.writeAsStringSync(
    json.encode({
      'last_completed_phase': lastPhase,
      'game_plan': plan.toJson(),
      'saved_at': DateTime.now().toIso8601String(),
    }),
  );
  print('Checkpoint saved to $runDir/checkpoint.json');
  print('Resume with: dart run scripts/triage/triage_cli.dart --resume ${runDir.split('/').last}');
}

Map<int, List<InvestigationResult>> _loadCachedResults(String runDir, GamePlan plan) {
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

List<TriageDecision> _loadCachedDecisions(String runDir) {
  final decisionsFile = File('$runDir/triage_decisions.json');
  if (!decisionsFile.existsSync()) return [];
  try {
    final data = json.decode(decisionsFile.readAsStringSync()) as Map<String, dynamic>;
    return (data['decisions'] as List<dynamic>).map((d) => TriageDecision.fromJson(d as Map<String, dynamic>)).toList();
  } catch (_) {
    return [];
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Release Triage Modes
// ═══════════════════════════════════════════════════════════════════════════════

/// Pre-release triage: scan issues/Sentry, correlate with diff, produce manifest.
Future<void> _runPreRelease({
  required String prevTag,
  required String newVersion,
  required String repoRoot,
  bool verbose = false,
}) async {
  final runDir = _createRunDir(repoRoot);

  try {
    final manifestPath = await pre_release_phase.preReleaseTriage(
      prevTag: prevTag,
      newVersion: newVersion,
      repoRoot: repoRoot,
      runDir: runDir,
      verbose: verbose,
    );

    _header('Pre-Release Triage Complete');
    print('  Manifest: $manifestPath');
    print('  Run dir: $runDir');
  } catch (e) {
    _error('Pre-release triage failed: $e');
    exit(1);
  }
}

/// Post-release triage: comment/close issues, link Sentry, update linked_issues.json.
Future<void> _runPostRelease({
  required String newVersion,
  required String releaseTag,
  required String releaseUrl,
  String? manifestPath,
  required String repoRoot,
  bool verbose = false,
}) async {
  final runDir = _createRunDir(repoRoot);

  // Find the manifest: explicit path, or search recent runs
  final resolvedManifest = manifestPath ?? _findLatestManifest(repoRoot);
  if (resolvedManifest == null) {
    _error('No issue_manifest.json found. Run --pre-release first, or pass --manifest <path>.');
    exit(1);
  }

  final url = releaseUrl.isNotEmpty
      ? releaseUrl
      : 'https://github.com/${config.repoOwner}/${config.repoName}/releases/tag/$releaseTag';

  try {
    await post_release_phase.postReleaseTriage(
      newVersion: newVersion,
      releaseTag: releaseTag,
      releaseUrl: url,
      manifestPath: resolvedManifest,
      repoRoot: repoRoot,
      runDir: runDir,
      verbose: verbose,
    );

    _header('Post-Release Triage Complete');
    print('  Run dir: $runDir');
  } catch (e) {
    _error('Post-release triage failed: $e');
    exit(1);
  }
}

/// Search recent triage runs for the latest issue_manifest.json.
String? _findLatestManifest(String repoRoot) {
  final runsDir = Directory('$repoRoot/.cicd_runs');
  if (!runsDir.existsSync()) return null;

  final runs = runsDir.listSync().whereType<Directory>().toList()..sort((a, b) => b.path.compareTo(a.path));

  for (final run in runs) {
    final manifest = File('${run.path}/issue_manifest.json');
    if (manifest.existsSync()) return manifest.path;
  }
  return null;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Status
// ═══════════════════════════════════════════════════════════════════════════════

Future<void> _showStatus(String repoRoot) async {
  _header('Triage Status');

  // Show config
  print('  Config: ${config.repoOwner}/${config.repoName}');
  print('  Cross-repo: ${config.crossRepoEnabled ? "enabled (${config.crossRepoRepos.length} repos)" : "disabled"}');
  print('  Agents: ${config.enabledAgents.join(", ")}');
  print(
    '  Thresholds: close=${config.autoCloseThreshold}, suggest=${config.suggestCloseThreshold}, comment=${config.commentThreshold}',
  );

  // Check for active lock
  final lockFile = File(kLockFilePath);
  if (lockFile.existsSync()) {
    try {
      final lockData = json.decode(lockFile.readAsStringSync());
      print('  Lock: ACTIVE (PID: ${lockData['pid']}, started: ${lockData['started']})');
    } catch (_) {
      print('  Lock: STALE (invalid lock file)');
    }
  } else {
    print('  Lock: none');
  }

  // List recent runs
  final runsDir = Directory('$repoRoot/.cicd_runs');
  if (runsDir.existsSync()) {
    final runs = runsDir.listSync().whereType<Directory>().toList()..sort((a, b) => b.path.compareTo(a.path));
    print('');
    print('  Recent runs (${runs.length}):');
    for (final run in runs.take(5)) {
      final name = run.path.split('/').last;
      final hasCheckpoint = File('${run.path}/checkpoint.json').existsSync();
      final hasPlan = File('${run.path}/triage_game_plan.json').existsSync();
      print('    $name${hasCheckpoint ? " [checkpoint]" : ""}${hasPlan ? " [plan]" : ""}');
    }
  }

  // MCP status
  print('');
  final mcpStatus = await mcp.validateMcpServers(repoRoot);
  print('  MCP servers:');
  for (final entry in mcpStatus.entries) {
    print('    ${entry.key}: ${entry.value ? "configured" : "NOT configured"}');
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Utilities
// ═══════════════════════════════════════════════════════════════════════════════

String? _findRepoRoot() {
  final repoName = config.repoName;
  var dir = Directory.current;
  for (var i = 0; i < 10; i++) {
    final pubspec = File('${dir.path}/pubspec.yaml');
    if (pubspec.existsSync()) {
      final content = pubspec.readAsStringSync();
      if (content.contains('name: $repoName')) {
        return dir.path;
      }
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return null;
}

void _header(String msg) => print('\n\x1B[1m$msg\x1B[0m');
void _error(String msg) => stderr.writeln('\x1B[31m$msg\x1B[0m');

void _printUsage() {
  print('''
Triage CLI for ${config.repoName}

Usage:
  dart run scripts/triage/triage_cli.dart <issue_number>    Triage a single issue
  dart run scripts/triage/triage_cli.dart --auto            Auto-triage all open issues
  dart run scripts/triage/triage_cli.dart --pre-release     Scan issues for upcoming release
  dart run scripts/triage/triage_cli.dart --post-release    Close loop after release
  dart run scripts/triage/triage_cli.dart --resume <run_id> Resume an interrupted run
  dart run scripts/triage/triage_cli.dart --status          Show triage status

Release Triage:
  --pre-release --prev-tag <tag> --version <ver>
      Scan GH issues + Sentry errors, correlate with diff, produce issue_manifest.json
      Run BEFORE changelog/release notes generation

  --post-release --version <ver> --release-tag <tag> [--release-url <url>] [--manifest <path>]
      Comment on issues with release links, close confident own-repo issues,
      recommend closure in cross-repo, link Sentry issues
      Run AFTER GitHub Release is created

Options:
  --dry-run     Run investigation but don't apply actions
  --verbose     Show detailed Gemini CLI output
  --force       Override an existing lock
  --help        Show this help message

Standard Pipeline Phases:
  1. PLAN        Discover issues, build game_plan.json
  2. INVESTIGATE Parallel Gemini agents (${config.enabledAgents.join(", ")})
  3. ACT         Apply labels, comments, close issues (confidence-based)
  4. VERIFY      Confirm all actions succeeded
  5. LINK        Cross-link issues to PRs, changelogs, release notes
  5b. CROSS-REPO Link related issues in dependent repos

Confidence Thresholds (from triage_config.json):
  >= ${(config.autoCloseThreshold * 100).toStringAsFixed(0)}%  Auto-close with detailed comment (own repo only)
  >= ${(config.suggestCloseThreshold * 100).toStringAsFixed(0)}%  Comment with findings, suggest/recommend closure
  >= ${(config.commentThreshold * 100).toStringAsFixed(0)}%  Informational comment with related links
  <  ${(config.commentThreshold * 100).toStringAsFixed(0)}%  Label as needs-investigation

Cross-Repo (${config.crossRepoEnabled ? "enabled" : "disabled"}):
${config.crossRepoRepos.map((r) => '  - ${r.fullName} (${r.relationship})').join('\n')}

Examples:
  dart run scripts/triage/triage_cli.dart 42
  dart run scripts/triage/triage_cli.dart --auto --dry-run
  dart run scripts/triage/triage_cli.dart --pre-release --prev-tag v0.0.1 --version 0.0.2
  dart run scripts/triage/triage_cli.dart --post-release --version 0.0.2 --release-tag v0.0.2
  dart run scripts/triage/triage_cli.dart --resume 12345_1707900000000
''');
}
