# MOS-M0-001 — Rapporto di fine M0

| Campo | Valore |
| --- | --- |
| Milestone | M0, fondamenta e spike |
| Stato | **Pronto per la revisione.** Unico punto non verificato: il test 3 di S2 (file dataless), rimandato su decisione dell'utente; non blocca la raccomandazione |
| Data | 2026-10-01 |
| Regola | Alla fine di M0 ci si ferma: M1 parte solo dopo la revisione e l'approvazione di questo rapporto |

## Fondamenta consegnate

| Elemento | Stato |
| --- | --- |
| Progetto Xcode da `project.yml` (XcodeGen) e script `bootstrap.sh`, `test.sh`, `build-app.sh` | Fatto |
| `MosaicCore`: UUIDv7, errori per causa, livelli di rischio, permessi, EventBus, `CommandRegistry` con parametri tipizzati e guard, Portachiavi | Fatto, 16 test |
| `MosaicStorage`: SQLCipher, chiavi nel Portachiavi, migrazioni versionate, backup cifrato prima delle migrazioni, permessi `0600`, schema v1 di `core.db` | Fatto, 9 test |
| `MosaicPlatform`: JobScheduler con code P0–P3, pausa, annullamento, arresto completo | Fatto, 6 test (8 casi) |
| App residente in menu bar: la finestra si chiude senza uscire, avvio al login opzionale, uscita che ferma tutto | Fatto; build verificata con database cifrato reale, 30 MB a riposo |
| Firma stabile (Apple Development) | Fatto; Team ID `HQJWK6BU8M`, Full Disk Access verificato sopravvivere a una rebuild (S8) |

## 1. Esiti degli spike

| Spike | Esito | Rapporto |
| --- | --- | --- |
| S1, SQLCipher con GRDB | **GO** | [S1](../spikes/S1-sqlcipher.md) |
| S2, XPC, TCC, sandbox, dataless | **GO** per XPC/sandbox (eredità FDA, isolamento della sandbox verificati); test del file dataless rimandato, non eseguito | — |
| S3, scansione e FSEvents | **GO** | [S3](../spikes/S3-crawl-fsevents.md) |
| S4, tastiere | **GO** | [S4](../spikes/S4-keyboard.md) |
| S5, posta | Thunderbird **GO** su fixture; Apple Mail **GO** | [S5](../spikes/S5-mail.md) |
| S6, embedding | **Rosa ristretta**; candidato predefinito granite-embedding-278m | [S6](../spikes/S6-embeddings.md) |
| S7, Foundation Models | **GO con revisione del design** | [S7](../spikes/S7-foundation-models.md) |
| S8, firma e permessi dopo le rebuild | **GO** | [S8](../spikes/S8-signing-permissions.md) |
| S9, versione minima di macOS | Raccomandazione **macOS 15** | [S9](../spikes/S9-deployment-target.md) |

## 2. ADR dopo M0 (provvisorio)

| ADR | Stato dopo M0 | Motivo |
| --- | --- | --- |
| ADR-006, cifratura a riposo | **Accettata** | S1: condizione di D7 soddisfatta |
| ADR-003, processo residente con servizi XPC | Accettata per il ciclo di vita e per XPC/sandbox; test del file dataless ancora da fare | S2 |
| ADR-012, Keyboard Manager | **Accettata**: 0 errori su 25 pressioni, latenza di switch 38–46 ms; nota di design su R47 da portare in M9 | S4 |
| ADR-009, posta dai client locali | **Accettata**: Thunderbird confermato su fixture, Apple Mail confermato su dati reali (236.041 messaggi) | S5 |
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
- **Apple Mail:** **GO** su dati reali. 236.041 messaggi, 73 mailbox (26 con messaggi), 300/300 campioni ben formati, schema letto con successo (versione V10), Envelope Index da 970 MB in circa 36 s di scansione a freddo.

## 6. Keyboard Manager

