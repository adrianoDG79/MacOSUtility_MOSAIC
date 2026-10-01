# MOS-PERM-001 — Permission Matrix

| Campo | Valore |
| --- | --- |
| Copre | Master prompt §72 D, §51 |
| Stato | Proposta |

## 1. Regole

1. **Just-in-time** (§51). Al primo avvio non si chiede nessun permesso. Ogni richiesta parte quando l'utente attiva una funzione che ne ha bisogno, ed è preceduta da una schermata di Mosaic che spiega a cosa serve, cosa sblocca e cosa succede se viene negato.
2. **Degrado esplicito.** Senza un permesso, la funzione mostra uno stato chiaro ("Permesso richiesto") e il modo per risolverlo. Mai un errore generico, e mai dati incompleti presentati come completi.
3. **Minimo necessario.** I permessi opzionali restano opzionali.
4. **Firma stabile obbligatoria.** TCC e Portachiavi associano i permessi alla firma del codice: con build firmate ad hoc, i permessi si perdono a ogni build (R1).
5. **Verifica continua.** L'utente può revocare un permesso in qualsiasi momento, quindi il Permission Center ricontrolla gli stati quando l'app torna attiva e prima di ogni operazione che ne dipende.

Stati (§51): **Concesso** · **Mancante** · **Limitato** (per esempio solo alcune cartelle) · **Errore** (verifica fallita) · **Non ancora richiesto** · **Non applicabile**.

## 2. Matrice

| # | Permesso (Impostazioni di Sistema) | Meccanismo | Funzioni che lo usano | Necessità | Quando si chiede | Se negato | Rilevamento | Milestone |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| P1 | Accesso completo al disco | TCC `SystemPolicyAllFiles`. Non si può chiedere via API: Mosaic apre le Impostazioni e spiega come aggiungere l'app; dopo la concessione serve riavviare Mosaic | Apple Mail, Mail Diagnostics; sorgenti che includono aree protette; (F2) residui in `~/Library/Containers`, alcune letture di Time Machine, Note tramite database | **Obbligatorio per Apple Mail**, altrimenti opzionale | Quando si attiva la sorgente Apple Mail o si sceglie l'intera cartella Inizio | Mail Search non disponibile, con istruzioni; le sorgenti di file usano i permessi per cartella | Tentativo di leggere un percorso protetto, per esempio l'elenco di `~/Library/Mail` (`EPERM`) | M5 (M2 se si sceglie l'intera home) |
| P2 | File e cartelle: Scrivania, Documenti, Download | TCC `SystemPolicyDesktopFolder`, `…DocumentsFolder`, `…DownloadsFolder`; il prompt di sistema compare al primo accesso | Sources, Search, Declutter, Organizer | Per sorgente | Quando si aggiunge la sorgente (prima scansione) | La sorgente resta in stato "Permesso richiesto" | L'accesso restituisce `EPERM` | M2 |
| P3 | Volumi rimovibili, volumi di rete | TCC `SystemPolicyRemovableVolumes`, `…NetworkVolumes` | Dischi esterni e NAS come sorgenti | Per sorgente | Al primo accesso a `/Volumes/…` | La sorgente resta in stato "Permesso richiesto" | L'accesso restituisce `EPERM` | M2 |
| P4 | File gestiti da provider cloud | Prompt "accedere ai file gestiti da Google Drive" (da Sonoma), sotto File e cartelle | Sorgenti Google Drive, OneDrive, Dropbox | Per sorgente | Quando si aggiunge la sorgente | La sorgente cloud resta in stato "Permesso richiesto" | L'accesso restituisce un errore di permesso | M2 |
| P5 | Monitoraggio dell'input | TCC `ListenEvent`, tramite `IOHIDCheckAccess` e `IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)` | Keyboard Manager: capire quale tastiera sta scrivendo | Opzionale | Quando si attiva "cambia layout mentre scrivo" | Il layout cambia solo al collegamento o scollegamento della tastiera | `IOHIDCheckAccess` | M4 |
| P6 | Accessibilità | TCC `Accessibility`, tramite `AXIsProcessTrustedWithOptions` | (F2) Clipboard: incollare nell'app in primo piano; Activity Timeline: documento attivo; Resume Work: posizione delle finestre. Opzionale anche per una modalità event tap del Keyboard Manager | Opzionale | Quando si attiva una di queste funzioni | Clipboard copia invece di incollare; la timeline non registra il documento in primo piano | `AXIsProcessTrusted` | M11–M12 |
| P7 | Automazione (Apple Events) | TCC `AppleEvents`, un consenso per ogni app di destinazione | (F2) Note via AppleScript | Opzionale | Quando si attiva la sorgente Note | Note non ricercabili | Errore `-1743` | M16 |
| P8 | Contatti | Contacts.framework | Ricerca dei contatti; risoluzione dei mittenti ("Marco") | Opzionale | Quando si attivano i contatti nella ricerca o alla prima query su una persona | Le persone si riconoscono solo dalle intestazioni delle mail | `CNContactStore.authorizationStatus` | M5 |
| P9 | Calendari | EventKit, accesso completo | Ricerca degli eventi; (F2) Related Items, Work Sessions | Opzionale | Quando si attiva la sorgente Calendario | Nessun evento nei risultati | `EKEventStore.authorizationStatus` | M9 |
| P10 | Promemoria | EventKit | Ricerca dei promemoria | Opzionale | Quando si attiva la sorgente | Nessun promemoria nei risultati | Come P9 | M9 |
| P11 | Notifiche | UserNotifications | Alert Center | Opzionale | Alla prima regola di alert attivata | Gli avvisi compaiono solo in Mosaic e in menu bar | `getNotificationSettings` | M6 |
| P12 | Elementi login, esecuzione in background | `SMAppService.mainApp`; notifica di sistema, gestione in Impostazioni → Generali → Elementi login | Avvio al login, lavoro in background | Consigliato | All'ultimo passo dell'onboarding | Mosaic lavora solo quando è aperta | `SMAppService.status` | M1 |
| P13 | Rete locale | Privacy della rete locale (macOS 15+), `NSLocalNetworkUsageDescription` | Raggiungibilità di NAS e SMB, destinazioni LAN nella sezione Rete | Opzionale | Al primo probe verso la LAN | Lo stato del NAS si basa solo su "montato" o "non montato" | Errore di connessione dovuto alla policy | M6 |
| P14 | Servizi di localizzazione | CoreLocation | Nome della rete Wi-Fi (SSID) e storico per rete | Opzionale | Quando si attiva "mostra il nome della rete Wi-Fi" | Si vedono interfaccia e IP, senza SSID | `CLLocationManager.authorizationStatus` | M15 |
| P15 | Gestione app | TCC `SystemPolicyAppBundles` (macOS 13+) | (F2) Disinstallazione delle app | Opzionale | Alla prima disinstallazione | Istruzioni per la rimozione manuale | Errore di scrittura sul bundle | M14 |
| P16 | Consenso agli appunti (macOS 26) | `NSPasteboard.accessBehavior` | (F2) Clipboard Manager | Obbligatorio per la cronologia | Quando si attiva il Clipboard Manager | Nessuna cronologia | `accessBehavior` | M11 |
| P17 | Autorizzazione di amministratore | Richiesta per la singola operazione | (F2) Pulizie di sistema, installazione degli aggiornamenti di macOS | Per operazione | Solo durante l'operazione | L'operazione non viene eseguita | — | M14 |
| P18 | Portachiavi | Elementi propri, con accesso legato alla firma | Chiave di cifratura dei database, chiavi API, token | Implicito | — | — | — | M0 |
| P19 | Apple Intelligence | Impostazione di sistema, non TCC | Foundation Models | Opzionale | In Diagnostica e nelle impostazioni AI | Regole, Ollama o cloud, secondo la policy | `SystemLanguageModel.default.availability` | M3 |

