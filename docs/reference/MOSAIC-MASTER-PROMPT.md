> Testo fornito dal committente il 2026-09-29 e conservato senza modifiche come riferimento dei requisiti. I documenti di discovery citano le sue sezioni con "§n".

# MOSAIC
## macOS Personal Utility Center
### Master Development Prompt

## 1. Project Vision

Build **Mosaic**, a premium macOS-only desktop application designed to act as an intelligent operational layer above macOS.

Mosaic must unify:

- file discovery;
- email search;
- semantic search;
- system monitoring;
- decluttering;
- file organization;
- keyboard layout management;
- clipboard history;
- system diagnostics;
- project organization;
- work-session reconstruction;
- activity timeline;
- application management;
- software maintenance;
- network diagnostics;
- AI-assisted interaction;
- automation;
- safety and rollback.

Mosaic is not intended to replace macOS.

It must improve areas where the native macOS experience is fragmented, inefficient, difficult to search, or insufficiently integrated.

The application must feel like a high-quality native macOS product.

The guiding concept is:

**MOSAIC — Your Mac. Connected.**

Individual pieces of the user's digital activity—files, emails, projects, system state, clipboard items, work sessions, applications, storage, network state, and other information—are the “tiles” that Mosaic connects into a coherent workspace.

---

# 2. Development Philosophy

Use a modular architecture designed from the beginning for the complete Mosaic ecosystem.

However, implementation must occur progressively by milestones.

Do NOT attempt to implement every feature superficially in the first release.

The architecture should support the complete roadmap, while each released module must be genuinely functional and production-quality.

The preferred development strategy is:

**Complete architecture + incremental implementation.**

Do not create fake functionality or non-functional UI placeholders presented as working features.

---

# 3. Technical Autonomy

The coding agent has autonomy to choose the most appropriate technical architecture.

Possible technologies may include, but are not limited to:

- Swift / SwiftUI;
- AppKit;
- Tauri;
- React / TypeScript;
- Rust;
- SQLite;
- native macOS frameworks;
- hybrid architectures;
- local helper services;
- local AI models.

Do NOT assume that the initially suggested stack is mandatory.

Before implementation, perform an architectural analysis considering:

- deep macOS integration;
- filesystem access;
- Spotlight integration;
- input-source management;
- menu-bar applications;
- performance;
- battery consumption;
- memory usage;
- application sandbox constraints;
- permissions;
- maintainability;
- security;
- code modularity;
- AI model integration;
- future extensibility.

Technical decisions may be made autonomously.

However:

**Any decision that materially changes the requested UX, feature behavior, privacy model, user workflow, or functional requirements must be presented to the user before implementation.**

---

# 4. Platform

Mosaic is:

**macOS-only.**

Do not optimize for Windows or Linux portability.

Take advantage of macOS-specific frameworks and capabilities whenever beneficial.

The application should preferably support recent Apple Silicon systems.

---

# 5. UX Philosophy

Mosaic must look and behave like a premium macOS application.

Visual direction:

**Apple-native premium + technical dashboard.**

The normal interface should be:

- elegant;
- minimal;
- spacious;
- clear;
- responsive;
- visually coherent with macOS.

Technical areas such as:

- System Health;
- Termica;
- Network;
- Index Health;
- Storage;
- diagnostics;

may use denser technical dashboards with graphs and metrics.

Avoid:

- generic web-dashboard appearance;
- excessive cards;
- visual clutter;
- gaming aesthetics;
- excessive gradients;
- gratuitous animations.

Use animations only where they improve understanding.

Support:

- Light Mode;
- Dark Mode;
- automatic system appearance.

---

# 6. Mosaic Visual Identity

Create a coherent visual identity for Mosaic.

Develop:

- application icon;
- menu-bar icon;
- wordmark if useful;
- visual system;
- component language.

The icon should communicate the Mosaic concept without literally looking like a generic tiled grid.

It should remain recognizable:

