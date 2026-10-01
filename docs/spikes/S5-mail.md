# S5 — Posta: Apple Mail su dati reali, Thunderbird su fixture

| Campo | Valore |
| --- | --- |
| Obiettivo | Confermare la fattibilità dei due adapter di V1 (D3, MOS-MAIL-001) |
| Esito | **Thunderbird: GO su fixture.** Apple Mail: in attesa della prova interattiva con Mosaic Probe, che richiede il tuo Full Disk Access |
| Codice | `Spikes/S5-Thunderbird/` (prototipo e test), `Spikes/Probe/App/MailTab.swift` (analisi di Apple Mail) |

## Thunderbird (su fixture)

Come stabilito da D3, Thunderbird si sviluppa su fixture perché non è installato su questo Mac. Il prototipo del lettore copre:

| Aspetto | Implementazione | Test |
| --- | --- | --- |
| Profili | `profiles.ini`, con il profilo predefinito preso dalla sezione `[Install…]` e percorsi relativi | ✔ |
| Messaggi | mbox: un messaggio inizia con una riga `From ` preceduta da una riga vuota; le righe `>From ` e le righe `From ` nel corpo non sono separatori | ✔ |
| Messaggi eliminati non compattati | Bit 0x0008 di `X-Mozilla-Status`: il messaggio viene escluso | ✔ |
| Cartelle | Da URI (`mailbox://…/Inbox/Progetti`, `imap://…/INBOX`) a file (`Mail/Local Folders/Inbox.sbd/Progetti`, `ImapMail/<server>/INBOX`) | ✔ |
| Indice di Thunderbird | `global-messages-db.sqlite`: tabelle `folderLocations` e `messages`, righe `deleted` escluse | ✔ |
| Diagnostica del §15 | Messaggi rilevati rispetto a quelli indicizzati per cartella; "degraded" se ne manca più del 5% | ✔ |
| Compattazione | Dimensione e data di modifica cambiano; riconteggio corretto | ✔ |

**5 test su 5 superati.**

Non ancora verificato (rischio R43):

- un profilo Thunderbird reale;
- l'archiviazione "un file per messaggio" (maildir);
- file mbox molto grandi (l'adapter reale deve leggere a flusso, non caricare il file intero);
- cartelle IMAP non conservate offline;
- la tabella full-text di Gloda, che usa un tokenizer proprio e non viene letta.

## Apple Mail (in attesa)

La scheda "Apple Mail" di Mosaic Probe, con Full Disk Access concesso all'app, riporta solo:

- cartelle V* presenti e cartella scelta;
- dimensione di `Envelope Index`;
- nomi di tabelle e colonne dello schema;
- conteggi di messaggi, caselle ed eliminati;
- file `.emlx` completi e parziali, con i relativi byte;
- verifica strutturale di un campione di 300 file e tempi.

Nessun indirizzo, oggetto o contenuto esce dal Mac né finisce nei risultati.

Da confermare con la prova:

- nome della cartella V* su macOS 26 (V12 su Sequoia);
- schema di `Envelope Index`;
- rapporto tra messaggi indicizzati da Mail e file `.emlx`;
- quota di corpi parziali.
