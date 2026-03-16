// ignore_for_file: avoid_print

import 'dart:io';

import '_ci_config.dart';

/// Autodoc: API_REFERENCE.md generator for a proto module (TypeScript variant).
///
/// Usage:
///   dart run scripts/prompts/autodoc_ts_api_reference_prompt.dart <module_name> <source_dir> <lib_dir>

void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln('Usage: autodoc_ts_api_reference_prompt.dart <module_name> <source_dir> [lib_dir]');
    exit(1);
  }

  final pkg = CiConfig.current.packageName;
  final moduleName = args[0];
  final sourceDir = args[1];
  final libDir = args.length > 2 ? args[2] : '';

  // Gather all proto content (truncated if massive)
  final protoFiles = _runSync('find $sourceDir -name "*.proto" -type f 2>/dev/null');
  final allProtoContent = StringBuffer();
  for (final file in protoFiles.split('\n').where((f) => f.isNotEmpty)) {
    allProtoContent.writeln('// === $file ===');
    allProtoContent.writeln(_truncate(_runSync('cat "$file"'), 20000));
    allProtoContent.writeln();
  }

  final protoContent = _truncate(allProtoContent.toString(), 60000);

  // Check for generated TypeScript code
  String tsPreview = '';
  if (libDir.isNotEmpty && Directory(libDir).existsSync()) {
    final generatedFiles = _runSync('find $libDir -name "*_pb.ts" -o -name "*_pb.js" 2>/dev/null | head -5');
    if (generatedFiles.isNotEmpty) {
      final buf = StringBuffer();
      for (final file in generatedFiles.split('\n').where((f) => f.isNotEmpty)) {
        buf.writeln('// === $file ===');
        buf.writeln(_truncate(_runSync('cat "$file"'), 10000));
        buf.writeln();
      }
      tsPreview = _truncate(buf.toString(), 30000);
    }
  }

  print('''
You are a documentation writer generating an API reference for the
**$moduleName** module of the $pkg TypeScript package.

## Proto Definitions

```protobuf
$protoContent
```

${tsPreview.isNotEmpty ? '## Generated TypeScript Code\n\n```typescript\n$tsPreview\n```' : ''}

## Instructions

Generate an API_REFERENCE.md with these sections:

### 1. Messages
For EACH message type in the proto files:
- **MessageName** -- one-line description (from proto comments or inferred)
  - List all fields with types and descriptions
  - Note required vs optional fields
  - Document any oneof groups
  - Show the TypeScript type mapping (e.g., `int32` -> `number`, `string` -> `string`, `bytes` -> `Uint8Array`, `repeated X` -> `X[]`)

### 2. Services (if any)
For EACH service:
- **ServiceName** -- what it does
  - List all RPC methods with input/output types
  - Note streaming methods (client/server/bidi)

### 3. Enums
For EACH enum:
- **EnumName** -- what it represents
  - List all values with descriptions

### 4. TypeScript Usage
For key message types, show how to create and use them with protobuf-es:
```typescript
import { create, toBinary, fromBinary, toJson, fromJson } from '@bufbuild/protobuf';
import { MessageNameSchema } from '@open-runtime/$pkg/$moduleName';

// Create a message
const msg = create(MessageNameSchema, {
  field1: value1,
  field2: value2,
});

// Serialize to binary
const bytes = toBinary(MessageNameSchema, msg);

// Deserialize from binary
const decoded = fromBinary(MessageNameSchema, bytes);

// Convert to/from JSON
const jsonObj = toJson(MessageNameSchema, msg);
const fromJsonMsg = fromJson(MessageNameSchema, jsonObj);
```

### 5. Installation
```bash
pnpm add @open-runtime/$pkg
```

## Rules
- Use ONLY names that appear in the proto definitions above
- Do NOT fabricate fields, methods, or enum values
- Group related messages together
- Keep descriptions concise but informative
- Use protobuf-es patterns: `create()`, `toBinary()`, `fromBinary()`, `toJson()`, `fromJson()`
- Import from `@open-runtime/$pkg/...` using the package.json exports map
- TypeScript field names use camelCase (converted from proto snake_case automatically by protobuf-es)

Generate the complete API_REFERENCE.md content and write it to the file path
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
