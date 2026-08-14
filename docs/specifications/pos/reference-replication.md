# POS Domain Specification: Reference Replication

**Design status:** Core snapshot, incremental update, cursor, tombstone, and local-reference authority model decided
**Implementation status:** Required in Phase 4
**Initial delivery:** Phase 4 — POS Runtime and Contract Foundation
**Expanded delivery:** Phase 6 — broader POS reference coverage
**Related specifications:** Workstation Identity, Local Persistence, Transactions, Pricing, Tax, Tenders, Approvals, Operation Synchronization
**Related workflows:** Initial Reference Snapshot, Incremental Reference Update, POS Startup
**Related contracts:** Reference Snapshot, Reference Delta, Protocol Versioning

---

## 1. Purpose

This specification defines how ShelfSense distributes centrally mastered reference data to POS installations for reliable local and offline use.

It establishes:

* central authority for POS reference data;
* local persisted reference projections;
* initial snapshots;
* incremental updates;
* ordered cursors;
* deletion/deactivation propagation;
* effective-dated reference data;
* atomic local application;
* stale-reference behavior;
* the boundary between replicated reference state and workstation-originated facts.

This specification does **not** define:

* transaction synchronization;
* central acceptance of POS operations;
* business conflict resolution;
* detailed HTTP endpoints;
* physical local database schema;
* exact serialization format.

Those belong to their owning specifications and contracts.

---

## 2. Governing principle

ShelfSense uses the organization server as the master for shared reference data while allowing POS workstations to operate against durable local copies.

> **Reference replication gives each POS installation a coherent local projection of the centrally mastered data it needs to operate offline.**

Conceptually:

```text
Organization Server
        ↓
Reference Snapshot / Deltas
        ↓
Local SQLite Reference Projection
        ↓
POS operation
```

The local projection is operationally usable while offline, but it does not become the master copy.

---

## 3. Reference authority

Shared configuration and master data are centrally authoritative.

Examples include:

* stores;
* workstations;
* merchandise;
* identifiers;
* prices;
* tax configuration;
* tender configuration;
* cashier identity/authorization references;
* approval-policy references.

The POS may use its local persisted copy while offline.

It does not redefine the central record merely because its copy is older.

---

## 4. Reference data versus originating facts

Reference replication applies only to centrally mastered data.

It must remain distinct from workstation-originated facts such as:

* completed transactions;
* receipt identities;
* Z reports;
* drawer reconciliations;
* Cash operations;
* approvals actually performed locally.

Conceptually:

```text
Server-master reference data
        ↓ replicate

Workstation-originated business facts
        ↑ synchronize
```

These are different data flows with different authority.

---

## 5. Local reference projection

Each POS installation maintains a durable local projection containing the subset of server-master data required for POS operation.

The projection exists so ordinary POS functions do not require a network lookup.

For example:

```text
scan identifier
    ↓
resolve local variant
    ↓
resolve local price
    ↓
resolve local tax
```

must be possible while disconnected where the workflow is supported offline.

---

## 6. Phase 4 reference scope

The initial reference projection should include enough data to prove one representative sale.

At minimum:

* store configuration;
* workstation configuration;
* sellable variants;
* product/variant identifiers;
* regular price;
* department/classification context needed by POS;
* tax classes;
* store tax components/rules;
* Cash tender configuration;
* actor/authorization data required by Phase 4 proofs.

Phase 5 may expand or operationalize the same projection for cashier use.

---

## 7. POS-specific projection

The POS does not need a byte-for-byte replica of the Rails database.

The server should publish a purpose-built POS reference projection.

For example, the POS may need:

```text
variant_id
identifier
description
tracking mode
regular price
tax class
active/sellable state
```

without needing every administrative field stored on the Rails models.

> **Replication should expose the stable POS contract, not mirror server implementation details.**

---

## 8. Stable identifiers

Replicated records retain the same durable identifiers used centrally.

For example:

```text
product_variant_id
department_id
tax_class_id
tender_type_id
```

The POS must not invent unrelated local identifiers for records that cross the synchronization boundary.

Local database surrogate keys may exist internally if useful, but distributed identity remains stable.

---

## 9. Initial snapshot

A new or deliberately rebuilt installation receives an initial reference snapshot.

The snapshot represents a coherent starting point for the POS projection.

Conceptually:

```text
Snapshot
├── protocol/schema version
├── store/workstation scope
├── reference records
└── cursor
```

After successfully applying the snapshot, the installation can continue from the snapshot's cursor using incremental updates.

---

## 10. Snapshot coherence

A snapshot must represent a logically coherent reference state.

The POS must not be handed combinations such as:

```text
new tax rule
+
old tax component set
```

if those states are not valid together.

The exact server-side mechanism used to construct a coherent snapshot is implementation-specific.

The contract must ensure that the resulting projection is internally usable.

---

## 11. Snapshot scope

Reference data should be scoped to what the enrolled installation needs.

At minimum this normally means its:

```text
organization
store
workstation
```

context.

ShelfSense should avoid distributing unrelated store-specific operational configuration merely because it exists centrally.

Some organization-wide data may naturally be shared.

---

## 12. Incremental updates

After the initial snapshot, the POS receives ordered reference changes.

Conceptually:

```text
cursor 100
    ↓
delta 101
    ↓
delta 102
    ↓
delta 103
```

Incremental replication reduces the need to repeatedly replace the entire local projection.

---

## 13. Cursor

The reference cursor identifies how far through the authoritative reference change stream the installation has durably applied.

It means:

> **All reference changes through this cursor have been successfully applied to the local projection.**

It does not mean merely:

> The POS downloaded them.

---

## 14. Cursor advances only after durable application

The local reference data and its cursor must be committed atomically.

Conceptually:

```text
BEGIN

apply reference changes
update local projection
advance cursor

COMMIT
```

If application fails:

```text
cursor remains unchanged
```

The POS may safely request/reapply the changes later.

Local Persistence owns the atomic durability guarantee.

---

## 15. Ordered application

Reference changes must be applied in the authoritative order defined by the replication contract.

The POS must not skip from:

```text
cursor 100
```

to:

```text
cursor 105
```

while silently ignoring required changes 101–104.

If the server determines that the requested cursor can no longer continue incrementally, it may require a new snapshot.

---

## 16. Idempotent application

Reapplying the same reference change must not create duplicate business reference records or compound its effect.

This allows safe retry after:

* network interruption;
* lost response;
* application restart.

Reference change identity/cursor semantics should make repeated application deterministic.

---

## 17. Create and update propagation

A reference change may create a new locally visible record or replace the replicated representation of an existing record.

Example:

```text
Variant V
regular price = $20
```

later becomes:

```text
Variant V
regular price = $22
```

After the relevant update is applied, new working activity uses the newly replicated state according to the owning domain rules.

Completed transactions remain historical and unchanged.

---

## 18. Deactivation and removal

Reference records cannot simply disappear from the change stream when the POS needs to know they are no longer usable.

ShelfSense therefore requires explicit removal/deactivation propagation.

Conceptually:

```text
tombstone
```

or an equivalent inactive representation.

This lets the POS distinguish:

```text
record was removed/deactivated
```

from:

```text
record has never been received
```

---

## 19. Historical references remain valid

If a completed local transaction referenced a variant, tax rule, tender type, or other reference record that is later deactivated, that historical operation remains valid history.

Reference removal affects future use.

It does not rewrite completed facts.

The local persistence model may therefore need to retain enough reference/snapshot context for historical transactions even when the current reference projection no longer considers the record active.

---

## 20. Effective-dated reference data

Some reference configuration changes over time rather than simply replacing an earlier value.

Examples include:

* tax rules;
* potentially future prices or policies.

Replication must preserve enough effective-period information for the POS to resolve the correct configuration locally.

Conceptually:

```text
Rule A
effective_from = T1
effective_until = T2

Rule B
effective_from = T2
```

The owning domain defines which timestamp determines applicability.

Reference Replication merely ensures those facts are available locally.

---

## 21. Replication does not determine business semantics

For example:

* Pricing determines how price is selected.
* Tax determines which tax rule is effective.
* Approvals determines authority policy.
* Tenders determines tender capabilities.

Reference Replication is responsible for delivering the required data.

It must not become a second rules engine.

---

## 22. Stale references are possible

Because POS workstations may operate offline:

> **A workstation may legitimately complete an operation using the most recent reference state it had successfully replicated, even if the server has newer reference data.**

This is an inherent property of offline operation.

The existence of newer central data does not automatically mean the local transaction did not occur.

---

## 23. Completed operations preserve the reference context they used

