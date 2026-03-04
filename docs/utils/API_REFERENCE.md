# Shared Utilities API Reference

This module provides shared constants and cross-platform utilities for CI/CD scripts within the `runtime_ci_tooling` package. It includes generic repo-root discovery, generated file detection, and promptless tool installation helpers.

## Constants

### `kGeneratedExtensions`
A list of all generated file extensions produced by `protoc-gen-dart` and `protoc-gen-enhance`.

- **Type**: `List<String>`
- **Value**: `['.pb.dart', '.pbenum.dart', '.pbjson.dart', '.pbgrpc.dart', ...]`

**Example:**
```dart
import 'package:runtime_ci_tooling/runtime_ci_tooling.dart';

void main() {
  print('Known generated extensions: $kGeneratedExtensions');
}
```

### `kSmithyCliVersion`
The latest Smithy CLI release version used for auto-installation.

- **Type**: `String`
- **Value**: `'1.67.0'`

### `kMinJavaVersion`
Minimum required Java major version for the Smithy CLI.

- **Type**: `int`
- **Value**: `17`

---

## Top-Level Functions

### `commandExists`
Checks if a given command is available on the system `PATH`.
It uses `where` on Windows and `which` on Unix-like systems.

- **Parameters**: 
  - `command` (`String`): The name of the command to check.
- **Return type**: `Future<bool>`

**Example:**
```dart
import 'package:runtime_ci_tooling/runtime_ci_tooling.dart';

Future<void> main() async {
  bool hasGit = await commandExists('git');
  if (hasGit) {
    print('Git is installed!');
  }
}
```

### `ensureSmithyCli`
Ensures the Smithy CLI and a compatible JDK (v17+) are installed.
If the Smithy CLI is missing, it automatically installs it without user prompts:
- **macOS**: via Homebrew, with a fallback to binary download.
- **Linux/Windows**: downloads the binary from GitHub releases.

- **Parameters**: None
- **Return type**: `Future<bool>` - Returns `true` if both Java and the Smithy CLI are available.

**Example:**
```dart
import 'package:runtime_ci_tooling/runtime_ci_tooling.dart';

Future<void> setupEnvironment() async {
  bool smithyReady = await ensureSmithyCli();
  if (!smithyReady) {
    print('Smithy CLI is not available. Skipping conversion step.');
    return;
  }
  // Proceed with Smithy -> OpenAPI conversion
}
```

### `findRepoRoot`
Finds a Dart package repo root by walking up from the current directory, looking for a `pubspec.yaml` containing `name: <packageName>`.

- **Parameters**: 
  - `packageName` (`String`): The exact package name to search for.
- **Return type**: `String?` - The path to the repository root, or `null` if not found.

**Example:**
```dart
import 'package:runtime_ci_tooling/runtime_ci_tooling.dart';
import 'dart:io';

void checkRepo() {
  String? root = findRepoRoot('runtime_ci_tooling');
  if (root != null) {
    print('Found repo at: $root');
  } else {
    print('Not running inside the correct repository.');
  }
}
```

### `isGeneratedFile`
Checks if a file path ends with any of the known generated extensions defined in `kGeneratedExtensions`.

- **Parameters**: 
  - `filePath` (`String`): The path or filename to check.
- **Return type**: `bool`

**Example:**
```dart
import 'package:runtime_ci_tooling/runtime_ci_tooling.dart';

void filterFiles(List<String> files) {
  final manualFiles = files.where((f) => !isGeneratedFile(f)).toList();
  print('Found ${manualFiles.length} manually written files.');
}
```
