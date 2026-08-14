# ADR-018 — POS Runtime and Workstation Architecture

**Status:** Proposed
**Date:** 2026-08-13
**Decision owners:** ShelfSense architecture
**Scope:** POS workstation runtime, cashier UI, local persistence, supported platforms, deployment, hardware integration, installation identity, durability, recovery, updating, and customer-facing display

---

## 1. Context

ShelfSense requires a separately deployable point-of-sale application capable of completing ordinary register operations without continuous access to the central ShelfSense server.

The central ShelfSense application remains a Rails/PostgreSQL system and owns organization-wide master and consolidated data. POS workstations must maintain sufficient local state to remain operational while disconnected.

A workstation must eventually support offline-capable operations including:

* POS user authentication and authorization;
* merchandise and identifier lookup;
* price resolution;
* discounts and price overrides;
* tax calculation;
* open and suspended transactions;
* transaction completion;
* permitted returns and exchanges;
* tender recording;
* local receipt numbering;
* drawer sessions;
* cash movements and counts;
* Z-periods;
* receipt printing;
* printer-attached cash-drawer control;
* durable outbound synchronization;
* reconciliation after reconnecting.

The cashier interface has one overriding usability requirement:

> **Every ordinary POS workflow must be fully operable using only a keyboard.**

Mouse and touch input may be supported, but neither may be required.

Expected workstation peripherals are intentionally limited:

* keyboard-wedge barcode scanner;
* receipt printer exposed through the operating system or otherwise supported by a printer adapter;
* cash drawer attached to the receipt printer;
* optional customer-facing second display.

Rich graphical presentation on the cashier display is not a primary requirement.

ShelfSense POS must run across:

* Windows;
* macOS;
* Linux.

---

# 2. Decision

ShelfSense POS will be implemented as a **.NET application using Terminal.Gui for the cashier interface and SQLite for durable workstation-local storage**.

The architecture is:

```text
ShelfSense POS Workstation
│
├── .NET
│
├── Terminal.Gui
│   └── fully keyboard-operable cashier UI
│
├── POS application/domain layer
│   ├── transaction lifecycle
│   ├── merchandise lookup
│   ├── pricing
│   ├── overrides
│   ├── discounts
│   ├── tax
│   ├── tendering
│   ├── returns
│   ├── approvals
│   ├── drawer operations
│   ├── Z-period operations
│   ├── receipt sequencing
│   └── synchronization
│
├── SQLite
│   ├── workstation/installation state
│   ├── reference cache
│   ├── offline authorization cache
│   ├── open/suspended transactions
│   ├── completed transactions
│   ├── receipt sequence
│   ├── drawer/Z state
│   ├── cash facts
│   ├── durable outbox
│   └── reconciliation state
│
├── Platform adapters
│   ├── printing
│   ├── cash drawer
│   ├── credential protection
│   ├── filesystem
│   └── application lifecycle
│
├── Optional customer-display adapter
│   └── second monitor
│
└── HTTPS API
    └── ShelfSense Rails server
```

The POS does **not** connect directly to the central PostgreSQL database.

---

# 3. Governing principles

The POS runtime follows these principles:

1. **Offline-first ordinary operation.** Loss of network connectivity must not stop operations that are locally authorized and classified as offline-capable.

2. **Local completion is authoritative at origin.** A completed workstation transaction is a durable local fact before synchronization begins.

3. **Completion precedes peripherals.** A sale is committed before receipt printing or cash-drawer commands are attempted.

4. **Keyboard operation is contractual.** Keyboard-only support is not a convenience feature.

5. **Local SQLite is not disposable cache.** It may contain the only existing copy of unsynchronized financial facts.

6. **One logical workstation has one active originating installation.**

7. **Platform-specific behavior remains at the application edge.** Pricing, tax, transaction, tender, cash, and synchronization behavior must remain platform-independent.

8. **Completed facts are not silently rewritten.** Sync or reconciliation may accept, warn, quarantine, or create compensating facts, but does not mutate the original completed workstation fact.

---

# 4. Runtime and framework

## 4.1 .NET

ShelfSense POS will target the current ShelfSense-supported **.NET LTS release**.

The initial implementation target is:

```text
.NET 10 LTS
```

ShelfSense should adopt supported security and servicing updates within the selected LTS generation.

The application should normally be published as a **self-contained deployment** so POS machines do not require separately managed .NET runtime installation.

---

## 4.2 Terminal.Gui

Terminal.Gui is the cashier presentation framework.

Terminal.Gui views are presentation components only. They must not contain authoritative pricing, tax, tender, completion, receipt-sequencing, or inventory logic.

The primary flow is:

```text
Keyboard / scanner input
        ↓
POS command
        ↓
application service
        ↓
domain/calculation logic
        ↓
SQLite / integrations
```

not:

```text
UI control callback
        ↓
financial logic embedded in view
```

---

# 5. Supported operating systems and CPU architectures

ShelfSense POS is **cross-platform by design**.

First-class release families are:

| Operating system |       x64 |     ARM64 |
| ---------------- | --------: | --------: |
| Windows          | Supported | Supported |
| macOS            | Supported | Supported |
| Linux            | Supported | Supported |

