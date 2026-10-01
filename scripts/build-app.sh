#!/usr/bin/env bash
# Builds Mosaic.app into build/DerivedData. CONFIGURATION defaults to Debug.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-Debug}"
"$ROOT/scripts/bootstrap.sh" > /dev/null
xcodebuild \
    -project "$ROOT/Mosaic.xcodeproj" \
    -scheme Mosaic \
    -configuration "$CONFIGURATION" \
    -destination "platform=macOS,arch=arm64" \
    -derivedDataPath "$ROOT/build/DerivedData" \
    build
echo "App: $ROOT/build/DerivedData/Build/Products/$CONFIGURATION/Mosaic.app"
