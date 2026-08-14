# POS Domain Specification: Operation Synchronization

**Design status:** Core upload, idempotency, acknowledgment, retry, and acceptance-boundary model decided
**Implementation status:** Required in Phase 4
**Initial delivery:** Phase 4 — POS Runtime and Contract Foundation
**Expanded delivery:** Phase 6 — broader POS operation coverage
**Related specifications:** Local Persistence, Workstation Identity, Transactions, Reference Replication, Reconciliation, Inventory Integration
**Related contracts:** Completed Sale Operation, Sync Outcomes, Protocol Versioning
**Related workflows:** Completed Operation Synchronization, Idempotent Retry, Reconciliation

---

## 1. Purpose

This specification defines how locally completed POS operations are delivered from a workstation installation to the ShelfSense organization server.

It establishes:

* synchronization of workstation-originated operations;
* installation authentication;
* stable operation identity;
* idempotent retry;
* payload identity/integrity;
* server acknowledgment;
* duplicate detection;
* acceptance versus reconciliation;
* ordering expectations;
* preservation of offline-originated facts;
* local synchronization state.

This specification does **not** define:

* transaction completion;
* local SQLite durability;
* reference-data replication;
* business conflict resolution;
* inventory correction workflows;
* exact HTTP endpoints;
* transport serialization.

Those belong to their owning specifications and contracts.

---

## 2. Governing principle

ShelfSense transactions complete locally before synchronization.

> **Synchronization transfers an already completed originating fact to the organization server; it does not make that fact completed.**

Conceptually:

```text
local durable completion
        ↓
outbox
        ↓
operation synchronization
        ↓
central acceptance / reconciliation
```

Loss of connectivity therefore delays consolidation, not local business completion.

---

## 3. Synchronization direction

Operation Synchronization concerns workstation-originated business facts flowing toward the server.

Examples include:

* completed sales;
* returns;
* Z reports;
* Cash operations;
* approvals;
* other terminal-originated operations.

Reference data flowing from the server to the workstation belongs to `reference-replication.md`.

---

## 4. Operation identity

Every synchronizable originating operation has a stable globally unique operation identity.

Conceptually:

```text
operation_id = UUIDv7
```

The same business operation must use the same `operation_id` on every retry.

A retry must never create a new operation identity merely because the previous network request failed.

---

## 5. Operation identity versus transaction identity

Operation identity and business-record identity are separate.

For a completed sale, the payload may contain:

```text
operation_id
transaction_id
```

where:

* `transaction_id` identifies the POS transaction;
* `operation_id` identifies the synchronization/business operation submitted to the server.

The exact one-to-one or one-to-many relationship for future operation types belongs to their contracts.

---

## 6. Origin identity

A synchronized operation preserves the identity of its origin.

At minimum, where applicable:

```text
store_id
workstation_id
installation_id
actor_id
operation_id
```

plus the relevant business-record identity.

These identities describe what actually originated the operation and are not reassigned by the server.

---

## 7. Installation authentication

Synchronization requests authenticate the POS installation separately from the human actor inside the operation.

The authenticated installation must agree with the payload's:

```text
installation_id
workstation_id
store_id
```

relationship.

An authenticated Installation A must not submit an operation claiming to originate from Installation B.

Identity disagreement is an integrity failure rather than a normal business reconciliation condition.

---

## 8. Completed facts only

The normal synchronization path publishes committed originating operations.

The workstation must not synchronize speculative states such as:

* partially completed transactions;
* uncommitted tenders;
* temporary receipt allocation;
* in-memory work.

The local transactional outbox guarantees that a published operation corresponds to a durable local completion.

---

## 9. Outbox-driven synchronization

Synchronization reads from the durable local outbox.

Conceptually:

```text
completed operation
      ↓
outbox pending
      ↓
send
      ↓
receive durable outcome
      ↓
record acknowledgment/outcome locally
```

The synchronization worker does not discover completed operations only by scanning transient application memory.

---

## 10. Retry is normal behavior

Network communication is inherently uncertain.

Examples include:

```text
request sent
server commits
response lost
```

or:

```text
connection interrupted
before client receives response
```

The workstation must therefore retry safely using the original operation identity.

Retries are part of the normal protocol, not exceptional repair behavior.

---

## 11. Idempotency

The server must process repeated delivery of the same operation idempotently.

For the same logical operation:

```text
first submission
→ one central effect

retry
→ same result
→ no second business effect
```

This applies to effects such as:

* central transaction persistence;
* inventory posting;
* Cash operation persistence;
* reporting facts.

---

## 12. Duplicate operation

A repeated submission with the same:

```text
operation_id
```

