# Contributing to dexie_web

First, thank you for contributing! This document outlines the architecture, development workflow, and testing strategies for `dexie_web`.

## Prerequisites

- Git
- [just](https://github.com/casey/just) as the command entrypoint
- [Determinate Nix](https://determinate.systems) with flakes enabled, or Docker/Podman for `CHAINMAN_MODE=container-nix`

### Development with Nix (recommended)

```bash
# Run a project recipe in the reproducible dev shell
just run bootstrap
```

Use `just run <task>` for the named tasks declared in `chainman.toml`, and
`just exec <command...>` for arbitrary commands. Just recipes are small aliases:

```bash
just run test-web
just run e2e
just exec flutter doctor -v
just exec node --version
```

## Getting Started with Nix

```bash
just run bootstrap   # deps, bundle, hooks
```

Or:

```bash
just shell           # interactive nix develop shell
just                # list recipes
just run ci-local
```

Chainman manages development commands only; it is not a dependency of applications using `dexie_web`.
The checked-in launcher executes the hash-verified runtime in the Nix store.
Host Nix is the default; select `CHAINMAN_MODE=container-nix` for Docker or Podman.
Frozen npm and Pub setup uses shared download caches and project-local installed
artifacts, protected by Chainman's setup leases. Nix supplies Flutter, its Dart
SDK, Chromium on Linux, and the matching ChromeDriver. E2E does not activate a
global CLI or install Node dependencies in the Pub cache.

## Getting Started

Once you've cloned the repository, run the bootstrap command. This will fetch Dart dependencies, install Node modules, bundle the Dexie assets, and install the Git hooks.

```bash
just run bootstrap
```

Run project commands through `just run` so Chainman supplies the pinned toolchain.

## Project Architecture

Unlike typical Flutter web plugins that require users to modify their `index.html`, this package is designed to be **zero-config and offline-first**.

1. **Asset Bundling**: We pull the `dexie` package via npm.
2. **SRI Generation**: The `just run bundle` command copies `dexie.min.js` into our `assets/` directory and triggers `tool/update_dexie_sri.sh`.
3. **Integrity Enforcement**: The shell script calculates a SHA-384 hash of the minified JS and writes it to `lib/src/dexie_sri.g.dart`.
4. **Runtime Injection**: At runtime, `ensureDexieInitialized` injects the script into the DOM using the generated integrity hash, ensuring the loaded JS exactly matches the version we shipped.

## Available Commands

We use `just` to encapsulate all common tasks. Use `just run <recipe>` to run recipes in the clean Nix shell. Run
`just --list` to see all available recipes:

- `just run bootstrap`: Full local setup (deps, bundling, hooks).
- `just run bundle`: Copies JS assets from `node_modules` and updates the SRI hash.
- `just run format`: Formats Dart, JSON, JS, HTML, and YAML files.
- `just run analyze`: Runs Flutter static analysis.
- `just run test-web`: Runs standard unit tests in Chromium.
- `just run e2e`: Runs profile-mode browser integration tests using Flutter’s SDK runner.
- `just run parity-check`: Verifies Dexie API parity by comparing implemented `Table`/`WhereClause`/`Collection` methods against `assets/dexie.d.ts` and failing with an explicit missing-method list.
- `just run ci-local`: Runs the full CI pipeline locally.
- `just run dexie-update`: Selects the newest eligible stable Dexie.js version and rebuilds assets.

## Testing

Because this package interacts heavily with the browser's DOM and IndexedDB APIs, testing is split into standard web tests and E2E tests.

The Linux Nix profile supplies a matching Chromium/ChromeDriver pair. macOS host
mode needs Chrome matching the pinned ChromeDriver; `CHROME_EXECUTABLE` selects
an explicit browser. Container mode supplies the complete Linux pair.

### Unit Tests

Run standard Flutter web tests:

```bash
just run test-web
```

_Note: `flutter test --platform=chrome` does not serve package assets properly, which is why we rely on E2E tests to validate the actual script loader._

### End-to-End (E2E) Tests

We use Flutter’s SDK `integration_test` with `flutter drive --profile` and
ChromeDriver. This builds and serves the application with its package assets in a
real browser, preserving all six IndexedDB, loader, and SRI cases from the prior
Patrol suite. The driver requires Flutter success plus the exact checked-in test
inventory, without skipped or duplicate cases. A nonce compiled into each run
rejects stale reports; results are saved to `example/test-results/integration.json`.

```bash
just run e2e
```

Chainman owns ChromeDriver readiness, task deadlines, and child cleanup; `e2e-prepare-ci` remains as a compatibility
recipe and performs no host installation.

## Updating Upstream Dexie.js

When a stable `dexie` release has satisfied the configured 30-day maturity period, update the bundled version by running:

```bash
just run dexie-update
```

This command will:

1. Select the newest stable release old enough for the project policy and update the exact npm pin.
2. Copy the new `dexie.min.js` and `dexie.d.ts` to the `assets/` folder.
3. Automatically recalculate the SHA-384 hash and update `lib/src/dexie_sri.g.dart`.

**Always review the `git diff`** after running this command to ensure the `dexie.d.ts` changes don't break our Dart JS interop bindings in `lib/src/dexie_web_impl.dart`.

## Formatting and Git Hooks

We enforce formatting for Dart (`dart format`) and web files (`prettier`).
If you ran `just run bootstrap`, Lefthook is already installed and will automatically format your staged files on `git commit`.

To manually format the codebase, run:

```bash
just run format
```

## Release Checklist

When preparing to publish a new version to pub.dev:

1. Run `just deps-update-js` to select the newest stable Dexie release that satisfies the 30-day maturity policy.
2. Run `just run ci-local` to verify all tests and analyzers pass.
3. Document the changes in `CHANGELOG.md`.
4. Bump the `version` in `pubspec.yaml`.
5. Commit, tag the release, and push.
6. Publish via `just run publish` (or `just run publish-dry-run` to test first).
