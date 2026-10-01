# Mosaic

**Your Mac. Connected.** È un utility center personale per macOS che collega file, mail, stato del sistema e attività in un unico spazio di lavoro.

> **Stato: Fase 0 approvata con modifiche il 2026-09-29. In corso: M0, fondamenta e spike.** M0 costruisce le fondamenta del progetto e verifica le capacità più rischiose; le funzioni per l'utente iniziano da M1, dopo la revisione dei risultati di M0.

## Da dove partire

- Per una lettura d'insieme c'è il [Riepilogo](docs/discovery/MOS-SUM-001-riepilogo.md): un solo file con architettura, permessi, milestone e decisioni.
- Per i dettagli e l'esito delle decisioni D1–D12 (§6.1) c'è il [Discovery Report](docs/discovery/MOS-DISC-001-discovery-report.md).

## Documenti

| Codice | Documento | Sezioni del master prompt |
| --- | --- | --- |
| MOS-SUM-001 | [Riepilogo](docs/discovery/MOS-SUM-001-riepilogo.md) | Sintesi dell'intera Fase 0 |
| MOS-DISC-001 | [Discovery Report](docs/discovery/MOS-DISC-001-discovery-report.md) | Verifiche, ambiente, decisioni |
| MOS-ARCH-001 | [Architettura](docs/discovery/MOS-ARCH-001-architecture.md) | §72 A, B, H |
| MOS-MAC-001 | [Integrazione macOS](docs/discovery/MOS-MAC-001-macos-integration.md) | §72 C, §73 |
| MOS-PERM-001 | [Permission Matrix](docs/discovery/MOS-PERM-001-permission-matrix.md) | §72 D, §51 |
| MOS-DM-001 | [Data Model](docs/discovery/MOS-DM-001-data-model.md) | §72 E, §57, §68 |
| MOS-SRCH-001 | [Search & Indexing](docs/discovery/MOS-SRCH-001-search-architecture.md) | §72 F, §8–§12, §53 |
| MOS-MAIL-001 | [Mail Architecture](docs/discovery/MOS-MAIL-001-mail-architecture.md) | §13–§15 |
| MOS-AI-001 | [AI Architecture](docs/discovery/MOS-AI-001-ai-architecture.md) | §72 G, §34–§36 |
| MOS-SEC-001 | [Security & Privacy Model](docs/discovery/MOS-SEC-001-security-privacy.md) | §59–§63 |
| MOS-TRM-001 | [Integrazione Termica](docs/discovery/MOS-TRM-001-termica-integration.md) | §72 I, §38 |
| MOS-UX-001 | [Information Architecture](docs/discovery/MOS-UX-001-information-architecture.md) | §72 J, §5–§7 |
| MOS-PLAN-001 | [Milestone e roadmap](docs/discovery/MOS-PLAN-001-milestones.md) | §72 K, §64–§66 |
| MOS-RISK-001 | [Risk Register](docs/discovery/MOS-RISK-001-risk-register.md) | §72 L |
| — | [Decision Log (ADR)](docs/DECISION_LOG.md) | §70 |
| — | [Master prompt](docs/reference/MOSAIC-MASTER-PROMPT.md) | Requisiti di riferimento |

## Stack proposto

Swift 6 · SwiftUI + AppKit · SQLite (GRDB, FTS5) · servizi XPC · Vision · Foundation Models · Core ML.

Mosaic è un'app nativa non sandboxed. Durante lo sviluppo è firmata Apple Development, ed è compatibile con una futura firma Developer ID e con la notarizzazione. Gira solo su Apple Silicon; la versione minima di macOS si decide a fine M0.
