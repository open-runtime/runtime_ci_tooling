// ignore_for_file: avoid_print

import 'dart:io';

/// Shared tool installation utilities for runtime_isomorphic_library scripts.
///
/// Provides cross-platform, fully automatic (promptless) installation helpers
/// for external CLI tools used by the build/fetch scripts:
///
///   - Smithy CLI  (used by fetch_openapi_specs.dart for Smithy -> OpenAPI)
///
/// Each installer follows the same pattern:
///   1. Check if the tool is already on PATH.
///   2. If missing, auto-install using the best method for the current platform:
///        macOS:   Homebrew (or binary download fallback)
///        Linux:   Binary download from GitHub releases
///        Windows: Binary download from GitHub releases
///   3. Verify the installation succeeded.
///   4. Return `true` if the tool is available, `false` otherwise.
///
/// All installation is automatic with no user prompts.
///
/// Used by:
///   - fetch_openapi_specs.dart  (Smithy CLI for Bedrock Smithy -> OpenAPI)
///   - manage_protos.dart        (could also adopt these for protoc in the future)

// ═══════════════════════════════════════════════════════════════════════════════
// Constants
// ═══════════════════════════════════════════════════════════════════════════════

/// The latest Smithy CLI release version used for auto-installation.
///
/// Update this when a new Smithy CLI release is available:
///   https://github.com/smithy-lang/smithy/releases
const String kSmithyCliVersion = '1.67.0';

/// Minimum required Java major version for the Smithy CLI.
const int kMinJavaVersion = 17;

// ═══════════════════════════════════════════════════════════════════════════════
// Smithy CLI
// ═══════════════════════════════════════════════════════════════════════════════

