# POS Domain Specification: Reconciliation

**Design status:** Core reconciliation-condition, preservation, and resolution model decided
**Implementation status:** Minimal support required in Phase 4; expanded operational reconciliation in Phase 6
**Initial delivery:** Phase 4 — POS Runtime and Contract Foundation
**Expanded delivery:** Phase 6 — Core POS Operations
**Related specifications:** Operation Synchronization, Local Persistence, Workstation Identity, Inventory Integration, Returns, Reporting Periods, Receipts, Approvals
**Related workflows:** Completed Operation Synchronization, Reconciliation Review, Inventory Conflict Resolution, Late Activity Review
**Related contracts:** Sync Outcomes, Completed Sale Operation

---

## 1. Purpose

This specification defines how ShelfSense identifies, records, and resolves discrepancies discovered when workstation-originated POS facts are consolidated with central state.

It establishes:

* what constitutes a reconciliation condition;
* the distinction between synchronization failure and business reconciliation;
* preservation of completed originating facts;
* multiple reconciliation conditions on one operation;
* condition severity and lifecycle;
* automatic versus human-required resolution;
* quarantine relationships;
* ownership of corrective business actions;
* reconciliation audit/history.

This specification does **not** define:

* synchronization transport retry;
* operation idempotency;
* cash drawer expected-versus-counted reconciliation;
* the corrective rules of Inventory, Returns, Cash Handling, or other domains;
* administrative audit logging generally.

Those belong to their owning specifications.

---

## 2. Governing principle

A locally completed POS operation may be historically valid even when it conflicts with what the organization server currently knows.

> **Reconciliation preserves the originating fact, records the discrepancy, and links any resulting correction or resolution without rewriting what originally occurred.**

Conceptually:

```text
Completed originating fact
        ↓
Central consolidation
        ↓
Discrepancy detected
        ↓
Reconciliation condition
        ↓
Automatic resolution
or
Owning-domain corrective action
```

The original completed fact remains immutable.

---

## 3. Why reconciliation exists

Offline-capable workstations do not share one continuously available transactional database.

Two facts that were individually valid from their originating workstation's perspective may conflict when later combined centrally.

Examples include:

* two offline sales of the same individually tracked inventory unit;
* two returns attempting to consume the same remaining returnable quantity;
* an operation performed under stale authorization;
* use of stale reference configuration;
* activity arriving after management reviewed a prior reporting period;
* conflicting workstation-scoped receipt identities.

These conditions cannot all be prevented through local validation.

ShelfSense therefore requires explicit reconciliation semantics.

---

## 4. Reconciliation is not synchronization

Operation Synchronization answers:

> Did this originating operation reach the server, and what processing outcome did the server establish?

Reconciliation answers:

> Does this otherwise understood operation create a discrepancy that needs to be recorded or resolved?

These are separate concerns.

A synchronized operation may be:

```text
accepted
+
no reconciliation conditions
```

or:

```text
accepted
+
one or more reconciliation conditions
```

or:

```text
quarantined
+
one or more reconciliation conditions
```

---

## 5. Transport duplicates are not reconciliation conditions

A retry such as:

```text
same operation_id
same payload
```

is handled through synchronization idempotency.

It does not create a business reconciliation issue merely because the request arrived twice.

By contrast:

```text
Operation A
Operation B
different operation IDs
incompatible business effects
```

represents two distinct originating facts and may require reconciliation.

---

## 6. Structural invalidity is not ordinary reconciliation

A payload that cannot be interpreted as a valid operation because of matters such as:

* unsupported schema;
* installation identity mismatch;
* invalid payload identity/hash;
* missing required operation identity;
* impossible contract structure;

belongs primarily to the synchronization/protocol boundary.

Reconciliation is intended for **understood business facts whose consolidation produces a meaningful discrepancy**.

---

## 7. Reconciliation condition

A **reconciliation condition** is a durable record that ShelfSense identified a discrepancy requiring:

* historical visibility;
* automatic handling;
* acknowledgment;
* or corrective business action.

Conceptually:

```text
Reconciliation Condition
├── type
├── subject
├── related operation(s)
├── detected_at
├── severity
├── state
├── supporting context
└── resolution
```

The exact physical schema is deferred.

---

## 8. Conditions are separate from transaction status

A completed transaction remains:

```text
status = completed
```

even if reconciliation is required.

Incorrect:

```text
transaction.status = conflict
```

Correct:

```text
Transaction
status = completed

Reconciliation Condition
state = open
```

Transaction lifecycle and reconciliation lifecycle are independent.

---

## 9. Multiple conditions may apply

One originating operation may produce more than one reconciliation condition.

Example:

```text
Offline Sale O
├── stale price reference
├── stale actor authorization
└── late reporting activity
```

The model therefore must not represent reconciliation as one enum directly on the operation.

---

## 10. Reconciliation subject

A condition should identify the business subject affected.

Depending on the condition, that may include:

* operation;
* transaction;
* inventory unit;
* product variant/store inventory;
* receipt identity;
* returnable sale line;
* reporting snapshot;
* installation;
* actor authorization context.

A condition may reference more than one originating operation when the conflict is inherently between them.

Example:

```text
duplicate inventory-unit activity
├── Sale Operation A
└── Sale Operation B
```

---

## 11. Condition type

Reconciliation conditions should use stable application-defined types.

Examples may include:

```text
stale_reference
stale_authority
duplicate_inventory_unit
excess_return_quantity
receipt_identity_conflict
late_reporting_activity
inventory_below_zero
```

Exact names and initial catalogs should be introduced only as concrete domains require them.

ShelfSense should not build a generic expression/rules language for arbitrary reconciliation types.

---

## 12. Severity and lifecycle are separate

A condition's importance and its resolution state answer different questions.

Conceptually:

### Severity

```text
informational
warning
requires_action
```

### Lifecycle

```text
open
resolved
```

Exact enum names remain an implementation decision.

A condition can therefore be:

```text
severity = warning
state = resolved
```

or:

```text
severity = requires_action
state = open
```

without overloading one status field.

---

## 13. Informational conditions

An informational condition records something worth preserving but normally requiring no corrective business action.

Example:

```text
late operation incorporated into
a previously reviewed reporting snapshot
```

if Reporting Periods automatically handles the amendment.

Such conditions are still useful for:

* support;
* audit;
* management visibility.

---

## 14. Warning conditions

A warning indicates an important discrepancy that may be accepted historically without preventing the underlying central effect.

Possible examples include policy-permitted use of stale:

* pricing;
* reference configuration;
* authority.

The owning domain determines when such use is permissible.

Reconciliation records the resulting condition.

---

## 15. Conditions requiring action

Some discrepancies cannot be resolved safely without a business decision or corrective workflow.

Examples may include:

* two sales of one individually tracked unit;
* conflicting return claims;
* receipt-identity collision;
* unresolved externally processed tender activity.

These remain open until an appropriate resolution is recorded.

---

## 16. Reconciliation does not define whether an operation is accepted

Whether an operation is:

```text
accepted
quarantined
rejected
```

belongs to the synchronization outcome and owning business-domain policy.

Reconciliation records discrepancies associated with that outcome.

For example:

```text
accepted
+
stale_reference warning
```

may be valid.

Likewise:

```text
quarantined
+
duplicate_inventory_unit
```

may be valid.

---

## 17. Quarantine

Quarantine should be reserved for an understood originating operation that must be preserved but whose normal central effects cannot all be safely applied without resolution.

Conceptually:

```text
originating fact preserved
        +
business discrepancy identified
        +
one or more effects withheld/restricted
```

Quarantine does **not** mean:

> Pretend the originating operation never happened.

The exact effect held by quarantine is defined by the owning domain.

---

## 18. Reconciliation never silently rewrites completed history

