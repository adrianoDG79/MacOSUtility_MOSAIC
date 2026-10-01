# S4 — Tastiere

| Campo | Valore |
| --- | --- |
| Obiettivo | Verificare la fattibilità del Keyboard Manager: rilevamento dei dispositivi HID, cambio automatico del layout per tastiera collegata, latenza percepita (MOS-MAC-001, ADR-012) |
| Esito | **GO** |
| Prova | Mosaic Probe, tab Tastiere; dati in `~/Library/Application Support/MosaicProbe/s4-keyboard.json` |

## Metodo

- Due sessioni: una a casa (tastiera esterna italiana, Logitech, collegamento via cavo/ricevitore USB) usata solo per verificare il rilevamento HID; una in ufficio (tastiera esterna U.S., stesso tipo di collegamento) usata per la misura definitiva.
- Mappatura assegnata: tastiera interna → Italiano – Pro, tastiera esterna → U.S. — scelta apposta per rendere visibile a schermo un cambio di layout software indipendente dall'etichettatura fisica dei tasti.
- Test del "primo tasto": il tasto fisico immediatamente a destra della L (riga ASDF…), che produce "ò" con Italiano – Pro attivo e ";" con U.S. attivo. 5 pressioni per tastiera, 3 giri (interna → esterna, ripetuto 3 volte): 25 pressioni totali, 5 cambi di tastiera misurati.
- Rilevamento dispositivi via `IOHIDManager` (notifiche di arrivo/rimozione); permesso di Monitoraggio dell'input richiesto e concesso tramite TCC.

## Risultati

| Misura | Valore |
| --- | --- |
| Dispositivi rilevati | Tastiera interna (Apple Inc., SPI) e tastiera esterna (Logitech, USB) — entrambe correttamente identificate |
| Mappatura applicata | `USB Keyboard → U.S.`, `Apple Internal Keyboard → Italiano – Pro` |
| Cambi di tastiera misurati | 5 |
| Latenza di switch, mediana | 37,9 ms |
| Latenza di switch, massima | 45,7 ms |
| Primo tasto dopo lo switch, errori | 0 su 5 |
| Tutte le pressioni, errori | 0 su 25 |
| Monitoraggio dell'input | Concesso |

## Interpretazione

- **Lo switch automatico per-dispositivo funziona**, con latenza ben sotto la soglia di percezione (qualche decina di millisecondi) e nessun errore di layout nei cambi misurati.
- **Rischio R47 risolto per la configurazione attuale.** Durante lo sviluppo era emerso un conflitto con la memoria per-documento di TSM (`Automatically switch to document's input source`, attiva di default in Pages/TextEdit): con quell'opzione attiva, il layout seguiva il documento invece che la tastiera fisica. Disattivandola nelle Impostazioni di sistema, il conflitto scompare e `per_context_input_source` risulta "disattivo" nei dati salvati. Resta da decidere in M9 se Mosaic debba disattivare quell'opzione in automatico (con consenso) quando il Keyboard Manager è attivo, dato che non è detto l'utente voglia rinunciare alla memoria per documento in generale.
- **Bug minore nell'app di prova**, non nel design: la mappatura salvata contiene una terza voce ridondante (`1133:49995:17825792 → Italiano-Pro`), probabile doppia chiave (nome generico vs. ID composito vendor:prodotto:posizione) per lo stesso dispositivo Logitech. Non ha causato errori nei risultati (0/25), ma va ripulito se il codice del probe viene riusato come base per il Keyboard Manager reale.
- **Rilevamento confermato su due tastiere Logitech fisicamente diverse** (casa e ufficio, product ID differenti, 49948 e 49995), entrambe correttamente viste come dispositivi HID distinti all'arrivo.

## Limiti

- Una sola marca di tastiera esterna testata (Logitech, ricevitore/cavo USB); non verificato con Bluetooth nativo o altre marche.
- Il test misura la correttezza del cambio software, non l'ergonomia reale di digitazione con layout "scambiati" rispetto all'etichettatura fisica dei tasti.
- Switch_latency misurata con il probe in primo piano e senza carico di sistema; da rivalidare con l'app reale in condizioni normali d'uso.

## Conseguenze

- **ADR-012 passa da "in attesa delle misure" ad accettabile**, con la nota su R47 da portare a design in M9 (gestione dell'opzione di sistema sulla memoria per-documento).
- Il bug di mappatura ridondante nel probe va corretto prima di riusare quel codice come base del Keyboard Manager.