Release runtime identifiers will therefore include:

```text
win-x64
win-arm64

osx-x64
osx-arm64

linux-x64
linux-arm64
```

## 5.1 Unsupported architectures

32-bit/x86 platforms are not supported.

musl-based Linux distributions are not initially supported.

ShelfSense will not initially publish:

```text
win-x86
linux-x86
linux-musl-x64
linux-musl-arm64
```

unless a concrete future requirement justifies them.

---

# 6. Platform certification

Framework compatibility does not by itself constitute ShelfSense support.

ShelfSense will maintain a **certified platform matrix** consisting of:

```text
OS version
+
CPU architecture
+
terminal environment
+
printer compatibility where applicable
```

## Windows

ShelfSense will certify selected currently supported Windows desktop versions compatible with the selected .NET LTS release.

The normal target is modern Windows, rather than maintaining broad compatibility with legacy Windows installations merely because .NET may technically run on them.

## macOS

ShelfSense will certify selected currently supported macOS releases compatible with the selected .NET LTS release.

Both Intel and Apple Silicon may be supported while the respective ShelfSense release target remains useful.

## Linux

ShelfSense will initially certify:

* Ubuntu LTS;
* Debian Stable;

on:

* x64;
* ARM64.

Other conventional glibc Linux distributions may work but are not initially part of the guaranteed certification matrix.

ShelfSense uses common:

```text
linux-x64
linux-arm64
```

artifacts rather than distribution-specific application builds unless later required.

---

# 7. Terminal and keyboard certification

Terminal.Gui depends on the terminal environment supplied by the host OS.

ShelfSense therefore certifies **terminal environments**, not merely operating systems.

Initial certification should include a standard terminal environment for each platform, for example:

* Windows: a supported Windows console/terminal environment;
* macOS: Terminal.app or another explicitly certified terminal;
* Linux: one or more explicitly certified terminal emulators used on supported Ubuntu/Debian installations.

Exact terminal products belong in the compatibility matrix rather than this ADR.

## 7.1 Keyboard invariant

> **Every ordinary cashier, tender, drawer, and register workflow must be completable without a mouse, touchscreen, or pointing device on every certified platform/terminal combination.**

Mouse support may be added for convenience.

It must never be the sole method of performing a POS action.

---

# 8. POS command model

Major functions should be exposed as application commands.

Illustrative mappings:

```text
F2   Find / Lookup
F3   Quantity
F4   Void
F5   Price Override
F6   Discount
F7   Open Ring
F8   Suspend / Recall
F9   Tender
F10  Complete

Enter  Accept / Continue
Esc    Cancel / Back
↑ ↓    Move selection
Tab    Secondary field navigation
```

The exact mappings are configuration, not domain behavior.

Required rules:

* commands must work predictably regardless of incidental UI focus;
* OS-reserved key combinations should be avoided;
* function-key mappings must be configurable;
* available shortcuts should be visible where practical;
* changing a key binding must not change the command's business behavior.

---

# 9. Input contexts and barcode scanning

Barcode scanners are initially assumed to operate as **keyboard-wedge devices**.

No scanner-specific SDK is required.

ShelfSense treats scanned identifier input and manually typed identifier input through the same lookup path.

However, keyboard input meaning depends on explicit UI context.

Example contexts include:

```text
READY / NORMAL
  input → identifier capture

SEARCH
  input → search text

TENDER
  input → tender workflow

APPROVAL
  input → approval credential

DRAWER COUNT
  input → count workflow
```

A barcode scan must not accidentally populate an approval PIN, tender amount, or unrelated modal because the scanner presents itself as a keyboard.

After ordinary commands complete or cancel, the POS should deliberately return to a predictable ready-for-scan state.

---

# 10. Keyboard testing

Keyboard operability is testable functionality.

Critical workflows must eventually have interaction tests equivalent to:

```text
Scan identifier
F3
Enter quantity
Enter
F9
Choose Cash
Enter amount presented
Enter
F10
```

with assertions against resulting domain and persistence state.

Testing must cover each certified OS/terminal combination at the compatibility level appropriate to that platform.

---

# 11. Application layering

The POS should maintain clear separation between presentation, application logic, domain calculations, persistence, and platform integrations.

```text
┌─────────────────────────────┐
│ Terminal.Gui Presentation   │
└─────────────┬───────────────┘
              │ commands / queries
              ▼
┌─────────────────────────────┐
│ POS Application Services    │
│                             │
│ AddItem                     │
│ ChangeQuantity              │
│ ApplyOverride               │
│ ApplyDiscount               │
│ RecordTender                │
│ CompleteTransaction         │
│ CloseDrawer                 │
│ RunZ                        │
└─────────────┬───────────────┘
              ▼
┌─────────────────────────────┐
│ Domain / Calculations       │
│                             │
│ pricing                     │
│ discount allocation         │
│ tax                         │
│ settlement                  │
│ returns                     │
│ cash reconciliation         │
└─────────────┬───────────────┘
              ▼
┌─────────────────────────────┐
│ Persistence / Adapters      │
│                             │
│ SQLite                      │
│ HTTPS sync                  │
│ printer                     │
│ cash drawer                 │
│ credential store            │
└─────────────────────────────┘
```