ShelfSense must not resolve a reconciliation issue by silently changing historical originating facts such as:

* receipt number;
* selling price;
* tax;
* inventory unit;
* actor;
* occurrence time;
* business date;
* return quantity.

Instead:

```text
original fact
+
reconciliation condition
+
resolution/correction
```

remains visible.

---

## 19. Corrective action belongs to the owning domain

Reconciliation must not become a generic "fix anything" subsystem.

For example:

```text
Inventory conflict
    → Inventory correction

Return conflict
    → Returns correction

Cash discrepancy
    → Cash Handling

Late reporting activity
    → Reporting amendment

Tender problem
    → Tender correction/reversal
```

Reconciliation:

* identifies the discrepancy;
* tracks its state;
* links to the corrective result.

It does not invent replacement business semantics.

---

## 20. Resolution

A reconciliation condition may be resolved when its required handling is complete.

A resolution should preserve:

* condition;
* outcome;
* resolving actor or system process;
* resolved time;
* related corrective business fact(s);
* notes/reason where appropriate.

Conceptually:

```text
Condition C
duplicate inventory unit
        ↓
Inventory investigation/correction I
        ↓
Resolution R
```

The original condition remains historical.

---

## 21. Resolution does not delete the condition

Resolved conditions remain visible.

ShelfSense should be able to answer:

> What discrepancy occurred, and how was it handled?

not merely:

> Are there any current discrepancies?

Resolution history is part of the operational audit trail.

---

## 22. Automated resolution

Some conditions can be handled deterministically without human intervention.

Example:

```text
late reporting activity
        ↓
Reporting Periods adds amendment
        ↓
condition automatically resolved
```

The system-generated resolution should still preserve the relationship between:

* condition;
* resulting action/amendment;
* resolution time.

---

## 23. Human resolution

Conditions requiring judgment may need an authorized actor.

Examples:

* inventory investigation;
* approving a business exception;
* choosing a corrective operation.

Authorization for the corrective action belongs to the appropriate domain and Approval policy.

A user marking a reconciliation condition "resolved" must not be a substitute for required business correction.

---

## 24. Accepting a discrepancy as-is

Some conditions may legitimately be resolved without a compensating financial/inventory action.

For example, management may determine:

> The historical stale-reference use was legitimate and requires no correction.

The resolution should state that outcome rather than deleting the condition.

Exact resolution categories remain pending.

---

## 25. Correcting through new facts

Where correction is required, the owning domain should create a new business fact.

Example:

```text
Completed Fact A
        ↓
Reconciliation Condition
        ↓
Inventory Adjustment B
```

not:

```text
edit Completed Fact A
```

This matches ShelfSense's immutable-history model.

---

## 26. Reconciliation and stale references

Offline operation necessarily permits periods where local reference data is older than central data.

A stale reference is not automatically an error.

The relevant domain determines whether use was:

```text
permitted
permitted but noteworthy
not permitted / requires action
```

Reconciliation records the resulting discrepancy when appropriate.

It does not recalculate the historical operation using current reference state.

---

## 27. Reconciliation and stale authority

A cashier, manager, workstation, or installation may become centrally unauthorized while offline.

Later synchronization may therefore reveal that the operation used stale authority information.

The historical operation continues to preserve:

* actor;
* installation;
* occurrence time;
* approval context.

Authorization policy determines the consequence.

Reconciliation records the discrepancy and any required handling.

---

## 28. Quantity-tracked inventory

An offline sale may cause consolidated quantity-tracked inventory to fall below zero.

ShelfSense must not invent inventory that did not exist merely to make the projection nonnegative.

Depending on Inventory policy, the condition may be:

* accepted without a reconciliation issue;
* recorded as an inventory warning;
* surfaced for investigation.

The completed sale itself remains historical.

---

## 29. Individually tracked inventory

Conflicting activity involving a unique physical unit is materially different.

Example:

```text
Sale A → Unit U
Sale B → Unit U
```

