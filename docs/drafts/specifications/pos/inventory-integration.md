# POS Domain Specification: Inventory Integration

**Design status:** Core POS-to-Inventory authority, quantity/unit effects, local availability projection, and synchronization behavior decided
**Implementation status:** Quantity-tracked sale integration required in Phase 4/5; individually tracked and return integration expanded in Phase 6
**Initial delivery:** Phase 4 — POS Runtime and Contract Foundation
**Expanded delivery:** Phase 6 — Core POS Operations
**Related specifications:** Transactions, Transaction Lines, Returns, Local Persistence, Reference Replication, Operation Synchronization, Reconciliation
**Related domains:** Inventory Ledger, Inventory Balances, Inventory Units, Inventory Valuation
**Related workflows:** Complete Transaction, Individual Unit Sale, Linked Return, Completed Operation Synchronization

---

## 1. Purpose

This specification defines the boundary between POS operations and ShelfSense Inventory.

It establishes:

* which POS activity affects inventory;
* Inventory authority versus workstation-local availability;
* quantity-tracked merchandise effects;
* individually tracked inventory-unit effects;
* non-inventory merchandise behavior;
* local offline availability projection;
* central inventory posting;
* idempotent synchronization;
* negative quantity handling;
* individually tracked conflicts;
* return effects;
* relationship to inventory valuation.

This specification does **not** define:

* the Inventory ledger schema;
* inventory adjustment workflows;
* receiving;
* reservations/customer requests;
* inventory valuation algorithms;
* return financial calculations;
* inventory conflict-resolution workflows.

Those remain owned by their respective domains.

---

## 2. Governing principle

POS records **what happened in the sale or return**.

Inventory records **what that event means for stock**.

> **The completed POS operation is the originating commercial fact; the central Inventory ledger is the authoritative inventory history.**

Conceptually:

```text
Completed POS operation
        ↓ synchronize
Accepted centrally
        ↓
Inventory posting
        ↓
Inventory ledger
        ↓
Inventory balance / unit state
```

The POS workstation does not maintain a second authoritative inventory ledger.

---

## 3. Inventory authority

The organization server owns the consolidated inventory record.

Inventory authority includes:

* `inventory_ledger_entries`;
* `inventory_balances`;
* `inventory_units`;
* inventory valuation records.

A workstation may possess:

* a replicated inventory checkpoint;
* locally completed unsynchronized sales/returns;
* an effective local availability projection.

That projection exists to support offline operation.

It does not replace central inventory authority.

---

## 4. Tracking modes

POS inventory behavior follows the merchandise/inventory tracking model defined by the catalog and Inventory domains.

The relevant distinctions are:

```text
quantity-tracked
individually tracked
non-inventory
```

These are materially different POS behaviors.

---

## 5. Quantity-tracked merchandise

For quantity-tracked merchandise, a completed sale creates a negative on-hand inventory effect for the sold variant at the transaction's store.

Conceptually:

```text
Sale:
Variant V
Quantity 2

Inventory effect:
Store S / Variant V
on_hand -2
```

The effect is associated with the completed transaction/line that caused it.

---

## 6. Quantity remains positive on POS lines

Transaction-line quantity remains a positive quantity.

Direction determines the inventory effect.

For example:

```text
direction = sale
quantity = 2
```

means:

```text
inventory effect = -2
```

while:

```text
direction = return
quantity = 2
```

may mean:

```text
inventory effect = +2
```

according to Returns rules.

POS does not encode returns by using negative line quantities.

---

## 7. Individually tracked merchandise

An individually tracked sale identifies the exact physical `inventory_unit`.

Conceptually:

```text
Variant V
Inventory Unit U
Quantity 1
```

The inventory effect remains associated with the parent variant while also identifying the exact unit.

Conceptually:

```text
Store S
Variant V
Inventory Unit U
sale
```

The unit does not become an unrelated inventory object detached from its variant.

