# dexie_web

Self-contained Dexie.js (IndexedDB) wrapper for Flutter Web.

- Zero manual `<script>` tags.
- Bundled `dexie.min.js` committed in package assets.
- Loaded only from package assets (no CDN fallback), with SRI enforced.
- Dart-first API (`open`, `put`, `get`, `getAll`, `whereEquals`).

## Installation

Add to your app:

```yaml
dependencies:
  dexie_web: ^0.1.0
```

Then run:

```bash
flutter pub get
```

## Usage

```dart
import 'package:dexie_web/dexie_web.dart';

Future<void> main() async {
  final db = DexieDatabase('myAppDb');

  await db.open({
    'friends': '++id, name, age',
    'todos': '++id, title, completed',
  });

  await db.put('friends', {'name': 'Alice', 'age': 30});

  final friends = await db.getAll<Map>('friends');
  final adults = await db.whereEquals<Map>('friends', 'age', 18);

  // Use values so static analysis won't mark them unused in examples.
  print('friends: ${friends.length}, adults: ${adults.length}');
}
```

Optional preload on web:

```dart
await ensureDexieInitialized();
```

Loader policy control:

```dart
// Default:
setDefaultDexieLoadPolicy(DexieLoadPolicy.strictPackage);

// Option 1:
setDefaultDexieLoadPolicy(DexieLoadPolicy.strictGlobal);

// Option 2:
setDefaultDexieLoadPolicy(DexieLoadPolicy.preferGlobalFallbackPackage);
```

You can also override per call:

```dart
await ensureDexieInitialized(
  policy: DexieLoadPolicy.preferGlobalFallbackPackage,
);
```

## Dexie Bundling Workflow

This package bundles Dexie with npm at development time and commits built assets.

```bash
just bootstrap-ci
just bundle
```

This generates:

- `assets/dexie.min.js`
- `assets/dexie.d.ts`

## Testing (Chromium)

This package is tested in a real browser with Chromium. Flutter's web device
id stays `chrome` for `flutter test`; set `CHROME_EXECUTABLE` to the Chromium
binary.

```bash
just test-web
just e2e
```

- `just test-web` runs package tests in Chromium.
- `just e2e` runs E2E tests from `example/patrol_test` with Patrol
  (`patrol test --device chrome --web-headless true`).
- `just e2e` auto-installs Patrol CLI if missing.
- `just e2e` sets `PATROL_ANALYTICS_ENABLED=false` and enforces
  `LANG/LC_ALL=en_US.UTF-8` for reliable Playwright + Flutter web startup.

`flutter test --platform=chrome` does not serve package assets, so real loader
validation (script path + SRI) is covered by Patrol E2E in `just e2e`.

## DateTime Behavior

`DateTime` values are stored as native JavaScript `Date` objects and
round-trip back to Dart as `DateTime` values.

## Justfile Commands

Common workflows are available via `just`:

```bash
just bootstrap
just bootstrap-ci
just bundle
just analyze
just test-web
just e2e
just ci-local
just dexie-update
just publish-dry-run
```

## Git Hooks (lefthook)

This repository uses `lefthook` with a `pre-commit` hook that auto-formats
staged Dart files (`dart format`) and staged web config files
(`*.json`, `*.js`, `*.html`) with `prettier`, then re-stages changes.

`lefthook` is expected to be installed on your system PATH.

Install hooks:

```bash
just bootstrap
```

## Updating Dexie

```bash
just dexie-update
```

Then review changes:

```bash
git diff
```

`just dexie-update` also refreshes the loader's SRI hash in
`lib/src/dexie_sri.g.dart`.
If needed, adjust interop based on `assets/dexie.d.ts` changes.

## Release Checklist

1. Run `just dexie-update`.
2. Update `CHANGELOG.md`.
3. Bump `version` in `pubspec.yaml`.
4. Commit, tag, and push.
5. Publish with `flutter pub publish`.
