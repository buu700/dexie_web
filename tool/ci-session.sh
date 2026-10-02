#!/bin/sh
set -eu

# Nix's daemon defaults to /etc; hosted runners need its packaged session config.
dbus_run_session="$(command -v dbus-run-session)"
exec "$dbus_run_session" \
  --config-file="$(dirname "$dbus_run_session")/../share/dbus-1/session.conf" \
  -- "$@"
