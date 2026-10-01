# MOS-UX-001 — UI Information Architecture

| Campo | Valore |
| --- | --- |
| Copre | Master prompt §72 J; §5–§7, §33, §46–§47, §55 |
| Stato | Approvata il 2026-09-29. Direzione visiva A in esplorazione, non definitiva (ADR-017) |

## 1. Principi (§5)

- **Nativo e sobrio.** Controlli di sistema, SF Pro e SF Symbols. Materiali e Liquid Glass di macOS 26 per sidebar e toolbar, contenuto su superfici pulite. Pochi riquadri, separatori leggeri, molto spazio.
- **Due densità.** Le aree normali sono ariose. Le aree tecniche (Health, Termica, Network, Index Health, Storage, Diagnostics) sono più dense, con grafici Swift Charts e cifre tabulari (SF Mono per le metriche).
- **Prima la tastiera.** Tutto è raggiungibile senza mouse.
- **Animazioni solo quando spiegano qualcosa**: cambi di stato, avanzamento, comparsa di un problema.
- **Onestà.** Nessuna funzione finta. Un modulo non ancora pronto non compare; una funzione senza permesso mostra il proprio stato e come risolverlo.
- Tema chiaro, scuro e automatico.

## 2. Superfici

| Superficie | Ruolo |
| --- | --- |
| **Finestra principale** | `NavigationSplitView`: sidebar, contenuto e Inspector a destra (`⌘I`) |
| **Pannello Universal Search** | Pannello fluttuante sopra qualsiasi app (`⌥Space`, configurabile): ricerca, comandi, anteprima |
| **Menu bar** | Stato sintetico e azioni rapide, non una seconda dashboard (§47) |
| **Notifiche** | Native, per severità (§45) |
| **Impostazioni** | Finestra Settings standard, con una sezione per modulo |
| **Onboarding** | Finestra dedicata al primo avvio, riapribile in seguito |
| **Fogli** | Anteprima e approvazione delle operazioni, consenso AI, richieste di permesso |

## 3. Navigazione

```text
Mosaic
├── Home
├── Cerca                       ricerca estesa con filtri e ricerche salvate
├── Assistant                   (M10)
│
├── LAVORO                      (Fase 2)
│   ├── Progetti
│   ├── Timeline
│   ├── Sessioni
│   └── Appunti
│
├── FILE
│   ├── Sorgenti
│   ├── Declutter               categorie, duplicati, spazio recuperabile
│   ├── Organizer               proposte, regole, storico
│   └── Automazioni
│
├── MAIL
│   ├── Ricerca mail
│   ├── Sorgenti mail
│   └── Salute mail
│
├── MAC
│   ├── Salute                  CPU, memoria, batteria, processi, Termica
│   ├── Archiviazione
│   ├── Rete                    (base in V1, storico in Fase 2)
│   ├── Tastiere
│   ├── Applicazioni            (Fase 2)
│   └── Aggiornamenti           (Fase 2)
│
└── CONTROLLO
    ├── Indice
    ├── Diagnostica
    ├── Permessi
    ├── Undo Center
    ├── Registro attività
    └── Avvisi
```

La modalità attiva (Work, Focus, Private, Presentation, Travel) non è una pagina: è un controllo globale nella toolbar e in menu bar, e la configurazione dei Modes sta nelle Impostazioni. Scorciatoie: `⌘1…⌘9` per le prime voci della sidebar, `⌘K` per le azioni sul contesto, `⌘F` per cercare nella vista corrente.

## 4. Home (§7)

Una griglia di widget in tre misure (piccolo, medio, largo). I widget si possono spostare, ridimensionare, nascondere e aggiungere, e si può ripristinare il layout di default.

Il layout di default proposto per V1 è questo:

| Riga | Widget |
| --- | --- |
| 1 | Universal Search (largo) · Avvisi (compare solo se ci sono problemi) |
| 2 | Salute del Mac (medio) · Archiviazione (piccolo) · Termica (piccolo) |
| 3 | Indice (piccolo) · Salute mail (piccolo) · Suggerimenti Declutter (medio) |
| 4 | Azioni rapide (medio) · Tastiera (piccolo) |

In Fase 2 si aggiungono Riprendi lavoro, Attività recente, Progetti, Appunti, Rete e Automazioni. Un avviso **critico** sale in cima con evidenza finché non viene risolto o preso in carico, poi torna al suo posto.

## 5. Universal Search e Command Palette (§8, §33)

```text
┌──────────────────────────────────────────────────────────────┐
│ 🔍 proposta nuses                                  ⌘K Azioni │
├──────────────────────────────┬───────────────────────────────┤
│ MIGLIORE CORRISPONDENZA      │                               │
│ ▸ NUSES_Proposal_v3.pdf      │   anteprima Quick Look        │
│ DOCUMENTI                    │                               │
│   NUSES_Proposal_v3_final.pdf│   Percorso · 2,4 MB · 3 ver.  │
│   Proposal_NUSES_2025.docx   │   Aperto ieri 17:42           │
│ MAIL                         │                               │
│   Marco R. — "Proposta NUSES"│                               │
│ COMANDI                      │                               │
│   > Trova versioni di …      │                               │
├──────────────────────────────┴───────────────────────────────┤
│ ↩ Apri  ⌘↩ Mostra nel Finder  Spazio Quick Look  ⌘C Percorso │
└──────────────────────────────────────────────────────────────┘
```

