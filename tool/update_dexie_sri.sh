#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
asset_file="$root_dir/assets/dexie.min.js"
hash_file="$root_dir/lib/src/dexie_sri.g.dart"

if [[ ! -s "$asset_file" ]]; then
  echo "Missing Dexie asset: $asset_file" >&2
  exit 1
fi

hash="$(openssl dgst -sha384 -binary "$asset_file" | openssl base64 -A)"

if [[ -z "$hash" ]]; then
  echo "Failed to compute SHA-384 for $asset_file" >&2
  exit 1
fi

cat > "$hash_file" <<EOF
// GENERATED FILE. Do not edit by hand.
// Updated by: tool/update_dexie_sri.sh

const String dexieScriptIntegrity = 'sha384-$hash';
EOF

dart format "$hash_file"

echo "Updated Dexie SHA-384 in $hash_file: $hash"