and the same accepted payload is a transport duplicate.

The server should return the previously established outcome rather than execute the business effect again.

This is fundamentally different from two distinct operation IDs representing competing business events.

---

## 13. Payload identity

ShelfSense should bind an operation ID to the material payload originally submitted under that identity.

Conceptually:

```text
operation_id
+
payload hash / canonical identity
```

allows the server to distinguish:

```text
same operation retried
```

from:

```text
same operation_id reused for different content
```

The exact canonicalization/hash contract remains an implementation contract.

---

## 14. Operation ID reuse with different content

If the same `operation_id` is later submitted with materially different content, the server must not treat it as an ordinary retry.

That is an integrity/protocol failure.

The server should preserve evidence of the mismatch and reject or otherwise isolate it according to the Sync Outcomes contract.

---

## 15. Server acknowledgment

A successful synchronization response means the server has durably established an outcome for the operation.

The client may then persist that outcome locally.

The response may represent outcomes such as:

```text
accepted
duplicate
rejected
quarantined
```

with additional warnings or reconciliation conditions.

Exact names belong to the Sync Outcomes contract.

---

## 16. Local acknowledgment state

The workstation may track synchronization state such as:

```text
pending
acknowledged
requires_attention
```

or equivalent.

This state is transport/central-processing metadata.

It does not alter whether the originating transaction is locally completed.

---

## 17. Local completion does not wait for acknowledgment

Incorrect:

```text
complete sale
→ wait for Rails
→ mark completed
```

Correct:

```text
commit locally
→ mark completed
→ synchronize later
```

This distinction is required for offline operation.

---

## 18. Central acknowledgment does not rewrite origin facts

When the server accepts an operation, it preserves the originating facts supplied by the workstation, including applicable:

* occurrence time;
* business date;
* workstation;
* installation;
* receipt identity;
* completed prices;
* completed tax;
* completed tenders.

Synchronization time is not substituted for business occurrence time.

---

## 19. Server acceptance

An accepted operation is one the server can durably incorporate into central business history according to the operation contract.

Acceptance may cause central secondary effects such as:

* persistence of the completed sale;
* inventory ledger posting;
* reporting availability.

The operation contract defines those effects.

---

## 20. Acceptance does not imply perfect freshness

An operation may have been created using stale but legitimately cached reference data.

For example:

* old regular price;
* prior tax configuration;
* prior authorization reference.

Whether such an operation is:

```text
accepted
accepted with warning
quarantined
```

depends on the relevant business/reconciliation policy.

Operation Synchronization transports and records the outcome; it does not define those business policies.

---

## 21. Reconciliation is orthogonal to synchronization

A completed operation may synchronize successfully while still producing a reconciliation condition.

For example:

```text
operation accepted
+
late reporting activity
```

or:

```text
operation accepted
+
stale permitted reference
```

or:

```text
operation preserved
+
duplicate inventory-unit conflict
```

Therefore:

> **Synchronization outcome and reconciliation state are separate dimensions.**

---

## 22. Transport duplicate versus business conflict

These must not be confused.

### Transport duplicate

```text
same operation_id
same payload
sent again
```

Result:

```text
same central effect
```

### Business conflict

```text
operation A
operation B
different operation IDs
both claim incompatible business effects
```

Example:

```text
same individually tracked unit
sold offline by two distinct operations
```

That is not an idempotency duplicate.

It belongs to Reconciliation.

---

## 23. Structural invalidity

Some payloads cannot be treated as valid originating operations.

Examples may include:

* malformed required data;
* unsupported schema version;
* identity mismatch;
* invalid payload hash;
* impossible contract arithmetic;
* missing required operation identity.

Such conditions may be rejected at the synchronization boundary.

They are distinct from valid but conflicting business facts.

---

## 24. Quarantine

Some operations may be understandable and historically important but unsafe to apply fully without reconciliation.

Conceptually:

```text
originating fact preserved
+
some central effect held/restricted
+
reconciliation required
```

This may be appropriate for cases such as conflicting individually tracked inventory activity.

The exact meaning and behavior of quarantine belongs to Reconciliation and the Sync Outcomes contract.

---

## 25. Warnings

A synchronization outcome may also contain non-blocking conditions.

Examples might include:

* stale permitted reference;
* late activity against an already reviewed reporting period.

Warnings do not imply that the underlying operation was duplicated or structurally invalid.

---

## 26. Operation ordering

The protocol must not assume network delivery order equals business occurrence order.

For example:

```text
Operation A occurred 10:00
Operation B occurred 10:05

B synchronizes first
A synchronizes later
```

Both preserve their original occurrence facts.