- in the Dock;
- at small size;
- in Finder;
- in the menu bar where appropriate.

The application name is:

# Mosaic

Preferred tagline:

**Your Mac. Connected.**

---

# 7. Home Dashboard

Create a modular, user-customizable Home.

Provide a carefully designed default configuration during onboarding.

Users must then be able to:

- move widgets;
- resize widgets;
- hide widgets;
- restore defaults;
- add widgets.

Potential widgets include:

- Universal Search;
- Resume Work;
- Recent Activity;
- Projects;
- System Health;
- Storage;
- Termica;
- Index Health;
- Mail Health;
- Network;
- Clipboard;
- Declutter Suggestions;
- Automations;
- Alerts;
- Quick Actions.

Critical problems may temporarily gain visual prominence.

---

# 8. Universal Search

Universal Search is one of Mosaic's core features.

It should be globally accessible through a configurable keyboard shortcut, for example:

`Option + Space`

It must search across available and authorized sources.

Potential searchable entities:

- files;
- folders;
- PDFs;
- document contents;
- emails;
- email attachments;
- applications;
- contacts;
- calendar events;
- reminders;
- notes;
- clipboard history;
- projects;
- work sessions;
- activity history;
- Mosaic commands.

Results must be grouped visually by type.

Provide:

- keyboard navigation;
- fuzzy matching;
- ranking;
- filters;
- fast preview;
- contextual actions.

---

# 9. Search Modes

Support multiple search strategies.

### 9.1 Filename / Path Search

Search:

- filename;
- extension;
- path;
- metadata.

### 9.2 Full-Text Search

Search inside supported document types.

Examples:

- PDF;
- DOCX;
- TXT;
- Markdown;
- source files;
- other extractable document formats.

### 9.3 Metadata Search

Examples:

- file type;
- modification date;
- creation date;
- size;
- tags;
- source;
- project;
- application;
- author where available.

### 9.4 Semantic Search

Allow natural queries such as:

“Find the document where I discussed NUSES thermal requirements.”

Semantic search should tolerate the absence of exact matching keywords.

---

# 10. Hybrid Indexing Architecture

Use a hybrid strategy.

### Native macOS layer

Use Spotlight/macOS metadata mechanisms whenever useful for immediate searches.

### Mosaic index

Create a separate Mosaic-controlled index for:

- reliable full-text search;
- semantic search;
- OCR results;
- normalized metadata;
- cross-source relationships;
- email indexing;
- project relationships.

Mosaic must not depend completely on Spotlight.

Provide:

- indexing status;
- progress;
- health information;
- reindex controls.

---

# 11. Sources

Create a dedicated **Sources** module.

Potential sources:

- internal storage;
- selected folders;
- external drives;
- mounted volumes;
- NAS;
- SMB shares;
- iCloud Drive;
- Google Drive;
- Dropbox;
- OneDrive;
- other locally synchronized cloud folders.

Each source must support:

- enable/disable;
- inclusion/exclusion rules;
- indexing level;
- semantic indexing enable/disable;
- source status.

Status examples:

- Online;
- Offline;
- Indexing;
- Paused;
- Error;
- Permission required.

Possible indexing levels:

1. Filename/metadata only.
2. Full text.
3. Semantic.

---

# 12. OCR

Provide optional local OCR.

Primary goal:

make otherwise unsearchable content searchable.

Examples:

- scanned PDFs;
- screenshots;
- images containing text;
- invoices;
- receipts;
- scanned documents.

Prefer native/local processing whenever feasible.

OCR output should enter:

- full-text index;
- semantic index;
- File Inspector.

OCR must obey Resource Manager rules.

---

# 13. Mail Search

Build a unified Mail Search system.

Potential sources include:

- Apple Mail;
- Thunderbird;
- Gmail;
- Outlook / Microsoft 365;
- IMAP where appropriate.

Create a **Mail Sources** manager similar to Sources.

Search must support:

- sender;
- recipients;
- CC;
- subject;
- date;
- message body;
- thread;
- account;
- folder/mailbox;
- attachments;
- attachment contents.

Also support semantic searches such as:

“Find the email Marco sent me around March about the detector tests.”

---

# 14. Mail Attachment Indexing

Attachments must optionally be indexed.

Examples:

- PDF;
- Word;
- Excel;
- text;
- supported document formats.

Allow attachment search independently from email body search.

---

# 15. Mail Diagnostics

Mosaic must be able to identify common search/indexing problems.

Example:

Thunderbird Search — Degraded

- messages detected: 38,412
- indexed: 31,087
- missing: 7,325
- last successful index;
- possible issue;
- recommended action.

Distinguish:

- Mosaic index problems;
- source client problems;
- permission problems;
- disconnected accounts;
- unavailable files.

---

# 16. Keyboard Manager

Keyboard layout must depend on the **physical keyboard being used**.

It must NOT depend on:

- document language;
- application language;
- text language.

Detect physical input devices and associate each device with a preferred layout.

Example:

MacBook keyboard → Italian

External US keyboard → US

Mechanical keyboard → custom profile

Persist mappings.

Automatically switch input source when the active physical keyboard changes.

Provide:

- device list;
- hardware identifier where available;
- assigned layout;
- current active keyboard;
- current active layout;
- temporary override.

---

# 17. Decluttering Engine

Create a configurable Decluttering system.

Modules must be independently selectable.

Potential categories:

- duplicates;
- large files;
- old files;
- Downloads;
- Desktop;
- cache;
- temporary files;
- installers;
- DMG;
- ZIP;
- unused packages;
- empty folders;
- abandoned application files;
- miscellaneous storage candidates.

Never assume all categories must run.

Allow the user to enable only selected categories.

---

# 18. Configurable Thresholds

No important cleanup threshold should be hard-coded.

User-configurable examples:

- 30 days;
- 60 days;
- 90 days;
- 120 days;
- custom.

Other thresholds:

- file size;
- similarity percentage;
- number of duplicates;
- minimum free disk space;
- retention duration.

Support presets:

- Conservative;
- Normal;
- Aggressive;
- Custom.

Every preset must remain inspectable and editable.

---

# 19. Duplicate Detection

Distinguish different forms of duplication.

### Exact Duplicate

Files identical byte-for-byte.

Use cryptographic hashing, e.g. SHA-256 or equivalent.

### Content Duplicate

Same meaningful content but differing binary representation.

Example:

two PDFs containing the same document but different metadata.

### Near Duplicate

Highly similar but not identical files.

Example:

Proposal_v3.pdf

Proposal_v3_final.pdf

Proposal_v3_final2.pdf

### Version Candidate

Files likely representing different versions of the same document.

UI groups:

- Exact;
- Same Content;
- Similar;
- Versions.

Show confidence levels where applicable.

Never automatically treat a near duplicate as safe to delete.

---

# 20. Smart Organizer

Build a Smart Organizer.

It should inspect messy folders such as:

- Downloads;
- Desktop;
- user-selected folders.

Classify files and propose organization.

Initial workflow:

**Suggest → Preview → Approve**

Examples:

- scientific papers;
- invoices;
- administrative documents;
- images;
- installers;
- archives;
- project files.

Learn from user-approved decisions where appropriate.

---

# 21. Automation Rules

Create an Automation system.

Examples:

“Every PDF containing invoice → propose moving to Documents/Invoices.”

“DMG older than 60 days → suggest deletion.”

“Every Friday → analyze Downloads.”

Automation levels:

1. Suggest only.
2. Ask before action.
3. Execute automatically.

Automations must always remain visible and editable.

---

# 22. Batch File Operations

Provide batch operations.

Functions may include:

- rename;
- move;
- classify;
- normalize names;
- numbering;
- date insertion;
- regex replacement;
- metadata-based rename;
- EXIF-based rename;
- PDF metadata rename.

Support:

**Preview → Apply → Undo**

---

# 23. AI Rename

