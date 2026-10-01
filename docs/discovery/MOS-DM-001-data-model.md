# MOS-DM-001 — Data Model

| Campo | Valore |
| --- | --- |
| Copre | Master prompt §72 E, §57, §68 |
| Stato | Proposta a livello concettuale: tabelle e campi chiave, non ancora il DDL definitivo |

## 1. Convenzioni

- **ID**: UUIDv7, ordinabili nel tempo e unici in assoluto, salvati come BLOB da 16 byte. Nessun ID auto-incrementale viene usato fuori dal proprio database.
- **Tempo**: UTC, in millisecondi dall'epoch (int64). La conversione nel fuso locale avviene solo nella UI.
- **Dispositivo**: un `device_id` generato all'installazione, presente sui record legati a questo Mac (§57).
- **Riferimenti tra entità**: `EntityRef = (kind, id)`, con `kind` tra file, folder, mail_message, mail_attachment, app, contact, event, reminder, note, clipboard_item, project, session, activity_event, command.
- **Entità curate dall'utente** (sorgenti, regole, progetti, mappature…): hanno `created_at`, `updated_at`, un tombstone `deleted_at` e una riga in `change_log` per ogni modifica, base per una futura sincronizzazione.
- **Dati derivati** (indice, telemetria): si possono ricostruire, quindi non hanno tombstone.

## 2. Archivi

| Database | Contenuto | Ciclo di vita | Nel backup della configurazione (§56) |
| --- | --- | --- | --- |
| `core.db` | Configurazione ed entità curate: impostazioni, sorgenti, regole, mappature della tastiera, modes, layout della Home, preset, automazioni, policy AI, regole di alert, (F2) progetti | Piccolo e prezioso; le migrazioni avvengono sempre sul posto | Sì, nel livello "solo configurazione" |
| `index.db` | Volumi, file, blocchi di testo con FTS5, embedding, gruppi di duplicati, mail, code di lavoro, errori | Grande e ricostruibile | No, salvo backup avanzato |
| `activity.db` | Audit, journal delle operazioni, quarantena, avvisi, chiamate AI; (F2) timeline, sessioni, appunti | Sensibile, con retention configurabile e soggetto alla Private Mode | Opzionale |
| `telemetry.db` | Serie temporali del sistema, campioni dei processi, batteria, spazio su disco, probe di rete | Solo in aggiunta, con retention per risoluzione | No |

La separazione ha diversi motivi: cicli di vita diversi, backup selettivo, minore contesa in scrittura in WAL, danni circoscritti in caso di corruzione, e la possibilità di ricostruire l'indice senza toccare configurazione e storico. Tutti gli archivi stanno in `~/Library/Application Support/Mosaic/`, con permessi `0600`, e sono cifrati se approvi D7.

## 3. Mappa delle entità

```text
core.db                          index.db                                          activity.db
───────                          ────────                                          ───────────
source ─┬─ source_rule           volume ── file ─┬─ content_chunk ── embedding     operation ── operation_step
        └────────────────────────────────────────┘      └─ content_fts           │
mail_source ─────────────── mail_account ── mailbox ── mail_message ─┬─ mail_participant
                                                                     ├─ mail_attachment ── content_chunk
                                          mail_thread ───────────────┘
keyboard_device ── keyboard_mapping       dup_group ── dup_member ── file
mode · home_layout · declutter_preset     index_job · index_error              audit_event · alert · ai_call
automation_rule · ai_policy · alert_rule  person (identità delle persone)      quarantine_item
project ── project_link (F2) ─────────────────── EntityRef ─────────────────── activity_event · work_session (F2)
```

## 4. Entità principali

### 4.1 `core.db`

