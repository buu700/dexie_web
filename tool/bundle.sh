#!/usr/bin/env bash
set -euo pipefail
cp node_modules/dexie/dist/dexie.min.js assets/dexie.min.js
cp node_modules/dexie/dist/dexie.d.ts assets/dexie.d.ts
./tool/update_dexie_sri.sh
