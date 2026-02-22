import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:yaml/yaml.dart';

import '../../triage/utils/config.dart';
import '../options/global_options.dart';
import '../utils/logger.dart';
import '../utils/process_runner.dart';
import '../utils/repo_utils.dart';

const List<String> _kDefaultOrgs = ['open-runtime', 'pieces-app'];
const String _kDefaultPackageName = 'runtime_ci_tooling';
const int _kDefaultRepoLimit = 1000;
const int _kDefaultReleaseListLimit = 100;
const String _kRuntimeCiConfigPath = '.runtime_ci/config.json';
const String _kLatestReleaseSyncFileName = 'latest_release_sync.json';
const Duration _kSearchRequestMinInterval = Duration(seconds: 7);
final RegExp _kDiscoveryFilePattern = RegExp(r'^discovery_run_(\d+)_local_time_\d{2}_\d{2}_\d{2}\.json$');
final RegExp _kLegacyDiscoveryFilePattern = RegExp(r'^discovery_#(\d+)_local_time_\d{2}_\d{2}_\d{2}\.json$');

/// Discover repos that consume `runtime_ci_tooling`, then sync release artifacts.
class ConsumersCommand extends Command<void> {
  Future<void> _searchSerialQueue = Future<void>.value();
  DateTime? _lastSearchRequestAt;

  @override
  final String name = 'consumers';

  @override
  final String description = 'Discover runtime_ci_tooling consumers and sync latest release data.';

  ConsumersCommand() {
    argParser
      ..addMultiOption(
        'org',
        defaultsTo: _kDefaultOrgs,
        help: 'GitHub organizations to scan for consumer repositories.',
      )
      ..addOption(
        'package',
        defaultsTo: _kDefaultPackageName,
        help: 'Dart package name to discover in pubspec dependencies.',
      )
      ..addOption(
        'output-dir',
        defaultsTo: '.consumers',
        help: 'Directory where discovery snapshots and release data are written.',
      )
      ..addFlag('discover-only', negatable: false, help: 'Only run repository discovery.')
      ..addFlag('releases-only', negatable: false, help: 'Only run release syncing using latest discovery snapshot.')
      ..addOption('tag', help: 'Exact release tag to fetch from each repository.')
      ..addOption('tag-regex', help: 'Regex filter used when selecting latest release tag (ignored when --tag is set).')
      ..addFlag(
        'include-prerelease',
        negatable: false,
        help: 'Allow prereleases when selecting latest tags (default excludes prereleases).',
      )
      ..addFlag(
        'resume',
        defaultsTo: true,
        help:
            'Resume release sync from existing .consumers/repos/latest_release_sync.json and skip already-complete repos.',
      )
      ..addFlag(
        'search-first',
        defaultsTo: true,
        help: 'Use org-level code search prefilter before per-repo verification.',
      )
      ..addOption('discovery-workers', defaultsTo: '4', help: 'Max concurrent workers for discovery verification.')
      ..addOption('release-workers', defaultsTo: '4', help: 'Max concurrent workers for release syncing.')
      ..addOption(
        'repo-limit',
        defaultsTo: '$_kDefaultRepoLimit',
        help: 'Maximum repositories to inspect per organization.',
      );
  }

  /// Computes the next discovery index from existing discovery filenames.
  static int computeNextDiscoveryIndexFromNames(Iterable<String> fileNames) {
    var maxIndex = 0;
    for (final name in fileNames) {
      final parsed = _extractDiscoveryIndex(name);
      if (parsed != null && parsed > maxIndex) {
        maxIndex = parsed;
      }
    }
    return maxIndex + 1;
  }

  /// Builds a discovery filename in the required format.
  static String buildDiscoverySnapshotName({required int index, required DateTime localTime}) {
    final day = localTime.day.toString().padLeft(2, '0');
    final month = localTime.month.toString().padLeft(2, '0');
    final year = (localTime.year % 100).toString().padLeft(2, '0');
    return 'discovery_run_$index'
        '_local_time_${day}_$month'
        '_$year.json';
  }

  static int? _extractDiscoveryIndex(String fileName) {
    final match = _kDiscoveryFilePattern.firstMatch(fileName) ?? _kLegacyDiscoveryFilePattern.firstMatch(fileName);
    if (match == null) return null;
    return int.tryParse(match.group(1) ?? '');
  }

  /// Keeps release folder names aligned with tag names (e.g. v1.2.3).
  static String resolveVersionFolderName(String tagName) {
    return tagName.trim();
  }

  /// Filename identity used for resume across moved workspaces.
  static String snapshotIdentityFromPath(String path) {
    final normalized = path.replaceAll('\\', '/');
    final segments = normalized.split('/').where((segment) => segment.isNotEmpty).toList();
    if (segments.isEmpty) return normalized;
    return segments.last;
  }

