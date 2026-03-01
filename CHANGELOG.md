## 0.1.2

- Adds deterministic schema validation for table/index access with stable `StateError` behavior.
- Adds `close()` and helper methods: `delete`, `whereStartsWith`, `deleteWhereStartsWith`.
- Adds fluent Dart API wrappers for Dexie `Table`, `WhereClause`, and `Collection`.
- Adds parity tooling: `tool/check_dexie_parity.dart` + `tool/dexie_parity_manifest.json` + `just parity-check`.
- Expands unit/browser and Patrol E2E coverage for fluent API, data fidelity, loader behavior, and error paths.
- Adds CI artifact upload for E2E failures and wires CI through `just` recipes.

## 0.1.1

- Improved readme.

## 0.1.0

- Initial release of `dexie_web`.
- Bundles `dexie@4.3.0` as package assets (`dexie.min.js`, `dexie.d.ts`).
- Adds zero-config Flutter web loader for Dexie.
- Exposes Dart API: `open`, `put`, `get`, `getAll`, `whereEquals`.
