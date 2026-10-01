#!/usr/bin/env bash
# Prepares a fresh checkout: vendored GRDB with SQLCipher, then the Xcode project.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/scripts/vendor-grdb.sh"
command -v xcodegen > /dev/null || { echo "Serve XcodeGen: brew install xcodegen" >&2; exit 1; }
(cd "$ROOT" && xcodegen generate --quiet)
echo "Progetto generato: $ROOT/Mosaic.xcodeproj"
