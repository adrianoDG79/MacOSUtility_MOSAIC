# Spike di M0

| Spike | Tema | Stato | Rapporto |
| --- | --- | --- | --- |
| S1 | SQLCipher con GRDB | **GO** | [S1-sqlcipher.md](S1-sqlcipher.md) |
| S2 | Servizi XPC, permessi, sandbox, file dataless | **GO** per XPC/sandbox; test del file dataless non eseguito | — |
| S3 | Scansione di massa e FSEvents | **GO** | [S3-crawl-fsevents.md](S3-crawl-fsevents.md) |
| S4 | Tastiere | **GO**: 0 errori su 25 pressioni, latenza di switch 38–46 ms | [S4-keyboard.md](S4-keyboard.md) |
| S5 | Posta | Thunderbird **GO** su fixture; Apple Mail **GO** (236.041 messaggi, 300/300 campioni ben formati) | [S5-mail.md](S5-mail.md) |
| S6 | Modelli di embedding | **Rosa ristretta**; candidato predefinito granite-embedding-278m | [S6-embeddings.md](S6-embeddings.md) |
| S7 | Foundation Models | **GO con revisione del design** | [S7-foundation-models.md](S7-foundation-models.md) |
| S8 | Firma e permessi dopo le rebuild | **GO**: Full Disk Access sopravvissuto alla rebuild con firma stabile | [S8-signing-permissions.md](S8-signing-permissions.md) |
| S9 | Versione minima di macOS | Raccomandazione: **macOS 15** | [S9-deployment-target.md](S9-deployment-target.md) |

## Sessione interattiva con Mosaic Probe (S2, S4, S5, S8)

Mosaic Probe riunisce i quattro spike che richiedono permessi o azioni manuali, così i permessi si concedono una volta sola. Salva solo valori aggregati in `~/Library/Application Support/MosaicProbe/`.

### Prima di cominciare

1. **Certificato**. In Xcode apri Settings → Accounts, aggiungi il tuo Apple ID, poi Manage Certificates → "+" → Apple Development.
2. **Firma locale**. Crea `Config/Signing.local.xcconfig`, che non è versionato:

   ```text
   DEVELOPMENT_TEAM = <il tuo Team ID, visibile in Xcode → Settings → Accounts>
   CODE_SIGN_IDENTITY = Apple Development
   ```

   Se Xcode chiede un profilo di provisioning, aggiungi anche `CODE_SIGN_STYLE = Automatic`. Senza certificato la prova funziona lo stesso con la firma ad hoc, ma S8 mostrerà solo che i permessi si perdono a ogni build.
3. **Compila e installa**:

   ```text
   INSTALL=1 Spikes/Probe/build.sh
   ```

   L'app va in `/Applications`, che serve per la prova sulla rete locale.

### Passi

1. **Firma e permessi**:
   - "Apri Accesso completo al disco", aggiungi Mosaic Probe e riaprila quando macOS lo chiede;
   - "Richiedi" il Monitoraggio dell'input, abilitalo nelle Impostazioni e riapri l'app;
   - "Verifica rete locale", consentendo la richiesta di sistema;
   - infine "Registra questa build".
2. **XPC e TCC**:
   - test 1, "Esegui";
   - test 2, scegli un PDF qualsiasi;
   - test 3, scegli in Google Drive un file **solo online** (icona a nuvola), consentendo l'accesso ai file di Google Drive se macOS lo chiede;
   - "Salva risultati".
3. **Apple Mail**: "Analizza", poi "Salva risultati".
4. **Tastiere**:
   - collega, scollega e ricollega la tastiera esterna;
   - "Avvia il rilevamento";
   - assegna Italiano – Pro alla tastiera interna e U.S. a quella esterna, poi attiva il cambio automatico;
   - esegui il test del primo tasto (tre giri);
   - "Salva risultati".
5. **Avvisami.** Ricompilo e reinstallo Mosaic Probe con la stessa firma; tu la riapri e premi di nuovo "Registra questa build". Il confronto dice se i permessi sopravvivono alla rebuild (S8).

### Nuovo rischio emerso il 2026-10-01: input source per documento

In Pages/TextEdit il layout della tastiera segue il **documento** (memoria TSM per campo di testo), non solo il dispositivo collegato: un documento "nato" in U.S. riapre in U.S. indipendentemente dalla tastiera fisica attiva in quel momento. Questo è in potenziale conflitto con lo switch automatico per-dispositivo previsto da ADR-012: TSM potrebbe riapplicare il proprio input source salvato dopo (o al posto di) quello impostato da Mosaic in risposta all'evento HID di arrivo tastiera.

- **Causa confermata e mitigata.** La voce di sistema "Automatically switch to document's input source" (Impostazioni → Tastiera → Sorgenti di input → Modifica…) era attiva; disattivandola il conflitto scompare.
- Nota di design per M9: valutare se il Keyboard Manager debba disattivare questa opzione in automatico (con consenso dell'utente) quando viene attivato, invece di lasciare il conflitto latente.
- Registrato come R47 in MOS-RISK-001, ora a probabilità bassa grazie alla mitigazione nota.

### Stato al 2026-09-29, fine sessione

- Certificato Apple Development creato ("MacBook, ADG2024"); Team ID `HQJWK6BU8M`; `Config/Signing.local.xcconfig` creato (non versionato).
- Mosaic Probe compilata e installata in `/Applications` con firma reale e Hardened Runtime attivo.
- **S8:** una registrazione salvata (FDA concesso, rete locale raggiunta, `adhoc: false`, `hardened_runtime: true`). Manca la rebuild di confronto: va rifatta una build, poi riaprire Mosaic Probe e premere di nuovo "Registra questa build".
- **S2:** test 1 e 2 eseguiti (esito atteso: XPC senza sandbox eredita FDA, XPC in sandbox bloccato). Test 3 (file solo online, dataless) non eseguito: nessun file del genere disponibile su Drive al momento della prova.
- **S5, Apple Mail:** eseguito con successo, dati salvati.
- **S4, tastiere: da rifare.** `input_monitoring` risulta "negato" nonostante il passo "Richiedi" sia stato eseguito, e la tastiera esterna non compare mai tra i dispositivi rilevati (solo quella interna). Prossima sessione:
  1. Impostazioni di sistema → Privacy e sicurezza → Monitoraggio dell'input → abilita **Mosaic Probe** manualmente (il pulsante "Richiedi" in app a volte non basta a far comparire la voce in lista);
  2. riapri Mosaic Probe;
  3. collega la tastiera esterna **prima** di premere "Avvia il rilevamento", cosicché compaia nella lista dispositivi;
  4. rifai il test del primo tasto (3 giri) e "Salva risultati".

### Pulizia dopo M0

```text
tccutil reset All it.mosaic.probe
rm -rf "/Applications/Mosaic Probe.app" ~/Library/Application\ Support/MosaicProbe
```
