// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import '../triage/utils/run_context.dart';
import '../triage/utils/config.dart';

// Re-export path constants from run_context for use throughout this file.
// All CI artifacts live under .runtime_ci/ at the repo root:
//   kRuntimeCiDir    = '.runtime_ci'
//   kCicdRunsDir     = '.runtime_ci/runs'
//   kCicdAuditDir    = '.runtime_ci/audit'
//   kReleaseNotesDir = '.runtime_ci/release_notes'
//   kVersionBumpsDir = '.runtime_ci/version_bumps'

/// CI/CD automation management CLI (package-agnostic).
///
/// Provides cross-platform setup, validation, and execution of the AI-powered
/// release pipeline locally (macOS, Linux, Windows) and in CI.
///
/// Commands:
///   setup              Install all prerequisites (Node.js, Gemini CLI, gh, jq, tree)
///   validate           Validate all configuration files (YAML, JSON, TOML, Dart prompts)
///   explore            Run Stage 1 Explorer Agent locally (writes JSON to /tmp/)
///   compose            Run Stage 2 Changelog Composer (updates CHANGELOG.md)
///   release-notes      Run Stage 3 Release Notes Author (rich release notes with examples)
///   triage <number>    Run issue triage on a specific GitHub issue
///   release            Run the full release pipeline locally (explore + compose)
///   version            Determine the next SemVer version from commit history
///   configure-mcp      Set up MCP servers (GitHub, Sentry) in .gemini/settings.json
///   status             Show current CI/CD configuration status
///
/// Options:
///   --dry-run          Show what would be done without executing
///   --verbose          Show detailed command output
///   --prev-tag <tag>   Override previous tag detection
///   --version <ver>    Override version (skip auto-detection)
///
/// Usage:
///   dart run scripts/manage_cicd.dart setup
///   dart run scripts/manage_cicd.dart validate
///   dart run scripts/manage_cicd.dart explore --prev-tag v0.0.1 --version 0.0.2
///   dart run scripts/manage_cicd.dart compose --prev-tag v0.0.1 --version 0.0.2
///   dart run scripts/manage_cicd.dart triage 42
///   dart run scripts/manage_cicd.dart triage --auto
///   dart run scripts/manage_cicd.dart triage --status
///   dart run scripts/manage_cicd.dart release
///   dart run scripts/manage_cicd.dart configure-mcp

// ═══════════════════════════════════════════════════════════════════════════════
// Constants
// ═══════════════════════════════════════════════════════════════════════════════

const String kGeminiModel = 'gemini-3-flash-preview';
const String kGeminiProModel = 'gemini-3-pro-preview';
const int kMaxTurns = 100;

const List<String> kRequiredTools = ['git', 'gh', 'node', 'npm', 'jq'];
const List<String> kOptionalTools = ['tree', 'gemini'];

/// Cached path to the runtime_ci_tooling package root.
/// Resolved lazily on first call to [_promptScript].
String? _toolingPackageRoot;

/// Resolves the absolute path to a prompt script within this package.
///
/// Prompt scripts live at `lib/src/prompts/` in the runtime_ci_tooling
/// package. When this code runs from the package's own repo, that's just
/// a relative path. When it runs from a consuming repo (e.g., via a thin
/// wrapper), we resolve the package location from .dart_tool/package_config.json.
String _promptScript(String scriptName) {
  _toolingPackageRoot ??= _resolveToolingPackageRoot();
  return '$_toolingPackageRoot/lib/src/prompts/$scriptName';
}

