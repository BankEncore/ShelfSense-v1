# POS Domain Specification: Transactions

**Design status:** Decided for core transaction lifecycle and completion semantics **Implementation status:** Planned incrementally across Phases 4–6 **Initial foundation:** Phase 4 — POS Runtime and Contract Foundation **First operational delivery:** Phase 5 — First Operational Cash Sale **Expanded delivery:** Phase 6 — Core POS Operations **Related ADRs:** ADR-003, ADR-005, ADR-006, ADR-009, ADR-010, ADR-014, ADR-018 **Related specifications:** Transaction Lines, Pricing, Discounts, Tax, Tenders, Receipts, Reporting Periods, Cash Handling, Local Persistence, Operation Synchronization, Inventory Integration **Related workflows:** Cash Sale, Complete Transaction, Cancel Transaction, Suspend/Recall Transaction, Linked Return, Exchange

---

## 1\. Purpose

This specification defines the ShelfSense POS transaction domain.

It establishes:

* what a POS transaction represents;  
* who owns it while it is being worked;  
* its lifecycle states;  
* which states are mutable;  
* the boundary at which it becomes an immutable business fact;  
* how cancellation and suspension differ from completion;  
* what completion must validate and freeze;  
* how completed transactions relate to receipt identity, business date, Z-periods, tenders, inventory, synchronization, and reporting;  
* how completed transactions are corrected without rewriting history.

This specification intentionally does **not** define detailed:

* transaction-line structure;  
* price-resolution algorithms;  
* discount-allocation algorithms;  
* tax arithmetic;  
* tender-category behavior;  
* receipt layout;  
* inventory-ledger posting;  
* synchronization wire schemas.

Those rules belong to their owning specifications and contracts.

The core lifecycle is already established as `open → suspended/cancelled/completed`, with completion acting as the hard immutability boundary and post-completion corrections represented by new facts rather than edits.

---

# 2\. Domain principle

The governing transaction rule is:

> **Before completion, a POS transaction is a mutable work object. At completion, it becomes an immutable financial and operational fact.**

This distinction is fundamental to ShelfSense.

An open or suspended transaction describes what a cashier is **attempting to do**.

A completed transaction describes what **actually occurred**.

Therefore:

```
OPEN / SUSPENDED
    mutable working state
            ↓
       COMPLETE
            ↓
COMPLETED
    immutable business fact
```

A completed transaction is never reopened for editing.

If a completed transaction needs correction, ShelfSense records a new return, reversal, tender correction, inventory correction, accounting correction, or other explicitly modeled compensating fact.

---

# 3\. Domain authority

## 3.1 Open and suspended work

Open and suspended transaction state is owned by the originating POS workstation.

The central server does not become the authoritative editor of a disconnected workstation's open transaction.

Initially:

> **Open and suspended work remains authoritative on its originating workstation.**

Cross-workstation recall or handoff is deferred until ShelfSense has an explicit ownership/claim protocol. This matches the existing POS design, which deliberately keeps suspended work with its origin until cross-register ownership is designed.

## 3.2 Completed work

Once completed, the workstation-originated transaction becomes an immutable originating fact.

Before acknowledgment by the server, the workstation holds the authoritative local copy of that completed operation.

After synchronization, the server preserves the originating transaction and becomes the consolidated authority for organization-wide effects and reporting.

Synchronization does not authorize the server to rewrite what the workstation completed.

---

# 4\. Transaction identity

Every durable POS transaction has a technical identity using the ShelfSense UUID policy.

A completed transaction also receives a permanent customer-facing receipt identity according to the Receipt specification.

These identities serve different purposes:

| Identity | Purpose |
| :---- | :---- |
| Transaction UUID | Distributed technical identity |
| Receipt identity | Human/store operational identity |
| Outbound operation UUID/idempotency identity | Synchronization identity |

Receipt identity is not the primary database identity of the transaction.

A receipt number is assigned as part of successful completion and remains permanently associated with that completed transaction.

