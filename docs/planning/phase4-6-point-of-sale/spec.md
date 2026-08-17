Below is a repository-ready **detailed implementation plan** translating the POS operating model and the implementation map into concrete Phase 4–6 work. It preserves the broader “initial complete POS” as the destination while deliberately sequencing the work from architectural foundation → first operational cash register → core POS breadth.

**Phase 4 implementation authority:** For Phase 4 scope, schema outline, completion boundary, tax, receipt identity, Register/Terminal vocabulary, operation/Core dual authority, and `CompletedPosOperation` v1 semantics, prefer:

- [phase4-plan.md](phase4-point-of-sale/phase4-plan.md)
- [phase4-schema.md](phase4-point-of-sale/phase4-schema.md)
- [completed-pos-operation-v1.md](phase4-point-of-sale/completed-pos-operation-v1.md)
- [pos-tax-contract.md](phase4-point-of-sale/pos-tax-contract.md) ([ADR-019](../../adr/ADR-019-pos-sales-tax-model.md))
- [receipt-identity.md](phase4-point-of-sale/receipt-identity.md) ([ADR-006](../../adr/ADR-006-receipt-numbering.md))
- [register-identity.md](phase4-point-of-sale/register-identity.md) ([ADR-021](../../adr/ADR-021-register-and-terminal-identity.md))
- [operation-and-core-facts.md](phase4-point-of-sale/operation-and-core-facts.md) ([ADR-020](../../adr/ADR-020-pos-operation-envelope-and-core-facts.md))

Those companions supersede conflicting Phase 4 detail in §4 of this document (especially command vs completed-operation naming, receipt-inside-operation, sales-tax model, receipt reference format, Register vs Terminal, envelope vs Core, session column minimality, `pos_operations`, and build order).

**Phase 5 implementation authority:** For Phase 5 cash accountability, session close snapshots, Z finalize snapshots, and slice sequencing, prefer:

- [phase5-plan.md](phase5-cash-register/phase5-plan.md)
- [phase5-schema.md](phase5-cash-register/phase5-schema.md)

Those companions supersede conflicting Phase 5 detail in §5 of this document (especially session cash column names, expected-cash formula, Z snapshot persistence, and authorization for finalize).

**Phase 4 prerequisite:** Complete the `workstations` → `registers` rename slice (ADR-021 / [register-identity.md](phase4-point-of-sale/register-identity.md) §5) before POS reporting-period, session, or transaction migrations.

# POS Phases 4–6 Detailed Implementation Plan

## 1. Purpose

This plan implements the initial ShelfSense POS defined by the POS Register Operating Model and Initial Implementation Scope.

The implementation will begin as a **Rails-native POS**, but Rails is treated as the first POS client rather than as a privileged bypass around the POS architecture.

The governing model is:

```text
Cashier interaction
        ↓
Working POS transaction
        ↓
CompleteTransactionCommand
        ↓
Authoritative completion
   ├── allocate receipt
   ├── freeze commercial facts
   └── construct CompletedPosOperation (includes receipt)
        ↓
Authoritative POS posting effects
        ↓
┌─────────────┬─────────────┬─────────────┐
│ Transaction │  Inventory  │  Reporting  │
│    facts    │   ledger    │    facts    │
└─────────────┴─────────────┴─────────────┘
```

The Rails POS performs completion and posting in one PostgreSQL transaction.

A future standalone Terminal completes locally on behalf of a Register (including receipt), then synchronizes the same canonical `CompletedPosOperation`. Terminal identity is required before offline completion authority (ADR-021).

The resulting central business facts must remain equivalent regardless of originating client.

---

# 2. Delivery model

The POS work is divided into three major delivery stages:

| Phase                                                | Purpose                                                                                                                                     |
| ---------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| **Phase 4 — POS Transaction and Posting Foundation** | Establish contracts, transaction semantics, calculations, immutable completion, idempotency, and authoritative posting                      |
| **Phase 5 — First Operational Cash Register**        | Turn the Phase 4 transaction path into a usable keyboard/scanner-oriented Cash register                                                     |
| **Phase 6 — Core POS Breadth**                       | Add merchandise breadth, controlled actions, discounts, tenders, suspend/recall, returns, post-void, Cash operations, and broader reporting |

Explicitly deferred beyond these phases:

* Stored Value;
* customer reservation pickup;
* customer display;
* integrated Card processor;
* standalone/offline Terminal runtime (requires first-class Terminal before offline completion).

---

