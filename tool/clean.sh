#!/usr/bin/env bash
set -euo pipefail
flutter clean
(cd example && flutter clean)
rm -rf -- build