where A and B are distinct originating operations.

ShelfSense must preserve both completed sale histories.

It must not:

* deduplicate them;
* substitute another unit;
* silently rewrite one sale.

The Inventory/Reconciliation workflow determines which central unit state and corrective action follow.

---

## 30. Returns

Two distinct return operations may attempt to consume the same remaining returnable quantity.

Example:

```text
Original sale quantity = 1

Return A = 1
Return B = 1
```

These are not synchronization duplicates if they have different operation identities.

Returns determines:

* remaining returnability;
* financial/inventory consequences;
* correction requirements.

Reconciliation preserves and tracks the conflict.

---

## 31. Receipt conflicts

Two distinct completed transactions may claim the same workstation receipt identity.

ShelfSense must not silently renumber either completed transaction centrally.

The condition should preserve:

```text
receipt identity
transaction A
transaction B
originating installations
```

Resolution may require operational investigation or later corrective presentation, but the customer-facing historical identity cannot simply be rewritten.

---

## 32. Reporting conditions

Late activity may arrive after management created a Store Close or other immutable reporting snapshot.

This generally should not quarantine an otherwise valid operation.

Instead:

```text
operation accepted
        ↓
original business date retained
        ↓
reporting amendment
        ↓
reconciliation condition recorded/resolved
```

Reporting Periods owns the amendment.

Reconciliation tracks the fact that late activity affected previously reviewed reporting.

---

## 33. Cash reconciliation is different

Cash Handling uses the word reconciliation for:

```text
expected Cash
versus
physical count
```

That is not this domain.

A `$2` drawer shortage is a Cash Handling fact.

It becomes a distributed Reconciliation condition only if some separate central/local inconsistency exists.

---

## 34. Condition detection

Conditions are generally created when central processing has enough information to identify a discrepancy.

Detection may occur:

* during operation ingest;
* when another conflicting operation arrives;
* during later central evaluation;
* when a referenced authority/configuration change is compared.

The precise detector belongs to the relevant domain/application service.

---

## 35. Detection must be idempotent

Retrying the same synchronization request must not create another copy of the same reconciliation condition.

Conceptually:

```text
Operation O
→ stale_reference condition C
```

retrying O should still result in:

```text
Condition C
```

not:

```text
C1
C2
C3
```

The exact stable-key/deduplication mechanism belongs to implementation.

---

## 36. New information may create new conditions

Idempotent detection does not mean a subject can have only one condition forever.

For example, later arrival of another operation may reveal a new conflict that could not have been known when the first operation arrived.

That new discrepancy should be recorded as a new condition.

---

## 37. Resolution history is immutable

Once a resolution has been recorded as a historical action, its facts should not be silently edited.

If later information proves that further correction is necessary, ShelfSense should create:

* another reconciliation condition;
* or another corrective fact;

rather than falsifying the previous resolution history.

---

## 38. Operational visibility

ShelfSense should eventually support views such as:

```text
Open reconciliation issues
by store
by workstation
by type
by severity
by age
```

and drill-down showing:

* originating operations;
* discrepancy;
* relevant historical snapshots;
* resolution options/history.

Detailed administrative UX belongs to later implementation.

---

## 39. Reporting

Reconciliation reporting should distinguish at least:

* currently open conditions;
* resolved historical conditions;
* automatic versus human resolution;
* condition type;
* severity;
* affected store/workstation;
* age/time-to-resolution.

It should not collapse operational discrepancies into ordinary sales totals.

---

## 40. Conceptual model

Without locking physical schema:

```text
Reconciliation Condition
│
├── id
├── condition_type
├── severity
├── state
├── detected_at
│
├── primary subject
├── related operations/facts
├── context
│
└── Resolution
    ├── outcome
    ├── resolved_by
    ├── resolved_at
    └── corrective fact references
```

One subject may have many reconciliation conditions.

---

## 41. Domain ownership

### Reconciliation owns

