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
cd example
mkdir -p test-results
rm -f -- test-results/integration.json
# A nonce compiled into this app ties the report to this invocation, independent
# of filesystem timestamp resolution or an earlier successful report.
export E2E_RUN_ID="$(openssl rand -hex 16)"
flutter drive --no-pub --driver test_driver/integration_test.dart \
  --target integration_test/dexie_e2e_test.dart \
  --device-id web-server --profile --browser-name chrome --headless \
  --driver-port 4444 --chrome-binary "$CHROME_EXECUTABLE" \
  --dart-define="E2E_RUN_ID=$E2E_RUN_ID" "$@" \
  2>&1 | tee test-results/e2e.log