Allow optional AI-based filename suggestions.

Example:

Read a document and propose:

`2026-09-29_NUSES_Technical_Board_Minutes.pdf`

Never silently rename large file groups without explicit authorization unless the user has deliberately created an automatic rule.

---

# 24. File Inspector

Create an advanced File Inspector.

Example information for a PDF:

- filename;
- path;
- type;
- size;
- number of pages;
- creation date;
- modification date;
- last-opened information where available;
- hash;
- source;
- cloud state;
- backup state;
- duplicates;
- versions;
- metadata;
- indexed text;
- OCR state.

Quick actions:

- Open;
- Quick Look;
- Show in Finder;
- Copy path;
- Rename;
- Move;
- Share;
- Delete;
- Related Items.

---

# 25. AI File Insights

Optional actions:

- Summarize;
- Explain document;
- Extract dates;
- Extract people;
- Extract organizations;
- Find related files;
- Find related emails;
- suggest Project.

Always indicate whether AI processing occurred:

- locally;
- via cloud service.

---

# 26. Related Items

Build a relationship engine linking:

- files;
- emails;
- attachments;
- events;
- notes;
- projects;
- sessions;
- clipboard entries where relevant.

Example:

Opening a project PDF could show:

- related email thread;
- previous versions;
- relevant meeting;
- related files.

---

# 27. Activity Timeline

Build a local **Activity Timeline**.

This must NOT be a keylogger.

It may track authorized events such as:

- file opened;
- file modified;
- file created;
- attachment downloaded;
- email interaction;
- mounted volume;
- session activity;
- project-related activity.

Example:

Today

11:42 — modified NUSES_Schedule.xlsx  
11:31 — opened ECSS-E-ST-10.pdf  
11:18 — relevant mail detected  
10:56 — downloaded quotation.pdf  
10:32 — NAS connected

Allow semantic queries such as:

“What PDF was I working with yesterday afternoon?”

---

# 28. Work Sessions

Group related user activity into **Work Sessions**.

Example:

NUSES — Technical Board  
14:05–16:42

- 7 documents
- 12 emails
- 1 meeting

Sessions can be:

- automatically suggested;
- manually created;
- manually edited.

---

# 29. Resume Work

Provide **Resume Work**.

Where technically possible, restore relevant context:

- files;
- folders;
- applications;
- documents;
- project;
- related items.

Browser-tab integration is NOT required in V1.

---

# 30. Projects

Create a first-class **Projects** layer.

Projects connect information scattered across different sources.

Possible project entities:

- files;
- emails;
- attachments;
- meetings;
- notes;
- clipboard content;
- sessions;
- related activity.

Project association may be:

- automatic suggestion;
- manual;
- rule-based.

AI suggestions must remain correctable.

Each Project should have its own dashboard.

Potential actions:

- Resume Project;
- Search Project;
- Project Timeline;
- Related Items;
- recent emails;
- recent files.

---

# 31. Clipboard Manager

Create a local Clipboard Manager.

Support:

- text;
- URLs;
- images;
- file paths;
- supported clipboard objects.

Functions:

- history;
- search;
- pin;
- favorites;
- preview;
- paste;
- Universal Search integration.

Retention must be configurable.

---

# 32. Clipboard Privacy

Default behavior must be conservative.

Do not intentionally retain known password-manager content.

Allow:

- application blacklist;
- pause;
- retention rules;
- clear history;
- Private Mode.

Sensitive applications may be excluded automatically where technically feasible.

---

# 33. Command Palette

Universal Search must also operate as a Command Palette.

Examples:

`> reindex mail`

`> clean downloads`

`> open Termica`

`> find duplicate PDFs`

`> show files > 2 GB`

`> clipboard last`

`> system health`

`> mount NAS`

Commands should support keyboard-only workflows.

---

# 34. Natural-Language Commands

Provide natural-language interpretation.

Examples:

“Show PDFs larger than 100 MB that I haven't opened in two years.”