| Entità | Campi chiave |
| --- | --- |
| `setting` | key, value_json, updated_at |
| `device` | id, name, model, os_version, first_seen_at |
| `source` | id, kind (local_folder · external_volume · network_share · cloud_file_provider · icloud), display_name, root_path, root_bookmark, volume_uuid, enabled, indexing_level (metadata · fulltext · semantic), ocr_enabled, dataless_policy (metadata_only · download_opt_in), status (online · offline · indexing · paused · error · permission_required), status_detail, last_scan_at, last_fsevent_id |
| `source_rule` | id, source_id, kind (include · exclude), matcher (glob · regex · path_prefix · uti · size · age), pattern, priority |
| `mail_source` | id, client (apple_mail · thunderbird · gmail_api · graph · imap), locator, index_bodies, index_attachments, semantic_enabled, status, last_sync_at |
| `keyboard_device` | id, fingerprint, vendor_id, product_id, serial_number?, product_name, transport, is_builtin, last_location_id, first_seen_at, last_seen_at |
| `keyboard_mapping` | device_id, input_source_id (per esempio `com.apple.keylayout.Italian-Pro`), created_at |
| `mode` | id, kind (work · focus · private · presentation · travel · custom), name, effects_json |
| `home_layout` | id, name, is_default, widgets_json (tipo, posizione, dimensione, configurazione) |
| `declutter_preset` | id, name (conservative · normal · aggressive · custom), categories_json, thresholds_json |
| `automation_rule` | id, name, trigger_json (orario · evento · condizione), conditions_json, action_json, level (suggest · ask · auto), enabled, last_run_at, origin (user · suggested) |
| `ai_policy` | scope_kind (global · module · source · data_category), scope_id, level (local_only · ask · cloud_allowed), provider_prefs_json |
| `alert_rule` | category, enabled, thresholds_json, snoozed_until |
| `probe_target` | id, name, host, port, kind (tcp · icmp · dns · http), interval_s |
| `change_log` | entity, entity_id, op, at, device_id |
| `project`, `project_link`, `project_rule` (F2) | project: id, name, color, icon, status. link: project_id, entity_ref, origin (manual · rule · ai_suggested), confidence, confirmed |

### 4.2 `index.db`

| Entità | Campi chiave |
| --- | --- |
| `volume` | uuid, name, fs_type, is_internal, is_network, is_removable, spotlight_enabled, fsevents_supported, last_seen_at |
| `file` | id, source_id, volume_uuid, file_resource_id, path, parent_path, name, ext, uti, is_dir, is_package, is_hidden, size, allocated_size, private_size?, created_at, modified_at, added_at, last_used_at, is_dataless, cloud_state, finder_tags, where_froms, quick_hash, sha256?, text_hash?, perceptual_hash?, clone_id?, extraction_state (none · pending · done · ocr_done · failed · skipped), extraction_error, language, page_count, metadata_json (autori, EXIF, metadati PDF), indexed_at, missing_since |
| `name_fts` | FTS5 `trigram` sul nome e sulle ultime componenti del percorso |
| `content_chunk` | id, owner_ref (file · mail_message · mail_attachment), seq, page?, char_start, char_end, text, origin (text_layer · ocr · body · attachment), ocr_confidence?, language |
| `content_fts` | FTS5 `unicode61 remove_diacritics 2`, con contenuto esterno in `content_chunk` |
| `embedding_model` | id, name, version, dim, provider, quantization |
| `embedding` | chunk_id, model_id, vector (int8), scale, created_at |
| `dup_group` | id, kind (exact · same_content · similar · version), confidence, algorithm_version, created_at |
| `dup_member` | group_id, file_id, score, reasons_json, suggested_role (keep · candidate) |
| `mail_account` | id, mail_source_id, address, display_name, provider_hint |
| `mailbox` | id, account_id, name, role (inbox · sent · archive · trash · junk · other), source_path, source_count, indexed_count, last_indexed_at |
| `mail_message` | id, account_id, mailbox_id, message_id_header, thread_id, subject, from_address, from_name, sent_at, received_at, snippet, flags, has_attachments, size, source_locator (percorso emlx, oppure mbox e offset), body_state (full · partial · missing), indexed_at, deleted_at |
| `mail_participant` | message_id, role (to · cc · bcc · reply_to), address, name, person_id? |
| `mail_thread` | id, normalized_subject, first_at, last_at, message_count |
| `mail_attachment` | id, message_id, filename, mime_type, size, sha256?, is_inline, extraction_state, saved_file_id? (file su disco con lo stesso hash) |
| `person` | id, display_name, addresses_json, contact_identifier? |
| `index_job` | id, kind, target_ref, priority, state, attempts, last_error, not_before, created_at |
| `index_error` | target_ref, stage, error_code, message, first_seen_at, last_seen_at, count |
| `entity_mention`, `relation` (F2) | mention: ref, kind (person · org · date · place), value, normalized, confidence. relation: src_ref, dst_ref, kind (version_of · duplicate_of · attachment_saved_as · same_thread · mentions · semantic · same_session · in_project), score, origin |

### 4.3 `activity.db`

