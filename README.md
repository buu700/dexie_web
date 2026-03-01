# dexie_web

A self-contained, zero-configuration [Dexie.js](https://dexie.org) (IndexedDB) wrapper for Flutter Web. 

`dexie_web` eliminates the friction of using IndexedDB in Flutter Web. It bundles the Dexie JS library directly into the package assets and automatically injects it at run-time with Subresource Integrity (SRI) enforced. No external CDN dependencies, no manual `<script>` tags in your `index.html`, and fully WASM-ready using modern `dart:js_interop`.

For avoidance of doubt, `dexie_web` is web-only at run-time. It can be imported on non-web platforms for shared code, but calling its APIs off-web throws `UnsupportedError`.

## Features

* **Zero Config:** Automatically loads the bundled Dexie.js script when you open a database.
* **Offline-First & Secure:** Does not rely on external networks. Loaded strictly from local package assets with built-in SRI hash validation to prevent tampering.
* **Type-Safe & Dart-First:** Wrap IndexedDB operations in a familiar Dart API (`open`, `put`, `get`, `getAll`, `whereEquals`).
* **Cross-Platform Stubs:** Safely import and compile on iOS/Android/Desktop (methods will throw an `UnsupportedError` if invoked off-web, but compilation won't break).
* **Native Dates:** Dart `DateTime` objects are automatically serialized to native JavaScript `Date` objects for accurate IndexedDB sorting and querying.

## Installation

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  dexie_web: ^0.1.1
```

Or install via the command line:

```bash
flutter pub add dexie_web
```

## Usage

Using `dexie_web` is straightforward. Instantiate a `DexieDatabase`, define your schema, and start reading/writing data.

```dart
import 'package:dexie_web/dexie_web.dart';

Future<void> main() async {
  // 1. Initialize the database instance
  final db = DexieDatabase('myAppDb');

  // 2. Open the database and define your schema.
  // The Dexie script is automatically injected into the DOM here if it isn't already.
  await db.open({
    'friends': '++id, name, age, birthday',
    'todos': '++id, title, completed',
  });

  // 3. Write data
  await db.put('friends', {
    'name': 'Alice', 
    'age': 30,
    'birthday': DateTime.utc(1996, 1, 1),
  });

  // 4. Read data
  final allFriends = await db.getAll<Map<String, dynamic>>('friends');
  
  // 5. Query data
  final adults = await db.whereEquals<Map<String, dynamic>>('friends', 'age', 18);

  print('friends: ${allFriends.length}, adults: ${adults.length}');
  db.close();
}
```

## Fluent API (Dexie-style)

Alongside helper methods, `dexie_web` exposes a fluent API for `Table`, `WhereClause`, and `Collection`.

```dart
final friends = db.table<Map<String, dynamic>, dynamic, Map<String, dynamic>>(
  'friends',
);

await friends.bulkPut([
  {'name': 'Alice', 'age': 30},
  {'name': 'Bob', 'age': 25},
]);

final adults = await friends
    .whereIndex('age')
    .aboveOrEqual(18)
    .reverse()
    .toList();
```

### Parity Coverage (Dexie 4.3 Runtime Surfaces)

`dexie_web` covers the primary runtime query/mutation APIs for:

* `Table`: `get`, `where`, `filter`, `count`, `offset`, `limit`, `each`, `toArray`, `toCollection`, `orderBy`, `reverse`, `mapToClass`, `add`, `update`, `upsert`, `put`, `delete`, `clear`, `bulkGet`, `bulkAdd`, `bulkPut`, `bulkUpdate`, `bulkDelete`
* `WhereClause`: `above`, `aboveOrEqual`, `anyOf`, `anyOfIgnoreCase`, `below`, `belowOrEqual`, `between`, `equals`, `equalsIgnoreCase`, `inAnyRange`, `startsWith`, `startsWithAnyOf`, `startsWithIgnoreCase`, `startsWithAnyOfIgnoreCase`, `noneOf`, `notEqual`
* `Collection`: `and`, `clone`, `count`, `distinct`, `each`, `eachKey`, `eachPrimaryKey`, `eachUniqueKey`, `filter`, `first`, `firstKey`, `keys`, `primaryKeys`, `last`, `lastKey`, `limit`, `offset`, `or`, `raw`, `reverse`, `sortBy`, `toArray`, `uniqueKeys`, `until`, `delete`, `modify`

Aliases:

* `toList()` -> `toArray()`
* `remove()` -> `delete()`
* `removeAll()` -> `clear()`

## Deterministic Validation Errors

`dexie_web` validates table/index names from your declared schema. Invalid table/index operations throw `StateError` immediately, rather than relying on browser-specific IndexedDB error timing.

## Advanced: Preloading & Loader Policies

By default, `dexie_web` automatically injects the bundled `dexie.min.js` file the first time you call `db.open()`. If you'd like to preload the script earlier in your app's lifecycle to speed up initial database access, you can call:

```dart
await ensureDexieInitialized();
```

### Customizing the Load Policy

If you need to control how the script is loaded (for example, if you prefer to manually provide your own Dexie script via a CDN in your `index.html`), you can change the global load policy before initialization:

```dart
// Default: Strictly loads the packaged asset and throws if an unmanaged global Dexie exists.
setDefaultDexieLoadPolicy(DexieLoadPolicy.strictPackage);

// Option 1: Expects a global `Dexie` object to already exist (e.g., loaded by your index.html).
setDefaultDexieLoadPolicy(DexieLoadPolicy.strictGlobal);

// Option 2: Uses a global `Dexie` if available, otherwise falls back to injecting the package asset.
setDefaultDexieLoadPolicy(DexieLoadPolicy.preferGlobalFallbackPackage);
```

You can also override the policy per initialization call:

```dart
await ensureDexieInitialized(
  policy: DexieLoadPolicy.preferGlobalFallbackPackage,
);
```
