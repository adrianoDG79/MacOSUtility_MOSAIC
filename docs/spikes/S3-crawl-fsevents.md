# S3 — Scansione di massa e ripresa di FSEvents

| Campo | Valore |
| --- | --- |
| Obiettivo | Misurare la scansione dei metadati (`getattrlistbulk` rispetto a `FileManager`) e verificare che FSEvents consegni le modifiche avvenute mentre Mosaic era chiusa (D2) |
| Esito | **GO** |
| Codice | `Spikes/S3-Crawl/` (l'output contiene solo conteggi aggregati) |

## Metodo

- **Stesse regole di MOS-SRCH-001 §3 per entrambi i metodi:** esclusioni `node_modules`, `.git`, `.build`, `DerivedData`, `.venv` e simili; pacchetti trattati come un solo elemento.
- **Policy dataless disattivata** (`IOPOL_MATERIALIZE_DATALESS_FILES_OFF`) per tutto il processo.
- **Due alberi:** uno sintetico da 300.000 file (100 × 30 cartelle × 100 file) e `~/Desktop` reale.
- **Ripresa di FSEvents:** si salva l'event ID corrente e, senza alcuno stream attivo, si creano 2.000 file, se ne modificano 200, se ne rinominano 100, se ne cancellano 100 e si aggiungono 50 file in una sottocartella. Poi si riapre uno stream dall'ID salvato.

## Risultati

| Albero | Metodo | 1° passaggio | 2° passaggio (cache calda) | Memoria |
| --- | --- | --- | --- | --- |
| Sintetico, 300.000 file | `getattrlistbulk` | 1,00 s (303.000/s) | **0,51 s (599.000/s)** | 6–9 MB |
| Sintetico, 300.000 file | `FileManager` | 2,30 s (132.000/s) | 2,23 s (136.000/s) | 9–10 MB |
| `~/Desktop`: 510.692 file, 13.564 cartelle, 166 GB | `getattrlistbulk` | 10,4 s (50.000/s) | **6,8 s (77.000/s)** | 7–13 MB |
| `~/Desktop` | `FileManager` | 10,2 s (52.000/s) | 10,3 s (51.000/s) | 12–16 MB |

- `getattrlistbulk` è da 2,3 a 4,4 volte più veloce sull'albero sintetico e fino a 1,5 volte sui dati reali, dove pesa di più l'I/O.
- Nessun errore di permesso e nessun file dataless sul Desktop. Tra i due metodi ci sono 34 file di differenza su 510.692, da chiarire in M2.
- Proiezione: una home da un milione di elementi richiede 15–20 s di scansione dei metadati. Il budget era di 20 minuti.

**Ripresa di FSEvents.** Tutte le modifiche sono state riportate: creazioni 2.000 su 2.000, modifiche 200 su 200, rinomine 100 su 100, cancellazioni 100 su 100, file nella nuova sottocartella 50 su 50. La cronologia si completa (`HistoryDone`) in **175 ms**, senza eventi `MustScanSubDirs`.

## Conseguenze

- Il crawler di M2 usa `getattrlistbulk`, con `FileManager` come ripiego per i casi particolari.
- La scelta di D2 (uscire da Mosaic ferma tutto, al rilancio si recupera via FSEvents) è confermata.
- La policy dataless a livello di processo non ha costi misurabili sulla scansione.

## Limiti

La cache fredda non è controllabile senza privilegi di amministratore (`purge`). I volumi di rete e i provider cloud non fanno parte di questo spike: il comportamento sui file dataless reali è coperto da S2.