# 3. Locked architectural constraints

## 3.1 One transaction model

ShelfSense does not persist separate transaction types for:

```text
sale
refund
exchange
```

A transaction contains independently directed:

```text
sale lines
return lines
```

The resulting transaction net determines settlement:

```text
transaction net > 0
→ payment required

transaction net < 0
→ refund required

transaction net = 0
→ no settlement required
```

“Sale,” “refund,” and “exchange” remain cashier/workflow descriptions only.

---

## 3.2 Completed transactions are immutable

Before completion:

```text
transaction = mutable working state
```

After completion:

```text
transaction = immutable commercial history
```

Corrections create new facts.

Examples:

```text
linked return
post-void
```

must never rewrite the original completed transaction.

---

## 3.3 POS clients do not directly post downstream effects

The POS client constructs the completed commercial operation.

The authoritative core posting boundary owns:

* completed transaction persistence;
* Inventory effects;
* reporting association;
* receipt assignment;
* operation idempotency;
* resulting authoritative status.

The Rails POS must not directly mutate:

```text
inventory_balances
report totals
Z totals
```

as shortcuts around the posting boundary.

---

## 3.4 Receipt identity

Permanent receipt identity is assigned during authoritative completion.

```text
open transaction      → no final receipt sequence / reference
suspended transaction → no final receipt sequence / reference
cancelled transaction → no final receipt sequence / reference
completed transaction → permanent receipt sequence + human reference
```

Receipt sequencing is scoped to store + register (`UNIQUE(store_id, register_id, receipt_sequence)`).

Human-facing forms (same identity):

```text
S{store_number}-R{register_number}-T{receipt_sequence}
Store: 003   Reg: 02   Trans: 0018427
```

See [receipt-identity.md](phase4-point-of-sale/receipt-identity.md), ADR-006, and ADR-021. Domain term is **Register**; cashier copy may say `Reg`. **Terminal** is deferred for Phases 4–6.

---

## 3.5 Working transactions do not initially reserve inventory

The initial Rails POS will not introduce inventory reservations for open transactions.

```text
working transaction
→ no authoritative inventory effect

completed sale
→ authoritative Inventory ledger effect
```

The existing invariant remains:

```text
available = on_hand - reserved - unavailable
```

but POS working state does not initially contribute to `reserved`.

Reservation behavior may be introduced later when there is a concrete need.

---

# 4. Phase 4 — POS Transaction and Posting Foundation

> **Canonical Phase 4 packet:** [phase4-plan.md](phase4-point-of-sale/phase4-plan.md), [phase4-schema.md](phase4-point-of-sale/phase4-schema.md), [completed-pos-operation-v1.md](phase4-point-of-sale/completed-pos-operation-v1.md). Use those for implementation. Sections 4.1–4.14 below remain a narrative summary and may lag the companions.

## Objective

Prove that ShelfSense can construct, validate, complete, and authoritatively post one deterministic Cash sale without relying on UI-specific or Rails-specific hidden state.

Phase 4 is primarily an architectural and domain foundation.

It is **not yet a complete operational register**.

---

# 4.1 Register execution context

Implement the minimum context required by every POS operation:

```text
store_id
register_id
pos_session_id
performed_by
occurred_at
business_date
```

### Requirements

* Register is the durable logical checkout identity (ADR-021).
* Register is distinct from a future Terminal (concrete POS client).
* Phase 4 does not require Terminal enrollment.
* Actor identity comes from existing central authentication.
* Business date must be explicitly resolved rather than inferred later from `created_at`.
* Reporting/Z periods and Sessions are Register-scoped.

### Acceptance

A completed operation can always answer:

> Where did this occur?

> On which Register?

> During which Session?

> Who performed it?

> When did it occur?

> To which business date does it belong?

---

# 4.2 Working transaction foundation

Implement a mutable Rails working transaction.

Initial scope:

```text
one Store
one Register
one active Session
Standard quantity-tracked merchandise
sale-directed lines only
Cash settlement
```

### Initial commands

Implement explicit application actions such as:

```text
StartTransaction
AddMerchandise
ChangeQuantity
RemoveOrVoidWorkingLine
CancelTransaction
TenderCash
CompleteTransaction
```

Exact class names are implementation details.

The important requirement is that POS business actions are expressed explicitly rather than through arbitrary model mutation.

---

# 4.3 Merchandise lookup

Implement POS merchandise resolution for Phase 4.

Support:

* primary product identifier;
* variant SKU;
* existing normalized identifier rules.