---

## 8. Exact-unit identity is required

For an individually tracked sale:

> **The POS must identify the exact inventory unit being sold.**

It must not synchronize:

```text
one Used copy of Variant V
```

and ask the server to choose whichever unit is available.

The customer transaction concerns the specific physical unit presented to the cashier.

---

## 9. No unit substitution

If the server later discovers that Inventory Unit U has conflicting central history, ShelfSense must not silently replace it with Inventory Unit V.

The completed POS fact remains:

```text
sold Inventory Unit U
```

Any conflict is handled through Inventory and Reconciliation.

---

## 10. Individually tracked quantity

An individually tracked transaction line has:

```text
quantity = 1
```

for one specific inventory unit.

Multiple individually tracked units are represented as distinct unit-bearing lines or equivalent distinct inventory effects.

They are not collapsed into one anonymous quantity line.

---

## 11. Non-inventory merchandise

A merchandise line may represent a legitimate sellable item that does not affect inventory.

For such a line:

```text
completed financial sale
→ no inventory posting
```

This is different from an inventory-tracked line whose inventory effect happens to be unavailable or conflicting.

---

## 12. Open-ring lines

Open-ring lines do not invent inventory.

A completed open-ring sale:

```text
financial effect
tax effect
tender effect
```

does not automatically create:

```text
inventory effect
```

unless a future explicit business workflow defines one.

---

## 13. Inventory changes at transaction completion

POS inventory consequences are associated with completed transactions.

An:

```text
open
```

or:

```text
suspended
```

transaction does not create an Inventory ledger movement.

Likewise, pre-completion line voids do not require compensating Inventory ledger movements because no completed inventory effect occurred.

---

## 14. Reservations are separate from ledger movement

If ShelfSense later uses open transactions or customer requests to reserve inventory, that reservation represents an availability commitment rather than an on-hand ledger movement.

The general Inventory invariant remains:

```text
available = on_hand - reserved - unavailable
```

A reservation does not require pretending that the item has already left on-hand inventory.

The exact source of `reserved` belongs to the reservation/requesting domain.

---

## 15. Local inventory view

Because a workstation can operate offline, it cannot rely entirely on a live central balance query.

Instead, the POS maintains an **effective local inventory view**.

Conceptually:

```text
accepted server inventory checkpoint
+
applicable locally completed operations
not yet represented by that checkpoint
=
effective local inventory view
```

This is a projection for local decision-making, not an independent ledger.

---

## 16. Quantity-tracked local projection

For quantity-tracked inventory, conceptually:

```text
local effective on_hand
=
server checkpoint on_hand
+ unsynchronized local inventory deltas
```

For example:

```text
Server checkpoint:
on_hand = 5

Local offline sales:
-1
-2

Effective local on_hand:
2
```

The POS therefore does not continue displaying `5` merely because those sales have not reached Rails.

---

## 17. Local availability

Where reserved and unavailable quantities are relevant:

```text
available =
effective on_hand
- effective reserved
- effective unavailable
```

Phase 4/5 may initially have no local reserved/unavailable effects.

The model must nevertheless remain compatible with the Inventory invariant.

---

## 18. Local operation overlay must not double-count

When a newer server checkpoint already incorporates a previously local operation, the POS must stop applying that operation as an additional local overlay.

Incorrect:

```text
server checkpoint already includes Sale A
+
local overlay still subtracts Sale A
```

Correct:

```text
server checkpoint includes Sale A
→ Sale A no longer contributes separately
```

The exact checkpoint/acknowledgment mechanism belongs to the inventory replication/synchronization contract.

---

## 19. Inventory checkpoint is not transaction history

A replicated balance such as:

```text
Variant V
on_hand = 8
```

is a server inventory checkpoint/projection.

It is not a replacement for:

* Inventory ledger history;
* local completed POS operations;
* unit-level history.

Refreshing that checkpoint must not erase local originating facts.

