# MOS-MAIL-001 — Mail Architecture

| Campo | Valore |
| --- | --- |
| Copre | Master prompt §13–§15, §54, §62 |
| Stato | Approvata il 2026-09-29 (D3 con modifica, ADR-009) |
| Milestone | Spike S5 in M0; implementazione in M5 |

## 1. Perimetro

| Sorgente | Fase | Accesso | Note |
| --- | --- | --- | --- |
| **Apple Mail** | V1 | Archivio locale, in sola lettura | Richiede Full Disk Access |
| **Thunderbird** | V1 | Profilo locale, in sola lettura | Sviluppato con fixture, poi validato su un profilo reale; oggi non installato sul Mac di sviluppo |
| Gmail API | Fase 2 | OAuth | Vincoli di Google: token di 7 giorni in stato *Testing*, scope *restricted* |
| Microsoft Graph | Fase 2 | OAuth | Possibile consenso dell'amministratore del tenant |
| IMAP diretto | Fase 2 | IMAP con OAuth o password per app | Chiamate di rete solo se attivate (D10) |

## 2. Principio: core indipendente dalle sorgenti

```text
Apple Mail adapter ─┐
Thunderbird adapter ├─► MailSourceAdapter ─► record normalizzati ─► pipeline di indicizzazione ─► ricerca
(F2) Gmail, Graph,  │     (contratto unico)     (MailMessageRecord)    (blocchi, FTS5, vettori)
     IMAP ──────────┘
```

Il core di indicizzazione e ricerca conosce solo il contratto `MailSourceAdapter` e i record normalizzati. Una nuova sorgente è un nuovo adapter e non richiede modifiche al core.

## 3. Contratto `MailSourceAdapter`

| Capacità | Descrizione |
| --- | --- |
| Scoperta | Trova archivi, account e cartelle disponibili; dichiara i permessi necessari |
| Enumerazione incrementale | Restituisce i messaggi nuovi, modificati o eliminati rispetto a un token di stato salvato |
| Lettura | Recupera intestazioni, corpo e allegati di un messaggio tramite il suo `source_locator` |
| Diagnostica | Fornisce conteggi e stati della sorgente: messaggi rilevati, messaggi con corpo parziale, stato del client, ultima modifica |
| Apertura nel client | Apre il messaggio nel client d'origine, quando il client lo consente |
| Salute | `available`, `degraded(reason)`, `unavailable(reason)`, `permissionRequired` |

Gli adapter sono **solo in lettura**: non scrivono mai negli archivi di Mail o di Thunderbird.

## 4. Record normalizzato

Ogni adapter produce `MailMessageRecord` con: account, cartella e ruolo della cartella, `Message-ID`, `In-Reply-To` e `References`, mittente, destinatari, CC, oggetto, date di invio e ricezione, flag, dimensione, `source_locator`, stato del corpo (`full`, `partial`, `missing`) e allegati (nome, tipo, dimensione, locator). La persistenza segue MOS-DM-001 §4.2 (`mail_account`, `mailbox`, `mail_message`, `mail_participant`, `mail_thread`, `mail_attachment`).

## 5. Adapter Apple Mail

| Aspetto | Approccio |
| --- | --- |
| Posizione | `~/Library/Mail/V*/`: la cartella V* cambia con le versioni di macOS (V12 su Sequoia) e si rileva a runtime, scegliendo quella che contiene `MailData/Envelope Index` |
| Metadati | `Envelope Index`, un database SQLite non documentato, aperto in sola lettura. Lo schema si rileva all'avvio (tabelle e colonne), con mappature per versione verificate da test |
| Contenuto | File `.emlx`: una riga con la lunghezza, il messaggio RFC 5322, poi un plist con i flag. `.partial.emlx` indica un messaggio senza allegati scaricati |
| Modifiche | FSEvents sulla cartella di Mail e confronto con il token di stato salvato |
| Apertura | URL `message:` con il `Message-ID` |
| Permesso | Full Disk Access (P1) |
| Ripieghi | Se lo schema di `Envelope Index` non è riconosciuto: scansione dei soli `.emlx`, più lenta ma indipendente dallo schema. Spotlight come ultimo ripiego per la ricerca |

## 6. Adapter Thunderbird