Flow:

```text
scan/input identifier
        ↓
resolve product variant
        ↓
verify supported Phase 4 tracking mode
        ↓
add Standard quantity-tracked line
```

Reject:

* unknown identifiers;
* inactive/unsellable merchandise;
* individually tracked merchandise;
* non-inventory merchandise;
* unsupported line types.

These become Phase 6 capabilities.

---

# 4.4 Basic pricing calculation

Implement the initial pricing sequence:

```text
regular reference price
        ↓
selling unit price
        ↓
quantity
        ↓
extended selling amount
```

For Phase 4:

```text
selling unit price = reference unit price
```

No override or discount is supported yet.

### Required behavior

* Missing required price blocks the line/completion.
* Missing price must never become zero implicitly.
* Money uses integer cents.
* Quantity changes deterministically recalculate extended value.

### Completed pricing facts

Preserve:

```text
reference_unit_price_cents
selling_unit_price_cents
quantity
extended_selling_amount_cents
```

---

# 4.5 Ordinary tax calculation

Implement the initial deterministic POS tax calculation per [pos-tax-contract.md](phase4-point-of-sale/pos-tax-contract.md) and [ADR-019](../../adr/ADR-019-pos-sales-tax-model.md).

```text
Tax Class + Store Tax Rules + active Store Taxes
→ independent component determinations
→ half-up cents per Store Tax
→ sum rounded components
```

Phase 4: taxable basis = extended selling amount; applied Tax Class = merchandise Tax Class; snapshot every active Store Tax (including `applies = false`); reject unresolved (`applies IS NULL`) rules. No Tax Class override, exemption, or combined-rate authority.

Golden fixtures: tax contract §14.

---

# 4.6 Cash settlement calculation

Implement Cash settlement.

Preserve:

```text
amount_due
amount_presented
amount_applied
change
```

For ordinary Cash payment:

```text
presented = applied + change
```

and:

```text
applied = transaction amount due
```

for the simple one-tender Phase 4 path.

### Validation

Reject:

```text
presented < amount due
```

unless future mixed tender capability is in use.

Change is not represented as a refund tender.

---

# 4.7 Completed POS operation contract

Define version 1 of the canonical completed operation per [completed-pos-operation-v1.md](phase4-point-of-sale/completed-pos-operation-v1.md).

Critical distinctions:

* `CompleteTransactionCommand` — pre-completion request (no permanent receipt yet).
* `CompletedPosOperation` — already-completed fact; **always includes** `receipt.sequence` and store/register number snapshots (optional compact `reference`).

The contract must be versioned, serializable, independent of Rails controller state, and sufficient without hidden input. Lock sign conventions, tax-component identity, and required merchandise snapshots before migrations.

---

# 4.8 Operation identity and idempotency

Every completion receives a globally unique `operation_id`, distinct from `transaction_id`.

Durable `pos_operations` holds ADR-009 command state (`command_payload_hash`) and permanent completed-operation provenance (`envelope` + `envelope_hash`) — see [operation-and-core-facts.md](phase4-point-of-sale/operation-and-core-facts.md) / ADR-020. Do not use `transaction_id` as the idempotency substitute. Do not treat the envelope as optional or reconstruct-only.

```text
same (source_id, command_type, idempotency_key) + same command_payload_hash → same authoritative result
same key + different command_payload_hash → integrity failure
```

Retry must never duplicate completed transaction, receipt sequence, tender, Inventory movements, outbox fact, or reporting effect.

Normalized Core is used for all ordinary commercial workflows; the envelope answers origin/provenance questions.

---

# 4.9 Authoritative completion boundary

Implement one central POS completion path.

Conceptually:

```text
CompleteTransactionCommand
        ↓
authorize + lease on command_payload_hash
        ↓
BEGIN PostgreSQL
        ↓
allocate registers.receipt_sequence (row lock)
freeze occurred_at / business_date
freeze commercial facts
construct canonical CompletedPosOperation v1 (fact_type = pos.transaction_completed)
persist normalized completed POS facts
persist pos_operations (envelope + envelope_hash)
post paired Inventory effects (Inventory::PostSale)
record audit + pos.transaction_completed outbox
        ↓
COMMIT
```

Only after this commits successfully is the transaction complete. Receipt assignment is part of constructing the completed operation. Envelope and Core must not diverge.

---

# 4.10 Inventory posting

For each completed quantity-tracked sale line, post through **`Inventory::PostSale`** (or equivalent)—not `Inventory::PostAdjustment`:

```text
paired physical effect  (delta −quantity)
paired valuation effect
reject_below_zero
source_type = PosTransactionLine
```

Do not directly mutate `inventory_balances`.

Required linkage should allow tracing:

```text
POS operation
→ transaction
→ transaction line
→ paired Inventory ledger effects
```

Retrying the same POS operation must produce no second Inventory ledger effect set.
# 4.11 Receipt identity

Implement Register-scoped receipt sequence allocation and the human-facing reference per [receipt-identity.md](phase4-point-of-sale/receipt-identity.md):

```text
S{store_number}-R{register_number}-T{receipt_sequence}
```

Requires durable `registers.register_number`. Snapshot store/register numbers on the completed transaction. Assignment must occur atomically with completion.

Receipt rendering/printing (header layout) is not required yet (Phase 5).

---

# 4.12 Minimum audit

Record enough activity to explain:

* operation completed;
* operation rejected;
* transaction cancelled;
* actor;
* Register;
* Session.

Do not build the full controlled-action audit model yet.

---

# 4.13 Phase 4 failure tests

Explicitly test:

### Completion validation failure

```text
invalid operation
→ no completed transaction
→ no receipt
→ no Inventory effect
```

### Database failure

```text
commit fails
→ transaction remains incomplete
```

### Duplicate operation

```text
submit O
submit O again
→ one transaction
→ one receipt
→ one Inventory effect
```

### Lost response simulation

```text
server commits O
client does not observe response
retry O
→ same result returned
```

---

# 4.14 Phase 4 acceptance

Phase 4 is complete when a headless/application-level scenario can:

```text
1. Establish Store/Register/Session/actor context.
2. Start a transaction.
3. Resolve a Standard quantity-tracked variant.
4. Add quantity.
5. Resolve regular price (from product_variants.regular_price_cents).
6. Calculate tax.
7. Create Cash settlement.
8. Complete through the versioned operation contract.
9. Assign receipt identity (snapshots + sequence).
10. Post exactly one paired Inventory physical + valuation effect set per sale line.
11. Record pos.transaction_completed outbox in the same transaction.
12. Retry the same operation.
13. Observe no duplicate business effect.
```

---

# 5. Phase 5 — First Operational Cash Register

**Implementation authority:** Prefer [phase5-plan.md](phase5-cash-register/phase5-plan.md) and [phase5-schema.md](phase5-cash-register/phase5-schema.md). Slice 1 (headless cash / Z) is locked. This section is the multi-phase narrative; where it disagrees on cash columns, blind close, snapshot authority, Z aggregates, business-date confirmation, or finalize gates, the Phase 5 packet wins.

## Objective

Turn the Phase 4 completion path into a cashier-usable online Rails register.

Active context is Store / Register / Reporting period / Session / Cashier. No Terminal table is required (ADR-021).

Phase 5 answers:

> Can a cashier operate an ordinary Cash register through a minimum shift lifecycle using keyboard/scanner input?

---

# 5.1 Register/Z period lifecycle

Implement the minimum Register reporting period.

Flow:

```text
derive BusinessDate.for_store(...)
        ↓
cashier confirms (no arbitrary override)
        ↓
open Register/Z period
        ↓
lock period; open Session; record opening float
        ↓
perform transactions (Phase 4 services)
        ↓
blind closing count; freeze Session cash snapshots
        ↓
lock period; freeze Z aggregates; finalize
```

### Rules

* one active Z/reporting period per Register;
* one immutable business date per active period, confirmed from the store calendar (no backdate);
* multiple Sessions may belong to one Z; each is an independent custody interval;
* closing a Session does not inherently finalize the Z;
* `OpenSession` and `FinalizeReportingPeriod` serialize on the reporting-period row.

Phase 5 UI may remain simple if only one Session is commonly used during testing.

---

# 5.2 Cashier Session

Implement:

```text
open Session
cashier identity
opening time
opening float
closing Cash count
expected Cash
variance
closing time
```

Closed Sessions are immutable.

Do not reopen a closed Session; create a new Session.

---

# 5.3 Opening float

Opening float establishes physical starting Cash.

It is not:

```text
paid-in
```

and not:

```text
Cash tender
```

It belongs to Cash custody/accountability.

---

# 5.4 Keyboard/scanner Register workspace

Authority: [register-workspace.md](phase5-cash-register/register-workspace.md). Interaction wireframes: [register-workspace-ux.md](phase5-cash-register/register-workspace-ux.md). That packet supersedes this section where they disagree.