Where a domain requires historical reference context, completed operations must preserve the relevant:

* values;
* identifiers;
* versions;
* effective context.

For example, a completed sale may preserve:

```text
regular/reference price
tax rule/version
tender configuration/version
approval policy/version
```

as required by those domains.

This allows central validation and historical explanation without treating today's reference state as though it existed at transaction time.

---

## 24. Central updates do not rewrite completed local operations

Suppose:

```text
POS cached price = $20
```

A sale completes offline.

Meanwhile:

```text
server price = $22
```

When the POS reconnects, applying the `$22` reference update affects future working transactions.

It does not mutate the completed `$20` sale.

Any stale-reference assessment belongs to synchronization/reconciliation policy.

---

## 25. Working transaction refresh

Whether an already-open or suspended transaction should adopt newly replicated reference data is an owning-domain/workflow decision.

Reference Replication only updates the available local reference state.

For example, Pricing may later decide whether a recalled suspended transaction:

```text
keeps old working price
```

or:

```text
refreshes to current reference price
```

This specification does not decide that behavior.

---

## 26. Local overlay

ShelfSense may maintain local state that temporarily overlays centrally replicated reference data.

The canonical example is a locally originated fact that the server has not yet acknowledged.

Conceptually:

```text
server reference projection
+
local originating overlay
=
effective local operational view
```

Reference Replication must not destroy locally originated state when applying a snapshot or delta.

The exact overlay semantics belong to the owning domains.

---

## 27. Inventory is not replicated as ordinary reference truth

Inventory deserves special treatment.

The central server remains authoritative for consolidated inventory history, but the POS may also have locally completed unsynchronized inventory-affecting operations.

Therefore an effective local availability view may need:

```text
accepted server checkpoint
+
applicable unacknowledged local operations
```

rather than blindly replacing local state with the latest server quantity.

This behavior belongs primarily to Inventory Integration.

Reference Replication must preserve the distinction between a server checkpoint and local originating effects.

---

## 28. Reference snapshot replacement

A full snapshot may be used when:

* installation is first enrolled;
* incremental history is unavailable;
* local reference projection needs deliberate rebuild.

Applying a snapshot must not erase:

* completed local transactions;
* outbox operations;
* local receipt/Z state;
* Cash facts;
* other workstation-originated history.

A snapshot replaces/rebuilds the **reference projection**, not the entire POS database.

---

## 29. Snapshot plus local state

Conceptually:

```text
Local SQLite

Originating facts          ← preserve
Working operational state  ← preserve according to workflow rules
Reference projection       ← rebuild from snapshot
Outbox                     ← preserve
```

This boundary is critical.

A "reference refresh" must never behave like a factory reset.

---

## 30. Reference failure behavior

If a reference snapshot or delta cannot be applied coherently:

* the cursor must not advance;
* the previous coherent local reference state remains authoritative for local use, subject to policy;
* the failure is surfaced operationally.

The POS must not expose a half-applied reference version.

---

## 31. Unknown reference records

A POS operation should not invent reference identities when required data is absent.

For example, if a scanned identifier cannot resolve against the local projection:

```text
unknown item
```

is different from:

```text
known inactive item
```

The owning workflow decides whether the user may use another supported path, such as an open ring.

---

## 32. Reference versioning

The replication protocol itself must be versioned independently from individual business-record versions.

Conceptually:

```text
protocol version
payload/schema version
reference cursor
```

These serve different purposes.

Protocol Versioning should define compatibility behavior.

---

## 33. Backward/forward compatibility

The server must not send reference payloads the POS version cannot safely interpret.

Likewise, the POS must not silently ignore unknown fields or record types when doing so could change business meaning.

Compatibility rules belong to the exact contract.

The domain requirement is:

> **An installation may only advance its reference cursor after safely understanding and applying the change.**

---

## 34. Workstation configuration changes

Workstation administrative configuration is replicated reference data.

For example:

```text
workstation name
active state
store configuration
supported POS capabilities
```

The POS may cache these while offline.

When the server later changes them, the new values become available after replication according to their owning policies.

---

## 35. Workstation deactivation while offline

An offline installation may not immediately learn that its workstation or installation has been deactivated.

Reference Replication cannot prevent activity that occurred before that information arrived locally.

When the new state is received:

* future ordinary activity should follow the new configuration;
* previously completed originating facts remain historical;
* any stale-authority issue belongs to synchronization/reconciliation.

