#!/usr/bin/env bash
# Prepara Vendor/GRDB.swift: GRDB a un commit verificato, compilato con SQLCipher.
# Vedi Vendor/README.md e ADR-006.
set -euo pipefail

GRDB_TAG="v7.11.1"
GRDB_COMMIT="b83108d10f42680d78f23fe4d4d80fc88dab3212"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/Vendor/GRDB.swift"
MANIFEST="$ROOT/Vendor/GRDB-SQLCipher/Package.swift"

if [[ -d "$DEST/.git" ]] && [[ "$(git -C "$DEST" rev-parse HEAD)" == "$GRDB_COMMIT" ]]; then
    echo "GRDB $GRDB_TAG già presente in Vendor/GRDB.swift"
else
    rm -rf "$DEST"
    git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$GRDB_TAG" https://github.com/groue/GRDB.swift.git "$DEST"
    actual="$(git -C "$DEST" rev-parse HEAD)"
    if [[ "$actual" != "$GRDB_COMMIT" ]]; then
        echo "Il tag $GRDB_TAG punta a $actual invece di $GRDB_COMMIT: interrotto." >&2
        rm -rf "$DEST"
        exit 1
    fi
fi

cp "$MANIFEST" "$DEST/Package.swift"
echo "Vendor/GRDB.swift pronto: GRDB $GRDB_TAG con SQLCipher"
