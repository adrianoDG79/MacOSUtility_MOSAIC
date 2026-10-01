# MOS-SEC-001 — Security & Privacy Model

| Campo | Valore |
| --- | --- |
| Copre | Master prompt §59–§63; §32, §48, §56 |
| Stato | Proposta |

## 1. Principi (§59)

Mosaic si basa su questi principi: local-first, accesso minimo, nessun upload silenzioso, nessuna telemetria nascosta, AI trasparente, esclusioni chiare, retention configurabile, pausa e cancellazione facili.

## 2. Classificazione dei dati

| Classe | Esempi | Trattamento |
| --- | --- | --- |
| C0, configurazione | Preferenze, layout, soglie | In `core.db`; esportabile |
| C1, metadati | Nomi e percorsi dei file, oggetti e mittenti delle mail | Possono essere sensibili, quindi cifrati a riposo (D7) |
| C2, contenuto | Testo di documenti e mail, OCR, embedding | Cifrati a riposo; mai nei log; inviati al cloud solo se la policy lo consente |
| C3, altamente sensibile | Appunti, timeline, token, chiavi, prompt che includono contenuti | Cifrati; esclusi dal backup standard; sospesi in Private Mode dove applicabile |

## 3. Minacce e contromisure

| # | Minaccia | Contromisure |
| --- | --- | --- |
| T1 | Un altro processo dell'utente legge l'indice di Mosaic, che contiene dati protetti da TCC come le mail, aggirando di fatto il Full Disk Access | Database cifrati con SQLCipher e chiave nel Portachiavi, legata alla firma di Mosaic; file con permessi `0600`; esportazioni in chiaro solo dopo conferma |
| T2 | Un file malevolo sfrutta un parser (PDF, MIME, Office) | Parsing solo nell'estrattore XPC: sandbox, niente rete, nessun accesso al filesystem oltre ai descrittori ricevuti, timeout e limiti di memoria; Hardened Runtime |
| T3 | Prompt injection da documenti o mail verso l'Assistant | Risultati degli strumenti marcati come dati non fidati; nessuna azione senza approvazione; strumenti in sola lettura |
| T4 | Esfiltrazione di dati tramite l'AI in cloud | Policy restrittive per default, consenso con anteprima, minimizzazione e oscuramento, audit delle chiamate |
| T5 | Bug distruttivo | Safety Engine, journal, precondizioni, Cestino e quarantena, test solo in directory temporanee |
| T6 | Segreti nei log | `os.Logger` con `privacy: .private`; niente contenuti, token o appunti nei log; controllo dei log nei test |
| T7 | Dipendenze compromesse | Poche dipendenze, versioni bloccate in `Package.resolved`, revisione delle licenze, nessun plugin caricato a runtime |
| T8 | Abuso dell'IPC | Mosaic non apre porte di rete; XPC con verifica della firma del processo collegato |
| T9 | Backup esportati letti da terzi | Backup sensibili cifrati con password (§56); segreti esclusi, salvo scelta esplicita |
| T10 | Integrazione con Termica | Sola lettura su loopback; Mosaic non modifica mai le impostazioni di Termica (vedi le osservazioni in MOS-TRM-001) |
| T11 | Canale di aggiornamento, quando esisterà | Sparkle con firme EdDSA e HTTPS |

## 4. Controlli

- **Firma e runtime.** Hardened Runtime e library validation; nessun entitlement che abiliti il JIT o disattivi la validazione.
- **Segreti** (§60). Nel Portachiavi, con accessibilità `AfterFirstUnlockThisDeviceOnly`. Mai nel codice, nei file di configurazione, nei log o in campi SQLite in chiaro.
- **Cifratura a riposo** (D7). SQLCipher (AES-256) per tutti i database di Mosaic, con una chiave casuale da 256 bit nel Portachiavi. Se lo spike S1 fallisce, i database restano in chiaro sotto FileVault, e il rischio T1 dovrà essere accettato esplicitamente da te.
- **Keyboard Manager.** Il callback HID legge solo l'identità del dispositivo; il valore dei tasti non viene letto, salvato né registrato. Un test automatico lo verifica.
- **Clipboard (F2).** Esclude in automatico i contenuti che i password manager marcano come nascosti o transitori (tipi `org.nspasteboard.ConcealedType` e `org.nspasteboard.TransientType`). Prevede una lista di app escluse, pausa, Private Mode e retention (§32).
- **Cancellazione.** Sono disponibili "Cancella tutti i dati di Mosaic" e pulizie per singolo modulo; la chiave nel Portachiavi viene rimossa insieme ai database.

## 5. Private Mode (§46, §59)

Quando la Private Mode è attiva, un indicatore resta visibile in menu bar e nella Home. Sono sospese la cronologia delle ricerche e la frecency, e in Fase 2 anche l'Activity Timeline, la cronologia degli appunti, lo storico dell'Assistant e ogni altra storia comportamentale opzionale. Proseguono le funzioni che non registrano il comportamento dell'utente (indicizzazione dei file, salute del sistema) e l'audit delle operazioni di Mosaic.
