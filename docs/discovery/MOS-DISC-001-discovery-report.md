# MOS-DISC-001 — Discovery Report

| Campo | Valore |
| --- | --- |
| Progetto | Mosaic, macOS Personal Utility Center |
| Fase | 0, Discovery & Architecture (master prompt §72) |
| Data | 2026-09-29 |
| Stato | Approvato con modifiche il 2026-09-29 (§6.1) |

## 1. Scopo

Questo documento riassume la fase di discovery richiesta dal master prompt al §72. Riporta cosa è stato verificato sul Mac di destinazione e sul web, quali capacità di macOS risultano confermate e quali limitate, e quali decisioni vanno approvate dal committente prima di iniziare l'implementazione (§71, §73). I dettagli sono nei documenti collegati in fondo.

Non è stata scritta alcuna riga di codice applicativo.

## 2. Metodo

- **Ispezione dell'ambiente**, in sola lettura: versione di macOS, hardware, toolchain, identità di firma, tastiere collegate, sorgenti di input, client di posta, cartelle cloud, volumi, Time Machine, stato di Spotlight, batteria (dal registro IOKit, IORegistry) e build dell'SQLite di sistema.
- **Ispezione di Termica**, in sola lettura: codice sorgente in `../MonitoraggioConsumiMAC`, LaunchAgent, database e porta in ascolto.
- **Progetti correlati**: `../RiorganizzazioneFolderMac`, un organizzatore della cartella Download che lavora in sola analisi, preso come precedente per lo Smart Organizer.
- **Verifica sul web** delle capacità di macOS incerte, per non procedere per ipotesi (§73): Foundation Models, privacy della rete locale, nome della rete Wi-Fi (SSID) e servizi di localizzazione, Input Monitoring con IOHIDManager, archivio di Apple Mail, file *dataless*, OAuth di Google, Vision, cloni APFS, privacy degli appunti, prompt di accesso ai file di File Provider.

## 3. Ambiente

| Voce | Rilevato | Implicazione |
| --- | --- | --- |
| Mac | MacBook Pro 14" (MacBookPro18,3), Apple M1 Pro a 10 core (8 ad alte prestazioni, 2 a efficienza), 32 GB | Destinazione primaria; target solo Apple Silicon |
| macOS | 26.6.2 (25G83) | Versione minima di macOS da determinare in M0 (S9, ADR-016) |
| Xcode e Swift | Xcode 27.0 (27A266a), Swift 6.4, SDK macOS 27.0 | Le funzioni di macOS 27 si possono usare quando disponibili |
| Identità di firma | **Nessuna identità valida** | Blocca M0: senza una firma stabile i permessi TCC e l'accesso al Portachiavi si perdono a ogni build (R1) |
| Altri toolchain | Homebrew 7.0.4, Node 26.5, Python 3.14.7, Rust 1.97.1, **Ollama 0.33.3**, git 2.54 | Ollama è utilizzabile come provider AI locale opzionale |
| Tastiere | Al momento solo la tastiera interna (SPI, Vendor ID 0x05AC, Product ID 0x0342, Built-In) | Gli identificativi hardware sono leggibili; le prove con tastiere esterne sono nello spike S4 |
| Sorgenti di input | U.S., US Extended, Italian – Pro | Layout di destinazione per le mappature |
| Cambio della sorgente per documento | **Attivo** (`TextInputGlobalPropertyPerContextInput = 1`) | In conflitto diretto con il §16 (D4) |
| Posta | Archivio di Apple Mail presente ma protetto da TCC (`Operation not permitted`); Thunderbird, Outlook e Spark non installati | Mail V1 passa da Apple Mail con Full Disk Access (D3) |
| Cloud | Google Drive via File Provider (account istituzionale); una cartella File Provider `iCloudDrive-iCloudDrive (10-04-25 10:09)`; nessun `~/Library/Mobile Documents/com~apple~CloudDocs` | Rischio di download massivi di file *dataless* (D8). La cartella iCloud va chiarita con l'utente |
| Volumi | Solo il disco interno; destinazione Time Machine "BackUpDisk" configurata; snapshot locali presenti | File Safety (Fase 2) avrà dati reali; gli snapshot alterano le stime di spazio liberabile |
| Spotlight | Indicizzazione attiva su `/` | Utilizzabile come percorso rapido |
| Batteria | 524 cicli, capacità di progetto 6075 mAh, capacità massima reale 5038 mAh (circa 83%), letti senza privilegi | La salute della batteria in System Health si ottiene con API pubbliche |
| SQLite di sistema | 3.51.0, FTS5 attivo, `OMIT_LOAD_EXTENSION` | FTS5 è disponibile; niente estensioni caricabili (sqlite-vec) e niente cifratura senza una build inclusa nell'app (ADR-004, ADR-006) |
| Termica | In esecuzione, server HTTP su `*:43127`, database SQLite in WAL | Integrazione tramite API confermata (MOS-TRM-001) |