/// Ensures the Smithy CLI and a compatible JDK are installed.
///
/// If the Smithy CLI is missing, automatically installs it:
///   - macOS:   via Homebrew (`brew tap smithy-lang/tap && brew install smithy-cli`),
///              with a fallback to binary download if Homebrew is unavailable.
///   - Linux:   downloads the binary from GitHub releases.
///   - Windows: downloads the binary from GitHub releases.
///
/// No user prompts -- installation is fully automatic.
///
/// Returns `true` if both Java $kMinJavaVersion+ and the Smithy CLI are
/// available after any installation attempts.
Future<bool> ensureSmithyCli() async {
  print('');
  print('--- Smithy CLI pre-flight check ---');

  // -------------------------------------------------------------------------
  // 1. Check Java (JDK 17+ required by Smithy CLI)
  // -------------------------------------------------------------------------
  if (!await _checkJava()) return false;

  // -------------------------------------------------------------------------
  // 2. Check Smithy CLI (auto-install if missing)
  // -------------------------------------------------------------------------
  print('  Checking for Smithy CLI...');
  if (await _isSmithyInstalled()) return true;

  print('    Smithy CLI not found. Installing automatically...');

  final bool installed;
  if (Platform.isMacOS) {
    installed = await _installSmithyViaBrew();
  } else {
    // Linux and Windows: download the binary from GitHub releases.
    installed = await _installSmithyFromGitHub();
  }

  if (!installed) {
    print('    Smithy -> OpenAPI conversion will be skipped.');
    return false;
  }

  // Verify the installation succeeded.
  if (await _isSmithyInstalled()) return true;

  print('    WARNING: Smithy CLI installed but not found on PATH.');
  print('    You may need to restart your terminal or add it to PATH.');
  print('    Smithy -> OpenAPI conversion will be skipped.');
  return false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Java check
// ═══════════════════════════════════════════════════════════════════════════════

/// Checks that a JDK of at least [kMinJavaVersion] is installed.
Future<bool> _checkJava() async {
  print('  Checking for Java (JDK $kMinJavaVersion+)...');
  try {
    // `java -version` writes to stderr, not stdout.
    final javaResult = await Process.run('java', ['-version']);
    final javaOutput =
        (javaResult.stderr as String) + (javaResult.stdout as String);

    // Parse the major version number from strings like:
    //   openjdk version "21.0.5" ...
    //   java version "17.0.2" ...
    final versionMatch = RegExp(r'version "(\d+)').firstMatch(javaOutput);
    if (versionMatch != null) {
      final major = int.tryParse(versionMatch.group(1)!) ?? 0;
      if (major >= kMinJavaVersion) {
        print('    Found Java $major');
        return true;
      } else {
        print('    WARNING: Java $major found, but Smithy CLI requires $kMinJavaVersion+.');
      }
    } else {
      print('    WARNING: Could not parse Java version.');
    }
  } on ProcessException {
    print('    WARNING: Java not found on PATH.');
  }

  print('    Install JDK $kMinJavaVersion+:');
  print('      macOS:   brew install --cask temurin');
  print('      Linux:   sudo apt install openjdk-21-jdk');
  print('      Windows: winget install EclipseAdoptium.Temurin.21.JDK');
  print('    Smithy -> OpenAPI conversion will be skipped.');
  return false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Smithy CLI detection
// ═══════════════════════════════════════════════════════════════════════════════

/// Returns `true` if `smithy --version` succeeds.
Future<bool> _isSmithyInstalled() async {
  try {
    final result = await Process.run('smithy', ['--version']);
    if (result.exitCode == 0) {
      final version = (result.stdout as String).trim();
      print('    Found: $version');
      return true;
    }
  } on ProcessException {
    // Not installed.
  }
  return false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// macOS: Homebrew installation
// ═══════════════════════════════════════════════════════════════════════════════

/// Installs the Smithy CLI via Homebrew (macOS).
///
/// Runs `brew tap smithy-lang/tap && brew install smithy-cli` without
/// prompting the user.  Falls back to [_installSmithyFromGitHub] if
/// Homebrew is not available.
Future<bool> _installSmithyViaBrew() async {
  // Check if Homebrew is available.
  try {
    final brewResult = await Process.run('brew', ['--version']);
    if (brewResult.exitCode != 0) throw const ProcessException('brew', []);
  } on ProcessException {
    print('    Homebrew not available. Falling back to binary download...');
    return _installSmithyFromGitHub();
  }

  print('    Tapping smithy-lang/tap...');
  final tapResult = await Process.run('brew', ['tap', 'smithy-lang/tap']);
  if (tapResult.exitCode != 0) {
    print('    ERROR: brew tap failed.');
    final err = (tapResult.stderr as String).trim();
    if (err.isNotEmpty) print('      $err');
    return false;
  }

  print('    Installing smithy-cli via Homebrew...');
  final installResult = await Process.run('brew', ['install', 'smithy-cli']);
  if (installResult.exitCode != 0) {
    print('    ERROR: brew install smithy-cli failed.');
    final err = (installResult.stderr as String).trim();
    if (err.isNotEmpty) print('      $err');
    return false;
  }

  print('    Smithy CLI installed successfully via Homebrew.');
  return true;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Cross-platform: GitHub binary download
// ═══════════════════════════════════════════════════════════════════════════════

/// Installs the Smithy CLI by downloading the binary from GitHub releases.
///
/// Works on macOS (if Homebrew is unavailable), Linux, and Windows.
///
/// Release artifacts follow this naming convention:
///   smithy-cli-darwin-x86_64.zip     (macOS Intel)
///   smithy-cli-darwin-aarch64.zip    (macOS Apple Silicon)
///   smithy-cli-linux-x86_64.zip     (Linux Intel)
///   smithy-cli-linux-aarch64.zip    (Linux ARM)
///   smithy-cli-windows-x64.zip      (Windows)
///
/// On Unix, installs to ~/.smithy with a fallback to /usr/local/smithy.
/// On Windows, runs the installer which defaults to Program Files.
///
/// Download page: https://github.com/smithy-lang/smithy/releases
Future<bool> _installSmithyFromGitHub() async {
  // Determine the correct artifact name for this platform + architecture.
  final String os;
  final String arch;

  if (Platform.isMacOS) {
    os = 'darwin';
  } else if (Platform.isLinux) {
    os = 'linux';
  } else if (Platform.isWindows) {
    os = 'windows';
  } else {
    print('    ERROR: Unsupported platform for auto-install.');
    print('    Install manually: https://smithy.io/2.0/guides/smithy-cli/cli_installation.html');
    return false;
  }

  // Detect architecture.  Dart's Platform doesn't expose CPU arch directly,
  // so we use `uname -m` on Unix or default to x64 on Windows.
  if (Platform.isWindows) {
    arch = 'x64';
  } else {
    final unameResult = await Process.run('uname', ['-m']);
    final machine = (unameResult.stdout as String).trim();
    if (machine == 'arm64' || machine == 'aarch64') {
      arch = 'aarch64';
    } else {
      arch = 'x86_64';
    }
  }

  final String artifactName = 'smithy-cli-$os-$arch';
  final String zipName = '$artifactName.zip';
  final String downloadUrl =
      'https://github.com/smithy-lang/smithy/releases/download/$kSmithyCliVersion/$zipName';

  print('    Downloading $zipName from GitHub releases...');
  print('    URL: $downloadUrl');

  // Create a temp directory for the download.
  final Directory tempDir =
      await Directory.systemTemp.createTemp('smithy_install_');
  try {
    final String zipPath = '${tempDir.path}/$zipName';

    // Download.
    final ProcessResult curlResult = await Process.run('curl', [
      '--silent',
      '--show-error',
      '--fail',
      '--location',
      '--output',
      zipPath,
      downloadUrl,
    ]);

    if (curlResult.exitCode != 0) {
      print('    ERROR: Download failed (exit code ${curlResult.exitCode}).');
      final err = (curlResult.stderr as String).trim();
      if (err.isNotEmpty) print('      $err');
      return false;
    }

    // Unzip.
    print('    Extracting...');
    final ProcessResult unzipResult = await Process.run('unzip', [
      '-qo',
      zipPath,
      '-d',
      tempDir.path,
    ]);

    if (unzipResult.exitCode != 0) {
      print('    ERROR: Unzip failed.');
      return false;
    }

    // Run the installer.  The extracted archive contains:
    //   <artifactName>/install      (Unix)
    //   <artifactName>/install.bat  (Windows)
    final String extractedDir = '${tempDir.path}/$artifactName';

    if (Platform.isWindows) {
      print('    Running installer...');
      final installResult = await Process.run(
        '$extractedDir\\install.bat',
        [],
        workingDirectory: extractedDir,
      );
      if (installResult.exitCode != 0) {
        print('    ERROR: Installer failed.');
        return false;
      }
    } else {
      // Unix: try installing to ~/.smithy first (no sudo needed), then fall
      // back to the default /usr/local/smithy.
      final String homeDir = Platform.environment['HOME'] ?? '/tmp';
      final String installDir = '$homeDir/.smithy';
      final String binDir = '$homeDir/.smithy/bin';

      print('    Installing to $installDir...');
      final installResult = await Process.run(
        '$extractedDir/install',
        ['--install-dir', installDir, '--bin-dir', binDir, '--update'],
      );

      if (installResult.exitCode != 0) {
        print('    ERROR: User-local install failed (exit code ${installResult.exitCode}).');
        final err = (installResult.stderr as String).trim();
        if (err.isNotEmpty) print('      $err');

        // Try again with the default location (/usr/local/smithy).
        print('    Retrying with default location (/usr/local/smithy)...');
        final fallbackResult = await Process.run(
          '$extractedDir/install',
          [],
        );
        if (fallbackResult.exitCode != 0) {
          print('    ERROR: Installation failed.');
          print('    Install manually: https://smithy.io/2.0/guides/smithy-cli/cli_installation.html');
          return false;
        }
      }

      // Note: The installer places smithy in either ~/.smithy/bin or
      // /usr/local/smithy/bin.  The user may need to add one of these to
      // their PATH permanently if smithy is not found after installation.
    }

    print('    Smithy CLI installed successfully.');
    return true;
  } finally {
    // Clean up temp directory.
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {
      // Best-effort cleanup.
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Generic helpers
// ═══════════════════════════════════════════════════════════════════════════════

/// Checks if a command is available on PATH.
Future<bool> commandExists(String command) async {
  try {
    final result = await Process.run(
      Platform.isWindows ? 'where' : 'which',
      [command],
    );
    return result.exitCode == 0;
  } on ProcessException {
    return false;
  }
}
