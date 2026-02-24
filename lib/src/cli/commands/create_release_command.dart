import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../../triage/utils/config.dart';
import '../../triage/utils/run_context.dart';
import '../manage_cicd_cli.dart';
import '../options/create_release_options.dart';
import '../options/version_options.dart';
import '../utils/ci_constants.dart';
import '../utils/file_utils.dart';
import '../utils/logger.dart';
import '../utils/process_runner.dart';
import '../utils/release_utils.dart';
import '../utils/repo_utils.dart';
import '../utils/step_summary.dart';
import '../utils/sub_package_utils.dart';
import '../utils/version_detection.dart';

/// Create a GitHub release: copy artifacts, save release notes folder, commit,
/// tag, gh release create.
///
/// Replaces 5 bash blocks in the create-release job.
class CreateReleaseCommand extends Command<void> {
  @override
  final String name = 'create-release';

  @override
  final String description = 'Create git tag, GitHub Release, commit all changes.';

  CreateReleaseCommand() {
    CreateReleaseOptionsArgParser.populateParser(argParser);
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
    final crOpts = CreateReleaseOptions.fromArgResults(argResults!);
    final versionOpts = VersionOptions.fromArgResults(argResults!);

    Logger.header('Create Release');

    final artifactsDir = crOpts.artifactsDir;
    final repo = crOpts.repo;

    final newVersion = versionOpts.version;
    if (newVersion == null) {
      Logger.error('--version <ver> is required for create-release');
      exit(1);
    }

    final prevTag = versionOpts.prevTag ?? VersionDetection.detectPrevTag(repoRoot, verbose: global.verbose);
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
            Logger.info('Copied $name from artifacts');
          }
        }

        // Copy autodoc.json from artifacts (updated hashes from compose stage)
        final autodocSrc = File('${artDir.path}/$kRuntimeCiDir/autodoc.json');
        if (autodocSrc.existsSync()) {
          Directory('$repoRoot/$kRuntimeCiDir').createSync(recursive: true);
          autodocSrc.copySync('$repoRoot/$kRuntimeCiDir/autodoc.json');
          Logger.info('Copied autodoc.json from artifacts');
        }

        // Copy generated docs/ directory from artifacts (autodoc output)
        final docsSrc = Directory('${artDir.path}/docs');
        if (docsSrc.existsSync()) {
          _copyDirectory(docsSrc, Directory('$repoRoot/docs'));
          Logger.info('Copied docs/ from artifacts');
        }
      }
    }

    // Step 2: Bump version in pubspec.yaml
    //
    // The regex matches the top-level `version:` field by requiring that it
    // is followed by a semver-like value (digits and dots).  This avoids
    // accidentally matching YAML comments (`# version: ...`) or indented
    // dependency version constraints, which are prefixed with whitespace and
    // use caret/range syntax (e.g. `  version: ^1.0.0`).
    final pubspecFile = File('$repoRoot/pubspec.yaml');
    final pubspecContent = pubspecFile.readAsStringSync();
    final versionPattern = RegExp(r'^version:\s+\d', multiLine: true);
    if (!versionPattern.hasMatch(pubspecContent)) {
      Logger.error('No "version:" field found in pubspec.yaml — cannot bump.');
      exit(1);
    }
    // Replace the entire version line (including the value) using a
    // separate regex so we capture the full line for replacement.
    final versionLinePattern = RegExp(r'^version:\s+.*', multiLine: true);
    pubspecFile.writeAsStringSync(pubspecContent.replaceFirst(versionLinePattern, 'version: $newVersion'));
    Logger.info('Bumped pubspec.yaml to version $newVersion');

    // Step 2b: Bump version in sub-package pubspec.yaml files
    final subPackages = SubPackageUtils.loadSubPackages(repoRoot);
    SubPackageUtils.logSubPackages(subPackages);
    for (final pkg in subPackages) {
      final subPubspec = File('$repoRoot/${pkg['path']}/pubspec.yaml');
      if (subPubspec.existsSync()) {
        final content = subPubspec.readAsStringSync();
        if (!versionPattern.hasMatch(content)) {
          Logger.warn('No "version:" field in ${pkg['name']}/pubspec.yaml — skipping bump');
          continue;
        }
        subPubspec.writeAsStringSync(content.replaceFirst(versionLinePattern, 'version: $newVersion'));
        Logger.info('Bumped ${pkg['name']}/pubspec.yaml to version $newVersion');
      } else {
        Logger.warn('Sub-package pubspec not found: ${pkg['path']}/pubspec.yaml');
      }
    }

    // Step 2c: Convert sibling deps to git format + strip resolution: workspace
    final siblingConversions = SubPackageUtils.convertSiblingDepsForRelease(
      repoRoot: repoRoot,
      newVersion: newVersion,
      effectiveRepo: effectiveRepo,
      subPackages: subPackages,
      verbose: global.verbose,
    );
    if (siblingConversions > 0) {
      Logger.success('Converted $siblingConversions sibling dep(s) to git format');
    }

    // Step 3: Assemble release notes folder from Stage 3 artifacts
    final releaseDir = Directory('$repoRoot/$kReleaseNotesDir/v$newVersion');
    releaseDir.createSync(recursive: true);

    // Copy Stage 3 release notes -- check multiple possible locations
    final releaseNotesSearchPaths = [
      '${releaseDir.path}/release_notes.md',
      '$repoRoot/release-notes-artifacts/release_notes/v$newVersion/release_notes.md',
      '$kStagingDir/release_notes_body.md',
      '$repoRoot/${artifactsDir ?? "."}/release_notes_body.md',
    ];

    File? foundReleaseNotes;
    for (final path in releaseNotesSearchPaths) {
      final f = File(path);
      if (f.existsSync() && f.lengthSync() > 100) {
        foundReleaseNotes = f;
        Logger.info('Found release notes at: $path (${f.lengthSync()} bytes)');
        break;
      }
    }

    if (foundReleaseNotes != null && foundReleaseNotes.path != '${releaseDir.path}/release_notes.md') {
      foundReleaseNotes.copySync('${releaseDir.path}/release_notes.md');
      Logger.info('Copied release notes to ${releaseDir.path}/release_notes.md');
    } else if (foundReleaseNotes == null) {
      File(
        '${releaseDir.path}/release_notes.md',
      ).writeAsStringSync(ReleaseUtils.buildFallbackReleaseNotes(repoRoot, newVersion, prevTag));
      Logger.warn('No Stage 3 release notes found -- generated fallback');
    }

    // Copy Stage 3 migration guide if it exists
    final migrationSearchPaths = [
      '${releaseDir.path}/migration_guide.md',
      '$repoRoot/release-notes-artifacts/release_notes/v$newVersion/migration_guide.md',
      '$kStagingDir/migration_guide.md',
    ];
    for (final path in migrationSearchPaths) {
      final f = File(path);
      if (f.existsSync() && f.lengthSync() > 50) {
        if (path != '${releaseDir.path}/migration_guide.md') {
          f.copySync('${releaseDir.path}/migration_guide.md');
        }
        Logger.info('Migration guide: ${f.lengthSync()} bytes');
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
      Logger.info('Highlights: ${existingHighlights.lengthSync()} bytes');
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
    final contribs = ReleaseUtils.gatherVerifiedContributors(repoRoot, prevTag);
    File(
      '${releaseDir.path}/contributors.json',
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(contribs));

    Logger.success('Release notes assembled in $kReleaseNotesDir/v$newVersion/');

    if (global.dryRun) {
      Logger.info('[DRY-RUN] Would commit, tag, and create GitHub Release');
      return;
    }

    // Step 4: Commit all changes
    CiProcessRunner.exec('git', ['config', 'user.name', 'github-actions[bot]'], cwd: repoRoot, verbose: global.verbose);
    CiProcessRunner.exec(
      'git',
      ['config', 'user.email', 'github-actions[bot]@users.noreply.github.com'],
      cwd: repoRoot,
      verbose: global.verbose,
    );

    final filesToAdd = [
      'pubspec.yaml',
      'CHANGELOG.md',
      'README.md',
      '$kReleaseNotesDir/',
      '$kVersionBumpsDir/',
      '$kRuntimeCiDir/autodoc.json',
    ];
    // Add sub-package pubspec.yaml files to the commit
    for (final pkg in subPackages) {
      filesToAdd.add('${pkg['path']}/pubspec.yaml');
    }
    if (Directory('$repoRoot/docs').existsSync()) filesToAdd.add('docs/');
    if (Directory('$repoRoot/$kCicdAuditDir').existsSync()) {
      filesToAdd.add('$kCicdAuditDir/');
    }
    for (final path in filesToAdd) {
      final fullPath = '$repoRoot/$path';
      if (File(fullPath).existsSync() || Directory(fullPath).existsSync()) {
        CiProcessRunner.exec('git', ['add', path], cwd: repoRoot, verbose: global.verbose);
      }
    }

    final diffResult = Process.runSync('git', ['diff', '--cached', '--quiet'], workingDirectory: repoRoot);
    if (diffResult.exitCode != 0) {
      // Build a rich, detailed commit message from available artifacts
      final commitMsg = ReleaseUtils.buildReleaseCommitMessage(
        repoRoot: repoRoot,
        version: newVersion,
        prevTag: prevTag,
        releaseDir: releaseDir,
        verbose: global.verbose,
      );
      // Use a temp file for the commit message to avoid shell escaping issues
      final commitMsgFile = File('$repoRoot/.git/RELEASE_COMMIT_MSG');
      commitMsgFile.writeAsStringSync(commitMsg);
      CiProcessRunner.exec(
        'git',
        ['commit', '-F', commitMsgFile.path],
        cwd: repoRoot,
        fatal: true,
        verbose: global.verbose,
      );
      commitMsgFile.deleteSync();

      // Use GH_TOKEN for push authentication (HTTPS remote)
      final ghToken = Platform.environment['GH_TOKEN'] ?? Platform.environment['GITHUB_TOKEN'];
      final remoteRepo = Platform.environment['GITHUB_REPOSITORY'] ?? effectiveRepo;
      if (ghToken != null && remoteRepo.isNotEmpty) {
        CiProcessRunner.exec(
          'git',
          ['remote', 'set-url', 'origin', 'https://x-access-token:$ghToken@github.com/$remoteRepo.git'],
          cwd: repoRoot,
          verbose: global.verbose,
        );
      }
      // Try to push directly first. The release pipeline runs on a fresh checkout,
      // so normally there are no remote changes to integrate. If the push fails
      // (e.g. another pipeline job pushed between checkout and now), fall back to
      // fetch + merge (NOT rebase — rebase fails when there are unstaged changes
      // from earlier pipeline steps like autodoc/compose-artifacts).
      final pushResult = Process.runSync('git', ['push', 'origin', 'main'], workingDirectory: repoRoot);
      if (pushResult.exitCode != 0) {
        Logger.warn('Direct push failed (non-fast-forward); fetching and merging remote changes...');
        if (global.verbose) Logger.info('  push stderr: ${(pushResult.stderr as String).trim()}');
        CiProcessRunner.exec('git', ['fetch', 'origin', 'main'], cwd: repoRoot, fatal: true, verbose: global.verbose);
        CiProcessRunner.exec(
          'git',
          ['merge', 'origin/main', '--no-edit'],
          cwd: repoRoot,
          fatal: true,
          verbose: global.verbose,
        );
        CiProcessRunner.exec('git', ['push', 'origin', 'main'], cwd: repoRoot, fatal: true, verbose: global.verbose);
      }
      Logger.success('Committed and pushed changes');
    } else {
      Logger.info('No changes to commit');
    }

    // Step 5: Create git tag (verify it doesn't already exist)
    // Use refs/tags/ prefix to avoid matching branches with the same name.
    final tagCheck = Process.runSync('git', ['rev-parse', 'refs/tags/$tag'], workingDirectory: repoRoot);
    if (tagCheck.exitCode == 0) {
      Logger.error('Tag $tag already exists. Cannot create release.');
      exit(1);
    }
    CiProcessRunner.exec(
      'git',
      ['tag', '-a', tag, '-m', 'Release v$newVersion'],
      cwd: repoRoot,
      fatal: true,
      verbose: global.verbose,
    );
    CiProcessRunner.exec('git', ['push', 'origin', tag], cwd: repoRoot, fatal: true, verbose: global.verbose);
    Logger.success('Created tag: $tag');

    // Step 5b: Create per-package tags for sub-packages with tag_pattern
    final pkgTagsCreated = <String>[];
    for (final pkg in subPackages) {
      final tp = pkg['tag_pattern'] as String?;
      if (tp == null) continue;
      final pkgTag = tp.replaceAll('{{version}}', newVersion);
      // Use refs/tags/ prefix to avoid matching branches with the same name.
      final pkgTagCheck = Process.runSync('git', ['rev-parse', 'refs/tags/$pkgTag'], workingDirectory: repoRoot);
      if (pkgTagCheck.exitCode == 0) {
        Logger.warn('Per-package tag $pkgTag already exists -- skipping');
        continue;
      }
      try {
        CiProcessRunner.exec(
          'git',
          ['tag', '-a', pkgTag, '-m', '${pkg['name']} v$newVersion'],
          cwd: repoRoot,
          fatal: true,
          verbose: global.verbose,
        );
        CiProcessRunner.exec('git', ['push', 'origin', pkgTag], cwd: repoRoot, fatal: true, verbose: global.verbose);
        pkgTagsCreated.add(pkgTag);
      } catch (e) {
        Logger.error('Failed to create per-package tag $pkgTag: $e');
        Logger.error('  Recovery: git tag -a $pkgTag -m "${pkg['name']} v$newVersion" && git push origin $pkgTag');
      }
    }
    if (pkgTagsCreated.isNotEmpty) {
      Logger.success(
        'Created ${pkgTagsCreated.length} per-package tag(s): '
        '${pkgTagsCreated.join(', ')}',
      );
    }

    // Step 6: Create GitHub Release using Stage 3 release notes
    var releaseBody = '';
    final bodyFile = File('${releaseDir.path}/release_notes.md');
    if (bodyFile.existsSync() && bodyFile.lengthSync() > 50) {
      releaseBody = bodyFile.readAsStringSync();
    } else {
      releaseBody = ReleaseUtils.buildFallbackReleaseNotes(repoRoot, newVersion, prevTag);
    }

    // Add footer with links
    final changelogLink = File('$repoRoot/CHANGELOG.md').existsSync()
        ? ' | [CHANGELOG.md](https://github.com/$effectiveRepo/blob/v$newVersion/CHANGELOG.md)'
        : '';
    final migrationLink = File('${releaseDir.path}/migration_guide.md').existsSync()
        ? ' | [Migration Guide]($kReleaseNotesDir/v$newVersion/migration_guide.md)'
        : '';
    releaseBody +=
        '\n\n---\n[Full Changelog](https://github.com/$effectiveRepo/compare/$prevTag...v$newVersion)'
        '$changelogLink$migrationLink';

    final ghArgs = ['release', 'create', tag, '--title', 'v$newVersion', '--notes', releaseBody];
    if (effectiveRepo.isNotEmpty) ghArgs.addAll(['--repo', effectiveRepo]);

    CiProcessRunner.exec('gh', ghArgs, cwd: repoRoot, verbose: global.verbose);
    Logger.success('Created GitHub Release: $tag');

    // Build rich summary
    final rnPreview = FileUtils.readFileOr('${releaseDir.path}/release_notes.md');
    final clEntryContent = FileUtils.readFileOr('${releaseDir.path}/changelog_entry.md');
    final contribContent = FileUtils.readFileOr('${releaseDir.path}/contributors.json');

    StepSummary.write('''
## Release Created

| Field | Value |
|-------|-------|
| Version | **v$newVersion** |
| Tag | [`$tag`](https://github.com/$effectiveRepo/tree/$tag) |
| Repository | `$effectiveRepo` |
| pubspec.yaml | Bumped to `$newVersion` |
${subPackages.isNotEmpty ? '| Sub-packages | ${subPackages.map((p) => '`${p['name']}`').join(', ')} bumped to `$newVersion` |' : ''}
${siblingConversions > 0 ? '| Sibling Deps | $siblingConversions dep(s) converted to git format |' : ''}
${pkgTagsCreated.isNotEmpty ? '| Per-Package Tags | ${pkgTagsCreated.map((t) => '`$t`').join(', ')} |' : ''}

### Links

- ${StepSummary.releaseLink(newVersion)}
- ${StepSummary.compareLink(prevTag, tag, 'Full Changelog')}
- ${StepSummary.ghLink('CHANGELOG.md', 'CHANGELOG.md')}
- ${StepSummary.ghLink('$kReleaseNotesDir/v$newVersion/', '$kReleaseNotesDir/v$newVersion/')}

${StepSummary.collapsible('Release Notes', rnPreview, open: true)}
${StepSummary.collapsible('CHANGELOG Entry', '```markdown\n$clEntryContent\n```')}
${StepSummary.collapsible('Contributors (JSON)', '```json\n$contribContent\n```')}

${StepSummary.artifactLink()}
''');
  }

  /// Recursively copy a directory tree.
  void _copyDirectory(Directory source, Directory destination) {
    destination.createSync(recursive: true);
    for (final entity in source.listSync(recursive: false)) {
      final newPath = '${destination.path}/${entity.uri.pathSegments.last}';
      if (entity is File) {
        entity.copySync(newPath);
      } else if (entity is Directory) {
        _copyDirectory(entity, Directory(newPath));
      }
    }
  }
}