---

## 36. Authorization references

Offline authentication/authorization may require replicated data such as:

* user identity;
* store eligibility;
* permissions;
* policy versions;
* credential verification material appropriate for offline use.

Only the minimum data required for supported offline authorization should be replicated.

Sensitive credential design belongs to authentication/security work rather than this specification.

---

## 37. Reference minimization

The POS projection should avoid storing centrally available data that is unnecessary for POS operation.

Benefits include:

* smaller snapshots;
* simpler compatibility;
* reduced local exposure of sensitive information;
* faster replication.

The design principle is:

> **Replicate what the POS contract requires, not every central record because it exists.**

---

## 38. Domain ownership

### Reference Replication owns

* POS reference projection;
* initial snapshots;
* incremental deltas;
* cursors;
* ordered application;
* tombstones/deactivation propagation;
* reference rebuild semantics;
* replication-version boundaries.

### Local Persistence owns

* atomic application;
* durable cursor;
* local storage.

### Workstation Identity owns

* enrollment and installation binding.

### Pricing owns

* price resolution.

### Tax owns

* tax rule selection and effective-time semantics.

### Tenders owns

* tender capability semantics.

### Approvals owns

* authorization policy meaning.

### Inventory Integration owns

* effective local inventory calculations involving central checkpoints and local operations.

### Operation Synchronization owns

* upload of workstation-originated business operations.

### Reconciliation owns

* treatment of stale/conflicting reference use discovered centrally.

---

## 39. Phase 4 delivery

Phase 4 should implement:

* POS-specific reference projection;
* initial snapshot;
* durable local reference storage;
* ordered incremental changes or a minimal cursor-based update mechanism;
* stable cursor;
* atomic apply + cursor advance;
* create/update/deactivation propagation;
* reference protocol/schema version;
* enough reference data for representative sale calculation.

Phase 4 should prove that a workstation can:

```text
enroll
↓
receive snapshot
↓
calculate locally
↓
go offline
↓
continue using reference state
↓
reconnect
↓
apply later changes
```

---

## 40. Phase 5 usage

Phase 5 relies on replicated reference state for:

* cashier/store context;
* Standard product lookup;
* identifier resolution;
* regular configured price;
* tax calculation;
* Cash tender configuration.

The first operational Cash sale must not depend on live central reference lookups.

---

## 41. Phase 6 expansion

As POS capabilities expand, replication should add the reference data required for:

* individually tracked units where appropriate;
* additional tenders;
* discounts/promotions;
* returns;
* approval policies;
* Cash Handling policy;
* broader pricing rules.

Each new reference set should be added because a POS domain requires it, rather than by turning the POS into a replica of the entire server database.

---

## 42. Pending decisions

### 42.1 Cursor representation

Define the exact cursor format in the Reference Delta contract.

The POS should treat it as an opaque authoritative continuation token unless a stronger semantic requirement emerges.

### 42.2 Delta organization

Determine whether changes are transmitted as:

* one ordered global POS reference stream;
* scoped streams;
* another equivalent mechanism.

Prefer the simplest mechanism that preserves coherent ordering.

### 42.3 Snapshot pagination/chunking

Determine whether initial snapshots need chunking for large catalogs.

If chunked, the POS must not expose a partially installed snapshot as complete.

### 42.4 Tombstone representation

Define exact removal/deactivation representation.

The important semantic requirement is explicit propagation of reference records that are no longer usable.

### 42.5 Reference-history retention

Determine how much prior reference-version data must remain locally beyond values already snapshotted into completed transactions.

### 42.6 Offline authorization data

Define the minimum safe authentication/permission material required for Phase 5 offline cashier authentication.

### 42.7 Inventory checkpoint replication

Define exact representation jointly with `inventory-integration.md`.

---

## 43. Core invariants

