// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

/// MCP server configuration helpers for GitHub and Sentry integration.
///
/// Provides utilities to configure, validate, and manage MCP server
/// settings in .gemini/settings.json.

// ═══════════════════════════════════════════════════════════════════════════════
// Constants
// ═══════════════════════════════════════════════════════════════════════════════

/// GitHub MCP server Docker image.
const String kGitHubMcpImage = 'ghcr.io/github/github-mcp-server';

/// Sentry MCP server remote URL.
const String kSentryMcpUrl = 'https://mcp.sentry.dev/mcp';

/// GitHub MCP tools allowed for triage operations.
const List<String> kGitHubTriageTools = [
  'issue_read',
  'issue_write',
  'add_issue_comment',
  'search_issues',
  'list_issues',
  'pull_request_read',
  'get_file_contents',
  'list_commits',
  'get_commit',
  'search_code',
  'search_repositories',
  'list_pull_requests',
  'get_me',
];

/// GitHub MCP tools explicitly blocked.
const List<String> kGitHubBlockedTools = ['delete_repository', 'fork_repository', 'create_repository'];

// ═══════════════════════════════════════════════════════════════════════════════
// Configuration Builders
// ═══════════════════════════════════════════════════════════════════════════════

/// Builds the GitHub MCP server configuration for .gemini/settings.json.
Map<String, dynamic> buildGitHubMcpConfig({String? token}) {
  final ghToken =
      token ??
      Platform.environment['GH_TOKEN'] ??
      Platform.environment['GITHUB_TOKEN'] ??
      Platform.environment['GITHUB_PAT'];

  if (ghToken == null || ghToken.isEmpty) {
    throw StateError('No GitHub token found. Set GH_TOKEN, GITHUB_TOKEN, or GITHUB_PAT environment variable.');
  }

  return {
    'command': 'docker',
    'args': ['run', '-i', '--rm', '-e', 'GITHUB_PERSONAL_ACCESS_TOKEN', kGitHubMcpImage],
    'env': {'GITHUB_PERSONAL_ACCESS_TOKEN': ghToken},
    'includeTools': kGitHubTriageTools,
    'excludeTools': kGitHubBlockedTools,
  };
}

/// Builds the Sentry MCP server configuration (remote, OAuth-based).
Map<String, dynamic> buildSentryMcpConfig() => {'url': kSentryMcpUrl};

/// Reads the current .gemini/settings.json file.
Map<String, dynamic> readSettings(String repoRoot) {
  final file = File('$repoRoot/.gemini/settings.json');
  if (!file.existsSync()) {
    return {};
  }
  try {
    return json.decode(file.readAsStringSync()) as Map<String, dynamic>;
  } catch (e) {
    print('Warning: Could not parse .gemini/settings.json: $e');
    return {};
  }
}

/// Writes updated settings to .gemini/settings.json.
void writeSettings(String repoRoot, Map<String, dynamic> settings) {
  final file = File('$repoRoot/.gemini/settings.json');
  file.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(settings)}\n');
}

/// Ensures MCP servers are configured in .gemini/settings.json.
///
/// Returns true if configuration was updated, false if already configured.
bool ensureMcpConfigured(String repoRoot) {
  final settings = readSettings(repoRoot);
  final mcpServers = settings['mcpServers'] as Map<String, dynamic>? ?? {};

  var updated = false;

  // Configure GitHub MCP if not present
  if (!mcpServers.containsKey('github')) {
    try {
      mcpServers['github'] = buildGitHubMcpConfig();
      updated = true;
      print('Configured GitHub MCP server');
    } catch (e) {
      print('Warning: Could not configure GitHub MCP: $e');
    }
  }

  // Configure Sentry MCP if not present
  if (!mcpServers.containsKey('sentry')) {
    mcpServers['sentry'] = buildSentryMcpConfig();
    updated = true;
    print('Configured Sentry MCP server');
  }

  if (updated) {
    settings['mcpServers'] = mcpServers;
    writeSettings(repoRoot, settings);
  }

  return updated;
}

/// Validates that required MCP servers are configured and accessible.
Future<Map<String, bool>> validateMcpServers(String repoRoot) async {
  final settings = readSettings(repoRoot);
  final mcpServers = settings['mcpServers'] as Map<String, dynamic>? ?? {};

  final results = <String, bool>{};

  // Check GitHub MCP
  if (mcpServers.containsKey('github')) {
    // Verify Docker is available for the GitHub MCP server
    try {
      final dockerCheck = await Process.run('docker', ['info']);
      results['github'] = dockerCheck.exitCode == 0;
    } catch (_) {
      results['github'] = false;
    }
  } else {
    results['github'] = false;
  }

  // Sentry MCP is remote, just check it's configured
  results['sentry'] = mcpServers.containsKey('sentry');

  return results;
}