| Aspetto | Approccio |
| --- | --- |
| Profili | `~/Library/Thunderbird/profiles.ini` (sezioni `[Profile…]` e `[Install…]`, percorsi relativi o assoluti) |
| Archivi | `Mail/` per Local Folders e POP; `ImapMail/<server>/` per IMAP, solo se l'account conserva copie offline. Le sottocartelle stanno in directory `.sbd` |
| Formato | mbox per default (un file per cartella), maildir se configurato. Il file `.msf` accanto è l'indice riassuntivo di Thunderbird in formato Mork: non serve per indicizzare |
| Messaggi eliminati | Restano nel file mbox con il flag di cancellazione in `X-Mozilla-Status` finché Thunderbird non compatta la cartella: l'adapter li esclude |
| Compattazione | Riscrive il file mbox e cambia gli offset: l'adapter la riconosce da dimensione e data di modifica e riscansiona la cartella |
| Indice di Thunderbird | `global-messages-db.sqlite` (Gloda): si leggono le tabelle ordinarie, non quella full-text che usa un tokenizer proprio. Serve alla diagnostica "rilevati rispetto a indicizzati" (§15) |
| Apertura | Supporto dell'apertura diretta di un messaggio da verificare; ripiego: anteprima in Mosaic e apertura di Thunderbird |
| Permesso | Nessuno: `~/Library/Thunderbird` è fuori dalle aree protette da TCC |

**Sviluppo con fixture.** Un generatore di profili di prova, costruito sui formati documentati, produce: `profiles.ini`, cartelle mbox con MIME complessi, messaggi eliminati ma non compattati, una compattazione simulata, cartelle IMAP non sincronizzate offline e un database Gloda con indicizzazione parziale. I test dell'adapter girano su queste fixture. Prima del rilascio di V1 l'adapter si valida su un profilo reale, installando Thunderbird o usando una copia di un profilo (rischio R43).

## 7. Parser MIME condiviso

Gira nell'estrattore XPC e serve a entrambi gli adapter: RFC 5322 e RFC 2045–2049, encoded-words (RFC 2047), set di caratteri, quoted-printable e base64, parti multipart annidate, allegati e parti inline. È coperto da test con input malformati; un messaggio che manda in errore il parser viene segnato e saltato, senza fermare l'indicizzazione.

## 8. Mail Diagnostics (§15, §54)

Per ogni sorgente e cartella, Mail Diagnostics confronta i messaggi rilevati nel client, quelli indicizzati da Mosaic e, per Thunderbird, quelli indicizzati da Gloda. La causa viene classificata secondo il §15:

| Causa | Esempi di verifica |
| --- | --- |
| Indice Mosaic | Coda in ritardo, errori di estrazione, schema non riconosciuto |
| Client di posta | Gloda incompleto, compattazione in sospeso, archivio di Mail da ricostruire |
| Permessi | Full Disk Access mancante o revocato |
| Account disconnessi | Account presente senza sincronizzazioni recenti, cartelle IMAP senza copia offline |
| File non disponibili | Corpi parziali (`.partial.emlx`), file mancanti, volume non montato |

Esempio di esito, nello stile del §15: "Thunderbird Search — Degraded · rilevati 38.412 · indicizzati da Thunderbird 31.087 · mancanti 7.325 · causa probabile: indicizzazione globale di Thunderbird incompleta · azione consigliata: …".

## 9. Connettori della Fase 2

Gmail API, Microsoft Graph e IMAP implementano lo stesso `MailSourceAdapter`. I token stanno nel Portachiavi, le chiamate di rete si attivano solo per scelta esplicita dell'utente (D10), e i vincoli OAuth di ciascun fornitore vanno riverificati al momento dell'implementazione.

## 10. Privacy e sicurezza

- Nessun accesso di rete da parte degli adapter locali.
- I corpi e gli allegati indicizzati finiscono nei database cifrati di Mosaic (D7, se S1 lo conferma).
- I log non contengono mai indirizzi, oggetti o testo dei messaggi.
- Nessuna scrittura negli archivi dei client.

## 11. Verifica in M0 (spike S5)

- **Apple Mail, su dati reali:** cartella V*, schema di `Envelope Index`, conteggi, `.emlx` e `.partial.emlx`, tempi di lettura. Il rapporto contiene solo valori aggregati, niente contenuti né indirizzi.
- **Thunderbird, su fixture:** generatore di profili, lettura di mbox e dei flag di cancellazione, diagnostica rilevati/indicizzati.