The server must not rewrite `occurred_at` or `business_date` to match arrival order.

---

## 27. Per-operation correctness over global ordering

The initial synchronization model should favor individually idempotent operations rather than requiring one fragile global workstation upload transaction.

This allows:

```text
operation A accepted
operation B temporarily fails
operation C later retried
```

without losing local facts.

Where a domain requires explicit ordering or causal dependency, its operation contract must state that requirement.

---

## 28. Related-operation dependencies

Some future operations may depend on another fact already being known centrally.

For example:

```text
correction
→ references original operation
```

or:

```text
return
→ references original sale
```

The synchronization protocol may need to:

* process dependencies;
* retry later;
* preserve a pending condition.

Those rules belong to the specific operation contract.

A general arbitrary ordering engine is not required unless concrete workflows demand one.

---

## 29. Completed-sale central effect

For the Phase 4 representative sale, successful central acceptance should establish exactly one central representation of the completed transaction and exactly one corresponding inventory effect.

Conceptually:

```text
POS Sale Operation O
        ↓
Central Sale T
        ↓
Inventory Ledger Effect
```

Retrying O must not produce another T or another inventory effect.

This is the primary Phase 4 synchronization proof.

---

## 30. Inventory posting

The server remains authoritative for the consolidated inventory ledger.

For an accepted sale, central inventory posting should use the immutable completed operation facts rather than attempting to reconstruct the sale from current product/reference state.

Inventory Integration owns the exact mapping.

---

## 31. Negative consolidated inventory

An offline quantity-tracked sale may cause central inventory to become negative after synchronization.

That condition does not inherently mean the sale should be rewritten or discarded.

The accepted physical/economic sale remains historical.

Inventory/Reconciliation policy determines the resulting warning or correction process.

---

## 32. Individually tracked conflicts

Two distinct locally completed operations may claim the same exact inventory unit.

Both are historical originating facts.

Synchronization must not misclassify one as a transport retry merely because they conflict.

Reconciliation determines the allowed central inventory consequence.

---

## 33. Receipt identity

Completed sales synchronize with their already assigned receipt identities.

Rails must not allocate a new receipt number during ingest.

If the same operation retries, the same receipt identity is preserved.

If two distinct operations claim the same receipt identity, that is a business/identity conflict rather than a normal duplicate retry.

---

## 34. Business date and reporting context

The server preserves the transaction's originating:

```text
occurred_at
business_date
Z context
```

where applicable.

An operation synchronized days later remains associated with the date/context in which it actually completed.

---

## 35. Offline authority changes

An installation or user may become centrally inactive while still offline.

The server may therefore later receive operations created under stale authorization state.

Synchronization preserves:

* originating installation;
* actor;
* occurrence time;
* claimed authorization/approval context.

Whether the operation is accepted, warned, or quarantined belongs to authorization/reconciliation policy.

---

## 36. Reference versions

Where relevant, an operation should identify the reference context used to calculate or authorize the completed action.

Examples may include:

```text
price reference/version
tax configuration/version
approval-policy version
tender configuration/version
```

The exact requirements belong to each domain contract.

This allows the server to validate what the POS actually used rather than assuming current master data applied.

---

## 37. Arithmetic validation

The server may validate deterministic calculations contained in an operation.

For example:

```text
line totals
discount allocations
tax components
tender settlement
transaction total
```

against the versioned calculation contracts.

Validation checks internal consistency.

It should not casually recalculate the historical transaction using current references and replace the originating result.

---

## 38. Protocol version

Every synchronized operation must identify a supported protocol/schema version.

The server must know how to interpret the payload before applying business effects.

Unsupported versions must not be silently interpreted as another version.

Detailed compatibility rules belong to Protocol Versioning.

---

## 39. Forward compatibility

The server and client should reject or explicitly handle semantic incompatibility rather than silently ignoring fields whose absence could alter business meaning.

The goal is deterministic interpretation of completed operations.

---

## 40. Batch transport

The transport may eventually send multiple operations in one network request for efficiency.

That does not require those operations to share one business transaction.

Conceptually:

```text
Batch
├── Operation A
├── Operation B
└── Operation C
```

Each operation retains:

* its own identity;
* its own idempotency;
* its own outcome.

A failure for B need not imply that A was never accepted unless the exact batch contract explicitly says so.

---

## 41. Synchronization frequency

Synchronization should generally occur promptly while connectivity is available.

However, correctness must not depend on a specific short interval.

The system must remain correct if an operation remains pending for:

* minutes;
* hours;
* days.

Operational alerts for long-pending synchronization may be added later.

---

## 42. Client retry behavior