“Find every version of the NUSES proposal.”

“Organize Downloads but don't change anything yet.”

“Why was my Mac hot yesterday afternoon?”

Potentially destructive actions must still pass through Safety Engine rules.

---

# 35. Mac Assistant

Create a Mosaic AI Assistant.

It should be capable of querying authorized Mosaic modules.

Examples:

“Why can't I find Francesco's old emails?”

“Where am I wasting disk space?”

“What was I doing Tuesday afternoon?”

“Find all versions of this proposal.”

“Why did the Mac get hot yesterday?”

“Organize Downloads, but show me the plan first.”

Responses should identify useful source context.

Indicate processing method:

- Local AI;
- Cloud AI.

---

# 36. AI Architecture

Use a hybrid architecture.

Support policies such as:

- Local only;
- Cloud allowed;
- Ask me.

Ideally allow policies per source or module.

Prefer local processing for:

- embeddings where practical;
- classification;
- privacy-sensitive indexing;
- OCR;
- lightweight semantic operations.

Cloud AI may be used for more advanced reasoning with user authorization.

---

# 37. System Health

Create a System Health module.

Potential metrics:

- CPU;
- RAM;
- storage;
- battery;
- battery health;
- cycle count;
- temperature where available;
- processes;
- storage growth;
- mounted volumes;
- system load.

Historical charts should be used where valuable.

---

# 38. Termica Integration

A separate existing project called **Termica** already exists on the user's Mac and provides a dashboard.

Mosaic must be designed to integrate with it.

Preferred behavior:

- preserve Termica as an independent application/system;
- integrate its relevant data into Mosaic;
- provide deep System Health correlation;
- allow opening the original Termica dashboard.

Implement an adapter layer.

Preferred integration order:

1. documented/local API;
2. database;
3. JSON/structured files;
4. logs;
5. other non-invasive integration.

Do not tightly couple Mosaic to Termica internals.

If Termica is unavailable, Mosaic must continue functioning.

---

# 39. Adaptive Resource Manager

Mosaic must monitor and limit its own resource consumption.

Default:

**Adaptive**

Additional modes:

- Performance;
- Eco;
- Paused;
- Custom.

Consider:

- CPU;
- system load;
- battery;
- power source;
- temperature;
- user activity.

Examples:

- pause bulk OCR during high temperature;
- reduce embeddings on battery;
- perform heavy indexing while connected to power and idle.

Mosaic itself must not become a significant source of system slowdown or overheating.

---

# 40. File Safety / Backup Awareness

Provide visibility into file protection.

Where technically feasible, indicate whether a file appears to be:

- local only;
- present in cloud;
- duplicated elsewhere;
- covered by Time Machine;
- at potential risk because only one copy exists.

Do NOT attempt to replace Time Machine.

---

# 41. Applications Manager

Create an Applications module.

Potential information:

- installed applications;
- size;
- last-used information;
- version;
- installation source;
- associated helpers;
- login items;
- associated residue files;
- update state where discoverable.

Provide uninstall analysis with preview.

Do not silently delete application support files.

---

# 42. Software Maintenance

Monitor:

- macOS updates;
- App Store applications;
- Homebrew packages;
- Homebrew casks;
- external applications where update detection is reliable.

Workflow:

**Detect → Review → Update**

Avoid uncontrolled mass updates.

---

# 43. Network & Connectivity

Create a Network module.

Potential information:

- Wi-Fi;
- Ethernet;
- local IP;
- public IP where appropriate;
- DNS;
- latency;
- connectivity;
- mounted NAS;
- SMB state;
- reachability;
- cloud availability;
- network diagnostics.

Provide configurable targets for monitoring.

---

# 44. Network History

Store configurable historical telemetry.

Potential information:

- outages;
- reconnects;
- latency changes;
- NAS availability;
- network interface changes.

Allow retention settings:

- 7 days;
- 30 days;
- 90 days;
- 365 days;
- custom.

Avoid invasive packet inspection.