**Nessun permesso** serve per: API di Termica e di Ollama su loopback, Spotlight, metriche di sistema, batteria, tasto rapido globale, notifiche di collegamento delle tastiere (da confermare in S4).

**Mai richiesti**: Registrazione dello schermo, Fotocamera, Microfono, Foto, Bluetooth, Endpoint Security, Strumenti per sviluppatori.

## 3. Matrice inversa: funzione → permessi

| Funzione | Obbligatori | Opzionali |
| --- | --- | --- |
| Universal Search (file) | P2, P3, P4 per le sorgenti scelte | P1, P8, P9, P10 |
| Sources | P2, P3, P4 per sorgente | P1 |
| Full-text, OCR, semantico | Gli stessi di Sources | P19 (interpretazione del linguaggio naturale) |
| Mail Search, Mail Diagnostics | **P1** | P8 |
| Keyboard Manager | — | P5 |
| Declutter, Smart Organizer | P2, P3, P4 per le cartelle analizzate | P1 |
| System Health | — | — (Termica non richiede permessi) |
| Menu bar | — | P12 |
| Alert Center | — | P11 |
| Diagnostics & Repair | — | P13 (NAS) |
| Network (base) | — | P13, P14 |
| Clipboard (F2) | P16 | P6 |
| Activity Timeline, Resume Work (F2) | — | P6 |
| Applications, Maintenance (F2) | — | P1, P15, P17 |
| Note (F2) | P7 oppure P1 | — |

## 4. Flusso della richiesta just-in-time

1. L'utente attiva una funzione.
2. `PermissionGate` controlla lo stato; se il permesso è *Concesso*, la funzione parte.
3. Altrimenti compare la scheda di Mosaic: a cosa serve, cosa sblocca, cosa succede senza, con i pulsanti "Concedi" e "Non ora".
4. "Concedi" avvia il prompt di sistema. Per P1 e P5 apre invece il pannello giusto delle Impostazioni con le istruzioni; per P1 ricorda anche di riavviare Mosaic.
5. Al ritorno Mosaic ricontrolla. Se il permesso manca ancora, la funzione resta nello stato ridotto e il permesso compare nella checklist del Permission Center.
