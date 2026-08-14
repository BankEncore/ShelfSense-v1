# POS Domain Specification: Local Persistence

**Design status:** Core persistence and durability model decided
**Implementation status:** Required in Phase 4
**Initial delivery:** Phase 4 — POS Runtime and Contract Foundation
**Expanded delivery:** Phase 6B — POS Productization and Recovery
**Related specifications:** Workstation Identity, Transactions, Receipts, Reporting Periods, Cash Handling, Reference Replication, Operation Synchronization
**Related workflows:** POS Startup, Complete Transaction, Reference Application, Restart Recovery, Installation Recovery

---

## 1. Purpose

This specification defines the durability guarantees provided by the local ShelfSense POS database.

It establishes:

* ownership of the local SQLite database;
* the authority of locally persisted state;
* classes of local data;
* atomic transaction completion;
* transactional outbox requirements;
* restart behavior;
* reference-state persistence;
* handling of missing, corrupt, or identity-inconsistent local storage.

This specification does **not** define:

* synchronization protocol or retry behavior;
* central conflict resolution;
* workstation enrollment;
* receipt or Z sequence semantics;
* detailed database recovery procedures;
* backup/restore tooling;
* platform-specific storage paths;
* database maintenance and monitoring.

Those belong to their owning specifications, workflows, implementation plans, or runbooks.

---

## 2. Governing model

ShelfSense POS treats its local SQLite database as durable offline operational storage.

> **Business completion is defined by an atomic local commit that includes the completed business fact and its synchronization outbox record. After that commit, the operation remains completed through restart, peripheral failure, and loss of server connectivity.**

The local database is therefore more than a cache.

A workstation may contain completed authoritative originating facts that the organization server does not yet know about.

Conceptually:

```text
POS operation
    ↓
durable local commit
    ↓
locally completed
    ↓
outbox
    ↓
later synchronization
```

Central acknowledgment is not required for local completion.

---

## 3. Database ownership

One production SQLite database belongs to one POS installation.

```text
Installation
    ↓
Local SQLite Database
```

The database must durably preserve enough identity information to establish its binding to:

```text
installation
workstation
store
```

A production database must not be treated as interchangeable with another installation's database.

The same database identity must not intentionally be operated concurrently as multiple independent POS installations.

Detailed clone detection and replacement behavior belong elsewhere.

---

## 4. Classes of local state

ShelfSense distinguishes three broad classes of locally persisted state.

### 4.1 Originating business facts

Facts created by the workstation as part of POS operation.

Examples include:

* completed transactions;
* completed tenders;
* receipt identity;
* approvals;
* Z reports;
* drawer reconciliations;
* Cash operations.

These are durable business history.

They are not disposable cache data.

### 4.2 Replicated reference state

Data mastered centrally and copied to the POS for local operation.

Examples include:

* merchandise;
* identifiers;
* prices;
* tax configuration;
* tender configuration;
* authorization/reference data;
* workstation configuration.

The server remains authoritative for this data, but the local persisted copy must remain usable while offline.

### 4.3 Derived or rebuildable state

State calculated from more authoritative persisted facts.

Examples may include:

* search indexes;
* materialized summaries;
* expected-Cash projections;
* other local performance projections.

Where practical, derived state should remain rebuildable and must not become the only surviving representation of an originating business fact.

---

## 5. Working state

Mutable working state may also require persistence.

Examples include:

* open transactions;
* suspended transactions;
* active Z context;
* open drawer sessions.

If ShelfSense expects such work to survive an application restart, it must be persisted before the application relies on that behavior.

In-memory state alone is not durable POS state.

---

## 6. Local completion

A business operation becomes completed only after its required SQLite transaction commits successfully.

For a completed sale, the local transaction conceptually includes:

```text
BEGIN

completed transaction facts
receipt identity
business date / Z association
required local effects
outbound operation
outbox entry

COMMIT
```

Only after `COMMIT` may ShelfSense tell the cashier that the operation completed.

---

## 7. Atomicity

