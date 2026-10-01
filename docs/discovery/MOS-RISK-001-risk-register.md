# MOS-RISK-001 — Risk Register

| Campo | Valore |
| --- | --- |
| Copre | Master prompt §72 L, §73 |
| Stato | Aperto; si aggiorna a ogni milestone |

Probabilità (P) e impatto (I): **A** alto · **M** medio · **B** basso.

| ID | Rischio | Area | P | I | Mitigazione | Milestone |
| --- | --- | --- | --- | --- | --- | --- |
| R1 | Su questo Mac non ci sono identità di firma: con build ad hoc, permessi TCC e accesso al Portachiavi si perdono a ogni build | Sicurezza, sviluppo | B | A | **Ridotto da S8**: certificato Apple Development creato, Full Disk Access verificato sopravvivere a una rebuild con Team ID fisso. Resta da verificare con Developer ID e notarizzazione prima della distribuzione | M0 |
| R2 | L'archivio di Apple Mail non è documentato e cambia tra versioni (V12 su Sequoia, versione su Tahoe da scoprire) | Mail | M | A | Rilevamento di cartella e schema; test su fixture; ripiego sui soli `.emlx`; Spotlight come ripiego per la ricerca | M5 |
| R3 | Full Disk Access non concesso, oppure concesso senza riavviare Mosaic | Permessi | M | M | Spiegazione just-in-time, istruzioni, rilevamento e richiesta di riavvio | M5 |
| R4 | Corpi e allegati non scaricati in locale da Mail (IMAP con download limitato) | Mail | M | M | Mail Diagnostics li conta e suggerisce le impostazioni di Mail; Mosaic non scarica nulla dalla rete | M5 |
| R5 | Connettori mail diretti: token validi 7 giorni in stato *Testing*, scope *restricted* con audit CASA, restrizioni dell'amministratore Workspace | Mail | A | M | Rimandati alla Fase 2 per decisione (D3); core indipendente dalle sorgenti (MOS-MAIL-001), quindi aggiungerli non tocca l'indicizzazione | F2 |
| R6 | Cambio di layout: primo tasto con il layout precedente; `TISSelectInputSource` inaffidabile in alcuni contesti; conflitto con il cambio per documento, attivo su questo Mac | Tastiera | B | M | **Chiuso da S4**: 0 errori su 25 pressioni, latenza 38–46 ms; il conflitto con l'input source per documento è confermato e mitigato, vedi R47 | M4 |
| R7 | Input Monitoring percepito come keylogging | Fiducia | M | M | Permesso opzionale; codice che scarta i valori dei tasti, verificato da test; spiegazione chiara | M4 |
| R8 | Tastiere identiche senza numero di serie non si distinguono | Tastiera | B | B | LocationID come indizio; limite documentato | M4 |
| R9 | Spotlight disattivato, incompleto o in ritardo su alcuni volumi | Ricerca | M | B | L'indice di Mosaic resta la fonte autorevole; Spotlight serve solo ad accelerare; diagnostica | M2 |
| R10 | Download massivi di file cloud *dataless* durante l'indicizzazione | Cloud | A* | A | Policy di I/O a livello di processo nei worker; controllo di `SF_DATALESS`; attivazione esplicita per sorgente; test con file solo online | M2 |
| R11 | Cancellare in una cartella sincronizzata cancella anche dal cloud e dagli altri dispositivi | Safety | M | A | Classe di rischio R3 (MOS-ARCH-001 §5); avviso esplicito; mai in automatico | M7 |
| R12 | Volumi di rete senza Cestino: la cancellazione diventa definitiva | Safety | M | A | Quarantena sullo stesso volume o conferma rafforzata; undo dichiarato non disponibile | M7 |
| R13 | Stime di spazio sbagliate a causa di cloni APFS, snapshot e file dataless | Declutter | M | M | Dimensione privata per i candidati; nota sugli snapshot locali; valori indicati come stime nella UI | M7 |
| R14 | Indicizzazione, OCR ed embedding scaldano il Mac o consumano batteria, in contrasto con il §39 | Risorse | M | A | Resource Manager, QoS background sui core a efficienza, blocchi termici ed energetici, auto-misurazione, benchmark | M3 |
| R15 | Crescita del database (FTS e vettori) | Storage | M | M | Livelli per sorgente, quantizzazione, limiti di dimensione per blocco, retention, dimensioni visibili | M3 |
| R16 | Integrazione di GRDB e SQLCipher via SPM su Xcode 27, o costo in prestazioni | Storage | M | M | Spike S1; ripiego in chiaro con FileVault, previa decisione esplicita | M0 |
| R17 | Qualità degli embedding per l'italiano; licenze dei modelli | AI | M | M | Confronto S6 sul corpus reale; revisione delle licenze; versionamento e ricalcolo | M0, M3 |
| R18 | Foundation Models non disponibile (Apple Intelligence spenta), contesto piccolo, guardrail | AI | M | M | Controlli a runtime; ripieghi; map-reduce | M3 |
| R19 | Prompt injection da documenti e mail verso l'Assistant | AI, sicurezza | M | A | Dati degli strumenti trattati come non fidati; nessuna azione autonoma; piani tramite il Safety Engine; elenco chiuso di strumenti | M10 |
| R20 | Dati inviati a un fornitore cloud; termini di conservazione | Privacy | M | A | Default *Solo locale*; consenso con anteprima; minimizzazione e oscuramento; audit | M10 |
| R21 | L'indice aggregato rende leggibili ad altri processi dati protetti da TCC | Privacy | M | A | Cifratura a riposo (D7), permessi `0600` | M0 |
| R22 | Termica: schema senza versione, possibili cambi dell'API, app non installata in `/Applications` | Integrazione | M | B | API prima del database; rilevamento delle capacità; sola lettura; stati espliciti | M6 |
| R23 | Termica esposta sulla rete (`0.0.0.0`) e vulnerabile al DNS rebinding (fuori scope) | Sicurezza | M | M | Follow-up registrato (MOS-TRM-001 §8), con priorità al binding su `127.0.0.1`; nessuna modifica a Termica senza autorizzazione esplicita; Mosaic usa solo loopback e non scrive nulla | — |
| R24 | Privacy della rete locale (macOS 15+): prompt, bug noti, TCP verso la LAN solo da app in `/Applications` | Rete | M | M | Build di sviluppo installate in `/Applications` per i test; descrizione nel plist; gestione del rifiuto | M6 |
| R25 | SSID leggibile solo con i servizi di localizzazione, BSSID solo con firma stabile | Rete | A | B | Permesso opzionale; funzione ridotta senza | M15 |
| R26 | Consenso agli appunti di macOS 26, e cronologia degli appunti già presente nello Spotlight di Tahoe | Clipboard | A | A | Verifica prima di M11; API `detect*`; valore aggiunto da ridefinire rispetto a Tahoe | M11 |
| R27 | `⌥Space` in conflitto con lo spazio unificatore o con altri launcher | UX | M | B | Scorciatoia configurabile, con segnalazione dei conflitti | M2 |
| R28 | Uscendo da Mosaic si ferma il lavoro in background e si saltano le esecuzioni pianificate | Background | M | B | Riproduzione degli eventi FSEvents; regola per le esecuzioni perse; avvio al login; trasparenza nella UI | M2, M8 |
| R29 | Attribuzione TCC dei servizi XPC diversa dal previsto | Architettura | M | M | Spike S2; ripiego su processi figli | M0 |
| R30 | Parser (MIME, PDF, OOXML) che vanno in crash o si bloccano su file malformati | Robustezza | M | M | Isolamento in XPC, timeout, test con input malformati, lista di esclusione | M3, M5 |
| R31 | Migrazioni che falliscono tra versioni | Dati | M | A | Migrazioni versionate, backup preventivo, test con fixture per ogni versione, indice ricostruibile | Tutte |
| R32 | Promettere un undo che macOS non garantisce | Safety | M | A | Capacità di undo dichiarata operazione per operazione; precondizioni; testi onesti nella UI | M1 |
| R33 | Perimetro che si allarga e funzioni superficiali | Progetto | A | A | Criteri di uscita per ogni milestone; nessuna funzione finta; feature flag | Tutte |
| R34 | Aggiornamenti di macOS che rompono integrazioni non documentate (Mail, preferenze HIToolbox, sensori letti da Termica) | Manutenzione | M | M | Adapter isolati, diagnostica, correzioni rapide; nessuna API privata dentro Mosaic | Tutte |
| R35 | Serve il permesso Gestione app per disinstallare; il database BTM è leggibile solo da root | App | M | M | Dati parziali dichiarati; passaggi manuali | M14 |
| R36 | Rilevamento degli aggiornamenti poco affidabile (App Store senza API, `softwareupdate` lento) | Manutenzione | M | B | Confidenza per origine; controlli di rete solo se attivati | M14 |
| R37 | Copertura di Time Machine determinabile solo in modo euristico | File Safety | M | M | Formula "sembra coperto", mai garanzie | M15 |
| R38 | SwiftUI lento con elenchi molto grandi | UI | B | M | `NSTableView` per le viste pesanti; paginazione; profilazione | M2 |
| R39 | Complessità di manutenzione per un solo sviluppatore assistito dall'AI | Progetto | M | M | Pacchetti modulari, ADR, test, documentazione | Tutte |
| R40 | Senza Endpoint Security, "file aperto" nella timeline è solo approssimato | Timeline | A | M | Più segnali combinati, dichiarati come approssimati | M12 |
| R41 | Note senza API pubblica | Ricerca | A | B | AppleScript con Automazione, oppure esclusione | M16 |
| R42 | Cambi di comportamento con macOS 27 (appena uscito; Xcode 27 già installato) e versione minima di macOS non ancora fissata | Piattaforma | M | M | Spike S9; controlli di disponibilità a runtime; test sulle versioni candidate | M0, tutte |
| R43 | Thunderbird sviluppato senza un profilo reale: le fixture possono divergere dal comportamento del client | Mail | M | M | Fixture costruite sui formati documentati; validazione su un profilo reale prima del rilascio di V1 | M5, M9 |
| R44 | Provider cloud (OpenAI per primo): termini di conservazione dei dati e cambi dell'API | AI, privacy | M | M | Contratto `CloudAIProvider`; termini verificati all'implementazione e mostrati nel consenso; policy *Chiedi*; provider sostituibile | M3 |
| R45 | Il substrato dell'Assistant in V1 allarga il perimetro | Progetto | M | M | Solo fondamenta riutilizzabili; nessuna interfaccia conversazionale prima di M10; criteri di uscita per milestone | M1–M3 |
| R46 | Gli spike interattivi (S2, S4, S5, S8) dipendono da azioni manuali: certificato, permessi, tastiera esterna | Processo | A | M | Istruzioni passo passo; app di prova dedicate; esiti parziali dichiarati come tali | M0 |
| R47 | L'input source in Pages/TextEdit segue il documento (memoria TSM per campo di testo), non solo la tastiera collegata: potenziale conflitto con lo switch automatico per-dispositivo di ADR-012 | Keyboard Manager | B | A | **Causa confermata e mitigata**: l'opzione di sistema "Automatically switch to document's input source" (Impostazioni → Tastiera → Sorgenti di input → Modifica…) disattivata risolve il conflitto. Da valutare in M9: se Mosaic debba disattivarla in automatico quando il Keyboard Manager è attivo, con consenso dell'utente | M9 |

\* Probabilità in assenza di mitigazione.