The client should continue retrying a pending operation until it obtains a durable terminal outcome or requires explicit operator/support action.

Retry scheduling, backoff, and connectivity detection are implementation concerns.

The domain requirement is preservation of the original operation identity and payload semantics across retries.

---

## 43. Acknowledgment persistence

Once the client receives a durable outcome, it should persist that outcome before treating synchronization work as finished.

A crash after receipt but before local persistence may simply cause another safe retry.

Idempotency makes that acceptable.

---

## 44. Never discard because "probably sent"

The workstation must not delete an outbox item based merely on:

```text
socket write succeeded
```

or:

```text
request left client
```

It needs a durable server outcome.

Otherwise a lost response could cause permanent uncertainty over whether the central effect exists.

---

## 45. Server outcomes should be stable

Once the server has durably established the outcome for an `operation_id`, later identical retries should return an equivalent result.

For example:

```text
first request
→ accepted

retry
→ accepted / duplicate-of-accepted
```

not:

```text
first request
→ accepted

retry
→ unrelated rejection
```

because current reference state changed in the meantime.

---

## 46. Local history is preserved after acknowledgment

Acknowledgment may allow the outbox transport entry to become inactive/archived.

It does not require deleting the underlying completed local transaction.

Local retention belongs to Local Persistence.

---

## 47. No central mutation of originating completed facts

When the server disagrees with a completed offline fact, the default architectural response is not:

```text
rewrite terminal transaction
```

Instead:

```text
preserve originating history
+
reconcile/correct with additional facts
```

This is consistent with ShelfSense's immutable-completion model.

---

## 48. Conceptual synchronization record

Without locking physical schema:

```text
Operation
├── operation_id
├── operation_type
├── schema_version
│
├── store_id
├── workstation_id
├── installation_id
├── actor context
│
├── business payload
├── payload identity/hash
│
└── synchronization outcome
```

The business payload structure is defined by each operation contract.

---

## 49. Domain ownership

### Operation Synchronization owns

* operation upload;
* stable operation identity;
* retry semantics;
* idempotent delivery;
* payload-identity binding;
* acknowledgment;
* synchronization outcome transport;
* protocol-version boundary.

### Local Persistence owns

* transactional outbox;
* durable pending operations;
* local acknowledgment persistence.

### Workstation Identity owns

* installation authentication identity;
* workstation/install binding.

### Transactions owns

* transaction completion and immutable facts.

### Reference Replication owns

* server-to-POS reference distribution.

### Reconciliation owns

* valid but conflicting/stale business conditions;
* quarantine resolution.

### Inventory Integration owns

* inventory effects of accepted operations.

---

## 50. Phase 4 delivery

Phase 4 should implement:

* authenticated installation submission;
* completed-sale operation contract;
* durable local outbox;
* stable operation UUID;
* payload identity/hash;
* protocol/schema version;
* server-side operation persistence;
* idempotent retry;
* durable acknowledgment;
* exactly-once central sale effect;
* exactly-once inventory ledger effect;
* basic sync outcomes.

The required end-to-end proof is:

```text
complete representative sale locally
↓
submit to Rails
↓
server accepts
↓
lose/retry acknowledgment
↓
submit same operation again
↓
one central sale
one central inventory effect
```

---

## 51. Phase 5 usage

Phase 5 uses the same synchronization architecture for real operational Cash sales.

The cashier does not wait for synchronization before:

* receiving the completed receipt;
* completing the transaction;
* continuing ordinary offline operation.

Synchronization occurs independently after local commit.

---

## 52. Phase 6 expansion

As POS functionality expands, Operation Synchronization should support additional operation contracts for:

* unit-tracked sales;
* additional tenders;
* returns;
* exchanges;
* discounts/overrides;
* Cash movements;
* Z reports;
* approvals;
* later POS operations.

These should reuse the same operation identity, idempotency, and acknowledgment model.

---

## 53. Pending decisions

### 53.1 Exact synchronization outcomes

Define the precise outcome vocabulary in `sync-outcomes.md`.

Likely distinctions include:

* accepted;
* duplicate;
* structurally rejected;
* quarantined;

plus zero or more warnings/reconciliation conditions.

### 53.2 Payload canonicalization/hash

Define exactly which fields contribute to the material payload identity and how canonicalization works.

### 53.3 Batch transport

Determine whether Phase 4 uses single-operation requests or supports batches immediately.

The domain model does not depend on batching.

### 53.4 Operation dependencies

Define dependency semantics only for operation types that concretely require them.

### 53.5 Historical recovery from inactive installations

Define whether and how previously committed operations from a replaced installation can be uploaded later.

### 53.6 Retention of server ingest records

