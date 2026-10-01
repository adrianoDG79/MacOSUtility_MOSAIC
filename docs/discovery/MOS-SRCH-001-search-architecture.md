# MOS-SRCH-001 — Search & Indexing Architecture

| Campo | Valore |
| --- | --- |
| Copre | Master prompt §72 F; §8–§12, §53–§54, §61 |
| Stato | Proposta |

## 1. Obiettivi

- Risultati istantanei per nomi, app e comandi; risultati full-text e semantici che arrivano progressivamente, senza bloccare l'interfaccia (§61).
- Un indice Mosaic affidabile e sotto controllo, con Spotlight come acceleratore e non come dipendenza (§10).
- Ricerca in italiano e inglese che tollera accenti, errori di battitura e l'assenza delle parole esatte (§9.4).
- Nessun download di file cloud per indicizzarli (D8).
- Stato dell'indice sempre visibile e riparabile in modo selettivo (§53).

## 2. Visione d'insieme

```text
          Query ──► QueryParser ──► (linguaggio naturale?) ──► SearchIntent (Foundation Models, generazione guidata)
                        │                                          │
                        ▼                                          ▼
   ┌────────────── provider in parallelo, ciascuno con budget e cancellazione ──────────────┐
   │ Comandi │ App │ Nomi (FTS5 trigram) │ Spotlight │ Full-text (FTS5) │ Semantico         │
   │ Mail (metadati e corpo) │ Contatti │ Calendario │ (F2: Appunti, Progetti, Sessioni)     │
   └──────────────────────────────────────────┬─────────────────────────────────────────────┘
                                              ▼
                  Ranker: fusione (RRF), segnali, raggruppamento, ordine stabile
                                              ▼
                  Pannello: sezioni per tipo, anteprima, azioni, filtri
```

## 3. Livelli di indicizzazione per sorgente (§11)

| Livello | Cosa si indicizza | Costo |
| --- | --- | --- |
| 1, nome e metadati | Nome, percorso, estensione, tipo, date, dimensione, tag, provenienza del download, ultimo utilizzo | Basso |
| 2, full text | Tutto il livello 1, più il testo estratto dai formati supportati; OCR se attivato per la sorgente | Medio |
| 3, semantico | Tutto il livello 2, più gli embedding dei blocchi di testo | Alto, governato dal Resource Manager |

Default proposti: Download, Scrivania e Documenti al livello 3; cartelle di progetto al livello 2 (3 su richiesta); volumi esterni e NAS al livello 1; cloud al livello 1 per i file solo online, 2 o 3 per quelli scaricati.

Esclusioni predefinite, modificabili: `node_modules`, `.git`, cartelle di build, `DerivedData`, cache, bundle delle app, `~/Library` (salvo sorgenti esplicite).

## 4. Pipeline

1. **Scoperta.** Scansione iniziale a bassa priorità (P3) con lettura dei metadati in blocco. Nel frattempo Spotlight fornisce subito risultati per le sorgenti non ancora pronte.
2. **Aggiornamento.** FSEvents per singolo file, con riproduzione dall'ultimo event ID. Le rinomine si riconoscono dall'identificativo del file. Sui volumi di rete si usano scansioni periodiche.
3. **Arricchimento.** Attributi Spotlight (`kMDItemLastUsedDate`, `kMDItemWhereFroms`, `kMDItemUserTags`, `kMDItemAuthors`, `kMDItemNumberOfPages`) e attributo di quarantena (app che ha scaricato il file, data).
4. **Estrazione** (livello 2 o superiore). L'app apre il file con la policy *dataless* disattivata e passa il descrittore all'estrattore XPC. Dimensione, numero di pagine e tempo hanno limiti configurabili. Un PDF protetto da password viene marcato come "protetto", non come errore.
5. **OCR**, opzionale per sorgente. Le pagine PDF senza strato di testo e le immagini (screenshot, scansioni, ricevute) passano a Vision `RecognizeDocumentsRequest`, con italiano e inglese. Il testo entra nell'indice marcato come OCR, con la sua confidenza (§12).
6. **Normalizzazione.** Unicode NFC, spazi, sillabazione a fine riga nei PDF, riconoscimento della lingua con `NLLanguageRecognizer`.
7. **Divisione in blocchi.** Per paragrafi e pagine, circa 1.000 caratteri con una sovrapposizione del 10–15%. Ogni blocco conserva pagina e offset, per anteprima ed evidenziazione.
8. **Embedding** (livello 3). Si usa il modello scelto nello spike S6, a lotti, nel servizio `MosaicML.xpc`, al ritmo deciso dal Resource Manager.