---

## 20. Quantity availability may be advisory offline

For ordinary quantity-tracked merchandise, ShelfSense may permit completion even when local effective availability is insufficient.

Example:

```text
effective local available = 0
customer buys quantity 1
```

The POS may:

* warn;
* require permitted policy handling;
* complete the sale.

It must not fabricate stock merely to make the calculation remain nonnegative.

This supports the established offline model where legitimate POS sales can cause consolidated inventory to become negative.

---

## 21. POS negative-inventory policy differs from administrative adjustment policy

Administrative inventory adjustments may reject posting below zero.

Trusted POS sale posting has different semantics:

> **A completed physical sale is evidence that the merchandise was sold, even if the Inventory projection previously said none was available.**

Therefore central POS inventory posting may produce:

```text
on_hand < 0
```

where permitted by the POS inventory contract.

This does not grant the administrative adjustment UI a general ability to bypass negative-inventory controls.

---

## 22. Individually tracked local availability

For individually tracked merchandise, the POS should know which exact units its local inventory view considers available for sale.

After locally selling Unit U:

```text
U
```

must immediately cease to appear as locally available on that installation, even before synchronization.

This prevents ordinary duplicate sale of the same unit on the same workstation.

---

## 23. Cross-workstation exact-unit conflict remains possible

Two disconnected workstations may both have stale local state showing:

```text
Unit U = available
```

and independently complete sales of U.

These are two distinct originating operations.

When consolidated centrally:

* both histories are preserved;
* they are not treated as transport duplicates;
* the server does not substitute another unit;
* Inventory/Reconciliation handles the conflict.

Offline architecture cannot completely prevent this scenario.

---

## 24. Central inventory posting

When a POS operation is centrally accepted, Inventory applies the inventory consequences defined by the completed operation.

The server should use the immutable POS facts such as:

```text
store
variant
inventory unit when applicable
direction
quantity
transaction/line identity
operation identity
```

rather than current UI state.

---

## 25. Inventory posting is idempotent

Retrying the same POS operation must not post another inventory effect.

Conceptually:

```text
Sale Operation O
first ingest:
inventory -1

retry O:
inventory +0 additional
```

The central Inventory effect must be traceable to the originating POS operation/line sufficiently to enforce this invariant.

---

## 26. One commercial effect, one inventory effect

For an inventory-affecting completed POS line, central Inventory should establish exactly one corresponding inventory effect.

It must not depend on whether the synchronization request was delivered:

* once;
* twice;
* ten times.

Transport retries never create additional stock movement.

---

## 27. Central inventory timing

The Inventory ledger records the effect when the operation is accepted centrally while preserving the transaction's original business context.

Relevant historical context may include:

```text
occurred_at
business_date
originating transaction
originating operation
```

The exact distinction between ledger posting timestamp and business occurrence timestamp belongs to Inventory.

Synchronization time must not be mistaken for when the physical sale occurred.

---

## 28. Late quantity sale

Example:

```text
August 13:
Store has central on_hand = 1

Offline POS sells 1.

Another centrally known effect consumes 1.

August 15:
offline sale synchronizes.
```

The August 13 sale is not rewritten or discarded merely because central inventory is now insufficient.

If accepted, Inventory applies the sale and may produce:

```text
on_hand = -1
```

with any appropriate reconciliation signal.

---

## 29. Returns restore the original inventory kind

A completed linked return reverses the relevant historical inventory effect.

For quantity-tracked merchandise:

```text
original sale -1
linked return +1
```

For individually tracked merchandise:

```text
original sale Unit U
linked return Unit U
```

The return does not select another unit.

---

## 30. Returned merchandise initially re-enters Inventory custody

The normal POS return answers:

> Was the sold merchandise physically returned to the store?

If yes, the return restores the corresponding Inventory custody/on-hand effect.

A later determination that the returned item is:

* damaged;
* unavailable for sale;
* return-to-vendor;
* discard;