  static String _normalizePathForComparisonText(String path) {
    var normalized = path.replaceAll('\\', '/').trim();
    while (normalized.endsWith('/') && normalized.length > 1) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  /// Compatible if either normalized path or filename identity matches.
  static bool isSnapshotSourceCompatible({
    required String? sourceSnapshotPath,
    required String? sourceSnapshotIdentity,
    required String expectedSnapshotPath,
  }) {
    final sourceIdentity = sourceSnapshotIdentity?.trim().isNotEmpty == true
        ? sourceSnapshotIdentity!.trim()
        : (sourceSnapshotPath == null ? null : snapshotIdentityFromPath(sourceSnapshotPath));
    final expectedIdentity = snapshotIdentityFromPath(expectedSnapshotPath);
    final normalizedSource = sourceSnapshotPath == null ? null : _normalizePathForComparisonText(sourceSnapshotPath);
    final normalizedExpected = _normalizePathForComparisonText(expectedSnapshotPath);
    final identityMatches = sourceIdentity == expectedIdentity;
    final pathMatches = normalizedSource == normalizedExpected;
    return identityMatches || pathMatches;
  }

  static bool isReleaseSummaryReusable({
    required String status,
    required String outputPath,
    required String? tag,
    required String? exactTag,
  }) {
    if (status == 'failed') return false;
    if (status == 'ok') {
      if (exactTag != null && exactTag.isNotEmpty && tag != exactTag) {
        return false;
      }
      return Directory(outputPath).existsSync();
    }
    if (status == 'no_release') {
      return File(outputPath).existsSync();
    }
    return false;
  }

  /// Returns the expected release output path for a repo/tag combination.
  static String buildReleaseOutputPath({required String outputDir, required String repoName, required String tagName}) {
    return _joinPath(outputDir, [repoName, resolveVersionFolderName(tagName)]);
  }

  /// Selects the latest matching tag from `gh release list` style JSON maps.
  static String? selectTagFromReleaseList({
    required List<Map<String, dynamic>> releases,
    required bool includePrerelease,
    RegExp? tagPattern,
  }) {
    final orderedReleases = List<Map<String, dynamic>>.from(releases)
      ..sort((a, b) {
        final aPublished = DateTime.tryParse(a['publishedAt']?.toString() ?? '');
        final bPublished = DateTime.tryParse(b['publishedAt']?.toString() ?? '');
        if (aPublished == null && bPublished == null) return 0;
        if (aPublished == null) return 1;
        if (bPublished == null) return -1;
        return bPublished.compareTo(aPublished);
      });

    for (final release in orderedReleases) {
      if (release['isDraft'] == true) continue;
      final isPrerelease = release['isPrerelease'] == true;
      if (!includePrerelease && isPrerelease) continue;

      final tag = release['tagName']?.toString().trim() ?? '';
      if (tag.isEmpty) continue;
      if (tagPattern != null && !tagPattern.hasMatch(tag)) continue;

      return tag;
    }
    return null;
  }

  @override
  Future<void> run() async {
    final repoRoot = RepoUtils.findRepoRoot();
    if (repoRoot == null) {
      Logger.error('Could not find ${config.repoName} repo root.');
      exit(1);
    }
    final global = globalResults == null ? const GlobalOptions() : GlobalOptions.fromArgResults(globalResults!);
    final options = _ConsumersOptions.fromArgResults(argResults!);

    if (options.discoverOnly && options.releasesOnly) {
      throw UsageException('Cannot use --discover-only and --releases-only together.', usage);
    }

    RegExp? tagPattern;
    if (options.tagRegex != null) {
      try {
        tagPattern = RegExp(options.tagRegex!);
      } catch (error) {
        throw UsageException('Invalid --tag-regex: ${options.tagRegex}. Error: $error', usage);
      }
    }

    _runPreflightChecks(repoRoot: repoRoot, verbose: global.verbose);

    final outputDir = _resolveOutputDirectory(repoRoot: repoRoot, outputDirOption: options.outputDir);
    final reposDir = Directory(_joinPath(outputDir.path, ['repos']));
    final releaseSummaryPath = _joinPath(reposDir.path, [_kLatestReleaseSyncFileName]);

    final runDiscovery = !options.releasesOnly;
    final runReleases = !options.discoverOnly;

    _SnapshotResult snapshotResult;
    if (runDiscovery) {
      Logger.header('Consumers Discovery');
      final snapshotTarget = _nextSnapshotTarget(reposDir: reposDir);
      var lastDiscoveryCheckpointWrite = DateTime.fromMillisecondsSinceEpoch(0);
      if (global.dryRun) {
        Logger.info('[DRY-RUN] Would stream discovery updates to ${snapshotTarget.snapshotPath}');
      } else {
        _writeDiscoverySnapshotAtPath(
          snapshotPath: snapshotTarget.snapshotPath,
          index: snapshotTarget.index,
          startedLocal: snapshotTarget.localTime,
          packageName: options.packageName,
          orgs: options.orgs,
          discovery: const _DiscoveryResult(consumers: [], scannedRepos: 0, failures: []),
          runStatus: 'in_progress',
          dryRun: false,
        );
      }

      final discovery = await _discoverConsumers(
        searchFirst: options.searchFirst,
        discoveryWorkers: options.discoveryWorkers,
        repoRoot: repoRoot,
        packageName: options.packageName,
        orgs: options.orgs,
        repoLimit: options.repoLimit,
        verbose: global.verbose,
        onProgress: (partial) {
          if (global.dryRun) return;
          final now = DateTime.now();
          final shouldFlush =
              partial.scannedRepos % 10 == 0 ||
              now.difference(lastDiscoveryCheckpointWrite) >= const Duration(seconds: 2);
          if (!shouldFlush) {
            return;
          }
          _writeDiscoverySnapshotAtPath(
            snapshotPath: snapshotTarget.snapshotPath,
            index: snapshotTarget.index,
            startedLocal: snapshotTarget.localTime,
            packageName: options.packageName,
            orgs: options.orgs,
            discovery: partial,
            runStatus: 'in_progress',
            dryRun: false,
          );
          lastDiscoveryCheckpointWrite = now;
        },
      );
      snapshotResult = _writeDiscoverySnapshotAtPath(
        snapshotPath: snapshotTarget.snapshotPath,
        index: snapshotTarget.index,
        startedLocal: snapshotTarget.localTime,
        packageName: options.packageName,
        orgs: options.orgs,
        discovery: discovery,
        runStatus: 'completed',
        dryRun: global.dryRun,
      );
      Logger.success('Discovered ${discovery.consumers.length} consumer repos.');
      Logger.info('Discovery snapshot: ${snapshotResult.snapshotPath}');
    } else {
      Logger.header('Consumers Release Sync');
      final loaded = _loadLatestDiscoverySnapshot(reposDir: reposDir);
      if (loaded == null) {
        Logger.error('No discovery snapshots found in ${reposDir.path}.');
        Logger.error('Run consumers command without --releases-only first.');
        exit(1);
      }
      snapshotResult = loaded;
      Logger.info('Loaded ${loaded.consumers.length} repos from ${loaded.snapshotPath}');
      if (loaded.runStatus != null && loaded.runStatus != 'completed') {
        Logger.warn('Latest discovery snapshot is not completed (run_status=${loaded.runStatus ?? "unknown"}).');
      }
    }

    if (!runReleases) {
      Logger.success('Discovery-only mode complete.');
      return;
    }

    if (snapshotResult.consumers.isEmpty) {
      Logger.warn('No consumer repositories to process.');
      return;
    }

    final criteria = _ReleaseSelectionCriteria(
      packageName: options.packageName,
      exactTag: options.tag,
      tagRegex: options.tagRegex,
      includePrerelease: options.includePrerelease,
    );
    final consumerRepoSet = snapshotResult.consumers.map((consumer) => consumer.fullName).toSet();
    final summaryByRepo = options.resume
        ? _loadExistingReleaseSummaries(
            releaseSummaryPath: releaseSummaryPath,
            expectedSnapshotPath: snapshotResult.snapshotPath,
            expectedCriteria: criteria,
            allowedRepos: consumerRepoSet,
          )
        : <String, _ReleaseSyncSummary>{};

    if (options.resume && summaryByRepo.isNotEmpty) {
      Logger.info('Resuming release sync with ${summaryByRepo.length} repos already completed.');
    }

    if (global.dryRun) {
      Logger.info('[DRY-RUN] Would stream release summary updates to $releaseSummaryPath');
    } else {
      _writeReleaseSummary(
        releaseSummaryPath: releaseSummaryPath,
        sourceSnapshotPath: snapshotResult.snapshotPath,
        criteria: criteria,
        packageName: options.packageName,
        repoCount: snapshotResult.consumers.length,
        summaries: summaryByRepo.values.toList(),
        runStatus: 'in_progress',
      );
    }

    final pendingConsumers = <_ConsumerRepo>[];
    for (final consumer in snapshotResult.consumers) {
      final existingSummary = summaryByRepo[consumer.fullName];
      if (existingSummary != null && _isCompletedSummaryReusable(existingSummary, exactTag: options.tag)) {
        Logger.info('Skipping ${consumer.fullName} (already completed in previous run).');
        continue;
      }
      pendingConsumers.add(consumer);
    }

    var completionsSinceFlush = 0;
    var lastReleaseCheckpointWrite = DateTime.now();
    Future<void> flushReleaseSummaryIfNeeded({required bool force}) async {
      if (global.dryRun) return;
      final now = DateTime.now();
      final shouldFlush =
          force ||
          completionsSinceFlush >= 3 ||
          now.difference(lastReleaseCheckpointWrite) >= const Duration(seconds: 2);
      if (!shouldFlush) return;
      _writeReleaseSummary(
        releaseSummaryPath: releaseSummaryPath,
        sourceSnapshotPath: snapshotResult.snapshotPath,
        criteria: criteria,
        packageName: options.packageName,
        repoCount: snapshotResult.consumers.length,
        summaries: summaryByRepo.values.toList(),
        runStatus: 'in_progress',
      );
      completionsSinceFlush = 0;
      lastReleaseCheckpointWrite = now;
    }

    Future<void> processConsumer(_ConsumerRepo consumer) async {
      Logger.info('');
      Logger.header('Sync ${consumer.fullName}');
      final summary = await _syncRepoRelease(
        repoRoot: repoRoot,
        outputDir: outputDir.path,
        consumer: consumer,
        exactTag: options.tag,
        tagPattern: tagPattern,
        includePrerelease: options.includePrerelease,
        verbose: global.verbose,
        dryRun: global.dryRun,
      );
      summaryByRepo[consumer.fullName] = summary;
      completionsSinceFlush++;
      await flushReleaseSummaryIfNeeded(force: false);
    }

    if (pendingConsumers.isNotEmpty) {
      if (options.releaseWorkers <= 1) {
        for (final consumer in pendingConsumers) {
          await processConsumer(consumer);
        }
      } else {
        await _forEachConcurrent<_ConsumerRepo>(
          items: pendingConsumers,
          concurrency: options.releaseWorkers,
          action: processConsumer,
        );
      }
      await flushReleaseSummaryIfNeeded(force: true);
    }

    final counts = _countReleaseStatuses(summaryByRepo.values);

    if (!global.dryRun) {
      _writeReleaseSummary(
        releaseSummaryPath: releaseSummaryPath,
        sourceSnapshotPath: snapshotResult.snapshotPath,
        criteria: criteria,
        packageName: options.packageName,
        repoCount: snapshotResult.consumers.length,
        summaries: summaryByRepo.values.toList(),
        runStatus: 'completed',
      );
      Logger.info('Release summary: $releaseSummaryPath');
    }

    if (counts.failureCount > 0) {
      Logger.warn('Release sync complete with failures: ${counts.failureCount} failed.');
      return;
    }
    Logger.success('Release sync complete. Success: ${counts.successCount}, no release: ${counts.noReleaseCount}.');
  }

  void _runPreflightChecks({required String repoRoot, required bool verbose}) {
    if (!CiProcessRunner.commandExists('gh')) {
      Logger.error('GitHub CLI (gh) is required but was not found on PATH.');
      exit(1);
    }

    final auth = Process.runSync('gh', ['auth', 'status'], workingDirectory: repoRoot);
    if (auth.exitCode != 0) {
      if (verbose) {
        final stderr = (auth.stderr as String).trim();
        if (stderr.isNotEmpty) {
          Logger.error(stderr);
        }
      }
      Logger.error('GitHub CLI is not authenticated. Run: gh auth login');
      exit(1);
    }
  }

  Future<_DiscoveryResult> _discoverConsumers({
    required bool searchFirst,
    required int discoveryWorkers,
    required String repoRoot,
    required String packageName,
    required List<String> orgs,
    required int repoLimit,
    required bool verbose,
    void Function(_DiscoveryResult partial)? onProgress,
  }) async {
    final consumersByRepo = <String, _ConsumerRepo>{};
    final failures = <Map<String, String>>[];
    var scannedRepos = 0;

    void emitProgress() {
      if (onProgress == null) return;
      final snapshotConsumers = consumersByRepo.values.toList()..sort((a, b) => a.fullName.compareTo(b.fullName));
      onProgress(
        _DiscoveryResult(
          consumers: snapshotConsumers,
          scannedRepos: scannedRepos,
          failures: List<Map<String, String>>.from(failures),
        ),
      );
    }

    for (final org in orgs) {
      Logger.info('Scanning org: $org');
      final repos = await _listReposForOrg(repoRoot: repoRoot, org: org, repoLimit: repoLimit, verbose: verbose);
      if (repos.isEmpty) continue;
      scannedRepos += repos.length;

      final prefilter = searchFirst
          ? await _searchFirstCandidatesForOrg(repoRoot: repoRoot, org: org, packageName: packageName, verbose: verbose)
          : const _OrgSearchPrefilter.failed();
      final usingFallback = !searchFirst || prefilter.failed || prefilter.incompleteResults;
      if (usingFallback && searchFirst) {
        Logger.warn('Search-first prefilter unavailable for $org; falling back to repo-by-repo verification.');
      }

      final candidatePathsByRepo = usingFallback ? const <String, List<String>>{} : prefilter.repoPathsByFullName;
      final candidateRepos = repos
          .where((repo) => repo.repo != packageName)
          .where((repo) => usingFallback || candidatePathsByRepo.containsKey(repo.fullName))
          .toList();
      if (candidateRepos.isEmpty) {
        emitProgress();
        continue;
      }

      var processedCandidates = 0;
      await _forEachConcurrent<_RepoDescriptor>(
        items: candidateRepos,
        concurrency: discoveryWorkers,
        action: (_RepoDescriptor repo) async {
          final prefilterPaths = candidatePathsByRepo[repo.fullName] ?? const <String>[];
          final consumer = await _discoverConsumerInRepo(
            allowRepoSearch: usingFallback,
            orgSearchUsed: !usingFallback,
            prefilterPaths: prefilterPaths,
            repoRoot: repoRoot,
            packageName: packageName,
            descriptor: repo,
            verbose: verbose,
          );
          processedCandidates++;
          if (consumer != null) {
            consumersByRepo[consumer.fullName] = consumer;
            Logger.success('  Consumer: ${consumer.fullName}');
            emitProgress();
          } else if (processedCandidates % 25 == 0) {
            emitProgress();
          }
        },
      );

      emitProgress();
    }

    final consumers = consumersByRepo.values.toList()..sort((a, b) => a.fullName.compareTo(b.fullName));
    return _DiscoveryResult(consumers: consumers, scannedRepos: scannedRepos, failures: failures);
  }

  Future<List<_RepoDescriptor>> _listReposForOrg({
    required String repoRoot,
    required String org,
    required int repoLimit,
    required bool verbose,
  }) async {
    final result = await _runProcess(
      executable: 'gh',
      args: ['repo', 'list', org, '--limit', '$repoLimit', '--json', 'name,nameWithOwner,isArchived'],
      cwd: repoRoot,
      verbose: verbose,
    );

    if (result.exitCode != 0) {
      final stderr = (result.stderr as String).trim();
      Logger.warn('Could not list repos for $org${stderr.isNotEmpty ? ': $stderr' : ''}');
      return [];
    }

    final stdout = (result.stdout as String).trim();
    if (stdout.isEmpty) return [];

    try {
      final parsed = json.decode(stdout);
      if (parsed is! List) return [];

      return parsed
          .whereType<Map<String, dynamic>>()
          .where((entry) => entry['isArchived'] != true)
          .map((entry) {
            final fullName = entry['nameWithOwner']?.toString().trim() ?? '';
            final repoName = entry['name']?.toString().trim() ?? '';
            if (fullName.isEmpty || repoName.isEmpty || !fullName.contains('/')) {
              return null;
            }
            final owner = fullName.split('/').first;
            return _RepoDescriptor(owner: owner, repo: repoName);
          })
          .whereType<_RepoDescriptor>()
          .toList();
    } catch (error) {
      Logger.warn('Could not parse repo list for $org: $error');
      return [];
    }
  }

  Future<_OrgSearchPrefilter> _searchFirstCandidatesForOrg({
    required String repoRoot,
    required String org,
    required String packageName,
    required bool verbose,
  }) async {
    final queries = <_OrgSearchQuery>[
      _OrgSearchQuery(query: '$packageName org:$org filename:pubspec.yaml'),
      _OrgSearchQuery(query: '$packageName org:$org'),
      _OrgSearchQuery(query: 'filename:config.json path:.runtime_ci org:$org'),
    ];

    final pathsByRepo = <String, Set<String>>{};
    var anyIncomplete = false;

    for (final query in queries) {
      final result = await _searchCodeByOrg(repoRoot: repoRoot, query: query.query, verbose: verbose);
      if (result.failed) {
        return const _OrgSearchPrefilter.failed();
      }
      if (result.incompleteResults) {
        anyIncomplete = true;
      }
      for (final hit in result.hits) {
        pathsByRepo.putIfAbsent(hit.fullName, () => <String>{}).add(hit.path);
      }
    }

    final normalized = <String, List<String>>{};
    for (final entry in pathsByRepo.entries) {
      final values = entry.value.toList()..sort();
      normalized[entry.key] = values;
    }
    return _OrgSearchPrefilter(failed: false, incompleteResults: anyIncomplete, repoPathsByFullName: normalized);
  }

  Future<_OrgSearchResult> _searchCodeByOrg({
    required String repoRoot,
    required String query,
    required bool verbose,
  }) async {
    final hits = <_OrgSearchHit>[];
    var page = 1;
    var incompleteResults = false;

    while (true) {
      final encodedQuery = Uri.encodeQueryComponent(query);
      final result = await _searchCodeApiRequest(
        repoRoot: repoRoot,
        args: ['api', 'search/code?q=$encodedQuery&per_page=100&page=$page'],
        verbose: verbose,
      );
      if (result.exitCode != 0) {
        return const _OrgSearchResult.failed();
      }

      final stdout = (result.stdout as String).trim();
      if (stdout.isEmpty) break;

      try {
        final parsed = json.decode(stdout);
        if (parsed is! Map<String, dynamic>) {
          return const _OrgSearchResult.failed();
        }
        incompleteResults = incompleteResults || parsed['incomplete_results'] == true;

        final items = parsed['items'];
        if (items is! List || items.isEmpty) {
          break;
        }

        var itemCount = 0;
        for (final item in items.whereType<Map<String, dynamic>>()) {
          final repository = item['repository'];
          if (repository is! Map<String, dynamic>) continue;
          final fullName = repository['full_name']?.toString().trim() ?? '';
          final path = item['path']?.toString().trim() ?? '';
          if (fullName.isEmpty || path.isEmpty) continue;
          hits.add(_OrgSearchHit(fullName: fullName, path: path));
          itemCount++;
        }

        if (itemCount < 100) {
          break;
        }
        page++;
      } catch (_) {
        return const _OrgSearchResult.failed();
      }
    }

    return _OrgSearchResult(failed: false, incompleteResults: incompleteResults, hits: hits);
  }

  Future<_ConsumerRepo?> _discoverConsumerInRepo({
    required bool allowRepoSearch,
    required bool orgSearchUsed,
    required List<String> prefilterPaths,
    required String repoRoot,
    required String packageName,
    required _RepoDescriptor descriptor,
    required bool verbose,
  }) async {
    final fullName = descriptor.fullName;
    var pubspec = await _fetchPubspec(repoRoot: repoRoot, fullName: fullName, verbose: verbose);
    var dependencyConstraint = _readDependencyConstraint(
      pubspec?.content,
      packageName: packageName,
      section: 'dependencies',
    );
    var devDependencyConstraint = _readDependencyConstraint(
      pubspec?.content,
      packageName: packageName,
      section: 'dev_dependencies',
    );

    final usageSignals = <String>{};
    String? runtimeCiConfigPath;
    String? matchedPath;
    if (dependencyConstraint != null || devDependencyConstraint != null) {
      matchedPath = pubspec?.path ?? 'pubspec.yaml';
      usageSignals.add('pubspec_dependency');
    } else {
      final prefilterPubspecPaths = prefilterPaths.where((path) => path.endsWith('pubspec.yaml')).toList();
      if (prefilterPubspecPaths.isNotEmpty) {
        matchedPath = prefilterPubspecPaths.first;
        usageSignals.add('org_search_pubspec');
      } else if (orgSearchUsed && prefilterPaths.isNotEmpty) {
        matchedPath = prefilterPaths.first;
        usageSignals.add('org_search_general');
      }

      if (prefilterPaths.contains(_kRuntimeCiConfigPath)) {
        runtimeCiConfigPath = _kRuntimeCiConfigPath;
        if (matchedPath == null) {
          matchedPath = _kRuntimeCiConfigPath;
        }
        usageSignals.add('runtime_ci_config');
      }

      if (matchedPath != null &&
          matchedPath.endsWith('pubspec.yaml') &&
          (pubspec == null || matchedPath != pubspec.path)) {
        final nestedPubspec = await _fetchPubspec(
          repoRoot: repoRoot,
          fullName: fullName,
          verbose: verbose,
          path: matchedPath,
        );
        if (nestedPubspec != null) {
          pubspec = nestedPubspec;
          dependencyConstraint = _readDependencyConstraint(
            nestedPubspec.content,
            packageName: packageName,
            section: 'dependencies',
          );
          devDependencyConstraint = _readDependencyConstraint(
            nestedPubspec.content,
            packageName: packageName,
            section: 'dev_dependencies',
          );
          if (dependencyConstraint != null || devDependencyConstraint != null) {
            usageSignals.add('pubspec_dependency_nested');
          }
        }
      }

      if (dependencyConstraint == null && devDependencyConstraint == null && matchedPath == null && allowRepoSearch) {
        final targetedSearch = await _searchCode(
          repoRoot: repoRoot,
          query: '$packageName repo:$fullName filename:pubspec.yaml',
          verbose: verbose,
        );
        if (targetedSearch.totalCount > 0) {
          matchedPath = targetedSearch.firstPath;
          usageSignals.add('code_search_pubspec');
        }
      }

      if (dependencyConstraint == null &&
          devDependencyConstraint == null &&
          matchedPath == null &&
          runtimeCiConfigPath == null &&
          allowRepoSearch) {
        final broadSearch = await _searchCode(
          repoRoot: repoRoot,
          query: '$packageName repo:$fullName',
          verbose: verbose,
        );
        if (broadSearch.totalCount > 0) {
          matchedPath = broadSearch.firstPath;
          usageSignals.add('code_search_general');
        } else if (await _repoFileExists(
          repoRoot: repoRoot,
          fullName: fullName,
          path: _kRuntimeCiConfigPath,
          verbose: verbose,
        )) {
          matchedPath = _kRuntimeCiConfigPath;
          runtimeCiConfigPath = _kRuntimeCiConfigPath;
          usageSignals.add('runtime_ci_config');
        }
      }
    }

    if (dependencyConstraint == null &&
        devDependencyConstraint == null &&
        matchedPath == null &&
        runtimeCiConfigPath == null) {
      return null;
    }

    return _ConsumerRepo(
      owner: descriptor.owner,
      repo: descriptor.repo,
      dependencyConstraint: dependencyConstraint,
      devDependencyConstraint: devDependencyConstraint,
      matchedPath: matchedPath,
      pubspecPath: pubspec?.path,
      pubspecSha: pubspec?.sha,
      runtimeCiConfigPath: runtimeCiConfigPath,
      usageSignals: usageSignals.toList()..sort(),
    );
  }

  Future<_CodeSearchResult> _searchCode({
    required String repoRoot,
    required String query,
    required bool verbose,
  }) async {
    final encodedQuery = Uri.encodeQueryComponent(query);
    final result = await _searchCodeApiRequest(
      repoRoot: repoRoot,
      args: ['api', 'search/code?q=$encodedQuery&per_page=1'],
      verbose: verbose,
    );
    if (result.exitCode != 0) {
      return const _CodeSearchResult(totalCount: 0, firstPath: null);
    }

    final stdout = (result.stdout as String).trim();
    if (stdout.isEmpty) return const _CodeSearchResult(totalCount: 0, firstPath: null);

    try {
      final map = json.decode(stdout);
      if (map is! Map<String, dynamic>) {
        return const _CodeSearchResult(totalCount: 0, firstPath: null);
      }
      final totalCount = (map['total_count'] as num?)?.toInt() ?? 0;
      final items = map['items'];
      String? firstPath;
      if (items is List && items.isNotEmpty && items.first is Map<String, dynamic>) {
        firstPath = (items.first as Map<String, dynamic>)['path']?.toString();
      }
      return _CodeSearchResult(totalCount: totalCount, firstPath: firstPath);
    } catch (_) {
      return const _CodeSearchResult(totalCount: 0, firstPath: null);
    }
  }

  Future<ProcessResult> _searchCodeApiRequest({
    required String repoRoot,
    required List<String> args,
    required bool verbose,
  }) {
    final completer = Completer<ProcessResult>();

    _searchSerialQueue = _searchSerialQueue
        .then((_) async {
          if (_lastSearchRequestAt != null) {
            final elapsed = DateTime.now().difference(_lastSearchRequestAt!);
            final remaining = _kSearchRequestMinInterval - elapsed;
            if (!remaining.isNegative) {
              await Future<void>.delayed(remaining);
            }
          }

          ProcessResult? finalResult;
          for (var attempt = 0; attempt < 3; attempt++) {
            final result = await _runProcess(executable: 'gh', args: args, cwd: repoRoot, verbose: verbose);
            finalResult = result;
            if (result.exitCode == 0) {
              break;
            }

            final stderr = (result.stderr as String?)?.toLowerCase() ?? '';
            final looksRateLimited = stderr.contains('rate limit') || stderr.contains('secondary rate');
            if (!looksRateLimited || attempt == 2) {
              break;
            }

            final backoffSeconds = 5 * (attempt + 1);
            Logger.warn('Code search rate-limited; retrying in ${backoffSeconds}s...');
            await Future<void>.delayed(Duration(seconds: backoffSeconds));
          }

          _lastSearchRequestAt = DateTime.now();
          completer.complete(finalResult ?? ProcessResult(0, 1, '', 'Unable to execute search request.'));
        })
        .catchError((Object error, StackTrace stackTrace) {
          if (!completer.isCompleted) {
            completer.completeError(error, stackTrace);
          }
        });

    return completer.future;
  }

  Future<bool> _repoFileExists({
    required String repoRoot,
    required String fullName,
    required String path,
    required bool verbose,
  }) async {
    final result = await _runProcess(
      executable: 'gh',
      args: ['api', 'repos/$fullName/contents/$path'],
      cwd: repoRoot,
      verbose: verbose,
    );
    return result.exitCode == 0;
  }

  Future<_PubspecFile?> _fetchPubspec({
    required String repoRoot,
    required String fullName,
    required bool verbose,
    String path = 'pubspec.yaml',
  }) async {
    final result = await _runProcess(
      executable: 'gh',
      args: ['api', 'repos/$fullName/contents/$path'],
      cwd: repoRoot,
      verbose: verbose,
    );
    if (result.exitCode != 0) {
      return null;
    }

    final stdout = (result.stdout as String).trim();
    if (stdout.isEmpty) return null;

    try {
      final parsed = json.decode(stdout);
      if (parsed is! Map<String, dynamic>) return null;
      final encoded = parsed['content']?.toString();
      if (encoded == null || encoded.isEmpty) return null;

      final cleanBase64 = encoded.replaceAll('\n', '');
      final bytes = base64.decode(cleanBase64);
      final content = utf8.decode(bytes);
      return _PubspecFile(path: parsed['path']?.toString() ?? path, sha: parsed['sha']?.toString(), content: content);
    } catch (_) {
      return null;
    }
  }

  String? _readDependencyConstraint(String? pubspecContent, {required String packageName, required String section}) {
    if (pubspecContent == null || pubspecContent.trim().isEmpty) return null;
    try {
      final parsed = loadYaml(pubspecContent);
      if (parsed is! YamlMap) return null;
      final normalized = _yamlToDart(parsed);
      if (normalized is! Map<String, dynamic>) return null;

      final depSection = normalized[section];
      if (depSection is! Map<String, dynamic>) return null;
      if (!depSection.containsKey(packageName)) return null;

      final value = depSection[packageName];
      if (value == null) return null;
      if (value is String) return value;
      return const JsonEncoder.withIndent('  ').convert(value);
    } catch (_) {
      return null;
    }
  }

  dynamic _yamlToDart(dynamic value) {
    if (value is YamlMap) {
      final map = <String, dynamic>{};
      for (final entry in value.entries) {
        map[entry.key.toString()] = _yamlToDart(entry.value);
      }
      return map;
    }
    if (value is YamlList) {
      return value.map(_yamlToDart).toList();
    }
    return value;
  }

  _SnapshotTarget _nextSnapshotTarget({required Directory reposDir}) {
    final existingNames = reposDir.existsSync()
        ? reposDir.listSync().whereType<File>().map(
            (f) => f.uri.pathSegments.isEmpty ? f.path : f.uri.pathSegments.last,
          )
        : const <String>[];
    final nextIndex = computeNextDiscoveryIndexFromNames(existingNames);
    final localTime = DateTime.now();
    final fileName = buildDiscoverySnapshotName(index: nextIndex, localTime: localTime);
    final snapshotPath = _joinPath(reposDir.path, [fileName]);
    return _SnapshotTarget(index: nextIndex, localTime: localTime, snapshotPath: snapshotPath);
  }

  _SnapshotResult _writeDiscoverySnapshotAtPath({
    required String snapshotPath,
    required int index,
    required DateTime startedLocal,
    required String packageName,
    required List<String> orgs,
    required _DiscoveryResult discovery,
    required String runStatus,
    required bool dryRun,
  }) {
    final nowLocal = DateTime.now();

    final snapshot = {
      'index': index,
      'generated_at_local': startedLocal.toIso8601String(),
      'generated_at_utc': startedLocal.toUtc().toIso8601String(),
      'updated_at_local': nowLocal.toIso8601String(),
      'updated_at_utc': nowLocal.toUtc().toIso8601String(),
      'run_status': runStatus,
      'package': packageName,
      'orgs': orgs,
      'scanned_repo_count': discovery.scannedRepos,
      'consumer_count': discovery.consumers.length,
      'failures': discovery.failures,
      'consumers': discovery.consumers.map((consumer) => consumer.toJson()).toList(),
    };

    if (!dryRun) {
      _atomicWriteJson(snapshotPath, snapshot);
    }

    return _SnapshotResult(snapshotPath: snapshotPath, consumers: discovery.consumers, runStatus: runStatus);
  }

  _SnapshotResult? _loadLatestDiscoverySnapshot({required Directory reposDir}) {
    if (!reposDir.existsSync()) return null;
    final candidates = reposDir
        .listSync()
        .whereType<File>()
        .map((file) => _SnapshotCandidate(path: file.path, fileName: file.uri.pathSegments.last))
        .where((file) => _extractDiscoveryIndex(file.fileName) != null)
        .toList();

    if (candidates.isEmpty) return null;

    candidates.sort((a, b) {
      final aIndex = _indexForDiscoveryName(a.fileName);
      final bIndex = _indexForDiscoveryName(b.fileName);
      return bIndex.compareTo(aIndex);
    });

    _SnapshotResult? bestCompleted;
    var bestCompletedScannedCount = -1;
    var bestCompletedIndex = -1;
    _SnapshotResult? latestFallback;
    var latestFallbackIndex = -1;

    for (final candidate in candidates) {
      try {
        final parsed = json.decode(File(candidate.path).readAsStringSync());
        if (parsed is! Map<String, dynamic>) continue;
        final consumerMaps = parsed['consumers'];
        if (consumerMaps is! List) continue;
        final consumers = consumerMaps
            .whereType<Map<String, dynamic>>()
            .map(_ConsumerRepo.fromJson)
            .whereType<_ConsumerRepo>()
            .toList();
        final runStatus = parsed['run_status']?.toString();
        final scannedRepoCount = (parsed['scanned_repo_count'] as num?)?.toInt() ?? 0;
        final index = _indexForDiscoveryName(candidate.fileName);
        final snapshot = _SnapshotResult(snapshotPath: candidate.path, consumers: consumers, runStatus: runStatus);

        final isCompleted = runStatus == null || runStatus == 'completed';
        if (isCompleted) {
          if (scannedRepoCount > bestCompletedScannedCount ||
              (scannedRepoCount == bestCompletedScannedCount && index > bestCompletedIndex)) {
            bestCompleted = snapshot;
            bestCompletedScannedCount = scannedRepoCount;
            bestCompletedIndex = index;
          }
        } else if (index > latestFallbackIndex) {
          latestFallback = snapshot;
          latestFallbackIndex = index;
        }
      } catch (_) {
        // Try older snapshots if latest is malformed.
      }
    }

    return bestCompleted ?? latestFallback;
  }

  int _indexForDiscoveryName(String fileName) {
    return _extractDiscoveryIndex(fileName) ?? 0;
  }

  bool _isCompletedSummaryReusable(_ReleaseSyncSummary summary, {required String? exactTag}) {
    return isReleaseSummaryReusable(
      status: summary.status,
      outputPath: summary.outputPath,
      tag: summary.tag,
      exactTag: exactTag,
    );
  }

  _ReleaseCounts _countReleaseStatuses(Iterable<_ReleaseSyncSummary> summaries) {
    var success = 0;
    var noRelease = 0;
    var failure = 0;
    for (final summary in summaries) {
      if (summary.status == 'ok') {
        success++;
      } else if (summary.status == 'no_release') {
        noRelease++;
      } else if (summary.status == 'failed') {
        failure++;
      }
    }
    return _ReleaseCounts(successCount: success, noReleaseCount: noRelease, failureCount: failure);
  }

  void _writeReleaseSummary({
    required String releaseSummaryPath,
    required String sourceSnapshotPath,
    required _ReleaseSelectionCriteria criteria,
    required String packageName,
    required int repoCount,
    required List<_ReleaseSyncSummary> summaries,
    required String runStatus,
  }) {
    final sortedSummaries = List<_ReleaseSyncSummary>.from(summaries)..sort((a, b) => a.fullName.compareTo(b.fullName));
    final counts = _countReleaseStatuses(sortedSummaries);
    final nowLocal = DateTime.now();

    final releaseSummary = {
      'generated_at_local': nowLocal.toIso8601String(),
      'generated_at_utc': nowLocal.toUtc().toIso8601String(),
      'source_snapshot': sourceSnapshotPath,
      'source_snapshot_identity': snapshotIdentityFromPath(sourceSnapshotPath),
      'package': packageName,
      'criteria': criteria.toJson(),
      'repo_count': repoCount,
      'processed_count': sortedSummaries.length,
      'success_count': counts.successCount,
      'no_release_count': counts.noReleaseCount,
      'failure_count': counts.failureCount,
      'run_status': runStatus,
      'repos': sortedSummaries.map((summary) => summary.toJson()).toList(),
    };

    _atomicWriteJson(releaseSummaryPath, releaseSummary);
  }

  Map<String, _ReleaseSyncSummary> _loadExistingReleaseSummaries({
    required String releaseSummaryPath,
    required String expectedSnapshotPath,
    required _ReleaseSelectionCriteria expectedCriteria,
    required Set<String> allowedRepos,
  }) {
    final summaryFile = File(releaseSummaryPath);
    if (!summaryFile.existsSync()) return {};

    try {
      final parsed = json.decode(summaryFile.readAsStringSync());
      if (parsed is! Map<String, dynamic>) return {};

      final sourceSnapshot = parsed['source_snapshot']?.toString();
      final sourceSnapshotIdentity = _normalizeNullableString(parsed['source_snapshot_identity']);
      if (!isSnapshotSourceCompatible(
        sourceSnapshotPath: sourceSnapshot,
        sourceSnapshotIdentity: sourceSnapshotIdentity,
        expectedSnapshotPath: expectedSnapshotPath,
      )) {
        return {};
      }

      final criteriaMap = parsed['criteria'];
      if (criteriaMap is! Map<String, dynamic>) return {};
      if (!_releaseCriteriaMatch(existingCriteria: criteriaMap, expectedCriteria: expectedCriteria)) {
        return {};
      }

      final repos = parsed['repos'];
      if (repos is! List) return {};

      final summaries = <String, _ReleaseSyncSummary>{};
      for (final entry in repos.whereType<Map<String, dynamic>>()) {
        final summary = _ReleaseSyncSummary.fromJson(entry);
        if (summary == null) continue;
        if (!allowedRepos.contains(summary.fullName)) continue;
        if (!_isCompletedSummaryReusable(summary, exactTag: expectedCriteria.exactTag)) continue;
        summaries[summary.fullName] = summary;
      }
      return summaries;
    } catch (error) {
      Logger.warn('Could not parse existing release summary ($releaseSummaryPath): $error');
      return {};
    }
  }

  bool _releaseCriteriaMatch({
    required Map<String, dynamic> existingCriteria,
    required _ReleaseSelectionCriteria expectedCriteria,
  }) {
    return _normalizeNullableString(existingCriteria['package']) == expectedCriteria.packageName &&
        _normalizeNullableString(existingCriteria['exact_tag']) == expectedCriteria.exactTag &&
        _normalizeNullableString(existingCriteria['tag_regex']) == expectedCriteria.tagRegex &&
        existingCriteria['include_prerelease'] == expectedCriteria.includePrerelease;
  }

  String? _normalizeNullableString(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty || text == 'null') return null;
    return text;
  }

