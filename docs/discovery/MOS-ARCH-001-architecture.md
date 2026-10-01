# MOS-ARCH-001 — Architettura

| Campo | Valore |
| --- | --- |
| Copre | Master prompt §72 A (stack), B (moduli), H (servizi in background); §48–§50, §61–§63, §67 |
| Stato | Approvata con modifiche il 2026-09-29 |
| ADR collegati | Da ADR-001 ad ADR-017 nel [Decision Log](../DECISION_LOG.md) |

## 1. Principi

1. **Architettura completa, implementazione incrementale** (§2). I confini dei moduli, il modello dati e i servizi di piattaforma sono progettati per l'intera roadmap, mentre ogni milestone consegna funzioni complete. I moduli non ancora pronti restano nascosti da feature flag e non compaiono mai come segnaposto.
2. **Local-first e privacy per costruzione** (§59). Mosaic non apre server locali e non invia telemetria; l'AI lavora in locale per default e i dati sensibili sono cifrati.
3. **Un solo punto d'ingresso per le modifiche** (§48). Nessun modulo tocca direttamente file o impostazioni di sistema: tutto passa dal Safety Engine.
4. **Isolamento dei guasti** (§62). Parser e integrazioni esterne stanno dietro adapter con timeout, circuit breaker e stati espliciti. I parser di file non fidati girano in processi XPC separati.
5. **Nessuna dipendenza fragile.** Spotlight, Termica e i client di posta sono sorgenti di dati, non fondamenta: se mancano, Mosaic continua a funzionare in modo ridotto.
6. **Un unico registro di comandi per tutte le interfacce.** La stessa azione è raggiungibile da UI, Command Palette, menu bar, linguaggio naturale, Assistant e in futuro Comandi Rapidi.

## 2. A — Stack tecnologico

### 2.1 Decisione

| Livello | Scelta |
| --- | --- |
| Linguaggio | Swift 6.x con strict concurrency; actor per i servizi con stato |
| UI | SwiftUI (Observation, `NavigationSplitView`, Swift Charts, scena Settings) più AppKit dove SwiftUI non basta: pannello di ricerca (`NSPanel` non attivante), `NSStatusItem`, Quick Look (`QLPreviewView`), tabelle molto grandi (`NSTableView`) |
| Persistenza | SQLite in WAL tramite GRDB (`DatabasePool`, `DatabaseMigrator`, FTS5); build SQLite o SQLCipher inclusa nell'app se S1 dà esito positivo |
| Full-text | SQLite FTS5: `unicode61` con rimozione dei diacritici per il contenuto, `trigram` per nomi e percorsi |
| Vettori | Vettori quantizzati int8 in SQLite, con ricerca esatta in memoria (Accelerate e SIMD) dietro il protocollo `VectorIndex` (ADR-007) |
| Estrazione e OCR | PDFKit; `NSAttributedString` per DOCX, DOC, RTF, ODT e HTML; parser OOXML per XLSX e PPTX; Vision (`RecognizeDocumentsRequest`); parser MIME proprio |
| AI | Foundation Models (on-device), Core ML (embedding), NaturalLanguage; Ollama come server locale opzionale. Provider cloud dietro l'astrazione neutrale `CloudAIProvider`: prima implementazione `OpenAIProvider`, poi Anthropic, Apple Private Cloud Compute (macOS 27) e altri (ADR-008) |
| IPC | XPC (`XPCSession`, `NSXPCConnection`) con verifica della firma del processo collegato |
| Background | Swift Concurrency con code a QoS diversi, `NSBackgroundActivityScheduler`, FSEvents, notifiche di alimentazione di IOKit |
| Test | Swift Testing, più XCTest per UI e prestazioni |
| Target | Solo Apple Silicon (arm64). Versione minima di macOS da determinare in M0 (S9, ADR-016), con rilevamento delle capacità a runtime |

### 2.2 Alternative valutate

