# Vendor

## GRDB con SQLCipher

Mosaic cifra i propri database con SQLCipher (ADR-006, condizionato allo spike S1).

GRDB supporta SQLCipher con Swift Package Manager solo tramite una propria copia con il `Package.swift` modificato, secondo le istruzioni "GRDB+SQLCipher" presenti nel manifesto originale. Per questo:

- `GRDB-SQLCipher/Package.swift` è il manifesto sostitutivo, versionato nel repository;
- `scripts/vendor-grdb.sh` scarica GRDB al tag indicato, verifica il commit e copia il manifesto;
- `GRDB.swift/` è generata dallo script e non è versionata.

| Componente | Versione | Licenza |
| --- | --- | --- |
| GRDB | v7.11.1 (commit `b83108d`) | MIT |
| SQLCipher.swift (Zetetic) | 4.19.0, xcframework binario | BSD-style: attribuzione e riproduzione della licenza nella documentazione dell'app |

Per aggiornare GRDB: cambiare `GRDB_TAG` e `GRDB_COMMIT` nello script e riportare nel manifesto sostitutivo eventuali modifiche del `Package.swift` originale.
