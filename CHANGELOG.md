# Changelog

Formato basato su [Keep a Changelog](https://keepachangelog.com/it-IT/1.1.0/).

## [Non rilasciato]

### Aggiunto — M0 (concluso, in attesa di revisione)

- Progetto Xcode generato da `project.yml` (XcodeGen), con script `bootstrap.sh`, `test.sh` e `build-app.sh`.
- `MosaicCore`: identificativi UUIDv7, errori per causa, livelli di rischio, permessi, EventBus, `CommandRegistry` con parametri tipizzati, Portachiavi.
- `MosaicStorage`: database SQLCipher con chiave nel Portachiavi, migrazioni versionate, backup cifrato prima delle migrazioni, permessi `0600`, schema v1 di `core.db`.
- `MosaicPlatform`: JobScheduler con quattro code di priorità, pausa, annullamento e arresto completo.
- Test: 31 test verdi (Core 16, Storage 9, Platform 6).
- App residente in menu bar: la finestra si chiude senza terminare Mosaic, l'avvio al login è opzionale e l'uscita ferma ogni attività.
- GRDB v7.11.1 con SQLCipher 4.19.0, preparato da `scripts/vendor-grdb.sh`.
- Spike S1, S3, S4, S6, S7, S8, S9 e S5 (Thunderbird e Apple Mail) completati, con rapporti in `docs/spikes/`. S2 completato per XPC/sandbox; il test del file dataless resta rimandato.
- Mosaic Probe (`Spikes/Probe/`), l'app per gli spike interattivi S2, S4, S5 e S8; certificato Apple Development creato, Team ID `HQJWK6BU8M`.
- Rapporto di fine M0 (`docs/discovery/MOS-M0-001-report.md`), pronto per la revisione: nessun risultato bloccante, raccomandazione di procedere a M1.
- Nuovo rischio R47 individuato e mitigato: conflitto tra lo switch automatico della tastiera per dispositivo (ADR-012) e la memoria per-documento di TSM in Pages/TextEdit.

### Aggiunto — Fase 0

- Fase 0, Discovery & Architecture. Documenti prodotti: discovery report, architettura, integrazione macOS, permission matrix, data model, architettura di ricerca e indicizzazione, architettura AI, modello di sicurezza e privacy, integrazione con Termica, information architecture, milestone, risk register e decision log (ADR-000 … ADR-014).
- Master prompt conservato in `docs/reference/` come riferimento dei requisiti.
- Riepilogo della Fase 0 in un unico file (`MOS-SUM-001`).
- Architettura della posta (`MOS-MAIL-001`): contratto `MailSourceAdapter`, adapter Apple Mail e Thunderbird, diagnostica.

### Modificato

- Applicate le decisioni del 2026-09-29. Negli ADR: Thunderbird in V1 (ADR-009), provider AI cloud neutrale con OpenAI come prima implementazione (ADR-008), substrato dell'Assistant in V1 (ADR-015), versione minima di macOS da determinare in M0 (ADR-016, sostituisce ADR-014), direzione visiva A in esplorazione (ADR-017).
- Aggiornati di conseguenza discovery report, architettura, AI architecture, piano delle milestone (spike S9, rapporto di fine M0), risk register (R43–R46), riepilogo e documenti collegati.
