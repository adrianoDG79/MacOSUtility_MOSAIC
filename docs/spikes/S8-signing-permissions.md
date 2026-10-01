# S8 — Firma e permessi dopo le rebuild

| Campo | Valore |
| --- | --- |
| Obiettivo | Verificare se i permessi TCC (Accesso completo al disco, Monitoraggio dell'input) e l'Hardened Runtime sopravvivono a una ricompilazione, con firma stabile (Apple Development, Team ID fisso) invece che ad hoc (R1) |
| Esito | **GO** |
| Prova | Mosaic Probe, tab Firma e permessi; dati in `~/Library/Application Support/MosaicProbe/signing-history.json` |

## Metodo

1. Creato il certificato Apple Development in Xcode; Team ID `HQJWK6BU8M` ricavato dal campo OU del certificato (`security find-certificate`).
2. Creato `Config/Signing.local.xcconfig` (non versionato) con `DEVELOPMENT_TEAM` e `CODE_SIGN_IDENTITY = Apple Development`.
3. Prima build e installazione in `/Applications` (`INSTALL=1 Spikes/Probe/build.sh`); concesso Accesso completo al disco e rete locale; prima registrazione in app.
4. Seconda build dagli stessi sorgenti, nessuna modifica al codice; reinstallazione; seconda registrazione in app, senza toccare i permessi di sistema nel frattempo (a parte Input Monitoring, concesso in precedenza per lo spike S4).

## Risultati

| Misura | Prima build (29/09) | Seconda build (01/10) |
| --- | --- | --- |
| Team ID | HQJWK6BU8M | HQJWK6BU8M |
| cdhash | `eab54342abb4f801` | `eab54342abb4f801` (identico) |
| Hardened Runtime | attivo | attivo |
| Ad hoc | no | no |
| Full Disk Access | concesso | **concesso** |
| In `/Applications` | sì | sì |

## Interpretazione

- **Full Disk Access è sopravvissuto alla rebuild**, con la stessa firma (Team ID fisso, non ad hoc). Questo è il risultato che conta per R1: una firma stabile risolve il problema di perdere i permessi TCC a ogni ricompilazione.
- **cdhash identico tra le due build**: il processo di build è deterministico a parità di sorgenti, environment e toolchain. Non è l'elemento su cui TCC si basa per riconoscere l'app (che usa il code requirement, ancorato al Team ID, non l'hash esatto), ma conferma indirettamente la stabilità del processo.
- **Hardened Runtime è rimasto attivo** su entrambe le build, confermando la conclusione di S1: serve una firma di team, non ad hoc, per usare SQLCipher.framework con library validation attiva.

## Limiti

- La rete locale non è stata riverificata nella seconda registrazione (campo "non verificata"), per scelta nella sessione di prova, non per una regressione osservata.
- Non testato il comportamento con **Developer ID** (distribuzione fuori Xcode) né con notarizzazione: lo spike copre solo Apple Development, sufficiente per lo sviluppo ma non per la distribuzione finale.
- Test su una singola macchina; non verificato il comportamento dopo un cambio di Team (es. passaggio da Personal Team a un account Developer Program a pagamento).

## Conseguenze

- **R1 ridotto**: la mitigazione (certificato Apple Development prima di M0, bundle ID fissato, firma di team) è confermata efficace per l'ambiente di sviluppo.
- Per la distribuzione (fuori dall'ambito di M0) resta da verificare lo stesso comportamento con Developer ID e notarizzazione.
