set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

default:
  @just --list

bootstrap:
  just bootstrap-ci
  just hooks-install

bootstrap-ci:
  flutter pub get
  (cd example && flutter pub get)
  npm ci --ignore-scripts
  just bundle

bundle:
  npm ci --ignore-scripts
  cp node_modules/dexie/dist/dexie.min.js assets/dexie.min.js
  cp node_modules/dexie/dist/dexie.d.ts assets/dexie.d.ts
  ./tool/update_dexie_sri.sh

dexie-update:
  npm install dexie@latest --save-dev --ignore-scripts
  just bundle

format:
  dart format lib test example/lib example/test example/patrol_test tool
  npx prettier --write "**/*.{json,js,html,yaml}"

analyze:
  flutter analyze

parity-check:
  dart run tool/check_dexie_parity.dart

test-vm:
  flutter test

test-web:
  #!/usr/bin/env bash
  set -euo pipefail
  CHROME_EXECUTABLE="${CHROME_EXECUTABLE:-}"
  if [[ -z "$CHROME_EXECUTABLE" ]]; then
    for candidate in \
      "$(command -v chromium-browser 2>/dev/null || true)" \
      "$(command -v chromium 2>/dev/null || true)" \
      "$(command -v google-chrome 2>/dev/null || true)" \
      /usr/bin/chromium-browser \
      /snap/bin/chromium \
    ; do
      if [[ -n "$candidate" && -x "$candidate" ]]; then
        CHROME_EXECUTABLE="$candidate"
        break
      fi
    done
  fi
  if [[ -z "$CHROME_EXECUTABLE" ]]; then
    echo "No Chromium/Chrome binary found. Set CHROME_EXECUTABLE." >&2
    exit 1
  fi
  CHROME_EXECUTABLE="$CHROME_EXECUTABLE" flutter test --platform=chrome

e2e-prepare-ci:
  #!/usr/bin/env bash
  set -euo pipefail
  if [[ "${CI:-}" != "true" ]]; then
    echo "Skipping Playwright CI dependency installation outside CI."
    exit 0
  fi
  cd example
  # Pre-install Linux runtime deps needed by Playwright/Chromium in CI.
  # This avoids Patrol's on-demand dependency installation failures.
  npx --yes playwright install --with-deps chromium

e2e:
  #!/usr/bin/env bash
  set -euo pipefail
  export PATH="$PATH:$HOME/.pub-cache/bin"
  if ! command -v patrol >/dev/null 2>&1; then
    dart pub global activate patrol_cli
  fi
  CHROME_EXECUTABLE="${CHROME_EXECUTABLE:-}"
  if [[ -z "$CHROME_EXECUTABLE" ]]; then
    for candidate in \
      "$(command -v chromium-browser 2>/dev/null || true)" \
      "$(command -v chromium 2>/dev/null || true)" \
      "$(command -v google-chrome 2>/dev/null || true)" \
      /usr/bin/chromium-browser \
      /snap/bin/chromium \
    ; do
      if [[ -n "$candidate" && -x "$candidate" ]]; then
        CHROME_EXECUTABLE="$candidate"
        break
      fi
    done
  fi
  if [[ -z "$CHROME_EXECUTABLE" ]]; then
    echo "No Chromium/Chrome binary found. Set CHROME_EXECUTABLE." >&2
    exit 1
  fi
  cd example
  mkdir -p test-results
  E2E_TIMEOUT_SECONDS="${E2E_TIMEOUT_SECONDS:-600}"
  timeout "${E2E_TIMEOUT_SECONDS}" env \
    CHROME_EXECUTABLE="$CHROME_EXECUTABLE" \
    PATROL_ANALYTICS_ENABLED=false \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    patrol test \
    --target patrol_test/dexie_e2e_test.dart \
    --device chrome \
    --web-headless true \
    2>&1 | tee test-results/e2e.log

check:
  just format
  just parity-check
  just analyze
  just test-web

ci-local:
  just bootstrap-ci
  just parity-check
  just analyze
  just test-web
  just e2e

publish-dry-run:
  flutter pub publish --dry-run

publish:
  flutter pub publish

hooks-install:
  lefthook install

clean:
  flutter clean
  (cd example && flutter clean)
  rm -rf build