1. **The organization server is authoritative for shared POS reference data.**
2. **The POS maintains a durable local reference projection for offline use.**
3. **Reference replication does not replace workstation-originated business facts.**
4. **The POS projection is purpose-built and need not mirror the central database schema.**
5. **Distributed reference records preserve stable central identifiers.**
6. **A new installation receives a coherent initial reference snapshot.**
7. **The snapshot establishes a continuation cursor for subsequent updates.**
8. **Incremental reference changes are applied in authoritative order.**
9. **The cursor advances only after the corresponding changes are durably applied.**
10. **Repeated application of the same reference change is safe.**
11. **Deletion/deactivation must be propagated explicitly where the POS must stop using a record.**
12. **Completed operations remain historically unchanged when reference data later changes.**
13. **Effective-dated reference data preserves sufficient timing information for local domain resolution.**
14. **A POS may legitimately operate on stale-but-valid replicated data while offline.**
15. **Completed operations preserve required reference snapshots/versions used at completion.**
16. **Reference snapshots/deltas must never erase local originating history or outbox state.**
17. **A failed reference update leaves the prior coherent projection and cursor intact.**
18. **Reference data and the cursor describing it are committed atomically.**
19. **The POS does not invent missing required reference identities.**
20. **Reference protocol compatibility must be established before the cursor advances.**
21. **Replication should include only data required by supported POS capabilities.**

---

## 44. Acceptance examples

### Example A — initial enrollment

Given a newly enrolled POS installation,

when it requests its initial reference state,

then the server provides a coherent snapshot containing the references required for that workstation's supported POS capabilities and an associated cursor.

After durable application, the installation can operate from that local state.

---

### Example B — offline product lookup

Given Variant V and identifier `221...` exist in the locally applied reference projection,

when the network is unavailable and the cashier scans the identifier,

then the POS may resolve V locally without contacting Rails.

---

### Example C — price update

Given the local POS currently has:

```text
Variant V
Regular price = $20
Cursor = 100
```

and the server publishes:

```text
Regular price = $22
```

then after the corresponding delta is durably applied:

```text
Regular price = $22
Cursor = 101
```

Future activity uses the updated reference according to Pricing rules.

Previously completed `$20` transactions remain unchanged.

---

### Example D — interrupted delta

Given the workstation is applying cursor 101,

when the application terminates before the SQLite transaction commits,

then after restart:

```text
reference state = cursor 100 state
cursor = 100
```

The POS may safely request/apply 101 again.

---

### Example E — deactivation

Given Tender Type T is currently available locally,

when T is centrally deactivated and the relevant reference change is applied,

then T is no longer available for new ordinary tender selection.

Historical transactions using T remain unchanged.

---

### Example F — stale offline price

Given:

```text
POS replicated price = $20
```

then the workstation goes offline.

The server later changes the price to `$22`.

If the offline POS completes an otherwise permitted sale using `$20`, the completed sale preserves the `$20` reference/selling context.

When connectivity returns:

* the `$22` reference update affects future activity;
* the completed `$20` sale is not rewritten;
* stale-reference treatment belongs to synchronization/reconciliation policy.

---

### Example G — full snapshot rebuild

Given the server requires a fresh reference snapshot,

when the POS installs that snapshot,

then it may replace the replicated reference projection.

It must preserve:

* completed local transactions;
* receipt state;
* Z/Cash state;
* unsynchronized operations;
* outbox entries.

---

### Example H — unknown identifier

Given a scanned identifier is absent from the local reference projection,

then ShelfSense treats it as unresolved.

It does not fabricate a merchandise reference.

A separate supported workflow may allow open-ring entry.

---

### Example I — effective-dated tax rules

Given two replicated tax rules have non-overlapping effective periods,

then the POS retains sufficient rule/effective-period data for the Tax domain to select the appropriate rule based on transaction occurrence time.

Reference Replication does not itself calculate the tax.

---

### Example J — cursor and state consistency

Given the POS reports:

```text
reference_cursor = 250
```

then all reference changes through 250 have been durably applied.

ShelfSense must never advance the cursor merely because the payload was downloaded.

---

## 45. Related contracts

Reference Replication should be implemented through exact contracts for:

### Reference Snapshot

Defines:

* installation/store scope;
* protocol/schema version;
* record collections;
* effective-dated data;
* tombstone/current-state behavior;
* resulting cursor.

### Reference Delta

Defines:

* starting cursor;
* ordered changes;
* change identity/type;
* resulting cursor;
* retry behavior.

### Protocol Versioning

Defines compatibility among:

* server reference protocol;
* POS version;
* snapshot/delta schema.

### Local Reference Application

Defines the atomic relationship:

```text
reference changes
+
local projection
+
cursor
```

The Reference Replication domain defines **how the central ShelfSense configuration becomes a coherent, durable, offline-usable POS reference projection without confusing replicated master data with locally originated business facts.**
