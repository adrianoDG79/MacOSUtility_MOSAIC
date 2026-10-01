# S9 — Versione minima di macOS

| Campo | Valore |
| --- | --- |
| Obiettivo | Stabilire se macOS 26 serve davvero al core o solo a capacità opzionali, e quali funzioni si perdono per ogni versione minima candidata (ADR-016) |
| Esito | **Raccomandazione: macOS 15 (Sequoia)**, da approvare. macOS 26 non serve al core |
| Codice | `Spikes/S9-DeploymentTarget/check.sh` |

## Metodo

- Compilazione reale di pacchetti e app su una copia del repository, con versione minima 12.0, 13.0 e 14.0 (quella attuale). 15 e 26 sono sovrainsiemi di 14.
- Inventario delle API previste per V1, con la versione di macOS che richiedono.

## Risultati della compilazione

| Versione minima | Esito | Errori |
| --- | --- | --- |
| 14.0 (attuale) | **Compila** | — |
| 13.0 | Il core compila; l'app no | Solo comodità della shell SwiftUI: `@Observable`, `@Environment(Type.self)` e `.environment(_:)` con oggetti Observation, `NSApp.activate()`. Tutte hanno alternative su 13 (`ObservableObject`, `activate(ignoringOtherApps:)`) |
| 12.0 | Non compila | Il core usa `OSAllocatedUnfairLock` (13+); servirebbero anche `MenuBarExtra`, `SMAppService` e la scena `Window` (13+) |

## Inventario per versione

| Richiede | Capacità | Uso in Mosaic | Se la versione è precedente |
| --- | --- | --- | --- |
| 13 | `SMAppService`, `MenuBarExtra`, Swift Charts, `NavigationSplitView`, `OSAllocatedUnfairLock` | Shell, avvio al login, grafici | Indispensabili: sotto 13 Mosaic non si costruisce |
| 14 | Observation, `SettingsLink`, `.inspector`, `XPCSession`, `NLContextualEmbedding`, accesso completo EventKit | Stato della UI, impostazioni, Inspector, XPC moderno | Su 13 servono alternative: `ObservableObject`, `NSXPCConnection`, API EventKit precedenti |
| 15 | `.defaultLaunchBehavior`, `Synchronization.Mutex` | Nessuna finestra all'avvio al login | Alternativa: chiudere la finestra in `applicationDidFinishLaunching` |
| 26 | Foundation Models, `RecognizeDocumentsRequest`, Liquid Glass, API `detect*` degli appunti, azioni App Intents in Spotlight | Arricchimento in linguaggio naturale, OCR strutturato, aspetto | Degrado: parser deterministico (vedi S7), `VNRecognizeTextRequest` senza tabelle e liste, materiali standard, solo Comandi Rapidi |
| 27 | Private Cloud Compute, modello on-device da 8K, protocollo `LanguageModel` | Opzionale | Non disponibile su 26 |

Indipendente dalla versione: SQLite arriva con SQLCipher (3.53.4), quindi FTS5 e trigram non dipendono dall'SQLite di sistema.

## Funzioni perse per ciascuna versione minima candidata

| Versione minima | Cosa si perde rispetto a macOS 26 | Valutazione |
| --- | --- | --- |
| **26** | Nulla | Esclude i Mac con Sequoia senza alcun beneficio per il core |
| **15** | Foundation Models, OCR strutturato, Liquid Glass, azioni in Spotlight: tutte con degrado previsto e rilevate a runtime | **Raccomandata:** core identico, sistema ancora aggiornato per la sicurezza |
| **14** | Come 15, più `.defaultLaunchBehavior` (con alternativa) | Compila già oggi; Sonoma sta uscendo dal periodo di aggiornamenti di sicurezza |
| **13** | Come 14, più riscrittura dello stato UI senza Observation, `NSXPCConnection` invece di `XPCSession`, niente `NLContextualEmbedding` | Sconsigliata: costo di codice e sistema senza aggiornamenti di sicurezza |

## Raccomandazione

**Versione minima macOS 15**, solo Apple Silicon, con rilevamento a runtime (`#available`) delle capacità di macOS 26 e 27.

Motivi:

- il core non ha bisogno di più di macOS 14;
- un'app con Full Disk Access che indicizza la posta non dovrebbe puntare a sistemi senza aggiornamenti di sicurezza (Apple di norma aggiorna la versione corrente e le due precedenti);
- 15 non costa nulla in più rispetto a 14 nel codice di oggi.

## Limiti

La compilazione è verificata; l'esecuzione su macOS 14 o 15 no, perché questo Mac ha 26.6.2 e non c'è una macchina virtuale. Prima di fissare definitivamente il target, M1 dovrebbe prevedere una prova in una VM macOS 15 (Virtualization.framework).