* reconciliation-condition identity;
* condition type;
* severity;
* lifecycle;
* discrepancy context;
* resolution history;
* linkage to corrective facts;
* operational visibility of unresolved discrepancies.

### Operation Synchronization owns

* operation transport;
* idempotency;
* protocol failures;
* server ingest outcome.

### Local Persistence owns

* original local completed history;
* persistence of synchronization outcomes locally.

### Inventory owns

* inventory conflict semantics and corrective inventory operations.

### Returns owns

* returnability and corrective return/refund semantics.

### Reporting Periods owns

* reporting amendments.

### Receipts owns

* receipt identity rules.

### Approvals owns

* authorization of corrective/exception actions.

### Cash Handling owns

* expected/count/variance reconciliation.

---

## 42. Phase 4 delivery

Phase 4 only needs enough reconciliation structure to prove the architecture.

Implement:

* ability for central ingest to associate zero or more reconciliation conditions with an operation;
* distinction between accepted, duplicate, invalid, and quarantined outcomes;
* durable preservation of originating facts;
* basic condition type/severity/state;
* idempotent condition creation;
* support for the Phase 4 inventory proof.

Phase 4 does **not** need a polished reconciliation workbench.

---

## 43. Phase 5 usage

Ordinary first Cash sales should normally synchronize without reconciliation.

The infrastructure must nevertheless preserve unexpected conditions without requiring the cashier transaction to be reopened.

Phase 5 should not add broad manager reconciliation workflows merely because the underlying model exists.

---

## 44. Phase 6 expansion

Phase 6 should add reconciliation handling as concrete POS conflicts become possible, including:

* individually tracked unit conflicts;
* return conflicts;
* receipt conflicts;
* stale-policy/authority conditions;
* late reporting activity;
* Cash/tender exception workflows where applicable.

Each owning domain defines its own corrective action.

---

## 45. Pending decisions

### 45.1 Initial condition catalog

Define condition types incrementally as each domain implements concrete conflict scenarios.

Avoid creating a speculative exhaustive taxonomy.

### 45.2 Severity vocabulary

Recommended conceptual distinction:

```text
informational
warning
requires_action
```

Exact names may be finalized during implementation.

### 45.3 Resolution outcomes

Determine whether structured outcomes such as:

```text
automatically_corrected
accepted_as_is
corrective_action_completed
```

are useful.

Do not encode business-domain correction semantics into a generic reconciliation enum.

### 45.4 Assignment/ownership

Determine whether open conditions need:

* assigned user;
* assigned role/team;
* due/escalation metadata.

This is operational UX rather than core reconciliation semantics.

### 45.5 Acknowledgment

Determine whether an informational/warning condition needs a separate `acknowledged` concept or whether resolution history is sufficient.

### 45.6 Reconciliation retention

Recommended: retain conditions and resolutions with the underlying operational history rather than deleting them after resolution.

---

## 46. Core invariants

1. **Reconciliation records discrepancies among understood business facts; it is not transport retry handling.**
2. **Transport duplicates are handled through synchronization idempotency, not reconciliation.**
3. **Structural protocol invalidity is distinct from business reconciliation.**
4. **A reconciliation condition is separate from transaction lifecycle.**
5. **A completed transaction remains completed while reconciliation is pending.**
6. **One operation may have multiple reconciliation conditions.**
7. **Conditions preserve stable type, subject, detection context, severity, and lifecycle.**
8. **Severity and resolution state are independent concepts.**
9. **Reconciliation does not silently rewrite originating completed facts.**
10. **Quarantine preserves the originating fact even when normal central effects cannot safely be applied.**
11. **Corrective business actions belong to the domain that owns the affected business state.**
12. **Reconciliation links to corrective facts rather than replacing them.**
13. **Resolved conditions remain historical.**
14. **Automatic resolution is permitted when the owning domain can handle the discrepancy deterministically.**
15. **Human resolution cannot substitute for required corrective business action.**
16. **Stale reference or authority does not automatically imply historical mutation or rejection.**
17. **Two distinct conflicting operation IDs are not deduplicated merely because only one effect could have been valid.**
18. **Receipt conflicts are not resolved by silent central renumbering.**
19. **Late reporting activity retains its original business date and is handled through reporting amendment where appropriate.**
20. **Reconciliation-condition detection must be idempotent for the same discrepancy.**
21. **Later newly discovered discrepancies may create additional conditions.**
22. **Resolution history is immutable; later problems require additional facts or conditions.**

