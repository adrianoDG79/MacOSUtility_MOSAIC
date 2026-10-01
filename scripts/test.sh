#!/usr/bin/env bash
# Runs the tests of every Mosaic package. Set MOSAIC_KEYCHAIN_TESTS=1 to include
# the test that writes a temporary item to the login keychain.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/scripts/vendor-grdb.sh" > /dev/null
for package in MosaicCore MosaicStorage MosaicPlatform; do
    echo "== $package"
    swift test --package-path "$ROOT/Packages/$package"
done
