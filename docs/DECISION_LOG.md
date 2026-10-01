# Decision Log — Mosaic

Registro delle decisioni architetturali, come richiesto dal master prompt al §70. Per ogni decisione: problema, alternative, soluzione, motivazione, conseguenze.

Stati possibili: *Proposta*, *Accettata*, *Accettata con condizione*, *Rivista*, *Sostituita*, *Rifiutata*. I riferimenti D1–D12 rimandano alla tabella delle decisioni in [MOS-DISC-001](discovery/MOS-DISC-001-discovery-report.md#6-decisioni-che-richiedono-approvazione); l'esito è registrato al §6.1 dello stesso documento.

## 2026-09-29 — Approvazione della Fase 0

- **Esito**: l'impianto della Fase 0 è approvato: architettura nativa Swift 6, SwiftUI e AppKit, SQLite con FTS5, isolamento XPC, elaborazione local-first, Safety Engine, integrazioni tramite adapter, sviluppo incrementale per milestone.
- **Approvate come proposte**: D1, D2, D4, D5, D8, D9, D10, D11. D7 è approvata con una condizione (ADR-006).
- **Modificate**: D3 (Thunderbird entra in V1), D6 (provider cloud neutrale, con OpenAI come prima implementazione), D12 (il substrato dell'Assistant entra in V1).
- **Da determinare in M0**: la versione minima di macOS (ADR-016).
- **Termica**: le osservazioni di sicurezza restano come lavoro di follow-up. In M0 Termica non si modifica senza autorizzazione esplicita.
- **Identità visiva**: si esplora la direzione A, senza considerarla definitiva (ADR-017).
- **Prossimo passo**: M0, fondamenta e spike. Alla fine di M0 ci si ferma prima di M1, con un rapporto in dieci punti.

## 2026-09-29 — ADR-000: discovery prima del codice

- **Stato**: Accettata
- **Decisione**: la prima fase produce solo documentazione (MOS-DISC-001 e documenti collegati). Nessun codice applicativo prima dell'approvazione (§72).
- **Svolto**: ispezione in sola lettura dell'ambiente e di Termica; verifica sul web delle capacità incerte di macOS (§73). Il master prompt è conservato in `docs/reference/MOSAIC-MASTER-PROMPT.md`.

## 2026-09-29 — ADR-001: stack nativo Swift

- **Stato**: Accettata
- **Problema**: serve uno stack che garantisca integrazione profonda con macOS, aspetto nativo di alto livello e consumo minimo per un'app sempre attiva.
- **Alternative**: Tauri (Rust e React, come Termica); SwiftUI con un core Rust via UniFFI; Electron; Swift nativo.
- **Soluzione**: Swift 6 con SwiftUI e AppKit, senza componenti Rust in V1.
- **Motivazione**: alcune API necessarie esistono solo in Swift (Foundation Models, la nuova API di Vision, App Intents); controlli nativi; nessuna WebView sempre attiva; un solo toolchain.
- **Conseguenze**: i parser MIME e OOXML vanno scritti in Swift; la ricerca full-text usa FTS5 invece di Tantivy. Il motore di ricerca resta dietro un protocollo, e un componente Rust è ammesso solo se un benchmark lo giustifica.

## 2026-09-29 — ADR-002: distribuzione fuori dalla sandbox

- **Stato**: Accettata (D1)
- **Problema**: Full Disk Access, lettura dell'archivio di Mail, accesso ai dispositivi HID, esecuzione di strumenti come `brew` e `softwareupdate` e analisi di `~/Library` sono incompatibili con App Sandbox e con il Mac App Store.
- **Alternative**: Mac App Store con sandbox, che renderebbe impossibili le funzioni principali; sandbox con eccezioni temporanee, non accettate dallo Store e fragili.
- **Soluzione**: app senza sandbox, con Hardened Runtime. Durante lo sviluppo personale si firma con Apple Development. Le impostazioni di build restano compatibili con una futura firma Developer ID e con la notarizzazione: nessun entitlement privato, tutti i componenti annidati firmati.
- **Conseguenze**: Mosaic deve proteggere da sola i propri dati (ADR-006); serve un certificato, oggi assente; il bundle ID non si potrà più cambiare dopo M0.

## 2026-09-29 — ADR-003: un unico processo residente, con servizi XPC

- **Stato**: Accettata per il ciclo di vita (D2). La topologia XPC resta subordinata allo spike S2
- **Problema**: servono lavoro continuo in background, isolamento dei parser che leggono file non fidati e permessi TCC semplici da gestire per l'utente.
- **Alternative**: un LaunchAgent sempre attivo più l'app con la UI, che richiederebbe permessi TCC per due eseguibili distinti; oppure tutto nello stesso processo, dove un PDF malformato basterebbe a far chiudere l'app.
- **Soluzione**: `Mosaic.app` resta attiva in menu bar; chiudere la finestra principale non la termina; l'avvio al login è opzionale (`SMAppService.mainApp`). Uscire esplicitamente da Mosaic ferma ogni attività in background; al rilancio le modifiche intercorse si recuperano via FSEvents. Parsing e OCR girano in `MosaicExtractor.xpc` (in sandbox, senza rete, riceve dall'app i descrittori dei file); gli embedding in `MosaicML.xpc`.
- **Motivazione**: l'utente concede Full Disk Access una sola volta; i crash restano isolati; il codice più esposto gira con i privilegi minimi.
- **Conseguenze**: l'attribuzione TCC dei servizi XPC va confermata (S2); in caso contrario si ripiega su processi figli.

## 2026-09-29 — ADR-004: SQLite con GRDB, un database per ciclo di vita

- **Stato**: Accettata
- **Problema**: servono persistenza affidabile, migrazioni versionate (§68) e ricerca full-text combinabile con i filtri sui metadati.
- **Alternative**: Core Data o SwiftData, che offrono poco controllo su FTS e sulle migrazioni complesse; un database documentale; un unico file SQLite.
- **Soluzione**: SQLite in modalità WAL tramite GRDB (`DatabasePool`, `DatabaseMigrator`), con quattro database: `core`, `index`, `activity`, `telemetry`.
- **Motivazione**: FTS5 e filtri nella stessa query; migrazioni esplicite e testabili; cicli di vita, backup e retention differenti per ciascun database.
- **Conseguenze**: l'SQLite di sistema (3.51.0) include FTS5 ma non carica estensioni, quindi la cifratura richiede una build di SQLite inclusa nell'app (ADR-006).

## 2026-09-29 — ADR-005: indice Mosaic con FTS5, Spotlight come acceleratore

- **Stato**: Accettata
- **Problema**: il §10 chiede di sfruttare Spotlight senza dipenderne.
- **Alternative**: solo Spotlight, inaffidabile su volumi esterni e di rete e senza accesso al testo indicizzato; un motore esterno come Tantivy o Lucene.
- **Soluzione**: indice Mosaic con FTS5 (`unicode61` senza diacritici per il contenuto, `trigram` per i nomi) e fusione ibrida di BM25 e vettori tramite RRF. Spotlight serve per i risultati immediati, i formati iWork, i metadati e la diagnostica.
- **Conseguenze**: in V1 manca lo stemming dell'italiano, compensato dalla ricerca per prefisso e da quella semantica.

## 2026-09-29 — ADR-006: cifratura a riposo dei database

- **Stato**: Accettata con condizione (D7)
- **Problema**: un indice che aggrega mail e documenti renderebbe leggibili da qualsiasi processo dell'utente dati che macOS protegge con TCC.
- **Alternative**: database in chiaro protetti da FileVault, che però non difende dagli altri processi dell'utente; cifratura per colonna con CryptoKit, incompatibile con FTS.
- **Soluzione**: SQLCipher per tutti i database, con una chiave casuale da 256 bit salvata nel Portachiavi e accessibile solo con la firma di Mosaic.
- **Condizione**: lo spike S1 deve confermare prestazioni accettabili e un'integrazione affidabile di GRDB con SQLCipher tramite Swift Package Manager.
- **Se S1 fallisce**: nessun ripiego silenzioso sul salvataggio in chiaro. La decisione torna all'utente prima di cambiare l'architettura di privacy.
- **Conseguenze**: serve una build di SQLite propria al posto di quella di sistema; la firma stabile diventa ancora più necessaria.

## 2026-09-29 — ADR-007: vettori in SQLite, con ricerca esatta in memoria

- **Stato**: Accettata, da riverificare con i benchmark di M3
- **Problema**: V1 deve offrire una ricerca semantica di base senza un'infrastruttura sproporzionata.
- **Alternative**: sqlite-vec, che richiede una build di SQLite con estensioni; un indice HNSW (USearch) fin da subito; un database vettoriale esterno.
- **Soluzione**: vettori int8 in `index.db`, cifrati come il resto, e un indice in memoria caricato su richiesta, con ricerca esatta tramite Accelerate, dietro il protocollo `VectorIndex`. Oltre circa un milione di blocchi, o se si sfora il budget di latenza, si passa a HNSW.
- **Conseguenze**: la memoria si occupa solo quando serve; il richiamo è perfetto; il costo cresce linearmente con il numero di blocchi.

## 2026-09-29 — ADR-008: AI locale per default, provider cloud neutrale

- **Stato**: Rivista (D6)
- **Problema**: il §36 chiede un'architettura ibrida, con policy per sorgente e per modulo, trasparente su dove avviene l'elaborazione, senza legare Mosaic a un unico fornitore.
- **Alternative**: un unico provider cloud cablato nel codice (la proposta iniziale indicava Anthropic), scartato su indicazione dell'utente.
- **Soluzione**: elaborazione locale per default (Foundation Models, Core ML, Vision, NaturalLanguage; Ollama su loopback come server locale). I provider cloud implementano un protocollo neutrale, `CloudAIProvider`, e sono sostituibili e configurabili. La prima implementazione di terze parti è `OpenAIProvider`; in seguito `AnthropicProvider`, Apple Private Cloud Compute e altri. Policy *Solo locale*, *Chiedi* e *Cloud consentito* per ambito, con prevalenza della più restrittiva. Con *Chiedi*, prima di ogni trasmissione Mosaic mostra il provider e le informazioni esatte, già minimizzate, che verranno inviate. Ogni risultato indica dove è stato elaborato; l'audit registra le chiamate senza salvarne il contenuto.
- **Conseguenze**: nessun modulo conosce un provider specifico, la scelta è configurazione. Endpoint, modelli, parametri e termini di conservazione dei dati di OpenAI si verificano sulla documentazione ufficiale al momento dell'implementazione (M3). Il modello di embedding si sceglie con lo spike S6.

## 2026-09-29 — ADR-009: in V1 le mail arrivano dai client locali, Apple Mail e Thunderbird

- **Stato**: Rivista (D3)
- **Problema**: il §13 elenca come sorgenti potenziali Apple Mail, Thunderbird, Gmail, Outlook e IMAP.
- **Alternative**: connettori cloud diretti già in V1; Thunderbird solo se installato.
- **Soluzione**: in V1 due adapter locali, Apple Mail e Thunderbird. Thunderbird resta in V1 anche se non è installato sul Mac di sviluppo: si sviluppa e si testa con fixture fedeli ai formati documentati, poi si valida su un profilo reale. Gmail API, Microsoft Graph e IMAP diretti restano in Fase 2. Il core di indicizzazione e ricerca dipende solo dal contratto `MailSourceAdapter`, quindi le nuove sorgenti non lo modificano (MOS-MAIL-001).
- **Motivazione**: nessuna credenziale cloud in Mosaic in V1. Per Google, un'app OAuth in stato *Testing* deve ripetere l'autorizzazione ogni 7 giorni, e lo scope `gmail.readonly` richiede verifica e audit CASA; le policy dell'amministratore di Google Workspace possono bloccare le app non verificate.
- **Conseguenze**: Full Disk Access resta necessario per Apple Mail (rischio R2); le fixture di Thunderbird possono divergere dal comportamento reale (rischio R43).

## 2026-09-29 — ADR-010: Safety Engine come unico punto di modifica

- **Stato**: Accettata (D9)
- **Soluzione**: ogni modifica è un `OperationPlan` classificato per rischio (da R0 a R4), con anteprima, approvazione, journal scritto prima di agire e verifica delle precondizioni. L'undo è offerto solo finché resta valido. Le cancellazioni passano dal Cestino o dalla quarantena di Mosaic ogni volta che è tecnicamente possibile. I file sincronizzati col cloud sono ad alto rischio, perché la cancellazione può propagarsi agli altri dispositivi. Sui volumi di rete senza Cestino servono la quarantena o una conferma rafforzata.
- **Conseguenze**: le operazioni rischiose richiedono qualche passaggio in più; la reversibilità dichiarata corrisponde a quella reale.

## 2026-09-29 — ADR-011: Termica tramite l'API locale, in sola lettura

- **Stato**: Accettata (D5)
- **Soluzione**: tre livelli in ordine. Primo, l'API locale di Termica (`/api/status`, `/api/events`, `/api/history` su loopback). Secondo, il database di Termica in sola lettura, dove appropriato (per esempio lo storico quando Termica non è in esecuzione). Terzo, `ProcessInfo.thermalState` quando Termica non è disponibile. Mosaic non duplica l'implementazione privata di lettura dei sensori di Termica e non scrive nulla in Termica.
- **Conseguenze**: senza Termica non ci sono temperature dettagliate. Le osservazioni di sicurezza su Termica sono lavoro di follow-up separato (MOS-TRM-001 §8).

## 2026-09-29 — ADR-012: Keyboard Manager con sole API pubbliche

- **Stato**: Accettata (D4)
- **Soluzione**: il layout dipende dalla tastiera fisica in uso, non dalla lingua del documento o dell'app. Notifiche IOKit per collegamento e scollegamento; IOHIDManager per capire quale tastiera è in uso, con Input Monitoring opzionale e richiesto just-in-time; Text Input Sources per cambiare layout. La disattivazione guidata del cambio automatico per documento passa dal Safety Engine e richiede una conferma esplicita.
- **Alternative scartate**: un driver o un'estensione di sistema in stile Karabiner, troppo invasivi; un event tap sempre attivo, che richiede Accessibilità e rischia di aggiungere latenza.
- **Conseguenze**: il primo carattere dopo il cambio di tastiera può uscire con il layout precedente (da misurare in S4); tastiere identiche senza numero di serie non sono distinguibili.

## 2026-09-29 — ADR-013: identificativi stabili e dati pronti per più dispositivi

- **Stato**: Accettata
- **Soluzione**: UUIDv7 per tutte le entità, `device_id`, orari in UTC, tombstone e `change_log` sulle entità curate dall'utente; l'indice resta per dispositivo.
- **Conseguenze**: una futura sincronizzazione non richiederà di riscrivere il modello dati (§57).

## 2026-09-29 — ADR-014: target macOS 26, solo Apple Silicon

- **Stato**: Sostituita da ADR-016
- **Nota**: l'utente ha approvato il solo Apple Silicon, ma non la versione minima macOS 26.

## 2026-09-29 — ADR-015: substrato dell'Assistant in V1

- **Stato**: Accettata (D12)
- **Problema**: l'interfaccia conversazionale dell'Assistant arriva in M10, ma non deve richiedere di riprogettare l'architettura di V1.
- **Soluzione**: V1 include le fondamenta riutilizzabili. Sono: ricerca in linguaggio naturale, `SearchIntent`, `CommandRegistry`, AI Runtime, astrazione dei provider AI, astrazione di strumenti e azioni, integrazione con il Safety Engine, azioni consapevoli dei permessi, retrieval consapevole delle sorgenti. M10 aggiunge l'esperienza conversazionale e il ragionamento avanzato.
- **Conseguenze**: ogni azione registrata dichiara parametri tipizzati, livello di rischio, permessi richiesti e sorgenti coinvolte, così può diventare uno strumento per l'AI senza adattamenti. Il perimetro di V1 cresce (rischio R45).

## 2026-09-29 — ADR-016: versione minima di macOS da determinare in M0

- **Stato**: Proposta, in valutazione nello spike S9
- **Problema**: la proposta iniziale fissava macOS 26 come minimo, ma molte capacità che lo richiedono (Foundation Models, nuove API di UI e di Vision) sono opzionali.
- **Soluzione**: solo Apple Silicon (accettato). In M0 si verifica se macOS 26 serve davvero al core o solo a capacità opzionali. Si preferisce il rilevamento delle capacità a runtime, con degrado controllato. A fine M0 si riportano la versione minima praticabile e, per ogni versione candidata, le funzioni concrete che si perdono; solo allora si fissa il target.
- **Conseguenze**: fino alla decisione il codice di M0 usa controlli di disponibilità (`#available`) per le API recenti, invece di presupporre macOS 26.

## 2026-09-29 — ADR-017: identità visiva, esplorazione della direzione A

- **Stato**: Accettata come direzione di lavoro
- **Soluzione**: l'esplorazione iniziale dell'icona e del design parte dalla direzione A, "Tessere convergenti". L'icona non è definitiva finché non sono state presentate alternative visive per la revisione (M1).