This separation is required in part because Rails and .NET must reproduce the same financial contracts.

---

# 12. SQLite ownership

Every active workstation installation owns one durable local SQLite database.

The database is **workstation installation state**, not cashier state.

Changing the operating-system user or POS cashier must not result in a different POS database.

The database must not be placed on a shared network filesystem.

Correct:

```text
Register 1 → local pos.db
Register 2 → local pos.db
Register 3 → local pos.db
```

Incorrect:

```text
Register 1 ─┐
Register 2 ─┼→ shared network pos.db
Register 3 ─┘
```

Cross-register coordination occurs through the ShelfSense synchronization protocol.

---

# 13. Single application instance

Exactly one ShelfSense POS application instance may own an active workstation installation and its database at a time.

This protects:

* open transaction ownership;
* receipt sequencing;
* drawer state;
* Z-period state;
* hardware access;
* synchronization workers.

The implementation must use an operating-system-level single-instance mechanism or equivalent robust process lock.

SQLite's ability to serialize multiple writers is **not** considered sufficient authorization for multiple POS processes.

---

# 14. Local database contents

The SQLite database should contain at least the following logical areas.

## 14.1 Installation state

* installation ID;
* logical workstation ID;
* store ID;
* schema version;
* reference cursor/version;
* software/runtime metadata;
* synchronization state.

## 14.2 Cached reference data

* products;
* variants;
* identifiers;
* relevant individually tracked units;
* departments;
* merchandise classifications;
* prices;
* tax configuration;
* tender types;
* POS users;
* cached offline authorization data;
* permissions;
* approval policies;
* reason codes.

## 14.3 Working state

* open transactions;
* suspended transactions;
* active line state;
* provisional adjustments;
* applicable workflow state required for crash recovery.

## 14.4 Completed facts

* transactions;
* line snapshots;
* discounts and allocations;
* tax snapshots;
* tenders;
* return linkage;
* POS activity/audit facts.

## 14.5 Register operations

* receipt sequence;
* Z-periods;
* drawer sessions;
* cash movements;
* counts;
* reconciliation data.

## 14.6 Synchronization

* durable outbound operations;
* idempotency keys;
* payload hashes;
* acknowledgment state;
* warnings/quarantine status;
* reconciliation results.

---

# 15. SQLite durability

ShelfSense will initially use:

```sql
PRAGMA journal_mode = WAL;
PRAGMA synchronous = FULL;
PRAGMA foreign_keys = ON;
```

The POS prioritizes durable financial completion over maximizing transaction throughput.

Secondary tuning such as:

```text
busy_timeout
wal_autocheckpoint
journal_size_limit
cache_size
```

is an implementation/performance decision and should be validated through testing.

---

# 16. Transaction completion boundary

The critical durability invariant is:

> **ShelfSense may report a transaction as completed only after all locally authoritative completion facts have successfully committed in one SQLite transaction.**

Conceptually:

```text
validate transaction
        ↓
BEGIN
        ↓
freeze transaction
assign business date
assign Z-period
assign receipt identity
freeze line snapshots
record discounts
record tax
record tenders
record inventory operation(s)
record completion event
insert durable outbound operation
        ↓
COMMIT
        ↓
COMPLETED
        ↓
peripheral actions
        ├── cash drawer
        └── receipt printing
```

The outbox operation required to synchronize the completed transaction must commit in the **same local transaction** as completion.

Therefore:

> If the completed fact exists locally, the durable synchronization operation also exists locally.

---

# 17. Crash semantics

## Crash before commit

The transaction is not completed.

There must be:

* no completed tender fact;
* no completed sale fact;
* no completed inventory effect;
* no completion receipt presented as successful.

Working state may remain recoverable.

## Crash after commit

The transaction is completed even if:

* the UI did not refresh;
* the printer was never contacted;
* the drawer never opened;
* synchronization never started.

On restart, the application reconstructs truth from SQLite.

It must not infer financial state from whichever screen was visible before the crash.

---

# 18. Disk-full and I/O failure behavior

ShelfSense must monitor local storage health and free disk space.

Conceptual states:

```text
NORMAL
LOW
CRITICAL
```

At LOW:

* warn locally;
* rotate bounded diagnostic logs;
* prune backups eligible for normal retention cleanup.

At CRITICAL:

> ShelfSense must refuse to begin new financial work when there is insufficient storage headroom to guarantee a reasonable completion attempt.

Exact thresholds are operational configuration and should be determined by testing.

Every write must still handle storage failures regardless of preflight checks.

If SQLite completion fails because of:

* disk full;
* I/O error;
* corruption;
* failed synchronization to durable storage;
* other commit failure;

then the POS transaction is **not completed**.

ShelfSense must not:

* print a completion receipt;
* open the drawer as a completion side effect;
* tell the cashier that the sale succeeded.

---

# 19. Corrupt or missing database behavior

