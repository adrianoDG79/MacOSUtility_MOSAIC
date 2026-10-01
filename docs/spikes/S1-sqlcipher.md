# S1 — SQLCipher con GRDB

| Campo | Valore |
| --- | --- |
| Obiettivo | Verificare la condizione di D7 (ADR-006): prestazioni accettabili e integrazione affidabile di GRDB con SQLCipher via Swift Package Manager |
| Esito | **GO** |
| Codice | `Spikes/S1-SQLCipher/`, `Vendor/`, `scripts/vendor-grdb.sh`, `Packages/MosaicStorage/` |

## Metodo

- **Integrazione.** GRDB v7.11.1 (commit `b83108d`) con il manifesto modificato secondo le istruzioni "GRDB+SQLCipher" dello stesso GRDB, e dipendenza dal pacchetto ufficiale SQLCipher.swift 4.19.0 di Zetetic (xcframework binario).
- **Carico sintetico e riproducibile:** 100.000 blocchi di testo da 160 parole (circa 100 MB, italiano e inglese con accenti, frequenze di tipo Zipf) indicizzati con FTS5 `unicode61 remove_diacritics 2` e prefissi 2 e 3, più 300.000 nomi di file indicizzati con `trigram`.
- **Quattro modalità, stesso codice:** SQLite di sistema (3.51.0); SQLCipher senza chiave; SQLCipher con chiave grezza da 256 bit; SQLCipher con passphrase (PBKDF2), quest'ultima solo per l'apertura.
- **Ambiente:** MacBook Pro M1 Pro, 32 GB, macOS 26.6.2, build release, cache calda, un'esecuzione per modalità.

## Risultati

| Misura | SQLite di sistema | SQLCipher senza chiave | **SQLCipher con chiave** |
| --- | --- | --- | --- |
| Motore | 3.51.0 | 3.53.4 | 3.53.4 |
| Inserimento blocchi | 17.635/s (5,7 s) | 15.443/s (6,5 s) | **11.322/s (8,8 s)** |
| Inserimento nomi | 188.133/s | 191.349/s | **142.008/s** |
| Aggiornamento di 1.000 blocchi | 482 ms | 523 ms | **872 ms** |
| Dimensione del database | 293 MB | 293 MB | **310 MB (+6%)** |
| Apertura | 4,2 ms | 7,4 ms | **1,9 ms** |
| Riapertura e prima query | 11,2 ms | 7,9 ms | **12,3 ms** |
| Memoria di picco | 60 MB | 35 MB | **35 MB** |
| Termine comune, p50/p95 | 12,6 / 28,1 ms | 5,6 / 15,4 ms | **7,1 / 16,9 ms** |
| Termine medio, p50/p95 | 1,1 / 1,9 ms | 0,6 / 0,8 ms | **0,8 / 1,2 ms** |
| Due termini (AND), p50/p95 | 0,6 / 1,2 ms | 0,5 / 1,0 ms | **1,0 / 2,0 ms** |
| Frase, p50/p95 | 3,9 / 58,0 ms | 2,9 / 45,4 ms | **3,9 / 46,5 ms** |
| Prefisso di 3 lettere, p50/p95 | 14,1 / 75,8 ms | 6,0 / 34,1 ms | **7,0 / 37,9 ms** |
| Senza accenti, p50/p95 | 0,7 / 1,2 ms | 0,4 / 0,7 ms | **0,6 / 1,0 ms** |
| Nomi (trigram), p50/p95 | 0,4 / 1,1 ms | 0,1 / 0,1 ms | **0,4 / 1,9 ms** |

- **Costo della cifratura** (con chiave rispetto a senza, stesso motore): circa −27% sugli inserimenti, +67% sugli aggiornamenti, +6% di spazio, query più lente ma sempre sotto 50 ms al 95° percentile.
- **Rispetto all'SQLite di sistema**, SQLCipher con chiave è pari o più veloce in lettura, perché usa un motore più recente.
- **Passphrase:** 98,5 ms per aprire e 197 ms per la riapertura con prima query (PBKDF2 per ogni connessione). La chiave grezza evita questo costo ed è la scelta implementata.
- **Verifiche di sicurezza, tutte superate:** intestazione non in chiaro; database illeggibile senza chiave e con una chiave sbagliata; backup cifrato con lo stesso numero di righe. Il backup di 310 MB richiede 1,5 s.
- **Budget di MOS-ARCH-001 §6.4:** full-text sotto 250 ms al 95° percentile, rispettato con ampio margine. La scrittura nel database non sarà il collo di bottiglia dell'indicizzazione.

## Integrazione

- **Compilazione.** SwiftPM compila senza problemi. La prima build scarica un artefatto da 50,5 MB (xcframework per tutte le piattaforme; nell'app finisce solo la parte macOS).
- **Motore.** FTS5 è attivo, il provider crittografico è CommonCrypto, la pagina cifrata è di 4.096 byte, `cipher_memory_security` è disattivato.
- **SQLCipher è un framework dinamico.** Xcode lo incorpora e lo firma automaticamente. Con l'Hardened Runtime, però, la verifica delle librerie richiede che app e framework abbiano lo stesso Team ID. Con la firma ad hoc non esiste Team ID, quindi l'app non si avvia ("mapping process and mapped file (non-platform) have different Team IDs"). Per questo Xcode non applica l'Hardened Runtime alle build ad hoc.
- **App reale** (build ad hoc senza Hardened Runtime): `core.db` creato cifrato, chiave nel Portachiavi, cartella `0700`, file `0600`, memoria 30 MB.
- **Test di `MosaicStorage`, 9 su 9 superati:** backup cifrato prima delle migrazioni, rifiuto della chiave sbagliata o mancante senza ripiego in chiaro, permessi dei file.
- **Licenza:** SQLCipher Community Edition è BSD-style e richiede l'attribuzione e la riproduzione della licenza nella documentazione dell'app.

## Conseguenze

- **ADR-006 passa ad *Accettata*:** la condizione posta da D7 è soddisfatta.
- Per le build con Hardened Runtime (Apple Development o Developer ID) serve una firma di team: è il tema di S8.
- Il manifesto sostitutivo di GRDB va riallineato a ogni aggiornamento di GRDB. Lo script verifica il commit.
- Alternativa, da valutare solo se il framework dinamico diventasse un problema: compilare SQLCipher dai sorgenti come libreria statica.

## Limiti

Corpus sintetico, un'esecuzione per modalità, cache calda. Le misure su dati reali arriveranno con l'indicizzazione di M2–M3.
