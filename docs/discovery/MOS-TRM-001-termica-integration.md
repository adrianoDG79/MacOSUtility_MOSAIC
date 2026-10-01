# MOS-TRM-001 — Integrazione con Termica

| Campo | Valore |
| --- | --- |
| Copre | Master prompt §38, §72 I |
| Stato | Approvata il 2026-09-29 (D5, ADR-011), sulla base dell'ispezione del codice dello stesso giorno |

## 1. Sintesi

Termica espone già un'**API HTTP locale** che, da loopback, non richiede autenticazione e fornisce stato istantaneo, storico e uno stream in tempo reale. È il primo livello dell'ordine di preferenza del §38 (API documentata o locale). Mosaic quindi si integra **tramite l'API, in sola lettura**, e ripiega sul **database in sola lettura** quando Termica non è in esecuzione. Mosaic non duplica il campionamento dei sensori, non scrive le impostazioni di Termica e funziona anche senza Termica.

## 2. Cosa è Termica (ispezione)

| Aspetto | Rilevato |
| --- | --- |
| Progetto | `../MonitoraggioConsumiMAC`, Tauri 2 (Rust con axum) e dashboard React/Vite |
| Bundle ID | `it.termica.monitor` |
| Eseguibile | `src-tauri/target/release/bundle/macos/Termica.app` (non installato in `/Applications`) |
| Avvio | LaunchAgent manuale `~/Library/LaunchAgents/Termica.plist` che punta alla cartella di build, più il plugin di avvio automatico di Tauri |
| Sensori | Crate `macmon`, ogni 2 s: temperatura media di CPU e GPU, utilizzo di CPU e GPU, potenza di CPU, GPU e SoC, RAM usata e totale, swap, ventole (nome, giri, massimo) |
| Storico | Aggregati al minuto in `~/Library/Application Support/it.termica.monitor/termica.sqlite3` (WAL) |
| Tabelle | `temperature_minutes` (minute_ts, sample_count, cpu_avg/min/max/last, gpu_*, cpu_usage_avg, gpu_usage_avg, cpu_power_avg, gpu_power_avg, soc_power_avg, ram_used_avg, swap_used_avg, soc_energy_wh); `fan_minutes` (minute_ts, fan_name, rpm_avg/min/max/last, max_rpm); `settings` (chiave `app`, JSON con soglie di 80 e 90 °C, porta, avvio automatico, prezzo dell'energia) |
| Schema | Senza versione: le colonne nuove si aggiungono con `ALTER TABLE` ignorando gli errori |
| Server | axum su `0.0.0.0:43127` |
| Avvisi propri | Notifiche alla soglia di avviso e a quella critica, dopo 3 campioni consecutivi, con isteresi di 5 °C per 5 minuti |

### API

| Endpoint | Metodo | Risposta | Autorizzazione |
| --- | --- | --- | --- |
| `/api/status` | GET | `LiveStatus`: connected, paused, timestamp, cpu/gpu_temp, cpu/gpu_usage, cpu/gpu/soc_power, ram_used, ram_total, swap_used, fans[], soglie, sample_error | Libera da loopback; PIN e cookie dalla LAN |
| `/api/history?from&to&resolution=minute\|hour\|day` | GET | `{points[], fans[]}` aggregati per intervallo | Come sopra |
| `/api/events` | GET (SSE) | `LiveStatus` a ogni campione (circa ogni 2 s), keep-alive ogni 15 s | Come sopra |
| `/api/settings` | GET, PUT | Impostazioni | Come sopra; il PUT verifica anche l'Origin. **Mosaic non lo usa** |
| `/api/auth/login`, `/api/auth/logout` | POST | Sessione | Per l'accesso dalla LAN |

## 3. Valutazione rispetto all'ordine del §38

| Livello | Disponibile | Valutazione |
| --- | --- | --- |
| 1. API documentata o locale | Sì | **Scelta**: contratto esplicito, nessun accoppiamento con lo schema interno, dati in tempo reale |
| 2. Database | Sì | **Ripiego** in sola lettura, per lo storico quando Termica non è in esecuzione |
| 3. File JSON o strutturati | No | — |
| 4. Log | Solo stderr | Non utile |

## 4. Contratto dell'adapter

```swift
protocol ThermalTelemetryProvider: Sendable {
    var availability: AsyncStream<ProviderAvailability> { get }   // available · degraded · unavailable(reason)
    func snapshot() async throws -> ThermalSnapshot                // da /api/status
    func live() -> AsyncThrowingStream<ThermalSnapshot, Error>     // da /api/events
    func history(_ range: DateInterval,
                 resolution: HistoryResolution) async throws -> ThermalHistory
    func openOriginalDashboard() async throws
}
```

- **Scoperta.** L'app si trova per bundle ID tramite LaunchServices, e `NSRunningApplication` dice se è in esecuzione. La porta si legge dalle impostazioni nel database, in sola lettura, con 43127 come valore di default.
- **Tolleranza.** Tutti i campi sono opzionali, come in Termica, e quelli sconosciuti vengono ignorati. Prima di usare il database se ne verifica lo schema con `PRAGMA table_info`.
- **Autenticazione.** Oggi da loopback non serve. L'adapter supporta comunque un token opzionale salvato nel Portachiavi, nel caso Termica cominci a richiederlo.
- **Cadenza.** Lo stream SSE è attivo solo mentre una vista Health è visibile. Altrimenti Mosaic interroga `/api/status` ogni 30 s per il Resource Manager, e chiede lo storico solo quando serve. I dati di Termica non vengono copiati nei database di Mosaic.
- **Apertura della dashboard.** Mosaic avvia o porta in primo piano `Termica.app`. Grazie al plugin *single instance*, un secondo avvio mostra la finestra della dashboard. Come ripiego si apre `http://127.0.0.1:43127`.

## 5. Stati e degradazione

| Stato | Causa | Comportamento di Mosaic |
| --- | --- | --- |
| Disponibile | API raggiungibile e `connected = true` | Temperature, ventole e potenza in Health, in menu bar e nel Resource Manager |
| Sensori in errore | `sample_error` valorizzato | Mostra il messaggio di Termica; il Resource Manager usa `thermalState` |
| In pausa | `paused = true` | Mostra "Termica in pausa" |
| Non in esecuzione | App presente, porta chiusa | Storico dal database; azione "Avvia Termica" |
| Non installata | Bundle non trovato | Health senza temperature, con `thermalState`; nessun errore bloccante |
| Incompatibile | Risposta non interpretabile | Stato "versione non supportata" in Diagnostics |

## 6. Correlazione (§37, §38)

Una domanda tipica: *"Perché ieri pomeriggio il Mac era caldo?"*

1. Da Termica: gli intervalli sopra la soglia di avviso o nel percentile più alto della giornata, con potenza e ventole.
2. Da Mosaic, negli stessi minuti: i processi che usavano più CPU (`process_minute`), i lavori di Mosaic in corso (OCR, embedding), gli eventi (volumi montati, app avviate, sospensione e risveglio), l'alimentazione e la batteria.
3. La risposta elenca le cause in ordine di contributo e dichiara i limiti: i processi sono campionati al minuto, e i dettagli completi esistono solo per i processi dell'utente.

Questa correlazione è il motivo per cui Mosaic campiona i processi: Termica non registra dati per processo.

## 7. Notifiche

Termica invia già le proprie notifiche termiche. Per evitare doppioni, quando Termica è attiva Mosaic **delega a Termica** gli avvisi termici, per default; le soglie di Termica vengono lette e mostrate. Mosaic genera avvisi termici propri solo se Termica manca o se lo scegli nelle impostazioni.

## 8. Osservazioni su Termica (fuori dallo scope di Mosaic)

Questi punti non cambiano l'integrazione, ma meritano un intervento su Termica:

1. **Esposizione in rete.** Il server ascolta su `0.0.0.0`, quindi la dashboard è raggiungibile da ogni rete a cui il Mac si collega, comprese quelle condivise come eduroam. È protetta da un PIN, con blocco per 5 minuti dopo 5 tentativi dallo stesso IP. Conviene comunque ascoltare su `127.0.0.1` per default e rendere l'accesso dalla LAN un'opzione.
2. **DNS rebinding.** Le richieste da loopback sono considerate fidate, e l'header `Host` non viene controllato. Una pagina web che fa risolvere il proprio dominio in `127.0.0.1` può quindi leggere lo stato e modificare le impostazioni con `PUT /api/settings`, perché Origin e Host coincidono. Alcuni browser attenuano il problema (Private Network Access), non tutti. Il rimedio è accettare solo valori di `Host` in un elenco consentito: localhost, 127.0.0.1 e gli IP LAN della macchina.
3. **Avvio fragile.** Il LaunchAgent punta alla cartella di build (un `cargo clean` lo rompe) e convive con quello creato dal plugin di avvio automatico. Conviene installare l'app in `/Applications` e tenere un solo meccanismo.
4. **Contratto.** Un endpoint `/api/version` o `/api/capabilities` e l'uso di `PRAGMA user_version` renderebbero l'integrazione più robusta.

**Stato (2026-09-29):** registrati come lavoro di follow-up. La priorità suggerita è portare il binding di default da `0.0.0.0` a `127.0.0.1`, rendendo l'esposizione in LAN un'opzione esplicita. Termica non viene modificata durante M0 né in seguito senza un'autorizzazione esplicita.
