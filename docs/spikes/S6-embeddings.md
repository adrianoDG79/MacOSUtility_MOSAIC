# S6 — Modelli di embedding

| Campo | Valore |
| --- | --- |
| Obiettivo | Scegliere il modello di embedding per la ricerca semantica in italiano e inglese (MOS-AI-001 §7) |
| Esito | **Rosa ristretta a tre modelli multilingue**, con granite-embedding-278m come candidato predefinito. La scelta finale va fatta in M3, dopo la misura sul runtime definitivo e sulle tue query reali |
| Codice | `Spikes/S6-Embeddings/`: estrazione, generazione delle query, valutazione. I dati restano in `.data/`, non versionata |

## Metodo

- **Corpus:** 300 documenti di lavoro PDF e DOCX dal Desktop, esclusa la cartella `Codice`: 150 in italiano e 150 in inglese, deduplicati in base all'inizio del testo, ciascuno in due blocchi da 1.000 caratteri (551 passaggi).
- **Query:** per 190 documenti (67 italiani, 123 inglesi), una query in italiano e una in inglese scritte da `qwen2.5:7b` in locale, chiedendo di descrivere l'argomento senza copiare frasi, codici o nomi di file. Sono 380 query di 4,3 parole in media: 190 nella lingua del documento e 190 nell'altra.
- **Valutazione per documento noto:** l'unico risultato giusto è il documento da cui la query è stata scritta. Metriche: R@1, R@10 e MRR@10. Il punteggio di un documento è quello del suo blocco migliore.
- **Modelli via Ollama**, con i prefissi consigliati da ciascuno; `NLContextualEmbedding` di Apple con mean pooling; BM25 con FTS5; ibrido RRF (k = 60).
- Tutto in locale: nessun testo è uscito dal Mac.

## Risultati

| Modello | Parametri | Dim. | Licenza | R@1 | R@10 | MRR | MRR query IT | MRR query EN | MRR tra lingue | Passaggi/s |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| BM25 (FTS5) | — | — | — | 0,487 | 0,718 | 0,560 | 0,523 | 0,596 | 0,362 | — |
| **bge-m3** | 568M | 1024 | MIT | **0,621** | 0,921 | **0,708** | **0,712** | 0,704 | **0,692** | 2,9 |
| embeddinggemma | 308M | 768 | Gemma Terms of Use | 0,616 | 0,892 | 0,695 | 0,655 | **0,735** | 0,654 | 7,3 |
| qwen3-embedding-0.6b | 596M | 1024 | Apache-2.0 | 0,592 | 0,895 | 0,681 | 0,649 | 0,714 | 0,659 | 4,7 |
| **granite-embedding-278m** | 278M | 768 | Apache-2.0 | 0,574 | 0,889 | 0,664 | 0,647 | 0,681 | 0,645 | **35,2** |
| nomic-embed-text v1.5 | 137M | 768 | Apache-2.0 | 0,450 | 0,700 | 0,518 | 0,455 | 0,581 | 0,341 | 24,2 |
| NLContextualEmbedding (Apple) | sistema | 512 | API di sistema | 0,066 | 0,192 | 0,100 | 0,069 | 0,130 | 0,022 | 16,8 |
| Ibrido RRF (BM25 + bge-m3) | — | — | — | 0,550 | **0,924** | 0,658 | 0,652 | 0,665 | 0,556 | — |

La velocità è misurata con Ollama sulla GPU, con un altro modello residente in memoria. Serve solo a confrontare i modelli tra loro, non rappresenta il runtime finale.

## Interpretazione

- **I modelli multilingue superano nettamente BM25:** MRR da 0,66 a 0,71 contro 0,56. Tra lingue diverse la differenza è di quasi il doppio (0,65–0,69 contro 0,36). Conferma il valore della ricerca semantica per un corpus misto italiano e inglese.
- **Esclusi:**
  - `NLContextualEmbedding`, perché con il semplice mean pooling non è adatto al retrieval (MRR 0,10);
  - nomic-embed-text v1.5, perché solo inglese (0,34 tra lingue).
- **Qualità:** bge-m3 è il migliore, ma è anche il più pesante e il più lento. embeddinggemma arriva al 98% della sua qualità, con una licenza che aggiunge vincoli d'uso. granite-embedding-278m arriva al 94%, è 12 volte più veloce in questa misura e ha una licenza Apache-2.0.
- **RRF a pesi uguali peggiora le prime posizioni** rispetto al solo bge-m3 (MRR 0,658 contro 0,708), pur migliorando R@10. Con query brevi e spesso in un'altra lingua, BM25 aggiunge rumore. Serve una **fusione pesata**, tarata sulle query reali, invece di RRF a pesi uguali.

## Conseguenze

- **Candidato predefinito:** granite-embedding-278m (qualità alta, veloce, licenza senza vincoli).
- **Alternative:** embeddinggemma (supporta anche la riduzione delle dimensioni a 128–512) e bge-m3 (massima qualità).
- **In M3:**
  - convertire i candidati in Core ML e misurarne velocità ed energia sul Neural Engine, con MLX come ripiego;
  - costruire il set di circa 50 query reali tue, con i documenti attesi, e rifare il confronto;
  - tarare i pesi della fusione ibrida.
- **ADR-007 regge:** 100.000 blocchi a 768 dimensioni in int8 occupano circa 77 MB; la ricerca esatta resta adeguata.

## Limiti

- **Le query sono parafrasi generate da un modello** che evita di copiare il testo: favoriscono i modelli semantici e penalizzano BM25. Le query reali sono spesso più ricche di parole chiave.
- **Il campione di query è sbilanciato** (67 documenti italiani su 190), perché la generazione è stata interrotta a 190 documenti su 300 per tempo; tutti e 300 i documenti sono comunque rimasti nel corpus come distrattori.
- **La velocità non è quella del runtime finale.**