Build a dedicated Rails POS workspace (Importmap + Turbo + Stimulus; dedicated POS layout, not admin chrome).

Ordinary path:

```text
scan
→ line added (compatible rescan increments the existing line)
→ scan
→ quantity correction if needed
→ tender (TenderCash)
→ complete (CompleteTransaction; separate HTTP request)
→ on-screen completion receipt/confirmation
→ next transaction
```

without requiring a mouse. Every shortcut has a visible control.

### Required UX behavior

* persistent transaction workspace;
* one primary scan/input control; autofocus; scanners are keyboard input ending in Enter;
* Enter confirms the current ephemeral mode;
* Escape backs out where [register-workspace.md](phase5-cash-register/register-workspace.md) allows;
* focus returns to the primary input after ordinary operations;
* GET workspace never creates a transaction; working + tender restores completion-pending (and a matching completion `operation_id` if one exists); no working transaction redirects to the enter gate (never infers a “latest” receipt);
* at most one working transaction per Session (`ResumeOrStartTransaction` on POST enter/continue);
* completed sale shows an on-screen confirmation from immutable facts, then continue starts a fresh working transaction;
* errors preserve the current working transaction.

---

# 5.5 Minimum input modes

Phase 5 needs at least:

```text
SALE_ENTRY
QUANTITY
TENDER
```

UI modes are ephemeral browser state. Authoritative status remains `working` / `completed` / `cancelled`. After `TenderCash` succeeds, input is locked for `CompleteTransaction` retry (not a fourth named mode). Additional named modes are Phase 6.

---

# 5.6 Standard merchandise sale

UI supports only:

```text
Standard quantity-tracked merchandise
```

No individually tracked, non-inventory, or open-ring lines yet.

`AddMerchandise` merges a compatible rescan (same variant, direction, unit price, tax class) by incrementing quantity and returns the resulting line.

---

# 5.7 Quantity correction

Allow quantity change before completion via `ChangeQuantity` (absolute quantity; `0` is invalid — remove the line instead).

Recalculate:

* extended price;
* tax;
* total.

Basket mutations (`AddMerchandise`, `ChangeQuantity`, `RemoveWorkingLine`) clear any working tender in the same transaction.

Phase 5 has no approval requirement because price/discount-controlled actions are not yet exposed.

---

# 5.8 Working-line removal

Allow an accidental working line to be removed/voided according to the meaningful-line persistence rule.

Do not introduce the full controlled line-void policy yet.

---

# 5.9 Transaction cancellation

Allow an open transaction to be cancelled.

Cancellation:

* requires explicit confirmation that scanner Enter cannot submit (second F9 confirms; Enter ignored);
* is disabled when the working transaction has no lines;
* then `ResumeOrStartTransaction` so the cashier returns to `SALE_ENTRY`;
* creates no completed commercial facts;
* creates no receipt;
* posts no Inventory movement.

Preserve minimal cancellation activity where the transaction had meaningful working state.

---

# 5.10 Cash tender UI

Provide a focused Cash interface. `TenderCash` and `CompleteTransaction` are **two HTTP requests**. Rails issues `completion_operation_id` on a successful tender (Stimulus treats it as opaque). Refresh of completion-pending **restores** a matching `in_flight`/`failed` operation rather than minting a second attempt. Completion retries must not call `TenderCash` again ([register-workspace.md](phase5-cash-register/register-workspace.md) §6). Return to sale is `AbandonTender` (clears the persisted tender). A lost complete response or `POST complete` against an already-completed transaction opens **that** sale's immutable receipt by id.

Example:

```text
Amount due:       $17.24
Cash received:    [20.00]
Change:            $2.76
```

Insufficient Cash stays in `TENDER`. No split tender in Phase 5.

---

# 5.11 Receipt rendering and printing

Slice 2: on-screen **completion receipt/confirmation** from immutable completed transaction facts (`transaction_reference`, total, Cash presented, change, concise lines). No print controls.

Slice 3: the first supported **print** path for those same facts.

Required (print, Slice 3):

* render from immutable completed transaction facts;
* permanent receipt number / transaction reference ([receipt-identity.md](phase4-point-of-sale/receipt-identity.md));
* print prompt after the cashier can already see the on-screen confirmation;
* one supported print path;
* printer failure does not undo completion.

Durable printer-success tracking remains out.

---

# 5.12 Minimum Session totals

Display at least:

```text
completed transaction count
gross sales
tax
Cash tender total
expected Cash
```

While the Session is open, totals may preview from completed facts. After close, cash figures come from persisted closing snapshots. Do not treat a later recomputation as authority.

---

# 5.13 Session close

Close is **blind**. The cashier enters only the physical count. `CloseSession` does not accept expected Cash or variance from the client.

The server calculates:

```text
opening float
+ completed cash payment amount_cents
=
expected Cash

counted − expected = variance
```

Slice 3 must collect the count **before** revealing expected or variance.

No paid-ins, paid-outs, or transfers exist yet. Closed Sessions are immutable.

---

# 5.14 Minimum Z

Provide a basic finalized Register report from **persisted** period snapshots, not a live recalculation.

Commercial totals (completed transactions):

```text
transaction count
subtotal
tax
total
cash payment
```

Session-custody aggregates (sums of independent closed Sessions — not one drawer):

```text
session count
opening float sum
closing expected sum
closing count sum
closing variance sum
```

Also show Register, business date, and who finalized (`finalized_by_user_id`).

Finalize requires: period open; matching `lock_version`; no open Sessions; no working transactions; every Session closed with complete cash snapshots. An unused period may finalize as an all-zero Z. Finalized Z is immutable. `pos.transact` authorizes finalize in Phase 5 (intentionally broad; reconsider in Phase 6).

---

# 5.15 Browser/request failure behavior

Test:

* browser refresh during working transaction;
* repeated Complete;
* response loss;
* Rails validation error;
* printer failure.

Meaningful working state expected to survive browser refresh should be persisted centrally.

Phase 5 does **not** support offline sales.

If Rails/core is unavailable:

```text
POS transaction completion unavailable
```

This is intentional.

---

# 5.16 Phase 5 acceptance

A cashier can:

```text
1. Confirm the calculated store business date (no override).
2. Open Register/Z period.
3. Open Session.
4. Establish opening float.
5. Scan Standard merchandise.
6. Change quantity.
7. Remove mistaken working line.
8. Cancel an open transaction.
9. Tender completed transaction with Cash.
10. Receive correct change.
11. Complete transaction.
12. Print receipt.
13. Immediately begin next transaction.
14. View current Session totals.
15. Enter a blind Cash count (expected/variance revealed after).
16. See variance.
17. Close Session.
18. Finalize basic Z.
```

The normal transaction path is fully keyboard-operable.

---

# 6. Phase 6 — Core POS Breadth

Phase 6 should be delivered as multiple vertical slices.

Do not implement it as one large branch.

---

# 6.1 Merchandise Breadth

## Goal

Support the remaining initial POS line forms.

### Build

#### Individually tracked merchandise

Support exact:

```text
inventory_unit_id
```

Requirements:

* quantity effectively one per unit line;
* exact unit validation;
* unit condition/context;
* unit-specific price behavior where applicable;
* exact Inventory-unit posting.

#### Non-inventory merchandise

Support sale lines that:

* participate in pricing/tax/tender;
* create no Inventory movement.

#### Open-ring lines

Support explicit open-ring entry containing required:

* description;
* department/classification;
* amount;
* tax context;
* reason where policy requires.

Open ring is a line type, not merchandise.

---

# 6.2 Controlled-Action Foundation

Implement the common policy/approval framework **before** implementing features that need manager approval.

### Common concepts

```text
permission
reason
policy
approval
```

### Policy result

```text
direct
approval_required
prohibited
```

### Performer versus approver

Preserve:

```text
performed_by
approved_by
```

Second-actor approval does not transfer cashier ownership of the Session.

### Initial framework

Support exact-action binding so approval applies only to the requested values.

Material changes invalidate approval.

---

# 6.3 Transaction Controls

Build controlled pre-completion actions.

## Price override

Support:

```text
reference price
→ requested selling price
```

Preserve both.

Apply reason/approval policy.

---

## Tax override

Allow selection only among valid configured **Tax Classes** (Tax Class override).

Do not permit arbitrary entered rates. Purchaser exemption is deferred beyond Phase 6.

---

## Controlled line void

Meaningful line voids preserve:

* reason where required;
* performer;
* approval where required;
* prior values/history.

---

## Controlled transaction cancellation

Apply the same framework where policy requires additional authority for meaningful transactions.

---

# 6.4 Discounts

Implement discounts only after the underlying policy framework exists.

## Line discounts

Support defined methods such as:

```text
percentage
fixed amount
fixed per unit
```

