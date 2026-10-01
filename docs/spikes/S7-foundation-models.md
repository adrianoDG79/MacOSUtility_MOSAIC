# S7 — Foundation Models per la ricerca in linguaggio naturale

| Campo | Valore |
| --- | --- |
| Obiettivo | Disponibilità del modello on-device, qualità nell'estrarre un `SearchIntent`, latenza |
| Esito | **GO con revisione del design**: il modello è utile come arricchimento asincrono e verificato, non come primo stadio della ricerca |
| Codice | `Spikes/S7-FoundationModels/` |

## Metodo

- `SystemLanguageModel.default` su macOS 26.6.2, con uno strumento a riga di comando.
- `SearchIntentDraft` con generazione guidata (`@Generable`), 10 campi: tipi, obiettivo, persone, argomento, luogo, campo data, inizio, fine, dimensione minima, allegati.
- 24 query reali per stile, 12 in inglese e 12 in italiano, compresi gli esempi del master prompt. "Adesso" è martedì 29 settembre 2026 alle 20:00, e le istruzioni lo dicono al modello.
- Ogni campo atteso viene confrontato con il risultato; le date sono accettate con uno scarto di ±1 giorno.

## Risultati

| Misura | Valore |
| --- | --- |
| Disponibilità | `available` (Apple Intelligence attiva) |
| Italiano supportato | Sì |
| Contesto | 4.096 token (`contextSize`, disponibile da macOS 26.4) |
| Query interpretate esattamente | 13 su 24 (54%); secondo run su 8 query: 5 su 8 |
| Accuratezza sui campi attesi | 81% (secondo run: 86%) |
| Latenza, primo run | mediana 22,7 s, massimo 425,7 s |
| Latenza, secondo run a sistema fermo | **2,3–2,5 s a regime**, con blocchi di 12,6, 54 e 93 s |

**Errori sistematici, non colti dall'accuratezza sui campi attesi:**

- **Date relative con l'anno sbagliato:** "yesterday" diventa 2025-09-28, "in August" diventa agosto 2025, "around March" diventa marzo 2023.
- **Campi inventati:** parole che non sono persone messe tra le persone ("you", "NUSES", "NAS", "screenshot", "fatture", "Terzina") in circa 10 query su 24; il luogo "Desktop" aggiunto senza che fosse citato in circa 12 su 24; filtri di data aggiunti a query senza espressioni temporali; "con allegati" attivato senza richiesta.
- **Tipi** a volte riempiti con tutti i valori possibili.

## Interpretazione

- **Il modello capisce l'obiettivo** (trovare, versioni, duplicati, organizzare, cancellare) e i filtri espliciti (tipo, dimensione, luogo nominato, persona reale).
- **Non è affidabile nell'aritmetica delle date** e tende a riempire i campi opzionali.
- **La latenza a regime di circa 2,4 s** per un output strutturato è incompatibile con il percorso interattivo: i primi risultati devono arrivare entro 50–250 ms.
- **I blocchi imprevedibili** fanno pensare a una limitazione da parte del sistema per i processi che non sono in primo piano. Va verificato dentro un'app in primo piano (M3).

## Conseguenze: revisione del `SearchIntent` (scostamento proposto, vedi rapporto di M0)

1. **Primo stadio deterministico:** sintassi esplicita, espressioni di data in italiano e inglese risolte nel codice, dimensioni, tipi riconosciuti da parole chiave ed estensioni, persone solo se corrispondono a contatti o mittenti noti.
2. **La ricerca parte subito** sulla query grezza, lessicale e semantica, senza aspettare il modello.
3. **Arricchimento asincrono** con Foundation Models solo per frasi lunghe o domande, con timeout (3 s) e annullamento al tasto successivo.
4. **Verifica contro il testo:** si accettano persone e luoghi solo se compaiono nella query; nessun filtro di data se il parser non ha trovato un'espressione temporale; le date le calcola sempre il codice.
5. **Chip con l'origine** (regola o modello), sempre modificabili.
6. **Nessuna dipendenza dal throughput del modello per il lavoro in background:** la classificazione dell'Organizer si basa su regole ed embedding, e Foundation Models interviene solo su richiesta.

## Da riverificare

- Latenza dentro un'app in primo piano (M3).
- Il nuovo modello da 8.192 token e il Private Cloud Compute di macOS 27, che potrebbero cambiare qualità e latenza.