| Criterio (§3) | Swift nativo | Tauri (Rust + React), come Termica | SwiftUI + core Rust (UniFFI) | Electron |
| --- | --- | --- | --- | --- |
| Integrazione profonda con macOS | Diretta. Alcune API esistono solo in Swift (Foundation Models, nuova API di Vision, App Intents) | Tramite bridge `objc2`; le API solo Swift richiedono comunque uno strato Swift | Diretta per la UI, tramite bridge per il core | Scarsa |
| Aspetto "Apple-native premium" (§5) | Controlli nativi, Liquid Glass, accessibilità | Imitazione web, mentre il §5 chiede di evitare l'aspetto da web dashboard | Nativo | Web |
| Consumo per un'app residente (§39, §61) | Minimo | Una WebView in più (50–100 MB) | Minimo | Alto |
| Motore full-text | FTS5, sufficiente per un corpus personale | Tantivy, più veloce | Tantivy | — |
| Parsing MIME e Office | Da scrivere in Swift o con librerie | Crate maturi (`mail-parser`, `calamine`) | Crate maturi | Librerie npm |
| Manutenibilità | Un solo toolchain | Due toolchain | Due toolchain più FFI | — |
| **Esito** | **Scelto** | Scartato | Di riserva: un componente Rust si introduce solo se un benchmark lo giustifica | Scartato |

La conseguenza principale è che la base Rust di Termica non viene riusata, e alcuni parser (MIME, OOXML) vanno scritti in Swift con test di robustezza. Il motore di ricerca sta dietro un protocollo, così si può sostituire se i benchmark di M2 e M3 non rispettano i budget.

### 2.3 Distribuzione e firma (ADR-002)

- App **non sandboxed**, con Hardened Runtime e senza eccezioni JIT.
- Firma **Apple Development** per l'uso personale (certificato gratuito). Se Mosaic verrà distribuita: **Developer ID con notarizzazione**, e aggiornamenti tramite Sparkle 2 con firme EdDSA.
- Il bundle identifier va fissato in M0 e poi non va più cambiato, perché i permessi TCC e gli elementi del Portachiavi dipendono da firma e bundle ID.
- Oggi su questo Mac non esistono identità di firma: è il primo prerequisito di M0.

## 3. Topologia dei processi (ADR-003)

```text
┌─────────────────── Mosaic.app  (processo residente in menu bar, avvio al login) ───────────────────┐
│ Presentazione  Main Window · Search Panel (NSPanel) · Menu Bar · Settings · Onboarding · fogli     │
│                di consenso e anteprima                                                              │
│ Moduli         Home · Search · Sources · Mail · Keyboard · Declutter · Organizer · Health ·        │
│                Alerts · Diagnostics · Permissions · Modes                                           │
│                (Fase 2: Assistant · Clipboard · Timeline · Projects · Apps · Maintenance ·          │
│                Network History · File Safety)                                                       │
│ Piattaforma    CommandRegistry · EventBus · JobScheduler + ResourceManager · SafetyEngine +         │
│                OperationExecutor + UndoCenter · AuditLog · PermissionCenter · AIRuntime +           │
│                PolicyEngine · Storage · SecretsStore · Telemetry                                    │
│ Adapter        FS/FSEvents · Spotlight · File Provider/iCloud · Apple Mail · Thunderbird ·          │
│                Contacts/EventKit · Termica · IOKit HID + TIS · IOPowerSources · Network.framework · │
│                Vision · Foundation Models · Core ML · Ollama · CloudAIProvider                      │
└──────────────┬────────────────────────────────────────────────────────┬───────────────────────────┘
               │ XPC (messaggi Codable, verifica della firma)           │
     ┌─────────▼─────────────┐                              ┌───────────▼────────────┐
     │ MosaicExtractor.xpc   │                              │ MosaicML.xpc           │
     │ PDF · Office · MIME   │                              │ embedding (Core ML,    │
     │ OCR (Vision)          │                              │ Neural Engine)         │
     │ sandbox, niente rete  │                              │ limite di memoria      │
     │ riceve descrittori    │                              └────────────────────────┘
     │ dataless OFF, timeout │
     └───────────────────────┘

Esterni, tutti opzionali: Termica 127.0.0.1:43127 (sola lettura) · Ollama 127.0.0.1:11434 ·
provider AI cloud (OpenAI per primo, con consenso) · Apple Private Cloud Compute (macOS 27)
Archivi: core.db · index.db · activity.db · telemetry.db (SQLite WAL, cifrati se D7) + cache vettoriale in memoria
```