/// Find the runtime_ci_tooling package root by checking:
///   1. package_config.json (works when consumed as a dependency)
///   2. CWD (works when running from the package's own repo)
String _resolveToolingPackageRoot() {
  // Try 1: Look for the package in .dart_tool/package_config.json
  var dir = Directory.current;
  for (var i = 0; i < 10; i++) {
    final configFile = File('${dir.path}/.dart_tool/package_config.json');
    if (configFile.existsSync()) {
      try {
        final configJson = json.decode(configFile.readAsStringSync()) as Map<String, dynamic>;
        final packages = configJson['packages'] as List<dynamic>? ?? [];
        for (final pkg in packages) {
          if (pkg is Map<String, dynamic> && pkg['name'] == 'runtime_ci_tooling') {
            final rootUri = pkg['rootUri'] as String? ?? '';
            if (rootUri.startsWith('file://')) {
              return Uri.parse(rootUri).toFilePath();
            }
            // Relative URI -- resolve against the .dart_tool/ directory
            final resolved = Uri.parse('${dir.path}/.dart_tool/').resolve(rootUri);
            final resolvedPath = resolved.toFilePath();
            // Strip trailing slash
            return resolvedPath.endsWith('/') ? resolvedPath.substring(0, resolvedPath.length - 1) : resolvedPath;
          }
        }
      } catch (_) {}
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }

  // Try 2: If we're running from the package's own repo, lib/src/prompts/ is relative
  if (File('lib/src/prompts/gemini_changelog_prompt.dart').existsSync()) {
    return Directory.current.path;
  }

  // Fallback: assume scripts/prompts/ (legacy location in consuming repos)
  _warn('Could not resolve runtime_ci_tooling package root. Prompt scripts may not be found.');
  return Directory.current.path;
}

const List<String> kStage1Artifacts = [
  '$kCicdRunsDir/explore/commit_analysis.json',
  '$kCicdRunsDir/explore/pr_data.json',
  '$kCicdRunsDir/explore/breaking_changes.json',
];

const List<String> kConfigFiles = [
  '.github/workflows/release.yaml',
  '.github/workflows/issue-triage.yaml',
  '.github/workflows/ci.yaml',
  '.gemini/settings.json',
  '.gemini/commands/changelog.toml',
  '.gemini/commands/release-notes.toml',
  '.gemini/commands/triage.toml',
  'GEMINI.md',
  'CHANGELOG.md',
  'lib/src/prompts/gemini_changelog_prompt.dart',
  'lib/src/prompts/gemini_changelog_composer_prompt.dart',
  'lib/src/prompts/gemini_release_notes_author_prompt.dart',
  'lib/src/prompts/gemini_documentation_prompt.dart',
  'lib/src/prompts/gemini_triage_prompt.dart',
];

// ═══════════════════════════════════════════════════════════════════════════════
// Globals
// ═══════════════════════════════════════════════════════════════════════════════

bool _dryRun = false;
bool _verbose = false;
String? _prevTagOverride;
String? _versionOverride;

// ═══════════════════════════════════════════════════════════════════════════════
// Main
// ═══════════════════════════════════════════════════════════════════════════════

void main(List<String> args) async {
  if (args.isEmpty || args.contains('--help') || args.contains('-h')) {
    _printUsage();
    return;
  }

  // Parse flags
  _dryRun = args.contains('--dry-run');
  _verbose = args.contains('--verbose') || args.contains('-v');

  final tagIdx = args.indexOf('--prev-tag');
  if (tagIdx != -1 && tagIdx + 1 < args.length) {
    _prevTagOverride = args[tagIdx + 1];
  }

  final verIdx = args.indexOf('--version');
  if (verIdx != -1 && verIdx + 1 < args.length) {
    _versionOverride = args[verIdx + 1];
  }

  // Find repo root
  final repoRoot = _findRepoRoot();
  if (repoRoot == null) {
    _error('Could not find ${config.repoName} repo root.');
    _error('Run this script from inside the repository.');
    exit(1);
  }

  final command = args.first;

  switch (command) {
    case 'setup':
      await _runSetup(repoRoot);
    case 'validate':
      await _runValidate(repoRoot);
    case 'explore':
      await _runExplore(repoRoot);
    case 'compose':
      await _runCompose(repoRoot);
    case 'triage':
      // Delegate to the modular triage CLI
      final triageArgs = args.skip(1).toList();
      await _runTriageCli(repoRoot, triageArgs);
    case 'release':
      await _runRelease(repoRoot);
    case 'version':
      await _runVersion(repoRoot);
    case 'configure-mcp':
      await _runConfigureMcp(repoRoot);
    case 'status':
      await _runStatus(repoRoot);
    case 'determine-version':
      await _runDetermineVersion(repoRoot, args);
    case 'create-release':
      await _runCreateRelease(repoRoot, args);
    case 'test':
      await _runTest(repoRoot);
    case 'analyze':
      await _runAnalyze(repoRoot);
    case 'verify-protos':
      await _runVerifyProtos(repoRoot);
    case 'documentation':
      await _runDocumentation(repoRoot);
    case 'release-notes':
      await _runReleaseNotes(repoRoot);
    case 'autodoc':
      await _runAutodoc(repoRoot, args);
    case 'pre-release-triage':
      await _runPreReleaseTriage(repoRoot, args);
    case 'post-release-triage':
      await _runPostReleaseTriage(repoRoot, args);
    case 'archive-run':
      await _runArchiveRun(repoRoot, args);
    case 'merge-audit-trails':
      await _runMergeAuditTrails(repoRoot, args);
    case 'init':
      await _runInit(repoRoot);
    default:
      _error('Unknown command: $command');
      _printUsage();
      exit(1);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Commands
// ═══════════════════════════════════════════════════════════════════════════════

/// Install all prerequisites cross-platform.
Future<void> _runSetup(String repoRoot) async {
  _header('Setting up CI/CD prerequisites');

  // Check and install required tools
  for (final tool in kRequiredTools) {
    if (_commandExists(tool)) {
      _success('$tool is installed');
    } else {
      _warn('$tool is not installed -- attempting installation');
      await _installTool(tool);
    }
  }

  // Check optional tools
  for (final tool in kOptionalTools) {
    if (_commandExists(tool)) {
      _success('$tool is installed');
    } else {
      _warn('$tool is not installed -- attempting installation');
      await _installTool(tool);
    }
  }

  // Verify Gemini CLI version supports Gemini 3 models
  if (_commandExists('gemini')) {
    final version = _runSync('gemini --version', repoRoot);
    _info('Gemini CLI version: $version');
  }

  // Check for API keys
  final geminiKey = Platform.environment['GEMINI_API_KEY'];
  if (geminiKey != null && geminiKey.isNotEmpty) {
    _success('GEMINI_API_KEY is set');
  } else {
    _warn('GEMINI_API_KEY is not set. Set it via: export GEMINI_API_KEY=<your-key>');
  }

  final ghToken = Platform.environment['GH_TOKEN'] ?? Platform.environment['GITHUB_TOKEN'];
  if (ghToken != null && ghToken.isNotEmpty) {
    _success('GitHub token is set');
  } else {
    _info('No GH_TOKEN/GITHUB_TOKEN set. Run "gh auth login" for GitHub CLI auth.');
  }

  // Install Dart dependencies
  _info('Installing Dart dependencies...');
  _runSync('dart pub get', repoRoot);
  _success('Dart dependencies installed');

  _header('Setup complete');
}

/// Validate all configuration files.
Future<void> _runValidate(String repoRoot) async {
  _header('Validating CI/CD configuration');

  var allValid = true;

  for (final file in kConfigFiles) {
    final path = '$repoRoot/$file';
    if (!File(path).existsSync()) {
      _error('Missing: $file');
      allValid = false;
      continue;
    }

    if (file.endsWith('.json')) {
      // Validate JSON
      try {
        final content = File(path).readAsStringSync();
        json.decode(content);
        _success('Valid JSON: $file');
      } catch (e) {
        _error('Invalid JSON: $file -- $e');
        allValid = false;
      }
    } else if (file.endsWith('.yaml') || file.endsWith('.yml')) {
      // Validate YAML (basic syntax check via dart:io)
      final result = Process.runSync('ruby', [
        '-ryaml',
        '-e',
        'YAML.safe_load(File.read("$path"))',
      ], workingDirectory: repoRoot);
      if (result.exitCode == 0) {
        _success('Valid YAML: $file');
      } else {
        // Fallback: just check it's non-empty
        final content = File(path).readAsStringSync();
        if (content.trim().isNotEmpty) {
          _success('Exists (YAML validation skipped): $file');
        } else {
          _error('Empty file: $file');
          allValid = false;
        }
      }
    } else if (file.endsWith('.dart')) {
      // Validate Dart files compile
      final result = Process.runSync('dart', ['analyze', path], workingDirectory: repoRoot);
      if (result.exitCode == 0) {
        _success('Valid Dart: $file');
      } else {
        _error('Dart analysis failed: $file');
        _error('  ${result.stderr}');
        allValid = false;
      }
    } else if (file.endsWith('.toml')) {
      // Basic TOML validation: check for required keys
      final content = File(path).readAsStringSync();
      if (content.contains('prompt') && content.contains('description')) {
        _success('Valid TOML: $file');
      } else {
        _error('TOML missing required keys (prompt, description): $file');
        allValid = false;
      }
    } else {
      // Markdown and others: just check existence and non-empty
      final content = File(path).readAsStringSync();
      if (content.trim().isNotEmpty) {
        _success('Exists: $file');
      } else {
        _error('Empty file: $file');
        allValid = false;
      }
    }
  }

  // Validate Stage 1 artifacts (if they exist from a previous run)
  _info('');
  _info('Checking Stage 1 artifacts from previous runs...');
  for (final artifact in kStage1Artifacts) {
    if (File(artifact).existsSync()) {
      try {
        final content = File(artifact).readAsStringSync();
        json.decode(content);
        _success('Valid JSON artifact: $artifact');
      } catch (e) {
        _warn('Invalid JSON artifact: $artifact -- $e');
      }
    } else {
      _info('Not present (expected before first run): $artifact');
    }
  }

  if (allValid) {
    _header('All configuration files are valid');
  } else {
    _header('Validation completed with errors');
    exit(1);
  }
}

/// Run Stage 1 Explorer Agent locally.
/// Gracefully skips if Gemini is unavailable.
Future<void> _runExplore(String repoRoot) async {
  _header('Stage 1: Explorer Agent (Gemini 3 Pro Preview)');

  if (!_geminiAvailable(warnOnly: true)) {
    _warn('Skipping explore stage (Gemini unavailable). No changelog data will be generated.');
    return;
  }

  final ctx = RunContext.create(repoRoot, 'explore');
  final prevTag = _prevTagOverride ?? _detectPrevTag(repoRoot);
  final newVersion = _versionOverride ?? _detectNextVersion(repoRoot, prevTag);

  _info('Previous tag: $prevTag');
  _info('New version: $newVersion');
  _info('Run dir: ${ctx.runDir}');

  // Generate prompt via Dart template
  final promptScriptPath = _promptScript('gemini_changelog_prompt.dart');
  _info('Generating explorer prompt from $promptScriptPath...');
  if (!File(promptScriptPath).existsSync()) {
    _error('Prompt script not found: $promptScriptPath');
    _error('Ensure runtime_ci_tooling is properly installed (dart pub get).');
    exit(1);
  }
  final prompt = _runSync('dart run $promptScriptPath "$prevTag" "$newVersion"', repoRoot);
  if (prompt.isEmpty) {
    _error('Prompt generator produced empty output. Check $promptScriptPath');
    exit(1);
  }
  ctx.savePrompt('explore', prompt);

  if (_dryRun) {
    _info('[DRY-RUN] Would run Gemini CLI with explorer prompt (${prompt.length} chars)');
    return;
  }

  // Write prompt to file for piping
  final promptPath = ctx.artifactPath('explore', 'prompt.txt');

  _info('Running Gemini 3 Pro Preview...');
  final result = Process.runSync(
    'sh',
    [
      '-c',
      'cat $promptPath | gemini '
          '-o json --yolo '
          '-m $kGeminiProModel '
          "--allowed-tools 'run_shell_command(git),run_shell_command(gh)'",
    ],
    workingDirectory: repoRoot,
    environment: {...Platform.environment},
  );

  // Gemini CLI may exit non-zero even when it produces valid JSON output.
  // Common stderr messages like "YOLO mode is enabled" are informational,
  // not errors. We try to extract valid JSON from stdout regardless of
  // the exit code, and only fall back to empty artifacts if that also fails.
  final rawStdout = result.stdout as String;
  final rawStderr = (result.stderr as String).trim();

  if (result.exitCode != 0) {
    _warn('Gemini CLI exited with code ${result.exitCode}');
    if (rawStderr.isNotEmpty) _warn('  stderr: ${rawStderr.split('\n').first}');
  }

  // Save raw response to audit trail (even on non-zero exit -- stdout may have valid data)
  if (rawStdout.isNotEmpty) {
    ctx.saveResponse('explore', rawStdout);
  }

  // Try to parse JSON response from stdout regardless of exit code
  bool geminiSucceeded = false;
  try {
    if (rawStdout.contains('{')) {
      final jsonStr = _extractJson(rawStdout);
      final response = json.decode(jsonStr) as Map<String, dynamic>;
      final stats = response['stats'] as Map<String, dynamic>?;
      geminiSucceeded = true;
      _success('Stage 1 completed.');
      if (stats != null) {
        _info('  Tool calls: ${stats['tools']?['totalCalls']}');
      }
    } else if (result.exitCode != 0) {
      _warn('Gemini CLI produced no JSON output. Using fallback artifacts.');
    }
  } catch (e) {
    _warn('Could not parse Gemini response as JSON: $e');
  }

  ctx.finalize(exitCode: geminiSucceeded ? 0 : result.exitCode);

  // Validate artifacts — Gemini may write to the RunContext dir or to
  // the working directory. Check both locations and copy to /tmp/ for
  // the workflow artifact upload step.
  _info('');
  _info('Validating Stage 1 artifacts...');
  final artifactNames = ['commit_analysis.json', 'pr_data.json', 'breaking_changes.json'];
  for (final name in artifactNames) {
    // Check RunContext path first, then hardcoded fallback
    final ctxPath = '${ctx.runDir}/explore/$name';
    final tmpPath = '/tmp/$name';

    File? source;
    if (File(ctxPath).existsSync()) {
      source = File(ctxPath);
    } else if (File('$repoRoot/$kCicdRunsDir/explore/$name').existsSync()) {
      source = File('$repoRoot/$kCicdRunsDir/explore/$name');
    }

    if (source != null) {
      try {
        final content = source.readAsStringSync();
        json.decode(content);
        _success('Valid: ${source.path} (${source.lengthSync()} bytes)');
        source.copySync(tmpPath);
      } catch (e) {
        _warn('Invalid JSON: ${source.path} -- $e');
        File(tmpPath).writeAsStringSync('{}');
      }
    } else {
      _warn('Missing: $name (Gemini may not have generated this artifact)');
      // Write empty fallback so downstream stages have something to work with
      File(tmpPath).writeAsStringSync('{}');
    }
  }

  _success('Stage 1 complete. Artifacts available in /tmp/ for upload.');

  // Write step summary
  // Build rich step summary with artifact previews
  final commitJson = _readFileOr('/tmp/commit_analysis.json');
  final prJson = _readFileOr('/tmp/pr_data.json');
  final breakingJson = _readFileOr('/tmp/breaking_changes.json');

  _writeStepSummary('''
## Stage 1: Explorer Agent Complete

| Field | Value |
|-------|-------|
| Version | **v$newVersion** |
| Previous tag | ${_compareLink(prevTag, 'HEAD', '`$prevTag...HEAD`')} |
| Gemini model | `$kGeminiProModel` |

${_collapsible('commit_analysis.json', '```json\n$commitJson\n```')}
${_collapsible('pr_data.json', '```json\n$prJson\n```')}
${_collapsible('breaking_changes.json', '```json\n$breakingJson\n```')}

${_artifactLink()}
''');
}

/// Stage 2: Changelog Composer.
///
/// Updates CHANGELOG.md and README.md only. Release notes are handled
/// separately by Stage 3 (_runReleaseNotes).
/// Gracefully skips if Gemini is unavailable.
Future<void> _runCompose(String repoRoot) async {
  _header('Stage 2: Changelog Composer (Gemini Pro)');

  if (!_geminiAvailable(warnOnly: true)) {
    _warn('Skipping changelog composition (Gemini unavailable).');
    return;
  }

  final ctx = RunContext.create(repoRoot, 'compose');
  final prevTag = _prevTagOverride ?? _detectPrevTag(repoRoot);
  final newVersion = _versionOverride ?? _detectNextVersion(repoRoot, prevTag);

  _info('Previous tag: $prevTag');
  _info('New version: $newVersion');
  _info('Run dir: ${ctx.runDir}');

  // Generate prompt via Dart template
  final composerScript = _promptScript('gemini_changelog_composer_prompt.dart');
  _info('Generating composer prompt from $composerScript...');
  if (!File(composerScript).existsSync()) {
    _error('Prompt script not found: $composerScript');
    exit(1);
  }
  final prompt = _runSync('dart run $composerScript "$prevTag" "$newVersion"', repoRoot);
  if (prompt.isEmpty) {
    _error('Composer prompt generator produced empty output.');
    exit(1);
  }
  ctx.savePrompt('compose', prompt);

  if (_dryRun) {
    _info('[DRY-RUN] Would run Gemini CLI with composer prompt (${prompt.length} chars)');
    return;
  }

  final promptPath = ctx.artifactPath('compose', 'prompt.txt');

  // Build the @ includes for file context.
  // Stage 1 artifacts may be at /tmp/ (CI download) or .runtime_ci/runs/explore/ (local).
  final includes = <String>[];
  final artifactNames = ['commit_analysis.json', 'pr_data.json', 'breaking_changes.json'];
  for (final name in artifactNames) {
    if (File('/tmp/$name').existsSync()) {
      includes.add('@/tmp/$name');
    } else if (File('$repoRoot/$kCicdRunsDir/explore/$name').existsSync()) {
      includes.add('@$repoRoot/$kCicdRunsDir/explore/$name');
    }
  }
  // Issue manifest from pre-release-triage
  if (File('/tmp/issue_manifest.json').existsSync()) {
    includes.add('@/tmp/issue_manifest.json');
  }
  includes.add('@CHANGELOG.md');
  includes.add('@README.md');

  _info('Running Gemini 3 Pro for CHANGELOG composition...');
  _info('File context: ${includes.join(", ")}');

  final result = Process.runSync(
    'sh',
    [
      '-c',
      'cat $promptPath | gemini '
          '-o json --yolo '
          '-m $kGeminiProModel '
          "--allowed-tools 'run_shell_command(git),run_shell_command(gh)' "
          '${includes.join(" ")}',
    ],
    workingDirectory: repoRoot,
    environment: {...Platform.environment},
  );

  // Handle non-zero exit gracefully -- try to extract JSON regardless
  final rawCompose = result.stdout as String;
  final composeStderr = (result.stderr as String).trim();

  if (result.exitCode != 0) {
    _warn('Gemini CLI exited with code ${result.exitCode}');
    if (composeStderr.isNotEmpty) _warn('  stderr: ${composeStderr.split('\n').first}');
  }

  if (rawCompose.isNotEmpty) {
    ctx.saveResponse('compose', rawCompose);
  }

  try {
    if (rawCompose.contains('{')) {
      final jsonStr = _extractJson(rawCompose);
      final response = json.decode(jsonStr) as Map<String, dynamic>;
      final stats = response['stats'] as Map<String, dynamic>?;
      _success('Stage 2 completed.');
      if (stats != null) {
        _info('  Tool calls: ${stats['tools']?['totalCalls']}');
        _info('  Duration: ${stats['session']?['duration']}ms');
      }
    } else if (result.exitCode != 0) {
      _warn('Gemini CLI produced no JSON output for compose stage.');
    }
  } catch (e) {
    _warn('Could not parse Gemini response as JSON: $e');
  }

  // Verify CHANGELOG was updated (handle encoding errors from Gemini writes)
  String changelogContent = '';
  try {
    if (File('$repoRoot/CHANGELOG.md').existsSync()) {
      changelogContent = File('$repoRoot/CHANGELOG.md').readAsStringSync();
      if (changelogContent.contains('## [$newVersion]')) {
        _success('CHANGELOG.md updated with v$newVersion entry');
      } else {
        _warn('CHANGELOG.md exists but does not contain a [$newVersion] entry');
      }
    }
  } catch (e) {
    _warn('Could not read CHANGELOG.md (encoding error): $e');
    // Try reading as bytes and converting with replacement
    try {
      final bytes = File('$repoRoot/CHANGELOG.md').readAsBytesSync();
      changelogContent = String.fromCharCodes(bytes.where((b) => b < 128));
      _info('Read CHANGELOG.md with ASCII fallback (${changelogContent.length} chars)');
    } catch (_) {
      changelogContent = '';
    }
  }

  // NOTE: Release notes are generated separately by Stage 3 (_runReleaseNotes).
  // This stage ONLY handles CHANGELOG.md and README.md updates.
  final clEntryMatch = RegExp(
    r'## \[' + RegExp.escape(newVersion) + r'\].*?(?=## \[|\Z)',
    dotAll: true,
  ).firstMatch(changelogContent);
  final clEntry = clEntryMatch?.group(0)?.trim() ?? '(no entry found)';

  _writeStepSummary('''
## Stage 2: Changelog Composer Complete

| Field | Value |
|-------|-------|
| Version | **v$newVersion** |
| CHANGELOG.md | ${changelogContent.contains('## [$newVersion]') ? 'Updated' : 'Not updated'} |
| Gemini model | `$kGeminiProModel` |

${_collapsible('CHANGELOG Entry', '```markdown\n$clEntry\n```', open: true)}

**Next**: Stage 3 (Release Notes Author) generates rich release notes.

${_artifactLink()} | ${_ghLink('CHANGELOG.md', 'CHANGELOG.md')}
''');

  ctx.finalize();
}

/// Stage 3: Release Notes Author.
///
/// Generates rich, narrative release notes distinct from the CHANGELOG.
/// Uses Gemini Pro to study source code, issues, and diffs to produce:
/// - release_notes.md (GitHub Release body)
/// - migration_guide.md (for breaking changes)
/// - linked_issues.json (structured issue linkage)
/// - highlights.md (announcement summary)
///
/// Gracefully skips if Gemini is unavailable.
Future<void> _runReleaseNotes(String repoRoot) async {
  _header('Stage 3: Release Notes Author (Gemini 3 Pro Preview)');

  if (!_geminiAvailable(warnOnly: true)) {
    _warn('Skipping release notes (Gemini unavailable).');
    // Create minimal fallback
    final newVersion = _versionOverride ?? 'unknown';
    final fallback = '# ${config.repoName} v$newVersion\n\nSee CHANGELOG.md for details.';
    File('/tmp/release_notes_body.md').writeAsStringSync(fallback);
    return;
  }

  final ctx = RunContext.create(repoRoot, 'release-notes');
  final prevTag = _prevTagOverride ?? _detectPrevTag(repoRoot);
  final newVersion = _versionOverride ?? _detectNextVersion(repoRoot, prevTag);

  // Derive bump type
  final currentVersion = _runSync("awk '/^version:/{print \$2}' pubspec.yaml", repoRoot);
  final currentParts = currentVersion.split('.');
  final newParts = newVersion.split('.');
  String bumpType = 'minor';
  if (currentParts.length >= 3 && newParts.length >= 3) {
    if (int.tryParse(newParts[0]) != int.tryParse(currentParts[0])) {
      bumpType = 'major';
    } else if (int.tryParse(newParts[1]) != int.tryParse(currentParts[1])) {
      bumpType = 'minor';
    } else {
      bumpType = 'patch';
    }
  }

  _info('Previous tag: $prevTag');
  _info('New version: $newVersion');
  _info('Bump type: $bumpType');
  _info('Run dir: ${ctx.runDir}');

  // ── Gather VERIFIED contributor data BEFORE Gemini runs ──
  final releaseNotesDir = Directory('$repoRoot/$kReleaseNotesDir/v$newVersion');
  releaseNotesDir.createSync(recursive: true);
  final verifiedContributors = _gatherVerifiedContributors(repoRoot, prevTag);
  File(
    '${releaseNotesDir.path}/contributors.json',
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(verifiedContributors));
  _info('Verified contributors: ${verifiedContributors.map((c) => '@${c['username']}').join(', ')}');

  // ── Load issue manifest for verified issue data ──
  List<dynamic> verifiedIssues = [];
  for (final path in ['/tmp/issue_manifest.json', '$repoRoot/$kCicdRunsDir/triage/issue_manifest.json']) {
    if (File(path).existsSync()) {
      try {
        final manifest = json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;
        verifiedIssues = (manifest['github_issues'] as List?) ?? [];
      } catch (_) {}
      break;
    }
  }
  _info('Verified issues: ${verifiedIssues.length}');

  // Generate prompt
  final rnScript = _promptScript('gemini_release_notes_author_prompt.dart');
  _info('Generating release notes prompt from $rnScript...');
  if (!File(rnScript).existsSync()) {
    _error('Prompt script not found: $rnScript');
    exit(1);
  }
  final prompt = _runSync('dart run $rnScript "$prevTag" "$newVersion" "$bumpType"', repoRoot);
  if (prompt.isEmpty) {
    _error('Release notes prompt generator produced empty output.');
    exit(1);
  }
  ctx.savePrompt('release-notes', prompt);

  if (_dryRun) {
    _info('[DRY-RUN] Would run Gemini CLI for release notes (${prompt.length} chars)');
    return;
  }

  final promptPath = ctx.artifactPath('release-notes', 'prompt.txt');

  // Build @ includes -- give Gemini all available context
  final includes = <String>[];
  final artifactNames = ['commit_analysis.json', 'pr_data.json', 'breaking_changes.json'];
  for (final name in artifactNames) {
    if (File('/tmp/$name').existsSync()) {
      includes.add('@/tmp/$name');
    } else if (File('$repoRoot/$kCicdRunsDir/explore/$name').existsSync()) {
      includes.add('@$repoRoot/$kCicdRunsDir/explore/$name');
    }
  }
  if (File('/tmp/issue_manifest.json').existsSync()) {
    includes.add('@/tmp/issue_manifest.json');
  }
  // Include verified contributors for Gemini to reference
  includes.add('@${releaseNotesDir.path}/contributors.json');
  if (File('$repoRoot/CHANGELOG.md').existsSync()) {
    includes.add('@CHANGELOG.md');
  }
  if (File('$repoRoot/$kVersionBumpsDir/v$newVersion.md').existsSync()) {
    includes.add('@$kVersionBumpsDir/v$newVersion.md');
  }

  _info('Running Gemini 3 Pro for release notes authoring...');
  _info('Bump type: $bumpType');
  _info('File context: ${includes.join(", ")}');

  final result = Process.runSync(
    'sh',
    [
      '-c',
      'cat $promptPath | gemini '
          '-o json --yolo '
          '-m $kGeminiProModel '
          // Expanded tool access: git, gh, AND shell commands for reading files
          "--allowed-tools 'run_shell_command(git),run_shell_command(gh),run_shell_command(cat),run_shell_command(head),run_shell_command(tail)' "
          '${includes.join(" ")}',
    ],
    workingDirectory: repoRoot,
    environment: {...Platform.environment},
  );

  if (result.exitCode != 0) {
    _warn('Gemini CLI failed for release notes: ${result.stderr}');
    // Create fallback
    final fallback = '# ${config.repoName} v$newVersion\n\nSee CHANGELOG.md for details.';
    File('/tmp/release_notes_body.md').writeAsStringSync(fallback);
    ctx.finalize(exitCode: result.exitCode);
    return;
  }

  final rawOutput = result.stdout as String;
  ctx.saveResponse('release-notes', rawOutput);

  try {
    final jsonStr = _extractJson(rawOutput);
    final response = json.decode(jsonStr) as Map<String, dynamic>;
    final stats = response['stats'] as Map<String, dynamic>?;
    _success('Stage 3 completed.');
    if (stats != null) {
      _info('  Tool calls: ${stats['tools']?['totalCalls']}');
      _info('  Duration: ${stats['session']?['duration']}ms');
    }
  } catch (e) {
    _warn('Could not parse Gemini response stats: $e');
  }

  // Validate output files
  final releaseNotesFile = File('${releaseNotesDir.path}/release_notes.md');
  final migrationFile = File('${releaseNotesDir.path}/migration_guide.md');
  final linkedIssuesFile = File('${releaseNotesDir.path}/linked_issues.json');
  final highlightsFile = File('${releaseNotesDir.path}/highlights.md');

  if (releaseNotesFile.existsSync()) {
    var content = releaseNotesFile.readAsStringSync();
    _success('Raw release notes: ${content.length} chars');

    // ── POST-PROCESS: Replace Gemini's hallucinated sections with verified data ──
    content = _postProcessReleaseNotes(
      content,
      verifiedContributors: verifiedContributors,
      verifiedIssues: verifiedIssues,
      repoSlug: Platform.environment['GITHUB_REPOSITORY'] ?? '${config.repoOwner}/${config.repoName}',
      repoRoot: repoRoot,
    );
    _success('Post-processed release notes: ${content.length} chars');

    // Write back the cleaned version
    releaseNotesFile.writeAsStringSync(content);
    File('/tmp/release_notes_body.md').writeAsStringSync(content);
    ctx.saveArtifact('release-notes', 'release_notes.md', content);
  } else {
    _warn('Gemini did not produce release_notes.md -- creating from CHANGELOG');
    final fallback = _buildFallbackReleaseNotes(repoRoot, newVersion, prevTag);
    releaseNotesDir.createSync(recursive: true);
    releaseNotesFile.writeAsStringSync(fallback);
    File('/tmp/release_notes_body.md').writeAsStringSync(fallback);
    ctx.saveArtifact('release-notes', 'release_notes.md', fallback);
  }

  if (migrationFile.existsSync()) {
    _success('Migration guide: ${migrationFile.lengthSync()} bytes');
    File('/tmp/migration_guide.md').writeAsStringSync(migrationFile.readAsStringSync());
  } else if (bumpType == 'major') {
    _warn('Major release but no migration guide generated');
  }

  if (linkedIssuesFile.existsSync()) {
    _success('Linked issues: ${linkedIssuesFile.lengthSync()} bytes');
  }

  if (highlightsFile.existsSync()) {
    _success('Highlights: ${highlightsFile.lengthSync()} bytes');
  }

  // Build rich step summary
  final rnContent = releaseNotesFile.existsSync() ? releaseNotesFile.readAsStringSync() : '(not generated)';
  final migContent = migrationFile.existsSync() ? migrationFile.readAsStringSync() : '';
  final linkedContent = linkedIssuesFile.existsSync() ? linkedIssuesFile.readAsStringSync() : '';
  final hlContent = highlightsFile.existsSync() ? highlightsFile.readAsStringSync() : '';

  _writeStepSummary('''
## Stage 3: Release Notes Author Complete

| Field | Value |
|-------|-------|
| Version | **v$newVersion** ($bumpType) |
| Gemini model | `$kGeminiProModel` |
| Release notes | ${releaseNotesFile.existsSync() ? '${releaseNotesFile.lengthSync()} bytes' : 'Not generated'} |
| Migration guide | ${migrationFile.existsSync() ? '${migrationFile.lengthSync()} bytes' : 'N/A'} |
| Linked issues | ${linkedIssuesFile.existsSync() ? '${linkedIssuesFile.lengthSync()} bytes' : 'N/A'} |
| Highlights | ${highlightsFile.existsSync() ? '${highlightsFile.lengthSync()} bytes' : 'N/A'} |

${_collapsible('Release Notes Preview', rnContent, open: true)}
${migContent.isNotEmpty ? _collapsible('Migration Guide', migContent) : ''}
${hlContent.isNotEmpty ? _collapsible('Highlights', hlContent) : ''}
${linkedContent.isNotEmpty ? _collapsible('Linked Issues (JSON)', '```json\n$linkedContent\n```') : ''}

${_artifactLink()}
''');

  ctx.finalize();
}

/// Build fallback release notes from CHANGELOG entry + version bump rationale.
/// Fallback contributor gathering using git log (no GitHub usernames).
/// Gather VERIFIED contributor usernames scoped to the release commit range.
///
/// Uses git log to find unique authors in prevTag..HEAD, then resolves each
/// to a verified GitHub username via the commits API. This ensures:
/// 1. Only contributors who actually committed in THIS release are listed
/// 2. GitHub usernames are verified (not guessed from display names)
/// 3. Bots are excluded
List<Map<String, String>> _gatherVerifiedContributors(String repoRoot, String prevTag) {
  final repo = Platform.environment['GITHUB_REPOSITORY'] ?? '${config.repoOwner}/${config.repoName}';

  // Step 1: Get one commit SHA per unique author email in the release range
  final gitResult = Process.runSync('sh', [
    '-c',
    'git log "$prevTag"..HEAD --format="%H %ae" --no-merges | sort -u -k2,2',
  ], workingDirectory: repoRoot);

  if (gitResult.exitCode != 0) {
    _warn('Could not get commit authors from git log');
    return [];
  }

  final lines = (gitResult.stdout as String).trim().split('\n').where((l) => l.isNotEmpty);
  final contributors = <Map<String, String>>[];
  final seenLogins = <String>{};

  for (final line in lines) {
    final parts = line.split(' ');
    if (parts.length < 2) continue;
    final sha = parts[0];
    final email = parts[1];

    // Skip bot emails
    if (email.contains('[bot]') || email.contains('noreply.github.com') && email.contains('bot')) continue;

    // Step 2: Resolve SHA to verified GitHub login via commits API
    try {
      final ghResult = Process.runSync('gh', [
        'api',
        'repos/$repo/commits/$sha',
        '--jq',
        '.author.login // empty',
      ], workingDirectory: repoRoot);

      if (ghResult.exitCode == 0) {
        final login = (ghResult.stdout as String).trim();
        if (login.isNotEmpty && !login.contains('[bot]') && !seenLogins.contains(login)) {
          seenLogins.add(login);
          contributors.add({'username': login});
        }
      }
    } catch (_) {
      // API call failed for this SHA, skip
    }
  }

  if (contributors.isEmpty) {
    _warn('No contributors resolved from GitHub API, falling back to git names');
    // Fallback: use git display names without usernames
    final names = (gitResult.stdout as String)
        .trim()
        .split('\n')
        .where((l) => l.isNotEmpty && !l.contains('[bot]'))
        .map((l) => l.split(' ').length > 1 ? l.split(' ')[1] : l)
        .toSet()
        .map<Map<String, String>>((email) => {'username': email.split('@').first})
        .toList();
    return names;
  }

  return contributors;
}

/// Post-process Gemini's release notes to replace hallucinated data with verified data.
///
/// Replaces:
/// - Contributors section with verified GitHub usernames
/// - Issues Addressed section with verified issue manifest data
/// - Strips fabricated (#N) references that don't exist in the repo
String _postProcessReleaseNotes(
  String content, {
  required List<Map<String, String>> verifiedContributors,
  required List<dynamic> verifiedIssues,
  required String repoSlug,
  required String repoRoot,
}) {
  var result = content;

  // ── Replace Contributors section ──
  final contributorsSection = StringBuffer();
  contributorsSection.writeln('## Contributors');
  contributorsSection.writeln();
  if (verifiedContributors.isNotEmpty) {
    contributorsSection.writeln('Thanks to everyone who contributed to this release:');
    for (final c in verifiedContributors) {
      final username = c['username'] ?? '';
      if (username.isNotEmpty) {
        contributorsSection.writeln('- @$username');
      }
    }
  } else {
    contributorsSection.writeln('No contributor data available.');
  }

  // Replace the existing Contributors section (match from ## Contributors to next ## or end)
  result = result.replaceFirstMapped(
    RegExp(r'## Contributors.*?(?=\n## |\n---|\Z)', dotAll: true),
    (m) => contributorsSection.toString().trim(),
  );

  // ── Replace Issues Addressed section ──
  final issuesSection = StringBuffer();
  issuesSection.writeln('## Issues Addressed');
  issuesSection.writeln();
  if (verifiedIssues.isNotEmpty) {
    for (final issue in verifiedIssues) {
      final number = issue['number'];
      final title = issue['title'] ?? '';
      final confidence = issue['confidence'] ?? 0.0;
      issuesSection.writeln(
        '- [#$number](https://github.com/$repoSlug/issues/$number) — $title (confidence: ${(confidence * 100).toStringAsFixed(0)}%)',
      );
    }
  } else {
    issuesSection.writeln('No linked issues for this release.');
  }

  result = result.replaceFirstMapped(
    RegExp(r'## Issues Addressed.*?(?=\n## |\n---|\Z)', dotAll: true),
    (m) => issuesSection.toString().trim(),
  );

  // ── Validate issue references throughout the document ──
  // Find all (#N) patterns and validate they exist
  final issueRefs = RegExp(r'\(#(\d+)\)').allMatches(result).map((m) => int.parse(m.group(1)!)).toSet();
  if (issueRefs.isNotEmpty) {
    final validIssues = verifiedIssues.map((i) => i['number'] as int? ?? 0).toSet();
    final fabricated = issueRefs.difference(validIssues);

    if (fabricated.isNotEmpty) {
      _warn('Stripping ${fabricated.length} fabricated issue references: ${fabricated.map((n) => "#$n").join(", ")}');
      for (final num in fabricated) {
        // Remove the link but keep descriptive text: "[#N](url) — desc" → "desc"
        result = result.replaceAll(RegExp(r'- \[#' + num.toString() + r'\]\([^)]*\)[^\n]*\n'), '');
        // Remove inline (#N) references
        result = result.replaceAll('(#$num)', '');
      }
    }
  }

  return result;
}

String _buildFallbackReleaseNotes(String repoRoot, String version, String prevTag) {
  final buf = StringBuffer();
  buf.writeln('# ${config.repoName} v$version');
  buf.writeln();

  // Try version bump rationale
  final bumpFile = File('$repoRoot/$kVersionBumpsDir/v$version.md');
  if (bumpFile.existsSync()) {
    buf.writeln(bumpFile.readAsStringSync());
    buf.writeln();
  }

  // Try CHANGELOG entry
  final changelog = File('$repoRoot/CHANGELOG.md');
  if (changelog.existsSync()) {
    final content = changelog.readAsStringSync();
    final entryMatch = RegExp(
      r'## \[' + RegExp.escape(version) + r'\].*?(?=## \[|\Z)',
      dotAll: true,
    ).firstMatch(content);
    if (entryMatch != null) {
      buf.writeln('## Changelog');
      buf.writeln();
      buf.writeln(entryMatch.group(0)!.trim());
      buf.writeln();
    }
  }

  buf.writeln('---');
  buf.writeln(
    '[Full Changelog](https://github.com/${config.repoOwner}/${config.repoName}/compare/$prevTag...v$version)',
  );

  return buf.toString();
}

// ═══════════════════════════════════════════════════════════════════════════════
// Autodoc: Config-driven documentation generation
// ═══════════════════════════════════════════════════════════════════════════════

/// Generate/update documentation for proto modules using Gemini Pro.
///
/// Uses autodoc.json for configuration, hash-based change detection for
/// incremental updates, and parallel Gemini execution.
///
/// Options:
///   --force       Regenerate all docs regardless of hash
///   --module <id> Only generate for a specific module
///   --dry-run     Show what would be generated without running Gemini
///   --init        Scan repo and create initial autodoc.json
Future<void> _runAutodoc(String repoRoot, List<String> args) async {
  _header('Autodoc: Documentation Generation');

  final force = args.contains('--force');
  final dryRun = args.contains('--dry-run') || _dryRun;
  final init = args.contains('--init');
  String? targetModule;
  final modIdx = args.indexOf('--module');
  if (modIdx != -1 && modIdx + 1 < args.length) targetModule = args[modIdx + 1];

  final configPath = '$repoRoot/autodoc.json';

  if (init) {
    _info('--init: autodoc.json should be created manually or already exists.');
    if (File(configPath).existsSync()) {
      _success('autodoc.json exists at $configPath');
    } else {
      _error('autodoc.json not found. Create it at $configPath');
    }
    return;
  }

  if (!File(configPath).existsSync()) {
    _error('autodoc.json not found. Run: dart run scripts/manage_cicd.dart autodoc --init');
    return;
  }

  // Load config
  final configContent = File(configPath).readAsStringSync();
  final config = json.decode(configContent) as Map<String, dynamic>;
  final modules = (config['modules'] as List).cast<Map<String, dynamic>>();
  final maxConcurrent = (config['max_concurrent'] as int?) ?? 4;
  final templates = (config['templates'] as Map<String, dynamic>?) ?? {};

  if (!_geminiAvailable(warnOnly: true)) {
    _warn('Gemini unavailable -- skipping autodoc generation.');
    return;
  }

  // Build task queue based on hash comparison
  final tasks = <Future<void>>[];
  final updatedModules = <String>[];
  var skippedCount = 0;

  for (final module in modules) {
    final id = module['id'] as String;
    if (targetModule != null && id != targetModule) continue;

    final sourcePaths = (module['source_paths'] as List).cast<String>();
    final currentHash = _computeModuleHash(repoRoot, sourcePaths);
    final previousHash = module['hash'] as String? ?? '';

    if (currentHash == previousHash && !force) {
      skippedCount++;
      if (_verbose) _info('  $id: unchanged, skipping');
      continue;
    }

    final name = module['name'] as String;
    final outputPath = '$repoRoot/${module['output_path']}';
    final libPaths = (module['lib_paths'] as List?)?.cast<String>() ?? [];
    final generateTypes = (module['generate'] as List).cast<String>();
    final libDir = libPaths.isNotEmpty ? '$repoRoot/${libPaths.first}' : '';

    _info('  $id ($name): ${force ? "forced" : "changed"} -> generating ${generateTypes.join(", ")}');

    if (dryRun) {
      updatedModules.add(id);
      continue;
    }

    // Create output directory
    Directory(outputPath).createSync(recursive: true);

    // Queue Gemini tasks for each doc type
    for (final docType in generateTypes) {
      final templateKey = docType;
      final templatePath = templates[templateKey] as String?;
      if (templatePath == null) {
        _warn('  No template for doc type: $docType');
        continue;
      }

      tasks.add(
        _generateAutodocFile(
          repoRoot: repoRoot,
          moduleId: id,
          moduleName: name,
          docType: docType,
          templatePath: templatePath,
          sourceDir: '$repoRoot/${sourcePaths.first}',
          libDir: libDir,
          outputPath: outputPath,
          previousHash: previousHash,
        ),
      );
    }

    updatedModules.add(id);
    // Update hash
    module['hash'] = currentHash;
    module['last_updated'] = DateTime.now().toUtc().toIso8601String();
  }

  if (dryRun) {
    _info('');
    _info('[DRY-RUN] Would generate docs for ${updatedModules.length} modules, skipped $skippedCount unchanged');
    for (final id in updatedModules) {
      _info('  - $id');
    }
    return;
  }

  if (tasks.isEmpty) {
    _success('All $skippedCount modules unchanged. Nothing to generate.');
    return;
  }

  // Execute in parallel batches
  _info('');
  _info('Running ${tasks.length} Gemini doc generation tasks (max $maxConcurrent parallel)...');

  // Simple batching: process maxConcurrent at a time
  for (var i = 0; i < tasks.length; i += maxConcurrent) {
    final batch = tasks.skip(i).take(maxConcurrent).toList();
    await Future.wait(batch);
  }

  // Save updated config with new hashes
  File(configPath).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(config));

  _success('Generated docs for ${updatedModules.length} modules, skipped $skippedCount unchanged.');
  _info('Updated hashes saved to autodoc.json');

  _writeStepSummary('''
## Autodoc: Documentation Generation

| Metric | Value |
|--------|-------|
| Modules updated | ${updatedModules.length} |
| Modules skipped | $skippedCount |
| Total tasks | ${tasks.length} |

### Updated Modules
${updatedModules.map((id) => '- `$id`').join('\n')}

${_artifactLink()}
''');
}

/// Generate a single autodoc file using a two-pass Gemini pipeline:
///   Pass 1 (Author): Generates the initial documentation from proto/source analysis.
///   Pass 2 (Reviewer): Fact-checks, corrects Dart naming conventions, fills gaps,
///     and enhances detail/coverage.
Future<void> _generateAutodocFile({
  required String repoRoot,
  required String moduleId,
  required String moduleName,
  required String docType,
  required String templatePath,
  required String sourceDir,
  required String libDir,
  required String outputPath,
  required String previousHash,
}) async {
  final outputFileName = switch (docType) {
    'quickstart' => 'QUICKSTART.md',
    'api_reference' => 'API_REFERENCE.md',
    'examples' => 'EXAMPLES.md',
    'migration' => 'MIGRATION.md',
    _ => '$docType.md',
  };

  final absOutputFile = '$outputPath/$outputFileName';

  _info('  [$moduleId] Pass 1: Generating $outputFileName...');

  // Generate prompt from template
  final promptArgs = [moduleName, sourceDir];
  if (libDir.isNotEmpty) promptArgs.add(libDir);
  if (docType == 'migration' && previousHash.isNotEmpty) promptArgs.add(previousHash);

  final prompt = _runSync('dart run $repoRoot/$templatePath ${promptArgs.map((a) => '"$a"').join(' ')}', repoRoot);

  if (prompt.isEmpty) {
    _warn('  [$moduleId] Empty prompt for $docType, skipping');
    return;
  }

  // Build context includes: always include source dir, optionally lib dir
  final includes = <String>['@${sourceDir.replaceFirst('$repoRoot/', '')}'];
  if (libDir.isNotEmpty) {
    final relLib = libDir.replaceFirst('$repoRoot/', '');
    if (Directory(libDir).existsSync()) includes.add('@$relLib');
  }

  // ═══════════════════════════════════════════════════════════════════
  // PASS 1: Author -- generate the initial documentation
  // ═══════════════════════════════════════════════════════════════════
  final pass1Prompt = File('$outputPath/.${docType}_pass1.txt');
  pass1Prompt.writeAsStringSync('''
$prompt

## OUTPUT INSTRUCTIONS

Write the generated documentation to this exact file path using write_file:
  $absOutputFile

Be extremely thorough and detailed. Read ALL proto files and ALL generated
Dart code in the included context directories before writing.

CRITICAL Dart naming rules for protobuf-generated code:
- Proto field names with underscores (e.g., batch_id, send_at, mail_settings)
  become camelCase in Dart (e.g., batchId, sendAt, mailSettings).
- Always use camelCase for Dart field access in code examples.
- Message/Enum names stay PascalCase as defined in the proto.

Cover EVERY message, service, enum, and field defined in the proto files.
Do not skip any -- completeness is more important than brevity.
''');

  final pass1Result = Process.runSync(
    'sh',
    ['-c', 'cat ${pass1Prompt.path} | gemini --yolo -m $kGeminiProModel ${includes.join(" ")}'],
    workingDirectory: repoRoot,
    environment: {...Platform.environment},
  );

  if (pass1Prompt.existsSync()) pass1Prompt.deleteSync();

  if (pass1Result.exitCode != 0) {
    _warn('  [$moduleId] Pass 1 failed: ${(pass1Result.stderr as String).trim()}');
    return;
  }

  final outputFile = File(absOutputFile);
  if (!outputFile.existsSync() || outputFile.lengthSync() < 100) {
    _warn('  [$moduleId] Pass 1 did not produce $outputFileName');
    return;
  }

  final pass1Size = outputFile.lengthSync();
  _info('  [$moduleId] Pass 1 complete: $pass1Size bytes');

  // ═══════════════════════════════════════════════════════════════════
  // PASS 2: Reviewer -- fact-check, correct, and enhance
  // ═══════════════════════════════════════════════════════════════════
  _info('  [$moduleId] Pass 2: Reviewing $outputFileName...');

  final pass2Prompt = File('$outputPath/.${docType}_pass2.txt');
  pass2Prompt.writeAsStringSync('''
You are a senior technical reviewer for Dart/protobuf documentation.

Your task is to review and improve the file at:
  $absOutputFile

This documentation was auto-generated for the **$moduleName** module.
The proto definitions are in: ${sourceDir.replaceFirst('$repoRoot/', '')}
${libDir.isNotEmpty ? 'Generated Dart code is in: ${libDir.replaceFirst('$repoRoot/', '')}' : ''}

## Review Checklist

### 1. Dart Naming Conventions (CRITICAL)
Protobuf-generated Dart code converts snake_case field names to camelCase:
  - batch_id -> batchId
  - send_at -> sendAt
  - mail_settings -> mailSettings
  - tracking_settings -> trackingSettings
  - click_tracking -> clickTracking
  - open_tracking -> openTracking
  - sandbox_mode -> sandboxMode
  - dynamic_template_data -> dynamicTemplateData
  - content_id -> contentId
  - custom_args -> customArgs
  - ip_pool_name -> ipPoolName
  - reply_to -> replyTo
  - reply_to_list -> replyToList
  - template_id -> templateId
  - enable_text -> enableText
  - substitution_tag -> substitutionTag
  - group_id -> groupId
  - groups_to_display -> groupsToDisplay

Fix ALL instances where snake_case is used for Dart field access in code blocks.
Message and enum names remain PascalCase (e.g., SendMailRequest, MailFrom).

### 2. Completeness
Read ALL proto definitions in the source directory. Ensure the documentation
covers every service RPC, every message type, every enum, and every field.
If anything is missing, add it with proper examples.

### 3. Code Correctness
- Every code block must use valid Dart syntax
- Import paths must be real: package:${config.repoName}/...
- Cascade notation (..field = value) must use the correct camelCase field name
- No fabricated class names, methods, or fields

### 4. Detail and Quality
- Add examples for any under-documented features
- Include proto field comments as documentation in the code examples
- Show the builder pattern (cascade ..) for constructing messages
- Cover edge cases and optional fields

## Instructions

Read the proto files, read the current documentation file, then use edit_file
to make all necessary corrections and enhancements in-place.
Write the corrected file to the same path: $absOutputFile
''');

  final pass2Result = Process.runSync(
    'sh',
    ['-c', 'cat ${pass2Prompt.path} | gemini --yolo -m $kGeminiProModel ${includes.join(" ")}'],
    workingDirectory: repoRoot,
    environment: {...Platform.environment},
  );

  if (pass2Prompt.existsSync()) pass2Prompt.deleteSync();

  if (pass2Result.exitCode != 0) {
    _warn('  [$moduleId] Pass 2 failed (keeping Pass 1 output): ${(pass2Result.stderr as String).trim()}');
  }

  // Verify final output
  if (outputFile.existsSync() && outputFile.lengthSync() > 100) {
    final finalSize = outputFile.lengthSync();
    final delta = finalSize - pass1Size;
    final deltaStr = delta >= 0 ? '+$delta' : '$delta';
    _success('  [$moduleId] $outputFileName: $finalSize bytes ($deltaStr from review)');
    return;
  }

  _warn('  [$moduleId] No $outputFileName produced');
}

/// Compute SHA256 hash of all source files in the given paths.
String _computeModuleHash(String repoRoot, List<String> sourcePaths) {
  // Use git to compute a hash of the directory contents
  final paths = sourcePaths.map((p) => '$repoRoot/$p').join(' ');
  final result = Process.runSync('sh', [
    '-c',
    'find $paths -type f \\( -name "*.proto" -o -name "*.dart" \\) 2>/dev/null | sort | xargs cat 2>/dev/null | sha256sum | cut -d" " -f1',
  ], workingDirectory: repoRoot);
  if (result.exitCode == 0) {
    return (result.stdout as String).trim();
  }
  // Fallback: timestamp-based
  return DateTime.now().millisecondsSinceEpoch.toString();
}

/// Run issue triage on a specific issue.
/// Delegate triage to the modular triage CLI (scripts/triage/triage_cli.dart).
///
/// Supports:
///   triage <N>       -- Triage a single issue
///   triage --auto    -- Auto-triage all open untriaged issues
///   triage --status  -- Show triage status
Future<void> _runTriageCli(String repoRoot, List<String> triageArgs) async {
  _requireGeminiCli();
  _requireApiKey();

  if (triageArgs.isEmpty) {
    _error('Usage:');
    _error('  dart run scripts/manage_cicd.dart triage <issue_number>');
    _error('  dart run scripts/manage_cicd.dart triage --auto');
    _error('  dart run scripts/manage_cicd.dart triage --status');
    exit(1);
  }

  // Forward flags from manage_cicd to triage_cli
  final forwardedArgs = [...triageArgs];
  if (_dryRun) forwardedArgs.add('--dry-run');
  if (_verbose) forwardedArgs.add('--verbose');

  _info('Delegating to triage CLI: dart run scripts/triage/triage_cli.dart ${forwardedArgs.join(" ")}');

  final result = await Process.run(
    'dart',
    ['run', 'scripts/triage/triage_cli.dart', ...forwardedArgs],
    workingDirectory: repoRoot,
    environment: {...Platform.environment},
  );

  // Stream output
  final stdout = (result.stdout as String).trim();
  if (stdout.isNotEmpty) print(stdout);

  final stderr = (result.stderr as String).trim();
  if (stderr.isNotEmpty) _error(stderr);

  if (result.exitCode != 0) {
    exit(result.exitCode);
  }
}

/// Run the full release pipeline locally.
Future<void> _runRelease(String repoRoot) async {
  _header('Full Release Pipeline');

  // Step 1: Version
  await _runVersion(repoRoot);

  // Step 2: Explore
  await _runExplore(repoRoot);

  // Step 3: Compose
  await _runCompose(repoRoot);

  _header('Release pipeline complete');
  _info('Next steps:');
  _info('  1. Review CHANGELOG.md changes');
  _info('  2. Review /tmp/release_notes_body.md');
  _info('  3. Commit and push to main to trigger CI/CD');
}

/// Determine the next SemVer version.
Future<void> _runVersion(String repoRoot) async {
  _header('Version Detection');

  final prevTag = _prevTagOverride ?? _detectPrevTag(repoRoot);
  final newVersion = _versionOverride ?? _detectNextVersion(repoRoot, prevTag);
  final currentVersion = _runSync("awk '/^version:/{print \$2}' pubspec.yaml", repoRoot);

  _info('Current version (pubspec.yaml): $currentVersion');
  _info('Previous tag: $prevTag');
  _info('Next version: $newVersion');

  // Save version bump rationale if Gemini produced one
  final rationaleFile = File('$repoRoot/$kCicdRunsDir/version_analysis/version_bump_rationale.md');
  if (rationaleFile.existsSync()) {
    final bumpDir = Directory('$repoRoot/$kVersionBumpsDir');
    bumpDir.createSync(recursive: true);
    final targetPath = '${bumpDir.path}/v$newVersion.md';
    rationaleFile.copySync(targetPath);
    _success('Version bump rationale saved to $kVersionBumpsDir/v$newVersion.md');
  }
}

/// Configure MCP servers in .gemini/settings.json.
Future<void> _runConfigureMcp(String repoRoot) async {
  _header('Configuring MCP Servers');

  final settingsPath = '$repoRoot/.gemini/settings.json';
  final settingsFile = File(settingsPath);

  Map<String, dynamic> settings;
  try {
    settings = json.decode(settingsFile.readAsStringSync()) as Map<String, dynamic>;
  } catch (e) {
    _error('Could not read .gemini/settings.json: $e');
    exit(1);
  }

  // Add MCP servers configuration
  final mcpServers = <String, dynamic>{};

  // GitHub MCP Server
  final ghToken =
      Platform.environment['GH_TOKEN'] ?? Platform.environment['GITHUB_TOKEN'] ?? Platform.environment['GITHUB_PAT'];

  if (ghToken != null && ghToken.isNotEmpty) {
    _info('Configuring GitHub MCP server...');
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
    _success('GitHub MCP server configured');
  } else {
    _warn('No GitHub token found. Set GH_TOKEN or GITHUB_PAT to configure GitHub MCP.');
    _info('  export GH_TOKEN=<your-github-personal-access-token>');
  }

  // Sentry MCP Server (remote, no local install needed)
  _info('Configuring Sentry MCP server (remote)...');
  mcpServers['sentry'] = {'url': 'https://mcp.sentry.dev/mcp'};
  _success('Sentry MCP server configured (uses OAuth -- browser auth on first use)');

  // Write updated settings
  settings['mcpServers'] = mcpServers;

  if (_dryRun) {
    _info('[DRY-RUN] Would write MCP configuration:');
    _info(const JsonEncoder.withIndent('  ').convert(settings));
    return;
  }

  settingsFile.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(settings)}\n');
  _success('Updated .gemini/settings.json with MCP servers');

  _info('');
  _info('To verify MCP servers, run: gemini /mcp');
  _info('GitHub MCP tools will be available as: github__<tool_name>');
  _info('Sentry MCP tools will be available as: sentry__<tool_name>');
}

/// Show current CI/CD configuration status.
Future<void> _runStatus(String repoRoot) async {
  _header('CI/CD Configuration Status');

  // Check files
  _info('Configuration files:');
  for (final file in kConfigFiles) {
    final exists = File('$repoRoot/$file').existsSync();
    if (exists) {
      _success('  $file');
    } else {
      _error('  $file (MISSING)');
    }
  }

  // Check tools
  _info('');
  _info('Required tools:');
  for (final tool in [...kRequiredTools, ...kOptionalTools]) {
    if (_commandExists(tool)) {
      final version = _runSync('$tool --version 2>/dev/null || echo "installed"', repoRoot);
      _success('  $tool: $version');
    } else {
      _error('  $tool: NOT INSTALLED');
    }
  }

  // Check environment
  _info('');
  _info('Environment:');
  final geminiKey = Platform.environment['GEMINI_API_KEY'];
  _info('  GEMINI_API_KEY: ${geminiKey != null ? "set (${geminiKey.length} chars)" : "NOT SET"}');
  final ghToken = Platform.environment['GH_TOKEN'] ?? Platform.environment['GITHUB_TOKEN'];
  _info('  GitHub token: ${ghToken != null ? "set" : "NOT SET"}');

  // Check MCP servers
  _info('');
  _info('MCP servers:');
  try {
    final settings = json.decode(File('$repoRoot/.gemini/settings.json').readAsStringSync());
    final mcpServers = settings['mcpServers'] as Map<String, dynamic>?;
    if (mcpServers != null && mcpServers.isNotEmpty) {
      for (final server in mcpServers.keys) {
        _success('  $server: configured');
      }
    } else {
      _info('  No MCP servers configured. Run: dart run scripts/manage_cicd.dart configure-mcp');
    }
  } catch (_) {
    _info('  Could not read MCP configuration');
  }

  // Check Stage 1 artifacts
  _info('');
  _info('Stage 1 artifacts:');
  for (final artifact in kStage1Artifacts) {
    if (File(artifact).existsSync()) {
      final size = File(artifact).lengthSync();
      _success('  $artifact ($size bytes)');
    } else {
      _info('  $artifact (not present)');
    }
  }

  // Show version info
  _info('');
  final currentVersion = _runSync("awk '/^version:/{print \$2}' pubspec.yaml", repoRoot);
  final prevTag = _detectPrevTag(repoRoot);
  _info('Package version: $currentVersion');
  _info('Latest tag: $prevTag');
}

// ═══════════════════════════════════════════════════════════════════════════════
// New CI Commands
// ═══════════════════════════════════════════════════════════════════════════════

/// Determine version bump with Gemini analysis and output for CI.
///
/// Replaces the 130+ lines of inline bash in release.yaml.
/// Outputs JSON to stdout. With --output-github-actions, also writes to $GITHUB_OUTPUT.
Future<void> _runDetermineVersion(String repoRoot, List<String> args) async {
  _header('Determine Version');

  final outputGha = args.contains('--output-github-actions');

  final prevTag = _prevTagOverride ?? _detectPrevTag(repoRoot);
  final newVersion = _versionOverride ?? _detectNextVersion(repoRoot, prevTag);
  final currentVersion = _runSync("awk '/^version:/{print \$2}' pubspec.yaml", repoRoot);
  final shouldRelease = newVersion != currentVersion;

  _info('Current version: $currentVersion');
  _info('Previous tag: $prevTag');
  _info('New version: $newVersion');
  _info('Should release: $shouldRelease');

  // Save version bump rationale if Gemini produced one
  if (shouldRelease) {
    final rationaleFile = File('$repoRoot/$kCicdRunsDir/version_analysis/version_bump_rationale.md');
    final bumpDir = Directory('$repoRoot/$kVersionBumpsDir');
    bumpDir.createSync(recursive: true);
    final targetPath = '${bumpDir.path}/v$newVersion.md';

    if (rationaleFile.existsSync()) {
      rationaleFile.copySync(targetPath);
      _success('Version bump rationale saved to $kVersionBumpsDir/v$newVersion.md');
    } else {
      // Generate basic rationale
      final commitCount = _runSync('git rev-list --count "$prevTag"..HEAD 2>/dev/null', repoRoot);
      final commits = _runSync('git log "$prevTag"..HEAD --oneline --no-merges 2>/dev/null | head -20', repoRoot);
      File(targetPath).writeAsStringSync(
        '# Version Bump: v$newVersion\n\n'
        '**Date**: ${DateTime.now().toUtc().toIso8601String()}\n'
        '**Previous**: $prevTag\n'
        '**Commits**: $commitCount\n\n'
        '## Commits\n\n$commits\n',
      );
      _success('Basic version rationale saved to $kVersionBumpsDir/v$newVersion.md');
    }
  }

  // Output JSON to stdout
  final result = json.encode({
    'prev_tag': prevTag,
    'current_version': currentVersion,
    'new_version': newVersion,
    'should_release': shouldRelease,
  });
  print(result);

  // Write to $GITHUB_OUTPUT if in CI
  if (outputGha) {
    final ghOutput = Platform.environment['GITHUB_OUTPUT'];
    if (ghOutput != null && ghOutput.isNotEmpty) {
      final file = File(ghOutput);
      file.writeAsStringSync(
        'prev_tag=$prevTag\n'
        'new_version=$newVersion\n'
        'should_release=$shouldRelease\n',
        mode: FileMode.append,
      );
      _success('Wrote outputs to \$GITHUB_OUTPUT');
    }
  }

  // Derive bump type from version comparison
  final currentParts = currentVersion.split('.');
  final newParts = newVersion.split('.');
  String bumpType = 'unknown';
  if (currentParts.length >= 3 && newParts.length >= 3) {
    if (int.tryParse(newParts[0]) != int.tryParse(currentParts[0])) {
      bumpType = 'major';
    } else if (int.tryParse(newParts[1]) != int.tryParse(currentParts[1])) {
      bumpType = 'minor';
    } else {
      bumpType = 'patch';
    }
  }

  // Read version bump rationale for summary
  final rationaleContent = _readFileOr('$repoRoot/$kVersionBumpsDir/v$newVersion.md');

  _writeStepSummary('''
## Version Determination

| Field | Value |
|-------|-------|
| Previous tag | `$prevTag` |
| Current version | `$currentVersion` |
| New version | **`$newVersion`** |
| Bump type | `$bumpType` |
| Should release | $shouldRelease |
| Method | ${_commandExists('gemini') && Platform.environment['GEMINI_API_KEY'] != null ? 'Gemini analysis' : 'Regex heuristic'} |
| Commits | ${_compareLink(prevTag, 'HEAD', 'View diff')} |

${_collapsible('Version Bump Rationale', rationaleContent, open: true)}

${_artifactLink()}
''');
}

/// Create a GitHub release: copy artifacts, save release notes folder, commit, tag, gh release create.
///
/// Replaces 5 bash blocks in the create-release job.
Future<void> _runCreateRelease(String repoRoot, List<String> args) async {
  _header('Create Release');

  // Parse args
  String? artifactsDir;
  String? repo;
  final adIdx = args.indexOf('--artifacts-dir');
  if (adIdx != -1 && adIdx + 1 < args.length) artifactsDir = args[adIdx + 1];
  final repoIdx = args.indexOf('--repo');
  if (repoIdx != -1 && repoIdx + 1 < args.length) repo = args[repoIdx + 1];

  final newVersion = _versionOverride;
  if (newVersion == null) {
    _error('--version <ver> is required for create-release');
    exit(1);
  }

  final prevTag = _prevTagOverride ?? _detectPrevTag(repoRoot);
  final tag = 'v$newVersion';
  final effectiveRepo = repo ?? Platform.environment['GITHUB_REPOSITORY'] ?? '';

  // Step 1: Copy artifacts if provided
  if (artifactsDir != null) {
    final artDir = Directory('$repoRoot/$artifactsDir');
    if (artDir.existsSync()) {
      for (final name in ['CHANGELOG.md', 'README.md']) {
        final src = File('${artDir.path}/$name');
        if (src.existsSync()) {
          src.copySync('$repoRoot/$name');
          _info('Copied $name from artifacts');
        }
      }
    }
  }

  // Step 2: Bump version in pubspec.yaml
  final pubspecFile = File('$repoRoot/pubspec.yaml');
  final pubspecContent = pubspecFile.readAsStringSync();
  pubspecFile.writeAsStringSync(
    pubspecContent.replaceFirst(RegExp(r'^version: .*', multiLine: true), 'version: $newVersion'),
  );
  _info('Bumped pubspec.yaml to version $newVersion');

  // Step 3: Assemble release notes folder from Stage 3 artifacts
  final releaseDir = Directory('$repoRoot/$kReleaseNotesDir/v$newVersion');
  releaseDir.createSync(recursive: true);

  // Copy Stage 3 release notes — check multiple possible locations
  // (different paths depending on CI artifact download vs local run)
  final releaseNotesSearchPaths = [
    '${releaseDir.path}/release_notes.md', // Already in place from workflow copy
    '$repoRoot/release-notes-artifacts/release_notes/v$newVersion/release_notes.md', // Direct artifact download
    '/tmp/release_notes_body.md', // Copied by workflow Prepare step
    '$repoRoot/${artifactsDir ?? "."}/release_notes_body.md', // From composed-artifacts
  ];

  File? foundReleaseNotes;
  for (final path in releaseNotesSearchPaths) {
    final f = File(path);
    if (f.existsSync() && f.lengthSync() > 100) {
      foundReleaseNotes = f;
      _info('Found release notes at: $path (${f.lengthSync()} bytes)');
      break;
    }
  }

  if (foundReleaseNotes != null && foundReleaseNotes.path != '${releaseDir.path}/release_notes.md') {
    foundReleaseNotes.copySync('${releaseDir.path}/release_notes.md');
    _info('Copied release notes to ${releaseDir.path}/release_notes.md');
  } else if (foundReleaseNotes == null) {
    File(
      '${releaseDir.path}/release_notes.md',
    ).writeAsStringSync(_buildFallbackReleaseNotes(repoRoot, newVersion, prevTag));
    _warn('No Stage 3 release notes found -- generated fallback');
  }

  // Copy Stage 3 migration guide if it exists
  final migrationSearchPaths = [
    '${releaseDir.path}/migration_guide.md',
    '$repoRoot/release-notes-artifacts/release_notes/v$newVersion/migration_guide.md',
    '/tmp/migration_guide.md',
  ];
  for (final path in migrationSearchPaths) {
    final f = File(path);
    if (f.existsSync() && f.lengthSync() > 50) {
      if (path != '${releaseDir.path}/migration_guide.md') {
        f.copySync('${releaseDir.path}/migration_guide.md');
      }
      _info('Migration guide: ${f.lengthSync()} bytes');
      break;
    }
  }

  // Copy Stage 3 linked issues if it exists, otherwise create minimal
  final existingLinked = File('${releaseDir.path}/linked_issues.json');
  if (!existingLinked.existsSync()) {
    File(
      '${releaseDir.path}/linked_issues.json',
    ).writeAsStringSync('{"version":"$newVersion","github_issues":[],"sentry_issues":[],"prs_referenced":[]}');
  }

  // Copy Stage 3 highlights if it exists
  final existingHighlights = File('${releaseDir.path}/highlights.md');
  if (existingHighlights.existsSync()) {
    _info('Highlights: ${existingHighlights.lengthSync()} bytes');
  }

  // Extract changelog entry for the folder
  final changelog = File('$repoRoot/CHANGELOG.md');
  if (changelog.existsSync()) {
    final content = changelog.readAsStringSync();
    final entryMatch = RegExp('## \\[$newVersion\\].*?(?=## \\[|\\Z)', dotAll: true).firstMatch(content);
    File(
      '${releaseDir.path}/changelog_entry.md',
    ).writeAsStringSync(entryMatch?.group(0)?.trim() ?? '## [$newVersion]\n');
  }

  // Contributors: use the single verified source of truth
  final contribs = _gatherVerifiedContributors(repoRoot, prevTag);
  File('${releaseDir.path}/contributors.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(contribs));

  _success('Release notes assembled in $kReleaseNotesDir/v$newVersion/');

  if (_dryRun) {
    _info('[DRY-RUN] Would commit, tag, and create GitHub Release');
    return;
  }

  // Step 4: Commit all changes
  _exec('git', ['config', 'user.name', 'github-actions[bot]'], cwd: repoRoot);
  _exec('git', ['config', 'user.email', 'github-actions[bot]@users.noreply.github.com'], cwd: repoRoot);

  // Add files that exist (.runtime_ci/audit/ may not exist on first release)
  final filesToAdd = [
    'pubspec.yaml',
    'CHANGELOG.md',
    'README.md',
    '$kReleaseNotesDir/',
    '$kVersionBumpsDir/',
    'autodoc.json',
  ];
  if (Directory('$repoRoot/docs').existsSync()) filesToAdd.add('docs/');
  if (Directory('$repoRoot/$kCicdAuditDir').existsSync()) filesToAdd.add('$kCicdAuditDir/');
  _exec('git', ['add', ...filesToAdd], cwd: repoRoot);

  final diffResult = Process.runSync('git', ['diff', '--cached', '--quiet'], workingDirectory: repoRoot);
  if (diffResult.exitCode != 0) {
    // Build a rich, detailed commit message from available artifacts
    final commitMsg = _buildReleaseCommitMessage(
      repoRoot: repoRoot,
      version: newVersion,
      prevTag: prevTag,
      releaseDir: releaseDir,
    );
    // Use a temp file for the commit message to avoid shell escaping issues
    final commitMsgFile = File('$repoRoot/.git/RELEASE_COMMIT_MSG');
    commitMsgFile.writeAsStringSync(commitMsg);
    _exec('git', ['commit', '-F', commitMsgFile.path], cwd: repoRoot, fatal: true);
    commitMsgFile.deleteSync();

    // Use GH_TOKEN for push authentication (HTTPS remote)
    final ghToken = Platform.environment['GH_TOKEN'] ?? Platform.environment['GITHUB_TOKEN'];
    final remoteRepo = Platform.environment['GITHUB_REPOSITORY'] ?? effectiveRepo;
    if (ghToken != null && remoteRepo.isNotEmpty) {
      _exec('git', [
        'remote',
        'set-url',
        'origin',
        'https://x-access-token:$ghToken@github.com/$remoteRepo.git',
      ], cwd: repoRoot);
    }
    _exec('git', ['push', 'origin', 'main'], cwd: repoRoot, fatal: true);
    _success('Committed and pushed changes');
  } else {
    _info('No changes to commit');
  }

  // Step 5: Create git tag
  _exec('git', ['tag', '-a', tag, '-m', 'Release v$newVersion'], cwd: repoRoot, fatal: true);
  _exec('git', ['push', 'origin', tag], cwd: repoRoot, fatal: true);
  _success('Created tag: $tag');

  // Step 6: Create GitHub Release using Stage 3 release notes
  var releaseBody = '';
  final bodyFile = File('${releaseDir.path}/release_notes.md');
  if (bodyFile.existsSync() && bodyFile.lengthSync() > 50) {
    releaseBody = bodyFile.readAsStringSync();
  } else {
    releaseBody = _buildFallbackReleaseNotes(repoRoot, newVersion, prevTag);
  }

  // Add footer with links
  final migrationLink = File('${releaseDir.path}/migration_guide.md').existsSync()
      ? ' | [Migration Guide]($kReleaseNotesDir/v$newVersion/migration_guide.md)'
      : '';
  releaseBody +=
      '\n\n---\n[Full Changelog](https://github.com/$effectiveRepo/compare/$prevTag...v$newVersion)'
      ' | [CHANGELOG.md](CHANGELOG.md)$migrationLink';

  final ghArgs = ['release', 'create', tag, '--title', 'v$newVersion', '--notes', releaseBody];
  if (effectiveRepo.isNotEmpty) ghArgs.addAll(['--repo', effectiveRepo]);

  _exec('gh', ghArgs, cwd: repoRoot);
  _success('Created GitHub Release: $tag');

  // Build rich summary
  final rnPreview = _readFileOr('${releaseDir.path}/release_notes.md');
  final clEntryContent = _readFileOr('${releaseDir.path}/changelog_entry.md');
  final contribContent = _readFileOr('${releaseDir.path}/contributors.json');

  _writeStepSummary('''
## Release Created

| Field | Value |
|-------|-------|
| Version | **v$newVersion** |
| Tag | [`$tag`](https://github.com/$effectiveRepo/tree/$tag) |
| Repository | `$effectiveRepo` |
| pubspec.yaml | Bumped to `$newVersion` |

### Links

- ${_releaseLink(newVersion)}
- ${_compareLink(prevTag, tag, 'Full Changelog')}
- ${_ghLink('CHANGELOG.md', 'CHANGELOG.md')}
- ${_ghLink('$kReleaseNotesDir/v$newVersion/', '$kReleaseNotesDir/v$newVersion/')}

${_collapsible('Release Notes', rnPreview, open: true)}
${_collapsible('CHANGELOG Entry', '```markdown\n$clEntryContent\n```')}
${_collapsible('Contributors (JSON)', '```json\n$contribContent\n```')}

${_artifactLink()}
''');
}

/// Run dart test.
Future<void> _runTest(String repoRoot) async {
  _header('Running Tests');
  final result = await Process.run('dart', ['test', '--exclude-tags', 'gcp'], workingDirectory: repoRoot);
  final output = result.stdout as String;
  stdout.write(output);
  stderr.write(result.stderr);
  // Parse test output for summary (before potential exit)
  final passMatch = RegExp(r'(\d+) tests? passed').firstMatch(output);
  final failMatch = RegExp(r'(\d+) failed').firstMatch(output);
  final skipMatch = RegExp(r'(\d+) skipped').firstMatch(output);
  final passed = passMatch?.group(1) ?? '?';
  final failed = failMatch?.group(1) ?? '0';
  final skipped = skipMatch?.group(1) ?? '0';

  // Truncate output for collapsible (keep last 5000 chars if huge)
  final testOutputPreview = output.length > 5000
      ? '... (truncated)\n${output.substring(output.length - 5000)}'
      : output;

  if (result.exitCode != 0) {
    _error('Tests failed (exit code ${result.exitCode})');
    // Write failure summary BEFORE exiting
    _writeStepSummary('''
## Test Results -- FAILED

| Metric | Count |
|--------|-------|
| Passed | $passed |
| Failed | **$failed** |
| Skipped | $skipped |

${_collapsible('Test Output', '```\n$testOutputPreview\n```', open: true)}
''');
    exit(result.exitCode);
  }
  _success('All tests passed');

  _writeStepSummary('''
## Test Results

| Metric | Count |
|--------|-------|
| Passed | **$passed** |
| Failed | $failed |
| Skipped | $skipped |

**All tests passed.**

${_collapsible('Test Output', '```\n$testOutputPreview\n```')}
''');
}

/// Run dart analyze and fail only on actual errors.
///
/// We run plain `dart analyze` (no --fatal-infos) and parse output ourselves.
/// The codebase has 33k+ info-level lints and some warnings in generated
/// protobuf code, which are expected and must not block CI.
Future<void> _runAnalyze(String repoRoot) async {
  _header('Running Analysis');
  final result = await Process.run('dart', ['analyze'], workingDirectory: repoRoot);
  final output = (result.stdout as String);
  stdout.write(output);
  stderr.write(result.stderr);

  // Count severity levels in output
  final errorCount = RegExp(r'^\s*error\s+-\s+', multiLine: true).allMatches(output).length;
  final warningCount = RegExp(r'^\s*warning\s+-\s+', multiLine: true).allMatches(output).length;
  final infoCount = RegExp(r'^\s*info\s+-\s+', multiLine: true).allMatches(output).length;

  _info('  Errors: $errorCount, Warnings: $warningCount, Infos: $infoCount');

  // Extract warning/error lines for collapsible summary
  final errorLines = RegExp(
    r'^\s*error\s+-\s+.*$',
    multiLine: true,
  ).allMatches(output).map((m) => m.group(0)).take(20).join('\n');
  final warningLines = RegExp(
    r'^\s*warning\s+-\s+.*$',
    multiLine: true,
  ).allMatches(output).map((m) => m.group(0)).take(20).join('\n');

  if (errorCount > 0) {
    _error('Analysis found $errorCount error(s)');
    // Write failure summary BEFORE exiting
    _writeStepSummary('''
## Analysis Results -- FAILED

| Severity | Count |
|----------|-------|
| Errors | **$errorCount** |
| Warnings | $warningCount |
| Infos | $infoCount |

${_collapsible('Errors (first 20)', '```\n$errorLines\n```', open: true)}
${warningLines.isNotEmpty ? _collapsible('Warnings (first 20)', '```\n$warningLines\n```') : ''}
''');
    exit(1);
  }

  if (warningCount > 0) {
    _warn('Analysis found $warningCount warning(s) (not blocking CI)');
  }

  _success('Analysis passed (no errors)');

  _writeStepSummary('''
## Analysis Results

| Severity | Count |
|----------|-------|
| Errors | $errorCount |
| Warnings | $warningCount |
| Infos | $infoCount |

**No errors found.**

${warningLines.isNotEmpty ? _collapsible('Warnings (first 20)', '```\n$warningLines\n```') : ''}
''');
}

/// Verify proto source files and generated files exist.
Future<void> _runVerifyProtos(String repoRoot) async {
  _header('Verifying Proto Files');

  // Count proto source files
  final protoDir = Directory('$repoRoot/proto/src');
  var protoCount = 0;
  if (protoDir.existsSync()) {
    protoCount = protoDir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.proto')).length;
  }
  _info('Proto source files in proto/src/: $protoCount');

  if (protoCount == 0) {
    _error('No .proto files found in proto/src/');
    exit(1);
  }

  // Count generated protobuf files
  final libDir = Directory('$repoRoot/lib');
  var generatedCount = 0;
  if (libDir.existsSync()) {
    final extensions = ['.pb.dart', '.pbenum.dart', '.pbjson.dart', '.pbgrpc.dart'];
    generatedCount = libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => extensions.any((ext) => f.path.endsWith(ext)))
        .length;
  }
  _info('Generated protobuf files in lib/: $generatedCount');

  if (generatedCount == 0) {
    _error('No generated .pb.dart files found in lib/');
    exit(1);
  }

  _success('Proto verification passed: $protoCount sources, $generatedCount generated');
}

/// Run documentation update via Gemini.
/// Gracefully skips if Gemini is unavailable.
Future<void> _runDocumentation(String repoRoot) async {
  _header('Documentation Update (Gemini 3 Pro Preview)');

  if (!_geminiAvailable(warnOnly: true)) {
    _warn('Skipping documentation update (Gemini unavailable).');
    return;
  }

  final ctx = RunContext.create(repoRoot, 'documentation');
  final prevTag = _prevTagOverride ?? _detectPrevTag(repoRoot);
  final newVersion = _versionOverride ?? _detectNextVersion(repoRoot, prevTag);

  final docScript = _promptScript('gemini_documentation_prompt.dart');
  _info('Generating documentation update prompt from $docScript...');
  if (!File(docScript).existsSync()) {
    _error('Prompt script not found: $docScript');
    exit(1);
  }
  final prompt = _runSync('dart run $docScript "$prevTag" "$newVersion"', repoRoot);
  if (prompt.isEmpty) {
    _error('Documentation prompt generator produced empty output.');
    exit(1);
  }
  ctx.savePrompt('documentation', prompt);

  if (_dryRun) {
    _info('[DRY-RUN] Would run Gemini for documentation update (${prompt.length} chars)');
    return;
  }

  final promptPath = ctx.artifactPath('documentation', 'prompt.txt');

  // Build @ includes -- check both /tmp/ and .runtime_ci/runs/ for stage1 artifacts
  final includes = <String>[];
  if (File('/tmp/commit_analysis.json').existsSync()) {
    includes.add('@/tmp/commit_analysis.json');
  } else if (File('$repoRoot/$kCicdRunsDir/explore/commit_analysis.json').existsSync()) {
    includes.add('@$repoRoot/$kCicdRunsDir/explore/commit_analysis.json');
  }
  includes.add('@README.md');

  _info('Running Gemini 3 Pro for documentation updates...');
  final result = Process.runSync(
    'sh',
    [
      '-c',
      'cat $promptPath | gemini '
          '-o json --yolo '
          '-m $kGeminiProModel '
          "--allowed-tools 'run_shell_command(git),run_shell_command(gh),run_shell_command(cat),run_shell_command(head)' "
          '${includes.join(" ")}',
    ],
    workingDirectory: repoRoot,
    environment: {...Platform.environment},
  );

  ctx.saveResponse('documentation', result.stdout as String);

  if (result.exitCode != 0) {
    _warn('Documentation update failed: ${result.stderr}');
  } else {
    try {
      final jsonStr = _extractJson(result.stdout as String);
      json.decode(jsonStr);
      _success('Documentation update completed');
    } catch (e) {
      _warn('Could not parse Gemini response: $e');
    }
  }
}

/// Pre-release triage: delegates to triage CLI.
/// Gracefully produces an empty manifest if Gemini is unavailable.
Future<void> _runPreReleaseTriage(String repoRoot, List<String> args) async {
  _header('Pre-release Triage');

  final prevTag = _prevTagOverride ?? _detectPrevTag(repoRoot);
  final newVersion = _versionOverride ?? _detectNextVersion(repoRoot, prevTag);

  if (!_geminiAvailable(warnOnly: true)) {
    _warn('Producing empty issue manifest (Gemini unavailable).');
    final ctx = RunContext.create(repoRoot, 'pre-release-triage');
    final emptyManifest = '{"version":"$newVersion","github_issues":[],"sentry_issues":[],"cross_repo_issues":[]}';
    ctx.saveArtifact('pre-release-triage', 'issue_manifest.json', emptyManifest);
    _success('Empty manifest saved to ${ctx.runDir}/pre-release-triage/issue_manifest.json');
    ctx.finalize(exitCode: 0);
    return;
  }

  final triageArgs = ['--pre-release', '--prev-tag', prevTag, '--version', newVersion, '--force'];
  if (_verbose) triageArgs.add('--verbose');

  _info('Delegating to triage CLI: dart run scripts/triage/triage_cli.dart ${triageArgs.join(" ")}');

  final result = await Process.run(
    'dart',
    ['run', 'scripts/triage/triage_cli.dart', ...triageArgs],
    workingDirectory: repoRoot,
    environment: {...Platform.environment},
  );

  final stdoutStr = (result.stdout as String).trim();
  if (stdoutStr.isNotEmpty) print(stdoutStr);
  final stderrStr = (result.stderr as String).trim();
  if (stderrStr.isNotEmpty) _error(stderrStr);

  if (result.exitCode != 0) exit(result.exitCode);
}

/// Post-release triage: delegates to triage CLI.
/// Gracefully skips if Gemini is unavailable.
Future<void> _runPostReleaseTriage(String repoRoot, List<String> args) async {
  _header('Post-release Triage');

  if (!_geminiAvailable(warnOnly: true)) {
    _warn('Skipping post-release triage (Gemini unavailable).');
    return;
  }

  final newVersion = _versionOverride;
  if (newVersion == null) {
    _error('--version <ver> is required for post-release-triage');
    exit(1);
  }

  // Parse release tag and URL from args
  String? releaseTag;
  String? releaseUrl;
  String? manifest;
  for (var i = 0; i < args.length - 1; i++) {
    if (args[i] == '--release-tag') releaseTag = args[i + 1];
    if (args[i] == '--release-url') releaseUrl = args[i + 1];
    if (args[i] == '--manifest') manifest = args[i + 1];
  }

  releaseTag ??= 'v$newVersion';

  final triageArgs = [
    '--post-release',
    '--version',
    newVersion,
    '--release-tag',
    releaseTag,
    if (releaseUrl != null) ...['--release-url', releaseUrl],
    if (manifest != null) ...['--manifest', manifest],
    '--force',
  ];
  if (_verbose) triageArgs.add('--verbose');

  _info('Delegating to triage CLI: dart run scripts/triage/triage_cli.dart ${triageArgs.join(" ")}');

  final result = await Process.run(
    'dart',
    ['run', 'scripts/triage/triage_cli.dart', ...triageArgs],
    workingDirectory: repoRoot,
    environment: {...Platform.environment},
  );

  final stdoutStr = (result.stdout as String).trim();
  if (stdoutStr.isNotEmpty) print(stdoutStr);
  final stderrStr = (result.stderr as String).trim();
  if (stderrStr.isNotEmpty) _error(stderrStr);

  // Post-release triage failures are non-fatal
  if (result.exitCode != 0) {
    _warn('Post-release triage exited with code ${result.exitCode}');
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
/// Archive a CI/CD run to .runtime_ci/audit/vX.X.X/ for permanent storage.
///
/// This step is non-critical -- the release succeeds even if archiving fails.
/// All failure paths return gracefully (exit 0) to avoid GitHub Actions error
/// annotations from continue-on-error steps.
Future<void> _runArchiveRun(String repoRoot, List<String> args) async {
  _header('Archive Run');

  final version = _versionOverride;
  if (version == null) {
    _warn('--version not provided for archive-run — skipping.');
    return;
  }

  // Find the run directory
  String? runDirPath;
  for (var i = 0; i < args.length - 1; i++) {
    if (args[i] == '--run-dir') runDirPath = args[i + 1];
  }

  if (runDirPath == null) {
    runDirPath = RunContext.findLatestRun(repoRoot);
    if (runDirPath == null) {
      _warn('No $kCicdRunsDir/ directory found — nothing to archive.');
      _info('This is expected if audit trail artifacts were not transferred between jobs.');
      return;
    }
    _info('Using latest run: $runDirPath');
  }

  try {
    final ctx = RunContext.load(repoRoot, runDirPath);
    ctx.archiveForRelease(version);
    _success('Archived to $kCicdAuditDir/v$version/');
  } catch (e) {
    _warn('Archive failed: $e — continuing without archive.');
  }
}

/// Merge CI/CD audit trail artifacts from multiple jobs into a single
/// run directory under .runtime_ci/runs/.
///
/// In CI, each Gemini-powered job (determine-version, pre-release-triage,
/// explore-changes, compose-artifacts) uploads its .runtime_ci/runs/ contents as
/// a uniquely-named artifact. The create-release job downloads them all into
/// a staging directory, then calls this command to merge them into a single
/// run directory that archive-run can process.
///
/// Options:
///   --incoming-dir <dir>  Staging directory with downloaded artifacts (default: .runtime_ci/runs_incoming)
///   --output-dir <dir>    Target runs directory (default: .runtime_ci/runs)
Future<void> _runMergeAuditTrails(String repoRoot, List<String> args) async {
  _header('Merge Audit Trails');

  var incomingDir = '$kRuntimeCiDir/runs_incoming';
  var outputDir = kCicdRunsDir;
  for (var i = 0; i < args.length - 1; i++) {
    if (args[i] == '--incoming-dir') incomingDir = args[i + 1];
    if (args[i] == '--output-dir') outputDir = args[i + 1];
  }

  final incomingPath = incomingDir.startsWith('/') ? incomingDir : '$repoRoot/$incomingDir';
  final incoming = Directory(incomingPath);
  if (!incoming.existsSync()) {
    _warn('No incoming audit trails found at $incomingDir');
    _warn('Skipping merge (no artifacts uploaded by prior jobs).');
    return;
  }

  final artifactDirs = incoming.listSync().whereType<Directory>().toList();
  if (artifactDirs.isEmpty) {
    _warn('Incoming directory exists but contains no artifact subdirectories.');
    return;
  }

  // Create the merged run directory with a unique timestamp
  final now = DateTime.now();
  final timestamp = now.toIso8601String().replaceAll(':', '-').replaceAll('.', '-').substring(0, 19);
  final outputPath = outputDir.startsWith('/') ? outputDir : '$repoRoot/$outputDir';
  final mergedRunDir = '$outputPath/run_${timestamp}_merged';
  Directory(mergedRunDir).createSync(recursive: true);

  final sources = <Map<String, dynamic>>[];
  var totalFiles = 0;

  for (final artifactDir in artifactDirs) {
    final artifactName = artifactDir.path.split('/').last;
    _info('Processing artifact: $artifactName');

    // Walk contents of this artifact subdirectory.
    // Each artifact contains the .runtime_ci/runs/ tree from a single job:
    //   - run_TIMESTAMP_PID/ directories (from RunContext)
    //   - version_analysis/ (from determine-version, direct writes)
    for (final entity in artifactDir.listSync()) {
      if (entity is Directory) {
        final dirName = entity.path.split('/').last;

        if (dirName.startsWith('run_')) {
          // RunContext directory — copy each phase subdirectory into the merged run
          for (final child in entity.listSync()) {
            if (child is Directory) {
              final phaseName = child.path.split('/').last;
              _copyDirRecursive(child, Directory('$mergedRunDir/$phaseName'));
              totalFiles += _countFiles(child);
              _info('  Merged phase: $phaseName (from $artifactName)');
            } else if (child is File) {
              final fileName = child.path.split('/').last;
              if (fileName == 'meta.json') {
                // Collect source meta for the merged meta.json
                try {
                  final meta = json.decode(child.readAsStringSync()) as Map<String, dynamic>;
                  sources.add({'artifact': artifactName, ...meta});
                } catch (_) {
                  sources.add({'artifact': artifactName, 'error': 'failed to parse meta.json'});
                }
              }
            }
          }
        } else {
          // Non-RunContext directory (e.g. version_analysis/) — copy as-is
          _copyDirRecursive(entity, Directory('$mergedRunDir/$dirName'));
          totalFiles += _countFiles(entity);
          _info('  Merged directory: $dirName (from $artifactName)');
        }
      }
    }
  }

  // Write merged meta.json
  final mergedMeta = {
    'command': 'merged-audit',
    'started_at': now.toIso8601String(),
    'merged_from': sources,
    'artifact_count': artifactDirs.length,
    'total_files': totalFiles,
    'ci': Platform.environment.containsKey('CI'),
    'platform': Platform.operatingSystem,
    'dart_version': Platform.version.split(' ').first,
  };
  File('$mergedRunDir/meta.json').writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(mergedMeta)}\n');

  _success('Merged ${artifactDirs.length} audit trail(s) into $mergedRunDir ($totalFiles files)');
}

/// Recursively copy a directory tree.
void _copyDirRecursive(Directory src, Directory dst) {
  dst.createSync(recursive: true);
  for (final entity in src.listSync()) {
    final name = entity.path.split('/').last;
    if (entity is File) {
      entity.copySync('${dst.path}/$name');
    } else if (entity is Directory) {
      _copyDirRecursive(entity, Directory('${dst.path}/$name'));
    }
  }
}

/// Count all files in a directory tree.
int _countFiles(Directory dir) {
  var count = 0;
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is File) count++;
  }
  return count;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tool Installation (Cross-Platform)
// ═══════════════════════════════════════════════════════════════════════════════

Future<void> _installTool(String tool) async {
  if (_dryRun) {
    _info('[DRY-RUN] Would install $tool');
    return;
  }

  switch (tool) {
    case 'node' || 'npm':
      await _installNodeJs();
    case 'gemini':
      await _installGeminiCli();
    case 'gh':
      await _installGitHubCli();
    case 'jq':
      await _installJq();
    case 'tree':
      await _installTree();
    case 'git':
      _error('git must be installed manually.');
      _info('  macOS: xcode-select --install');
      _info('  Linux: sudo apt install git');
      _info('  Windows: https://git-scm.com/downloads');
    default:
      _warn('No auto-installer for $tool');
  }
}

Future<void> _installNodeJs() async {
  if (Platform.isMacOS) {
    _info('Installing Node.js via Homebrew...');
    _exec('brew', ['install', 'node']);
  } else if (Platform.isLinux) {
    _info('Installing Node.js via apt...');
    _exec('sudo', ['apt', 'install', '-y', 'nodejs', 'npm']);
  } else if (Platform.isWindows) {
    if (_commandExists('winget')) {
      _info('Installing Node.js via winget...');
      _exec('winget', ['install', 'OpenJS.NodeJS']);
    } else if (_commandExists('choco')) {
      _info('Installing Node.js via Chocolatey...');
      _exec('choco', ['install', 'nodejs', '-y']);
    } else {
      _error('Install Node.js manually: https://nodejs.org/');
    }
  }
}

Future<void> _installGeminiCli() async {
  if (!_commandExists('npm')) {
    _error('npm is required to install Gemini CLI. Install Node.js first.');
    return;
  }
  _info('Installing Gemini CLI via npm...');
  _exec('npm', ['install', '-g', '@google/gemini-cli@latest']);
}

Future<void> _installGitHubCli() async {
  if (Platform.isMacOS) {
    _info('Installing GitHub CLI via Homebrew...');
    _exec('brew', ['install', 'gh']);
  } else if (Platform.isLinux) {
    _info('Installing GitHub CLI via apt...');
    // Use the official GitHub CLI apt repo
    _exec('sh', [
      '-c',
      'type -p curl >/dev/null || sudo apt install curl -y && '
          'curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | '
          'sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && '
          'echo "deb [arch=\$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] '
          'https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null && '
          'sudo apt update && sudo apt install gh -y',
    ]);
  } else if (Platform.isWindows) {
    if (_commandExists('winget')) {
      _exec('winget', ['install', 'GitHub.cli']);
    } else if (_commandExists('choco')) {
      _exec('choco', ['install', 'gh', '-y']);
    }
  }
}

Future<void> _installJq() async {
  if (Platform.isMacOS) {
    _exec('brew', ['install', 'jq']);
  } else if (Platform.isLinux) {
    _exec('sudo', ['apt', 'install', '-y', 'jq']);
  } else if (Platform.isWindows) {
    if (_commandExists('winget')) {
      _exec('winget', ['install', 'jqlang.jq']);
    } else if (_commandExists('choco')) {
      _exec('choco', ['install', 'jq', '-y']);
    }
  }
}

Future<void> _installTree() async {
  if (Platform.isMacOS) {
    _exec('brew', ['install', 'tree']);
  } else if (Platform.isLinux) {
    _exec('sudo', ['apt', 'install', '-y', 'tree']);
  } else if (Platform.isWindows) {
    _info('tree is built-in on Windows (limited). For full tree: choco install tree');
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Version Detection
// ═══════════════════════════════════════════════════════════════════════════════

String _detectPrevTag(String repoRoot) {
  final result = _runSync("git tag -l 'v*' --sort=-version:refname | head -1", repoRoot);
  if (result.isEmpty) {
    // No tags yet -- use the first commit (head -1 to handle multiple roots in monorepos)
    return _runSync('git rev-list --max-parents=0 HEAD | head -1', repoRoot);
  }
  return result;
}

String _detectNextVersion(String repoRoot, String prevTag) {
  final currentVersion = _runSync("awk '/^version:/{print \$2}' pubspec.yaml", repoRoot);
  final parts = currentVersion.split('.');
  if (parts.length != 3) return currentVersion;

  var major = int.tryParse(parts[0]) ?? 0;
  var minor = int.tryParse(parts[1]) ?? 0;
  var patch = int.tryParse(parts[2]) ?? 0;

  // ── Pass 1: Fast regex heuristic (fallback if Gemini unavailable) ──
  final commits = _runSync('git log "$prevTag"..HEAD --pretty=format:"%s%n%b" 2>/dev/null', repoRoot);

  var bump = 'patch';
  if (RegExp(r'(BREAKING CHANGE|^[a-z]+(\(.+\))?!:)', multiLine: true).hasMatch(commits)) {
    bump = 'major';
  } else if (RegExp(r'^feat(\(.+\))?:', multiLine: true).hasMatch(commits)) {
    bump = 'minor';
  }

  _info('  Regex heuristic: $bump');

  // ── Pass 2: Gemini analysis (authoritative, overrides regex if available) ──
  if (_commandExists('gemini') && Platform.environment['GEMINI_API_KEY'] != null) {
    final commitCount = _runSync('git rev-list --count "$prevTag"..HEAD 2>/dev/null', repoRoot);
    final changedFiles = _runSync('git diff --name-only "$prevTag"..HEAD 2>/dev/null | head -30', repoRoot);
    final diffStat = _runSync('git diff --stat "$prevTag"..HEAD 2>/dev/null | tail -5', repoRoot);
    final commitSummary = commits.split('\n').take(50).join('\n');

    // Create a version analysis output directory within the CWD (sandbox-safe)
    final versionAnalysisDir = Directory('$repoRoot/$kCicdRunsDir/version_analysis');
    versionAnalysisDir.createSync(recursive: true);
    final bumpJsonPath = '${versionAnalysisDir.path}/version_bump.json';
    final prompt =
        'You are a semantic versioning expert analyzing the ${config.repoName} '
        'Dart package.\n\n'
        'Current version: $currentVersion\n'
        'Commits since last release: $commitCount\n\n'
        'Commit messages:\n$commitSummary\n\n'
        'Changed files:\n$changedFiles\n\n'
        'Diff statistics:\n$diffStat\n\n'
        '## Instructions\n\n'
        '1. Run `git diff $prevTag..HEAD` to see the full diff\n'
        '2. Examine changed files for API surface changes\n'
        '3. Check if any public APIs were broken, removed, or changed incompatibly\n'
        '4. Assess the overall scope\n\n'
        '## Write TWO files:\n\n'
        '### File 1: .runtime_ci/runs/version_analysis/version_bump.json\n'
        '```json\n{"bump": "major|minor|patch"}\n```\n\n'
        '### File 2: .runtime_ci/runs/version_analysis/version_bump_rationale.md\n'
        'A markdown document explaining the decision with:\n'
        '- **Decision**: major/minor/patch and why\n'
        '- **Key Changes**: Bullet list of significant changes\n'
        '- **Breaking Changes** (if any)\n'
        '- **New Features** (if any)\n'
        '- **References**: Relevant PRs and commits\n\n'
        'Rules:\n'
        '- MAJOR: Breaking changes to public APIs, removed functions, changed signatures\n'
        '- MINOR: New features, new proto messages, new exports, additive API changes\n'
        '- PATCH: Bug fixes, docs, refactoring, dependency updates, CI, tests\n';

    final promptPath = '${versionAnalysisDir.path}/prompt.txt';
    File(promptPath).writeAsStringSync(prompt);
    final geminiResult = _runSync(
      'cat $promptPath | gemini '
      '-o json --yolo '
      '-m $kGeminiProModel '
      "--allowed-tools 'run_shell_command(git),run_shell_command(gh)' "
      '2>/dev/null',
      repoRoot,
    );

    // Save raw Gemini response for audit trail
    if (geminiResult.isNotEmpty) {
      File('${versionAnalysisDir.path}/gemini_response.json').writeAsStringSync(geminiResult);
    }

    if (geminiResult.isNotEmpty && File(bumpJsonPath).existsSync()) {
      try {
        final bumpData = json.decode(File(bumpJsonPath).readAsStringSync()) as Map<String, dynamic>;
        final rawBump = (bumpData['bump'] as String?)?.trim().toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
        if (rawBump == 'major' || rawBump == 'minor' || rawBump == 'patch') {
          _info('  Gemini analysis: $rawBump (overriding regex: $bump)');
          bump = rawBump!;
        } else {
          _info('  Gemini returned unexpected: "$rawBump", using regex: $bump');
        }
      } catch (e) {
        _info('  Gemini parse error: $e, using regex: $bump');
      }
    } else {
      _info('  Gemini unavailable, using regex: $bump');
    }
  } else {
    _info('  Gemini not available for version analysis, using regex heuristic');
  }

  // Apply the bump
  switch (bump) {
    case 'major':
      major++;
      minor = 0;
      patch = 0;
    case 'minor':
      minor++;
      patch = 0;
    case 'patch':
      patch++;
  }

  final nextVersion = '$major.$minor.$patch';

  // Guard: ensure version never goes backward
  if (_compareVersions(nextVersion, currentVersion) < 0) {
    _warn('Version regression detected: $nextVersion < $currentVersion. Using $currentVersion.');
    return currentVersion;
  }

  _info('  Bump type: $bump -> $nextVersion');
  return nextVersion;
}

/// Compare two semver versions. Returns negative if a < b, 0 if equal, positive if a > b.
int _compareVersions(String a, String b) {
  final aParts = a.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  final bParts = b.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  for (var i = 0; i < 3; i++) {
    final av = i < aParts.length ? aParts[i] : 0;
    final bv = i < bParts.length ? bParts[i] : 0;
    if (av != bv) return av - bv;
  }
  return 0;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Utilities
// ═══════════════════════════════════════════════════════════════════════════════

/// Extract JSON from Gemini CLI output.
///
/// Gemini CLI v0.24+ may output warning/error lines (MCP discovery, deprecation)
/// to stdout before the JSON object. This finds the first '{' and extracts from there.
String _extractJson(String rawOutput) {
  final jsonStart = rawOutput.indexOf('{');
  if (jsonStart < 0) {
    throw FormatException('No JSON object found in Gemini output');
  }
  return rawOutput.substring(jsonStart);
}

String? _findRepoRoot() {
  var dir = Directory.current;
  // Walk up to find pubspec.yaml with matching package name
  for (var i = 0; i < 10; i++) {
    final pubspec = File('${dir.path}/pubspec.yaml');
    if (pubspec.existsSync()) {
      final content = pubspec.readAsStringSync();
      if (content.contains('name: ${config.repoName}')) {
        return dir.path;
      }
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return null;
}

/// Build a rich, detailed commit message for the automated release commit.
///
/// Includes:
/// - Bot prefix with version
/// - Summary from changelog entry or release notes
/// - List of modified files with descriptions
/// - Contributors
/// - [skip ci] marker for loop prevention
String _buildReleaseCommitMessage({
  required String repoRoot,
  required String version,
  required String prevTag,
  required Directory releaseDir,
}) {
  final buf = StringBuffer();

  // Line 1: Subject line with bot prefix and [skip ci]
  buf.writeln('bot(release): v$version [skip ci]');
  buf.writeln();

  // Summary from changelog entry if available
  final changelogEntry = File('${releaseDir.path}/changelog_entry.md');
  if (changelogEntry.existsSync()) {
    final entry = changelogEntry.readAsStringSync().trim();
    if (entry.isNotEmpty) {
      buf.writeln('## Changelog');
      buf.writeln();
      // Trim to first 2000 chars to keep commit message reasonable
      buf.writeln(entry.length > 2000 ? '${entry.substring(0, 2000)}...' : entry);
      buf.writeln();
    }
  }

  // Staged file summary
  final stagedResult = Process.runSync('git', ['diff', '--cached', '--stat'], workingDirectory: repoRoot);
  final stagedStat = (stagedResult.stdout as String).trim();
  if (stagedStat.isNotEmpty) {
    buf.writeln('## Files Modified');
    buf.writeln();
    buf.writeln('```');
    buf.writeln(stagedStat);
    buf.writeln('```');
    buf.writeln();
  }

  // Version bump detail
  final bumpRationale = File('$repoRoot/$kVersionBumpsDir/v$version.md');
  if (bumpRationale.existsSync()) {
    final rationale = bumpRationale.readAsStringSync().trim();
    if (rationale.isNotEmpty) {
      buf.writeln('## Version Bump Rationale');
      buf.writeln();
      buf.writeln(rationale.length > 1000 ? '${rationale.substring(0, 1000)}...' : rationale);
      buf.writeln();
    }
  }

  // Contributors (verified @username from GitHub API)
  final contribFile = File('${releaseDir.path}/contributors.json');
  if (contribFile.existsSync()) {
    try {
      final contribs = json.decode(contribFile.readAsStringSync()) as List;
      if (contribs.isNotEmpty) {
        buf.writeln('## Contributors');
        buf.writeln();
        for (final c in contribs) {
          final entry = c as Map;
          final username = entry['username'] as String? ?? '';
          if (username.isNotEmpty) {
            buf.writeln('- @$username');
          }
        }
        buf.writeln();
      }
    } catch (_) {
      // Skip if parse fails
    }
  }

  // Commit range
  final commitCount = _runSync('git rev-list --count "$prevTag"..HEAD 2>/dev/null', repoRoot);
  buf.writeln('---');
  buf.writeln('Automated release by CI/CD pipeline (Gemini CLI + GitHub Actions)');
  buf.writeln('Commits since $prevTag: $commitCount');
  buf.writeln('Generated: ${DateTime.now().toUtc().toIso8601String()}');

  return buf.toString();
}

bool _commandExists(String command) {
  try {
    final which = Platform.isWindows ? 'where' : 'which';
    final result = Process.runSync(which, [command]);
    return result.exitCode == 0;
  } catch (_) {
    return false;
  }
}

String _runSync(String command, String workingDirectory) {
  if (_verbose) _info('[CMD] $command');
  final result = Process.runSync('sh', ['-c', command], workingDirectory: workingDirectory);
  final output = (result.stdout as String).trim();
  if (_verbose && output.isNotEmpty) _info('  $output');
  return output;
}

/// Write a markdown summary to $GITHUB_STEP_SUMMARY (visible in Actions UI).
/// No-op when running locally (env var not set).
void _writeStepSummary(String markdown) {
  final summaryFile = Platform.environment['GITHUB_STEP_SUMMARY'];
  if (summaryFile != null) {
    File(summaryFile).writeAsStringSync(markdown, mode: FileMode.append);
  }
}

// ── Step Summary Helpers ─────────────────────────────────────────────────────

/// Build a link to the current workflow run's artifacts page.
String _artifactLink([String label = 'View all artifacts']) {
  final server = Platform.environment['GITHUB_SERVER_URL'] ?? 'https://github.com';
  final repo = Platform.environment['GITHUB_REPOSITORY'];
  final runId = Platform.environment['GITHUB_RUN_ID'];
  if (repo == null || runId == null) return '';
  return '[$label]($server/$repo/actions/runs/$runId)';
}

/// Build a GitHub compare link between two refs.
String _compareLink(String prevTag, String newTag, [String? label]) {
  final server = Platform.environment['GITHUB_SERVER_URL'] ?? 'https://github.com';
  final repo = Platform.environment['GITHUB_REPOSITORY'] ?? '${config.repoOwner}/${config.repoName}';
  final text = label ?? '$prevTag...$newTag';
  return '[$text]($server/$repo/compare/$prevTag...$newTag)';
}

/// Build a link to a file/path in the repository.
String _ghLink(String label, String path) {
  final server = Platform.environment['GITHUB_SERVER_URL'] ?? 'https://github.com';
  final repo = Platform.environment['GITHUB_REPOSITORY'] ?? '${config.repoOwner}/${config.repoName}';
  final sha = Platform.environment['GITHUB_SHA'] ?? 'main';
  return '[$label]($server/$repo/blob/$sha/$path)';
}

/// Build a link to a GitHub Release by tag.
String _releaseLink(String tag) {
  final server = Platform.environment['GITHUB_SERVER_URL'] ?? 'https://github.com';
  final repo = Platform.environment['GITHUB_REPOSITORY'] ?? '${config.repoOwner}/${config.repoName}';
  return '[v$tag]($server/$repo/releases/tag/$tag)';
}

/// Wrap content in a collapsible <details> block for step summaries.
String _collapsible(String title, String content, {bool open = false}) {
  if (content.trim().isEmpty) return '';
  final openAttr = open ? ' open' : '';
  return '\n<details$openAttr>\n<summary>$title</summary>\n\n$content\n\n</details>\n';
}

/// Read a file and return its content, or a fallback message if not found.
String _readFileOr(String path, [String fallback = '(not available)']) {
  final f = File(path);
  return f.existsSync() ? f.readAsStringSync().trim() : fallback;
}

/// Execute a command. Set [fatal] to true to exit on failure (default: false).
void _exec(String executable, List<String> args, {String? cwd, bool fatal = false}) {
  if (_verbose) _info('  \$ $executable ${args.join(" ")}');
  final result = Process.runSync(executable, args, workingDirectory: cwd);
  if (result.exitCode != 0) {
    _error('  Command failed (exit ${result.exitCode}): ${result.stderr}');
    if (fatal) exit(result.exitCode);
  }
}

void _requireGeminiCli() {
  if (!_commandExists('gemini')) {
    _error('Gemini CLI is not installed. Run: dart run scripts/manage_cicd.dart setup');
    exit(1);
  }
}

void _requireApiKey() {
  final key = Platform.environment['GEMINI_API_KEY'];
  if (key == null || key.isEmpty) {
    _error('GEMINI_API_KEY is not set.');
    _error('Set it via: export GEMINI_API_KEY=<your-key-from-aistudio.google.com>');
    exit(1);
  }
}

/// Returns true if Gemini CLI and API key are both available.
/// When [warnOnly] is true, logs a warning instead of exiting.
bool _geminiAvailable({bool warnOnly = false}) {
  if (!_commandExists('gemini')) {
    if (warnOnly) {
      _warn('Gemini CLI not installed — skipping Gemini-powered step.');
      return false;
    }
    _error('Gemini CLI is not installed. Run: dart run scripts/manage_cicd.dart setup');
    exit(1);
  }
  final key = Platform.environment['GEMINI_API_KEY'];
  if (key == null || key.isEmpty) {
    if (warnOnly) {
      _warn('GEMINI_API_KEY not set — skipping Gemini-powered step.');
      return false;
    }
    _error('GEMINI_API_KEY is not set.');
    exit(1);
  }
  return true;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Logging
// ═══════════════════════════════════════════════════════════════════════════════

void _header(String msg) => print('\n\x1B[1m$msg\x1B[0m');
void _info(String msg) => print(msg);
void _success(String msg) => print('\x1B[32m$msg\x1B[0m');
void _warn(String msg) => print('\x1B[33m$msg\x1B[0m');
void _error(String msg) => stderr.writeln('\x1B[31m$msg\x1B[0m');

void _printUsage() {
  print('''
CI/CD Automation CLI for ${config.repoName}

Commands:
  setup              Install all prerequisites (Node.js, Gemini CLI, gh, jq, tree)
  validate           Validate all configuration files (YAML, JSON, TOML, Dart)
  determine-version  Determine SemVer bump via Gemini + regex (CI: --output-github-actions)
  explore            Run Stage 1 Explorer Agent (Gemini 3 Pro)
  compose            Run Stage 2 Changelog Composer (Gemini Pro)
  release-notes      Run Stage 3 Release Notes Author (Gemini Pro)
  documentation      Run documentation update via Gemini
  autodoc            Generate/update module docs (--init, --force, --module, --dry-run)
  create-release     Create git tag, GitHub Release, commit all changes
  archive-run        Archive .runtime_ci/runs/ to .runtime_ci/audit/vX.X.X/ for permanent storage
  merge-audit-trails Merge CI/CD audit artifacts from multiple jobs (CI use)
  pre-release-triage Scan issues/Sentry before release, produce issue_manifest.json
  post-release-triage Comment on issues, close confident ones, link Sentry
  triage <N>         Run issue triage (single, --auto, --status)
  release            Run the full local release pipeline
  version            Show the next SemVer version (no side effects)
  test               Run dart test
  analyze            Run dart analyze (fail on errors only, warn on warnings)
  verify-protos      Verify proto source and generated files exist
  configure-mcp      Set up MCP servers (GitHub, Sentry)
  status             Show current CI/CD configuration status
  init               Scan repo and generate .runtime_ci/config.json + scaffold workflows

Options:
  --dry-run          Show what would be done without executing
  --verbose, -v      Show detailed command output
  --prev-tag <tag>   Override previous tag detection
  --version <ver>    Override version (skip auto-detection)
  --help, -h         Show this help message

Examples:
  dart run scripts/manage_cicd.dart setup
  dart run scripts/manage_cicd.dart validate
  dart run scripts/manage_cicd.dart explore --prev-tag v0.0.1 --version 0.0.2
  dart run scripts/manage_cicd.dart compose --prev-tag v0.0.1 --version 0.0.2
  dart run scripts/manage_cicd.dart triage 42
  dart run scripts/manage_cicd.dart release
  dart run scripts/manage_cicd.dart configure-mcp
  dart run scripts/manage_cicd.dart status

Prerequisites:
  Required: git, gh (GitHub CLI), node, npm, jq
  Optional: tree, gemini (Gemini CLI)
  
  GEMINI_API_KEY must be set for explore/compose/triage commands.
  Get your key at: https://aistudio.google.com/apikey
''');
}

// ═══════════════════════════════════════════════════════════════════════════════
// Init Command
// ═══════════════════════════════════════════════════════════════════════════════

/// Scans the current repo and generates `.runtime_ci/config.json` plus
/// optional scaffolding (workflows, gemini config, script wrappers).
///
/// This is the entry point for any repo that wants to opt into the
/// runtime CI tooling. It auto-detects as much as possible from the
/// repo state and writes a config that the triage/release pipeline can use.
Future<void> _runInit(String repoRoot) async {
  _header('Initialize Runtime CI Tooling');

  final configDir = Directory('$repoRoot/$kRuntimeCiDir');
  final configFile = File('$repoRoot/$kConfigFileName');

  if (configFile.existsSync()) {
    _warn('$kConfigFileName already exists. Skipping init.');
    _info('Delete it and re-run init to regenerate, or edit it directly.');
    return;
  }

  // ── 1. Auto-detect package name from pubspec.yaml ──────────────────────
  String packageName = 'unknown';
  String packageVersion = '0.0.0';
  final pubspecFile = File('$repoRoot/pubspec.yaml');
  if (pubspecFile.existsSync()) {
    final content = pubspecFile.readAsStringSync();
    final nameMatch = RegExp(r'^name:\s*(\S+)', multiLine: true).firstMatch(content);
    if (nameMatch != null) packageName = nameMatch.group(1)!;
    final versionMatch = RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(content);
    if (versionMatch != null) packageVersion = versionMatch.group(1)!;
    _success('Detected package: $packageName v$packageVersion');
  } else {
    _warn('No pubspec.yaml found at repo root. Using defaults.');
  }

  // ── 2. Auto-detect GitHub owner/org via gh CLI ─────────────────────────
  String repoOwner = 'unknown';
  try {
    final ghResult = Process.runSync('gh', [
      'repo',
      'view',
      '--json',
      'owner',
      '-q',
      '.owner.login',
    ], workingDirectory: repoRoot);
    if (ghResult.exitCode == 0) {
      final owner = (ghResult.stdout as String).trim();
      if (owner.isNotEmpty) {
        repoOwner = owner;
        _success('Detected GitHub owner: $repoOwner');
      }
    }
  } catch (_) {}
  if (repoOwner == 'unknown') {
    // Fallback: try parsing git remote
    try {
      final gitResult = Process.runSync('git', ['remote', 'get-url', 'origin'], workingDirectory: repoRoot);
      if (gitResult.exitCode == 0) {
        final url = (gitResult.stdout as String).trim();
        // git@github.com:owner/repo.git or https://github.com/owner/repo.git
        final match = RegExp(r'github\.com[:/]([^/]+)/').firstMatch(url);
        if (match != null) {
          repoOwner = match.group(1)!;
          _success('Detected GitHub owner from remote: $repoOwner');
        }
      }
    } catch (_) {}
  }

  // ── 3. Scan for existing files ─────────────────────────────────────────
  final hasChangelog = File('$repoRoot/CHANGELOG.md').existsSync();
  final hasGithub = Directory('$repoRoot/.github').existsSync();
  final hasGemini = Directory('$repoRoot/.gemini').existsSync();

  // ── 4. Auto-generate area labels from lib/ directory structure ─────────
  final areaLabels = <String>['area/core', 'area/ci-cd', 'area/docs'];
  final libDir = Directory('$repoRoot/lib');
  if (libDir.existsSync()) {
    for (final entity in libDir.listSync()) {
      if (entity is Directory) {
        final dirName = entity.path.split('/').last;
        if (dirName != 'src' && !dirName.startsWith('.')) {
          areaLabels.add('area/$dirName');
        }
      }
    }
    // Also scan lib/src/ one level deep
    final srcDir = Directory('$repoRoot/lib/src');
    if (srcDir.existsSync()) {
      for (final entity in srcDir.listSync()) {
        if (entity is Directory) {
          final dirName = entity.path.split('/').last;
          if (!dirName.startsWith('.')) {
            final label = 'area/$dirName';
            if (!areaLabels.contains(label)) areaLabels.add(label);
          }
        }
      }
    }
  }

  // ── 5. Write .runtime_ci/config.json ───────────────────────────────────
  configDir.createSync(recursive: true);
  final configData = {
    'repository': {
      'name': packageName,
      'owner': repoOwner,
      'triaged_label': 'triaged',
      'changelog_path': hasChangelog ? 'CHANGELOG.md' : 'CHANGELOG.md',
      'release_notes_path': '$kReleaseNotesDir',
    },
    'gcp': {'project': ''},
    'sentry': {'organization': '', 'projects': <String>[], 'scan_on_pre_release': false, 'recent_errors_hours': 168},
    'release': {
      'pre_release_scan_sentry': false,
      'pre_release_scan_github': true,
      'post_release_close_own_repo': true,
      'post_release_close_cross_repo': false,
      'post_release_comment_cross_repo': true,
      'post_release_link_sentry': false,
    },
    'cross_repo': {
      'enabled': false,
      'orgs': [repoOwner],
      'repos': <Map<String, String>>[],
      'discovery': {
        'enabled': true,
        'search_orgs': [repoOwner],
      },
    },
    'labels': {
      'type': ['bug', 'feature-request', 'enhancement', 'documentation', 'question'],
      'priority': ['P0-critical', 'P1-high', 'P2-medium', 'P3-low'],
      'area': areaLabels,
    },
    'thresholds': {'auto_close': 0.9, 'suggest_close': 0.7, 'comment': 0.5},
    'agents': {
      'enabled': ['code_analysis', 'pr_correlation', 'duplicate', 'sentiment', 'changelog'],
      'conditional': {
        'changelog': {'require_file': 'CHANGELOG.md'},
      },
    },
    'gemini': {
      'flash_model': 'gemini-3-flash-preview',
      'pro_model': 'gemini-3-pro-preview',
      'max_turns': 100,
      'max_concurrent': 4,
      'max_retries': 3,
    },
    'secrets': {
      'gemini_api_key_env': 'GEMINI_API_KEY',
      'github_token_env': ['GH_TOKEN', 'GITHUB_TOKEN', 'GITHUB_PAT'],
      'sentry_token_env': 'SENTRY_ACCESS_TOKEN',
      'gcp_secret_name': '',
    },
  };

  configFile.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(configData)}\n');
  _success('Created $kConfigFileName');

  // ── 6. Add .runtime_ci/runs/ to .gitignore ─────────────────────────────
  final gitignoreFile = File('$repoRoot/.gitignore');
  if (gitignoreFile.existsSync()) {
    final content = gitignoreFile.readAsStringSync();
    if (!content.contains('.runtime_ci/runs/')) {
      gitignoreFile.writeAsStringSync('$content\n# Runtime CI audit trails (local only)\n.runtime_ci/runs/\n');
      _success('Added .runtime_ci/runs/ to .gitignore');
    }
  } else {
    gitignoreFile.writeAsStringSync('# Runtime CI audit trails (local only)\n.runtime_ci/runs/\n');
    _success('Created .gitignore with .runtime_ci/runs/');
  }

  // ── 7. Create script wrappers ──────────────────────────────────────────
  final scriptsDir = Directory('$repoRoot/scripts');
  scriptsDir.createSync(recursive: true);

  final manageCicdWrapper = File('$repoRoot/scripts/manage_cicd.dart');
  if (!manageCicdWrapper.existsSync()) {
    manageCicdWrapper.writeAsStringSync(
      '/// Thin wrapper that delegates to the shared runtime_ci_tooling package.\n'
      '// ignore_for_file: depend_on_referenced_packages\n'
      "import 'package:runtime_ci_tooling/src/cli/manage_cicd.dart' as cicd;\n\n"
      'Future<void> main(List<String> args) => cicd.main(args);\n',
    );
    _success('Created scripts/manage_cicd.dart');
  }

  final triageDir = Directory('$repoRoot/scripts/triage');
  triageDir.createSync(recursive: true);

  final triageWrapper = File('$repoRoot/scripts/triage/triage_cli.dart');
  if (!triageWrapper.existsSync()) {
    triageWrapper.writeAsStringSync(
      '/// Thin wrapper that delegates to the shared runtime_ci_tooling package.\n'
      '// ignore_for_file: depend_on_referenced_packages\n'
      "import 'package:runtime_ci_tooling/src/triage/triage_cli.dart' as triage;\n\n"
      'Future<void> main(List<String> args) => triage.main(args);\n',
    );
    _success('Created scripts/triage/triage_cli.dart');
  }

  // ── 8. Summary ─────────────────────────────────────────────────────────
  print('');
  _header('Init Complete');
  _info('  Config:    $kConfigFileName');
  _info('  Package:   $packageName');
  _info('  Owner:     $repoOwner');
  _info('  Areas:     ${areaLabels.join(", ")}');
  _info('  Changelog: ${hasChangelog ? "found" : "not found (will be created on first release)"}');
  _info('  .github/:  ${hasGithub ? "exists (not overwritten)" : "not found"}');
  _info('  .gemini/:  ${hasGemini ? "exists (not overwritten)" : "not found"}');
  print('');
  _info('Next steps:');
  _info('  1. Review .runtime_ci/config.json and customize area labels, cross-repo, etc.');
  _info('  2. Add runtime_ci_tooling as a dev_dependency in pubspec.yaml');
  _info('  3. Run: dart run scripts/manage_cicd.dart setup');
  _info('  4. Run: dart run scripts/manage_cicd.dart status');
}
