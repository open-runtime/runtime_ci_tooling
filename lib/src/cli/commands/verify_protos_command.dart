import 'dart:io';

import 'package:args/command_runner.dart';

import '../../triage/utils/config.dart';
import '../utils/logger.dart';
import '../utils/repo_utils.dart';

/// Verify proto source and generated files exist.
class VerifyProtosCommand extends Command<void> {
  @override
  final String name = 'verify-protos';

  @override
  final String description = 'Verify proto source and generated files exist.';

  @override
  Future<void> run() async {
    final repoRoot = RepoUtils.findRepoRoot();
    if (repoRoot == null) {
      Logger.error('Could not find ${config.repoName} repo root.');
      exit(1);
    }

    Logger.header('Verifying proto files');

    // Check for proto files
    final protoDir = Directory('$repoRoot/protos');
    if (!protoDir.existsSync()) {
      Logger.info('No protos/ directory found. Skipping verification.');
      return;
    }

    final protoFiles = protoDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.proto'))
        .toList();

    Logger.info('Found ${protoFiles.length} proto files');

    // Check for generated Dart files
    final libDir = Directory('$repoRoot/lib');
    if (!libDir.existsSync()) {
      Logger.warn('No lib/ directory found.');
      return;
    }

    final generatedFiles = libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where(
          (f) =>
              f.path.endsWith('.pb.dart') ||
              f.path.endsWith('.pbenum.dart') ||
              f.path.endsWith('.pbgrpc.dart') ||
              f.path.endsWith('.pbjson.dart'),
        )
        .toList();

    Logger.info('Found ${generatedFiles.length} generated protobuf files');

    if (protoFiles.isNotEmpty && generatedFiles.isEmpty) {
      Logger.error('Proto files exist but no generated Dart files found. Run protoc.');
      exit(1);
    }

    Logger.success('Proto verification complete');
  }
}
