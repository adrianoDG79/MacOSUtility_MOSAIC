# MOS-AI-001 — AI Architecture

| Campo | Valore |
| --- | --- |
| Copre | Master prompt §72 G; §9.4, §23, §25, §34–§36, §59 |
| Stato | Approvata con modifiche il 2026-09-29 (D6, D12). I modelli locali vanno confermati con S6 e S7 |
| ADR | ADR-008 (provider), ADR-015 (substrato dell'Assistant) |

## 1. Principi

1. **Locale per default.** Indicizzazione, OCR, embedding e classificazione non lasciano mai il Mac, salvo una tua scelta esplicita.
2. **Trasparenza.** Ogni risultato prodotto con l'AI indica dove è stato elaborato: *Sul dispositivo*, *Server locale (Ollama)*, *Private Cloud Compute*, oppure *Cloud* seguito dal nome del provider (§25, §35).
3. **Nessun invio silenzioso** (§59). Con la policy *Chiedi*, prima di ogni trasmissione vedi il provider e le informazioni esatte, già minimizzate, che verranno inviate.
4. **L'AI propone, il Safety Engine decide.** Nessun modello esegue modifiche. Le azioni proposte diventano `OperationPlan`, con anteprima e approvazione.
5. **Provider sostituibili.** Nessun provider è cablato nei moduli: i provider cloud implementano lo stesso protocollo, `CloudAIProvider`, e si scelgono in configurazione.

## 2. Architettura

```text
Moduli (Search, Organizer, Insights, Assistant…)
        │  richieste per compito: embed · classify · extractIntent · summarize · answer
        ▼
AI Runtime ──► Policy engine ──► (Chiedi) foglio di consenso con provider e dati esatti
        │
        ├── Provider locali   Foundation Models · Core ML (embedding) · Vision · NaturalLanguage · Ollama
        └── CloudAIProvider   OpenAIProvider (primo) · AnthropicProvider · Apple Private Cloud Compute · altri
```

- L'**AI Runtime** riceve richieste tipizzate per compito. Sceglie il provider consentito dalla policy, applica minimizzazione e oscuramento, chiede il consenso quando serve e registra l'audit.
- I moduli chiedono un compito, non un modello: cambiare provider non tocca il loro codice.

## 3. Provider

| Classe | Implementazione | Uso | Disponibilità |
| --- | --- | --- | --- |
| Sul dispositivo | **Foundation Models**, l'LLM di Apple Intelligence | Intenti di ricerca, classificazione, estrazione, brevi riassunti, domande semplici | macOS 26 con Apple Intelligence attiva; contesto di 4.096 token (8.192 con il nuovo modello) |
| Sul dispositivo | **Core ML**, con il modello di embedding scelto in S6 | Embedding di blocchi e query | Sempre; il modello si scarica una volta o viene incluso nell'app |
| Sul dispositivo | **Vision**, **NaturalLanguage**, `NSDataDetector` | OCR, lingua, entità, date | Sempre |
| Server locale | **Ollama** (`127.0.0.1:11434`) | Modelli più grandi, embedding alternativi | Se installato; su questo Mac c'è la versione 0.33.3 |
| Cloud | **`OpenAIProvider`**, prima implementazione di `CloudAIProvider` | Domande complesse, riassunti lunghi, ripiego per l'interpretazione delle query | Con chiave API nel Portachiavi e una policy che lo consente |
| Cloud | `AnthropicProvider`, Apple Private Cloud Compute (macOS 27), altri | Come sopra | Implementazioni successive, senza modifiche ai moduli |

### 3.1 Contratto `CloudAIProvider`

| Elemento | Contenuto |
| --- | --- |
| Identità | Id stabile, nome mostrato all'utente, fornitore |
| Capacità dichiarate | Output strutturato, chiamata di strumenti, streaming, dimensione del contesto, input di immagini |
| Trattamento dei dati | Testo mostrato nel foglio di consenso (conservazione, luogo dell'elaborazione), mantenuto dall'implementazione |
| Configurazione | Endpoint, modello, parametri; modificabili dall'utente |
| Credenziali | Solo dal Portachiavi, tramite `SecretsStore` |
| Operazioni | Richiesta completa, streaming, stima di token e costo |
| Errori | Tipizzati (autenticazione, quota, rete, rifiuto, formato) e ricondotti al modello di errore di Mosaic |

`OpenAIProvider` è la prima implementazione (M3). Endpoint, modelli, parametri e termini di conservazione dei dati si verificano sulla documentazione ufficiale di OpenAI al momento dell'implementazione, senza darli per scontati. Le implementazioni successive rispettano lo stesso contratto; se un provider non offre una capacità (per esempio l'output strutturato), l'AI Runtime lo esclude dai compiti che la richiedono.

## 4. Compiti e provider di default

| Compito | Default | Alternative, secondo la policy |
| --- | --- | --- |
| Embedding | Core ML | Ollama; mai il cloud per default |
| OCR | Vision | — |
| Lingua, entità, date | NaturalLanguage, `NSDataDetector` | Foundation Models |
| Da linguaggio naturale a `SearchIntent` | Foundation Models | Parser a regole; provider cloud se consentito |
| Classificazione dei file (Organizer) | Regole, esempi approvati simili negli embedding, Foundation Models | Ollama; provider cloud se consentito per il modulo |
| Riassunti (§25) | Foundation Models, con map-reduce oltre la finestra di contesto | Provider cloud, con *Chiedi* |
| AI Rename (§23, F2) | Foundation Models | Provider cloud |
| Mac Assistant (§35, M10) | Foundation Models per le domande semplici | Provider cloud configurato per quelle complesse; Ollama |

## 5. Policy engine

**Livelli**: *Solo locale* · *Chiedi* · *Cloud consentito*. "Locale" comprende anche Ollama su loopback. Ogni provider cloud si abilita separatamente.

**Ambiti**, dal più generale: globale, modulo (Assistant, Organizer, Insights, Rename, ricerca in linguaggio naturale), sorgente (per esempio "Mail istituzionale: Solo locale"), categoria di dati (corpi delle mail, documenti, appunti, timeline). Tra le policy pertinenti vale **la più restrittiva**.

**Default**: globale *Solo locale*; Assistant *Chiedi*. Mail, appunti e timeline restano *Solo locale* anche con l'Assistant su *Chiedi*.

**Consenso** (con *Chiedi*): un foglio mostra provider, modello, testo esatto e già minimizzato da inviare, nomi dei file, token stimati e costo, con tre scelte: *Consenti una volta*, *Consenti sempre per questo modulo*, *Nega*. Quello che compare nel foglio è esattamente ciò che viene trasmesso.

**Minimizzazione.** Al cloud vanno i blocchi di testo recuperati, non i file interi. Prima dell'invio si applicano regole di oscuramento configurabili per chiavi API, IBAN, codici fiscali e password riconoscibili.

## 6. Substrato dell'Assistant in V1 (D12, ADR-015)

| Componente | Ruolo | Milestone |
| --- | --- | --- |
| `CommandRegistry` | Registro unico delle azioni, con parametri tipizzati, rischio e permessi richiesti | M0 (base), M1 |
| Astrazione di azioni e strumenti | Ogni azione del registro è esponibile come strumento per l'AI senza adattamenti; le modifiche diventano `OperationPlan` | M1, M3 |
| Integrazione con il Safety Engine | Le azioni proposte dall'AI passano da anteprima e approvazione | M1 |
| Azioni consapevoli dei permessi | Ogni azione dichiara i propri permessi; `PermissionGate` li verifica prima dell'esecuzione | M1 |
| AI Runtime e policy | Scelta del provider, consenso, minimizzazione, audit | M3 |
| Astrazione dei provider | Provider locali e `CloudAIProvider`, con `OpenAIProvider` | M3 |
| `SearchIntent` e ricerca in linguaggio naturale | Dalla frase a un filtro strutturato, mostrato con chip modificabili | M3 |
| Retrieval consapevole delle sorgenti | Recupero di blocchi filtrato per sorgente, permessi e policy, con riferimenti citabili | M3, M5 |

M10 aggiunge l'interfaccia conversazionale e il ragionamento avanzato sopra questo substrato, senza riprogettarlo.

## 7. Embedding e memorizzazione dei vettori

- **Scelta del modello (S6).** Candidati: `multilingual-e5-small` e `-base`, EmbeddingGemma-300M, Qwen3-Embedding-0.6B, BGE-M3, `NLContextualEmbedding` con mean pooling. Le analisi pubblicate indicano la famiglia `multilingual-e5` come competitiva sull'italiano. Metriche: richiamo@10 e MRR sul tuo corpus (italiano, inglese e tra lingue diverse), millisecondi per blocco, consumo energetico, dimensione e **licenza** (per esempio i termini d'uso di Gemma rispetto a MIT o Apache).
- **Memorizzazione.** Vettori int8 in `index.db` (cifrato se S1 conferma D7), ricerca esatta in memoria, indice HNSW oltre la soglia (ADR-007). Gli embedding sono dati sensibili: da un embedding si può ricostruire in parte il testo originale.
- **Versionamento.** Ogni vettore ha il suo `model_id`; quando il modello cambia, i vettori si ricalcolano in background.