## 5. Ruolo di Spotlight

| Uso | Dettaglio |
| --- | --- |
| Risultati immediati | Prima che la scansione di Mosaic sia completa, limitati alle sorgenti abilitate |
| Formati non estraibili | Pages, Numbers, Keynote: `kMDItemTextContent` si può interrogare anche se il testo non è leggibile |
| Metadati | Ultimo utilizzo, provenienza, tag, autori, pagine |
| Diagnostica | Confronto tra la copertura di Mosaic e quella di Spotlight per sorgente; stato di `mdutil` per volume (voce "Spotlight dependency" dell'Health Check, §52) |

Se Spotlight è disattivato o incompleto, Mosaic continua a funzionare con il proprio indice.

## 6. Full-text

- FTS5 con il tokenizer `unicode61 remove_diacritics 2` ("perché" trova "perche"), indici di prefisso a 2 e 3 caratteri per la ricerca mentre si digita, e ranking `bm25()` con pesi per campo: titolo o oggetto più del corpo, corpo più dell'OCR.
- Un indice FTS5 `trigram` separato per nomi e percorsi, che trova sottostringhe e tollera errori prima del punteggio fuzzy.
- Frasi, `NEAR`, operatori e filtri vengono tradotti dal parser; la sintassi SQL non è esposta all'utente.
- FTS5 non ha uno stemmer italiano integrato. In V1 lo compensano i prefissi e la ricerca semantica; più avanti si valuterà un tokenizer con lo stemmer Snowball per l'italiano.
- Snippet ed evidenziazioni sono generati da FTS5 sul testo del blocco.

## 7. Semantico

- **Ricerca ibrida.** La lista BM25 e quella vettoriale si fondono con la Reciprocal Rank Fusion (k = 60). Una query esatta non peggiora, e una query concettuale trova documenti anche senza parole in comune.
- **Vettori.** Salvati come int8 con un fattore di scala in `index.db`. L'indice in memoria si carica alla prima query semantica e si libera dopo un periodo di inattività o sotto pressione di memoria. La ricerca è esatta, con Accelerate: su 300.000 blocchi da 384–768 dimensioni costa decine di millisecondi. Oltre circa un milione di blocchi, o se si esce dal budget, si passa a un indice HNSW (USearch) dietro lo stesso protocollo `VectorIndex` (ADR-007).
- **Filtri prima dei vettori.** Sorgente, tipo, data e (F2) progetto riducono l'insieme dei candidati prima di calcolare la similarità.
- **Versioni del modello.** Ogni vettore è etichettato con `model_id`. Cambiare modello avvia un ricalcolo in background, e nel frattempo la ricerca continua con il modello precedente.

## 8. Comprensione della query

**Sintassi esplicita**, sempre disponibile: `kind:pdf`, `ext:docx`, `size:>100MB`, `modified:<2y`, `opened:yesterday`, `in:Downloads`, `from:marco`, `has:attachment`, virgolette per le frasi, `>` per i comandi.

**Linguaggio naturale.** Se la query sembra una frase ("il PDF su cui lavoravo ieri pomeriggio"), Foundation Models la traduce in un `SearchIntent` tipizzato tramite generazione guidata: tipi di entità, intervallo di tempo, persone, luoghi, parole chiave, testo semantico, ordinamento. L'interpretazione compare sopra i risultati come chip modificabili ("Tipo: PDF · Aperto: ieri 12–18"), così l'utente la vede e la corregge. Senza Apple Intelligence, un parser a regole gestisce le date e i tipi più comuni.

Esempi tratti dal master prompt:

| Query | Interpretazione |
| --- | --- |
| "Show PDFs larger than 100 MB that I haven't opened in two years" | kind=pdf, size>100MB, last_used<now−2y |
| "Find the email Marco sent me around March about the detector tests" | kind=mail, from≈Marco (risolto con i Contatti e i mittenti noti), sent_at nel marzo più recente ± 3 settimane, semantico="detector tests" |
| "Find every version of the NUSES proposal" | gruppi `version`, nome simile a "NUSES proposal", semantico |

## 9. Ranking

| Segnale | Uso |
| --- | --- |
| Qualità della corrispondenza | In ordine decrescente: esatta, prefisso, inizio di parola, fuzzy (sottosequenza con punteggio in stile fzf), trigram, BM25, similarità semantica |
| Recenza | Ultimo utilizzo, ultima modifica |
| Frecency | Selezioni dell'utente in Mosaic, con decadimento esponenziale (sospesa in Private Mode) |
| Luogo | Cartelle dell'utente prima di cartelle di sistema e cache; sorgenti preferite |
| Tipo | Priorità suggerite dalla query ("pdf" nella query, filtri attivi) |
| Contesto (F2) | Progetto attivo, sessione corrente |
| Salute della sorgente | I risultati di sorgenti offline restano, marcati come non raggiungibili |

**Streaming stabile.** Nomi, app e comandi arrivano entro 50 ms, il full-text entro 250 ms, il semantico entro 600 ms. Un risultato già mostrato in cima non viene scalzato dai risultati tardivi: questi si inseriscono più sotto o nella propria sezione, così la lista non salta mentre l'utente naviga con la tastiera.

## 10. Mail

- Metadati (mittente, destinatari, CC, oggetto, data, account, cartella, thread) in tabelle dedicate con indici. Corpo e allegati diventano blocchi nello stesso FTS e negli stessi vettori, marcati per tipo.
- La ricerca negli allegati si attiva separatamente da quella nel corpo (§14).
- Un allegato con lo stesso hash di un file su disco viene collegato a quel file ("salvato come"), ed è la base per i Related Items.
- I thread si ricostruiscono da `Message-ID`, `In-Reply-To` e `References`, con l'oggetto normalizzato come ripiego.

## 11. Index Health (§53)

| Indicatore | Dettaglio |
| --- | --- |
| Copertura | File e mail indicizzati, per sorgente e livello |
| Code | Elementi in attesa di estrazione, OCR, embedding |
| Velocità | Elementi al minuto, ultima esecuzione riuscita |
| Errori | Per motivo (permesso, formato, timeout, protetto da password, dataless, crash del parser), con l'elenco degli elementi |
| Spazio | Dimensione di ogni database e della cache vettoriale |
| Consumo | CPU ed energia usate da Mosaic |
| Dipendenze | Stato di Spotlight per volume, stream FSEvents attivi |

**Reindex selettivo**: per sorgente, cartella, tipo, stato (solo i falliti) o fase (solo OCR, solo embedding, solo ricostruzione dell'indice vettoriale). Un cambio di configurazione non richiede mai un reindex completo.

## 12. "File non trovato", con diagnosi (§54)

Quando un elemento atteso manca, Diagnostics verifica in quest'ordine:

1. La sorgente è disattivata.
2. Il volume non è montato, o il provider cloud è disconnesso.
3. Manca il permesso.
4. Il percorso è escluso da una regola.
5. Il file esiste solo online e l'indicizzazione del contenuto è disattivata.
6. L'elemento è ancora in coda (con il ritardo stimato).
7. C'è un errore di estrazione registrato.
8. L'indice è incoerente (controllo di integrità).

La risposta riporta la prima causa confermata, insieme all'azione per risolverla.
