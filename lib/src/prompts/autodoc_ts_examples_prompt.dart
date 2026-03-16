// ignore_for_file: avoid_print

import 'dart:io';

import '_ci_config.dart';

/// Autodoc: EXAMPLES.md generator for a proto module (TypeScript variant).
///
/// Usage:
///   dart run scripts/prompts/autodoc_ts_examples_prompt.dart <module_name> <source_dir> <lib_dir>

void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln('Usage: autodoc_ts_examples_prompt.dart <module_name> <source_dir> [lib_dir]');
    exit(1);
  }

  final pkg = CiConfig.current.packageName;
  final moduleName = args[0];
  final sourceDir = args[1];
  final libDir = args.length > 2 ? args[2] : '';

  // Gather proto services and messages
  final services = _runSync('grep -rn "^service\\|^  rpc" $sourceDir 2>/dev/null');
  final messages = _runSync('grep -rn "^message" $sourceDir 2>/dev/null | head -30');
  final enums = _runSync('grep -rn "^enum" $sourceDir 2>/dev/null');

  // Look for test files
  String testContent = '(no tests found)';
  if (libDir.isNotEmpty) {
    final testDir = _runSync(
      'find ${Directory(libDir).parent.path} -type d -name "__tests__" -o -type d -name "test" 2>/dev/null | head -1',
    );
    if (testDir.isNotEmpty && Directory(testDir).existsSync()) {
      testContent = _truncate(
        _runSync('find $testDir -name "*.test.ts" -o -name "*.spec.ts" | head -3 | xargs head -50 2>/dev/null'),
        10000,
      );
    }
  }

  // Look for utility/helper files (usage patterns)
  String helperContent = '';
  if (libDir.isNotEmpty) {
    helperContent = _truncate(
      _runSync('find $libDir -name "*utils*" -o -name "*helpers*" | head -3 | xargs head -40 2>/dev/null'),
      5000,
    );
  }

  print('''
You are writing practical code examples for the **$moduleName** module
of the $pkg TypeScript package.

## Available Services and RPCs
```
$services
```

## Key Message Types
```
$messages
```

## Enums
```
$enums
```

${testContent != '(no tests found)' ? '## Existing Test Patterns\n```typescript\n$testContent\n```' : ''}

${helperContent.isNotEmpty ? '## Helper/Utility Patterns\n```typescript\n$helperContent\n```' : ''}

## Instructions

Generate an EXAMPLES.md with practical, copy-paste-ready TypeScript code examples:

### 1. Basic Usage
- Create and populate the most common message types using `create(Schema, {...})`
- Show TypeScript type annotations and intellisense-friendly patterns

```typescript
import { create } from '@bufbuild/protobuf';
import { MessageNameSchema } from '@open-runtime/$pkg/$moduleName';

const msg = create(MessageNameSchema, {
  field1: 'value1',
  field2: 42,
});
```

### 2. Serialization
- Binary serialization with `toBinary()` and `fromBinary()`
- JSON serialization with `toJson()` and `fromJson()`

```typescript
import { toBinary, fromBinary, toJson, fromJson } from '@bufbuild/protobuf';
import { MessageNameSchema } from '@open-runtime/$pkg/$moduleName';

// Binary round-trip
const bytes: Uint8Array = toBinary(MessageNameSchema, msg);
const decoded = fromBinary(MessageNameSchema, bytes);

// JSON round-trip
const jsonObj = toJson(MessageNameSchema, msg);
const restored = fromJson(MessageNameSchema, jsonObj);
```

### 3. Service Calls (if services exist)
- Set up a gRPC-web or Connect client
- Make a unary call with error handling
- Handle streaming responses (if server/client streaming RPCs exist)

### 4. Working with Enums and Oneofs
- Enum usage with TypeScript type safety
- Oneof field access patterns using the `case` property

```typescript
import { MessageName_FieldCase } from '@open-runtime/$pkg/$moduleName';

// Check which oneof field is set
switch (msg.field.case) {
  case 'optionA':
    console.log(msg.field.value);
    break;
  case 'optionB':
    console.log(msg.field.value);
    break;
}
```

### 5. Integration Patterns
- How this module connects to other modules in the library
- Common workflows (e.g., create request -> send -> process response)
- Using with pnpm workspaces or standalone

### 6. Error Handling
- gRPC/Connect error codes and what they mean for this service
- Retry patterns for transient failures
- TypeScript-idiomatic error handling with try/catch

## Rules
- Use ONLY real type/field names from the proto definitions
- Every code block must be valid, compilable TypeScript
- Import from `@open-runtime/$pkg/...` using the package.json exports map
- Show complete, runnable examples (not fragments)
- Include comments explaining what each step does
- Use protobuf-es v2 patterns: `create()`, `toBinary()`, `fromBinary()`, `toJson()`, `fromJson()`
- Field names are camelCase in TypeScript (auto-converted from proto snake_case)
- Use `Schema` suffix for message descriptor imports (e.g., `MessageNameSchema`)

Generate the complete EXAMPLES.md content and write it to the file path
specified by the build system.
''');
}

String _runSync(String command) {
  try {
    final result = Process.runSync('sh', ['-c', command], workingDirectory: Directory.current.path);
    if (result.exitCode == 0) return (result.stdout as String).trim();
    return '';
  } catch (_) {
    return '';
  }
}

String _truncate(String input, int maxChars) {
  if (input.length <= maxChars) return input;
  return '${input.substring(0, maxChars)}\n\n... [TRUNCATED]\n';
}