## 8. LLM sul dispositivo: limiti e contromisure

| Limite | Contromisura |
| --- | --- |
| Contesto piccolo (4K o 8K token) | RAG con pochi blocchi pertinenti; map-reduce per i riassunti; `contextSize` letto a runtime |
| Apple Intelligence disattivata, lingua non supportata o macOS precedente al 26 | Stato visibile in Diagnostics; ripiego su regole, Ollama o provider cloud secondo la policy |
| Guardrail con falsi positivi | Messaggio chiaro e opzione di ripiego |
| Output variabile | Generazione guidata (`@Generable`) per tutto ciò che è strutturato, con convalida dei valori |

## 9. Mac Assistant (M10)

- **Strumenti.** Il modello chiama le azioni del registro esposte come strumenti, *in sola lettura* per default: `search_files`, `search_mail`, `file_details`, `health_history`, `termica_history`, `index_health`, `declutter_candidates`, `propose_organization` e altre. Le azioni che modificherebbero qualcosa restituiscono un piano, senza eseguirlo.
- **Policy dentro gli strumenti.** Se una categoria di dati è *Solo locale* e il provider attivo è cloud, lo strumento risponde "non disponibile con la policy corrente" oppure chiede il consenso.
- **Prompt injection.** Documenti e mail possono contenere istruzioni ostili. Per questo i risultati degli strumenti sono marcati come dati non fidati, nessuna azione parte senza approvazione e l'elenco degli strumenti è chiuso.
- **Risposte con fonti.** Ogni risposta elenca gli elementi usati (file, mail, intervalli di telemetria), apribili con un clic (§35).

## 10. Apprendimento dalle decisioni (Organizer, §20)

Le proposte approvate o corrette diventano esempi (caratteristiche del file → destinazione). Le classificazioni successive combinano regole esplicite, esempi simili e il modello. Ogni proposta mostra il proprio motivo, per esempio "simile a 12 fatture già spostate in Documenti/Fatture". Gli esempi si possono consultare e cancellare, e non c'è alcun fine-tuning.

Come punto di partenza si possono usare la tassonomia e le regole di `RiorganizzazioneFolderMac` (`config/categories.yaml`, `config/rules.yaml`) e la struttura già presente in `Download_Organizzati/`.

## 11. Audit e costi

Ogni chiamata AI registra in `activity.db` modulo, classe di provider, provider, modello, scopo, categorie di dati, riferimenti agli elementi, token, costo stimato e tipo di consenso, **mai il contenuto**. Un pannello mostra quanto è stato elaborato in locale e quanto in cloud, per provider, con i costi del mese.