- **Un solo processo con i permessi.** L'utente concede Full Disk Access una sola volta, a "Mosaic". Un demone separato richiederebbe un secondo set di permessi per un eseguibile diverso, e sarebbe fonte di confusione.
- **I servizi XPC** isolano i crash (un PDF malformato non abbatte l'app), permettono limiti di memoria e timeout per singola richiesta e riducono i privilegi. L'estrattore gira in sandbox senza rete e riceve dall'app solo i descrittori dei file da leggere. L'attribuzione TCC dei servizi XPC all'app che li ospita va confermata nello spike S2; in caso contrario si ripiega su processi figli, attribuiti anch'essi all'app.
- **Uscire da Mosaic ferma tutto** (D2), una scelta trasparente per l'utente. Al rilancio FSEvents consegna le modifiche avvenute nel frattempo, a partire dall'ultimo event ID salvato per ogni volume, senza riscansioni complete.

## 4. B — Architettura dei moduli

### 4.1 Livelli e regole di dipendenza

1. **Presentazione**: dipende dai moduli funzionali, mai dagli adapter.
2. **Moduli funzionali**: dipendono dalla piattaforma e da *porte*, cioè protocolli. Non si importano a vicenda; collaborano tramite eventi, comandi e interrogazioni sulle porte.
3. **Piattaforma**: servizi condivisi, che non conoscono le funzioni.
4. **Adapter**: implementano le porte verso macOS e i sistemi esterni. Nei test si sostituiscono con implementazioni finte.

### 4.2 Mappa dei moduli

| Modulo | Responsabilità | Porte usate | Fornisce | Milestone |
| --- | --- | --- | --- | --- |
| Home | Griglia di widget personalizzabile, layout di default | Interrogazioni ai moduli | — | M2 (base), M6 (completo) |
| Search | Pannello universale, Command Palette, provider, ranking, interpretazione del linguaggio naturale | `SearchProvider`, CommandRegistry, AIRuntime | Comandi `>` | M2–M3 |
| Sources | Sorgenti di file, regole di inclusione ed esclusione, livelli di indicizzazione, stati | FS, DiskArbitration, File Provider | Evento `SourceStatusChanged` | M2 |
| Indexing | Scansione, FSEvents, code di estrazione, OCR ed embedding, Index Health | Extractor XPC, ML XPC, Spotlight | Evento `ItemIndexed` | M2–M3 |
| Mail | Mail Sources, adapter Apple Mail e Thunderbird, thread, allegati, Mail Diagnostics (MOS-MAIL-001) | `MailSourceAdapter`, Contacts | Provider di ricerca per le mail | M5 |
| Keyboard | Dispositivi, mappature, cambio automatico, override | IOKit, TIS | Stato per la menu bar | M4 |
| Declutter | Categorie, soglie, preset, duplicati, stime di spazio | Index, SafetyEngine | Piani di operazioni | M7 |
| Organizer | Classificazione, proposte, apprendimento, regole di automazione v1, rinomina di base | Index, AIRuntime, SafetyEngine | Piani di operazioni | M8 |
| Health | Metriche di sistema, storico, correlazione, adapter Termica, rete di base | Telemetry, Termica | Widget, dati per la menu bar | M6 |
| Alerts | Regole, severità, notifiche native, rinvio, storico | UserNotifications | — | M6 |
| Diagnostics | Health Check non distruttivo, ricerca della causa, riparazioni tramite piani | Tutte le porte, in sola lettura | Piani di riparazione | M6 |
| Permissions | Stati, richieste just-in-time, spiegazioni, link alle Impostazioni | Verifiche TCC | `PermissionGate` | M1 |
| Modes | Profili globali e loro effetti | ResourceManager, Alerts, moduli | Evento `ModeChanged` | M9 |
| AI Runtime | Compiti AI per i moduli, policy, consenso, minimizzazione, audit; `SearchIntent`; provider locali e `CloudAIProvider` | Provider AI, SecretsStore | Substrato dell'Assistant (ADR-015) | M3 |
| Assistant (F2) | Interfaccia conversazionale e ragionamento avanzato sopra il substrato di V1; le azioni diventano piani | AI Runtime, CommandRegistry, porte dei moduli | — | M10 |
| Clipboard, Timeline, Sessions, Projects, Related, Apps, Maintenance, Network History, File Safety (F2) | Vedi MOS-PLAN-001 | — | — | M11–M16 |

### 4.3 Come comunicano i moduli

| Meccanismo | Uso | Esempio |
| --- | --- | --- |
| **Porte (protocolli) e ServiceContainer** | Interrogazioni tra moduli, sincrone o asincrone | Search interroga `MailSearchPort`; Declutter legge `FileIndexPort` |
| **EventBus** (pub/sub tipizzato su `AsyncStream`) | Notifiche disaccoppiate | `VolumeMounted`: Sources aggiorna lo stato, Diagnostics rivaluta il NAS, la Home aggiorna il widget |
| **CommandRegistry** | Azioni invocabili dall'utente, con parametri tipizzati e livello di rischio | `reindex.source`, `declutter.scan`, `keyboard.override`, esposti a Palette, menu bar, linguaggio naturale, Assistant e App Intents |
| **JobScheduler** | Lavoro lungo o differibile | `ExtractContent(fileID)`, `EmbedChunks`, `ScanDuplicates` |
| **OperationPlan verso il SafetyEngine** | Qualsiasi modifica | "Sposta 14 file in Documenti/Fatture" |
| **XPC** | Parsing, OCR, inferenza | L'app invia un descrittore di file e riceve testo diviso in blocchi e metadati |

### 4.4 Flussi principali

**Indicizzazione.** La scansione o un evento FSEvents aggiornano i metadati in `index.db`. Si valuta il livello richiesto dalla sorgente e, se serve, si accoda `ExtractContent` (priorità P2 o P3). L'app apre il file con la policy *dataless* disattivata e passa il descrittore all'estrattore XPC, che restituisce testo normalizzato e diviso in blocchi; i blocchi entrano in FTS5. Se il livello è *semantico*, si accoda `EmbedChunks` per calcolare i vettori. Ogni passaggio aggiorna lo stato dell'elemento, visibile in Index Health.

**Ricerca.** Il tasto rapido mostra un pannello già creato e nascosto, che si apre in meno di 100 ms. A ogni tasto la query viene divisa in sintassi e filtri, e i provider rispondono in parallelo (comandi, app, nomi, Spotlight, full-text, semantico, mail, contatti) con risultati progressivi entro il proprio budget. Il ranker li unisce, li raggruppa per tipo e ne stabilizza l'ordine. Sugli elementi sono disponibili azioni contestuali: apri, Quick Look, mostra nel Finder, copia percorso, Inspector.

**Modifica (Safety).** Il modulo costruisce un `OperationPlan` e `SafetyEngine.classify` assegna un rischio a ogni passo. Segue l'anteprima con l'approvazione, oppure un'auto-approvazione, ammessa solo per rischi bassi e regole esplicite. `OperationExecutor` scrive l'intento nel journal, verifica le precondizioni (inode, dimensione, data di modifica), esegue, controlla l'esito e registra l'operazione inversa. Infine l'operazione arriva a `UndoCenter` e `AuditLog`.

**Tastiera.** Una notifica IOKit di collegamento o scollegamento, oppure un callback HID di attività (con Input Monitoring), identifica il dispositivo. Mosaic cerca la mappatura, chiama `TISSelectInputSource` e pubblica l'evento `KeyboardLayoutChanged`, che aggiorna menu bar e audit.

**Termica.** Mosaic interroga `GET /api/status` su loopback. Se Termica risponde, usa lo stream SSE solo mentre la vista Health è aperta e, per il resto, un polling ogni 30 s per il ResourceManager. Lo storico (`/api/history`) si richiede solo quando serve una correlazione. Se l'app non è in esecuzione, si ripiega sul database in sola lettura.

### 4.5 Substrato dell'Assistant in V1 (ADR-015)

V1 costruisce le fondamenta su cui M10 aggiungerà l'interfaccia conversazionale, senza riprogettazioni:

- **Azioni tipizzate.** Ogni voce del `CommandRegistry` dichiara parametri, livello di rischio, permessi richiesti e sorgenti coinvolte. La stessa azione si esegue da UI e Command Palette e si espone all'AI come strumento.
- **Integrazione con Safety e permessi.** Le azioni che modificano qualcosa producono un `OperationPlan`; `PermissionGate` verifica i permessi prima dell'esecuzione.
- **AI Runtime.** Policy, consenso, minimizzazione e audit, con provider locali e `CloudAIProvider` (MOS-AI-001 §6).
- **`SearchIntent` e retrieval.** La ricerca in linguaggio naturale produce intenti strutturati; il retrieval rispetta sorgenti, permessi e policy e restituisce riferimenti citabili.

## 5. Safety Engine, Undo Center, Audit (§48–§50)

### 5.1 Classi di rischio

| Livello | Esempi | Approvazione |
| --- | --- | --- |
| R0, nessun effetto | Scansioni, analisi, anteprime, reindex | Nessuna |
| R1, basso e reversibile | Aggiungere un tag del Finder, creare una cartella, cambiare layout della tastiera, spostare un singolo file sullo stesso volume | Implicita nell'azione; auto-approvabile da regola |
| R2, medio e reversibile | Spostamenti o rinomine in blocco, spostamento nel Cestino, pulizia delle cache utente | Anteprima e conferma. Auto-approvabile solo da una regola creata esplicitamente, entro limiti di numero di file e dimensione |
| R3, alto | Cestino su cartelle sincronizzate col cloud, file senza altre copie, file di supporto delle app, operazioni tra volumi diversi, modifiche alle impostazioni di sistema | Anteprima dettagliata e conferma esplicita; mai in automatico |
| R4, irreversibile | Cancellazione definitiva, volumi senza Cestino, operazioni che richiedono i privilegi di amministratore | Conferma rafforzata (va digitata); mai in automatico; esclusa da V1, salvo lo svuotamento della quarantena |

Il rischio di un piano è il massimo tra quelli dei suoi passi. Lo aumentano il numero di elementi, i byte coinvolti, la presenza di file senza backup e le sorgenti cloud.

### 5.2 Ciclo di vita di un'operazione

`planned → approved → executing → completed | failed | partially_completed → (rolled_back)`

- **Journal prima dell'azione.** Ogni passo viene scritto con le sue precondizioni e la sua inversa prima di essere eseguito. Dopo un crash, un processo di riconciliazione confronta journal e filesystem.
- **Undo** disponibile solo finché le precondizioni dell'inversa sono ancora vere, cioè il file è dove Mosaic l'ha messo e ha la stessa identità. Un Cestino svuotato, modifiche successive dell'utente o un volume scollegato rendono l'undo *non disponibile*, e la UI lo dice (§49: non promettere una reversibilità che macOS non garantisce).
- **Cestino per default**, con `FileManager.trashItem`, che restituisce la posizione nel Cestino e rende possibile l'undo. Dove il Cestino non esiste, per esempio su molte condivisioni di rete, si usa la **quarantena Mosaic** (`.MosaicQuarantine/<operation-id>/` sullo stesso volume): lo spostamento è atomico e non copia dati. La quarantena si svuota dopo un periodo configurabile e sempre con conferma.
- **Audit.** Ogni piano, approvazione, esecuzione, errore e rollback genera eventi in `activity.db`, con riferimenti agli elementi e mai il loro contenuto.

## 6. H — Servizi in background

### 6.1 JobScheduler

| Classe | Esempi | QoS | Note |
| --- | --- | --- | --- |
| P0, interattivo | Query di ricerca, anteprime, Inspector | `userInteractive` | Mai accodato dietro altro lavoro |
| P1, richiesto dall'utente | "Reindex adesso", scansione Declutter avviata a mano | `userInitiated` | Mostra l'avanzamento |
| P2, manutenzione | Eventi FSEvents incrementali, nuove mail | `utility` | Eventi raggruppati ogni 1–2 s |
| P3, massivo | Scansione iniziale, OCR arretrato, embedding, analisi dei quasi-duplicati | `background` | Su Apple Silicon il QoS `background` gira sui core a efficienza |

- Le code sono **salvate** in SQLite, quindi il lavoro riprende dopo un'uscita o un crash.
- I tentativi falliti si ripetono con attesa crescente. Dopo N crash sullo stesso file, l'elemento finisce in una lista di esclusione visibile in Index Health.
- Timeout per tipo di lavoro (per esempio 30 s per l'estrazione e 120 s per l'OCR di un documento) e limiti di dimensione configurabili.

### 6.2 Resource Manager (§39)

Il Resource Manager tiene conto di: alimentazione e livello della batteria (IOPowerSources), modalità Risparmio energetico, `ProcessInfo.thermalState`, temperature di Termica se disponibile, carico della CPU, inattività dell'utente (secondi dall'ultimo input), pressione sulla memoria, schermo bloccato o in stop, e Mosaic Mode attivo.

