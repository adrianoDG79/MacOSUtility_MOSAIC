# MOS-PLAN-001 — Milestone e roadmap

| Campo | Valore |
| --- | --- |
| Copre | Master prompt §72 K; §2, §64–§66 |
| Stato | Approvato con modifiche il 2026-09-29. M0 in corso |

## 1. Regole

- Ogni milestone consegna funzioni **complete e reali**, con test e documentazione; nessun segnaposto presentato come funzionante (§2).
- Gli spike più rischiosi stanno all'inizio (M0), così un vincolo di macOS emerge prima di costruirci sopra.
- Safety Engine e Undo arrivano **prima** di qualsiasi funzione che modifica file.
- Il substrato dell'Assistant (ADR-015) si costruisce dentro V1, distribuito tra M0, M1 e M3.
- Alla fine di ogni milestone ci si ferma per la revisione. M1 non parte finché i risultati di M0 non sono stati rivisti e approvati.
- Solo Apple Silicon. La versione minima di macOS si fissa a fine M0 (S9, ADR-016).
- Le dimensioni sono relative (S, M, L, XL) e non ci sono date.

## 2. Panoramica

| # | Milestone | Contenuto principale | Dim. |
| --- | --- | --- | --- |
| **M0** | Fondamenta e spike | Progetto, firma, pacchetti core (ID, eventi, `CommandRegistry`, storage e migrazioni, JobScheduler, Portachiavi); app residente in menu bar; spike da S1 a S9; rapporto di fine milestone | L |
| **M1** | Shell, design system, Permission Center, Safety | Finestra, Settings, menu bar minima, design system, esplorazione dell'icona (direzione A, con alternative); Permission Center; Safety Engine, Undo Center, Audit Log; astrazione delle azioni con rischio e permessi; onboarding di base | L |
| **M2** | Sorgenti, indice dei file, Universal Search v1 | Sources, scansione, FSEvents, metadati; pannello di ricerca con fuzzy, ranking, anteprima, azioni, filtri; Command Palette, Index Health v1, Home v1 | XL |
| **M3** | Full-text, OCR, semantico, AI Runtime, Resource Manager | Estrattore XPC, FTS5, File Inspector, OCR, embedding, ricerca ibrida; AI Runtime con policy, `CloudAIProvider` e `OpenAIProvider`; `SearchIntent` e linguaggio naturale; retrieval consapevole delle sorgenti; Resource Manager | XL |
| **M4** | Keyboard Manager e menu bar | Dispositivi, mappature, cambio automatico, override; menu bar completa | M |
| **M5** | Mail Search e Mail Diagnostics | Mail Sources; adapter Apple Mail e Thunderbird; corpi, allegati, thread, contatti, diagnostica | XL |
| **M6** | System Health, Termica, Alert Center, Diagnostics | Telemetria e storico, adapter Termica, correlazione, rete di base, Alert Center, Health Check e ricerca delle cause, Home personalizzabile | L |
| **M7** | Declutter e duplicati | Categorie, soglie e preset, quattro livelli di duplicati, stime reali, azioni reversibili | L |
| **M8** | Smart Organizer e automazioni v1 | Classificazione, proposte, apprendimento, regole (suggerisci, chiedi, automatico), rinomina di base | L |
| **M9** | Onboarding, Modes, backup, rifinitura: **V1** | Onboarding in 10 passi, Modes, backup e ripristino della configurazione, Calendario e Promemoria nella ricerca, prestazioni, accessibilità | M |
| M10 | Mac Assistant e AI File Insights | Interfaccia conversazionale e ragionamento avanzato sul substrato di V1; riassunti ed estrazioni | L |
| M11 | Clipboard Manager | Cronologia, ricerca, elementi fissati, privacy, consenso agli appunti di macOS 26 | M |
| M12 | Activity Timeline, Work Sessions, Resume Work | Eventi autorizzati, sessioni, ripresa del contesto | XL |
| M13 | Projects e Related Items | Progetti, collegamenti, motore delle relazioni, dashboard di progetto | L |
| M14 | Applications Manager e Software Maintenance | Inventario, residui, disinstallazione con anteprima, aggiornamenti (rileva, rivedi, aggiorna) | L |
| M15 | Network completo e File Safety | Storico di rete, SSID, NAS; copertura dei backup e rischio della copia unica | M |
| M16 | Automazioni avanzate e completamenti | Regole avanzate, AI Rename, operazioni in blocco avanzate, Note; connettori mail cloud (Gmail API, Microsoft Graph, IMAP) | M |
| — | Solo architettura (§66) | Sincronizzazione tra più Mac, estensione per browser, accesso remoto, team, app mobile | — |