**GO.** Rilevamento HID corretto su due tastiere esterne fisicamente diverse (Logitech, casa e ufficio); switch automatico del layout per dispositivo con latenza mediana 37,9 ms (massima 45,7 ms) e **0 errori su 25 pressioni misurate**. Durante la prova è emerso un conflitto reale con la memoria per-documento di macOS (TSM, opzione "Automatically switch to document's input source", attiva di default): con quell'opzione attiva il layout seguiva il documento invece della tastiera collegata. Disattivandola il conflitto scompare (registrato come R47 in MOS-RISK-001, ora a probabilità bassa). Resta da decidere in M9 se Mosaic debba gestire quell'opzione in automatico, con consenso dell'utente. Dettagli in [S4](../spikes/S4-keyboard.md).

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
7. **Test 3 di S2 (file dataless) non eseguito**, su scelta dell'utente. Candidati identificati sul disco reale (file su Google Drive con 0 blocchi allocati, quindi dataless) ma non selezionati nel picker di Mosaic Probe. Non blocca M0: XPC/TCC/sandbox sono comunque verificati dagli altri due test di S2. Da eseguire prima di dichiarare ADR-003 pienamente accettata.

## 9. Rischi aggiornati (provvisorio)

| Rischio | Variazione |
| --- | --- |
| R16, integrazione GRDB e SQLCipher | Chiuso da S1 |
| R18, Foundation Models | Confermato e aggravato: latenza e qualità documentate in S7 |
| R1, firma | **Ridotto da S8**: Full Disk Access sopravvive alla rebuild con Team ID fisso; resta da verificare con Developer ID e notarizzazione |
| R42, versione minima | Ridotto da S9 |
| R17, qualità e licenze degli embedding | Ridotto da S6 per la qualità; resta aperto il runtime Core ML |
| R6, cambio di layout e conflitto con l'input source per documento | Chiuso da S4: switch per-dispositivo verificato (0 errori su 25 pressioni), conflitto confermato e mitigato (vedi R47) |
| R8, tastiere identiche senza numero di serie | Confermato da S4: entrambe le tastiere Logitech testate risultano senza serial number; resta un limite dichiarato, non un blocco |
| Nuovo | Xcode 27 su macOS 26.6.2 segnala plugin CoreDevice e CoreSimulator non allineati: nessun effetto sulle build per macOS |
| **R47 (nuovo)**, conflitto tra input source per-dispositivo (ADR-012) e memoria per-documento di TSM in Pages/TextEdit | Causa confermata e mitigata (disattivazione dell'opzione di sistema); nota di design per M9 |

## 10. Raccomandazione su M1

**Si raccomanda di procedere a M1**, con queste condizioni:

- **Nessun risultato bloccante.** Tutti gli spike hanno un esito, 8 su 9 con verifica interattiva completa; l'unico punto non chiuso (S2, test 3) non mette in discussione la fattibilità già dimostrata da XPC/sandbox negli altri due test, ma va eseguito prima di dichiarare ADR-003 pienamente accettata — può avvenire anche a inizio M1, senza bloccarlo.
- **Decisioni che restano da prendere esplicitamente**, elencate per chiarezza:
  1. approvare **macOS 15** come versione minima (ADR-016), dopo una prova in VM che resta da fare;
  2. confermare il **bundle identifier definitivo** (oggi `it.mosaic.app`, provvisorio);
  3. prendere atto dei 7 scostamenti elencati al punto 8, in particolare il `SearchIntent` a due stadi e la fusione ibrida pesata, che toccano ADR-005 e ADR-015;
  4. prendere atto del nuovo rischio R47 (conflitto tastiera/documento) come nota di design per M9, non per M1.
- **Area con il margine di incertezza maggiore:** gli embedding (S6) restano "rosa ristretta", non scelta definitiva — la decisione si sposta a M3 come già pianificato, non blocca l'inizio di M1.
- **Area con l'esito più debole in assoluto:** Foundation Models (S7), con latenze che possono arrivare a 93–425 secondi in alcuni blocchi; la revisione di design (parser deterministico come primo stadio) è già incorporata nell'architettura e considerata sufficiente per procedere, ma resta da validare su più hardware in M9.

In sintesi: le fondamenta (pacchetti, storage cifrato, app residente, firma stabile) sono solide e verificate; i rischi principali del progetto (cifratura, scansione, posta, tastiera, firma) sono stati ridotti o chiusi da misure reali, non da supposizioni. Si può passare a M1.