where explicitly configured.

---

## Transaction discounts

Support:

```text
percentage
fixed total
```

Allocate transaction discounts deterministically to eligible lines.

### Golden fixtures

Lock and test:

* percentage rounding;
* fixed discounts;
* multiple quantities;
* allocation basis;
* residual-cent allocation;
* discount floor;
* price override + discount;
* tax after discount.

---

# 6.5 Tender Breadth

Expand beyond Cash.

## Check

Support configured Check tender and appropriate reference metadata.

## Externally processed Card

Workflow:

```text
ShelfSense calculates amount
→ cashier processes externally
→ cashier confirms success
→ ShelfSense records Card tender
```

No processor integration yet.

## Other

Support configured genuine settlement methods.

## Mixed tender

Allow multiple tenders.

Enforce:

```text
payments - refunds = transaction net
```

Store tender ordering where meaningful.

---

# 6.6 Suspend and Recall

Implement persistent suspended transactions.

## Suspend

Preserve working state including:

* lines;
* quantities;
* unit identities;
* pricing;
* discounts;
* tax;
* approvals/reasons where applicable;
* originating Register;
* cashier context.

Suspension creates no completed financial facts.

---

## Recall

Revalidate:

```text
merchandise sellability
unit availability/state
price/reference state
tax state
discount eligibility
approval validity
```

Changes affecting the customer must be made visible.

Support at least same-Store recall.

Preserve:

```text
originating_register_id
current_register_id
```

where they differ.

---

# 6.7 Returns and Refunds

Implement after return policy decisions are locked.

## Linked return

Each return line references:

```text
original_sale_line_id
```

Eligibility:

```text
original quantity
-
previously returned quantity
=
remaining returnable quantity
```

Reverse historical:

* selling price;
* override;
* discounts;
* tax;
* exact unit identity where applicable.

---

## Partial returns

Implement deterministic consumption of historical discount/tax allocations.

The final eligible return consumes any residual historical cents.

---

## Unlinked return

Support as a controlled action.

Default:

```text
current selling price
Tax Class + Store Tax configuration (current active determinations)
```

but require explicit confirmation.

Allow controlled price / Tax Class overrides.

Require reason and configurable approval.

Purchaser exemption remains deferred beyond Phase 6.

---

## Refund tender

Refund method is independent of return value.

Policy determines valid refund tenders.

Original tender informs policy for linked returns.

---

## Mixed sale/return

Support sale and return lines in one transaction.

Test:

```text
net payment
net refund
zero net
```

Do not create an `exchange` transaction type.

---

# 6.8 Post-Void

Implement PostVoid as a correction operation against an entire completed transaction.

Original transaction remains immutable.

Create new reversing facts for:

* sale/return activity;
* tax;
* tender;
* Inventory;
* reporting.

Require reason and configurable approval.

External Card corrections must be confirmed as actually performed outside ShelfSense before corresponding Card reversal facts are recorded.

---

# 6.9 Full Cash Operations

Expand Cash Handling.

## Paid-in

Require:

* amount;
* reason;
* actor;
* Session/Register;
* approval where configured.

## Paid-out

Same pattern.

## Drawer → Safe

Internal transfer.

Requires:

```text
source
destination
amount
actor
```

## Safe → Drawer

Same internal transfer model.

Do not represent transfers as paid-in/out.

---

# 6.10 Cash Accountability Expansion

Expected Cash becomes:

```text
opening float
+ Cash payments
- Cash refunds
+ paid-ins
- paid-outs
+ transfers in
- transfers out
=
expected Cash
```

Then:

```text
counted Cash - expected Cash = variance
```

Variance policies may require:

* reason;
* acknowledgment;
* approval.

---

# 6.11 Reporting Breadth

Expand reporting beyond the Phase 5 minimum.

## Current Session

Include:

* gross sale activity;
* gross return activity;
* discounts;
* net commercial activity;
* tax;
* tenders by type;
* expected Cash;
* suspended transaction count.

## Session Close

Preserve immutable Session totals and Cash-accountability result.

## Current Register/Z period

Aggregate completed activity across Sessions.

## Previous Sessions/Z

Support historical lookup and drill-down.

---

# 6.12 Completed Transaction Retrieval

Build practical transaction search.

Support lookup by:

```text
receipt number
transaction reference
date/time
Register
Session
```

Display:

* completed lines;
* sale/return direction;
* quantities;
* returned-to-date quantities;
* price;
* discounts;
* tax;
* tenders;
* inventory unit where applicable.