| Modalità | Comportamento |
| --- | --- |
| **Adaptive** (default) | Il lavoro P3 procede solo con l'utente inattivo da almeno 3 minuti, altrimenti con un solo worker a QoS background. P3 va in pausa sotto il 30% di batteria o con stato termico `serious` o peggiore; OCR ed embedding si fermano sopra la soglia di avviso di Termica. Il lavoro massivo si fa preferibilmente con l'alimentatore collegato e l'utente inattivo |
| **Performance** | P3 sempre attivo, con più worker; resta solo il blocco termico |
| **Eco** | P3 solo con alimentatore e inattività; P2 rallentato |
| **Paused** | Solo P0 e P1 |
| **Custom** | Soglie modificabili |

**Auto-misurazione.** Mosaic misura il proprio consumo, CPU ed energia tramite `proc_pid_rusage`, servizi XPC inclusi, e lo mostra in Index Health ("Mosaic oggi: x% di CPU in media, y mWh"). Il budget di Adaptive prevede meno dell'1% di CPU in media a riposo e nessun contributo misurabile alla temperatura durante l'uso attivo.

### 6.3 Sorgenti di eventi

- **FSEvents** su ogni radice, con eventi a livello di singolo file e l'ultimo event ID salvato per volume. Eventi persi, `MustScanSubDirs` o spostamenti della radice provocano riscansioni mirate.
- **Volumi**: notifiche di NSWorkspace e DiskArbitration, con l'UUID del volume come identità.
- **Volumi di rete**: FSEvents non vede le modifiche fatte da altri client, quindi si usa una scansione incrementale periodica (intervallo configurabile) e una scansione al montaggio.
- **Pianificazioni** (per esempio le automazioni "ogni venerdì"): `NSBackgroundActivityScheduler`, che rispetta le condizioni energetiche. Le esecuzioni perse si recuperano secondo la regola scelta: eseguire al prossimo avvio, oppure saltare.

