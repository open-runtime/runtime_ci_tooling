import 'dart:io';

import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import 'logger.dart';
import 'workflow_generator.dart';

/// Utilities for loading and working with sub-packages defined in
/// `.runtime_ci/config.json` under `ci.sub_packages`.
///
/// Sub-packages represent independently meaningful packages within a
/// multi-package repository (e.g., `dart_custom_lint` with 5 sub-packages).
abstract final class SubPackageUtils {
  /// Load validated sub-packages from the CI config.
  ///
  /// Returns an empty list when the repo has no sub-packages configured
  /// or if the config file contains malformed JSON (logs a warning).
  /// Each entry has at least `name` (String) and `path` (String).
  static List<Map<String, dynamic>> loadSubPackages(String repoRoot) {
    final Map<String, dynamic>? ciConfig;
    try {
      ciConfig = WorkflowGenerator.loadCiConfig(repoRoot);
    } on StateError catch (e) {
      Logger.warn('Could not load CI config: $e');
      return [];
    }
    if (ciConfig == null) return [];
    final raw = ciConfig['sub_packages'] as List?;
    if (raw == null || raw.isEmpty) return [];
    final seenNames = <String>{};
    final seenPaths = <String>{};
    final result = <Map<String, dynamic>>[];
    for (final item in raw) {
      if (item is! Map<String, dynamic>) continue;
      if (item['name'] == null || item['path'] == null) continue;
      final err = WorkflowGenerator.validateSubPackageEntry(item, seenNames, seenPaths);
      if (err != null) {
        Logger.warn('Skipping invalid sub-package "${item['name']}": $err');
        continue;
      }
      result.add({...item, 'path': (item['path'] as String).replaceAll(RegExp(r'/+$'), '')});
    }
    return result;
  }

