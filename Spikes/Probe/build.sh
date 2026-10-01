#!/usr/bin/env bash
# Builds Mosaic Probe. With INSTALL=1 it also copies the app to /Applications,
# which the local network test of S8 requires.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
(cd "$HERE" && xcodegen generate --quiet)
xcodebuild \
    -project "$HERE/MosaicProbe.xcodeproj" \
    -scheme MosaicProbe \
    -configuration Debug \
    -destination "platform=macOS,arch=arm64" \
    -derivedDataPath "$ROOT/build/ProbeDerivedData" \
    build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
APP="$ROOT/build/ProbeDerivedData/Build/Products/Debug/Mosaic Probe.app"
if [[ "${INSTALL:-0}" == "1" ]]; then
    rm -rf "/Applications/Mosaic Probe.app"
    cp -R "$APP" /Applications/
    APP="/Applications/Mosaic Probe.app"
fi
echo "$APP"