  void _atomicWriteJson(String targetPath, Map<String, dynamic> data) {
    final targetFile = File(targetPath);
    targetFile.parent.createSync(recursive: true);

    final tempFile = File('$targetPath.tmp.${DateTime.now().microsecondsSinceEpoch}');
    tempFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));

    if (targetFile.existsSync()) {
      targetFile.deleteSync();
    }
    tempFile.renameSync(targetPath);
  }

  Future<_ReleaseSyncSummary> _syncRepoRelease({
    required String repoRoot,
    required String outputDir,
    required _ConsumerRepo consumer,
    required String? exactTag,
    required RegExp? tagPattern,
    required bool includePrerelease,
    required bool verbose,
    required bool dryRun,
  }) async {
    final release = await _resolveRelease(
      repoRoot: repoRoot,
      consumer: consumer,
      exactTag: exactTag,
      tagPattern: tagPattern,
      includePrerelease: includePrerelease,
      verbose: verbose,
    );

    if (release == null) {
      final repoDirPath = _joinPath(outputDir, [consumer.repo]);
      final noReleasePath = _joinPath(repoDirPath, ['NO_RELEASE.md']);
      if (dryRun) {
        Logger.info('[DRY-RUN] Would write no-release marker to $noReleasePath');
      } else {
        Directory(repoDirPath).createSync(recursive: true);
        File(noReleasePath).writeAsStringSync(
          'No matching release found for ${consumer.fullName}.\n'
          'Criteria: exactTag=${exactTag ?? "none"}, '
          'tagRegex=${tagPattern?.pattern ?? "none"}, '
          'includePrerelease=$includePrerelease.\n',
        );
      }
      Logger.warn('No matching release for ${consumer.fullName}');
      return _ReleaseSyncSummary(
        fullName: consumer.fullName,
        status: 'no_release',
        tag: null,
        outputPath: noReleasePath,
      );
    }

    final tag = release['tagName']?.toString().trim();
    if (tag == null || tag.isEmpty) {
      return _ReleaseSyncSummary(
        fullName: consumer.fullName,
        status: 'failed',
        tag: null,
        outputPath: '',
        error: 'Release metadata missing tagName.',
      );
    }

    final repoOutputPath = buildReleaseOutputPath(outputDir: outputDir, repoName: consumer.repo, tagName: tag);
    final releaseDir = Directory(repoOutputPath);
    final assetsDir = Directory(_joinPath(repoOutputPath, ['assets']));
    final metadataPath = _joinPath(repoOutputPath, ['metadata.json']);
    final releaseMdPath = _joinPath(repoOutputPath, ['RELEASE.md']);
    final pubspecPath = _joinPath(repoOutputPath, ['pubspec.yaml']);

    final pubspec = await _fetchPubspec(repoRoot: repoRoot, fullName: consumer.fullName, verbose: verbose);
    final metadata = <String, dynamic>{
      'repository': consumer.fullName,
      'discovery': consumer.toJson(),
      'release': release,
    };

    if (dryRun) {
      Logger.info('[DRY-RUN] Would write $metadataPath');
      Logger.info('[DRY-RUN] Would write $releaseMdPath');
      if (pubspec != null) {
        Logger.info('[DRY-RUN] Would write $pubspecPath');
      }
    } else {
      releaseDir.createSync(recursive: true);
      assetsDir.createSync(recursive: true);
      File(metadataPath).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(metadata));
      File(releaseMdPath).writeAsStringSync(release['body']?.toString() ?? '');
      if (pubspec != null) {
        File(pubspecPath).writeAsStringSync(pubspec.content);
      }
    }

    final assets = release['assets'];
    if (assets is List && assets.isNotEmpty) {
      if (dryRun) {
        Logger.info('[DRY-RUN] Would download ${assets.length} assets to ${assetsDir.path}');
      } else {
        final download = await _runProcess(
          executable: 'gh',
          args: ['release', 'download', tag, '--repo', consumer.fullName, '--dir', assetsDir.path, '--clobber'],
          cwd: repoRoot,
          verbose: verbose,
        );
        if (download.exitCode != 0) {
          final stderr = (download.stderr as String).trim();
          Logger.warn('Asset download failed for ${consumer.fullName}@$tag${stderr.isNotEmpty ? ': $stderr' : ''}');
          return _ReleaseSyncSummary(
            fullName: consumer.fullName,
            status: 'failed',
            tag: tag,
            outputPath: repoOutputPath,
            error: stderr.isEmpty ? 'Asset download failed.' : stderr,
          );
        }
      }
    }

    Logger.success('Synced ${consumer.fullName} @ $tag -> $repoOutputPath');
    return _ReleaseSyncSummary(fullName: consumer.fullName, status: 'ok', tag: tag, outputPath: repoOutputPath);
  }

  Future<Map<String, dynamic>?> _resolveRelease({
    required String repoRoot,
    required _ConsumerRepo consumer,
    required String? exactTag,
    required RegExp? tagPattern,
    required bool includePrerelease,
    required bool verbose,
  }) async {
    if (exactTag != null && exactTag.isNotEmpty) {
      return _viewRelease(repoRoot: repoRoot, fullName: consumer.fullName, tag: exactTag, verbose: verbose);
    }

    final listResult = await _runProcess(
      executable: 'gh',
      args: [
        'release',
        'list',
        '--repo',
        consumer.fullName,
        '--limit',
        '$_kDefaultReleaseListLimit',
        '--json',
        'tagName,isPrerelease,isDraft,publishedAt',
      ],
      cwd: repoRoot,
      verbose: verbose,
    );
    if (listResult.exitCode != 0) {
      return null;
    }

    final stdout = (listResult.stdout as String).trim();
    if (stdout.isEmpty) return null;

    try {
      final parsed = json.decode(stdout);
      if (parsed is! List) return null;
      final releases = parsed.whereType<Map<String, dynamic>>().toList();
      final selectedTag = selectTagFromReleaseList(
        releases: releases,
        includePrerelease: includePrerelease,
        tagPattern: tagPattern,
      );
      if (selectedTag == null) return null;
      return _viewRelease(repoRoot: repoRoot, fullName: consumer.fullName, tag: selectedTag, verbose: verbose);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _viewRelease({
    required String repoRoot,
    required String fullName,
    required String tag,
    required bool verbose,
  }) async {
    final result = await _runProcess(
      executable: 'gh',
      args: [
        'release',
        'view',
        tag,
        '--repo',
        fullName,
        '--json',
        'tagName,name,body,createdAt,publishedAt,isPrerelease,isDraft,url,assets',
      ],
      cwd: repoRoot,
      verbose: verbose,
    );

    if (result.exitCode != 0) return null;
    final stdout = (result.stdout as String).trim();
    if (stdout.isEmpty) return null;

    try {
      final parsed = json.decode(stdout);
      if (parsed is! Map<String, dynamic>) return null;
      return parsed;
    } catch (_) {
      return null;
    }
  }

  static String _joinPath(String base, List<String> segments) {
    var path = base;
    for (final segment in segments) {
      final normalized = segment.replaceAll('\\', '/');
      if (normalized.isEmpty) continue;
      if (path.endsWith(Platform.pathSeparator)) {
        path = '$path$normalized';
      } else {
        path = '$path${Platform.pathSeparator}$normalized';
      }
    }
    return path;
  }

  Directory _resolveOutputDirectory({required String repoRoot, required String outputDirOption}) {
    final candidate = Directory(outputDirOption);
    if (candidate.isAbsolute) return candidate;
    return Directory(_joinPath(repoRoot, [outputDirOption]));
  }

  Future<ProcessResult> _runProcess({
    required String executable,
    required List<String> args,
    required String cwd,
    required bool verbose,
  }) async {
    if (verbose) {
      Logger.info('  \$ $executable ${args.join(" ")}');
    }
    return Process.run(executable, args, workingDirectory: cwd);
  }

  Future<void> _forEachConcurrent<T>({
    required List<T> items,
    required int concurrency,
    required Future<void> Function(T item) action,
  }) async {
    if (items.isEmpty) return;
    final workerCount = concurrency <= 1 ? 1 : (concurrency > items.length ? items.length : concurrency);
    var index = 0;

    Future<void> worker() async {
      while (true) {
        if (index >= items.length) break;
        final currentIndex = index;
        index++;
        await action(items[currentIndex]);
      }
    }

    final workers = <Future<void>>[];
    for (var i = 0; i < workerCount; i++) {
      workers.add(worker());
    }
    await Future.wait(workers);
  }
}

class _ConsumersOptions {
  final List<String> orgs;
  final String packageName;
  final String outputDir;
  final bool discoverOnly;
  final bool releasesOnly;
  final String? tag;
  final String? tagRegex;
  final bool includePrerelease;
  final bool resume;
  final bool searchFirst;
  final int discoveryWorkers;
  final int releaseWorkers;
  final int repoLimit;

  const _ConsumersOptions({
    required this.orgs,
    required this.packageName,
    required this.outputDir,
    required this.discoverOnly,
    required this.releasesOnly,
    required this.tag,
    required this.tagRegex,
    required this.includePrerelease,
    required this.resume,
    required this.searchFirst,
    required this.discoveryWorkers,
    required this.releaseWorkers,
    required this.repoLimit,
  });

  factory _ConsumersOptions.fromArgResults(ArgResults results) {
    final orgs = (results['org'] as List<String>?)?.where((value) => value.trim().isNotEmpty).toList() ?? <String>[];
    final packageName = (results['package'] as String?)?.trim() ?? _kDefaultPackageName;
    final outputDir = (results['output-dir'] as String?)?.trim() ?? '.consumers';
    final discoverOnly = results['discover-only'] == true;
    final releasesOnly = results['releases-only'] == true;
    final tag = (results['tag'] as String?)?.trim();
    final tagRegex = (results['tag-regex'] as String?)?.trim();
    final includePrerelease = results['include-prerelease'] == true;
    final resume = results['resume'] != false;
    final searchFirst = results['search-first'] != false;
    final discoveryWorkersRaw = (results['discovery-workers'] as String?)?.trim() ?? '4';
    final discoveryWorkers = int.tryParse(discoveryWorkersRaw) ?? 4;
    final releaseWorkersRaw = (results['release-workers'] as String?)?.trim() ?? '4';
    final releaseWorkers = int.tryParse(releaseWorkersRaw) ?? 4;
    final repoLimitRaw = (results['repo-limit'] as String?)?.trim() ?? '$_kDefaultRepoLimit';
    final repoLimit = int.tryParse(repoLimitRaw) ?? _kDefaultRepoLimit;

    return _ConsumersOptions(
      orgs: orgs.isEmpty ? _kDefaultOrgs : orgs,
      packageName: packageName.isEmpty ? _kDefaultPackageName : packageName,
      outputDir: outputDir.isEmpty ? '.consumers' : outputDir,
      discoverOnly: discoverOnly,
      releasesOnly: releasesOnly,
      tag: tag == null || tag.isEmpty ? null : tag,
      tagRegex: tagRegex == null || tagRegex.isEmpty ? null : tagRegex,
      includePrerelease: includePrerelease,
      resume: resume,
      searchFirst: searchFirst,
      discoveryWorkers: discoveryWorkers <= 0 ? 1 : discoveryWorkers,
      releaseWorkers: releaseWorkers <= 0 ? 1 : releaseWorkers,
      repoLimit: repoLimit <= 0 ? _kDefaultRepoLimit : repoLimit,
    );
  }
}

class _RepoDescriptor {
  final String owner;
  final String repo;

  const _RepoDescriptor({required this.owner, required this.repo});

  String get fullName => '$owner/$repo';
}

class _PubspecFile {
  final String path;
  final String? sha;
  final String content;

  const _PubspecFile({required this.path, required this.sha, required this.content});
}

class _CodeSearchResult {
  final int totalCount;
  final String? firstPath;

  const _CodeSearchResult({required this.totalCount, required this.firstPath});
}

class _OrgSearchQuery {
  final String query;

  const _OrgSearchQuery({required this.query});
}

class _OrgSearchHit {
  final String fullName;
  final String path;

  const _OrgSearchHit({required this.fullName, required this.path});
}

class _OrgSearchResult {
  final bool failed;
  final bool incompleteResults;
  final List<_OrgSearchHit> hits;

  const _OrgSearchResult({required this.failed, required this.incompleteResults, required this.hits});

  const _OrgSearchResult.failed() : this(failed: true, incompleteResults: false, hits: const <_OrgSearchHit>[]);
}

class _OrgSearchPrefilter {
  final bool failed;
  final bool incompleteResults;
  final Map<String, List<String>> repoPathsByFullName;

  const _OrgSearchPrefilter({required this.failed, required this.incompleteResults, required this.repoPathsByFullName});

  const _OrgSearchPrefilter.failed() : this(failed: true, incompleteResults: false, repoPathsByFullName: const {});
}

class _ConsumerRepo {
  final String owner;
  final String repo;
  final String? dependencyConstraint;
  final String? devDependencyConstraint;
  final String? matchedPath;
  final String? pubspecPath;
  final String? pubspecSha;
  final String? runtimeCiConfigPath;
  final List<String> usageSignals;

  const _ConsumerRepo({
    required this.owner,
    required this.repo,
    required this.dependencyConstraint,
    required this.devDependencyConstraint,
    required this.matchedPath,
    required this.pubspecPath,
    required this.pubspecSha,
    required this.runtimeCiConfigPath,
    required this.usageSignals,
  });

  String get fullName => '$owner/$repo';

  Map<String, dynamic> toJson() {
    return {
      'owner': owner,
      'repo': repo,
      'full_name': fullName,
      'dependency_constraint': dependencyConstraint,
      'dev_dependency_constraint': devDependencyConstraint,
      'matched_path': matchedPath,
      'pubspec_path': pubspecPath,
      'pubspec_sha': pubspecSha,
      'runtime_ci_config_path': runtimeCiConfigPath,
      'usage_signals': usageSignals,
    };
  }

  static _ConsumerRepo? fromJson(Map<String, dynamic> map) {
    final owner = map['owner']?.toString().trim() ?? '';
    final repo = map['repo']?.toString().trim() ?? '';
    if (owner.isEmpty || repo.isEmpty) return null;
    return _ConsumerRepo(
      owner: owner,
      repo: repo,
      dependencyConstraint: map['dependency_constraint']?.toString(),
      devDependencyConstraint: map['dev_dependency_constraint']?.toString(),
      matchedPath: map['matched_path']?.toString(),
      pubspecPath: map['pubspec_path']?.toString(),
      pubspecSha: map['pubspec_sha']?.toString(),
      runtimeCiConfigPath: map['runtime_ci_config_path']?.toString(),
      usageSignals: (map['usage_signals'] as List?)?.map((value) => value.toString()).toList() ?? const <String>[],
    );
  }
}

class _DiscoveryResult {
  final List<_ConsumerRepo> consumers;
  final int scannedRepos;
  final List<Map<String, String>> failures;

  const _DiscoveryResult({required this.consumers, required this.scannedRepos, required this.failures});
}

class _SnapshotResult {
  final String snapshotPath;
  final List<_ConsumerRepo> consumers;
  final String? runStatus;

  const _SnapshotResult({required this.snapshotPath, required this.consumers, this.runStatus});
}

class _SnapshotTarget {
  final int index;
  final DateTime localTime;
  final String snapshotPath;

  const _SnapshotTarget({required this.index, required this.localTime, required this.snapshotPath});
}

class _SnapshotCandidate {
  final String path;
  final String fileName;

  const _SnapshotCandidate({required this.path, required this.fileName});
}

class _ReleaseSelectionCriteria {
  final String packageName;
  final String? exactTag;
  final String? tagRegex;
  final bool includePrerelease;

  const _ReleaseSelectionCriteria({
    required this.packageName,
    required this.exactTag,
    required this.tagRegex,
    required this.includePrerelease,
  });

  Map<String, dynamic> toJson() {
    return {
      'package': packageName,
      'exact_tag': exactTag,
      'tag_regex': tagRegex,
      'include_prerelease': includePrerelease,
    };
  }
}

class _ReleaseCounts {
  final int successCount;
  final int noReleaseCount;
  final int failureCount;

  const _ReleaseCounts({required this.successCount, required this.noReleaseCount, required this.failureCount});
}

class _ReleaseSyncSummary {
  final String fullName;
  final String status;
  final String? tag;
  final String outputPath;
  final String? error;

  const _ReleaseSyncSummary({
    required this.fullName,
    required this.status,
    required this.tag,
    required this.outputPath,
    this.error,
  });

  Map<String, dynamic> toJson() {
    return {'repository': fullName, 'status': status, 'tag': tag, 'output_path': outputPath, 'error': error};
  }

  static _ReleaseSyncSummary? fromJson(Map<String, dynamic> map) {
    final fullName = map['repository']?.toString().trim() ?? '';
    final status = map['status']?.toString().trim() ?? '';
    final outputPath = map['output_path']?.toString().trim() ?? '';
    if (fullName.isEmpty || status.isEmpty || outputPath.isEmpty) return null;
    return _ReleaseSyncSummary(
      fullName: fullName,
      status: status,
      tag: map['tag']?.toString(),
      outputPath: outputPath,
      error: map['error']?.toString(),
    );
  }
}