### 6.4 Budget prestazionali (da verificare in M2–M3)

| Misura | Obiettivo |
| --- | --- |
| Apertura del pannello di ricerca | Meno di 100 ms |
| Primi risultati (nomi, app, comandi) | Meno di 50 ms al 95° percentile, su 1 milione di elementi |
| Risultati full-text | Meno di 250 ms al 95° percentile |
| Risultati semantici | Meno di 600 ms al 95° percentile, su 300.000 blocchi |
| Memoria residente a riposo | Meno di 150 MB, esclusi modello e cache vettoriale, caricati su richiesta |
| CPU a riposo (Adaptive) | Meno dell'1% in media |

## 7. Isolamento dei guasti e modello di errore (§62, §54)

- Ogni adapter espone uno **stato di salute** (`available`, `degraded(reason)`, `unavailable(reason)`, `permissionRequired(permission)`) e un **circuit breaker**: dopo errori ripetuti smette di essere interrogato e riprova con attesa crescente.
- Gli errori sono **classificati per causa**: permesso, sorgente offline, client esterno, formato, risorsa, bug interno. Così Diagnostics può spiegare *perché* qualcosa non si trova ("Google Drive non montato", "cartella esclusa", "indice in ritardo di 4 minuti") invece di rispondere "file non trovato".
- Nessun `fatalError` nei percorsi di esecuzione. Ogni task di modulo gira in un proprio ambito, e un errore viene registrato e segnalato senza propagarsi al resto dell'app.

