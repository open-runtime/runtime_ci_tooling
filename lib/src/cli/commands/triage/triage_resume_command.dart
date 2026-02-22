import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../../../triage/models/game_plan.dart';
import '../../../triage/models/investigation_result.dart';
import '../../../triage/models/triage_decision.dart';
import '../../../triage/phases/investigate.dart' as investigate_phase;
import '../../../triage/phases/act.dart' as act_phase;
import '../../../triage/phases/verify.dart' as verify_phase;
import '../../../triage/phases/link.dart' as link_phase;
import '../../../triage/phases/cross_repo_link.dart' as cross_repo_phase;
import '../../../triage/utils/config.dart';
import '../../manage_cicd_cli.dart';
import '../../utils/logger.dart';
import '../../utils/repo_utils.dart';
import 'triage_utils.dart';

/// Resume a previously interrupted triage run.
class TriageResumeCommand extends Command<void> {
  @override
  final String name = 'resume';

  @override
  final String description = 'Resume a previously interrupted triage run.';

  @override
  String get invocation => '${runner!.executableName} triage resume <run_id>';

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      Logger.error('Provide a run ID to resume.');
      printUsage();
      exit(1);
    }
    final runId = rest.first;

    final repoRoot = RepoUtils.findRepoRoot();
    if (repoRoot == null) {
      Logger.error('Could not find ${config.repoName} repo root.');
      exit(1);
    }
    final global = ManageCicdCli.parseGlobalOptions(globalResults);

    reloadConfig();

    if (!acquireTriageLock(false)) {
      exit(1);
    }

    try {
      final runDir = '$repoRoot/.cicd_runs/$runId';
      final checkpointFile = File('$runDir/checkpoint.json');

      if (!checkpointFile.existsSync()) {
        Logger.error('No checkpoint found for run $runId at $runDir');
        exit(1);
      }

      Logger.header('Resuming Triage Run: $runId');

      final checkpoint = json.decode(checkpointFile.readAsStringSync()) as Map<String, dynamic>;
      final lastPhase = checkpoint['last_completed_phase'] as String;
      final gamePlan = GamePlan.fromJson(checkpoint['game_plan'] as Map<String, dynamic>);

      Logger.info('  Last completed phase: $lastPhase');
      Logger.info('  Issues: ${gamePlan.issues.length}');

      // Determine where to resume
      var results = <int, List<InvestigationResult>>{};
      List<TriageDecision>? decisions;

      if (lastPhase == 'plan' || lastPhase == 'investigate') {
        if (lastPhase == 'plan') {
          try {
            results = await investigate_phase.investigate(gamePlan, repoRoot, runDir: runDir, verbose: global.verbose);
          } catch (e) {
            Logger.error('Phase 2 INVESTIGATE failed on resume: $e');
            saveCheckpoint(runDir, gamePlan, 'investigate');
            exit(1);
          }
        } else {
          results = loadCachedResults(runDir, gamePlan);
        }

        if (!global.dryRun) {
          try {
            decisions = await act_phase.act(gamePlan, results, repoRoot, runDir: runDir);
          } catch (e) {
            Logger.error('Phase 3 ACT failed on resume: $e');
            saveCheckpoint(runDir, gamePlan, 'act');
            exit(1);
          }
        }
      }

      if (lastPhase == 'act' && !global.dryRun) {
        results = loadCachedResults(runDir, gamePlan);
        decisions = loadCachedDecisions(runDir);
      }

      if (decisions != null) {
        try {
          await verify_phase.verify(gamePlan, decisions, repoRoot, runDir: runDir);
        } catch (e) {
          Logger.error('Phase 4 VERIFY failed on resume: $e');
        }

        try {
          await link_phase.link(gamePlan, decisions, repoRoot, runDir: runDir);
        } catch (e) {
          Logger.error('Phase 5 LINK failed on resume: $e');
        }

        if (config.crossRepoEnabled) {
          try {
            await cross_repo_phase.crossRepoLink(gamePlan, decisions, repoRoot, runDir: runDir);
          } catch (e) {
            Logger.error('Phase 5b CROSS-REPO failed on resume: $e');
          }
        }
      }

      Logger.header('Resume Complete');
      Logger.info('  Run dir: $runDir');
    } finally {
      releaseTriageLock();
    }
  }
}