## 4. Risultati chiave

1. **Lo stack nativo Swift è l'unica scelta coerente con i requisiti.** Diverse API necessarie esistono solo in Swift (Foundation Models, le nuove API di Vision, App Intents). L'aspetto "Apple-native premium" richiede controlli nativi, e un'app residente in menu bar deve consumare pochissimo. Tauri, usato per Termica, è stato valutato e scartato (ADR-001).
2. **Niente App Sandbox e niente Mac App Store.** Full Disk Access, lettura dell'archivio Mail, accesso ai dispositivi HID, analisi dei residui delle app e comandi come `brew` sono incompatibili con la sandbox. La distribuzione è Developer ID (ADR-002).
3. **Termica espone già un'API locale** (`/api/status`, `/api/history`, `/api/events` in SSE) che da loopback non chiede il PIN. È il livello d'integrazione preferito dal §38 (livello 1). Il database in sola lettura resta come ripiego (MOS-TRM-001).
4. **Il cambio automatico di layout in base alla tastiera fisica si fa con API pubbliche**, cioè IOKit e Text Input Sources, ma con tre limiti. Serve il permesso *Input Monitoring* per sapere quale tastiera sta scrivendo. Il primo carattere dopo il cambio di tastiera può uscire con il layout precedente. L'opzione di sistema "cambia automaticamente sorgente per documento", oggi attiva su questo Mac, va disattivata (D4).
5. **Apple Mail si indicizza solo con Full Disk Access**, leggendo formati non documentati: il database SQLite `Envelope Index` e i file `.emlx`. Il loro percorso cambia con le versioni di macOS (V12 su Sequoia). Serve un adapter che rilevi lo schema, verificato con test su fixture (R2).
6. **I connettori diretti per Gmail e Outlook sono sconsigliati in V1.** Un'app Google OAuth in stato *Testing* riceve token di aggiornamento che scadono dopo 7 giorni, e lo scope `gmail.readonly` è classificato *restricted*: richiede la verifica di Google e un audit di sicurezza CASA. In più, l'amministrazione Google Workspace dell'ente può bloccare le app non verificate (D3).
7. **I file cloud *dataless* si proteggono a livello di sistema.** Con `setiopolicy_np(IOPOL_TYPE_VFS_MATERIALIZE_DATALESS_FILES, …, OFF)` le letture di file non scaricati falliscono invece di avviarne il download. Il blocco sarà attivo nei processi di estrazione (D8).
8. **Per temperature e ventole non esistono API pubbliche.** Termica le legge tramite interfacce private (crate `macmon`). Mosaic delega a Termica e, se Termica manca, mostra solo `ProcessInfo.thermalState` (D5).
9. **C'è un'AI locale senza download.** Foundation Models (macOS 26) offre un LLM on-device con generazione guidata e chiamata di strumenti. Il contesto è di 4.096 token su macOS 26; il nuovo modello annunciato al WWDC26 arriva a 8.192, e il Private Cloud Compute di Apple a 32K. Per gli embedding serve invece un modello dedicato, da scegliere con un confronto misurato sul corpus reale in italiano e inglese (S6).
10. **Un indice aggregato indebolisce la protezione TCC.** Se Mosaic salva in chiaro il testo di mail e documenti, qualsiasi processo dell'utente può leggerli senza Full Disk Access. La proposta è la cifratura a riposo con chiave nel Portachiavi (D7, ADR-006).
11. **macOS 26 introduce la privacy degli appunti.** La lettura programmatica della clipboard richiede un consenso per app, e Tahoe include già una cronologia degli appunti in Spotlight. Il Clipboard Manager (Fase 2) va progettato attorno a questi vincoli (R26).
12. **Le stime di spazio vanno calcolate con cura.** Per via dei cloni APFS e degli snapshot, cancellare un file non sempre libera spazio. `ATTR_CMNEXT_PRIVATESIZE` restituisce i byte davvero liberabili, ma rallenta la scansione: si usa solo sui candidati.

