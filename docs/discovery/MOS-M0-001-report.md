# MOS-M0-001 — Rapporto di fine M0

| Campo | Valore |
| --- | --- |
| Milestone | M0, fondamenta e spike |
| Stato | **Bozza**: gli spike autonomi sono conclusi; mancano quelli interattivi (S2, S4, S8 e la parte Apple Mail di S5) |
| Data | 2026-09-29 |
| Regola | Alla fine di M0 ci si ferma: M1 parte solo dopo la revisione e l'approvazione di questo rapporto |

## Fondamenta consegnate

| Elemento | Stato |
| --- | --- |
| Progetto Xcode da `project.yml` (XcodeGen) e script `bootstrap.sh`, `test.sh`, `build-app.sh` | Fatto |
| `MosaicCore`: UUIDv7, errori per causa, livelli di rischio, permessi, EventBus, `CommandRegistry` con parametri tipizzati e guard, Portachiavi | Fatto, 16 test |
| `MosaicStorage`: SQLCipher, chiavi nel Portachiavi, migrazioni versionate, backup cifrato prima delle migrazioni, permessi `0600`, schema v1 di `core.db` | Fatto, 9 test |
| `MosaicPlatform`: JobScheduler con code P0–P3, pausa, annullamento, arresto completo | Fatto, 6 test (8 casi) |
| App residente in menu bar: la finestra si chiude senza uscire, avvio al login opzionale, uscita che ferma tutto | Fatto; build verificata con database cifrato reale, 30 MB a riposo |
| Firma stabile (Apple Development) | **In attesa del certificato** |

## 1. Esiti degli spike

| Spike | Esito | Rapporto |
| --- | --- | --- |
| S1, SQLCipher con GRDB | **GO** | [S1](../spikes/S1-sqlcipher.md) |
| S2, XPC, TCC, sandbox, dataless | In attesa (Mosaic Probe) | — |
| S3, scansione e FSEvents | **GO** | [S3](../spikes/S3-crawl-fsevents.md) |
| S4, tastiere | In attesa (Mosaic Probe e tastiera esterna) | — |
| S5, posta | Thunderbird **GO** su fixture; Apple Mail in attesa | [S5](../spikes/S5-mail.md) |
| S6, embedding | **Rosa ristretta**; candidato predefinito granite-embedding-278m | [S6](../spikes/S6-embeddings.md) |
| S7, Foundation Models | **GO con revisione del design** | [S7](../spikes/S7-foundation-models.md) |
| S8, firma e permessi dopo le rebuild | In attesa del certificato | — |
| S9, versione minima di macOS | Raccomandazione **macOS 15** | [S9](../spikes/S9-deployment-target.md) |

## 2. ADR dopo M0 (provvisorio)

| ADR | Stato dopo M0 | Motivo |
| --- | --- | --- |
| ADR-006, cifratura a riposo | **Accettata** | S1: condizione di D7 soddisfatta |
| ADR-003, processo residente con servizi XPC | Accettata per il ciclo di vita; topologia XPC in attesa | S2 |
| ADR-012, Keyboard Manager | In attesa delle misure | S4 |
| ADR-009, posta dai client locali | Thunderbird confermato su fixture; Apple Mail in attesa | S5 |
| ADR-016, versione minima di macOS | Proposta di risoluzione: macOS 15 | S9, da approvare |
| ADR-005, ricerca, e ADR-015, substrato | Revisione proposta: `SearchIntent` a due stadi e fusione ibrida pesata | S7 e S6 (scostamenti 1 e 5) |
| ADR-007, vettori | Accettata: 100.000 blocchi a 768 dimensioni in int8 occupano circa 77 MB, la ricerca esatta resta adeguata | S6 |

## 3. Benchmark principali

| Misura | Valore | Budget |
| --- | --- | --- |
| Query full-text, p95, cifrate, 100.000 blocchi | ≤ 47 ms | 250 ms |
| Nomi (trigram), p95, 300.000 file | 1,9 ms | 50 ms |
| Inserimento cifrato | 11.300 blocchi al secondo | — |
| Apertura del database cifrato (chiave grezza) | 1,9 ms | — |
| Scansione dei metadati, `~/Desktop` (510.000 file) | 6,8 s a caldo | — |
| Ripresa di FSEvents dopo un'uscita | 175 ms, nessuna modifica persa | — |
| App a riposo | 30 MB | 150 MB |
| Foundation Models, query strutturata | 2,3–2,5 s a regime, con blocchi fino a 93 s | Fuori dal percorso interattivo |
| Ricerca semantica, MRR@10 (380 query, 300 documenti) | bge-m3 0,708 · granite-278m 0,664 · BM25 0,560 | — |
| Ricerca tra italiano e inglese, MRR@10 | Modelli multilingue 0,65–0,69 · BM25 0,36 | — |