belongs to a subsequent Inventory workflow.

POS Returns should not overload the financial return with an inventory disposition system.

---

## 31. Non-inventory returns

A return of non-inventory merchandise may have financial/tender effects without an Inventory effect.

Returns owns whether the return itself is permitted.

Inventory Integration simply follows the tracking mode of the returned historical line.

---

## 32. Unlinked returns

The Inventory effect of an unlinked return cannot always be inferred safely because ShelfSense may not know the original:

* tracking mode/history;
* exact inventory unit;
* prior inventory effect.

Therefore unlinked-return inventory behavior must be explicitly defined by Returns policy before implementation.

It must not be inferred by simply using current product state.

---

## 33. Inventory correction is not POS mutation

If a POS operation later produces an inventory discrepancy, ShelfSense does not edit the completed transaction to make inventory balance.

Instead:

```text
completed POS fact
+
inventory reconciliation condition
+
Inventory-domain correction if needed
```

preserves both commercial and inventory history.

---

## 34. Inventory valuation

POS owns the commercial sale/return facts.

Inventory owns inventory valuation.

A POS operation may trigger corresponding valuation consequences centrally, but the POS should not become the authority for:

* inventory unit cost;
* weighted-average inventory value;
* COGS calculation;
* valuation adjustments.

Conceptually:

```text
Completed POS sale
        ↓
Inventory quantity/unit posting
        ↓
Inventory valuation policy
        ↓
valuation entry / COGS basis
```

The exact valuation algorithm belongs to Inventory.

---

## 35. Offline POS does not calculate authoritative inventory cost

A workstation may possess cost information later if a concrete POS workflow needs it, but ordinary transaction completion should not require the POS to calculate authoritative inventory valuation.

Customer price and inventory cost are separate concepts.

Therefore:

```text
selling price
```

must not be treated as:

```text
inventory cost
```

or vice versa.

---

## 36. Late operations and valuation

Late offline operations can complicate inventory valuation because their business occurrence order may differ from central arrival order.

This specification does not define the valuation algorithm used to handle such late activity.

The required invariant is:

> **The original sale/return occurrence context must remain available so Inventory valuation can apply its defined late-posting policy without rewriting the POS transaction.**

The exact valuation treatment remains an Inventory-domain decision.

---

## 37. Reporting

POS reporting may summarize inventory effects such as:

```text
units sold
units returned
individually tracked units sold
```

but those totals are reporting projections.

Inventory reporting requiring authoritative stock state should derive from the Inventory domain.

A Z report does not replace the Inventory ledger.

---

## 38. Synchronization and inventory outcome

Operation Synchronization owns delivery and ingest outcome.

Inventory Integration owns the inventory consequence of an accepted operation.

Reconciliation owns discrepancies that arise when that consequence conflicts with central state.

Conceptually:

```text
Operation Synchronization
        ↓
accepted POS operation
        ↓
Inventory Integration
        ↓
inventory posting
        ↓
possible Reconciliation condition
```

---

## 39. Phase 4 delivery

Phase 4 should implement the minimum integration necessary to prove the architecture:

* quantity-tracked Standard variant;
* one completed sale;
* local inventory checkpoint/projection;
* local sale overlay;
* completed-sale inventory payload;
* central inventory posting;
* POS-specific permission to permit resulting negative on-hand where appropriate;
* idempotent inventory posting.

The end-to-end proof is:

```text
server checkpoint
↓
complete sale locally
↓
local effective inventory decreases
↓
synchronize
↓
central inventory ledger changes exactly once
↓
retry synchronization
↓
no additional inventory effect
```

---

## 40. Phase 5 usage

Phase 5 operationalizes the quantity-tracked path for real Cash sales.

The cashier can:

```text
scan Standard item
↓
complete sale offline
↓
local effective availability updates immediately
↓
continue selling
↓
synchronize later
```

