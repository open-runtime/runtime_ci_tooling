import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../../triage/utils/config.dart';
import '../../triage/utils/run_context.dart';
import '../manage_cicd_cli.dart';
import '../options/version_options.dart';
import '../utils/gemini_utils.dart';
import '../utils/logger.dart';
import '../utils/process_runner.dart';
import '../utils/prompt_resolver.dart';
import '../utils/release_utils.dart';
import '../utils/repo_utils.dart';
import '../utils/step_summary.dart';
import '../utils/version_detection.dart';

const String _kGeminiProModel = 'gemini-3-1-pro-preview';

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
class ReleaseNotesCommand extends Command<void> {
  @override
  final String name = 'release-notes';

  @override
  final String description =
      'Run Stage 3 Release Notes Author (Gemini 3 Pro Preview).';

  ReleaseNotesCommand() {
    VersionOptionsArgParser.populateParser(argParser);
  }

  @override
  Future<void> run() async {
    final repoRoot = RepoUtils.findRepoRoot();
    if (repoRoot == null) {
      Logger.error('Could not find ${config.repoName} repo root.');
      exit(1);
    }
    final global = ManageCicdCli.parseGlobalOptions(globalResults);
    final versionOpts = VersionOptions.fromArgResults(argResults!);

    Logger.header('Stage 3: Release Notes Author (Gemini 3 Pro Preview)');

    if (!GeminiUtils.geminiAvailable(warnOnly: true)) {
      Logger.warn('Skipping release notes (Gemini unavailable).');
      // Create minimal fallback
      final newVersion = versionOpts.version ?? 'unknown';
      final fallback =
          '# ${config.repoName} v$newVersion\n\nSee CHANGELOG.md for details.';
      File('/tmp/release_notes_body.md').writeAsStringSync(fallback);
      return;
    }

    final ctx = RunContext.create(repoRoot, 'release-notes');
    final prevTag = versionOpts.prevTag ??
        VersionDetection.detectPrevTag(repoRoot, verbose: global.verbose);
    final newVersion = versionOpts.version ??
        VersionDetection.detectNextVersion(repoRoot, prevTag,
            verbose: global.verbose);

    // Derive bump type
    final currentVersion = CiProcessRunner.runSync(
        "awk '/^version:/{print \$2}' pubspec.yaml", repoRoot,
        verbose: global.verbose);
    final currentParts = currentVersion.split('.');
    final newParts = newVersion.split('.');
    String bumpType = 'minor';
    if (currentParts.length >= 3 && newParts.length >= 3) {
      if (int.tryParse(newParts[0]) != int.tryParse(currentParts[0])) {
        bumpType = 'major';
      } else if (int.tryParse(newParts[1]) !=
          int.tryParse(currentParts[1])) {
        bumpType = 'minor';
      } else {
        bumpType = 'patch';
      }
    }

    Logger.info('Previous tag: $prevTag');
    Logger.info('New version: $newVersion');
    Logger.info('Bump type: $bumpType');
    Logger.info('Run dir: ${ctx.runDir}');

    // -- Gather VERIFIED contributor data BEFORE Gemini runs --
    final releaseNotesDir =
        Directory('$repoRoot/$kReleaseNotesDir/v$newVersion');
    releaseNotesDir.createSync(recursive: true);
    final verifiedContributors =
        ReleaseUtils.gatherVerifiedContributors(repoRoot, prevTag);
    File('${releaseNotesDir.path}/contributors.json').writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(verifiedContributors));
    Logger.info(
        'Verified contributors: ${verifiedContributors.map((c) => '@${c['username']}').join(', ')}');

    // -- Load issue manifest for verified issue data --
    List<dynamic> verifiedIssues = [];
    for (final path in [
      '/tmp/issue_manifest.json',
      '$repoRoot/$kCicdRunsDir/triage/issue_manifest.json',
    ]) {
      if (File(path).existsSync()) {
        try {
          final manifest = json.decode(File(path).readAsStringSync())
              as Map<String, dynamic>;
          verifiedIssues = (manifest['github_issues'] as List?) ?? [];
        } catch (_) {}
        break;
      }
    }
    Logger.info('Verified issues: ${verifiedIssues.length}');

