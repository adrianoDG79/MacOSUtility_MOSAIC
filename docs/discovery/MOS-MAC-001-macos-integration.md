# MOS-MAC-001 — Integrazione con macOS

| Campo | Valore |
| --- | --- |
| Copre | Master prompt §72 C, §73 |
| Stato | Proposta. Le voci 🧪 vanno confermate negli spike di M0 |

Legenda: ✅ verificato o API pubblica stabile · 🧪 da confermare con uno spike · ⚠️ possibile con limiti · ❌ escluso

## 1. Piattaforma e shell

| Area | API / framework | Permesso | Esito | Note |
| --- | --- | --- | --- | --- |
| Finestre, sidebar, inspector | SwiftUI, AppKit | — | ✅ | `NavigationSplitView` con `.inspector` |
| Pannello di ricerca globale | `NSPanel` non attivante | — | ✅ | Sopra le altre app, riceve la tastiera |
| Tasto rapido globale | Carbon `RegisterEventHotKey` | — | ✅ | Non richiede Input Monitoring. Su molti layout `⌥Space` digita lo spazio unificatore, quindi la scorciatoia è configurabile e i conflitti vengono segnalati |
| Menu bar | `NSStatusItem` / `MenuBarExtra` | — | ✅ | Icona template con stati |
| Avvio al login | `SMAppService.mainApp` | Notifica di sistema; si gestisce in Impostazioni → Generali → Elementi login | ✅ | L'utente può disattivarlo |
| Notifiche | UserNotifications | Notifiche | ✅ | Richieste alla prima regola di alert attivata |
| Comandi nel sistema | App Intents | — | ✅ | Azioni di Mosaic in Comandi Rapidi e nello Spotlight di macOS 26 (opzionale) |
| Quick Look | QuickLookUI (`QLPreviewView`), QuickLookThumbnailing | — | ✅ | Anteprima nel pannello e nell'Inspector |

## 2. File, sorgenti, Spotlight

| Area | API / framework | Permesso | Esito | Note |
| --- | --- | --- | --- | --- |
| Enumerazione veloce | `getattrlistbulk`, `FileManager` con resource keys | File e cartelle, oppure Full Disk Access | 🧪 S3 | Metadati letti in blocco |
| Modifiche | FSEvents (CoreServices) | Come sopra | ✅ | Riproduzione degli eventi da un event ID salvato; sui volumi di rete non arrivano le modifiche fatte da altri |
| Volumi | NSWorkspace, DiskArbitration, `statfs` | Volumi rimovibili, volumi di rete | ✅ | Identità tramite UUID del volume |
| Cloud (Google Drive, OneDrive, Dropbox) | File Provider, flag `SF_DATALESS` | Prompt "accedere ai file gestiti da …" (da Sonoma) | ✅ | Solo metadati per i file non scaricati |
| Blocco dei download impliciti | `setiopolicy_np(IOPOL_TYPE_VFS_MATERIALIZE_DATALESS_FILES, …, OFF)` | — | ✅ | Le letture falliscono con `EDEADLK` invece di scaricare il file |
| iCloud Drive | Resource keys `ubiquitousItem*` | Come sopra | ✅ | Su questo Mac c'è una cartella File Provider iCloud da chiarire |
| Spotlight | `NSMetadataQuery`, `MDQuery`; `mdutil -s` per lo stato | — | ✅ | Percorso rapido e arricchimento (`kMDItemLastUsedDate`, `kMDItemWhereFroms`, tag); mai una dipendenza |
| Entità Mosaic nello Spotlight di sistema | Core Spotlight | — | ✅ | Opzionale, Fase 2 |
| Identità dei file | `NSURLFileResourceIdentifierKey`, inode, bookmark | — | ✅ | Riconoscimento delle rinomine |
| Hash | CryptoKit SHA-256 | — | ✅ | Solo sui candidati con la stessa dimensione |
| Cloni APFS e spazio reale | `getattrlist` con `ATTR_CMNEXT_PRIVATESIZE`, `ATTR_CMNEXT_CLONEID`, `EF_MAY_SHARE_BLOCKS` | — | ✅ | Operazione costosa, solo sui candidati alla pulizia |
| Cestino | `FileManager.trashItem(at:resultingItemURL:)` | — | ✅ | Restituisce la posizione nel Cestino, e quindi permette l'undo. Non disponibile su molti volumi di rete |
| Montaggio NAS | NetFS (`NetFSMountURLAsync`) | Volumi di rete, rete locale | ✅ | Credenziali nel Portachiavi |

