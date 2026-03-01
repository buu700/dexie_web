import 'dart:convert';
import 'dart:io';

const _interfaceToClass = <String, String>{
  'Table': 'DexieTable',
  'WhereClause': 'DexieWhereClause',
  'Collection': 'DexieCollection',
};

void main() {
  final root = Directory.current.path;
  final dtsFile = File('$root/assets/dexie.d.ts');
  final manifestFile = File('$root/tool/dexie_parity_manifest.json');
  final implFile = File('$root/lib/src/dexie_web_impl.dart');

  if (!dtsFile.existsSync()) {
    stderr.writeln('Missing ${dtsFile.path}');
    exitCode = 1;
    return;
  }
  if (!manifestFile.existsSync()) {
    stderr.writeln('Missing ${manifestFile.path}');
    exitCode = 1;
    return;
  }
  if (!implFile.existsSync()) {
    stderr.writeln('Missing ${implFile.path}');
    exitCode = 1;
    return;
  }

  final dtsContent = dtsFile.readAsStringSync();
  final implContent = implFile.readAsStringSync();
  final manifestContent = manifestFile.readAsStringSync();

  final manifest = (jsonDecode(manifestContent) as Map<String, dynamic>).map(
    (key, value) => MapEntry(key, (value as List).cast<String>().toSet()),
  );

  final dtsMethodsByInterface = <String, Set<String>>{};
  for (final interfaceName in _interfaceToClass.keys) {
    dtsMethodsByInterface[interfaceName] = _extractInterfaceMethods(
      dtsContent,
      interfaceName,
    );
  }

  final implMethodsByClass = <String, Set<String>>{};
  for (final className in _interfaceToClass.values) {
    implMethodsByClass[className] = _extractClassMethods(
      implContent,
      className,
    );
  }

  final failures = <String>[];

  for (final entry in _interfaceToClass.entries) {
    final interfaceName = entry.key;
    final className = entry.value;

    final dtsMethods = dtsMethodsByInterface[interfaceName] ?? <String>{};
    final manifestMethods = manifest[interfaceName] ?? <String>{};
    final implMethods = implMethodsByClass[className] ?? <String>{};

    final missingFromManifest = dtsMethods.difference(manifestMethods).toList()
      ..sort();
    if (missingFromManifest.isNotEmpty) {
      failures.add(
        '$interfaceName: methods present in dexie.d.ts but missing from manifest: '
        '${missingFromManifest.join(', ')}',
      );
    }

    final missingFromImpl = manifestMethods.difference(implMethods).toList()
      ..sort();
    if (missingFromImpl.isNotEmpty) {
      failures.add(
        '$className: methods present in manifest but missing from implementation: '
        '${missingFromImpl.join(', ')}',
      );
    }
  }

  if (failures.isNotEmpty) {
    stderr.writeln('Dexie parity check failed:');
    for (final failure in failures) {
      stderr.writeln('- $failure');
    }
    exitCode = 1;
    return;
  }

  stdout.writeln('Dexie parity check passed.');
}

Set<String> _extractInterfaceMethods(String dtsContent, String interfaceName) {
  final signature = 'export interface $interfaceName';
  final start = dtsContent.indexOf(signature);
  if (start < 0) {
    throw StateError('Could not find interface $interfaceName in dexie.d.ts');
  }
  final braceStart = dtsContent.indexOf('{', start);
  if (braceStart < 0) {
    throw StateError('Could not locate body for interface $interfaceName');
  }

  var depth = 0;
  var bodyStart = -1;
  var bodyEnd = -1;
  for (var i = braceStart; i < dtsContent.length; i++) {
    final char = dtsContent[i];
    if (char == '{') {
      depth++;
      if (bodyStart < 0) {
        bodyStart = i + 1;
      }
    } else if (char == '}') {
      depth--;
      if (depth == 0) {
        bodyEnd = i;
        break;
      }
    }
  }

  if (bodyStart < 0 || bodyEnd < 0) {
    throw StateError('Malformed interface body for $interfaceName');
  }

  final body = dtsContent.substring(bodyStart, bodyEnd);
  final methods = <String>{};
  final methodPattern = RegExp(
    r'^\s*([A-Za-z_][A-Za-z0-9_]*)\s*\(',
    multiLine: true,
  );
  for (final match in methodPattern.allMatches(body)) {
    final name = match.group(1)!;
    methods.add(name);
  }
  return methods;
}

Set<String> _extractClassMethods(String dartContent, String className) {
  final signature = 'class $className';
  final start = dartContent.indexOf(signature);
  if (start < 0) {
    throw StateError('Could not find class $className in implementation file');
  }
  final braceStart = dartContent.indexOf('{', start);
  if (braceStart < 0) {
    throw StateError('Could not locate body for class $className');
  }

  var depth = 0;
  var bodyStart = -1;
  var bodyEnd = -1;
  for (var i = braceStart; i < dartContent.length; i++) {
    final char = dartContent[i];
    if (char == '{') {
      depth++;
      if (bodyStart < 0) {
        bodyStart = i + 1;
      }
    } else if (char == '}') {
      depth--;
      if (depth == 0) {
        bodyEnd = i;
        break;
      }
    }
  }

  if (bodyStart < 0 || bodyEnd < 0) {
    throw StateError('Malformed class body for $className');
  }

  final body = dartContent.substring(bodyStart, bodyEnd);
  final methods = <String>{};
  final methodPattern = RegExp(
    r'^\s*(?:@override\s+)?[A-Za-z0-9_<>,?.\[\] ]+\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(',
    multiLine: true,
  );
  for (final match in methodPattern.allMatches(body)) {
    final name = match.group(1)!;
    if (name != className && !name.startsWith('_')) {
      methods.add(name);
    }
  }
  return methods;
}