  /// Build a per-package diff summary suitable for appending to a Gemini prompt.
  ///
  /// For each sub-package, runs `git diff <prevTag>..HEAD -- <path>` and
  /// `git log --oneline <prevTag>..HEAD -- <path>` to gather per-package
  /// changes. The output is a Markdown-formatted section that can be
  /// appended to the prompt file.
  ///
  /// Returns an empty string when [subPackages] is empty.
  static String buildSubPackageDiffContext({
    required String repoRoot,
    required String prevTag,
    required List<Map<String, dynamic>> subPackages,
    bool verbose = false,
  }) {
    if (subPackages.isEmpty) return '';

    // Guard: if prevTag is empty, git commands like `git log ..HEAD` are
    // invalid.  Fall back to showing the entire history.
    // For `git diff`, use the well-known empty tree SHA so we diff against
    // an empty tree (showing all files as additions).  For `git log`, plain
    // `HEAD` already lists the full commit history.
    final diffRange = prevTag.isNotEmpty ? '$prevTag..HEAD' : '4b825dc642cb6eb9a060e54bf899d15f3f7f8f0e..HEAD';
    final logRange = prevTag.isNotEmpty ? '$prevTag..HEAD' : 'HEAD';

    final buffer = StringBuffer();
    buffer.writeln();
    buffer.writeln('## Multi-Package Repository Structure');
    buffer.writeln();
    buffer.writeln('This is a multi-package repository containing ${subPackages.length} sub-packages.');
    buffer.writeln('Organize your output with per-package sections using a **hierarchical** format.');
    buffer.writeln();
    buffer.writeln('Sub-packages:');
    for (final pkg in subPackages) {
      buffer.writeln('- **${pkg['name']}**: `${pkg['path']}/`');
    }
    buffer.writeln();

    for (final pkg in subPackages) {
      final name = pkg['name'] as String;
      final path = pkg['path'] as String;

      buffer.writeln('### Changes in `$name` (`$path/`)');
      buffer.writeln();

      // Per-package commit log — use Process.runSync with array args to
      // avoid shell injection via path or tag values from config.json.
      final logArgs = <String>[
        'log',
        ...logRange == 'HEAD' ? ['HEAD'] : [logRange],
        '--oneline',
        '--no-merges',
        '--',
        path,
      ];
      if (verbose) Logger.info('[CMD] git ${logArgs.join(' ')}');
      final commitLogResult = Process.runSync('git', logArgs, workingDirectory: repoRoot);
      final commitLog = (commitLogResult.stdout as String).trim();
      if (commitLog.isNotEmpty) {
        buffer.writeln('Commits:');
        buffer.writeln('```');
        buffer.writeln(_truncate(commitLog, 3000));
        buffer.writeln('```');
      } else {
        buffer.writeln(
          'No commits touching this package since ${prevTag.isNotEmpty ? prevTag : 'repository creation'}.',
        );
      }
      buffer.writeln();

      // Per-package diff stat — safe array-based args, no shell interpolation.
      final diffArgs = ['diff', '--stat', diffRange, '--', path];
      if (verbose) Logger.info('[CMD] git ${diffArgs.join(' ')}');
      final diffStatResult = Process.runSync('git', diffArgs, workingDirectory: repoRoot);
      final diffStat = (diffStatResult.stdout as String).trim();
      if (diffStat.isNotEmpty) {
        buffer.writeln('Diff stat:');
        buffer.writeln('```');
        buffer.writeln(_truncate(diffStat, 2000));
        buffer.writeln('```');
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// Build hierarchical changelog prompt instructions for multi-package repos.
  ///
  /// Instructs Gemini to produce a changelog with a top-level summary
  /// followed by per-package sections.
  static String buildHierarchicalChangelogInstructions({
    required String newVersion,
    required List<Map<String, dynamic>> subPackages,
  }) {
    if (subPackages.isEmpty) return '';

    final packageNames = subPackages.map((p) => p['name']).join(', ');
    final today = DateTime.now().toIso8601String().substring(0, 10);

    // Build example sections using ALL actual sub-package names so
    // Gemini sees every package name once and doesn't invent extras.
    final exampleSections = StringBuffer();
    for (final pkg in subPackages) {
      exampleSections.writeln('### ${pkg['name']}');
      exampleSections.writeln('#### Added');
      exampleSections.writeln('- ...');
      exampleSections.writeln('#### Fixed');
      exampleSections.writeln('- ...');
      exampleSections.writeln();
    }

    return '''

## Hierarchical Changelog Format (Multi-Package)

Because this is a multi-package repository ($packageNames), the changelog
entry MUST use a hierarchical format with per-package sections:

```
## [$newVersion] - $today

### Summary
High-level summary covering ALL packages. This should be a concise
hierarchical summarization of the changes across all sub-packages.

${exampleSections.toString().trimRight()}
```

Rules for hierarchical format:
- The **Summary** section comes first and covers ALL packages at a high level
- Each sub-package gets its own **### PackageName** section
- Under each package, use the standard Keep a Changelog categories (#### Added, #### Changed, etc.)
- Only include sub-package sections for packages that actually have changes
- Only include category sub-sections (#### Added, etc.) that have entries
- If a sub-package has no changes, omit it entirely
- Do NOT invent sub-package names; the ONLY valid names are: $packageNames
''';
  }

  /// Build hierarchical release notes prompt instructions for multi-package repos.
  ///
  /// Instructs Gemini to produce release notes with a top-level narrative
  /// summary followed by per-package detail sections.
  static String buildHierarchicalReleaseNotesInstructions({
    required String newVersion,
    required List<Map<String, dynamic>> subPackages,
  }) {
    if (subPackages.isEmpty) return '';

    final packageNames = subPackages.map((p) => p['name']).join(', ');

    // Build example per-package sections using ALL actual names so Gemini
    // sees every valid package name and doesn't hallucinate extras.
    final exampleSections = StringBuffer();
    for (final pkg in subPackages) {
      exampleSections.writeln('## ${pkg['name']}');
      exampleSections.writeln("### What's New");
      exampleSections.writeln('- ...');
      exampleSections.writeln('### Bug Fixes');
      exampleSections.writeln('- ...');
      exampleSections.writeln();
    }

    return '''

## Hierarchical Release Notes Format (Multi-Package)

Because this is a multi-package repository ($packageNames), the release notes
MUST use a hierarchical format:

1. **Top-level summary and highlights** cover ALL packages -- this is a
   hierarchical summarization of the entire release across all sub-packages.
2. Each sub-package with changes gets its own **## PackageName** detail section
   describing what changed in that specific package.
3. Shared infrastructure changes (CI, tooling, root-level config) go in a
   **## Infrastructure** section if applicable.

Structure:
```markdown
# <REPO_NAME> v$newVersion

> Executive summary covering ALL sub-packages.

## Highlights
- **Highlight 1** covering the most impactful cross-package change
- ...

${exampleSections.toString().trimRight()}

## Infrastructure (if applicable)
- ...

## Contributors
(auto-generated from verified commit data -- do NOT fabricate usernames)

## Issues Addressed
(from issue_manifest.json or "No linked issues for this release.")
```

Rules:
- Only include sub-package sections for packages that actually have changes.
- Do NOT invent sub-package names; the ONLY valid names are: $packageNames
- Replace `<REPO_NAME>` with the actual repository name.
''';
  }

  /// Enrich an existing prompt file with sub-package diff context and
  /// hierarchical formatting instructions.
  ///
  /// This is the single entry-point used by both the compose and
  /// release-notes commands.  It reads the prompt file written by
  /// [RunContext.savePrompt], appends the sub-package diff context and
  /// the appropriate hierarchical instructions, and writes the result
  /// back.
  ///
  /// [promptFilePath] is the absolute path to the prompt file to enrich.
  /// [buildInstructions] is a callback that returns the hierarchical
  /// instructions string (changelog vs release-notes format).
  ///
  /// Returns the list of sub-packages that were used for enrichment
  /// (empty if the repo has no sub-packages).
  static List<Map<String, dynamic>> enrichPromptWithSubPackages({
    required String repoRoot,
    required String prevTag,
    required String promptFilePath,
    required String Function({required String newVersion, required List<Map<String, dynamic>> subPackages})
    buildInstructions,
    required String newVersion,
    bool verbose = false,
  }) {
    final subPackages = loadSubPackages(repoRoot);
    logSubPackages(subPackages);
    if (subPackages.isEmpty) return subPackages;

    final promptFile = File(promptFilePath);
    final subPkgContext = buildSubPackageDiffContext(
      repoRoot: repoRoot,
      prevTag: prevTag,
      subPackages: subPackages,
      verbose: verbose,
    );
    final hierarchicalInstructions = buildInstructions(newVersion: newVersion, subPackages: subPackages);
    promptFile.writeAsStringSync('${promptFile.readAsStringSync()}\n$subPkgContext\n$hierarchicalInstructions');
    Logger.info('Appended sub-package context to prompt (${subPackages.length} packages)');
    return subPackages;
  }

  /// Convert bare sibling dependencies to git format and strip
  /// `resolution: workspace`.
  ///
  /// For each sub-package pubspec, any dependency whose name matches another
  /// sub-package (with a `tag_pattern`) is rewritten from a bare version
  /// constraint to a full git dep block with `url`, `tag_pattern`, `path`,
  /// and `version: ^newVersion`.
  ///
  /// Returns the total number of dependency conversions across all pubspecs.
  static int convertSiblingDepsForRelease({
    required String repoRoot,
    required String newVersion,
    required String effectiveRepo,
    required List<Map<String, dynamic>> subPackages,
    bool verbose = false,
  }) {
    // Build sibling lookup: {packageName -> {tag_pattern, path}}
    // Only packages WITH tag_pattern participate.
    final siblingMap = <String, Map<String, String>>{};
    for (final pkg in subPackages) {
      final tp = pkg['tag_pattern'] as String?;
      if (tp == null) continue;
      siblingMap[pkg['name'] as String] = {'tag_pattern': tp, 'path': pkg['path'] as String};
    }
    if (siblingMap.isEmpty) return 0;

    final gitUrl = 'git@github.com:$effectiveRepo.git';
    var totalConversions = 0;

    for (final pkg in subPackages) {
      final pkgName = pkg['name'] as String;
      final pubspecFile = File('$repoRoot/${pkg['path']}/pubspec.yaml');
      if (!pubspecFile.existsSync()) {
        Logger.warn('Sub-package pubspec not found: ${pkg['path']}/pubspec.yaml');
        continue;
      }

      final original = pubspecFile.readAsStringSync();
      final editor = YamlEditor(original);
      final doc = loadYaml(original) as YamlMap;
      var conversions = 0;

      // Scan both dependency sections.
      for (final sectionKey in ['dependencies', 'dev_dependencies']) {
        final section = doc[sectionKey] as YamlMap?;
        if (section == null) continue;

        for (final key in section.keys) {
          final depName = key as String;
          if (depName == pkgName) continue; // skip self
          final sibling = siblingMap[depName];
          if (sibling == null) continue; // not a sibling

          final depValue = section[depName];
          // Only convert bare string constraints (e.g., "^0.8.2") and
          // null values (workspace refs). Map deps are already structured.
          if (depValue is! String && depValue != null) continue;

          final gitBlock = <String, Object>{
            'url': gitUrl,
            'tag_pattern': sibling['tag_pattern']!,
            'path': sibling['path']!,
          };
          final newValue = <String, Object>{'git': gitBlock, 'version': '^$newVersion'};

          try {
            editor.update([sectionKey, depName], newValue);
            conversions++;
          } on Exception catch (e) {
            Logger.warn('yaml_edit: failed to update $sectionKey.$depName -- $e');
          }
        }
      }

      // Strip `resolution: workspace` if present.
      if (doc.containsKey('resolution')) {
        try {
          editor.remove(['resolution']);
          Logger.info('Stripped resolution: workspace from ${pkg['name']}');
        } on Exception catch (e) {
          Logger.warn('Could not strip resolution from ${pkg['name']}: $e');
        }
      }

      final updated = editor.toString();
      if (updated != original) {
        Logger.info('Updating ${pkg['path']}/pubspec.yaml ($conversions sibling dep conversion(s))');
        pubspecFile.writeAsStringSync(updated);
        totalConversions += conversions;
      }
    }

    return totalConversions;
  }

  /// Truncate a string to a maximum length, appending an indicator.
  static String _truncate(String input, int maxChars) {
    if (input.length <= maxChars) return input;
    return '${input.substring(0, maxChars)}\n... [truncated ${input.length - maxChars} chars]';
  }

  /// Log discovered sub-packages.
  static void logSubPackages(List<Map<String, dynamic>> subPackages) {
    if (subPackages.isEmpty) return;
    Logger.info('Multi-package repo: ${subPackages.length} sub-packages');
    for (final pkg in subPackages) {
      Logger.info('  - ${pkg['name']} (${pkg['path']}/)');
    }
  }
}
