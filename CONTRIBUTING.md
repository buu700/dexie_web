# Contributing to dexie_web

First, thank you for contributing! This document outlines the architecture, development workflow, and testing strategies for `dexie_web`.

## Prerequisites

To work on this package, you will need the following installed on your system:
* **Flutter & Dart SDK**
* **Node.js** (v20+ recommended) - Used for fetching the upstream Dexie.js package.
* **[just](https://github.com/casey/just)** - A command runner used to simplify dev workflows.
* **[lefthook](https://github.com/evilmartians/lefthook)** - Used for managing Git pre-commit hooks.
* **Chromium or Google Chrome** - Required for running web and E2E tests.

## Getting Started

Once you've cloned the repository, run the bootstrap command. This will fetch Dart dependencies, install Node modules, bundle the Dexie assets, and install the Git hooks.

```bash
just bootstrap
```

## Project Architecture

Unlike typical Flutter web plugins that require users to modify their `index.html`, this package is designed to be **zero-config and offline-first**. 

1. **Asset Bundling**: We pull the `dexie` package via npm.
2. **SRI Generation**: The `just bundle` command copies `dexie.min.js` into our `assets/` directory and triggers `tool/update_dexie_sri.sh`.
3. **Integrity Enforcement**: The shell script calculates a SHA-384 hash of the minified JS and writes it to `lib/src/dexie_sri.g.dart`.
4. **Runtime Injection**: At runtime, `ensureDexieInitialized` injects the script into the DOM using the generated integrity hash, ensuring the loaded JS exactly matches the version we shipped.

## Available Commands

We use `just` to encapsulate all common tasks. Run `just` or `just --list` to see all available commands:

* `just bootstrap`: Full local setup (deps, bundling, hooks).
* `just bundle`: Copies JS assets from `node_modules` and updates the SRI hash.
* `just format`: Formats Dart, JSON, JS, HTML, and YAML files.
* `just analyze`: Runs Flutter static analysis.
* `just test-web`: Runs standard unit tests in Chromium.
* `just e2e`: Runs full end-to-end integration tests using Patrol.
* `just parity-check`: Verifies Dexie API parity by comparing implemented `Table`/`WhereClause`/`Collection` methods against `assets/dexie.d.ts` and failing with an explicit missing-method list.
* `just ci-local`: Runs the full CI pipeline locally.
* `just dexie-update`: Fetches the latest Dexie.js version from npm and rebuilds assets.

## Testing

Because this package interacts heavily with the browser's DOM and IndexedDB APIs, testing is split into standard web tests and E2E tests.

You must have a Chromium-based browser installed. If it is not in your default path, set the `CHROME_EXECUTABLE` environment variable.

### Unit Tests
Run standard Flutter web tests:
```bash
just test-web
```
*Note: `flutter test --platform=chrome` does not serve package assets properly, which is why we rely on E2E tests to validate the actual script loader.*

### End-to-End (E2E) Tests
We use [Patrol](https://patrol.leancode.co/) for E2E testing to ensure the app actually loads in a real browser environment, properly serves the bundled `dexie.min.js` asset, and passes the Subresource Integrity (SRI) checks.

```bash
just e2e
```
*(If running in a Linux CI environment, be sure to run `just e2e-prepare-ci` first to install Playwright's system dependencies).*

## Updating Upstream Dexie.js

When a new version of `dexie` is released on npm, you can update the bundled version in this package by running:

```bash
just dexie-update
```

This command will:
1. Run `npm install dexie@latest --save-dev --ignore-scripts`
2. Copy the new `dexie.min.js` and `dexie.d.ts` to the `assets/` folder.
3. Automatically recalculate the SHA-384 hash and update `lib/src/dexie_sri.g.dart`.

**Always review the `git diff`** after running this command to ensure the `dexie.d.ts` changes don't break our Dart JS interop bindings in `lib/src/dexie_web_impl.dart`.

## Formatting and Git Hooks

We enforce formatting for Dart (`dart format`) and web files (`prettier`). 
If you ran `just bootstrap`, Lefthook is already installed and will automatically format your staged files on `git commit`. 

To manually format the codebase, run:
```bash
just format
```


## Release Checklist

When preparing to publish a new version to pub.dev:

1. Run `just dexie-update` to ensure we are wrapping the latest JS library.
2. Run `just ci-local` to verify all tests and analyzers pass.
3. Document the changes in `CHANGELOG.md`.
4. Bump the `version` in `pubspec.yaml`.
5. Commit, tag the release, and push.
6. Publish via `just publish` (or `just publish-dry-run` to test first).