## 3. Dipendenze

```text
M0 ─► M1 ─► M2 ─► M3 ─┬─► M5 ─────────────┐
            │         ├─► M7 ─► M8 ───────┤
            │         └─► M10 (F2)        ├─► M9 = V1 ─► M11 … M16
            ├─► M4 ───────────────────────┤
            └─► M6 ───────────────────────┘
```

M4 e M6 dipendono solo dalla shell e dalla piattaforma: si possono anticipare, se preferisci avere presto la gestione della tastiera e la salute del Mac.

## 4. Dettaglio di V1

### M0 — Fondamenta e spike

- **Prerequisiti da parte tua**:
  - un certificato Apple Development, necessario per S8 e per rendere stabili i permessi;
  - la concessione di Full Disk Access e Input Monitoring alle app di prova degli spike (S2, S4, S5);
  - una tastiera esterna (S4);
  - facoltativo: da 20 a 50 query reali, ciascuna con il documento atteso, per il confronto degli embedding (S6).
- **Consegna**:
  - progetto Xcode generato da `project.yml` (XcodeGen), con script di build e test;
  - pacchetti SPM `MosaicCore` (ID UUIDv7, errori, EventBus, `CommandRegistry`, container), `MosaicStorage` (GRDB, migrazioni, backup prima delle migrazioni, cifratura se S1 va bene) e `MosaicPlatform` (JobScheduler, Portachiavi);
  - app residente in menu bar: la finestra si chiude senza terminare l'app, l'avvio al login è opzionale e l'uscita ferma ogni attività.
- **Spike**:

| Spike | Obiettivo |
| --- | --- |
| S1 | GRDB con SQLCipher via Swift Package Manager; FTS5 con e senza cifratura |
| S2 | Attribuzione TCC dei servizi XPC; estrattore in sandbox con descrittori di file; policy *dataless* |
| S3 | Scansione di massa della home; ripresa di FSEvents dopo un'uscita |
| S4 | Tastiere: rilevamento, attività, latenza del cambio, primo tasto, cambio per documento |
| S5 | Apple Mail su dati reali; Thunderbird su fixture |
| S6 | Confronto dei modelli di embedding sul tuo corpus |
| S7 | Foundation Models: disponibilità, `SearchIntent`, latenza |
| S8 | Firma stabile e permessi dopo le rebuild; rete locale da `/Applications` |
| S9 | Versione minima di macOS: cosa richiede davvero macOS 26 e cosa si perde con versioni precedenti |

- **Rapporto di fine M0**, in dieci punti:
  1. esiti degli spike S1–S9;
  2. ADR accettati, rifiutati o rivisti;
  3. risultati dei benchmark;
  4. raccomandazione confermata sulla versione minima di macOS;
  5. fattibilità confermata della posta;
  6. misure di fattibilità del Keyboard Manager;
  7. risultati della valutazione dei modelli di embedding;
  8. eventuali scostamenti dall'architettura approvata;
  9. risk register aggiornato;
  10. raccomandazione se procedere con M1.
- **Criteri di uscita**: rapporto consegnato, ADR aggiornati, test verdi. **Ci si ferma prima di M1.**

### M1 — Shell, design system, Permission Center, Safety

- **Consegna**:
  - finestra principale con la navigazione di MOS-UX-001 (solo le voci che funzionano), Settings e menu bar minima (apri, pausa, esci);
  - design system (tipografia, spaziature, colori, componenti, grafici);
  - esplorazione dell'icona nella direzione A, presentata insieme ad alternative visive per la revisione;
  - **Permission Center** completo: stati da P1 a P19, spiegazioni, link alle Impostazioni, `PermissionGate`;
  - **Safety Engine, OperationExecutor, Undo Center e Audit Log**;
  - **astrazione delle azioni**: ogni azione del `CommandRegistry` dichiara parametri, rischio e permessi richiesti, così è eseguibile da UI e Command Palette ed esponibile in seguito come strumento per l'AI;
  - onboarding di base: benvenuto, filosofia dei permessi, preferenza AI.
