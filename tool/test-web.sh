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
CHROME_EXECUTABLE="$CHROME_EXECUTABLE" flutter test --no-pub --platform=chrome