---

# 45. Notification & Alert Center

Use native macOS notifications.

Alert severity:

- Info;
- Warning;
- Critical.

Possible alerts:

- low disk space;
- high temperature;
- degraded battery;
- NAS unavailable;
- failed indexing;
- mail index problem;
- source disconnected;
- declutter review ready;
- system issue.

Allow:

- category disable;
- snooze;
- history;
- configurable thresholds.

---

# 46. Mosaic Modes

Support global behavioral profiles.

Initial profiles:

### Work

Full professional functionality.

### Focus

Reduce distractions.

### Private

Pause non-essential history collection.

At minimum consider suspending:

- Activity Timeline;
- Clipboard History;
- optional behavioral history.

### Presentation

Suppress intrusive notifications.

### Travel

Reduce background activity and power usage.

### Custom

Fully configurable.

Modes should be accessible from:

- dashboard;
- menu bar;
- Command Palette.

---

# 47. Menu Bar Utility

Create a lightweight Menu Bar component.

It should NOT replicate the whole dashboard.

Possible information:

Mac — Normal  
CPU 18%  
RAM 62%  
54 °C  
Disk 71%  
Battery 83%  
Keyboard: Logitech → IT  
Index: Healthy

Possible quick actions:

- Search;
- Clipboard;
- Clean;
- Health;
- Keyboard;
- Reindex;
- Open Dashboard.

Allow users to select what information appears.

The menu-bar icon may visually indicate problems without becoming distracting.

---

# 48. Safety Engine

All potentially destructive actions must pass through a central Safety Engine.

Risk levels should be classified.

Low-risk actions may eventually be automatically authorized by explicit user configuration.

Higher-risk actions must remain protected.

Examples:

- deleting files;
- bulk moving;
- batch rename;
- removing caches;
- deleting application support data;
- changing system settings.

---

# 49. Undo Center

Where technically possible, all modifying operations should be reversible.

Prefer:

- Trash;
- quarantine;
- transaction logs;
- reversible renames;
- reversible moves;
- rollback data.

Create a central **Undo Center**.

Do not promise reversibility where macOS or external systems cannot guarantee it.

---

# 50. Audit Trail

Maintain an Activity Log for Mosaic operations.

Examples:

- file moved;
- file renamed;
- file deleted;
- declutter action;
- indexing;
- keyboard layout change;
- automation execution;
- notification;
- AI action proposed;
- AI action approved;
- rollback;
- errors.

Allow:

- filtering;
- search;
- export.

---

# 51. Permission Center

Create a dedicated Permission Center.

Possible permissions include:

- Full Disk Access;
- Accessibility;
- Automation;
- Notifications;
- Contacts;
- Calendar;
- Reminders;
- selected folders;
- other macOS permissions.

Use **just-in-time permission requests**.

Do not overwhelm the user with all permissions at first launch.

Status examples:

- Granted;
- Missing;
- Limited;
- Error.

Explain:

- why permission is needed;
- what functionality depends on it;
- how to fix the issue.

---

# 52. Diagnostics & Repair

Create a centralized diagnostics engine.

Include:

**Run Health Check**

This initial check must be non-destructive.

Diagnose:

- Mosaic index;
- Spotlight dependency;
- Mail index;
- source accessibility;
- NAS;
- cloud folders;
- permissions;
- Mosaic database;
- Termica adapter;
- background services.

Repairs that change data or system state must pass through Safety Engine.

---

# 53. Index Health

Provide a dedicated Index Health view.

Show:

- indexed files;
- indexed mail;
- pending items;
- errors;
- indexing speed;
- last successful run;
- database size;
- OCR queue;
- semantic queue.

Provide selective reindexing.

Avoid forcing full reindex unnecessarily.

---

# 54. Smart Root-Cause Analysis

Mosaic should distinguish between failures.

Example:

A missing Google Drive document might result from:

- Google Drive disconnected;
- source not mounted;
- permission denied;
- indexing lag;
- excluded directory;
- Mosaic index corruption.