- **Criteri di uscita**: stati dei permessi corretti, sia con verifiche finte sia reali; test a tabella della classificazione del rischio; spostamento, rinomina e Cestino con undo verificati in directory temporanee, compreso un crash simulato a metà operazione.

### M2 — Sorgenti, indice dei file, Universal Search v1

- **Consegna**:
  - Sources (cartelle, volumi esterni, condivisioni montate, cartelle cloud), con regole di inclusione ed esclusione, livelli e stati;
  - scansione e FSEvents con riproduzione degli eventi; arricchimento da Spotlight;
  - pannello Universal Search (`⌥Space`) per file, cartelle e app: fuzzy, ranking, gruppi, tastiera, Quick Look, azioni (apri, mostra nel Finder, copia percorso, apri con) e filtri;
  - Command Palette con i primi comandi; Spotlight come percorso rapido;
  - Index Health v1 e Home v1 con i soli widget già reali.
- **Criteri di uscita**: benchmark sulla tua home (almeno 500.000 elementi) entro i budget di MOS-ARCH-001 §6.4; modifiche recuperate dopo un'uscita; **nessun download** di file cloud durante la scansione, verificato con un file di Google Drive disponibile solo online.

### M3 — Full-text, OCR, semantico, AI Runtime, Resource Manager

- **Consegna**:
  - `MosaicExtractor.xpc` per PDF, DOCX, DOC, RTF, ODT, HTML, XLSX, PPTX, testo e sorgenti, con divisione in blocchi, FTS5 e snippet;
  - File Inspector v1: metadati, hash, stato dell'indice e dell'OCR, testo indicizzato, azioni;
  - OCR per sorgente;
  - `MosaicML.xpc` con il modello scelto in S6, ricerca ibrida;
  - **AI Runtime** con policy engine, foglio di consenso e audit; provider locali; `CloudAIProvider` con la prima implementazione `OpenAIProvider` (opzionale, policy *Chiedi*);
  - `SearchIntent` e ricerca in linguaggio naturale con chip; retrieval consapevole delle sorgenti; azioni del registro esposte come strumenti;
  - Resource Manager con le modalità del §39 e l'auto-misurazione.
- **Criteri di uscita**: un set di valutazione con circa 50 query reali tue e i documenti attesi, con un obiettivo di richiamo@10 concordato; OCR verificato su scansioni di esempio; test del Resource Manager con stati di alimentazione e temperatura simulati; nessuna trasmissione al cloud senza consenso, verificata dai test.

### M4 — Keyboard Manager e menu bar

- **Consegna**: elenco dei dispositivi con i loro identificativi, mappature persistenti, cambio al collegamento e, con Input Monitoring richiesto just-in-time, durante la digitazione; override temporaneo; dispositivo e layout correnti. Rilevamento del cambio per documento, con disattivazione guidata tramite il Safety Engine e conferma esplicita. Menu bar completa e configurabile.
- **Criteri di uscita**: prova con almeno due tastiere fisiche; latenza del cambio misurata; comportamento del primo tasto documentato.

### M5 — Mail Search e Mail Diagnostics

- **Consegna**:
  - Mail Sources e contratto `MailSourceAdapter` (MOS-MAIL-001);
  - adapter **Apple Mail**: account, cartelle, metadati, corpi, thread, allegati con estrazione opzionale, apertura in Mail;
  - adapter **Thunderbird**: profili, mbox e maildir, messaggi eliminati non compattati, compattazione, diagnostica tramite Gloda; sviluppato su fixture;
  - ricerca per mittente, destinatari, CC, oggetto, data, corpo, thread, account, cartella, allegati e loro contenuto, anche semantica;
  - Contatti per riconoscere le persone;
  - **Mail Diagnostics** con le cause del §15.
- **Criteri di uscita**: indicizzazione del tuo archivio Apple Mail reale con conteggi riconciliati, o con le differenze spiegate; test dell'adapter Thunderbird verdi sulle fixture; validazione su un profilo Thunderbird reale pianificata prima del rilascio di V1; query semantiche sulle mail nel set di valutazione.

### M6 — System Health, Termica, Alert Center, Diagnostics