The exact point during mutable working state at which the transaction UUID itself is allocated is an implementation/schema concern, provided the identity is stable once persisted and completion never replaces it with a different transaction identity.

---

# 5\. Lifecycle states

The primary transaction lifecycle states are:

```
open
suspended
cancelled
completed
```

These states describe the lifecycle of the transaction as a whole.

They are distinct from:

* line active/void state;  
* tender state;  
* drawer-session state;  
* Z-period state;  
* synchronization state;  
* reconciliation state.

For example:

```
transaction.status = completed
sync.status        = pending
```

is valid.

A transaction can be financially complete even though it has not yet reached the organization server.

---

# 6\. State transitions

The core state machine is:

```
                 ┌─────────────┐
                 │    OPEN     │
                 └──────┬──────┘
                        │
          ┌─────────────┼──────────────┐
          │             │              │
          ▼             ▼              ▼
   ┌────────────┐ ┌─────────────┐ ┌─────────────┐
   │ SUSPENDED  │ │  CANCELLED  │ │  COMPLETED  │
   └─────┬──────┘ └─────────────┘ └─────────────┘
         │             terminal        terminal
         │ recall
         ▼
   ┌─────────────┐
   │    OPEN     │
   └─────────────┘
```

Allowed transitions:

| From | To | Meaning |
| :---- | :---- | :---- |
| Open | Suspended | Park incomplete work |
| Suspended | Open | Recall parked work |
| Open | Cancelled | Abandon meaningful incomplete work |
| Suspended | Cancelled | Abandon suspended work where workflow permits |
| Open | Completed | Successfully complete transaction |

Completed and cancelled are terminal.

Neither transitions back to open.

---

# 7\. Open transactions

An open transaction is mutable working state.

Depending on capabilities implemented at that point in the roadmap, an open transaction may allow:

* merchandise lines to be added;  
* line quantities to change;  
* lines to be voided;  
* open rings to be added;  
* price overrides to be added, changed, or removed;  
* discounts to be added, changed, or removed;  
* customer association;  
* return lines;  
* provisional tender interaction;  
* approvals associated with specific requested actions.

These capabilities are not all required in the first POS implementation.

## 7.1 Open transactions are not financial facts

An open transaction:

* is not revenue;  
* does not create finalized tax liability;  
* is not included in completed Z-period totals;  
* does not contain completed tender settlement;  
* has no completed inventory movement;  
* has no permanent completed-sale receipt.

Operational reservations may exist while work is open, but those reservations are not completed inventory movement.

## 7.2 Mutable calculations

Amounts displayed while open are provisional calculations.

ShelfSense may recalculate an open transaction as:

* merchandise changes;  
* quantities change;  
* prices change;  
* adjustments change;  
* reference data is deliberately refreshed;  
* tax inputs change;  
* customer context changes.

Only completed snapshots become historical facts.

---

# 8\. Suspended transactions

A suspended transaction is an incomplete transaction deliberately parked for later continuation.

Suspension does **not** convert the transaction into a sale.

A suspended transaction:

* remains incomplete;  
* is not revenue;  
* is not finalized tax liability;  
* has no completed tender settlement;  
* has no completed inventory movement;  
* is not completed Z-period activity;  
* has no completed receipt identity.

The current design explicitly treats suspension as parked mutable work rather than a financial event.

## 8.1 Recall

When recalled, the transaction returns to `open`.

The original working state is restored subject to the applicable refresh/revalidation policy.

## 8.2 Reference-data changes while suspended

Suspension does not permanently freeze current reference-based pricing or tax simply because the transaction crossed time while parked.

On recall, ShelfSense may need to:

* compare current reference state;  
* refresh eligible reference-derived values;  
* warn about material changes;  
* preserve or revalidate manual overrides;  
* preserve or revalidate approvals.

### Pending decision

The exact suspended-transaction recalculation policy remains unresolved, including:

* which prices refresh;  
* which tax configuration refreshes;  
* which automatic discounts refresh;  
* when warnings are required;  
* when existing approvals become invalid.

This decision is required before full suspend/recall implementation.

## 8.3 Cross-workstation recall

Cross-workstation recall is not initially supported.

It requires an explicit distributed ownership/claim protocol and remains deferred.

---

# 9\. Cancelled transactions

Cancellation means that meaningful transaction work was abandoned **before completion**.

A cancelled transaction is terminal.

A cancelled transaction has:

* no revenue;  
* no final tax liability;  
* no completed tender;  
* no permanent completed-sale receipt;  
* no completed inventory movement.

Once cancelled, it is not reopened.

## 9.1 Ephemeral versus retained work

ShelfSense does not need to persist every empty screen as a cancelled business object.

Completely empty or trivial work may be discarded as ephemeral application state.

Once meaningful activity has occurred, cancellation should retain the transaction for audit and operational reporting.

Meaningful activity may include such things as:

* adding merchandise;  
* adding an open ring;  
* applying an override;  
* applying an adjustment;  
* performing significant tender activity.

The exact threshold separating ephemeral work from retained cancelled work remains a pending policy decision. The consolidated design explicitly leaves this threshold unresolved.

---

# 10\. Completed transactions

A completed transaction is an immutable financial and operational fact.

Completion permanently freezes the transaction state required to describe what occurred.

At minimum, depending on the capabilities exercised by the transaction, completion freezes:

* active transaction lines;  
* quantities;  
* merchandise identity;  
* inventory-unit identity where applicable;  
* customer-facing descriptions;  
* merchandise/classification snapshots;  
* reference prices;  
* selling prices;  
* price overrides;  
* discounts;  
* transaction-discount allocations;  
* tax components;  
* tender facts;  
* cashier;  
* approvers;  
* relevant reasons;  
* occurrence timestamp;  
* business date;  
* Z-period;  
* drawer association relevant to cash tenders;  
* receipt identity;  
* applicable local inventory consequences;  
* applicable stored-value consequences;  
* reference/configuration versions needed to explain the completed result.

The existing POS design explicitly identifies completion as the point where line, price, tax, discount, tender, actor, reporting, receipt, and inventory facts become permanently frozen.

---

# 11\. Snapshot principle

Completed transactions must remain reproducible even after master data changes.

The governing rule is:

> **References describe which master record ShelfSense used. Snapshots describe what actually happened.**

For example:

```
product_variant_id
    → identifies the referenced variant

description_snapshot
department_snapshot
tax_snapshot
selling_price_snapshot
    → preserve transaction history
```

A historical transaction must not change because somebody later edits:

* product description;  
* department;  
* price;  
* tax configuration;  
* tender name;  
* user display name;  
* merchandise classification.

Current foreign-key targets and historical financial facts serve different purposes.

---

# 12\. Transaction economic character

ShelfSense must support transactions containing:

* sale-direction lines;  
* return-direction lines;  
* eventually both in the same transaction.

A mixed sale/return transaction represents an exchange.

Therefore, the economic outcome of the transaction is determined by its completed line/tax/adjustment totals rather than requiring all transactions to be exclusively categorized as either “sale” or “return.”

Conceptually:

```
net amount > 0
    customer owes ShelfSense

net amount < 0
    ShelfSense owes customer

net amount = 0
    no tender settlement required
```

Detailed line-direction and return behavior belongs to the Transaction Lines and Returns specifications.

---

# 13\. Completion command

Completion must be implemented as **one business command**.

It must not be a sequence of independent UI saves such as:

```
save transaction
save tenders
save receipt
save inventory
hope everything succeeded
```

Instead:

```
CompleteTransaction
```

owns the local completion boundary.

The source architecture explicitly requires one atomic completion command rather than loosely related saves.

---

# 14\. Completion validation

Before completion may commit, ShelfSense validates all conditions required by the transaction's actual contents and capabilities.

The validation set includes, as applicable:

### Transaction

* at least one active financially meaningful line;  
* transaction is currently `open`;  
* transaction has not already completed or cancelled;  
* calculations reconcile.

### Lines

* all active lines are internally valid;  
* quantities satisfy their line type/tracking rules;  
* required merchandise identities exist;  
* individually tracked merchandise identifies exact units;  
* required open-ring classification exists.

### Pricing and adjustments

* required prices exist;  
* price calculations reconcile;  
* required override reasons exist;  
* required approvals remain valid;  
* discounts/allocations reconcile.

### Tax

* tax calculation succeeded;  
* required tax classifications/configuration exist;  
* component totals reconcile.

### Tender

* transaction settlement is valid;  
* required tender references exist;  
* tender category rules are satisfied;  
* the transaction is fully settled.

### Actor/authorization

* cashier identity exists;  
* required permissions are satisfied according to locally applicable authority;  
* required second-actor approvals exist and remain valid.

### Operational context

* `occurred_at` can be established;  
* `business_date` can be determined;  
* required Z-period exists;  
* cash transactions have required drawer-session context.

### Persistence

* local database is writable;  
* the operation can be durably persisted;  
* receipt-sequence state can be safely advanced.

A validation failure leaves the transaction incomplete.

---

# 15\. Atomic local completion

On the POS workstation, the locally authoritative completion facts must be committed atomically.

Conceptually:

```
Validate transaction
        ↓
BEGIN SQLITE TRANSACTION
        ↓
establish occurred_at
derive business_date
associate active Z-period
associate required drawer context
freeze transaction facts
freeze line snapshots
freeze calculations
freeze tax
freeze tenders
freeze actors/approvals
allocate receipt identity
record applicable local operational consequences
record completion activity
create durable outbound operation
mark transaction completed
        ↓
COMMIT
```

Only after successful commit is the transaction `completed`.

The exact table layout is not owned by this specification.

---

# 16\. Completion and the transactional outbox

A locally completed transaction must never exist without the durable operation needed to synchronize it to the server.

Therefore:

> **Transaction completion and creation of the required outbound operation occur within the same local database transaction.**

This guarantees:

```
completed local transaction
        ⇒
durable sync operation exists
```

A crash after completion cannot leave ShelfSense with a valid local sale that it has forgotten how to send centrally.

---

# 17\. Commit precedes external side effects

Local database commit defines transaction completion.

Peripheral and network operations occur afterward.

Correct ordering:

```
COMMIT
   ↓
transaction is completed
   ↓
cash drawer command
receipt print submission
background synchronization
```

Incorrect ordering:

```
print receipt
open drawer
send server request
then attempt local completion
```

Receipt-printer, drawer, or network failure therefore cannot roll back a transaction that has already successfully committed.

---

# 18\. Crash semantics

## 18.1 Crash before commit

If the local completion transaction has not committed:

> **The POS transaction is not completed.**

There must be no independently valid:

* completed tender;  
* completed sale;  
* completed inventory effect;  
* completed outbound operation.

Persisted working state may be recovered according to the local-persistence implementation.

## 18.2 Crash after commit

If commit succeeded:

> **The POS transaction is completed.**

This remains true even if the process crashes:

* before the UI refreshes;  
* before the drawer opens;  
* before the receipt prints;  
* before synchronization starts.

On restart, ShelfSense determines truth from durable local state.

It must not reopen the transaction or allocate a second receipt.

---

# 19\. Occurrence time

A completed transaction records the time at which the originating workstation completed the business operation.

This is distinct from:

* transaction-open time;  
* first scan time;  
* synchronization time;  
* server-received time.

Synchronization must not replace the originating occurrence timestamp with server receipt time.

Where useful, ShelfSense may retain additional operational timestamps, but they do not redefine the occurrence of the completed transaction.

---

# 20\. Business date

Every completed transaction has an explicit `business_date`.

The business date is determined **at completion** according to the store's applicable local business-date policy.