## 5. Architettura in sintesi

Mosaic è un'app nativa **Swift 6, SwiftUI + AppKit**, con un unico processo residente in menu bar (avvio al login tramite `SMAppService`). Parsing di file non fidati, OCR e calcolo degli embedding girano in **servizi XPC isolati**. La persistenza è **SQLite (GRDB) con FTS5**, divisa per ciclo di vita (configurazione, indice, attività, telemetria), con migrazioni versionate dal primo giorno.

Ogni modifica a file o al sistema passa dal **Safety Engine**: piano, anteprima, approvazione, esecuzione registrata in un journal, Undo. L'AI lavora **in locale per default**, con policy per modulo e per sorgente e con un consenso esplicito prima di ogni invio al cloud. I dettagli sono in [MOS-ARCH-001](MOS-ARCH-001-architecture.md).

## 6. Decisioni che richiedono approvazione

Secondo i §3, §71 e §73, le scelte seguenti cambiano UX, privacy, comportamento distruttivo o perimetro funzionale. Per ciascuna è indicata la raccomandazione.

| # | Decisione | Raccomandazione | Alternativa | Perché serve l'approvazione |
| --- | --- | --- | --- | --- |
| D1 | Distribuzione e firma | App non sandboxed, firmata e notarizzata (Developer ID). Per l'uso personale basta un certificato **Apple Development** gratuito (Personal Team), da creare in Xcode | Programma sviluppatori a pagamento (99 $ l'anno), necessario solo per distribuire Mosaic ad altri | Esclude il Mac App Store e richiede un'azione dell'utente |
| D2 | Ciclo di vita | Mosaic resta attiva in menu bar e parte al login; chiudere la finestra non la ferma. **Uscire da Mosaic sospende ogni attività in background**; al rilancio le modifiche intercorse si recuperano tramite FSEvents | Un demone separato sempre attivo, con un secondo set di permessi da concedere | Riguarda UX e comportamento in background |
| D3 | Perimetro Mail V1 | **Apple Mail**, dall'archivio locale, con Full Disk Access. Adapter Thunderbird solo se lo usi (su questo Mac non c'è). Gmail API, Microsoft Graph e IMAP diretti in Fase 2 | Connettori cloud già in V1, con login OAuth da rinnovare ogni 7 giorni | Riduce le sorgenti "potenziali" elencate al §13 |
| D4 | Keyboard Manager | Cambio di layout al collegamento della tastiera (senza permessi) e, in via opzionale, durante la digitazione (con *Input Monitoring*). Il primo tasto dopo il cambio di tastiera può uscire con il layout precedente. Mosaic propone di **disattivare "cambia automaticamente sorgente per documento"**, previa conferma | Solo cambio al collegamento, oppure un event tap invasivo che richiede Accessibilità | È un limite rispetto al §16 e modifica un'impostazione di sistema |
| D5 | Temperature | Delegate a Termica; senza Termica, solo lo stato termico di macOS su 4 livelli | Mosaic legge i sensori da sola, con API private | Il §37 chiede la temperatura "dove disponibile" |
| D6 | Default AI | *Solo locale* per indicizzazione, classificazione, OCR ed embedding. Assistant su *Chiedi*, con anteprima esatta dei dati da inviare. Provider cloud: Anthropic (`claude-opus-5-5`, configurabile) con la tua chiave API. Apple Private Cloud Compute come livello intermedio su macOS 27 | *Cloud consentito* come default | Riguarda i dati inviati al cloud (§36, §59) |
| D7 | Cifratura dell'indice | Database cifrati con SQLCipher e chiave nel Portachiavi, se la verifica delle prestazioni (S1) va a buon fine | Database in chiaro, protetti solo da FileVault | Cambia il comportamento di privacy |
| D8 | File cloud *dataless* | Mai scaricati per indicizzarli: solo metadati. L'indicizzazione del contenuto dei file cloud si attiva solo con consenso esplicito, sorgente per sorgente | Scaricare tutto per indicizzare | La ricerca non copre il contenuto dei file che esistono solo online |
| D9 | Cancellazioni | Sempre reversibili per default: Cestino, oppure quarantena Mosaic sullo stesso volume. Sui volumi di rete senza Cestino: quarantena o conferma esplicita di cancellazione definitiva. I file nelle cartelle sincronizzate col cloud sono classificati **ad alto rischio**, perché la cancellazione si propaga agli altri dispositivi | Cancellazione diretta | Riguarda il comportamento distruttivo (§48, §49) |
| D10 | Chiamate a servizi esterni | Rilevamento dell'IP pubblico, controllo degli aggiornamenti App Store e simili **disattivati per default**, attivabili a scelta | Attivi per default | Nessun upload silenzioso (§59) |
| D11 | Wi-Fi | Il nome della rete (SSID) richiede i servizi di localizzazione da macOS 14.4. Permesso opzionale, chiesto solo quando serve | Nessuna | È un permesso non previsto dal master prompt |
| D12 | Perimetro di V1 | V1 = M0–M9 (MOS-PLAN-001). Include Command Palette, ricerca in linguaggio naturale, Alert Center, Modes, File Inspector, backup della configurazione e Network di base. **Mac Assistant e AI File Insights passano a M10**, primo milestone della Fase 2 | Assistant già in V1 | Il §64 non elenca l'Assistant; va confermato |