ShelfSense must **never silently create a fresh production POS database** because the expected database is missing, unreadable, or corrupt.

Doing so could silently reset:

* receipt numbering;
* installation identity;
* drawer state;
* Z-period state;
* unsynchronized transactions.

Instead ShelfSense enters a controlled state such as:

```text
RECOVERY REQUIRED
```

and prevents normal register operation until the database is recovered or the workstation is explicitly reprovisioned.

---

# 20. Local backup

Local backups protect against:

* failed migration;
* logical corruption;
* application defects;
* accidental database modification.

They do **not** protect against catastrophic loss of the storage device when stored on the same disk.

ShelfSense should create a SQLite-aware backup:

* before every local schema migration;
* on a regular rolling schedule while the database changes;
* optionally on graceful shutdown when unsynchronized work exists.

Retention should be bounded.

An illustrative policy might retain hourly and daily backups, but exact retention is operational policy.

The application must not simply copy a live SQLite/WAL file using an unsafe generic filesystem copy.

---

# 21. Catastrophic workstation loss

Recovery protection is layered:

```text
SQLite durability
    ↓
protects committed local facts

Local backup
    ↓
protects against local logical/schema damage

Server synchronization
    ↓
protects acknowledged facts against workstation loss
```

Unsynchronized transactions whose only copy existed on a catastrophically failed storage device may be unrecoverable.

ShelfSense should mitigate this risk through:

* durable local commits;
* frequent synchronization when connected;
* reliable storage;
* operational monitoring;
* optional stronger backup strategies where required.

The architecture must not claim that a same-disk local backup protects against disk failure.

---

# 22. SQLite migrations

The POS has its own ordered SQLite schema migrations independent of Rails/PostgreSQL migrations.

At startup after an application upgrade:

1. inspect local schema version;
2. verify compatibility;
3. create required pre-migration backup;
4. apply migrations transactionally where possible;
5. verify migration success;
6. start normal POS operation only after schema compatibility is confirmed.

A partially migrated database must never silently enter normal operation.

Migrations should favor backward-compatible expansion where practical.

Destructive schema contraction should be delayed because it complicates application rollback.

---

# 23. Logical workstation versus installation

ShelfSense distinguishes:

```text
Store
  ↓
Logical workstation
  ↓
Workstation installation
```

Example:

```text
Store: Downtown
Workstation: REG03
Installation: UUIDv7 A
```

If the computer is replaced:

```text
Store: Downtown
Workstation: REG03
Installation: UUIDv7 B
```

The logical workstation persists.

The physical/software installation changes.

---

# 24. Installation records

Conceptually, central installation state should record:

```text
workstation_installations

id
workstation_id
enrolled_at
revoked_at
last_seen_at
software_version
installation metadata
```

The exact schema is specified elsewhere.

Completed operations identify both:

* logical workstation;
* originating installation.

---

# 25. Single active originating installation

Only **one active installation** may originate new POS operations for a logical workstation at a time.

This protects:

* receipt sequencing;
* workstation identity;
* offline authority;
* duplicate local-origin operations.

A copied SQLite database does not create a second valid POS writer.

---

# 26. Installation credentials

The workstation installation must authenticate independently to the ShelfSense server.

The installation credential is distinct from:

* logical workstation ID;
* cashier user ID;
* offline cashier PIN/credential.

Conceptually:

```text
installation credential
    → authenticates workstation installation to server

offline POS credential
    → authenticates cashier to workstation
```

Sensitive installation authentication material should be stored using machine-protected operating-system facilities where practical rather than as plaintext inside SQLite.

Platform adapters may use suitable secure machine credential facilities for:

* Windows;
* macOS;
* Linux.

Exact cryptographic/enrollment mechanics are specified separately.

---

# 27. Local data security

The initial security model should rely primarily on:

* appropriate machine/file permissions;
* restricted POS OS account;
* machine-level disk encryption where appropriate;
* protected installation credentials;
* minimal sensitive cached data.

Database-level SQLite encryption is not required initially.

If regulatory or operational requirements later demand application-level database encryption, it can be added as a separate decision because it affects key management, backup, recovery, and cross-platform native dependencies.

---

# 28. Workstation enrollment

A new POS installation must be explicitly enrolled.

Enrollment establishes:

* store;
* logical workstation;
* unique installation ID;
* installation credential;
* supported software/protocol state;
* reference synchronization baseline;
* safe receipt-sequence starting point.

Simply copying application files or `pos.db` is not enrollment.

---

# 29. Workstation replacement

## Healthy handoff

Where the old workstation is available:

1. synchronize pending completed operations;
2. resolve or explicitly preserve open work;
3. capture current receipt sequence;
4. revoke/deactivate old installation;
5. enroll replacement installation;
6. establish a safe receipt high-water mark;
7. download current reference state;
8. begin operation.

## Lost workstation

If the old installation is destroyed or unavailable:

1. administrator marks it lost/revoked;
2. server determines the highest known receipt sequence;
3. recovery policy selects a safe new receipt starting point;
4. replacement installation is enrolled;
5. new workstation begins from the new safe sequence/range.

