import 'dart:io';

import 'package:args/command_runner.dart';

import '../../../triage/models/game_plan.dart';
import '../../../triage/models/investigation_result.dart';
import '../../../triage/models/triage_decision.dart';
import '../../../triage/phases/plan.dart' as plan_phase;
import '../../../triage/phases/investigate.dart' as investigate_phase;
import '../../../triage/phases/act.dart' as act_phase;
import '../../../triage/phases/verify.dart' as verify_phase;
import '../../../triage/phases/link.dart' as link_phase;
import '../../../triage/phases/cross_repo_link.dart' as cross_repo_phase;
import '../../../triage/utils/config.dart';
import '../../manage_cicd_cli.dart';
import '../../options/triage_options.dart';
import '../../utils/logger.dart';
import '../../utils/repo_utils.dart';
import 'triage_utils.dart';

/// Auto-triage all untriaged open issues.
class TriageAutoCommand extends Command<void> {
  @override
  final String name = 'auto';

  @override
  final String description = 'Auto-triage all untriaged open issues.';

  TriageAutoCommand() {
    TriageOptionsArgParser.populateParser(argParser);
  }

  @override
  Future<void> run() async {
    final repoRoot = RepoUtils.findRepoRoot();
    if (repoRoot == null) {
      Logger.error('Could not find ${config.repoName} repo root.');
      exit(1);
    }
    final global = ManageCicdCli.parseGlobalOptions(globalResults);
    final triageOpts = TriageOptions.fromArgResults(argResults!);

    reloadConfig();

    if (!acquireTriageLock(triageOpts.force)) {
      exit(1);
    }

    try {
      Logger.header('Auto-Triage Pipeline: All Open Issues');
      final stopwatch = Stopwatch()..start();
      final runDir = createTriageRunDir(repoRoot);

      GamePlan? gamePlan;
      Map<int, List<InvestigationResult>>? results;
      List<TriageDecision>? decisions;

      // Phase 1: Plan
      try {
        gamePlan = await plan_phase.planAutoTriage(repoRoot, runDir: runDir);
      } catch (e) {
        Logger.error('Phase 1 PLAN failed: $e');
        exit(1);
      }

      if (gamePlan.issues.isEmpty) {
        Logger.info('No untriaged issues found. Nothing to do.');
        return;
      }

      // Phase 2: Investigate
      try {
        results = await investigate_phase.investigate(gamePlan, repoRoot,
            runDir: runDir, verbose: global.verbose);
      } catch (e) {
        Logger.error('Phase 2 INVESTIGATE failed: $e');
        saveCheckpoint(runDir, gamePlan, 'investigate');
        exit(1);
      }

      if (global.dryRun) {
        Logger.info('\n[DRY-RUN] Would apply actions but stopping here.');
        Logger.info('Run dir: $runDir');
        return;
      }

      // Phase 3: Act
      try {
        decisions = await act_phase.act(gamePlan, results, repoRoot,
            runDir: runDir);
      } catch (e) {
        Logger.error('Phase 3 ACT failed: $e');
        saveCheckpoint(runDir, gamePlan, 'act');
        exit(1);
      }

      // Phase 4: Verify
      try {
        await verify_phase.verify(gamePlan, decisions, repoRoot,
            runDir: runDir);
      } catch (e) {
        Logger.error('Phase 4 VERIFY failed: $e');
      }

      // Phase 5: Link
      try {
        await link_phase.link(gamePlan, decisions, repoRoot, runDir: runDir);
      } catch (e) {
        Logger.error('Phase 5 LINK failed: $e');
      }

      // Phase 5b: Cross-Repo Link
      if (config.crossRepoEnabled) {
        try {
          await cross_repo_phase.crossRepoLink(gamePlan, decisions, repoRoot,
              runDir: runDir);
        } catch (e) {
          Logger.error('Phase 5b CROSS-REPO failed: $e');
        }
      }

      stopwatch.stop();
      Logger.header('Auto-Triage Complete');
      Logger.info('  Issues triaged: ${gamePlan.issues.length}');
      Logger.info('  Duration: ${stopwatch.elapsed.inSeconds}s');
      Logger.info('  Run dir: $runDir');
    } finally {
      releaseTriageLock();
    }
  }
}