### 6.1 Esito delle decisioni (2026-09-29)

L'impianto architetturale è approvato. Esito per ciascuna decisione:

| # | Esito | Note |
| --- | --- | --- |
| D1 | Approvata | Firma Apple Development per lo sviluppo personale; architettura compatibile con Developer ID e notarizzazione |
| D2 | Approvata | Avvio al login opzionale; chiudere la finestra non termina Mosaic; uscire ferma ogni attività; recupero via FSEvents |
| D3 | Approvata con modifica | **Thunderbird entra in V1** insieme ad Apple Mail: sviluppo su fixture, poi validazione su un profilo reale. Gmail API, Microsoft Graph e IMAP in Fase 2, con un core basato su adapter (MOS-MAIL-001) |
| D4 | Approvata | La disattivazione del cambio per documento passa dal Safety Engine, con conferma esplicita; Input Monitoring opzionale e just-in-time |
| D5 | Approvata | API di Termica, poi database in sola lettura, poi `ProcessInfo.thermalState`; nessuna duplicazione della lettura dei sensori |
| D6 | Modificata | Nessun provider cloud cablato: astrazione `CloudAIProvider`, prima implementazione `OpenAIProvider`, poi Anthropic, Apple Private Cloud Compute e altri. Locale per default; con *Chiedi*, provider e dati esatti e minimizzati mostrati prima dell'invio |
| D7 | Approvata con condizione | SQLCipher solo se S1 conferma prestazioni accettabili e un'integrazione GRDB/SPM affidabile. Se S1 fallisce, nessun ripiego silenzioso in chiaro: la decisione torna all'utente |
| D8 | Approvata | Per default si indicizzano solo i metadati; il contenuto dei file solo online è configurabile per sorgente |
| D9 | Approvata | Come proposta |
| D10 | Approvata | Come proposta |
| D11 | Approvata | Mosaic resta pienamente usabile senza il permesso di localizzazione |
| D12 | Approvata con modifica | L'interfaccia conversazionale resta in M10, ma il **substrato dell'Assistant entra in V1** (ADR-015) |