Receipt-number gaps are preferable to possible duplication.

---

# 30. Receipt sequence recovery

A recovered or replacement workstation must never simply resume from an older local backup's receipt sequence without considering the server-known high-water mark and recovery policy.

The rule is:

> **Receipt numbers may skip forward. They must not knowingly move backward or be reused.**

Recovery may intentionally reserve a new sequence range above the highest known value where uncertainty exists because unsynchronized transactions may have been lost.

---

# 31. Installation, uninstall, and decommissioning

These actions are distinct:

```text
install application
update application
repair application
uninstall application
```

versus:

```text
decommission workstation installation
wipe workstation POS data
```

Uninstalling ShelfSense POS must **not automatically delete**:

* `pos.db`;
* backups;
* installation state;
* receipt sequencing;
* unsynchronized operations.

Destructive decommissioning must be an explicit authorized operation.

Where possible, pending synchronization state should be resolved before data deletion.

---

# 32. Operating-system user lifecycle

The POS database belongs to the workstation installation, not the currently signed-in cashier.

Operating-system events such as:

* user logout;
* login;
* sleep;
* suspend;
* resume;

must not implicitly:

* close the drawer session;
* run a Z;
* cancel a transaction;
* complete a transaction;
* change historical business dates.

The application must recover gracefully after suspend/resume and reassess:

* connectivity;
* current clock;
* synchronization state;
* relevant reference state.

---

# 33. Clock, timestamps, and timezone

A workstation may operate offline, so its clock can affect business facts.

ShelfSense will therefore:

* cache the store timezone and business-date configuration;
* persist transaction timestamps as absolute instants;
* assign explicit `business_date` at transaction completion;
* preserve completed timestamps/business dates during later synchronization;
* never substitute server receipt time for the workstation's occurrence time;
* detect materially suspicious workstation clock drift when comparison becomes possible.

A server discovering clock drift may:

* warn;
* flag;
* quarantine according to policy;

but must not silently rewrite a completed local transaction's original occurrence data.

Historical records are unaffected by later operating-system timezone changes.

---

# 34. Receipt printing

Receipt printing is a platform adapter.

The preferred path is the host operating system's configured print subsystem.

Conceptually:

```text
Completed transaction
        ↓
Receipt document
        ↓
Receipt renderer
        ↓
IReceiptPrinter
        ↓
platform print adapter
        ↓
configured receipt printer
```

Likely adapters include:

```text
Windows printer adapter
macOS printer adapter
Linux/CUPS adapter
```

Vendor-specific printer SDK logic must not enter the POS domain layer.

---

# 35. Receipt representation

Receipt facts and printer commands are separate concerns.

ShelfSense should define a logical receipt representation capable of expressing such things as:

* text;
* line items;
* quantities;
* prices;
* discounts;
* tax;
* tender summaries;
* totals;
* separators;
* alignment;
* customer-visible messages;
* identifiers/barcodes/QR codes later.

The transaction itself remains the source of receipt facts.

Reprinting regenerates the receipt from immutable completed transaction data.

---

# 36. Printing does not define completion

A transaction can validly be:

```text
COMPLETED
receipt print submission failed
```

The cashier may retry/reprint without creating another transaction.

ShelfSense may track:

```text
print requested
submission accepted
submission failed
```

but cannot always determine whether paper physically exited the printer merely because an OS spooler accepted a job.

Therefore physical print success is not part of transaction atomicity.

---

# 37. Cash drawer

The drawer is represented separately from the receipt printer:

```text
IReceiptPrinter

ICashDrawer
```

even when the physical drawer is attached to the receipt printer.

An implementation may use:

* printer-driver capabilities;
* raw ESC/POS control sequences;
* another supported printer-mediated mechanism.

The POS domain calls a drawer capability, not a printer command.

---

# 38. Drawer-opening policy

The drawer may open for explicitly authorized operations such as:

* completed cash sale;
* completed cash refund;
* paid-in;
* paid-out;
* cash drop;
* opening/closing/count workflows requiring access;
* explicit authorized no-sale/open-drawer operation.

Printing a receipt does not itself imply drawer opening.

Specifically:

```text
REPRINT RECEIPT
```

must **not** automatically mean:

```text
OPEN DRAWER
```

---

# 39. Peripheral ordering

Where a completed cash transaction requires both drawer access and receipt printing:

```text
SQLite completion COMMIT
        ↓
transaction now completed
        ↓
cash-drawer command
receipt print submission
```

Peripheral calls happen after durable completion.

Failure of either peripheral does not roll back the completed transaction.

---

# 40. Peripheral failure

Examples:

```text
transaction completed
printer unavailable
```

or:

```text
transaction completed
drawer command failed
```

remain completed financial transactions.

ShelfSense surfaces an operational error and permits the user to resolve or retry the appropriate peripheral action.

It must not:

* duplicate the sale;
* reverse the transaction automatically;
* repeat inventory effects;
* repeat drawer operations unintentionally.

---

# 41. Hardware scope

The initial required hardware abstraction remains intentionally narrow:

```text
IReceiptPrinter
ICashDrawer
```