All facts required to represent one completed operation must commit atomically.

ShelfSense must not expose inconsistent states such as:

```text
transaction completed
but receipt identity missing
```

or:

```text
transaction completed
but synchronization operation missing
```

or:

```text
outbox operation committed
for a transaction that never completed
```

The exact records participating in each operation are defined by the owning domain and completion contract.

---

## 8. Transactional outbox

Every locally completed operation that must synchronize centrally must create its durable outbox entry as part of the same SQLite transaction.

Therefore:

```text
locally completed synchronizable operation
    ⇒
durable synchronization path
```

ShelfSense must not:

```text
commit business operation
then separately attempt to enqueue it later
```

because a crash between those steps could create a completed operation with no synchronization path.

The outbox transports the business fact; it is not itself the business authority.

---

## 9. Local completion versus synchronization

Local transaction lifecycle and synchronization status are separate.

A transaction may be:

```text
completed locally
not yet synchronized
```

and still be a valid completed originating fact.

The organization server later:

* receives;
* validates;
* acknowledges;
* warns;
* or reconciles

that operation according to synchronization and reconciliation rules.

Those later outcomes do not reopen the locally completed transaction.

---

## 10. Restart behavior

Any state required to safely continue POS operation after restart must already be persisted.

This includes, as applicable:

* completed operations;
* unsynchronized outbox items;
* receipt sequence state;
* active Z state;
* drawer-session state;
* open/suspended transactions;
* reference version/cursor.

Restart must recover persisted state rather than reconstructing business history from assumptions held only in memory.

---

## 11. Crash before commit

If the application or machine terminates before the completion transaction commits:

```text
completed operation = no
committed receipt identity = no
committed outbox item = no
```

ShelfSense must not infer successful completion merely because completion had begun.

---

## 12. Crash after commit

If the SQLite transaction commits before termination:

```text
completed operation = yes
receipt identity = permanent
outbox = durable
```

On restart, ShelfSense must recover that completed state.

The transaction must not become open again or require the cashier to complete it a second time.

---

## 13. Peripheral actions occur after commit

Physical/peripheral actions such as:

```text
print receipt
open cash drawer
```

occur after the durable business commit.

Peripheral failure does not roll back the completed business operation.

This ensures:

```text
database commit
    ↓
business completion
    ↓
peripheral delivery/action
```

rather than making the printer or drawer part of the financial transaction boundary.

---

## 14. Reference-state persistence

Replicated reference state must be persisted coherently.

The local reference cursor/version must mean:

> The corresponding reference changes have been durably applied.

Therefore reference data and the cursor/version describing it must be committed atomically.

Incorrect:

```text
cursor = version 100
local reference data only partially at version 100
```

Correct:

```text
BEGIN

apply reference changes
update local projections
advance reference cursor

COMMIT
```

The content and ordering of reference updates belong to `reference-replication.md`.

---

## 15. Persistence requirements

The initial POS persistence engine is SQLite.

Production configuration includes:

```text
PRAGMA journal_mode = WAL;
PRAGMA synchronous = FULL;
PRAGMA foreign_keys = ON;
```

ShelfSense favors durable completed operations over marginal write-performance gains.

The initial runtime also assumes one normal POS process mutates a production installation database at a time.

Detailed SQLite tuning belongs to implementation planning rather than this domain specification.

---

## 16. Schema versioning

The local database schema must be explicitly versioned and migrated through a controlled migration mechanism.

The POS must not enter normal operational mode when it cannot determine that the database schema is compatible with the running application.

Schema migration details, downgrade behavior, and release procedures belong to implementation planning.

---

## 17. Missing local database

If an enrolled installation expects an existing production database but the database is missing, ShelfSense must not silently create a blank database and continue under the same installation identity.

Instead:

```text
RECOVERY REQUIRED
```

The missing database may contain unsynchronized historical activity unknown to the server.

---

## 18. Corrupt or inconsistent local state

If ShelfSense cannot safely establish the integrity or installation identity of the local production database, ordinary POS operation must not continue.

Examples include:

* database cannot be opened safely;
* required installation identity is absent;
* local identity conflicts with expected installation/workstation binding;
* schema state cannot be understood.

The workstation enters explicit recovery rather than guessing or silently replacing state.

Detailed recovery procedures belong elsewhere.

---

## 19. Fresh replacement storage

A newly created empty database without recovered installation identity is not automatically the previous installation database.

If the old installation state cannot be recovered, Workstation Identity determines how a new installation is enrolled against the logical workstation.

Local Persistence must not fabricate continuity by assigning an empty database the identity of lost production storage.

---

## 20. Write failure

ShelfSense must not report a business operation as completed unless its required persistence transaction succeeds.

Conditions such as:

* disk full;
* read-only storage;
* SQLite commit failure;

therefore prevent successful completion.

Offline operation means independence from the central server.

It does **not** mean operation without durable local storage.

---

## 21. Unsynchronized facts are protected

Locally originated business facts awaiting synchronization must not be discarded through ordinary:

* cleanup;
* cache refresh;
* reference replacement;
* archival;
* log rotation.

> **Unsynchronized originating facts are durable business records until safely handled by synchronization/recovery policy.**

Reference state and rebuildable projections may have different retention rules because the server remains authoritative for them.

---

## 22. Local history after synchronization

Central acknowledgment does not inherently require deletion of the local business fact.

Local completed history may remain useful for:

* receipt reprinting;
* Z review;
* transaction lookup;
* support;
* diagnostics.

Retention and archival policy may be defined later.

---

## 23. Domain boundaries

### Local Persistence owns

* database ownership;
* durability guarantees;
* local transaction atomicity;
* transactional outbox persistence;
* restart persistence requirements;
* reference-state atomic application;
* schema-version requirement;
* missing/corrupt-storage safety behavior.

### Workstation Identity owns

* installation/workstation identity;
* installation replacement;
* enrollment.

### Transactions owns

* transaction lifecycle;
* which business facts are required for completion.

### Receipts owns

* receipt identity and sequence semantics.

### Reporting Periods owns

* Z identity, lifecycle, and sequence semantics.

### Cash Handling owns

* drawer and Cash business facts.

### Reference Replication owns

* reference contents;
* snapshot/delta semantics;
* cursor protocol.

### Operation Synchronization owns

* delivery;
* retry;
* acknowledgment;
* idempotency protocol.

### Reconciliation owns

* central conflicts and exception handling.

---

## 24. Phase 4 delivery

Phase 4 should implement:

* one SQLite database per installation;
* schema migrations/versioning;
* production SQLite durability configuration;
* local installation/workstation identity;
* persisted reference state;
* transaction/outbox atomicity;
* restart recovery of committed operations;
* atomic reference cursor updates;
* explicit recovery-required behavior for missing or inconsistent production storage.

Phase 4 should also prove durability through forced-termination tests around the local commit boundary.

---

## 25. Phase 5 usage

Phase 5 relies on Local Persistence for the first operational Cash sale.

At minimum, the completion transaction must durably preserve:

```text
transaction
transaction lines
price/tax facts
Cash tender
receipt identity
business date / Z context
outbound operation
outbox
```

before the POS reports successful completion.

Receipt printing and drawer-opening occur afterward.

---

## 26. Phase 6B expansion

Productization may later add:

* guided recovery;
* backup/restore;
* database diagnostics;
* storage monitoring;
* retention/archival;
* installation-replacement tooling;
* support exports.

These capabilities must preserve the durability and identity guarantees defined here.

---

## 27. Pending decisions

### 27.1 Physical local schema

Define tables and indexes as each owning domain is implemented.

This specification should not create a second parallel business model.

### 27.2 Installation credential storage

Determine which installation security material belongs in:

* SQLite;
* platform-protected credential storage;
* or both.

### 27.3 Local history retention

Determine how much acknowledged local business history should remain on the workstation.

Receipt reprinting and register lookup requirements should guide this decision.

### 27.4 Backup and restore

