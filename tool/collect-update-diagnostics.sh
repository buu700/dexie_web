#!/usr/bin/env bash
set -euo pipefail

update_cache="${XDG_CACHE_HOME:-$HOME/.cache}/chainman/updates"
output="${1:-test-results}/candidates"
shopt -s nullglob

# Failed transactions retain their candidate; successful ones are removed.
for candidate in "$update_cache"/candidate.*/candidate \
  "$update_cache"/v1/candidate.*/candidate; do
  [[ -d "$candidate" ]] || continue
  candidate_output="$output/$(basename "$(dirname "$candidate")")"
  mkdir -p "$candidate_output"
  for reports in test-results example/test-results; do
    if [[ -d "$candidate/$reports" ]]; then
      mkdir -p "$candidate_output/$reports"
      cp -R -- "$candidate/$reports/." "$candidate_output/$reports/"
    fi
  done
  if [[ -e "$candidate/.git" ]]; then
    if ! git -C "$candidate" -c core.hooksPath=/dev/null -c core.fsmonitor=false \
      diff --binary HEAD > "$candidate_output/deps-update.patch"; then
      printf 'Could not export candidate patch: %s\n' "$candidate" >&2
    fi
  fi
done
