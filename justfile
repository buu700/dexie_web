set shell := ["bash", "--noprofile", "--norc", "-c"]

default:
  @just --list

shell:
  CHAINMAN_MODE="${CHAINMAN_MODE:-host-nix}" ./scripts/chainman.sh shell --profile default

# Run any raw command inside the clean Nix devShell
#   just exec flutter doctor
#   just exec ls -la
#   just exec cargo build
exec *args:
    CHAINMAN_MODE="${CHAINMAN_MODE:-host-nix}" ./scripts/chainman.sh exec --profile default -- {{args}}

# Run a `just` recipe inside the clean Nix devShell
#   just run bootstrap
#   just run e2e
#   just run test-web
#   just run ci-local
run name *args:
    CHAINMAN_MODE="${CHAINMAN_MODE:-host-nix}" ./scripts/chainman.sh run "{{name}}" -- {{args}}

bootstrap:
  just bootstrap-ci
  just hooks-install

bootstrap-ci:
  flutter pub get
  (cd example && flutter pub get)
  dart pub global activate patrol_cli 4.1.0
  npm ci --ignore-scripts
  just bundle

bundle:
  npm ci --ignore-scripts
  cp node_modules/dexie/dist/dexie.min.js assets/dexie.min.js
  cp node_modules/dexie/dist/dexie.d.ts assets/dexie.d.ts
  ./tool/update_dexie_sri.sh

dexie-update:
  CHAINMAN_MODE="${CHAINMAN_MODE:-host-nix}" ./scripts/chainman.sh deps-update --no-commit -- --targets js

deps-update *args:
  CHAINMAN_MODE="${CHAINMAN_MODE:-host-nix}" ./scripts/chainman.sh deps-update {{args}}

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
  @echo 'Nix supplies browser libraries; the pinned Patrol runner installs its matching browsers in .cache/patrol-browsers.'

e2e:
  #!/usr/bin/env bash
  set -euo pipefail
  command -v patrol >/dev/null 2>&1 || { echo 'Patrol CLI is missing; run just run bootstrap-ci.' >&2; exit 1; }
  # Patrol explicitly installs its pinned Playwright browsers before running tests.
  export PLAYWRIGHT_BROWSERS_PATH="$PWD/.cache/patrol-browsers"
  mkdir -p "$PLAYWRIGHT_BROWSERS_PATH"
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
  (
    runner_pid=''
    cleanup() {
      status=$?
      trap - EXIT INT TERM
      if [[ -n "$runner_pid" ]]; then
        # GNU timeout owns this process group. Patrol may leave its Flutter
        # server alive after returning, so release the entire owned group.
        kill -TERM -- "-$runner_pid" 2>/dev/null || true
        for attempt in {1..20}; do
          kill -0 -- "-$runner_pid" 2>/dev/null || break
          sleep 0.1
        done
        kill -KILL -- "-$runner_pid" 2>/dev/null || true
        wait "$runner_pid" 2>/dev/null || true
      fi
      exit "$status"
    }
    trap cleanup EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    timeout --kill-after=15s "${E2E_TIMEOUT_SECONDS}" env \
      CHROME_EXECUTABLE="$CHROME_EXECUTABLE" \
      PATROL_ANALYTICS_ENABLED=false \
      LANG=en_US.UTF-8 \
      LC_ALL=en_US.UTF-8 \
      patrol test \
      --target patrol_test/dexie_e2e_test.dart \
      --device chrome \
      --web-headless true &
    runner_pid=$!
    wait "$runner_pid"
  ) 2>&1 | tee test-results/e2e.log

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
