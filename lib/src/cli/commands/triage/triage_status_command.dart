import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../../../triage/utils/config.dart';
import '../../../triage/utils/mcp_config.dart' as mcp;
import '../../utils/logger.dart';
import '../../utils/repo_utils.dart';
import 'triage_utils.dart';

/// Show triage status without running.
class TriageStatusCommand extends Command<void> {
  @override
  final String name = 'status';

  @override
  final String description = 'Show triage pipeline status.';

  @override
  Future<void> run() async {
    final repoRoot = RepoUtils.findRepoRoot();
    if (repoRoot == null) {
      Logger.error('Could not find ${config.repoName} repo root.');
      exit(1);
    }

    reloadConfig();

    Logger.header('Triage Status');

    // Show config
    Logger.info(
        '  Config: ${config.repoOwner}/${config.repoName}');
    Logger.info(
        '  Cross-repo: ${config.crossRepoEnabled ? "enabled (${config.crossRepoRepos.length} repos)" : "disabled"}');
    Logger.info('  Agents: ${config.enabledAgents.join(", ")}');
    Logger.info(
        '  Thresholds: close=${config.autoCloseThreshold}, suggest=${config.suggestCloseThreshold}, comment=${config.commentThreshold}');

    // Check for active lock
    final lockFile = File(kLockFilePath);
    if (lockFile.existsSync()) {
      try {
        final lockData = json.decode(lockFile.readAsStringSync());
        Logger.info(
            '  Lock: ACTIVE (PID: ${lockData['pid']}, started: ${lockData['started']})');
      } catch (_) {
        Logger.info('  Lock: STALE (invalid lock file)');
      }
    } else {
      Logger.info('  Lock: none');
    }

    // List recent runs
    final runsDir = Directory('$repoRoot/.cicd_runs');
    if (runsDir.existsSync()) {
      final runs = runsDir.listSync().whereType<Directory>().toList()
        ..sort((a, b) => b.path.compareTo(a.path));
      Logger.info('');
      Logger.info('  Recent runs (${runs.length}):');
      for (final run in runs.take(5)) {
        final name = run.path.split('/').last;
        final hasCheckpoint =
            File('${run.path}/checkpoint.json').existsSync();
        final hasPlan =
            File('${run.path}/triage_game_plan.json').existsSync();
        Logger.info(
            '    $name${hasCheckpoint ? " [checkpoint]" : ""}${hasPlan ? " [plan]" : ""}');
      }
    }

    // MCP status
    Logger.info('');
    final mcpStatus = await mcp.validateMcpServers(repoRoot);
    Logger.info('  MCP servers:');
    for (final entry in mcpStatus.entries) {
      Logger.info(
          '    ${entry.key}: ${entry.value ? "configured" : "NOT configured"}');
    }
  }
}