The sale must not require a live central inventory query.

---

## 41. Phase 6 expansion

Phase 6 should add:

* individually tracked units;
* duplicate-unit conflict handling;
* returns;
* exchanges;
* broader inventory-effect reporting;
* required inventory reconciliation workflows.

The same authority model remains:

```text
POS originates commercial fact
Inventory owns stock consequence
```

---

## 42. Pending decisions

### 42.1 Inventory checkpoint contract

Define the exact server-to-POS checkpoint representation for:

* quantity balances;
* individually tracked unit state;
* acknowledgment/watermark needed to remove local overlays.

### 42.2 Local availability warnings

Define UX/policy for quantity-tracked sale when:

```text
effective available <= 0
```

The architecture permits negative consolidated on-hand; exact cashier warning behavior remains open.

### 42.3 Reservation integration

When POS/customer reservations are implemented, define how local/central reservation facts contribute to:

```text
reserved
```

without turning reservation into an on-hand ledger movement.

### 42.4 Individually tracked availability projection

Define the exact local unit states required before Phase 6.1.

### 42.5 Unlinked return inventory behavior

Finalize with Returns before Phase 6.4.

### 42.6 Valuation of late offline operations

Define in the Inventory valuation specification how sale/return valuation handles business occurrence time versus central posting order.

### 42.7 Inventory-effect linkage

Define the exact central relationship among:

```text
POS operation
transaction line
inventory ledger entry
valuation entry
```

sufficient for idempotency, audit, and reporting.

---

## 43. Core invariants

1. **The completed POS transaction is the originating commercial fact; the central Inventory ledger is authoritative for inventory history.**
2. **The POS workstation does not maintain a second authoritative Inventory ledger.**
3. **Quantity-tracked sales decrease on-hand inventory for the sold variant.**
4. **Individually tracked sales identify the exact inventory unit and its parent variant.**
5. **An individually tracked unit is never silently substituted during synchronization or reconciliation.**
6. **Non-inventory and open-ring lines do not create inventory effects.**
7. **Open/suspended transactions do not create on-hand ledger movements.**
8. **Reservations, when supported, affect availability without pretending on-hand stock has already moved.**
9. **The POS maintains an effective local inventory view from a server checkpoint plus applicable local originating effects.**
10. **Local operations already incorporated into a newer server checkpoint must not be applied twice.**
11. **A locally completed sale changes the local effective inventory view before central synchronization.**
12. **Quantity-tracked POS sales may produce negative central on-hand rather than rewriting a completed physical sale.**
13. **Administrative negative-inventory policy does not automatically govern trusted POS posting.**
14. **Locally sold individually tracked units cease to appear locally available immediately.**
15. **Two distinct offline sales of the same unit are business conflicts, not transport duplicates.**
16. **Accepted POS inventory effects are posted centrally idempotently.**
17. **Retrying the same POS operation never creates another inventory movement.**
18. **Synchronization time does not replace the original sale/return occurrence context.**
19. **Linked returns reverse the inventory effect of the original line.**
20. **An individually tracked linked return restores the exact original unit.**
21. **Physical returns restore Inventory custody first; damage/RTV/etc. are later Inventory workflows.**
22. **Inventory discrepancies are corrected with new Inventory facts, not by editing completed POS history.**
23. **Inventory valuation is owned by Inventory, not POS.**
24. **POS selling price is not inventory cost.**
25. **Late operation context must be preserved so Inventory can apply its defined valuation policy.**
26. **Z and POS inventory summaries do not replace the Inventory ledger.**

---

## 44. Acceptance examples

### Example A — quantity-tracked offline sale

Given:

```text
Server checkpoint:
Variant V on_hand = 5
```

when the offline POS completes a sale of quantity `2`,

then:

```text
effective local on_hand = 3
```

before synchronization.

After central acceptance:

```text
central inventory effect = -2
```

exactly once.

---

### Example B — synchronization retry

