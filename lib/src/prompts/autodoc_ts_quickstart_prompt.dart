// ignore_for_file: avoid_print

import 'dart:io';

import '_ci_config.dart';

/// Autodoc: QUICKSTART.md generator for a proto module (TypeScript variant).
///
/// Usage:
///   dart run scripts/prompts/autodoc_ts_quickstart_prompt.dart <module_name> <source_dir> <lib_dir> <output_path>

void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln('Usage: autodoc_ts_quickstart_prompt.dart <module_name> <source_dir> [lib_dir]');
    exit(1);
  }

  final pkg = CiConfig.current.packageName;
  final moduleName = args[0];
  final sourceDir = args[1];
  final libDir = args.length > 2 ? args[2] : '';

  final protoTree = _runSync(
    'tree $sourceDir -L 3 --dirsfirst 2>/dev/null || find $sourceDir -name "*.proto" | head -30',
  );
  final protoFiles = _runSync('find $sourceDir -name "*.proto" -type f 2>/dev/null');
  final protoCount = _runSync('find $sourceDir -name "*.proto" -type f 2>/dev/null | wc -l');

  // Read first proto file for service/message overview
  final firstProto = _runSync('find $sourceDir -name "*.proto" -type f 2>/dev/null | head -1');
  final protoPreview = firstProto.isNotEmpty ? _truncate(_runSync('cat "$firstProto"'), 15000) : '(no proto files)';

  // Check for existing generated TypeScript code
  String libTree = '(no lib directory)';
  String tsPreview = '';
  if (libDir.isNotEmpty && Directory(libDir).existsSync()) {
    libTree = _runSync(
      'tree $libDir -L 2 --dirsfirst -I "*.pb.ts|*.pb.js|node_modules" 2>/dev/null || echo "(no tree)"',
    );
    final firstTs = _runSync(
      'find $libDir -name "*.ts" -not -name "*.pb.*" -not -name "*.d.ts" -type f 2>/dev/null | head -1',
    );
    if (firstTs.isNotEmpty) {
      tsPreview = _truncate(_runSync('cat "$firstTs"'), 5000);
    }
  }

  // Check for gRPC services
  final services = _runSync('grep -r "^service " $sourceDir 2>/dev/null || echo "(no services)"');
  final messages = _runSync('grep -rn "^message " $sourceDir 2>/dev/null | head -30');

  // Check for package.json exports
  String exportsPreview = '';
  final packageJsonPath = _runSync(
    'find $libDir/.. -maxdepth 2 -name "package.json" -not -path "*/node_modules/*" 2>/dev/null | head -1',
  );
  if (packageJsonPath.isNotEmpty) {
    exportsPreview = _truncate(_runSync('cat "$packageJsonPath"'), 3000);
  }

  print('''
You are a documentation writer for the **$moduleName** module of the
$pkg TypeScript package.

Your job is to write a QUICKSTART.md that helps a developer get started
with this module in under 5 minutes.

## Module Structure

### Proto Files ($protoCount files)
```
$protoTree
```

### Proto File List
```
$protoFiles
```

### Generated TypeScript Code
```
$libTree
```

### Services Defined
```
$services
```

### Key Message Types
```
$messages
```

## Proto File Preview (first file)
```protobuf
$protoPreview
```

${tsPreview.isNotEmpty ? '## TypeScript Code Preview\n```typescript\n$tsPreview\n```' : ''}

${exportsPreview.isNotEmpty ? '## package.json\n```json\n$exportsPreview\n```' : ''}

## Instructions

Write a QUICKSTART.md with these sections:

### 1. Overview
- What this module does (2-3 sentences)
- What APIs/services it provides

### 2. Installation
```bash
pnpm add @open-runtime/$pkg
```

### 3. Import
```typescript
import { create, toBinary, fromBinary, toJson, fromJson } from '@bufbuild/protobuf';
import { MessageNameSchema } from '@open-runtime/$pkg/$moduleName';
```
Use the REAL import paths based on the package.json exports map.
Always use ESM import syntax.

### 4. Setup
Show how to create a client/channel (if gRPC service) or instantiate key messages.
Use REAL type names from the proto definitions.

For protobuf-es message creation:
```typescript
const msg = create(MessageNameSchema, {
  fieldName: value,
});
```

### 5. Common Operations
3-5 code examples showing the most useful operations:
- Creating and populating key messages using `create(Schema, {...})`
- Serializing with `toBinary()` and `fromBinary()`
- JSON conversion with `toJson()` and `fromJson()`
- Making service calls (if applicable)
- Working with enums and oneof fields

### 6. Error Handling
Common error patterns and how to handle them.

### 7. Related Modules
List any related modules in the $pkg.

## Rules
- Use ONLY real type/field names from the proto definitions
- Do NOT fabricate API names or import paths
- Code examples must be valid TypeScript that would compile
- Keep it concise -- this is a QUICKSTART, not a full reference
- Use ESM import syntax: `import { X } from '@open-runtime/$pkg/...'`
- Use protobuf-es patterns: `create()`, `toBinary()`, `fromBinary()`, `toJson()`, `fromJson()`
- Field names in TypeScript are camelCase (auto-converted from proto snake_case)

Generate the complete QUICKSTART.md content and write it to the file path
specified by the build system.
''');
}

String _runSync(String command) {
  try {
    final result = Process.runSync('sh', ['-c', command], workingDirectory: Directory.current.path);
    if (result.exitCode == 0) return (result.stdout as String).trim();
    return '(command failed)';
  } catch (_) {
    return '(unavailable)';
  }
}

String _truncate(String input, int maxChars) {
  if (input.length <= maxChars) return input;
  return '${input.substring(0, maxChars)}\n\n... [TRUNCATED: ${input.length - maxChars} chars omitted]\n';
}