## 3. Estrazione del contenuto e OCR

| Formato | API | Esito | Note |
| --- | --- | --- | --- |
| PDF | PDFKit | ✅ | Le pagine senza testo passano all'OCR |
| DOCX, DOC, RTF, ODT, HTML, webarchive | `NSAttributedString(url:options:)` | ✅ | Importatori di sistema |
| XLSX, PPTX | ZIP e XML, con un parser proprio | ⚠️ | Da scrivere e testare |
| Pages, Numbers, Keynote | Nessuna API di estrazione | ⚠️ | Ricerca nel contenuto via Spotlight: `kMDItemTextContent` si può interrogare ma non leggere |
| Testo, Markdown, sorgenti | Lettura con rilevamento della codifica | ✅ | |
| Email (`.emlx`, mbox, `.eml`) | macOS non offre un parser MIME | ⚠️ | Parser proprio dentro l'estrattore XPC, con test di robustezza |
| OCR | Vision: `RecognizeDocumentsRequest` (macOS 26: paragrafi, tabelle, liste, 26 lingue) e `VNRecognizeTextRequest` | ✅ | Sul dispositivo, tramite il Neural Engine |
| Somiglianza tra immagini | Vision, `VNGenerateImageFeaturePrintRequest` | ✅ | Per i duplicati simili |

## 4. Mail, contatti, calendario

| Area | API / accesso | Permesso | Esito | Note |
| --- | --- | --- | --- | --- |
| Apple Mail | `~/Library/Mail/V*/MailData/Envelope Index` (SQLite non documentato) e file `.emlx` | **Full Disk Access** | 🧪 S5 | La cartella V* cambia con macOS (V12 su Sequoia): va rilevata a runtime. Negli account IMAP con download limitato i corpi sono parziali. I messaggi si aprono con l'URL `message:` |
| Thunderbird | `profiles.ini`, mbox o maildir, `.msf`, `global-messages-db.sqlite` | Nessuno (fuori dalle aree TCC) | ⚠️ | In V1 (D3): sviluppo su fixture, poi validazione su un profilo reale. Non installato su questo Mac (MOS-MAIL-001) |
| Gmail API, Microsoft Graph, IMAP | URLSession e OAuth (`ASWebAuthenticationSession`) | Account | ⚠️ | Google in stato *Testing* rilascia token validi 7 giorni, e `gmail.readonly` è *restricted* (verifica e audit CASA). Rimandati alla Fase 2 (D3) |
| Contatti | Contacts.framework | Contatti | ✅ | Per risolvere le persone ("Marco") |
| Calendario, Promemoria | EventKit, accesso completo (macOS 14+) | Calendari, Promemoria | ✅ | |
| Note | Nessuna API pubblica. Alternative: AppleScript (Automazione) oppure `NoteStore.sqlite` (Full Disk Access, protobuf non documentato) | Automazione o Full Disk Access | ⚠️ | Fase 2, sperimentale |

## 5. Tastiera