Given Sale Operation O has already caused:

```text
Variant V -1
```

centrally,

when O is submitted again,

then no second `-1` inventory effect is created.

---

### Example C — another local sale before synchronization

Given:

```text
server checkpoint = 5
local Sale A = -2
```

the POS displays effective local on-hand `3`.

If another local sale of `1` completes:

```text
effective local on_hand = 2
```

even though Rails has not yet received either sale.

---

### Example D — updated server checkpoint

Given Sale A has synchronized and a new checkpoint contains:

```text
on_hand = 3
```

with sufficient context indicating Sale A is included,

then the POS does not calculate:

```text
3 - Sale A = 1
```

again.

Sale A is removed from the local overlay.

---

### Example E — quantity sale below zero

Given:

```text
effective local available = 0
```

when policy allows the cashier to complete a quantity-tracked sale of `1`,

then the sale remains a completed physical/business fact.

After synchronization, central on-hand may become:

```text
-1
```

rather than ShelfSense inventing stock or changing the sale.

---

### Example F — individually tracked sale

Given:

```text
Variant V
Inventory Unit U
locally available
```

when U is sold,

then:

* the transaction records U;
* U immediately ceases to be locally available;
* synchronization posts the inventory effect against V/U.

---

### Example G — duplicate exact-unit sale across workstations

Given disconnected Workstations A and B both believe Unit U is available,

when each completes a distinct sale of U,

then:

* both originating sale histories are preserved;
* neither is treated as a retry of the other;
* no substitute unit is assigned;
* Inventory/Reconciliation receives an exact-unit conflict.

---

### Example H — linked quantity return

Given the original sale reduced Variant V by `2`,

when a linked return of quantity `1` completes,

then the return creates:

```text
Variant V +1
```

according to the historical return relationship.

---

### Example I — linked individual-unit return

Given the original transaction sold Inventory Unit U,

when the customer completes a linked return,

then Inventory receives U back.

ShelfSense does not select another unit of the same variant.

---

### Example J — damaged returned item

Given a linked return physically restores Unit U to store custody,

when staff determine that U is damaged,

then the POS return remains unchanged.

Inventory subsequently records the appropriate unavailable/damaged classification through its own workflow.

---

### Example K — non-inventory sale

Given a Standard variant is configured as non-inventory,

when it is sold,

then the transaction has normal:

* pricing;
* tax;
* tender;
* receipt

facts but no Inventory ledger effect.

---

### Example L — open ring

Given a cashier completes an authorized open-ring line,

then no product inventory is created or decremented merely to account for the sale.

---

### Example M — late offline sale

Given an August 13 sale synchronizes August 15,

then its central Inventory posting preserves linkage to the original August 13 transaction/occurrence context.

The POS transaction is not moved to August 15.

---

## 45. Related contracts

Inventory Integration will eventually require exact contracts for:

### Completed-sale inventory effect

Define the inventory-relevant portion of a completed sale operation:

```text
store_id
transaction_id
transaction_line_id
operation_id
variant_id
inventory_unit_id when applicable
tracking mode
direction
quantity
occurred_at
business_date
```

### Inventory checkpoint

Define the server state replicated to the workstation and the mechanism for determining which local operations are already represented by that checkpoint.

### Local inventory projection

Define deterministic calculation of:

```text
server checkpoint
+
unincorporated local operations
→ effective local availability
```

### Inventory posting idempotency

Define the stable source relationship preventing repeated synchronization from creating repeated ledger effects.

### Inventory valuation

Define separately how centrally accepted POS inventory movements produce inventory valuation/COGS effects, particularly when offline operations arrive out of occurrence order.

---

The Inventory Integration domain defines **how completed POS commercial activity becomes inventory history without requiring the POS workstation to become an independent inventory authority**.

Its central boundary is:

> **The POS says what was sold or returned. Inventory decides and records what that means for stock and valuation.**