Opening a transaction does not freeze the business date.

A transaction opened before a reporting boundary and completed afterward belongs to the business date applicable when it completes.

A transaction synchronized days later remains on its original business date.

The current architecture explicitly defines `business_date` as a reporting classification assigned at completion rather than a centrally controlled distributed lock.

Detailed rollover rules belong to the Reporting Periods specification.

---

# 21\. Z-period association

A completed transaction belongs to the workstation Z-period in which it completes.

It does not belong to:

* the Z-period in which it was opened;  
* the Z-period in which it was first scanned;  
* the Z-period in which it later synchronizes.

An open transaction can therefore span time without becoming reporting activity.

A suspended transaction is likewise not Z activity until recalled and completed.

Detailed Z lifecycle rules belong to the Reporting Periods specification.

---

# 22\. Drawer association

The transaction itself and the drawer session are distinct concepts.

Cash tender activity must be attributable to the drawer session responsible for that physical cash custody.

Other tender categories do not automatically imply drawer impact.

Detailed drawer/cash behavior belongs to Cash Handling and Tenders.

---

# 23\. Receipt association

Only successful completion creates the permanent customer receipt identity.

The receipt:

* represents the completed transaction;  
* uses historical completed facts;  
* is not recalculated against current reference data;  
* may be reprinted without altering the transaction.

Receipt printing is not itself completion.

A completed transaction can exist even when the printer fails.

Detailed sequence/reprint/presentation rules belong to Receipts.

---

# 24\. Inventory relationship

An open transaction has no completed inventory movement.

An open/suspended transaction may eventually have operational reservation behavior, but reservation is not an on-hand ledger movement.

Upon completion, the transaction carries the facts required for its inventory consequence.

The workstation may use the completed operation as an input to its local effective inventory projection.

The server applies authoritative consolidated inventory posting on accepted synchronization.

The POS transaction does not own a competing authoritative central inventory ledger.

Detailed behavior belongs to Inventory Integration.

---

# 25\. Tender relationship

Tendering describes how the transaction's net financial obligation is settled.

Tender facts are children/associated completed facts of the transaction.

A transaction cannot complete until its settlement requirements are satisfied.

Once completed:

* tender facts are immutable;  
* incorrect tender recording is corrected by a later explicit correction/reversal workflow;  
* the completed transaction is not reopened to edit the original tender.

Detailed tender-category behavior belongs to Tenders.

---

# 26\. Returns and exchanges

A return is not an edit of the original transaction.

A linked return references the original completed line and creates a new completed transaction/fact that reverses the applicable historical effects.

An exchange is represented by a transaction that contains both return-direction and sale-direction activity.

Return completion follows the same fundamental immutability rule:

> Return lines, financial reversal, refund tender, inventory reversal, and required approvals become completed facts together.

The consolidated design explicitly treats a post-void as distinct from an ordinary return: a post-void reverses a transaction because the original completion itself should not have occurred.

Detailed return policy belongs to Returns.

---

# 27\. Post-completion corrections

Completed transactions are never edited in place.

Possible correction mechanisms include:

* linked return;  
* unlinked return where policy permits;  
* full transaction reversal/post-void;  
* tender correction;  
* inventory reconciliation;  
* cash correction;  
* reporting amendment;  
* accounting adjustment.

The exact correction type must reflect the business fact being corrected.

For example:

```
wrong tender recorded
    → tender correction

physical item returned
    → return

sale itself should never have existed
    → post-void / transaction reversal

inventory mismatch discovered later
    → inventory workflow
```

A generic “edit completed transaction” operation must not exist.

---

# 28\. Activity and audit history

ShelfSense should preserve meaningful transaction activity without making the transaction domain event-sourced.

The transaction and its child records remain the authoritative current/completed state.

The activity log explains how the cashier arrived there.

Meaningful activity may include:

* transaction opened/became meaningful;  
* line added;  
* line voided;  
* quantity changed;  
* price override applied/changed/removed;  
* discount applied/changed/removed;  
* approval granted;  
* open ring added;  
* suspended;  
* recalled;  
* cancelled;  
* completion attempted where operationally meaningful;  
* completed.

The existing design explicitly rejects recording every keystroke or UI focus event.

Activity metadata should remain bounded to information useful for:

* audit;  
* operational investigation;  
* loss prevention;  
* before/after explanation.

---

# 29\. Actor identity

Transactions distinguish the cashier/operator from other actors.

At minimum, completed transactions preserve the originating cashier identity.

Where an operation requires approval:

```
performed_by
    ≠
approved_by
```

A supervisor approving one action does not become the transaction's cashier and does not grant the cashier general elevated authority.

Detailed approval behavior belongs to Approvals.

---

# 30\. Offline behavior

Transactions are designed for offline operation.

When the organization server is unavailable, the workstation may continue to operate using valid locally available:

* installation authority;  
* cashier authority;  
* reference data;  
* pricing/tax inputs;  
* inventory projection;  
* supported tender capabilities.

If an operation is permitted offline, failure to contact the server does not block local completion.

After completion:

```
completed transaction
        ↓
durable outbound operation
        ↓
retry until acknowledged/reconciled
```

Later discovery that centralized state differed does not automatically invalidate the originating transaction.

Conflict handling belongs to Synchronization/Reconciliation.

---

# 31\. Synchronization state is orthogonal to transaction state

A transaction does not transition from `completed` to some different business state merely because it synchronizes.

Instead, synchronization is tracked separately.

For example:

```
Transaction:
  status = completed

Operation synchronization:
  status = pending
```

then:

```
Transaction:
  status = completed

Operation synchronization:
  status = acknowledged
```

or:

```
Transaction:
  status = completed

Operation synchronization:
  status = quarantined
```

The transaction remains completed in all three cases.

This separation is critical to preserving terminal-originated facts.

---

# 32\. Server reconciliation

The server may classify a synchronized completed transaction according to issues such as:

* stale price;  
* stale tax;  
* negative consolidated inventory;  
* duplicate individually tracked unit sale;  
* revoked cashier;  
* disabled tender;  
* receipt-sequence conflict;  
* reporting-period conflict.

These may result in:

* acceptance;  
* acceptance with warning;  
* quarantine;  
* structural rejection where the payload itself is invalid.

A reconciliation result does not silently mutate transaction history.

Detailed conflict taxonomy belongs to Reconciliation.

---

# 33\. Reporting semantics

Only completed transactions are financial reporting facts.

Open and suspended transactions are excluded from sales/tax/tender totals.

Cancelled transactions may appear in operational metrics but are not revenue.

Operational reporting may separately measure:

* cancellation count;  
* cancelled cart value;  
* voided line value;  
* overrides;  
* approvals;  
* open rings;  
* other exception activity.

These metrics must not be confused with financial sales.

---

# 34\. Conceptual transaction aggregate

This specification does not lock table names, but conceptually the transaction aggregate contains or relates to:

```
POS Transaction
│
├── identity
├── lifecycle state
├── store/workstation/installation context
├── cashier
├── occurred_at
├── business_date
├── Z-period
│
├── transaction lines
│   ├── merchandise
│   └── open ring
│
├── adjustments
│   ├── price override references
│   ├── line discounts
│   └── transaction discounts/allocations
│
├── tax components
│
├── tenders
│
├── approvals
│
├── receipt identity
│
├── activity history
│
└── synchronization operation
```

Cash drawer, inventory ledger, stored-value ledger, and accounting records remain separate domain records even when transaction completion causes or references them.

---

# 35\. Domain boundaries

## Transaction owns

* transaction identity;  
* lifecycle;  
* mutation/completion boundary;  
* overall transaction state;  
* relationship to lines;  
* occurrence context;  
* completed snapshot envelope;  
* completion orchestration/invariants;  
* correction immutability principle.

## Transaction Lines owns