- Risultati raggruppati per tipo, con la "migliore corrispondenza" in cima.
- `↑↓` sposta la selezione, `⌘↑↓` salta tra le sezioni, `Tab` applica un filtro suggerito, `⌘K` apre le azioni sull'elemento.
- `>` apre la Command Palette (`> reindex mail`, `> clean downloads`, `> system health` …). I comandi sono gli stessi del registro, con parametri e completamento automatico.
- Le frasi in linguaggio naturale mostrano la propria interpretazione come chip modificabili sopra i risultati.
- Le azioni con rischio R2 o superiore aprono l'anteprima del Safety Engine, senza mai eseguire direttamente.

## 6. Menu bar (§47)

Icona template monocromatica. Un piccolo segno indica gli avvisi e un'icona dedicata la Private Mode; niente animazioni continue. Il menu mostra solo le voci scelte dall'utente, per esempio:

```text
Mac — Normale
CPU 18% · RAM 62% · 54 °C · Disco 71% · Batteria 83%
Tastiera: Logitech → IT
Indice: in salute
──────────────
Cerca…              ⌥Space
Appunti…            (F2)
Pulisci…
Salute
Tastiera ▸          override temporaneo
Reindex
Modalità ▸          Work · Focus · Private · Presentation · Travel
Pausa attività
Apri Mosaic
```

## 7. Onboarding (§55)

Passi: Benvenuto → Sorgenti → Sorgenti mail → Tastiere → Permessi (spiega l'approccio just-in-time, senza richieste in blocco) → Preferenza AI e privacy → Declutter → Termica (rilevata o meno) → Layout della Home → Avvio dell'indicizzazione.

- Ogni passo ha **Salta** e **Configura dopo**. Un passo compare solo quando il suo modulo esiste davvero nella build.
- Una checklist finale elenca ciò che resta da configurare e rimane disponibile nella Home.
- L'indicizzazione parte in background, quindi Mosaic è usabile da subito.

## 8. Mosaic Modes (§46)

| Modalità | Effetti principali |
| --- | --- |
| Work | Tutto attivo |
| Focus | Solo notifiche critiche; widget non essenziali nascosti |
| Private | Storia comportamentale sospesa (MOS-SEC-001 §5), con un indicatore sempre visibile |
| Presentation | Nessuna notifica (quelle critiche restano in coda e compaiono all'uscita); icona neutra in menu bar |
| Travel | Resource Manager su Eco, meno probe di rete, niente lavoro massivo a batteria |
| Custom | Tutti gli effetti configurabili |

## 9. Pattern ricorrenti

- **Suggerisci → Anteprima → Approva** (Organizer, Declutter, rinomina). Elenco delle modifiche con il prima e il dopo, selezione parziale, rischio evidenziato, byte coinvolti, reversibilità dichiarata.
- **Stati delle sorgenti.** Online, Offline, Indicizzazione, In pausa, Errore, Permesso richiesto, sempre con la causa e l'azione possibile.
- **Consenso AI.** Un foglio con il testo esatto e il fornitore.
- **Stati vuoti onesti.** Spiegano cosa manca e come ottenerlo, senza dati d'esempio spacciati per reali.

## 10. Identità visiva (§6): tre direzioni tra cui scegliere

| Direzione | Idea | Menu bar |
| --- | --- | --- |
| **A. Tessere convergenti** | Poche tessere irregolari, non una griglia, che convergono verso una tessera centrale luminosa: frammenti che diventano un insieme | Tre tessere stilizzate |
| **B. M a mosaico** | Una "M" composta da tre tessere inclinate, separate da fughe sottili | La M semplificata |
| **C. Tessera connessa** | Una sola tessera, con linee sottili che la collegano ad altre appena accennate: "Connected" | Una tessera con un punto di connessione |

Tutte seguono la griglia delle icone di macOS (squircle), restano leggibili a 16 px e hanno varianti per tema chiaro e scuro. Il wordmark "Mosaic" usa SF Pro Display. La raccomandazione è **A**, perché richiama "Your Mac. Connected." senza sembrare una griglia generica.

**Decisione del 2026-09-29:** l'esplorazione iniziale parte dalla direzione **A**. L'icona non è definitiva: in M1 si presentano alternative visive per la revisione, prima di sceglierla.

## 11. Accessibilità e lingua

VoiceOver su tutti i controlli, contrasto verificato in entrambi i temi, rispetto delle impostazioni "Riduci movimento" e della dimensione del testo. Interfaccia in italiano e inglese.