Altre indicazioni:

- **Versione minima di macOS.** È confermato solo Apple Silicon; macOS 26 non è approvato come minimo. In M0 lo spike S9 determina la versione più vecchia praticabile e le funzioni perse per ciascuna candidata (ADR-016).
- **Termica.** Le osservazioni di sicurezza restano come follow-up (MOS-TRM-001 §8). Nessuna modifica a Termica in M0 senza autorizzazione esplicita.
- **Identità visiva.** Direzione A per l'esplorazione iniziale, non definitiva finché non sono presentate alternative (ADR-017).

## 7. Spike tecnici pianificati in M0

| ID | Obiettivo | Esito atteso |
| --- | --- | --- |
| S1 | GRDB con SQLCipher via Swift Package Manager su Xcode 27; prestazioni di FTS5 (`unicode61`, `trigram`) con e senza cifratura | Go/no-go su D7 e overhead misurato |
| S2 | Attribuzione TCC dei servizi XPC incorporati; servizio di estrazione in sandbox che riceve descrittori di file; policy *dataless* nel processo XPC | Conferma della topologia dei processi (ADR-003) |
| S3 | Scansione di massa (`getattrlistbulk` contro `FileManager`) sulla home reale; ripresa di FSEvents dall'ultimo event ID dopo un'uscita | Tempi e memoria misurati |
| S4 | Tastiere: notifiche IOKit di collegamento senza permessi; rilevamento dell'attività con IOHIDManager e Input Monitoring; latenza di `TISSelectInputSource`; frequenza del problema del primo tasto; interazione con il cambio per documento | D4 confermata con dati misurati |
| S5 | Apple Mail su macOS 26, su dati reali: cartella V*, schema di `Envelope Index`, file `.emlx` e `.partial.emlx`, confronto dei conteggi. Thunderbird su fixture: profili, mbox, flag di cancellazione, Gloda | Contratto degli adapter. Apple Mail richiede che tu conceda Full Disk Access |
| S6 | Confronto tra modelli di embedding (italiano e inglese) sul tuo corpus. Candidati: `multilingual-e5` (small e base), EmbeddingGemma-300M, Qwen3-Embedding-0.6B, `NLContextualEmbedding` | Modello scelto per qualità, velocità, consumo e licenza |
| S7 | Foundation Models sul tuo Mac: disponibilità (Apple Intelligence è attiva?), qualità nell'estrarre intenti di ricerca, latenza. Verifica di Private Cloud Compute e del protocollo `LanguageModel` (WWDC26) rispetto al target macOS 26 | Ruolo di Foundation Models confermato |
| S8 | Firma stabile: i permessi TCC sopravvivono alle rebuild; l'accesso alla rete locale funziona solo da `/Applications` | Procedura di sviluppo documentata |
| S9 | Versione minima di macOS: compilazione del core con target 14, 15 e 26; inventario delle API che richiedono versioni recenti; rilevamento delle capacità a runtime | Versione minima praticabile e funzioni perse per ciascuna candidata |

## 8. Prossimi passi

1. Decisioni D1–D12 approvate il 2026-09-29 (§6.1).
2. **M0 in corso**: fondamenta e spike S1–S9 (MOS-PLAN-001 §4).
3. Dalla tua parte, per gli spike interattivi: certificato Apple Development (Xcode → Settings → Accounts → Manage Certificates), Full Disk Access e Input Monitoring alle app di prova, una tastiera esterna.
4. A fine M0: rapporto in dieci punti e **stop prima di M1**.