Define central retention of:

* operation ID;
* payload hash;
* outcome;
* reconciliation references.

Enough must remain to guarantee durable idempotency.

---

## 54. Core invariants

1. **POS operations complete locally before synchronization.**
2. **Synchronization transports completed facts; it does not complete them.**
3. **Every synchronizable operation has a stable globally unique operation ID.**
4. **Retries reuse the same operation identity.**
5. **The same operation delivered repeatedly produces at most one central business effect.**
6. **Operation ID reuse with materially different payload content is an integrity failure.**
7. **The authenticated installation must agree with the operation's installation/workstation/store identity.**
8. **Only durable locally committed operations enter the normal synchronization path.**
9. **The client retains an operation until it receives and persists a durable server outcome.**
10. **Central acknowledgment is not required for local transaction completion.**
11. **Synchronization preserves originating timestamps, business date, receipt identity, actors, and other immutable completed facts.**
12. **Network arrival order does not redefine business occurrence order.**
13. **Transport duplicates and competing business operations are different conditions.**
14. **Reconciliation state is orthogonal to synchronization state.**
15. **Valid stale-reference use may result in warning/reconciliation rather than historical mutation.**
16. **Structural invalidity is distinct from business conflict.**
17. **The server does not silently renumber or rewrite completed originating facts to resolve conflicts.**
18. **Protocol/schema compatibility must be established before business effects are applied.**
19. **Server outcomes for an operation ID must remain stable across identical retries.**
20. **Accepted operations produce their central secondary effects idempotently.**

---

## 55. Acceptance examples

### Example A — normal synchronization

Given Sale Operation O completed locally,

when O is submitted to Rails,

then Rails:

* authenticates the installation;
* validates the payload;
* records O;
* creates one central sale representation;
* creates the required inventory effect;
* returns a durable outcome.

The POS records the acknowledgment.

---

### Example B — lost acknowledgment

Given Rails accepts Operation O but the network response is lost,

when the POS retries O,

then Rails recognizes the same operation identity and payload.

No second sale or inventory effect is created.

---

### Example C — retry after client restart

Given O remains pending locally,

when the POS application restarts,

then the durable outbox permits O to be submitted again using the same operation identity.

---

### Example D — same ID, different payload

Given Operation O was previously submitted with:

```text
total = $20
```

when another request uses the same operation ID but claims:

```text
total = $25
```

then ShelfSense treats this as an operation-integrity failure.

It is not accepted as an ordinary retry.

---

### Example E — two distinct offline sales

Given:

```text
Operation A
Operation B
```

have different operation IDs but both claim sale of the same individually tracked unit,

then they are two distinct originating business facts.

They must not be deduplicated as retry traffic.

The inventory conflict belongs to Reconciliation.

---

### Example F — stale price

Given the workstation completed an otherwise permitted sale using a cached `$20` price while the server had since changed the current price to `$22`,

then synchronization preserves the completed `$20` sale.

Any stale-reference warning is attached separately.

Rails does not rewrite the sale to `$22`.

---

### Example G — late synchronization

Given a transaction completed August 13 but synchronized August 15,

then the central record preserves:

```text
occurred_at = original occurrence
business_date = August 13
receipt identity = original receipt
```

The synchronization timestamp remains separate.

---

### Example H — identity mismatch

Given the request authenticates as Installation I1 bound to Workstation W1,

when the payload claims Installation I2,

then Rails rejects the operation as an identity-integrity failure.

---

### Example I — central inventory becomes negative

Given a valid quantity-tracked sale completed offline,

when later synchronization causes consolidated on-hand inventory to become negative,

then the sale is not silently changed or moved to another date.

Inventory/Reconciliation handles the resulting condition.

---

### Example J — batch retry

If a future request contains Operations A, B, and C and the response is lost,

then retrying the batch must remain safe because each operation retains its own stable operation identity and idempotent outcome.

---

## 56. Related contracts

Operation Synchronization should be implemented through exact contracts for:

### Completed Sale Operation

Defines the immutable sale payload including:

```text
operation identity
transaction identity
store/workstation/installation
actor
occurred_at
business_date
receipt identity
lines
pricing
discounts
tax
tenders
reference/version context
```

### Sync Outcomes

Defines exact server outcomes, warnings, quarantine, and acknowledgment semantics.

### Protocol Versioning

Defines operation schema compatibility between POS and Rails.

### Idempotency / Payload Identity

Defines stable operation identity, canonical payload comparison, and durable server replay behavior.

The Operation Synchronization domain defines **how a completed offline POS fact reliably becomes part of central ShelfSense history without making network availability part of transaction completion.**
