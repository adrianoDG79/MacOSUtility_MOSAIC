#!/usr/bin/env bash
# Esegue lo spike S1 in tutte le modalità e salva i risultati in results/.
# Variabili opzionali: CHUNKS (default 100000), FILES (default 300000).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
CHUNKS="${CHUNKS:-100000}"
FILES="${FILES:-300000}"

"$ROOT/scripts/vendor-grdb.sh"
swift build -c release --package-path "$HERE/Plain"
swift build -c release --package-path "$HERE/Cipher"
PLAIN="$(swift build -c release --package-path "$HERE/Plain" --show-bin-path)/S1Plain"
CIPHER="$(swift build -c release --package-path "$HERE/Cipher" --show-bin-path)/S1Cipher"

mkdir -p "$HERE/results"
"$PLAIN" --mode system --chunks "$CHUNKS" --files "$FILES" --out "$HERE/results/system.json" > /dev/null
"$CIPHER" --mode cipherNoKey --chunks "$CHUNKS" --files "$FILES" --out "$HERE/results/cipherNoKey.json" > /dev/null
"$CIPHER" --mode cipherRawKey --chunks "$CHUNKS" --files "$FILES" --out "$HERE/results/cipherRawKey.json" > /dev/null
# La passphrase cambia solo il tempo di apertura (derivazione PBKDF2): basta un carico piccolo.
"$CIPHER" --mode cipherPassphrase --chunks 5000 --files 5000 --out "$HERE/results/cipherPassphrase.json" > /dev/null
echo "Risultati in $HERE/results"
