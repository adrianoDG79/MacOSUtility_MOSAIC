# MOS-SUM-001 — Riepilogo della discovery

| Campo | Valore |
| --- | --- |
| Progetto | Mosaic, macOS Personal Utility Center — *Your Mac. Connected.* |
| Fase | 0, Discovery & Architecture (master prompt §72) |
| Data | 2026-09-29 |
| Stato | Approvata con modifiche il 2026-09-29; M0 in corso |
| Dettagli | [Indice dei documenti](#indice-dei-documenti) · [Decision Log](../DECISION_LOG.md) · [Master prompt](../reference/MOSAIC-MASTER-PROMPT.md) |

## In breve

- La discovery è conclusa e approvata con alcune modifiche (§9).
- **Architettura:** un'app **nativa Swift** per Apple Silicon, **fuori dalla sandbox**, firmata Apple Development durante lo sviluppo e compatibile con Developer ID. Resta attiva in menu bar, esegue parsing e OCR in processi isolati e tiene un indice SQLite cifrato. L'AI lavora in locale per default, e ogni modifica a file o sistema passa dal **Safety Engine**.
- **Versione minima di macOS:** non ancora fissata; si decide a fine M0 in base allo spike S9.
- **V1 in dieci milestone (M0–M9)**, con posta da Apple Mail e Thunderbird e con il substrato dell'Assistant; la Fase 2 occupa M10–M16.
- **AI cloud:** provider neutrale e sostituibile, con OpenAI come prima implementazione; sempre subordinato a policy e consenso.
- **Termica** si integra tramite la sua API locale, già esistente, in sola lettura.
- **In corso:** M0, fondamenta e spike. Alla fine ci si ferma prima di M1 per la revisione.

## 1. Cosa è stato verificato

| Ambito | Cosa | Esito principale |
| --- | --- | --- |
| Ambiente | macOS, hardware, toolchain, firma, tastiere, sorgenti di input, posta, cloud, volumi, batteria, SQLite | macOS 26.6.2 su M1 Pro con 32 GB; Xcode 27; **nessuna identità di firma**; cambio automatico della sorgente per documento **attivo** |
| Termica | Codice, database, LaunchAgent, porta in ascolto | API locale sulla porta 43127, senza PIN da loopback |
| Progetti correlati | `RiorganizzazioneFolderMac` | Tassonomia e regole riusabili per lo Smart Organizer |
| Web (§73) | Capacità di macOS incerte: Foundation Models, rete locale, Wi-Fi, Input Monitoring, Apple Mail, file dataless, OAuth Google, Vision, APFS, appunti, File Provider | Vedi §7 |

## 2. Architettura

| Scelta | Motivo |
| --- | --- |
| Swift 6 con SwiftUI e AppKit | Alcune API necessarie esistono solo in Swift (Foundation Models, nuova API di Vision, App Intents); aspetto nativo; consumo minimo. Tauri ed Electron sono stati scartati |
| Fuori dalla sandbox, firma Apple Development ora e Developer ID in futuro | Full Disk Access, archivio di Mail, periferiche HID e strumenti come `brew` sono incompatibili con App Sandbox e Mac App Store |
| Un processo residente e due servizi XPC | Full Disk Access si concede una sola volta; i crash dei parser restano isolati; il codice più esposto gira con privilegi minimi |
| SQLite con GRDB e FTS5, quattro database | Full-text e filtri nella stessa query; migrazioni versionate dal primo giorno; configurazione, indice, attività e telemetria con cicli di vita separati |
| Database cifrati con SQLCipher, se S1 lo conferma | L'indice aggrega dati che macOS protegge, come le mail. Se S1 fallisce la decisione torna a te, senza ripieghi silenziosi |
| Vettori in SQLite con ricerca esatta in memoria | Ricerca semantica di base senza un'infrastruttura sproporzionata; indice HNSW oltre circa un milione di blocchi |
| AI locale per default, provider cloud neutrale | Privacy (§59); il cloud si usa solo con una policy che lo consente e con il tuo consenso, tramite provider sostituibili |
| Safety Engine come unico punto di modifica | Piano → anteprima → approvazione → journal → undo |

```text
Mosaic.app  (residente in menu bar, avvio al login opzionale)
├── UI          finestra principale · pannello di ricerca ⌥Space · menu bar · impostazioni
├── Moduli      Search · Sources · Mail · Keyboard · Declutter · Organizer · Health · Alerts · Diagnostics …
├── Piattaforma CommandRegistry · EventBus · JobScheduler + Resource Manager · Safety + Undo + Audit · AI Runtime + policy
├── Adapter     FSEvents · Spotlight · File Provider · Apple Mail · Thunderbird · Termica · IOKit/TIS · Vision · Foundation Models
├── MosaicExtractor.xpc   PDF, Office, MIME, OCR — sandbox, niente rete
└── MosaicML.xpc          embedding con Core ML
Archivi: core.db · index.db · activity.db · telemetry.db
```

- **Comunicazione tra moduli.** I moduli non si importano a vicenda: collaborano tramite protocolli, eventi e un registro unico di azioni. La stessa azione è raggiungibile da UI, Command Palette, menu bar, linguaggio naturale e, da M10, dall'Assistant.
- **Lavoro in background.** Quattro code di priorità, dalle query interattive al lavoro massivo; quest'ultimo su Apple Silicon gira sui core a efficienza. Il **Resource Manager** (Adaptive, Performance, Eco, Paused, Custom) rallenta o sospende OCR ed embedding in base a batteria, temperatura e attività dell'utente, e mostra quanto consuma Mosaic stessa.
- **Chiudere la finestra non ferma Mosaic; uscire sì.** Al rilancio le modifiche intercorse si recuperano da FSEvents, senza riscansioni complete.
- **Budget prestazionali:** pannello di ricerca in meno di 100 ms; primi risultati in meno di 50 ms; full-text in meno di 250 ms; semantico in meno di 600 ms; meno dell'1% di CPU a riposo.

## 3. Ricerca e AI

- **Livelli di indicizzazione per sorgente:** 1 nome e metadati, 2 testo completo (con OCR opzionale), 3 semantico.
- **Spotlight** serve per i risultati immediati, per i formati iWork e per i metadati, ma non è una dipendenza.
- **Ricerca ibrida:** parole esatte (BM25) e significato (vettori) confluiscono in un'unica classifica. I risultati arrivano progressivamente, senza far saltare la lista.
- **Linguaggio naturale:** una frase come "il PDF su cui lavoravo ieri pomeriggio" diventa un `SearchIntent` strutturato, mostrato come chip modificabili.
- **File cloud presenti solo online:** mai scaricati per indicizzarli senza un'autorizzazione esplicita per sorgente.

| Compito AI | Default | Alternative, secondo la policy |
| --- | --- | --- |
| Embedding | Modello locale Core ML, scelto con un confronto sul tuo corpus (S6) | Ollama |
| OCR, lingua, entità, date | Vision, NaturalLanguage | — |
| Query in linguaggio naturale, classificazione | Foundation Models (on-device) | Regole, Ollama, provider cloud |
| Riassunti, domande complesse all'Assistant (M10) | Foundation Models | Provider cloud configurato (OpenAI per primo) con consenso; Apple Private Cloud Compute su macOS 27 |

Le policy si impostano per modulo, sorgente e tipo di dato: *Solo locale*, *Chiedi*, *Cloud consentito*; vale sempre la più restrittiva. Ogni risultato indica dove è stato elaborato. Con *Chiedi*, prima di un invio vedi il provider e le informazioni esatte e minimizzate che partono; l'audit registra le chiamate senza salvarne il contenuto.

**Substrato dell'Assistant in V1:** ricerca in linguaggio naturale, `SearchIntent`, `CommandRegistry`, AI Runtime, astrazione dei provider, astrazione di azioni e strumenti, integrazione con il Safety Engine, azioni consapevoli dei permessi, retrieval consapevole delle sorgenti. M10 aggiunge l'interfaccia conversazionale.

## 4. Permission matrix

Tutti i permessi si chiedono just-in-time, mai al primo avvio. Ognuno è accompagnato da una spiegazione, e se viene negato la funzione passa a uno stato ridotto.

| Permesso | Serve per | Se negato | Milestone |
| --- | --- | --- | --- |
| Full Disk Access | **Apple Mail (obbligatorio)** | Niente ricerca in Apple Mail; i file funzionano con i permessi per cartella | M5 |
| File e cartelle, volumi, provider cloud | Le sorgenti che scegli | La sorgente resta in "Permesso richiesto" | M2 |
| Input Monitoring | Capire quale tastiera sta scrivendo | Il layout cambia solo al collegamento della tastiera | M4 |
| Contatti | Ricerca contatti, riconoscimento dei mittenti | Persone riconosciute solo dalle intestazioni | M5 |
| Calendari, Promemoria | Ricerca di eventi e promemoria | Assenti dai risultati | M9 |
| Notifiche | Alert Center | Avvisi solo dentro Mosaic | M6 |
| Elementi login | Avvio al login | Mosaic lavora solo se aperta | M1 |
| Rete locale | Stato del NAS | NAS solo "montato" o "non montato" | M6 |
| Localizzazione | Nome della rete Wi-Fi | Nessun nome di rete; Mosaic resta pienamente usabile | M15 |
| Accessibilità, Automazione, Gestione app, Appunti | Funzioni della Fase 2 | Funzione ridotta | M11–M16 |
| **Mai richiesti** | Registrazione schermo, fotocamera, microfono, Foto, Endpoint Security | — | — |

Thunderbird non richiede permessi: il suo profilo è fuori dalle aree protette da TCC.

## 5. Milestone

| # | Contenuto | Dim. |
| --- | --- | --- |
| M0 | Fondamenta e spike S1–S9; rapporto di fine milestone | L |
| M1 | Shell, design system, Permission Center, Safety Engine con Undo e Audit, astrazione delle azioni | L |
| M2 | Sources, indice dei file, Universal Search v1, Command Palette | XL |
| M3 | Full-text, OCR, ricerca semantica, AI Runtime con `OpenAIProvider`, `SearchIntent`, Resource Manager | XL |
| M4 | Keyboard Manager, menu bar completa | M |
| M5 | Mail Search e Mail Diagnostics: Apple Mail e Thunderbird | XL |
| M6 | System Health, Termica, Alert Center, Diagnostics & Repair | L |
| M7 | Declutter e duplicati | L |
| M8 | Smart Organizer, automazioni v1 | L |
| M9 | Onboarding, Modes, backup della configurazione → **V1** | M |
| M10 | Interfaccia conversazionale dell'Assistant, AI File Insights | L |
| M11 | Clipboard Manager | M |
| M12 | Activity Timeline, Work Sessions, Resume Work | XL |
| M13 | Projects e Related Items | L |
| M14 | Applications Manager e Software Maintenance | L |
| M15 | Network completo e File Safety | M |
| M16 | Automazioni avanzate, AI Rename, operazioni in blocco, Note, connettori mail cloud | M |

- Safety Engine e Undo arrivano in M1, prima di qualsiasi funzione che modifica file.
- M4 (tastiera) e M6 (salute del Mac) dipendono solo dalla shell e si possono anticipare.
- Ogni milestone si chiude con criteri misurabili e con una pausa per la revisione.
- Entro M9 sono coperte tutte le 19 voci del §64.

## 6. Termica

- **Integrazione:** in ordine, API locale (`/api/status`, `/api/history`, `/api/events`) in sola lettura, poi database di Termica in sola lettura, poi lo stato termico di macOS se Termica non c'è. Mosaic non duplica la lettura privata dei sensori.
- **Valore aggiunto:** Termica non registra i processi, quindi Mosaic li campiona per poter rispondere a domande come "perché ieri il Mac era caldo?".
- **Notifiche:** quando Termica è attiva, gli avvisi termici restano a Termica, per evitare doppioni.
- **Follow-up di sicurezza su Termica** (registrato, fuori da M0 salvo autorizzazione esplicita): ascolto su `127.0.0.1` per default con esposizione in LAN come opzione esplicita; verifica dell'header `Host` contro il DNS rebinding; LaunchAgent che punta alla cartella di build; schema del database senza versione.

## 7. Risultati delle verifiche che cambiano il piano

1. **Nessuna identità di firma sul Mac.** Senza una firma stabile, permessi e Portachiavi si azzerano a ogni build. Serve un certificato Apple Development, che è gratuito.
2. **Il cambio automatico della sorgente per documento è attivo** e contraddice il §16. In più, il primo tasto premuto su una tastiera appena usata può uscire con il layout precedente.
3. **Posta:** sul Mac c'è solo Apple Mail, il cui archivio è protetto e richiede Full Disk Access; il formato non è documentato e cambia con le versioni di macOS. Thunderbird non è installato: si sviluppa su fixture.
4. **Gmail diretto rimandato:** un'app Google in modalità test deve ripetere il login ogni 7 giorni, e l'autorizzazione alla lettura delle mail richiede un audit di sicurezza.
5. **Google Drive in streaming:** un blocco a livello di sistema impedisce all'indicizzazione di scaricare i file presenti solo online.
6. **Temperature:** macOS non le espone con API pubbliche, quindi arrivano da Termica.
7. **Indice e privacy:** un indice in chiaro renderebbe leggibili ad altri programmi dati che macOS protegge. Da qui la cifratura, condizionata a S1.
8. **Appunti:** macOS 26 chiede un consenso per leggere la clipboard, e Tahoe ha già una cronologia degli appunti in Spotlight. Il Clipboard Manager va ripensato prima di M11.
9. **AI locale:** Foundation Models funziona senza download, con un contesto di 4.096 token su macOS 26. Il nuovo modello arriva a 8.192 token, Private Cloud Compute a 32K.

## 8. Rischi principali

| ID | Rischio | Mitigazione |
| --- | --- | --- |
| R1 | Nessuna identità di firma: permessi persi a ogni build | Certificato Apple Development in M0 |
| R2 | Archivio di Apple Mail non documentato e variabile | Rilevamento dello schema, test su fixture, ripieghi |
| R6 | Limiti del cambio di layout | Spike S4, limiti dichiarati, disattivazione guidata dell'opzione per documento |
| R10 | Download massivi di file cloud | Blocco di sistema nei processi di estrazione; autorizzazione esplicita per sorgente |
| R14 | Indicizzazione che scalda il Mac o consuma batteria | Resource Manager, core a efficienza, auto-misurazione |
| R21 | Indice leggibile da altri processi | Cifratura a riposo, se S1 la conferma |
| R43 | Thunderbird sviluppato senza profilo reale | Fixture sui formati documentati; validazione su un profilo reale prima di V1 |
| R45 | Il substrato dell'Assistant allarga V1 | Solo fondamenta riutilizzabili; UI conversazionale in M10 |

Il registro completo è in [MOS-RISK-001](MOS-RISK-001-risk-register.md).

## 9. Decisioni (esito del 2026-09-29)

| # | Esito | Contenuto approvato |
| --- | --- | --- |
| D1 | Approvata | App fuori dalla sandbox; firma Apple Development per lo sviluppo personale; compatibilità con Developer ID e notarizzazione |
| D2 | Approvata | Mosaic resta in menu bar; avvio al login opzionale; chiudere la finestra non la termina; uscire ferma tutto; recupero via FSEvents |
| D3 | Approvata con modifica | Apple Mail **e Thunderbird** in V1 (Thunderbird su fixture, poi profilo reale); Gmail API, Microsoft Graph e IMAP in Fase 2; core basato su adapter |
| D4 | Approvata | Layout in base alla tastiera fisica; disattivazione del cambio per documento tramite Safety Engine e conferma esplicita; Input Monitoring opzionale e just-in-time |
| D5 | Approvata | API di Termica, poi database in sola lettura, poi stato termico di macOS; niente duplicazione dei sensori |
| D6 | Modificata | Provider cloud neutrale (`CloudAIProvider`), prima implementazione `OpenAIProvider`, poi Anthropic, Apple Private Cloud Compute e altri; locale per default; con *Chiedi* si mostrano provider e dati esatti prima dell'invio |
| D7 | Approvata con condizione | SQLCipher con chiave nel Portachiavi se S1 va bene; altrimenti decisione rimandata a te, senza ripiego in chiaro |
| D8 | Approvata | File cloud solo online mai scaricati per indicizzarli senza autorizzazione; indicizzazione del contenuto configurabile per sorgente |
| D9 | Approvata | Cancellazioni reversibili per default; file sincronizzati col cloud ad alto rischio; volumi di rete senza Cestino con quarantena o conferma rafforzata |
| D10 | Approvata | Chiamate esterne non essenziali disattivate per default |
| D11 | Approvata | Localizzazione chiesta just-in-time solo per l'SSID; Mosaic pienamente usabile senza |
| D12 | Approvata con modifica | Interfaccia conversazionale in M10, ma il substrato dell'Assistant è in V1 |

Inoltre: solo Apple Silicon confermato, con la versione minima di macOS da decidere a fine M0; direzione visiva A per l'esplorazione iniziale, non definitiva finché non sono presentate alternative.

## 10. Prossimi passi

1. **M0 in corso**: fondamenta del progetto e spike S1–S9.
2. Dalla tua parte, per gli spike interattivi: certificato Apple Development, Full Disk Access e Input Monitoring alle app di prova, una tastiera esterna.
3. A fine M0: rapporto in dieci punti e **stop prima di M1**.

| Spike | Cosa verifica |
| --- | --- |
| S1 | SQLCipher con GRDB e costo della cifratura |
| S2 | Permessi dei servizi XPC ed estrattore in sandbox |
| S3 | Velocità di scansione della home e ripresa di FSEvents |
| S4 | Tastiere: rilevamento, latenza del cambio, primo tasto |
| S5 | Apple Mail su macOS 26 (richiede Full Disk Access); Thunderbird su fixture |
| S6 | Scelta del modello di embedding sul tuo corpus |
| S7 | Foundation Models sul tuo Mac |
| S8 | Stabilità dei permessi dopo le rebuild |
| S9 | Versione minima di macOS praticabile e funzioni perse per versione |

## Indice dei documenti

| Codice | Documento |
| --- | --- |
| MOS-DISC-001 | [Discovery Report: verifiche, ambiente, decisioni ed esito, fonti](MOS-DISC-001-discovery-report.md) |
| MOS-ARCH-001 | [Architettura: stack, moduli, servizi in background, Safety](MOS-ARCH-001-architecture.md) |
| MOS-MAC-001 | [Integrazione macOS: API e fattibilità](MOS-MAC-001-macos-integration.md) |
| MOS-PERM-001 | [Permission Matrix](MOS-PERM-001-permission-matrix.md) |
| MOS-DM-001 | [Data Model](MOS-DM-001-data-model.md) |
| MOS-SRCH-001 | [Search & Indexing](MOS-SRCH-001-search-architecture.md) |
| MOS-MAIL-001 | [Mail Architecture](MOS-MAIL-001-mail-architecture.md) |
| MOS-AI-001 | [AI Architecture](MOS-AI-001-ai-architecture.md) |
| MOS-SEC-001 | [Security & Privacy](MOS-SEC-001-security-privacy.md) |
| MOS-TRM-001 | [Integrazione Termica](MOS-TRM-001-termica-integration.md) |
| MOS-UX-001 | [Information Architecture](MOS-UX-001-information-architecture.md) |
| MOS-PLAN-001 | [Milestone e roadmap](MOS-PLAN-001-milestones.md) |
| MOS-RISK-001 | [Risk Register](MOS-RISK-001-risk-register.md) |
| — | [Decision Log (ADR-000 … ADR-017)](../DECISION_LOG.md) |