## 9. Fonti esterne consultate

- Foundation Models: [Apple Newsroom](https://www.apple.com/newsroom/2025/09/apples-foundation-models-framework-unlocks-new-intelligent-app-experiences/), [WWDC25, Meet the Foundation Models framework](https://developer.apple.com/videos/play/wwdc2025/286/), [WWDC26, What's new in the Foundation Models framework](https://developer.apple.com/videos/play/wwdc2026/241/), [finestra di contesto](https://zats.io/blog/making-the-most-of-apple-foundation-models-context-window/)
- Privacy della rete locale: [Michael Tsai](https://mjtsai.com/blog/2024/10/02/local-network-privacy-on-sequoia/), [Apple Developer Forums](https://developer.apple.com/forums/thread/759262), [Eclectic Light](https://eclecticlight.co/2025/03/10/manage-privacy-protection-for-network-devices-and-others/)
- SSID e servizi di localizzazione: [Apple Developer Forums](https://developer.apple.com/forums/thread/748518), [Apple Community](https://discussions.apple.com/thread/255524474)
- Input Monitoring e IOHIDManager: [nachtimwald.com](https://nachtimwald.com/2020/11/08/macos-iohidmanager-permission-issue/), [Apple Developer Forums](https://developer.apple.com/forums/thread/696673)
- Apple Mail: [contenuto di Envelope Index](https://dev.to/paris_moschovakos_5f8f1e0/whats-actually-inside-apple-mails-envelope-index-2loh), [versioni della cartella V*](https://aiemaily.com/blog/where-apple-mail-stores-emails-mac), [differenze di schema V10](https://github.com/imdinu/apple-mail-mcp/issues/127)
- File dataless: [setiopolicy_np(3)](https://keith.github.io/xcode-man-pages/setiopolicy_np.3.html)
- Google OAuth: [OAuth 2.0](https://developers.google.com/identity/protocols/oauth2), [pubblico dell'app](https://support.google.com/cloud/answer/15549945?hl=en), [scadenza a 7 giorni](https://dev.to/ko-hi/googles-oauth-testing-mode-expires-refresh-tokens-in-7-days-publish-the-consent-screen-before-24hm)
- Vision: [WWDC25, Read documents using the Vision framework](https://developer.apple.com/videos/play/wwdc2025/272/)
- APFS: [getattrlist(2)](https://leancrew.com/all-this/man/man2/getattrlist.html)
- Embedding in italiano: [Sease](https://sease.io/2026/09/understanding-embeddings-in-the-italian-language-part-2.html), [arXiv 2605.23618](https://arxiv.org/pdf/2605.23618)
- Privacy degli appunti: [Michael Tsai](https://mjtsai.com/blog/2025/05/12/pasteboard-privacy-preview-in-macos-15-4/), [iDownloadBlog](https://www.idownloadblog.com/2025/05/14/apple-macos-16-clipboard-privacy-prompt/), [cronologia appunti di Tahoe](https://pasteapp.io/blog/macos-tahoe-clipboard-history)
- File Provider: [Apple Community](https://discussions.apple.com/thread/254660914)

## Documenti collegati

[MOS-ARCH-001](MOS-ARCH-001-architecture.md) · [MOS-MAC-001](MOS-MAC-001-macos-integration.md) · [MOS-PERM-001](MOS-PERM-001-permission-matrix.md) · [MOS-DM-001](MOS-DM-001-data-model.md) · [MOS-SRCH-001](MOS-SRCH-001-search-architecture.md) · [MOS-AI-001](MOS-AI-001-ai-architecture.md) · [MOS-SEC-001](MOS-SEC-001-security-privacy.md) · [MOS-TRM-001](MOS-TRM-001-termica-integration.md) · [MOS-UX-001](MOS-UX-001-information-architecture.md) · [MOS-PLAN-001](MOS-PLAN-001-milestones.md) · [MOS-RISK-001](MOS-RISK-001-risk-register.md) · [Decision Log](../DECISION_LOG.md)