    // Generate prompt
    final rnScript =
        PromptResolver.promptScript('gemini_release_notes_author_prompt.dart');
    Logger.info('Generating release notes prompt from $rnScript...');
    if (!File(rnScript).existsSync()) {
      Logger.error('Prompt script not found: $rnScript');
      exit(1);
    }
    final prompt = CiProcessRunner.runSync(
        'dart run $rnScript "$prevTag" "$newVersion" "$bumpType"', repoRoot,
        verbose: global.verbose);
    if (prompt.isEmpty) {
      Logger.error('Release notes prompt generator produced empty output.');
      exit(1);
    }
    ctx.savePrompt('release-notes', prompt);

    if (global.dryRun) {
      Logger.info(
          '[DRY-RUN] Would run Gemini CLI for release notes (${prompt.length} chars)');
      return;
    }

    final promptPath = ctx.artifactPath('release-notes', 'prompt.txt');

    // Build @ includes
    final includes = <String>[];
    final artifactNames = [
      'commit_analysis.json',
      'pr_data.json',
      'breaking_changes.json',
    ];
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

    Logger.info('Running Gemini 3 Pro for release notes authoring...');
    Logger.info('Bump type: $bumpType');
    Logger.info('File context: ${includes.join(", ")}');

    final result = Process.runSync(
      'sh',
      [
        '-c',
        'cat $promptPath | gemini '
            '-o json --yolo '
            '-m $_kGeminiProModel '
            "--allowed-tools 'run_shell_command(git),run_shell_command(gh),run_shell_command(cat),run_shell_command(head),run_shell_command(tail)' "
            '${includes.join(" ")}',
      ],
      workingDirectory: repoRoot,
      environment: {...Platform.environment},
    );

    if (result.exitCode != 0) {
      Logger.warn('Gemini CLI failed for release notes: ${result.stderr}');
      // Create fallback
      final fallback =
          '# ${config.repoName} v$newVersion\n\nSee CHANGELOG.md for details.';
      File('/tmp/release_notes_body.md').writeAsStringSync(fallback);
      ctx.finalize(exitCode: result.exitCode);
      return;
    }

    final rawOutput = result.stdout as String;
    ctx.saveResponse('release-notes', rawOutput);

    try {
      final jsonStr = GeminiUtils.extractJson(rawOutput);
      final response = json.decode(jsonStr) as Map<String, dynamic>;
      final stats = response['stats'] as Map<String, dynamic>?;
      Logger.success('Stage 3 completed.');
      if (stats != null) {
        Logger.info('  Tool calls: ${stats['tools']?['totalCalls']}');
        Logger.info('  Duration: ${stats['session']?['duration']}ms');
      }
    } catch (e) {
      Logger.warn('Could not parse Gemini response stats: $e');
    }

    // Validate output files
    final releaseNotesFile =
        File('${releaseNotesDir.path}/release_notes.md');
    final migrationFile =
        File('${releaseNotesDir.path}/migration_guide.md');
    final linkedIssuesFile =
        File('${releaseNotesDir.path}/linked_issues.json');
    final highlightsFile =
        File('${releaseNotesDir.path}/highlights.md');

    if (releaseNotesFile.existsSync()) {
      var content = releaseNotesFile.readAsStringSync();
      Logger.success('Raw release notes: ${content.length} chars');

      // -- POST-PROCESS: Replace Gemini's hallucinated sections with verified data --
      content = _postProcessReleaseNotes(
        content,
        verifiedContributors: verifiedContributors,
        verifiedIssues: verifiedIssues,
        repoSlug: Platform.environment['GITHUB_REPOSITORY'] ??
            '${config.repoOwner}/${config.repoName}',
        repoRoot: repoRoot,
      );
      Logger.success('Post-processed release notes: ${content.length} chars');

      // Write back the cleaned version
      releaseNotesFile.writeAsStringSync(content);
      File('/tmp/release_notes_body.md').writeAsStringSync(content);
      ctx.saveArtifact('release-notes', 'release_notes.md', content);
    } else {
      Logger.warn(
          'Gemini did not produce release_notes.md -- creating from CHANGELOG');
      final fallback = ReleaseUtils.buildFallbackReleaseNotes(
          repoRoot, newVersion, prevTag);
      releaseNotesDir.createSync(recursive: true);
      releaseNotesFile.writeAsStringSync(fallback);
      File('/tmp/release_notes_body.md').writeAsStringSync(fallback);
      ctx.saveArtifact('release-notes', 'release_notes.md', fallback);
    }