| Area | API | Permesso | Esito | Note |
| --- | --- | --- | --- | --- |
| Collegamento e scollegamento delle tastiere | IOKit, `IOServiceAddMatchingNotification` su `IOHIDDevice` | Nessuno (da confermare) | 🧪 S4 | Vendor ID, Product ID, trasporto, `Built-In`, LocationID; il numero di serie spesso manca |
| Quale tastiera sta scrivendo | `IOHIDManager` con callback di input | **Input Monitoring** (`IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)`) | ✅ | Si legge solo il dispositivo di origine; il valore del tasto viene scartato subito (vedi MOS-SEC-001) |
| Cambio del layout | Text Input Sources: `TISCreateInputSourceList`, `TISSelectInputSource`, notifica `kTISNotifySelectedKeyboardInputSourceChanged` | — | ✅ | Il cambio avviene dopo il primo evento della nuova tastiera, quindi quel primo carattere può usare il layout precedente |
| Conflitto con il cambio per documento | Preferenza `com.apple.HIToolbox`, chiave `AppleGlobalTextInputProperties.TextInputGlobalPropertyPerContextInput` | — | ✅ rilevabile | **Attiva su questo Mac**: macOS ripristina il layout finestra per finestra, contro il §16. Mosaic la segnala e propone di disattivarla (D4) |
| Campi password | Secure Event Input | — | ⚠️ | Mentre è attivo il cambio può fallire; Mosaic riprova quando termina |
| Rimappatura a livello di driver, come Karabiner | DriverKit, estensione di sistema | Approvazione dell'estensione | ❌ | Troppo invasiva rispetto al beneficio |

## 6. Sistema, energia, temperatura

