#!/usr/bin/env bash
# Spike S9: compiles packages and app for older macOS deployment targets and
# lists the availability errors. Works on a temporary copy of the repository.
# Usage: check.sh [targets...]   (default: 13.0 14.0 15.0 26.0)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TARGETS=("${@:-13.0 14.0 15.0 26.0}")
[[ $# -eq 0 ]] && TARGETS=(13.0 14.0 15.0 26.0)
WORK="$(mktemp -d -t mosaic-s9)"
trap 'rm -rf "$WORK"' EXIT
"$ROOT/scripts/vendor-grdb.sh" > /dev/null

for target in "${TARGETS[@]}"; do
    major="${target%%.*}"
    copy="$WORK/$target"
    mkdir -p "$copy/Vendor"
    rsync -a --exclude '.build' "$ROOT/App" "$ROOT/Packages" "$ROOT/Config" "$ROOT/project.yml" "$copy/"
    ln -s "$ROOT/Vendor/GRDB.swift" "$copy/Vendor/GRDB.swift"
    sed -i '' "s/\.macOS(\.v14)/.macOS(\"$target\")/" "$copy"/Packages/*/Package.swift
    sed -i '' "s/macOS: \"14.0\"/macOS: \"$target\"/" "$copy/project.yml"
    sed -i '' "s/^MACOSX_DEPLOYMENT_TARGET = .*/MACOSX_DEPLOYMENT_TARGET = $target/" "$copy/Config/Mosaic.xcconfig"
    (cd "$copy" && xcodegen generate --quiet)
    log="$copy/build.log"
    if xcodebuild -project "$copy/Mosaic.xcodeproj" -scheme Mosaic -configuration Debug \
        -destination "platform=macOS,arch=arm64" -derivedDataPath "$copy/DerivedData" build > "$log" 2>&1; then
        echo "macOS $target: BUILD SUCCEEDED"
    else
        echo "macOS $target: BUILD FAILED"
        grep -E "error:" "$log" | sed -E "s#$copy/##; s#^.*/(App|Packages)/#\1/#" | sort -u | head -40
    fi
    echo "---"
done