    if (migrationFile.existsSync()) {
      Logger.success('Migration guide: ${migrationFile.lengthSync()} bytes');
      File('/tmp/migration_guide.md')
          .writeAsStringSync(migrationFile.readAsStringSync());
    } else if (bumpType == 'major') {
      Logger.warn('Major release but no migration guide generated');
    }

    if (linkedIssuesFile.existsSync()) {
      Logger.success(
          'Linked issues: ${linkedIssuesFile.lengthSync()} bytes');
    }

    if (highlightsFile.existsSync()) {
      Logger.success('Highlights: ${highlightsFile.lengthSync()} bytes');
    }

    // Build rich step summary
    final rnContent = releaseNotesFile.existsSync()
        ? releaseNotesFile.readAsStringSync()
        : '(not generated)';
    final migContent =
        migrationFile.existsSync() ? migrationFile.readAsStringSync() : '';
    final linkedContent = linkedIssuesFile.existsSync()
        ? linkedIssuesFile.readAsStringSync()
        : '';
    final hlContent =
        highlightsFile.existsSync() ? highlightsFile.readAsStringSync() : '';

    StepSummary.write('''
## Stage 3: Release Notes Author Complete

| Field | Value |
|-------|-------|
| Version | **v$newVersion** ($bumpType) |
| Gemini model | `$_kGeminiProModel` |
| Release notes | ${releaseNotesFile.existsSync() ? '${releaseNotesFile.lengthSync()} bytes' : 'Not generated'} |
| Migration guide | ${migrationFile.existsSync() ? '${migrationFile.lengthSync()} bytes' : 'N/A'} |
| Linked issues | ${linkedIssuesFile.existsSync() ? '${linkedIssuesFile.lengthSync()} bytes' : 'N/A'} |
| Highlights | ${highlightsFile.existsSync() ? '${highlightsFile.lengthSync()} bytes' : 'N/A'} |

${StepSummary.collapsible('Release Notes Preview', rnContent, open: true)}
${migContent.isNotEmpty ? StepSummary.collapsible('Migration Guide', migContent) : ''}
${hlContent.isNotEmpty ? StepSummary.collapsible('Highlights', hlContent) : ''}
${linkedContent.isNotEmpty ? StepSummary.collapsible('Linked Issues (JSON)', '```json\n$linkedContent\n```') : ''}

${StepSummary.artifactLink()}
''');

    ctx.finalize();
  }
}

/// Post-process Gemini's release notes to replace hallucinated data with
/// verified data.
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

  // -- Replace Contributors section --
  final contributorsSection = StringBuffer();
  contributorsSection.writeln('## Contributors');
  contributorsSection.writeln();
  if (verifiedContributors.isNotEmpty) {
    contributorsSection
        .writeln('Thanks to everyone who contributed to this release:');
    for (final c in verifiedContributors) {
      final username = c['username'] ?? '';
      if (username.isNotEmpty) {
        contributorsSection.writeln('- @$username');
      }
    }
  } else {
    contributorsSection.writeln('No contributor data available.');
  }

  result = result.replaceFirstMapped(
    RegExp(r'## Contributors.*?(?=\n## |\n---|\Z)', dotAll: true),
    (m) => contributorsSection.toString().trim(),
  );

  // -- Replace Issues Addressed section --
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

  // -- Validate issue references throughout the document --
  final issueRefs = RegExp(r'\(#(\d+)\)')
      .allMatches(result)
      .map((m) => int.parse(m.group(1)!))
      .toSet();
  if (issueRefs.isNotEmpty) {
    final validIssues =
        verifiedIssues.map((i) => i['number'] as int? ?? 0).toSet();
    final fabricated = issueRefs.difference(validIssues);

    if (fabricated.isNotEmpty) {
      Logger.warn(
          'Stripping ${fabricated.length} fabricated issue references: ${fabricated.map((n) => "#$n").join(", ")}');
      for (final num in fabricated) {
        result = result.replaceAll(
            RegExp(r'- \[#' + num.toString() + r'\]\([^)]*\)[^\n]*\n'), '');
        result = result.replaceAll('(#$num)', '');
      }
    }
  }

  return result;
}
