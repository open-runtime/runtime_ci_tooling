import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../../triage/utils/config.dart';
import '../manage_cicd_cli.dart';
import '../utils/ci_constants.dart';
import '../utils/logger.dart';
import '../utils/process_runner.dart';
import '../utils/repo_utils.dart';
import '../utils/version_detection.dart';

const List<String> _kRequiredTools = ['git', 'gh', 'node', 'npm', 'jq'];
const List<String> _kOptionalTools = ['tree', 'gemini'];

/// Show current CI/CD configuration status.
class StatusCommand extends Command<void> {
  @override
  final String name = 'status';

  @override
  final String description = 'Show current CI/CD configuration status.';

  @override
  Future<void> run() async {
    final repoRoot = RepoUtils.findRepoRoot();
    if (repoRoot == null) {
      Logger.error('Could not find ${config.repoName} repo root.');
      exit(1);
    }
    final global = ManageCicdCli.parseGlobalOptions(globalResults);

    Logger.header('CI/CD Configuration Status');

    // Check files
    Logger.info('Configuration files:');
    for (final file in kCiConfigFiles) {
      final exists = File('$repoRoot/$file').existsSync();
      if (exists) {
        Logger.success('  $file');
      } else {
        Logger.error('  $file (MISSING)');
      }
    }

    // Check tools
    Logger.info('');
    Logger.info('Required tools:');
    for (final tool in [..._kRequiredTools, ..._kOptionalTools]) {
      if (CiProcessRunner.commandExists(tool)) {
        final version = CiProcessRunner.runSync(
          '$tool --version 2>/dev/null || echo "installed"',
          repoRoot,
          verbose: global.verbose,
        );
        Logger.success('  $tool: $version');
      } else {
        Logger.error('  $tool: NOT INSTALLED');
      }
    }

    // Check environment
    Logger.info('');
    Logger.info('Environment:');
    final geminiKey = Platform.environment['GEMINI_API_KEY'];
    Logger.info('  GEMINI_API_KEY: ${geminiKey != null ? "set (${geminiKey.length} chars)" : "NOT SET"}');
    final ghToken = Platform.environment['GH_TOKEN'] ?? Platform.environment['GITHUB_TOKEN'];
    Logger.info('  GitHub token: ${ghToken != null ? "set" : "NOT SET"}');

    // Check MCP servers
    Logger.info('');
    Logger.info('MCP servers:');
    try {
      final settings = json.decode(File('$repoRoot/.gemini/settings.json').readAsStringSync());
      final mcpServers = settings['mcpServers'] as Map<String, dynamic>?;
      if (mcpServers != null && mcpServers.isNotEmpty) {
        for (final server in mcpServers.keys) {
          Logger.success('  $server: configured');
        }
      } else {
        Logger.info('  No MCP servers configured. Run: dart run runtime_ci_tooling:manage_cicd configure-mcp');
      }
    } catch (_) {
      Logger.info('  Could not read MCP configuration');
    }

    // Check Stage 1 artifacts
    Logger.info('');
    Logger.info('Stage 1 artifacts:');
    for (final artifact in kStage1Artifacts) {
      if (File(artifact).existsSync()) {
        final size = File(artifact).lengthSync();
        Logger.success('  $artifact ($size bytes)');
      } else {
        Logger.info('  $artifact (not present)');
      }
    }

    // Show version info
    Logger.info('');
    final currentVersion = CiProcessRunner.runSync(
      "awk '/^version:/{print \$2}' pubspec.yaml",
      repoRoot,
      verbose: global.verbose,
    );
    final prevTag = VersionDetection.detectPrevTag(repoRoot, verbose: global.verbose);
    Logger.info('Package version: $currentVersion');
    Logger.info('Latest tag: $prevTag');
  }
}