Do not simply display:

“File not found.”

Prefer actionable diagnoses.

---

# 55. Onboarding Wizard

Create a polished onboarding process.

Suggested steps:

1. Welcome to Mosaic.
2. Configure Sources.
3. Configure Mail Sources.
4. Detect keyboards.
5. Configure permissions.
6. Choose AI privacy preference.
7. Configure Decluttering.
8. Detect / configure Termica.
9. Configure initial Home layout.
10. Start initial indexing.

Allow:

- Skip;
- Configure later.

Provide a final checklist for incomplete setup.

Initial indexing must not block application usage.

---

# 56. Configuration Backup & Restore

Allow export/import of Mosaic configuration.

Possible content:

- preferences;
- Sources;
- Projects;
- rules;
- thresholds;
- automations;
- keyboard mappings;
- exclusions;
- Modes;
- Home layout.

Offer different backup levels:

### Configuration only

Default preferred option.

### Configuration + selected local data

Optional.

### Advanced backup

May include logs/database if explicitly requested.

Sensitive backups should support encryption.

---

# 57. Multi-Mac Architecture

Mosaic V1 is:

**single-Mac only.**

Do NOT implement multi-Mac synchronization now.

However, architecture and data model should be designed so future multi-device support is possible.

Use stable identifiers and avoid assumptions that would prevent future device synchronization.

---

# 58. Browser Integration

Browser extensions are:

**OUT OF SCOPE FOR V1.**

Do not implement Safari, Chrome, or Chromium extensions now.

However, avoid architectural choices that make future browser integration unnecessarily difficult.

---

# 59. Privacy

Mosaic will potentially access highly personal information.

Privacy must be treated as a primary architectural requirement.

Principles:

- local-first;
- minimum necessary access;
- no silent upload;
- no hidden telemetry;
- transparent AI processing;
- clear exclusion rules;
- configurable retention;
- easy pause;
- easy deletion.

Private Mode must clearly indicate when history-related modules are suspended.

---

# 60. Security

Sensitive tokens/API credentials must use appropriate secure storage such as macOS Keychain or equivalent.

Never store API keys in:

- plain-text source code;
- configuration files;
- logs;
- SQLite fields without appropriate protection.

Follow macOS security best practices.

---

# 61. Performance

Mosaic should feel instantaneous for normal UI interactions.

Do not run expensive content extraction on the UI thread.

Use:

- queues;
- background workers;
- incremental indexing;
- caching;
- prioritization.

Search should return partial/high-confidence results quickly while slower sources continue if necessary.

---

# 62. Failure Isolation

A failure in one module must not crash Mosaic.

Examples:

- Termica unavailable;
- NAS offline;
- Gmail authentication expired;
- OCR failure;
- cloud source unavailable.

Each adapter should fail gracefully.

---

# 63. Logs

Implement internal technical logging.

Separate:

- user-facing Activity Log;
- developer/system logs.

Logs must avoid storing passwords, tokens, clipboard secrets, or unnecessary document content.

---

# 64. Core V1 Priority

The first genuinely usable Mosaic release should prioritize:

1. Application shell and premium UI.
2. Home Dashboard.
3. Sources.
4. Universal Search.
5. hybrid file indexing.
6. full-text file search.
7. basic semantic search.
8. Mail Search.
9. Mail diagnostics.
10. Keyboard Manager.
11. Decluttering.
12. Smart Organizer.
13. System Health.
14. Termica integration.
15. Menu Bar Utility.
16. Permission Center.
17. Safety Engine.
18. Undo architecture.
19. Diagnostics & Repair.

Do not sacrifice these core functions in order to prematurely implement every roadmap feature.

---

# 65. Suggested Phase 2

After V1 stabilizes:

- Clipboard Manager;
- AI Rename;
- advanced batch operations;
- Related Items;
- Activity Timeline;
- Work Sessions;
- Resume Work;
- Projects;
- Network History;
- Application Manager;
- Software Maintenance;
- advanced automations;
- File Safety analysis.