| Area | API | Permesso | Esito | Note |
| --- | --- | --- | --- | --- |
| CPU, memoria, swap, carico | Mach (`host_statistics64`, `host_processor_info`), `sysctl` | — | ✅ | |
| Processi | `libproc` (`proc_pidinfo`, `proc_pid_rusage`) | — | ✅ | Dettagli completi per i processi dell'utente, parziali per quelli di sistema |
| Batteria | IOPowerSources e registro `AppleSmartBattery` | — | ✅ | Verificato su questo Mac: 524 cicli, circa 83% di capacità, senza privilegi |
| Stato termico | `ProcessInfo.thermalState` | — | ✅ | Quattro livelli: nominal, fair, serious, critical |
| Temperature, ventole, potenza | Nessuna API pubblica | — | ⚠️ | Tramite Termica, che le legge via SMC e IOReport con `macmon` |
| Inattività, sospensione, blocco dello schermo | `CGEventSource` (secondi dall'ultimo input), notifiche di NSWorkspace | — | 🧪 | Non dovrebbe servire alcun permesso |
| Risparmio energetico, memoria | `ProcessInfo`, `DispatchSource` per la pressione sulla memoria | — | ✅ | |
| Consumo di Mosaic | `proc_pid_rusage` (energia consumata) | — | ✅ | Auto-misurazione |

## 7. Rete

| Area | API | Permesso | Esito | Note |
| --- | --- | --- | --- | --- |
| Stato della connessione, interfacce | Network.framework (`NWPathMonitor`), SystemConfiguration | — | ✅ | |
| Probe verso host e NAS | `NWConnection` (TCP), ICMP senza privilegi | **Rete locale** (macOS 15+) per gli indirizzi della LAN | ✅ | Problema noto in sviluppo: il TCP verso la LAN funziona solo se l'app è in `/Applications` |
| SSID del Wi-Fi | CoreWLAN | **Servizi di localizzazione** (da macOS 14.4); il BSSID solo con firma stabile | ⚠️ | Opzionale (D11) |
| DNS | SystemConfiguration | — | ✅ | |
| IP pubblico | Servizio esterno | — | ⚠️ | Solo se attivato (D10) |
| Ispezione dei pacchetti | — | — | ❌ | Esclusa dal §44 |

## 8. Area personale (Fase 2)

| Area | API | Permesso | Esito | Note |
| --- | --- | --- | --- | --- |
| Cronologia degli appunti | `NSPasteboard` (`changeCount`). macOS 26 introduce il consenso per la lettura programmatica (`accessBehavior`, metodi `detect*`) | Consenso agli appunti | ⚠️ | Tahoe ha già una cronologia degli appunti in Spotlight: il valore aggiunto va ridefinito (R26) |
| Incollare nell'app in primo piano | Evento `⌘V` sintetico con CGEvent | Accessibilità | ✅ | |
| Documento in primo piano, per la timeline | Accessibilità (`AXDocument` della finestra attiva) | Accessibilità | ✅ | Funziona con le app basate su documenti |
| "File aperto" | `kMDItemLastUsedDate`, FSEvents, `AXDocument` | — / Accessibilità | ⚠️ | Approssimato: senza Endpoint Security non esiste un evento di apertura affidabile |
| Riprendere il lavoro | `NSWorkspace.open(_:withApplicationAt:)`; posizionamento delle finestre con Accessibilità | — / Accessibilità | ⚠️ | Le schede del browser sono escluse (§29) |

## 9. Applicazioni e manutenzione (Fase 2)

| Area | API | Permesso | Esito | Note |
| --- | --- | --- | --- | --- |
| Elenco app, versioni, ultimo uso | LaunchServices, Info.plist, Spotlight | — | ✅ | |
| Origine (App Store, Homebrew, download) | Ricevuta `_MASReceipt`, Caskroom, attributo di quarantena | — | ✅ | |
| Elementi di login di altre app | Il database BTM è leggibile solo da root; plist in `LaunchAgents` | — | ⚠️ | Dati parziali, dichiarati come tali |
| Residui | Scansione euristica di `~/Library/*` | Full Disk Access per `Containers` | ⚠️ | Con livelli di confidenza, mai cancellazioni silenziose |
| Disinstallazione | Cestino | **Gestione app** (macOS 13+) | ⚠️ | |
| Aggiornamenti di macOS | `softwareupdate --list`; l'installazione richiede privilegi di amministratore | Amministratore per installare | ⚠️ | Lento; mai aggiornamenti in massa |
| Homebrew | `brew outdated --json=v2` | — | ✅ | Rileva, rivedi, aggiorna |
| App Store | Nessuna API pubblica | — | ⚠️ | Stima tramite iTunes Lookup (rete, solo se attivato) |
| Time Machine | `tmutil destinationinfo`, `tmutil isexcluded` | Full Disk Access per alcune letture | ⚠️ | Si può dire solo "sembra coperto", mai garantirlo |

## 10. AI

| Area | API | Permesso | Esito | Note |
| --- | --- | --- | --- | --- |
| LLM on-device | Foundation Models (macOS 26) | Apple Intelligence attiva | 🧪 S7 | 4.096 token su macOS 26, 8.192 con il nuovo modello (WWDC26). Generazione guidata con `@Generable` e tool calling; `contextSize` va letto a runtime |
| Private Cloud Compute | Foundation Models (macOS 27) | — | 🧪 S7 | 32K token, con ragionamento. Gratuito per gli sviluppatori sotto i 2 milioni di primi download (annuncio WWDC26) |
| Embedding | Core ML (Neural Engine), `NLContextualEmbedding` | — | 🧪 S6 | Modello scelto con un benchmark |
| Analisi del testo | NaturalLanguage: lingua, token, entità (`nameType`), lemmi | — | ✅ | |
| Date, indirizzi, link | `NSDataDetector` | — | ✅ | |
| LLM locale alternativo | Ollama su `127.0.0.1:11434` | — | ✅ | Già installato su questo Mac (0.33.3) |
| Cloud | Astrazione `CloudAIProvider` via HTTP: prima implementazione OpenAI, con API da verificare sulla documentazione ufficiale in M3; poi Anthropic, Apple Private Cloud Compute e altri. Il protocollo `LanguageModel` annunciato al WWDC26 va valutato come possibile base comune | Chiave API nel Portachiavi | ✅ | Solo con policy e consenso (D6) |

## 11. Esclusi di proposito

| Capacità | Motivo |
| --- | --- |
| Endpoint Security | Richiede un entitlement concesso da Apple e un'estensione di sistema con privilegi di root. Per questo gli eventi "file aperto" dell'Activity Timeline sono approssimati |
| Registrazione dello schermo | Mai richiesta: i titoli delle finestre di altre app non servono |
| Keylogging | Il Keyboard Manager legge solo *quale* dispositivo genera eventi |
| Lettura dei sensori con API private dentro Mosaic | Delegata a Termica (D5) |
| Estensioni di sistema e kext | Non necessarie |
