import 'dart:io';

import 'logger.dart';
import 'process_runner.dart';

/// Cross-platform tool installation utilities.
abstract final class ToolInstallers {
  /// Install a tool by name, dispatching to the appropriate installer.
  static Future<void> installTool(String tool, {bool dryRun = false}) async {
    if (dryRun) {
      Logger.info('[DRY-RUN] Would install $tool');
      return;
    }

    switch (tool) {
      case 'node' || 'npm':
        await installNodeJs();
      case 'gemini':
        await installGeminiCli();
      case 'gh':
        await installGitHubCli();
      case 'jq':
        await installJq();
      case 'tree':
        await installTree();
      case 'git':
        Logger.error('git must be installed manually.');
        Logger.info('  macOS: xcode-select --install');
        Logger.info('  Linux: sudo apt install git');
        Logger.info('  Windows: https://git-scm.com/downloads');
      default:
        Logger.warn('No auto-installer for $tool');
    }
  }

  static Future<void> installNodeJs() async {
    if (Platform.isMacOS) {
      Logger.info('Installing Node.js via Homebrew...');
      CiProcessRunner.exec('brew', ['install', 'node']);
    } else if (Platform.isLinux) {
      Logger.info('Installing Node.js via apt...');
      CiProcessRunner.exec('sudo', ['apt', 'install', '-y', 'nodejs', 'npm']);
    } else if (Platform.isWindows) {
      if (CiProcessRunner.commandExists('winget')) {
        Logger.info('Installing Node.js via winget...');
        CiProcessRunner.exec('winget', ['install', 'OpenJS.NodeJS']);
      } else if (CiProcessRunner.commandExists('choco')) {
        Logger.info('Installing Node.js via Chocolatey...');
        CiProcessRunner.exec('choco', ['install', 'nodejs', '-y']);
      } else {
        Logger.error('Install Node.js manually: https://nodejs.org/');
      }
    }
  }

  static Future<void> installGeminiCli() async {
    if (!CiProcessRunner.commandExists('npm')) {
      Logger.error('npm is required to install Gemini CLI. Install Node.js first.');
      return;
    }
    Logger.info('Installing Gemini CLI via npm...');
    CiProcessRunner.exec('npm', ['install', '-g', '@google/gemini-cli@latest']);
  }

  static Future<void> installGitHubCli() async {
    if (Platform.isMacOS) {
      Logger.info('Installing GitHub CLI via Homebrew...');
      CiProcessRunner.exec('brew', ['install', 'gh']);
    } else if (Platform.isLinux) {
      Logger.info('Installing GitHub CLI via apt...');
      CiProcessRunner.exec('sh', [
        '-c',
        'type -p curl >/dev/null || sudo apt install curl -y && '
            'curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | '
            'sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && '
            'echo "deb [arch=\$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] '
            'https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null && '
            'sudo apt update && sudo apt install gh -y',
      ]);
    } else if (Platform.isWindows) {
      if (CiProcessRunner.commandExists('winget')) {
        CiProcessRunner.exec('winget', ['install', 'GitHub.cli']);
      } else if (CiProcessRunner.commandExists('choco')) {
        CiProcessRunner.exec('choco', ['install', 'gh', '-y']);
      }
    }
  }

  static Future<void> installJq() async {
    if (Platform.isMacOS) {
      CiProcessRunner.exec('brew', ['install', 'jq']);
    } else if (Platform.isLinux) {
      CiProcessRunner.exec('sudo', ['apt', 'install', '-y', 'jq']);
    } else if (Platform.isWindows) {
      if (CiProcessRunner.commandExists('winget')) {
        CiProcessRunner.exec('winget', ['install', 'jqlang.jq']);
      } else if (CiProcessRunner.commandExists('choco')) {
        CiProcessRunner.exec('choco', ['install', 'jq', '-y']);
      }
    }
  }

  static Future<void> installTree() async {
    if (Platform.isMacOS) {
      CiProcessRunner.exec('brew', ['install', 'tree']);
    } else if (Platform.isLinux) {
      CiProcessRunner.exec('sudo', ['apt', 'install', '-y', 'tree']);
    } else if (Platform.isWindows) {
      Logger.info('tree is built-in on Windows (limited). For full tree: choco install tree');
    }
  }
}