Architecture for these features may already exist in V1.

---

# 66. Future Architecture Only

Prepare but do not implement:

- multi-Mac synchronization;
- browser extension;
- remote access;
- shared/team Mosaic;
- mobile companion app.

---

# 67. Testing

Create automated testing where meaningful.

Include:

- unit tests;
- indexing tests;
- file operation tests;
- migration tests;
- permission-state tests;
- safety classification tests;
- duplicate detection tests;
- rule-engine tests.

Destructive test operations must use controlled temporary test environments.

---

# 68. Data Migration

Database schemas and indexes will evolve.

Create a versioned migration system from the beginning.

Avoid requiring users to destroy their Mosaic database after every upgrade.

---

# 69. Development Documentation

Maintain:

- README;
- architecture document;
- data model;
- module map;
- permission matrix;
- security model;
- AI architecture;
- indexing architecture;
- adapter documentation;
- roadmap;
- changelog.

---

# 70. Decision Log

Maintain a technical **Architecture Decision Record**.

For important decisions document:

- problem;
- alternatives;
- chosen solution;
- rationale;
- consequences.

The agent has technical autonomy, but architectural decisions must remain inspectable.

---

# 71. User Approval Boundary

The coding agent may autonomously decide:

- implementation details;
- data structures;
- internal libraries;
- test frameworks;
- performance optimizations;
- technical patterns.

The coding agent MUST request user approval before materially changing:

- UX;
- workflow;
- feature scope;
- privacy behavior;
- data sent to cloud;
- destructive behavior;
- default automation behavior;
- visual design direction;
- requested functional requirements.

---

# 72. Initial Task for the Coding Agent

Do NOT begin by implementing hundreds of features.

Begin with a **Discovery and Architecture Phase**.

Produce:

### A. Architecture Proposal

Recommend the technical stack and explain why.

### B. Module Architecture

Show how major Mosaic modules communicate.

### C. macOS Integration Assessment

Identify native APIs/frameworks required.

### D. Permission Matrix

List required macOS permissions per feature.

### E. Data Model

Define high-level database entities.

### F. Search Architecture

Explain:

- Spotlight;
- Mosaic index;
- full text;
- semantic search;
- OCR;
- ranking.

### G. AI Architecture

Explain:

- local models;
- embeddings;
- vector storage;
- cloud fallback;
- privacy.

### H. Background Services Architecture

Explain scheduling and resource management.

### I. Termica Integration Plan

Inspect the existing Termica project before choosing the integration mechanism.

### J. UI Information Architecture

Create the navigation structure.

### K. Milestone Plan

Break implementation into concrete deliverable milestones.

### L. Risk Register

Identify technical risks.

Examples:

- Apple security limitations;
- email-client access;
- Full Disk Access;
- input-source switching;
- Spotlight behavior;
- cloud providers;
- sandboxing;
- background execution;
- system telemetry access.

---

# 73. Do Not Guess

If a technical capability may be restricted by macOS:

investigate it first.

If the requested behavior cannot be safely or reliably implemented exactly as described:

do not silently substitute another behavior.

Explain:

- the limitation;
- why it exists;
- available alternatives;
- recommended solution.

Request user approval if the alternative materially changes the UX.

---

# 74. Final Product Goal

Mosaic should eventually allow the user to interact with their Mac almost as if the computer had a unified memory.

Examples:

“Where is the PDF I was working on yesterday?”

“Find the email that contained the quote for the NAS.”

“What was I doing Tuesday afternoon?”

“Find every version of the NUSES schedule.”

“Why was my Mac running hot yesterday?”

“Which files are consuming unnecessary space?”

“Organize my Downloads, but show me what you would do first.”

“Resume the NUSES project.”

The final experience should make fragmented information across macOS feel connected, searchable, understandable, and actionable.

That is the central purpose of:

# MOSAIC
### Your Mac. Connected.
