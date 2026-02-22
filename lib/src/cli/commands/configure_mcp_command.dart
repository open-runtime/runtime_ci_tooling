import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../../triage/utils/config.dart';
import '../manage_cicd_cli.dart';
import '../utils/logger.dart';
import '../utils/repo_utils.dart';

/// Configure MCP servers in .gemini/settings.json.
class ConfigureMcpCommand extends Command<void> {
  @override
  final String name = 'configure-mcp';

  @override
  final String description = 'Set up MCP servers (GitHub, Sentry).';

  @override
  Future<void> run() async {
    final repoRoot = RepoUtils.findRepoRoot();
    if (repoRoot == null) {
      Logger.error('Could not find ${config.repoName} repo root.');
      exit(1);
    }
    final global = ManageCicdCli.parseGlobalOptions(globalResults);

    Logger.header('Configuring MCP Servers');

    final settingsPath = '$repoRoot/.gemini/settings.json';
    final settingsFile = File(settingsPath);

    Map<String, dynamic> settings;
    try {
      settings = json.decode(settingsFile.readAsStringSync()) as Map<String, dynamic>;
    } catch (e) {
      Logger.error('Could not read .gemini/settings.json: $e');
      exit(1);
    }

    // Add MCP servers configuration
    final mcpServers = <String, dynamic>{};

    // GitHub MCP Server
    final ghToken =
        Platform.environment['GH_TOKEN'] ?? Platform.environment['GITHUB_TOKEN'] ?? Platform.environment['GITHUB_PAT'];

    if (ghToken != null && ghToken.isNotEmpty) {
      Logger.info('Configuring GitHub MCP server...');
      mcpServers['github'] = {
        'command': 'docker',
        'args': ['run', '-i', '--rm', '-e', 'GITHUB_PERSONAL_ACCESS_TOKEN', 'ghcr.io/github/github-mcp-server'],
        'env': {'GITHUB_PERSONAL_ACCESS_TOKEN': ghToken},
        'includeTools': [
          'get_issue',
          'get_issue_comments',
          'create_issue',
          'update_issue',
          'add_issue_comment',
          'list_issues',
          'search_issues',
          'get_pull_request',
          'get_pull_request_diff',
          'get_pull_request_files',
          'get_pull_request_reviews',
          'get_pull_request_comments',
          'list_pull_requests',
          'create_pull_request',
          'get_file_contents',
          'list_commits',
          'get_commit',
          'search_code',
          'search_repositories',
          'create_or_update_file',
          'push_files',
          'create_repository',
          'get_me',
        ],
        'excludeTools': ['delete_repository', 'fork_repository'],
      };
      Logger.success('GitHub MCP server configured');
    } else {
      Logger.warn('No GitHub token found. Set GH_TOKEN or GITHUB_PAT to configure GitHub MCP.');
      Logger.info('  export GH_TOKEN=<your-github-personal-access-token>');
    }

    // Sentry MCP Server
    Logger.info('Configuring Sentry MCP server (remote)...');
    mcpServers['sentry'] = {'url': 'https://mcp.sentry.dev/mcp'};
    Logger.success('Sentry MCP server configured (uses OAuth -- browser auth on first use)');

    // Write updated settings
    settings['mcpServers'] = mcpServers;

    if (global.dryRun) {
      Logger.info('[DRY-RUN] Would write MCP configuration:');
      Logger.info(const JsonEncoder.withIndent('  ').convert(settings));
      return;
    }

    settingsFile.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(settings)}\n');
    Logger.success('Updated .gemini/settings.json with MCP servers');

    Logger.info('');
    Logger.info('To verify MCP servers, run: gemini /mcp');
    Logger.info('GitHub MCP tools will be available as: github__<tool_name>');
    Logger.info('Sentry MCP tools will be available as: sentry__<tool_name>');
  }
}
