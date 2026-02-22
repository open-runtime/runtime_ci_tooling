import 'dart:io';

import 'package:args/command_runner.dart';

import '../../triage/utils/config.dart';
import '../manage_cicd_cli.dart';
import '../utils/logger.dart';
import '../utils/process_runner.dart';
import '../utils/repo_utils.dart';
import '../utils/tool_installers.dart';

const List<String> _kRequiredTools = ['git', 'gh', 'node', 'npm', 'jq'];
const List<String> _kOptionalTools = ['tree', 'gemini'];

/// Install all prerequisites cross-platform.
class SetupCommand extends Command<void> {
  @override
  final String name = 'setup';

  @override
  final String description = 'Install all prerequisites (Node.js, Gemini CLI, gh, jq, tree).';

  @override
  Future<void> run() async {
    final repoRoot = RepoUtils.findRepoRoot();
    if (repoRoot == null) {
      Logger.error('Could not find ${config.repoName} repo root.');
      exit(1);
    }
    final global = ManageCicdCli.parseGlobalOptions(globalResults);

    Logger.header('Setting up CI/CD prerequisites');

    // Check and install required tools
    for (final tool in _kRequiredTools) {
      if (CiProcessRunner.commandExists(tool)) {
        Logger.success('$tool is installed');
      } else {
        Logger.warn('$tool is not installed -- attempting installation');
        await ToolInstallers.installTool(tool, dryRun: global.dryRun);
      }
    }

    // Check optional tools
    for (final tool in _kOptionalTools) {
      if (CiProcessRunner.commandExists(tool)) {
        Logger.success('$tool is installed');
      } else {
        Logger.warn('$tool is not installed -- attempting installation');
        await ToolInstallers.installTool(tool, dryRun: global.dryRun);
      }
    }

    // Verify Gemini CLI version
    if (CiProcessRunner.commandExists('gemini')) {
      final version = CiProcessRunner.runSync('gemini --version', repoRoot, verbose: global.verbose);
      Logger.info('Gemini CLI version: $version');
    }

    // Check for API keys
    final geminiKey = Platform.environment['GEMINI_API_KEY'];
    if (geminiKey != null && geminiKey.isNotEmpty) {
      Logger.success('GEMINI_API_KEY is set');
    } else {
      Logger.warn('GEMINI_API_KEY is not set. Set it via: export GEMINI_API_KEY=<your-key>');
    }

    final ghToken = Platform.environment['GH_TOKEN'] ?? Platform.environment['GITHUB_TOKEN'];
    if (ghToken != null && ghToken.isNotEmpty) {
      Logger.success('GitHub token is set');
    } else {
      Logger.info('No GH_TOKEN/GITHUB_TOKEN set. Run "gh auth login" for GitHub CLI auth.');
    }

    // Install Dart dependencies
    Logger.info('Installing Dart dependencies...');
    CiProcessRunner.runSync('dart pub get', repoRoot, verbose: global.verbose);
    Logger.success('Dart dependencies installed');

    Logger.header('Setup complete');
  }
}