Keyboard-wedge scanners remain ordinary keyboard input.

Potential future abstractions such as:

```text
IScale
ICustomerDisplay
```

should be introduced only when a concrete use case requires them.

---

# 42. Customer-facing display

A customer-facing display is optional and **non-critical**.

Failure, disconnection, or absence of the display must never prevent:

* scanning;
* calculation;
* tendering;
* completion;
* printing;
* drawer operations.

The customer display should normally be a separate second-monitor presentation rather than mirroring the Terminal.Gui cashier UI.

---

# 43. Customer-display projection

The customer display receives a deliberately limited presentation model such as:

```text
status
store_name

lines[]
  description
  quantity
  unit_price
  extended_amount
  visible_discount

subtotal
discount_total
tax_total
total

tender_summary
amount_presented
change

message
```

It must not expose internal information such as:

* reference-price variance;
* manager approval details;
* internal inventory state;
* internal UUIDs;
* permission data;
* synchronization warnings;
* loss-prevention information.

---

# 44. Customer-display implementation boundary

Preferred initial direction:

```text
.NET POS
│
├── Terminal.Gui cashier interface
│
└── local customer-display service
          ↓
   graphical second-monitor view
```

A localhost HTTP/browser-kiosk implementation is a reasonable first candidate.

However, the exact display technology is not an architectural dependency of the POS core.

The customer display:

* communicates locally;
* owns no transaction state;
* does not write SQLite;
* does not independently query the central server;
* may disappear without affecting cashier operation.

---

# 45. Synchronization

The workstation communicates with ShelfSense through a versioned HTTPS API.

Synchronization is asynchronous relative to cashier operation.

```text
SQLite completion
      ↓
durable local outbox
      ↓
sync worker
      ↓
HTTPS
      ↓
Rails server
```

The sync worker runs within the POS process initially.

A separate daemon should not be introduced unless a concrete requirement justifies the additional process and database concurrency.

---

# 46. Connectivity behavior

ShelfSense should not require a separate "internet check" before deciding whether cashier workflows can proceed.

Instead:

```text
sync/API succeeds
    → connected

sync/API fails
    → retain durable work locally
    → retry according to policy
```

Retries should use controlled backoff and must not block cashier input.

Network/TLS configuration includes:

* server endpoint;
* certificate validation;
* request timeout;
* retry/backoff;
* reconnect behavior;
* optional future proxy support if required.

---

# 47. Software updates

ShelfSense should use one conceptual cross-platform update lifecycle rather than fundamentally different business behavior per OS.

A small launcher/updater may manage versioned application releases.

Conceptually:

```text
ShelfSense Launcher
│
├── installed release A
├── installed release B
├── selects active release
└── starts ShelfSense POS
```

Durable POS state lives outside replaceable application release directories.

---

# 48. Update process

A normal update is:

1. discover an available compatible release;
2. download package in background;
3. verify integrity/authenticity;
4. stage package;
5. wait for a safe operational point;
6. stop POS cleanly;
7. create pre-migration backup if required;
8. activate new release;
9. apply compatible SQLite migrations;
10. start new POS version;
11. verify normal startup.

An update must not replace executable files in the middle of transaction completion.

---

# 49. Safe update boundary

The updater must not interrupt transaction-critical work.

At minimum, update installation waits until there is no operation actively in a completion-critical section.

The exact relationship to:

* open transaction;
* suspended transaction;
* open drawer session;
* open Z-period;

is operational policy.

An update need not necessarily require closing an entire business period merely because an application restart is needed.

---

# 50. Rollback

Application rollback is allowed only when the current local database schema remains compatible with the older application.

A release that performs incompatible schema changes may require restoration of the pre-upgrade database backup rather than merely launching the older binary.

POS migrations should therefore prefer:

```text
expand
deploy/use
contract later
```

rather than immediate destructive changes.

---

# 51. Update classifications

ShelfSense may distinguish releases such as:

```text
available
recommended
required
```

Most updates should not unnecessarily interrupt register operations.

Security or protocol requirements may eventually mark a version as required.

However, a currently offline workstation should not become unusable merely because it cannot contact the server to discover whether a newer version exists.

Protocol support and minimum-version enforcement are specified by the synchronization/versioning contract.

---

# 52. Release integrity and platform trust

Release packages must be verifiable.

ShelfSense should support appropriate platform trust mechanisms including:

* Windows code signing;
* macOS signing/notarization;
* signed/verifiable Linux artifacts;
* signed updater metadata/packages.

The application's use of open-source frameworks does not eliminate platform-specific signing/distribution requirements.

Exact certificate and release infrastructure belongs to implementation/release engineering.

---

# 53. Application filesystem layout

Durable state must be separated from replaceable application files.

Conceptually:

```text
Application
  replaceable versioned binaries

Machine POS Data
  pos.db
  backups/
  logs/
  runtime state
```

Exact paths follow platform conventions.

Examples may include machine-scoped application data locations on Windows/macOS/Linux.

The ADR does not require `/opt` or another Linux-specific path as part of core application design.

---

# 54. Logging and diagnostics