## 4. Versione minima di macOS

Raccomandazione: **macOS 15**, solo Apple Silicon, con rilevamento a runtime delle capacità di macOS 26 e 27. Il core non richiede più di macOS 14. Il dettaglio delle funzioni perse per ogni versione candidata è in [S9](../spikes/S9-deployment-target.md). Prima di fissarla serve una prova di esecuzione in una macchina virtuale macOS 15.

## 5. Fattibilità della posta

- **Thunderbird:** GO su fixture. Profili, mbox, eliminati non compattati, cartelle, Gloda e diagnostica "rilevati rispetto a indicizzati" funzionano (5 test su 5). Manca la validazione su un profilo reale (R43).
- **Apple Mail:** in attesa della prova con Mosaic Probe.

## 6. Keyboard Manager

In attesa della prova S4 con Mosaic Probe. Già noto: il cambio automatico per documento è attivo su questo Mac.

## 7. Modelli di embedding

- I modelli multilingue superano nettamente la sola ricerca lessicale: MRR 0,66–0,71 contro 0,56, e quasi il doppio tra lingue diverse.
- **Esclusi:** `NLContextualEmbedding` di Apple (MRR 0,10 con mean pooling) e i modelli solo inglesi.
- **Rosa:** granite-embedding-278m (candidato predefinito: 94% della qualità migliore, 12 volte più veloce, Apache-2.0), embeddinggemma (98%, licenza Gemma) e bge-m3 (il migliore, il più lento).
- **Scelta finale in M3**, dopo la conversione in Core ML, la misura sul Neural Engine e il confronto su circa 50 query reali tue. Dettagli in [S6](../spikes/S6-embeddings.md).

## 8. Scostamenti dall'architettura approvata

1. **`SearchIntent` a due stadi** (S7). Il parser deterministico diventa il primo stadio; Foundation Models serve solo come arricchimento asincrono, verificato contro il testo della query; le date si calcolano sempre nel codice. Il modello resta nel substrato dell'Assistant, ma non sul percorso interattivo.
2. **Hardened Runtime solo con firma di team** (S1). SQLCipher è un framework dinamico: con l'Hardened Runtime la verifica delle librerie richiede lo stesso Team ID per app e framework. Le build ad hoc girano senza Hardened Runtime; quelle con Apple Development o Developer ID lo hanno.
3. **Dettagli di implementazione**, nell'autonomia tecnica del §71:
   - `SecretsStore` è in `MosaicCore`, per evitare una dipendenza circolare tra storage e piattaforma;
   - le dipendenze si compongono in modo esplicito, senza un container generico;
   - GRDB ha un manifesto sostitutivo, da riallineare a ogni aggiornamento.
4. **Bundle identifier provvisorio `it.mosaic.app`.** Va confermato prima di M1, perché permessi e Portachiavi vi resteranno legati.
5. **Fusione ibrida pesata** (S6). RRF a pesi uguali ha peggiorato le prime posizioni rispetto al solo modello semantico (MRR 0,658 contro 0,708): i pesi vanno tarati sulle query reali in M3.
6. **Runtime degli embedding ancora da validare.** In M0 i modelli girano via Ollama; la conversione in Core ML, prevista dall'architettura, è pianificata in M3, con MLX come ripiego.

## 9. Rischi aggiornati (provvisorio)

| Rischio | Variazione |
| --- | --- |
| R16, integrazione GRDB e SQLCipher | Chiuso da S1 |
| R18, Foundation Models | Confermato e aggravato: latenza e qualità documentate in S7 |
| R1, firma | Ancora aperto; si aggiunge il vincolo sulla verifica delle librerie |
| R42, versione minima | Ridotto da S9 |
| R17, qualità e licenze degli embedding | Ridotto da S6 per la qualità; resta aperto il runtime Core ML |
| Nuovo | Xcode 27 su macOS 26.6.2 segnala plugin CoreDevice e CoreSimulator non allineati: nessun effetto sulle build per macOS |

## 10. Raccomandazione su M1

Da formulare dopo gli spike interattivi. Stato attuale: nessun risultato bloccante, fondamenta pronte.