* line types;  
* line direction;  
* quantities;  
* line active/void lifecycle;  
* merchandise/unit identity;  
* line consolidation;  
* line-specific snapshots.

## Pricing owns

* reference price;  
* selling price;  
* price resolution;  
* price override semantics.

## Discounts owns

* line discounts;  
* transaction discounts;  
* allocation.

## Tax owns

* tax rules;  
* taxable basis;  
* tax components;  
* rounding.

## Tenders owns

* settlement;  
* payment/refund directions;  
* category-specific behavior.

## Receipts owns

* receipt sequencing;  
* representation;  
* reprinting.

## Reporting Periods owns

* business-date policy;  
* Z-period lifecycle;  
* store finalization.

## Cash Handling owns

* drawer sessions;  
* cash expected/count/variance;  
* non-sale cash movement.

## Inventory Integration owns

* local inventory projection effects;  
* central ledger posting;  
* exact-unit behavior.

## Operation Synchronization owns

* operation envelopes;  
* outbox delivery;  
* idempotency;  
* acknowledgment.

This ownership map is intended to prevent duplication across specifications.

---

# 36\. Delivery by phase

This domain model is permanent; implementation is incremental.

## Phase 4 — Foundation

Implement enough transaction behavior to prove:

* transaction identity;  
* basic completed-sale representation;  
* calculation contract integration;  
* business-date assignment;  
* atomic local completion;  
* immutable completed payload;  
* receipt identity contract;  
* durable outbox;  
* crash-before/after-commit semantics;  
* idempotent server intake.

Phase 4 does not provide a production cashier register.

## Phase 5 — First operational transaction

Implement:

* production cashier sign-in;  
* open transaction;  
* quantity-tracked Standard merchandise;  
* quantity changes;  
* basic line void;  
* regular price;  
* tax;  
* Cash tender;  
* minimum Z/drawer context;  
* permanent receipt;  
* real offline completion;  
* receipt printing;  
* synchronization.

## Phase 6 — Full transaction breadth

Extend with:

* individually tracked units;  
* open rings;  
* price overrides;  
* approvals;  
* suspended transactions;  
* richer cancellation/activity behavior;  
* discounts;  
* multiple tender categories;  
* mixed tenders;  
* returns;  
* exchanges;  
* full cash/reporting interaction.

The lifecycle and immutability rules do not change when these capabilities are added.

---

# 37\. Deferred capabilities

The transaction model must leave room for, but this specification does not currently fully define:

* cross-workstation suspended transaction handoff;  
* full post-void workflow;  
* tender correction workflow;  
* customer-specific transaction behavior;  
* promotion requalification/clawback;  
* additional transaction types that may arise from future domains.

These capabilities must preserve the core immutable-completion model unless a future ADR explicitly supersedes it.

---

# 38\. Pending decisions

The following transaction-specific decisions remain unresolved.

## 38.1 Meaningful cancellation threshold

Define when an abandoned transaction becomes sufficiently meaningful that a retained `cancelled` record is required instead of discarding ephemeral UI state.

## 38.2 Suspended transaction refresh

Define exactly which:

* prices;  
* taxes;  
* promotions;  
* reference-dependent values

refresh upon recall.

Define how manual overrides and approvals are preserved or revalidated.

## 38.3 Cross-workstation handoff

Define ownership, claim, concurrency, and stale-work handling before suspended transactions can move between workstations.

## 38.4 Post-void

Define the exact authorization and reversal workflow when an entire completed transaction should be treated as having been completed in error.

## 38.5 Completed tender correction

Define how ShelfSense corrects an incorrectly recorded tender without editing the completed transaction.

These decisions are not required for the Phase 4 foundational transaction model.

---

# 39\. Core invariants summary

The following are non-negotiable unless explicitly superseded by a later architectural decision:

1. **Open transactions are mutable working state.**  
2. **Suspended transactions remain incomplete working state.**  
3. **Cancelled transactions are terminal and have no completed financial/inventory effects.**  
4. **Completed transactions are immutable.**  
5. **Completed and cancelled transactions never reopen.**  
6. **Completion is one atomic local business command.**  
7. **Completion and its required outbox operation commit together.**  
8. **A failed commit does not produce a completed transaction.**  
9. **A successful commit remains completed despite printer, drawer, network, or UI failure afterward.**  
10. **Receipt identity belongs only to a successfully completed transaction.**  
11. **Business date and Z-period are determined by completion, not transaction opening.**  
12. **Synchronization status is separate from transaction lifecycle state.**  
13. **Current master-data changes never rewrite historical completed snapshots.**  
14. **Corrections create new facts instead of editing completed transactions.**  
15. **The originating workstation owns open/suspended work and unacknowledged completed facts according to the offline authority model.**  
16. **Server reconciliation may flag or quarantine a completed originating fact but does not silently rewrite it.**

---

# 40\. Acceptance examples

## Example A — ordinary successful sale

Given an open valid transaction with fully settled tender,

when `CompleteTransaction` succeeds,

then:

* transaction becomes `completed`;  
* completed snapshots are frozen;  
* receipt identity is assigned;  
* business date and Z-period are fixed;  
* tender becomes immutable;  
* required local effects are recorded;  
* outbound operation exists;  
* all completion facts commit atomically.

---

## Example B — validation failure

Given an open transaction whose tender does not fully settle the transaction,

when completion is requested,

then:

* completion is rejected;  
* transaction remains open;  
* no completed receipt exists;  
* no completed tender exists;  
* no completed inventory consequence is posted.

---

## Example C — crash before commit

Given completion is in progress,

when the POS process terminates before SQLite commit,

then:

* the transaction is not completed;  
* no independent completed-sale outbox operation exists.

---

## Example D — crash after commit

Given SQLite completion commit succeeded,

when the POS terminates before printing or synchronization,

then after restart:

* transaction remains completed;  
* original receipt identity remains assigned;  
* outbound operation remains available;  
* transaction is not reopened.

---

## Example E — cancellation

Given meaningful incomplete transaction activity,

when the cashier cancels before completion,

then:

* transaction becomes cancelled;  
* it does not contribute revenue, tax, completed tender, or inventory movement;  
* it cannot later be reopened.

---

## Example F — suspension

Given an open transaction,

when the cashier suspends it,

then:

* transaction becomes suspended;  
* it is not reported as a sale;  
* no completed inventory movement exists;  
* it may later be recalled to open on its originating workstation.

---

## Example G — correction after completion

Given a completed transaction whose merchandise is later returned,

when staff process the return,

then:

* the original transaction remains unchanged;  
* the return is recorded as a new completed fact linked to the original where applicable.

---

## Example H — late synchronization

Given a transaction completed offline on business date August 12,

when it synchronizes on August 14,

then:

* its occurrence data remains the original occurrence data;  
* its business date remains August 12;  
* the server does not rewrite it as an August 14 sale.

---

# 41\. Related workflow specifications

This domain specification should eventually be referenced by:

* `workflows/sales/cash-sale.md`  
* `workflows/sales/start-sale.md`  
* `workflows/sales/cancel-transaction.md`  
* `workflows/sales/complete-transaction.md`  
* `workflows/sales/suspend-recall.md`  
* `workflows/sales/individual-unit-sale.md`  
* `workflows/sales/open-ring.md`  
* `workflows/returns/linked-return.md`  
* `workflows/returns/exchange.md`  
* `workflows/returns/post-void.md`  
* `workflows/sync/completed-operation.md`  
* `workflows/sync/idempotent-retry.md`

---

# 42\. Related contract specifications

The transaction domain depends on versioned contracts for:

* completed-sale operation payload;  
* calculation arithmetic;  
* tax calculation;  
* receipt identity;  
* reference-data versions;  
* synchronization/idempotency;  
* protocol/schema compatibility.