Diagnostic logs are distinct from financial/audit facts.

Logs may contain:

* application startup/shutdown;
* application version;
* OS/architecture;
* database migration events;
* connectivity changes;
* synchronization failures;
* printing failures;
* drawer failures;
* updater events;
* unhandled exceptions;
* database integrity issues.

Logs must have bounded retention.

Logs are never an alternate source of truth for:

* sales;
* tenders;
* cash movements;
* Z reports;
* receipt identity.

Those remain structured domain records.

---

# 55. Support diagnostics

ShelfSense should provide a support/diagnostics view or export containing non-sensitive operational information such as:

```text
POS application version
.NET/runtime version
OS / CPU architecture
Terminal.Gui version
local database schema version
database health/integrity result
logical workstation
installation ID
store
current Z-period
drawer status
last successful sync
pending operation count
age of oldest pending operation
printer configuration
disk-space status
recent operational failures
```

Support output must not expose:

* plaintext offline credentials;
* installation secrets;
* unnecessary customer data;
* payment-sensitive values beyond operational need.

---

# 56. Unicode and text handling

ShelfSense data is Unicode throughout.

Catalog data, user-visible text, and POS snapshots must preserve Unicode correctly.

Printer limitations are handled by the printer/renderer adapter.

A printer incapable of representing a character must not cause ShelfSense to alter the authoritative transaction description merely to accommodate printer encoding.

Receipt rendering may use:

* supported printer encoding;
* font/raster output;
* fallback/transliteration where explicitly required.

Terminal font/glyph behavior should be covered by platform certification.

---

# 57. Open-source/runtime licensing

The initial POS software stack should require no paid POS runtime, database, or UI-framework license.

The architecture uses:

* .NET;
* Terminal.Gui;
* SQLite;
* standard/open platform facilities where practical.

Hardware firmware, printer drivers, operating systems, signing infrastructure, or vendor-provided device software may have their own licensing terms.

ShelfSense should prefer hardware that does not require proprietary application SDK integration.

---

# 58. Alternatives considered

## Tauri

Tauri was the primary alternative.

Advantages included:

* richer graphical UI;
* natural multi-window model;
* strong HTML/CSS presentation;
* straightforward graphical customer display.

It was not selected because:

* rich cashier graphics are not a priority;
* ShelfSense requires complete keyboard operation;
* Terminal.Gui naturally supports a command-oriented register;
* .NET provides one primary language/runtime for UI, application logic, synchronization, persistence, and hardware adapters;
* Tauri introduces a web-frontend/native boundary without satisfying a current requirement that Terminal.Gui cannot address.

Tauri is therefore rejected for the initial POS runtime.

It should be reconsidered only in response to a concrete Terminal.Gui limitation, not kept as a parallel implementation path.

---

# 59. Consequences

## Positive

The chosen architecture provides:

* true local offline operation;
* a keyboard-first cashier experience;
* a relatively small runtime stack;
* one main POS programming language;
* durable embedded persistence;
* straightforward scanner support;
* straightforward receipt printing;
* cross-platform deployment;
* x64 and ARM64 hardware flexibility;
* no required paid POS framework;
* a clean separation between cashier UI and customer presentation;
* explicit crash/recovery behavior;
* portable business logic independent of the central Rails UI.

## Negative

ShelfSense assumes responsibility for:

* maintaining a separate .NET application alongside Rails;
* local SQLite schema evolution;
* workstation backup/recovery;
* native application distribution;
* Windows/macOS/Linux certification;
* terminal emulator certification;
* code signing/notarization;
* printer/cash-drawer adapter compatibility;
* duplicated deterministic calculation implementations between Rails and .NET;
* workstation enrollment and credential lifecycle.

Terminal.Gui also constrains visual richness on the cashier display.

---

# 60. Required cross-platform contract fixtures

Because core financial logic exists in both Rails and .NET, equivalent behavior must be demonstrated through shared contracts/golden fixtures.

At minimum fixtures should cover:

* price resolution;
* price overrides;
* fixed discounts;
* percentage discounts;
* transaction-discount allocation;
* rounding;
* multiple tax components;
* tax treatment;
* return reversals;
* partial-return cents allocation;
* tender settlement;
* cash presented/change;
* completed transaction payload;
* receipt data;
* business-date assignment where deterministic inputs are supplied.

The goal is not identical implementation code.

The goal is:

> **Identical inputs and configuration produce the same authoritative financial result.**

---

# 61. Phase 4 runtime proof-of-concept

Before ADR-018 is moved from Proposed to Accepted, the Phase 4 runtime spike should demonstrate:

### Platform

* build self-contained application releases;
* run on at least representative Windows, macOS, and Linux systems;
* validate x64/ARM64 build strategy;
* validate selected certified terminal environments.

### Keyboard

* launch and sign in without pointer input;
* scan/type identifier;
* navigate transaction;
* quantity change;
* void;
* price override;
* approval modal;
* tender;
* complete transaction;
* drawer workflow;
* Z workflow;
* recover from modal cancellation;
* prove no tested workflow requires mouse/touch.

### SQLite