| Entità | Campi chiave |
| --- | --- |
| `audit_event` | id, at, actor (user · automation · assistant · system), module, action, target_refs, summary, details_json (mai contenuti né segreti), outcome, operation_id?, risk_level, ai_provider_class? |
| `operation` | id, plan_json, risk_level, approval (explicit · rule · auto_low_risk), state, created_at, completed_at, undo_state (available · expired · unavailable), undo_until |
| `operation_step` | operation_id, seq, kind (move · rename · trash · quarantine · create_dir · set_tags · select_input_source · set_system_pref …), source, destination, preconditions_json (identificativo del file, dimensione, data di modifica, hash), result, inverse_json |
| `quarantine_item` | id, operation_id, original_path, quarantine_path, volume_uuid, size, expires_at |
| `alert` | id, at, category, severity (info · warning · critical), title, body, module, state (active · acknowledged · resolved · snoozed), dedupe_key |
| `ai_call` | id, at, module, provider_class (on_device · local_server · private_cloud · third_party_cloud), model, purpose, data_categories, item_refs, input_tokens, output_tokens, estimated_cost, consent (policy · asked_allowed), outcome |
| `activity_event` (F2) | id, at, kind (file_opened · file_modified · file_created · download · mail_received · volume_mounted · app_activated · browser_*), entity_ref, app_bundle_id, details_json |
| `work_session`, `session_item` (F2) | session: id, started_at, ended_at, title, origin (auto · manual), project_id?, confirmed. item: session_id, entity_ref, weight |
| `clipboard_item` (F2) | id, at, kinds, text?, file_refs?, image_blob_ref?, source_app, pinned, favorite, sensitive, expires_at |

### 4.4 `telemetry.db`

| Entità | Campi chiave |
| --- | --- |
| `metric_minute` | minute_at, metric (cpu_total · load1 · mem_used · mem_pressure · swap_used · disk_free:<volume> · battery_pct · power_source · net_rx · net_tx · thermal_state · mosaic_cpu · mosaic_energy), avg, min, max, last |
| `metric_hour`, `metric_day` | Aggregati con la stessa struttura |
| `process_minute` | minute_at, pid, name, bundle_id, cpu_pct, memory_bytes, solo per i primi N processi |
| `battery_day` | day, cycle_count, design_capacity, raw_max_capacity, health_pct, condition |
| `storage_day` | day, volume_uuid, used, free, purgeable?, top_dirs_json |
| `network_probe` | at, target_id, kind, latency_ms, success, error |
| `network_event` | at, kind (path_changed · interface_up · interface_down · outage_start · outage_end · nas_available · nas_unavailable), details_json |

I dati di Termica **non vengono copiati**: si interrogano quando servono (MOS-TRM-001).

## 5. Retention e Private Mode

| Dato | Default | Configurabile |
| --- | --- | --- |
| Metriche al minuto | 7 giorni | Sì |
| Aggregati orari e giornalieri | 90 giorni e 2 anni | Sì |
| Probe ed eventi di rete (§44) | 30 giorni | 7, 30, 90, 365 giorni o personalizzato |
| Audit | 1 anno | Sì |
| Quarantena | 30 giorni | Sì; lo svuotamento chiede sempre conferma |
| Chiamate AI (solo metadati) | 90 giorni | Sì |
| (F2) Timeline, appunti | Da definire insieme al modulo | Sì |

In **Private Mode** Mosaic non registra la cronologia delle ricerche e la frecency, né, in Fase 2, gli eventi della timeline, gli appunti e lo storico dell'Assistant. L'audit delle operazioni di Mosaic continua, perché serve alla sicurezza e all'undo.

## 6. Migrazioni (§68)

- Ogni database ha migrazioni nominate e versionate (GRDB `DatabaseMigrator`), eseguite all'avvio dentro una transazione.
- Prima di ogni migrazione di schema, Mosaic salva una copia di sicurezza del database.
- I test partono da una fixture di ogni versione rilasciata, la migrano fino all'ultima e verificano i dati.
- `index.db` può essere ricostruito, ma solo come ultima risorsa: la ricostruzione avviene in background, l'indice precedente resta interrogabile e la UI lo segnala. `core.db` e `activity.db` si migrano sempre sul posto.
- Cambiare modello di embedding non è una migrazione di schema: ogni vettore è etichettato con il suo `model_id` e viene ricalcolato in background.

## 7. Predisposizione per più Mac (§57), senza implementarla

- ID univoci, `device_id`, tombstone e `change_log` sulle entità di `core.db` permettono in futuro una sincronizzazione con fusione entità per entità, per esempio tramite CloudKit.
- `index.db` e `telemetry.db` restano per dispositivo: ogni Mac indicizza i propri file.
- I percorsi sono dati del dispositivo, non identità. Tra Mac diversi i file si collegano tramite l'hash del contenuto e i riferimenti di progetto.