Define productized backup/restore only after workstation replacement, synchronization, and receipt/Z sequence recovery rules are sufficiently established.

### 27.5 Recovery tooling

Define how damaged or missing databases are diagnosed and recovered during productization.

The domain requirement is only that ordinary operation fails safely when durable identity/history cannot be trusted.

---

## 28. Core invariants

1. **One production SQLite database belongs to one POS installation.**
2. **The local database is durable operational storage, not merely a cache.**
3. **Originating facts, replicated references, and derived projections have distinct authority.**
4. **A locally completed operation does not require central acknowledgment to be completed.**
5. **A business operation becomes completed only after its required SQLite transaction commits.**
6. **Receipt identity and other required completion facts commit atomically with the business operation.**
7. **Every synchronizable completed operation commits with a durable outbox entry.**
8. **Crash before commit produces no completed operation.**
9. **Crash after commit preserves a completed operation and its synchronization path.**
10. **Any operational state required after restart must be durably persisted.**
11. **Reference state and its cursor/version are applied atomically.**
12. **Missing, corrupt, or identity-inconsistent production storage prevents ordinary POS operation and requires explicit recovery.**
13. **Persistence failure prevents ShelfSense from reporting successful completion.**
14. **Unsynchronized originating business facts may never be discarded as ordinary cache or cleanup.**
15. **Peripheral failure after commit does not change business completion.**

---

## 29. Acceptance examples

### Example A — offline completion

Given the workstation has no central connectivity,

when a sale commits successfully to SQLite,

then the transaction is completed locally and has a durable outbox path for later synchronization.

Network acknowledgment is not required.

---

### Example B — crash before commit

Given transaction completion has begun,

when the process terminates before SQLite commits,

then after restart there is no completed sale, committed receipt identity, or committed synchronization operation.

---

### Example C — crash after commit

Given transaction completion commits successfully,

when the process terminates before receipt printing or synchronization,

then after restart ShelfSense recovers:

* the completed transaction;
* its receipt identity;
* its pending synchronization operation.

The cashier does not complete the sale again.

---

### Example D — printer failure

Given the sale has committed,

when receipt printing fails,

then the transaction remains completed.

Printing may be retried without changing the completed transaction.

---

### Example E — reference update interrupted

Given the workstation is applying a reference update,

when the process terminates before the reference transaction commits,

then the previously coherent reference state and cursor remain in effect after restart.

The cursor does not falsely indicate that the interrupted update completed.

---

### Example F — active drawer restart

Given the database contains an open drawer session and completed Cash activity,

when the application restarts,

then the existing persisted drawer context is recovered rather than replaced with a new empty session.

---

### Example G — missing database

Given an installation previously operated using a production database,

when that database is missing at startup,

then ShelfSense enters recovery mode.

It does not silently create a blank database and continue as the same installation.

---

### Example H — persistence failure

Given the local database cannot commit because durable storage is unavailable,

when the cashier attempts to complete a sale,

then ShelfSense does not report the sale as successfully completed.

---

### Example I — synchronization acknowledgment

Given a completed sale has already synchronized centrally,

then central acknowledgment may update local synchronization metadata.

It does not redefine when the sale became completed.

---

### Example J — unsynchronized history

Given a locally completed transaction has not yet synchronized,

then ordinary cleanup or reference refresh must not delete that transaction or its synchronization path.

---

## 30. Related contracts

Local Persistence will eventually support exact contracts for:

### Completion boundary

Define which records must commit together for each completed operation.

### Transactional outbox

Define the durable relationship between an originating operation and its outbound synchronization entry.

### Reference application

Define the atomic relationship between replicated reference state and its cursor/version.

### Startup integrity

Define the minimum local identity/schema checks required before entering ordinary POS mode.

Detailed retry, network, and central acceptance semantics belong to Operation Synchronization.

---

The Local Persistence domain defines **the durability boundary that makes offline POS operation trustworthy**:

> **Once ShelfSense reports a business operation as completed, the local database has already committed the completed fact and the durable work necessary to synchronize it later.**