* initialize local database;
* apply migrations;
* operate with WAL + FULL;
* recover after ordinary restart;
* survive forced process termination;
* demonstrate no partial completed transaction;
* preserve receipt sequencing across restart.

### Completion/outbox

* complete transaction atomically;
* persist outbound operation in same commit;
* restart before synchronization;
* successfully resume and synchronize;
* submit same operation more than once without duplicating business effects server-side.

### Crash boundaries

Test forced failure:

* before SQLite commit;
* immediately after commit;
* before receipt print;
* after print submission;
* before sync;
* during sync.

### Disk/recovery

* simulate low disk warning;
* simulate write/commit failure;
* verify completion is rejected;
* verify missing/corrupt database enters controlled recovery;
* test pre-migration backup and recovery.

### Printing

* print through supported OS path;
* reprint without duplicating transaction;
* fail printer and retain completed transaction;
* restore printer and reprint.

### Drawer

* open through receipt-printer integration;
* verify drawer failure does not invalidate sale;
* verify receipt reprint does not open drawer;
* test authorized explicit drawer opening.

### Installation identity

* enroll workstation;
* persist installation identity;
* enforce single active local instance;
* reject cloned installation authority;
* revoke/re-enroll replacement;
* establish safe receipt sequence after replacement.

### Customer display

If implemented during Phase 4:

* display customer-safe transaction projection;
* disconnect/terminate customer display;
* verify cashier operation continues unaffected.

---

# 62. Decisions locked by this ADR

| Area                        | Decision                                           |
| --------------------------- | -------------------------------------------------- |
| Runtime                     | **.NET**                                           |
| Initial .NET generation     | **.NET 10 LTS**                                    |
| Cashier UI                  | **Terminal.Gui**                                   |
| Local database              | **SQLite**                                         |
| Ordinary POS operation      | **Offline capable**                                |
| Keyboard requirement        | **100% keyboard operable**                         |
| Windows                     | **First-class supported platform**                 |
| macOS                       | **First-class supported platform**                 |
| Linux                       | **First-class supported platform**                 |
| CPU                         | **x64 and ARM64 only**                             |
| 32-bit                      | **Unsupported**                                    |
| Linux initial certification | **Ubuntu LTS + Debian Stable**                     |
| musl/Alpine                 | **Not initially supported**                        |
| Deployment                  | **Self-contained .NET release**                    |
| Local DB scope              | **Machine/workstation installation**               |
| Shared SQLite               | **Prohibited**                                     |
| Local application writers   | **One active POS instance**                        |
| SQLite journal              | **WAL**                                            |
| SQLite synchronous policy   | **FULL**                                           |
| Foreign keys                | **Enabled**                                        |
| Completion/outbox           | **Single SQLite transaction**                      |
| Receipt printing            | **After completion**                               |
| Drawer operation            | **After completion where applicable**              |
| Peripheral failure          | **Does not invalidate completed transaction**      |
| Scanner                     | **Keyboard wedge initially**                       |
| Receipt printer             | **Platform/OS print adapter preferred**            |
| Drawer                      | **Separate abstraction, printer-driven initially** |
| Installation identity       | **Separate from logical workstation**              |
| Active origin               | **One active installation per workstation**        |
| Uninstall                   | **Does not automatically wipe POS data**           |
| Customer display            | **Optional, second-monitor, non-authoritative**    |
| Sync transport              | **Versioned HTTPS API**                            |
| Direct PostgreSQL access    | **Prohibited**                                     |
| Update model                | **Staged/versioned self-update model**             |
| Release verification        | **Required**                                       |
| Corrupt DB behavior         | **Controlled recovery, never silent reset**        |
| Unicode                     | **Preserved throughout authoritative data**        |

---

# 63. Remaining implementation/certification details

The following do **not** block the architectural decision:

* exact default keyboard shortcuts;
* exact certified terminal emulator versions;
* exact Ubuntu/Debian versions in each release;
* exact Windows/macOS minimum versions;
* disk-space warning thresholds;
* local backup frequency and retention;
* exact updater implementation/library;
* application packaging formats;
* exact machine credential-store implementation;
* exact printer models;
* exact printer-native drawer command mechanism;
* exact receipt renderer;
* exact customer-display implementation;
* exact diagnostic bundle format.

These should be specified through implementation plans, compatibility matrices, and operational documentation rather than reopening the runtime architecture.

---

# 64. Decision summary

> **ShelfSense POS will be a cross-platform, self-contained .NET application using Terminal.Gui for a completely keyboard-operable cashier interface and SQLite for durable workstation-local state. Windows, macOS, and glibc Linux are first-class runtime families, with x64 and ARM64 builds. Each logical workstation has one active originating installation and one locally owned SQLite database. Completed transactions and their synchronization outbox records are committed atomically before receipt printing or drawer actions. Printer, drawer, credential, filesystem, and lifecycle differences are isolated behind platform adapters. A second-monitor customer display may provide graphical customer presentation but remains optional and non-authoritative. The application remains capable of ordinary offline POS operation and synchronizes immutable completed facts to the Rails organization server through a versioned HTTPS protocol.**