- **Consegna**:
  - metriche (CPU, memoria e pressione, swap, spazio per volume e sua crescita, batteria e salute, carico, processi, volumi) con storico e retention;
  - adapter Termica (API, poi database in sola lettura, poi `thermalState`) e vista di correlazione;
  - rete di base: connettività, interfacce, DNS, latenza verso destinazioni configurabili, raggiungibilità del NAS;
  - Alert Center: severità, categorie, soglie, rinvio, storico, deduplicazione con Termica;
  - **Run Health Check** non distruttivo, ricerca delle cause e riparazioni tramite piani;
  - Home completamente personalizzabile.
- **Criteri di uscita**: la domanda "perché ieri il Mac era caldo?" ottiene una spiegazione verificabile su dati reali; l'Health Check non fa alcuna modifica, come verificato dall'audit.

### M7 — Declutter e duplicati

- **Consegna**:
  - categorie selezionabili una per una: duplicati, file grandi, file vecchi, Download, Scrivania, cache utente, file temporanei, installer, DMG, ZIP, pacchetti inutilizzati, cartelle vuote, file di app abbandonate (con approccio prudente), altro;
  - soglie e preset ispezionabili e modificabili;
  - duplicati esatti (SHA-256), con lo stesso contenuto, simili e versioni, ciascuno con la sua confidenza;
  - stime di spazio basate sulla dimensione privata APFS; azioni reversibili.
- **Criteri di uscita**: precisione e richiamo misurati per ogni tipo di duplicato su un corpus di prova; nessun quasi-duplicato proposto come "sicuro da eliminare"; test distruttivi solo in ambienti temporanei.

### M8 — Smart Organizer e automazioni v1

- **Consegna**:
  - analisi di Download, Scrivania e cartelle scelte, con categorie come articoli scientifici, fatture, documenti amministrativi, immagini, installer, archivi e file di progetto;
  - tassonomia configurabile, importabile da `RiorganizzazioneFolderMac`;
  - flusso Suggerisci → Anteprima → Approva, con apprendimento dalle approvazioni;
  - regole con trigger (orario, file aggiunto, condizione) e livelli (suggerisci, chiedi, automatico solo per rischi bassi);
  - rinomina di base con anteprima e undo.
- **Criteri di uscita**: prova su una copia della tua cartella Download, con il tasso di accettazione misurato; test del motore delle regole.

### M9 — Onboarding, Modes, backup, rifinitura: V1

- **Consegna**: onboarding completo (§55), Modes (§46), backup e ripristino della configurazione su tre livelli con cifratura (§56), Calendario e Promemoria nella ricerca, ottimizzazione di prestazioni ed energia, accessibilità, interfaccia in italiano e inglese.
- **Criteri di uscita**: tutte le voci del §64 coperte (tabella del §5); validazione dell'adapter Thunderbird su un profilo reale; una o due settimane di uso reale senza perdita di dati; budget di risorse rispettati.

## 5. Copertura del §64

| # §64 | Funzione | Milestone |
| --- | --- | --- |
| 1 | Shell e UI premium | M1 |
| 2 | Home | M2 (base), M6 (completa) |
| 3 | Sources | M2 |
| 4 | Universal Search | M2–M3 |
| 5 | Indicizzazione ibrida | M2 |
| 6 | Full-text | M3 |
| 7 | Semantico di base | M3 |
| 8 | Mail Search | M5 |
| 9 | Mail diagnostics | M5 |
| 10 | Keyboard Manager | M4 |
| 11 | Decluttering | M7 |
| 12 | Smart Organizer | M8 |
| 13 | System Health | M6 |
| 14 | Termica | M6 |
| 15 | Menu bar | M1 (minima), M4 (completa) |
| 16 | Permission Center | M1 |
| 17 | Safety Engine | M1 |
| 18 | Undo | M1 |
| 19 | Diagnostics & Repair | M6 |

## 6. Definition of Done, per ogni milestone

- Funzioni usabili dall'inizio alla fine su dati reali, senza segnaposto.
- Test automatici (§67) verdi, migrazioni comprese.
- Permessi chiesti just-in-time, con uno stato ridotto esplicito quando mancano.
- Operazioni che modificano dati solo tramite il Safety Engine, con audit.
- Documentazione aggiornata: ADR, data model, permission matrix, changelog.
- Budget di risorse misurati, non stimati.