## 8. Log (§63)

- **Log tecnici**: `os.Logger`, con un sottosistema e una categoria per modulo. I valori dinamici sono `privacy: .private` per default. Non vi finiscono mai contenuto dei documenti, testo delle mail, appunti, token o chiavi.
- **Activity Log per l'utente**: tabella di audit in `activity.db`, filtrabile, ricercabile ed esportabile (§50). Contiene riepiloghi e riferimenti.
- I crash report restano sul Mac.

## 9. Struttura del progetto

```text
Mosaic/
├── Mosaic.xcodeproj            app, servizi XPC, test UI
├── App/                        entry point, scene, composizione delle dipendenze
├── XPC/
│   ├── MosaicExtractor/
│   └── MosaicML/
├── Packages/                   pacchetti SPM locali
│   ├── MosaicCore/             ID, errori, orologio, EventBus, CommandRegistry, DI
│   ├── MosaicStorage/          GRDB, migrazioni, cifratura, archivi
│   ├── MosaicPlatform/         JobScheduler, ResourceManager, Telemetry, Permissions, Secrets
│   ├── MosaicSafety/           SafetyEngine, OperationExecutor, UndoCenter, Audit
│   ├── MosaicIndexing/         scansione, FSEvents, pipeline, blocchi di testo
│   ├── MosaicSearch/           parser, provider, ranker
│   ├── MosaicAI/               provider, policy, embedding, client cloud
│   ├── MosaicMail/             adapter, parser MIME
│   ├── MosaicKeyboard/
│   ├── MosaicDeclutter/        duplicati inclusi
│   ├── MosaicOrganizer/        regole di automazione v1 incluse
│   ├── MosaicHealth/           telemetria, Termica, alert, diagnostica, rete di base
│   └── MosaicDesign/           design system, componenti, grafici
└── docs/
```