---

## 47. Acceptance examples

### Example A — ordinary retry

Given Operation O was accepted centrally,

when O is submitted again with the same payload,

then synchronization recognizes the retry.

No reconciliation condition is created solely because the operation was delivered twice.

---

### Example B — stale permitted price

Given an offline transaction completes using a cached `$20` reference price while the central price had become `$22`,

if policy permits that stale offline price,

then the sale may be accepted as completed at `$20`.

ShelfSense may record a stale-reference warning.

It does not rewrite the sale to `$22`.

---

### Example C — duplicate inventory unit

Given:

```text
Sale A → Inventory Unit U
Sale B → Inventory Unit U
```

and A and B have different operation IDs,

then both completed originating sale histories are preserved.

ShelfSense creates an inventory reconciliation condition.

It does not treat B as a retry of A or substitute a different inventory unit.

---

### Example D — negative quantity inventory

Given an offline quantity-tracked sale causes central on-hand to become `-1`,

then the completed sale remains preserved.

Inventory policy determines whether this creates an informational/warning condition or simply an allowed negative balance.

ShelfSense does not fabricate stock to avoid the negative result.

---

### Example E — duplicate return claim

Given one unit/quantity remains returnable,

when two distinct offline return operations each claim that remaining quantity,

then both originating return operations remain historical facts.

The second operation is not a transport duplicate.

Returns/Reconciliation determines the resulting financial and inventory correction.

---

### Example F — receipt collision

Given two distinct transactions claim:

```text
Store S1
Workstation W1
Receipt 4814
```

then ShelfSense records a receipt-identity reconciliation condition.

Neither completed transaction is silently renumbered.

---

### Example G — late reporting activity

Given a Store Close was recorded for August 13,

when another valid August 13 workstation operation later synchronizes,

then:

* the operation remains August 13 activity;
* the original Store Close remains historical;
* Reporting Periods records the appropriate amendment;
* any late-activity reconciliation condition may then resolve automatically.

---

### Example H — stale cashier authority

Given a cashier completed an offline sale using locally valid cached authorization,

but the server later determines the user had been centrally deactivated before the sale occurred,

then the transaction continues to preserve:

```text
original actor
original occurred_at
original installation
```

Authorization/Reconciliation policy determines the appropriate outcome.

The actor is not replaced or erased.

---

### Example I — correction through owning domain

Given a reconciliation investigation determines inventory must be corrected,

then Inventory creates the appropriate inventory correction/adjustment.

The reconciliation condition links to that correction and becomes resolved.

The original POS operation remains unchanged.

---

### Example J — repeated detection

Given Operation O already produced Condition C,

when O is retried,

then ShelfSense does not create a second equivalent Condition C.

---

## 48. Related contracts

Reconciliation depends primarily on:

### Sync Outcomes

Defines how server ingest communicates:

```text
acceptance outcome
+
zero or more warnings/conditions
```

without conflating transport outcome with reconciliation lifecycle.

### Completed Operation contracts

Provide the historical facts and version context needed to detect discrepancies.

### Owning-domain correction contracts

Inventory, Returns, Reporting, Tender, and other domains define the actual business actions used to resolve their conditions.

---

The Reconciliation domain defines **how ShelfSense deals with the fact that an offline operation can be real, immutable history and still conflict with other real history discovered later**.

Its central rule is:

> **Preserve what happened, identify what disagrees, and correct through new facts rather than rewriting the past.**
