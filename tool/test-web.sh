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
if [[ -n "$CHROME_EXECUTABLE" && "$CHROME_EXECUTABLE" != */* ]]; then
  CHROME_EXECUTABLE="$(command -v -- "$CHROME_EXECUTABLE" || true)"
fi
if [[ -z "$CHROME_EXECUTABLE" || ! -x "$CHROME_EXECUTABLE" ]]; then
  echo "No executable Chromium/Chrome binary found. Set CHROME_EXECUTABLE." >&2
  exit 1
fi
printf 'Browser: %s\n' "$CHROME_EXECUTABLE"
"$CHROME_EXECUTABLE" --version
printf '%s\n' 'Starting Flutter browser test compilation and launch'
CHROME_EXECUTABLE="$CHROME_EXECUTABLE" exec flutter test --no-pub --platform=chrome --verbose --reporter=expanded "$@"
