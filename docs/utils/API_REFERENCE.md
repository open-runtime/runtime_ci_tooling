# Shared Utilities API Reference

## 1. Classes
*(No public classes defined in this module)*

## 2. Enums
*(No public enums defined in this module)*

## 3. Extensions
*(No public extensions defined in this module)*

## 4. Constants

- **kGeneratedExtensions** -- `List<String>`
  All generated file extensions produced by `protoc-gen-dart` and `protoc-gen-enhance`.
  
  **Example:**
  ```dart
  import 'package:runtime_ci_tooling/src/utils/repo_utils.dart';

  void main() {
    print('Known generated extensions: $kGeneratedExtensions');
  }
  ```

- **kSmithyCliVersion** -- `String`
  The latest Smithy CLI release version used for auto-installation.
  
  **Example:**
  ```dart
  import 'package:runtime_ci_tooling/src/utils/tool_installers.dart';

  void main() {
    print('Required Smithy CLI version: $kSmithyCliVersion');
  }
  ```

- **kMinJavaVersion** -- `int`
  Minimum required Java major version for the Smithy CLI.
  
  **Example:**
  ```dart
  import 'package:runtime_ci_tooling/src/utils/tool_installers.dart';

  void main() {
    print('Minimum Java version: $kMinJavaVersion');
  }
  ```

## 5. Top-Level Functions

- **isGeneratedFile** -- `bool isGeneratedFile(String filePath)`
  Check if a file path ends with a known generated extension.
  - Parameters: 
    - `filePath` (`String`): The path of the file to check.
  - Return Type: `bool`
  
  **Example:**
  ```dart
  import 'package:runtime_ci_tooling/src/utils/repo_utils.dart';

  void main() {
    final isGen = isGeneratedFile('lib/src/generated/api.pb.dart');
    print('Is generated file: $isGen'); // true
  }
  ```

- **findRepoRoot** -- `String? findRepoRoot(String packageName)`
  Finds a Dart package repo root by walking up from the current directory, looking for a `pubspec.yaml` with `name: <packageName>`. Returns `null` if not found.
  - Parameters:
    - `packageName` (`String`): The name of the package to locate.
  - Return Type: `String?`
  
  **Example:**
  ```dart
  import 'package:runtime_ci_tooling/src/utils/repo_utils.dart';

  void main() {
    final rootDir = findRepoRoot('runtime_ci_tooling');
    if (rootDir != null) {
      print('Found repo root at: $rootDir');
    } else {
      print('Repo root not found.');
    }
  }
  ```

- **ensureSmithyCli** -- `Future<bool> ensureSmithyCli()`
  Ensures the Smithy CLI and a compatible JDK are installed. If the Smithy CLI is missing, automatically installs it based on the platform. Returns `true` if both Java and the Smithy CLI are available.
  - Parameters: None
  - Return Type: `Future<bool>`
  
  **Example:**
  ```dart
  import 'package:runtime_ci_tooling/src/utils/tool_installers.dart';

  void main() async {
    final isReady = await ensureSmithyCli();
    if (isReady) {
      print('Smithy CLI is ready to use!');
    } else {
      print('Failed to locate or install Smithy CLI.');
    }
  }
  ```

- **commandExists** -- `Future<bool> commandExists(String command)`
  Checks if a command is available on the system PATH.
  - Parameters:
    - `command` (`String`): The name of the command (e.g., 'git', 'java').
  - Return Type: `Future<bool>`
  
  **Example:**
  ```dart
  import 'package:runtime_ci_tooling/src/utils/tool_installers.dart';

  void main() async {
    final hasGit = await commandExists('git');
    print('Git installed: $hasGit');
  }
  ```