Ogni pacchetto funzionale ha due target: la logica, testabile senza UI, e la UI.

## 10. Strategia di test (§67)

| Tipo | Contenuto |
| --- | --- |
| Unit | Parser delle query, ranker, classificatore del rischio, regole, soglie, calcolo delle stime di spazio |
| Indicizzazione | Fixture di file reali (PDF con e senza testo, DOCX, XLSX, email MIME difficili); errori di lettura dataless simulati (`EDEADLK`) |
| Operazioni su file | Solo in directory temporanee create dal test; verifica di journal, undo e crash a metà operazione |
| Migrazioni | Un database di fixture per ogni versione rilasciata, migrato fino all'ultima |
| Permessi | Verifiche finte per ogni stato: concesso, negato, limitato, errore |
| Safety | Test a tabella: piano e rischio atteso |
| Duplicati | Corpus sintetico con coppie esatte, stesso contenuto, simili e versioni; precisione e richiamo per gruppo |
| Regole | Test su trigger, condizioni e livelli di automazione |
| Robustezza | Input malformati per MIME, PDF e OOXML inviati all'estrattore |
| Prestazioni | `XCTMetric` sui budget del §6.4, con un indice sintetico da 1 milione di elementi |

## 11. Estendibilità futura (§57, §58, §66)

- **Più Mac**: ID UUIDv7, `device_id` sui record, tombstone e `change_log` sulle entità curate dall'utente. L'indice resta locale a ogni Mac (MOS-DM-001 §7).
- **Browser**: una futura estensione comunicherà con un host *native messaging*, che inoltrerà gli eventi via XPC alla stessa `IngestAPI` usata dagli adapter. Gli eventi `browser_*` sono già previsti nel modello dell'Activity Timeline.
- **Accesso remoto, team, app mobile**: nessuna scelta attuale li preclude. Mosaic non espone porte di rete, e un eventuale servizio remoto andrebbe progettato con autenticazione forte fin dall'inizio.
