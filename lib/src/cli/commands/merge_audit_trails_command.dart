import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../../triage/utils/config.dart';
import '../../triage/utils/run_context.dart';
import '../manage_cicd_cli.dart';
import '../options/merge_audit_trails_options.dart';
import '../utils/file_utils.dart';
import '../utils/logger.dart';
import '../utils/repo_utils.dart';

/// Merge CI/CD audit trail artifacts from multiple jobs into a single
/// run directory under .runtime_ci/runs/.
///
/// In CI, each Gemini-powered job (determine-version, pre-release-triage,
/// explore-changes, compose-artifacts) uploads its .runtime_ci/runs/ contents as
/// a uniquely-named artifact. The create-release job downloads them all into
/// a staging directory, then calls this command to merge them into a single
/// run directory that archive-run can process.
class MergeAuditTrailsCommand extends Command<void> {
  @override
  final String name = 'merge-audit-trails';

  @override
  final String description =
      'Merge CI/CD audit artifacts from multiple jobs (CI use).';

  MergeAuditTrailsCommand() {
    MergeAuditTrailsOptionsArgParser.populateParser(argParser);
  }

  @override
  Future<void> run() async {
    final repoRoot = RepoUtils.findRepoRoot();
    if (repoRoot == null) {
      Logger.error('Could not find ${config.repoName} repo root.');
      exit(1);
    }
    // ignore: unused_local_variable -- parsed for consistency with other commands
    final global = ManageCicdCli.parseGlobalOptions(globalResults);
    final matOpts = MergeAuditTrailsOptions.fromArgResults(argResults!);

    Logger.header('Merge Audit Trails');

    final incomingDir =
        matOpts.incomingDir ?? '$kRuntimeCiDir/runs_incoming';
    final outputDir = matOpts.outputDir ?? kCicdRunsDir;

    final incomingPath = incomingDir.startsWith('/')
        ? incomingDir
        : '$repoRoot/$incomingDir';
    final incoming = Directory(incomingPath);
    if (!incoming.existsSync()) {
      Logger.warn('No incoming audit trails found at $incomingDir');
      Logger.warn(
          'Skipping merge (no artifacts uploaded by prior jobs).');
      return;
    }

    final artifactDirs =
        incoming.listSync().whereType<Directory>().toList();
    if (artifactDirs.isEmpty) {
      Logger.warn(
          'Incoming directory exists but contains no artifact subdirectories.');
      return;
    }

    // Create the merged run directory with a unique timestamp
    final now = DateTime.now();
    final timestamp = now
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-')
        .substring(0, 19);
    final outputPath =
        outputDir.startsWith('/') ? outputDir : '$repoRoot/$outputDir';
    final mergedRunDir = '$outputPath/run_${timestamp}_merged';
    Directory(mergedRunDir).createSync(recursive: true);

    final sources = <Map<String, dynamic>>[];
    var totalFiles = 0;

    for (final artifactDir in artifactDirs) {
      final artifactName = artifactDir.path.split('/').last;
      Logger.info('Processing artifact: $artifactName');

      for (final entity in artifactDir.listSync()) {
        if (entity is Directory) {
          final dirName = entity.path.split('/').last;

          if (dirName.startsWith('run_')) {
            // RunContext directory -- copy each phase subdirectory into the
            // merged run
            for (final child in entity.listSync()) {
              if (child is Directory) {
                final phaseName = child.path.split('/').last;
                FileUtils.copyDirRecursive(
                    child, Directory('$mergedRunDir/$phaseName'));
                totalFiles += FileUtils.countFiles(child);
                Logger.info(
                    '  Merged phase: $phaseName (from $artifactName)');
              } else if (child is File) {
                final fileName = child.path.split('/').last;
                if (fileName == 'meta.json') {
                  // Collect source meta for the merged meta.json
                  try {
                    final meta =
                        json.decode(child.readAsStringSync())
                            as Map<String, dynamic>;
                    sources.add({'artifact': artifactName, ...meta});
                  } catch (_) {
                    sources.add({
                      'artifact': artifactName,
                      'error': 'failed to parse meta.json',
                    });
                  }
                }
              }
            }
          } else {
            // Non-RunContext directory (e.g. version_analysis/) -- copy as-is
            FileUtils.copyDirRecursive(
                entity, Directory('$mergedRunDir/$dirName'));
            totalFiles += FileUtils.countFiles(entity);
            Logger.info(
                '  Merged directory: $dirName (from $artifactName)');
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
    File('$mergedRunDir/meta.json').writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(mergedMeta)}\n');

    Logger.success(
        'Merged ${artifactDirs.length} audit trail(s) into $mergedRunDir ($totalFiles files)');
  }
}