Actions:

```text
reprint receipt
begin linked return
initiate post-void
```

where permitted.

---

# 6.13 Full Controlled-Action Audit

Expand durable accountability for:

```text
price override
tax override
discount
line void
transaction cancellation
unlinked return
return exception
post-void
paid-in
paid-out
Cash transfer
variance acceptance
approval
```

Preserve as appropriate:

```text
action type
subject
performed_by
approved_by
reason
before values
requested/after values
occurred_at
Register
Session
transaction/line
policy context
```

---

# 7. Deferred capabilities

The following remain explicitly outside Phases 4–6.

## Stored Value

Deferred until there is an authoritative shared-balance model.

Includes:

* gift cards;
* Store Credit;
* Stored Value issuance;
* Stored Value tender.

---

## Customer reservation pickup

Deferred to the customer/request domain.

---

## Customer display

Deferred until the cashier transaction model is stable enough to expose a non-authoritative display projection.

---

## Integrated Card processor

The first POS only records externally processed Card.

Processor authorization, capture, reversal, crash recovery, and unknown-result handling are separate future work.

---

## Standalone/offline Terminal (operating a Register)

Deferred runtime work includes:

```text
.NET
Terminal.Gui or selected dedicated UI
SQLite
Terminal identity
Terminal credentials
Register assignment
reference replication
offline cashier authentication
local deterministic calculation
local transaction completion
receipt/Z local sequence management
transactional outbox
operation synchronization
local Inventory checkpoint/overlay
reconciliation
recovery
clone detection
backup/restore
```

The standalone client must use completed-operation semantics established during Phases 4–6, including a later compatible envelope version that carries Terminal/config provenance before offline completion authority is enabled.

---

# 8. Cross-phase test strategy

## Domain/application tests

Prefer exhaustive tests for:

* calculations;
* state transitions;
* controlled actions;
* idempotency;
* return eligibility;
* Cash equations.

---

## Golden fixtures

Maintain portable fixtures for calculations expected eventually to execute in both Ruby and .NET.

Initially cover:

```text
basic pricing
quantity extensions
tax
Cash settlement
```

Later add:

```text
price overrides
discounts
discount allocations
mixed tender
linked returns
partial-return residuals
mixed sale/return totals
```

---

## Request/integration tests

Test:

* POS commands;
* authoritative completion;
* duplicate operation submission;
* Inventory consequences;
* Session/Z association;
* receipt assignment.

---

## Cashier interaction tests

Where practical, test:

* focus target after scan;
* modal focus;
* Enter/Escape behavior;
* repeated completion input;
* workspace reset;
* validation preserving context.

The normal transaction path should remain keyboard-only.

---

# 9. Implementation sequence summary

```text
PHASE 4
POS TRANSACTION & POSTING FOUNDATION
│
├── operation contract
├── working transaction
├── basic price
├── ordinary tax
├── Cash settlement
├── idempotency
├── authoritative completion
├── receipt identity
└── Inventory posting
        ↓

PHASE 5
FIRST OPERATIONAL CASH REGISTER
│
├── Register/Z period
├── cashier Session
├── opening float
├── scanner/keyboard UI
├── Standard merchandise
├── quantity/cancel
├── Cash tender
├── receipt printing
├── Session totals
├── count/variance
└── minimum Z
        ↓

PHASE 6
CORE POS BREADTH
│
├── 6.1 merchandise breadth
├── 6.2 controlled-action framework
├── 6.3 price/tax controls
├── 6.4 discounts
├── 6.5 tender breadth
├── 6.6 suspend/recall
├── 6.7 returns/refunds
├── 6.8 post-void
├── 6.9 full Cash operations
├── 6.10 Cash accountability
├── 6.11 reporting breadth
├── 6.12 transaction retrieval
└── 6.13 controlled-action audit
        ↓

LATER
STANDALONE/OFFLINE TERMINAL (OPERATING A REGISTER)
```

## 10. Definition of success

At the end of Phase 6, the Rails-native POS should be a functionally complete online bookstore register for the intended initial scope.

More importantly, every completed commercial operation should already be expressible through a stable boundary that a future standalone Terminal operating a Register can reproduce:

```text
Register behavior
        ↓
completed POS operation
        ↓
authoritative ShelfSense posting
```

That means the eventual .NET effort becomes primarily a new implementation of the **Register-side runtime, persistence, calculations, and synchronization**, rather than a redesign of the POS business model.
