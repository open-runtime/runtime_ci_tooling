# Shared Utilities API Reference

This module provides generic repository discovery, file detection, and cross-platform automatic installation of CLI tools (e.g., Smithy CLI).

**Importing:**
```dart
import 'package:runtime_ci_tooling/runtime_ci_tooling.dart';
```

### 1. Classes
*No public classes are defined in this module.*

### 2. Enums
*No public enums are defined in this module.*

### 3. Extensions
*No public extensions are defined in this module.*

### 4. Top-Level Functions

- **isGeneratedFile** -- `bool isGeneratedFile(String filePath)`
  Check if a file path ends with a known generated extension produced by `protoc-gen-dart` and `protoc-gen-enhance`.
  - **Parameters:** 
    - `filePath` (`String`): The file path to verify.
  - **Returns:** `bool`

  **Example:**
  ```dart
  import 'package:runtime_ci_tooling/runtime_ci_tooling.dart';

  void main() {
    final isGen = isGeneratedFile('lib/src/messages.pb.dart');
    print('Is generated: $isGen'); // Prints: Is generated: true
  }
  ```

- **findRepoRoot** -- `String? findRepoRoot(String packageName)`
  Finds a Dart package repo root by walking up from the current directory, looking for a `pubspec.yaml` with `name: <packageName>`.
  - **Parameters:** 
    - `packageName` (`String`): The name of the package to locate.
  - **Returns:** `String?` - The absolute path to the repository root, or `null` if not found (e.g., running from outside the repo).

  **Example:**
  ```dart
  import 'package:runtime_ci_tooling/runtime_ci_tooling.dart';

  void main() {
    final repoRoot = findRepoRoot('runtime_ci_tooling');
    if (repoRoot != null) {
      print('Found repository root at: $repoRoot');
    } else {
      print('Could not locate repository root.');
    }
  }
  ```

- **ensureSmithyCli** -- `Future<bool> ensureSmithyCli()`
  Ensures the Smithy CLI and a compatible JDK (Java 17+) are installed. 
  If the Smithy CLI is missing, it automatically installs it without user prompts:
  - **macOS**: Uses Homebrew (`brew tap smithy-lang/tap && brew install smithy-cli`), with a fallback to binary download.
  - **Linux / Windows**: Downloads the appropriate binary from GitHub releases.
  - **Parameters:** None
  - **Returns:** `Future<bool>` - Returns `true` if both Java 17+ and the Smithy CLI are available after any installation attempts.

  **Example:**
  ```dart
  import 'package:runtime_ci_tooling/runtime_ci_tooling.dart';

  void main() async {
    final isAvailable = await ensureSmithyCli();
    if (isAvailable) {
      print('Smithy CLI is installed and ready to use.');
    } else {
      print('Failed to install or locate Smithy CLI.');
    }
  }
  ```

- **commandExists** -- `Future<bool> commandExists(String command)`
  Checks if a given CLI command is available on the system's `PATH`. This uses `where` on Windows and `which` on Unix-based systems.
  - **Parameters:** 
    - `command` (`String`): The CLI command name to look up.
  - **Returns:** `Future<bool>`

  **Example:**
  ```dart
  import 'package:runtime_ci_tooling/runtime_ci_tooling.dart';

  void main() async {
    final hasGit = await commandExists('git');
    print('Git is installed: $hasGit');
  }
  ```

### 5. Constants

- **kGeneratedExtensions** -- `const List<String> kGeneratedExtensions`
  All generated file extensions produced by `protoc-gen-dart` and `protoc-gen-enhance`.
  *Values include:* `'.pb.dart'`, `'.pbenum.dart'`, `'.pbjson.dart'`, `'.pbgrpc.dart'`, `'.enhance.oneof.dart'`, `'.enhance.builder.dart'`, `'.enhance.fixture.dart'`, `'.enhance.timestamps.dart'`, `'.enhance.collection.dart'`, `'.enhance.map.dart'`, `'.enhance.enum.dart'`, `'.enhance.dx.dart'`, `'.enhance.http.dart'`

- **kSmithyCliVersion** -- `const String kSmithyCliVersion = '1.67.0'`
  The latest Smithy CLI release version used for auto-installation. When a new Smithy CLI release is available, this constant should be updated.

- **kMinJavaVersion** -- `const int kMinJavaVersion = 17`
  Minimum required Java major version for the Smithy CLI.
