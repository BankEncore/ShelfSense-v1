# Phase 6 Slice 6.6 — Post-void

**Status:** Implemented (6.6A–B). Authority remains this document.

**Authority:** Whole-transaction post-void as a compensating completed POS transaction with its own correction lineage. Dual authority with Core remains [mvp-contract.md](mvp-contract.md) / [ADR-020](../../../adr/ADR-020-pos-operation-envelope-and-core-facts.md). Inventory posting remains [inventory-posting-contract.md](../../phase3-inventory-foundation/inventory-posting-contract.md). Controlled-action policy remains [controlled-actions.md](controlled-actions.md). History entry extends [transaction-history.md](transaction-history.md). Returns remain [returns.md](returns.md).

Companions: [phase6-plan.md](phase6-plan.md), [close-z-screens.md](../phase5-cash-register/close-z-screens.md).

Draft POS specifications are vocabulary. This document is implementation authority for the MVP subset. No new ADR.

### Actually locked

```text
post-void ≠ customer return
one new completed PosTransaction; source rows never updated
post_void_of_transaction_id is transaction-level authority
post_void_source_line_id ≠ original_transaction_line_id
post_void_source_tender_id is tender reversal lineage
no return_reason on generated lines
no working basket; cannot edit the generated reversal
FreezePostVoidLine copies source cents exactly; never Tax::Calculate
Inventory::PostPostVoid exact inverse via reversal_of_id
command_type pos.post_void_transaction; fact_type pos.transaction_completed
prospective reversal UUID is fingerprinted before persist
Card confirmation is per tender; Check/Other have no extra policy
Session/Z Sales and Returns exclude post-void transactions
additive finalized_post_void_* snapshots in this slice
Phase 5 ordinary Cash sale unchanged when unused
```

---

## 1. Objective

Correct a completed transaction whose **completion should not have occurred**, without encoding that correction as a linked customer return.

```text
Completed source PosTransaction
         │
         │ post_void_of_transaction_id
         ▼
Completed reversal PosTransaction
         ├── generated line  (post_void_source_line_id)
         ├── generated tender (post_void_source_tender_id)
         └── PosControlledAction(post_void)  # transaction-scoped
```

```text
customer linked return  ≠  post-void generated return-direction line
Inventory::PostReturn   ≠  Inventory::PostPostVoid
```

---

## 2. Scope

### In 6.6

Whole-transaction post-void of a completed current-Store sale, return-only, or mixed transaction. Entry from history. Controlled-action authorization. Exact commercial and inventory inverse as **new-period** facts. Returnability conflict with linked returns. Session/Z post-void snapshots. Receipt/reprint identification.

### Explicitly out

```text
partial post-void
post-void of a post-void
integrated Card reversal
Stored Value
time windows
cross-Store
cancelling foreign working baskets
keyboard map lock (6.7 — [pos-workflow.md](pos-workflow.md); post-void stays history-only)
return_price_adjustment permission
Check/Other external-reversal policy
```

---

## 3. Line kinds (mutually exclusive)

```text
ordinary sale            direction = sale, both FKs nil
linked_return            original_transaction_line_id present
unlinked_return          direction = return, both FKs nil, unlinked_return fact
post_void_generated      post_void_source_line_id present
```

Do **not** set `original_transaction_line_id` on generated reversal lines. Do **not** add `post_void` to the customer return-reason catalog. Generated return-direction lines have **no** return reason.

When the source line was a linked return, that historical FK stays on the **source**. The generated sale does not inherit active return semantics.

---

## 4. Schema

### `pos_transactions`

```text
post_void_of_transaction_id  uuid nullable FK → pos_transactions ON DELETE RESTRICT
UNIQUE WHERE post_void_of_transaction_id IS NOT NULL
CHECK (post_void_of_transaction_id IS NULL OR post_void_of_transaction_id <> id)
```

No reverse pointer on the source. Do **not** add `return_of_transaction_id`.

### `pos_transaction_lines`

```text
post_void_source_line_id  uuid nullable self-FK ON DELETE RESTRICT
UNIQUE WHERE present
CHECK (post_void_source_line_id IS NULL OR post_void_source_line_id <> id)
```

Return-reason CHECK:

```text
ordinary return → return reason required, post_void_source_line_id NULL
post-void generated return → post_void_source_line_id required, return reason absent,
                             original_transaction_line_id NULL
post-void generated sale → post_void_source_line_id required, no return reason
ordinary sale → both FKs nil, no return reason
```

### `pos_tenders`

```text
post_void_source_tender_id  uuid nullable self-FK ON DELETE RESTRICT
UNIQUE WHERE present
CHECK (post_void_source_tender_id IS NULL OR post_void_source_tender_id <> id)
```

### `pos_controlled_actions`

Drop `pos_controlled_actions_line_present`. Expand `action_type` with `post_void`.

```text
post_void → pos_transaction_line_id IS NULL
other types → pos_transaction_line_id NOT NULL
UNIQUE (pos_transaction_id, action_type) WHERE action_type = 'post_void'
```

Do not run post-void through line-oriented `ExecuteControlledAction`.

### Reporting period (additive; not in `closed_at_matches_status`)

```text
finalized_post_void_transaction_count
finalized_post_void_merchandise_cents   # signed
finalized_post_void_discount_cents      # signed
finalized_post_void_tax_cents           # signed
finalized_post_void_net_cents           # signed
```

NULL on pre-6.6 finalized = not captured. New finalize writes `0` when no post-void activity. Lineage FKs keep only the partial unique indexes (`add_reference` `index: false`). The migration is irreversible once post-void rows exist.

---

## 5. Command

No working basket the cashier can edit. `Pos::PostVoidTransaction` owns one atomic command.

Allocate `reversal_transaction_id = SecureRandom.uuid_v7` **before** manager approval. Do not persist the reversal until the command succeeds.

Do **not** call public `CompleteTransaction.call` by stuffing an ordinary working transaction. Reuse receipt allocation, Core completion persistence, operation envelope, audit, and outbox. Controllers never allocate receipts or post inventory.

No Session ⇒ `Open a register before processing a post-void.` A **nonempty** working basket on this Session ⇒ `Complete or cancel the current transaction before post-void.` An empty working row (the usual idle SALE ENTRY) is cancelled, same as Close Register, so the reversal can occupy the one-working-per-session slot.

### Idempotency

```text
command_type = pos.post_void_transaction
fact_type    = pos.transaction_completed
schema_version = 2
```

Narrowly generalize `Pos::OperationLease` to accept `command_type`. Ordinary complete defaults to `pos.complete_transaction` and stays unchanged.

Command payload:

```text
source_transaction_id
prospective_reversal_transaction_id
source_completion_operation_id
source_envelope_hash
reason_code
reason_note iff other
card_reversals[]  { source_tender_id, confirmed, external_reference }
```

Same operation ID + same payload → same completed reversal. Same operation ID + different facts → `PayloadMismatch`. Unique `post_void_of_transaction_id` is the independent DB guard.

---

## 6. Eligibility

Lock source `PosTransaction` then its lines (id order). Inventory locks happen inside `PostPostVoid`.

**Hard invariants** (serialize at completion via source line locks):

```text
effective completed linked return exists → source cannot be post-voided
source has completed post-void → linked return cannot complete
```

Also refuse: source not completed; wrong Store; source is itself a post-void; a completed post-void of this source already exists.

**Working linked return:** if one already exists against the source, refuse. Do **not** redesign 6.5 so line creation reserves the original. A working return started after the check may remain stale; returnability is 0 and completion fails.

---

## 7. Generated reversal

One reversal line per source line; one reversal tender per source tender. Opposite `direction`. Same quantity, variant, unit, prices, discount cents, Tax Class, tax components, line total magnitude, merchandise snapshot.

`Pos::FreezePostVoidLine`: copy the source completed facts, change economic direction. No `Tax::Calculate`, `recalc_extended!`, live price/Tax Class, or `HistoricalReturnAllocation`.

Completion dispatch tests `post_void_generated?` first.

Never copy `price_override` / `line_discount` / `tax_class_override` / `unlinked_return` onto the reversal.

Tenders: reverse **applied** amount and tender-type identity snapshots. Payments ↔ refunds. Do **not** copy `external_reference`. Cash refund omits presented/change. Cash payment reversing a refund is exact (`presented = applied`, `change = 0`). Do not consult `tender_types.allows_refund`.

`reversal.signed_net_cents = -source.signed_net_cents`. Zero-net source → no tenders.

---

## 8. `Pos::PostVoidIntegrity`

Before persisting the completed operation, prove the exact locked mirror: bijection of lines and tenders, opposite directions, equal magnitudes and copied snapshots (`manual_discount_basis_points`, Tax Class ids/code/name including defaults, tax-component code/name snapshots, tender type id/name), signed-net negation, no sale/unlinked controlled actions on generated lines.

---

## 9. Inventory — `Inventory::PostPostVoid`

Named posting service. Do **not** add a historical mode to `PostSale` / `PostReturn`. Do not call `PostAdjustment`. Joins the caller’s transaction.

Locate the source line’s `InventoryLedgerEntry` / `InventoryValuationEntry` (`source_type = PosTransactionLine`, `source_id = source line`). Write exact inverse rows with `reversal_of_id`. New rows: `source_type = PosTransactionLine`, `source_id = generated line`, `entry_type = reversal`. Unique `reversal_of_id` prevents reversing the same effect twice. Non-inventory source lines skip posting. Outbox/audit `inventory.post_void_posted`.

Fail rather than recost:

- Quantity: lock balance; inverse must leave `on_hand >= 0`, `inventory_value >= 0`, and `on_hand == 0 → value == 0`.
- Used reversing a sale: unit currently `removed`; restore at the exact original depletion value; write that amount onto `carrying_value_cents`.
- Used reversing a return: unit currently `on_hand` **and** `carrying_value_cents` equals the source-return acquisition value; then remove.

Message: `Post-void cannot be completed because subsequent inventory activity conflicts with the original transaction.`

Lock order: `InventoryBalance` then `InventoryUnit`.

---

## 10. Returnability

`remaining_quantity` and `summary_for` share one effective-return definition:

- Post-voided source sale → remaining = 0.
- Completed linked return whose **parent** was later post-voided does **not** consume entitlement.

Ordinary `CompleteTransaction` linked-return completion also refuses when the original sale transaction has been post-voided.

---

## 11. Controlled action

Seed:

```text
pos.post_void.perform
pos.post_void.approve
```

`scope_type: either`. Same `phase6_permission_tier_v1`. Associate perform-only; store manager and system administrator perform+approve. `return_price_adjustment` stays reserved.

Reason catalog:

```text
entered_in_error
duplicate_transaction
test_transaction
wrong_register
other          # note required, max 200
```

Fingerprint material includes source/reversal ids, source operation id, source envelope hash, and per-Card reversal facts reconstructed from generated reversal tenders. `line_id` is omitted. Completion recomputes stored `material_values` and `action_fingerprint` from those Core facts and refuses a mismatch. Stored reason name must match `PostVoidReasons`.

---

## 12. External Card confirmation

**Card** source tenders: exactly one confirmation row per source Card tender. Duplicate `source_tender_id` rows are refused before validation, fingerprinting, or persist. Confirmation means the reversal was performed outside ShelfSense, plus optional **new** `external_reference` on the reversal tender (not the original AUTH).

Check / Other: no extra confirmation policy. Cash: none.

---

## 13. Session / Z

Directional Core on the reversal still uses sale/return for economic sign. **Reporting queries filter:**

```text
Sales / Returns  = completed txns where post_void_of_transaction_id IS NULL
Post-void        = completed txns where post_void_of_transaction_id IS NOT NULL
Net              = all completed (includes post-void)
Tender payments/refunds = all (actual custody)
```

Signed post-void snapshots for a reversal transaction:

```text
merchandise = subtotal_cents - return_subtotal_cents
discount    = discount_cents - return_discount_cents
tax         = tax_cents - return_tax_cents
net         = signed_net_cents
```

Close/Z presents Sales, Returns, Post-void adjustments, Net.

---

## 14. Envelope v2 (no version bump)

```text
corrections.original_transaction_id
corrections.post_void_of_transaction_id
```

Lines: `post_void_source_line_id` when generated. Do **not** emit `original_transaction_line_id` or `return_reason` on generated lines. When the source line had a commercial discount or unit-price variance, emit the historical `discount` / `override` blocks from those copied cents. Do **not** copy `line_discount` / `price_override` / `tax_class_override` / `unlinked_return` into `controlled_actions[]`. Tenders: `post_void_source_tender_id` when generated. Keep rejecting `corrections.return_of_transaction_id`. Transaction-scoped `post_void` in `controlled_actions[]` omits `subject.line_id`.

Historical v2 envelopes without correction keys remain valid.

---

## 15. Receipt / history

History detail: **Post-void** only when eligible (fact-driven). Dedicated POST `/pos/transactions/:transaction_id/post_void`. Success → completion screen of the **new** transaction.

Source detail and reprint share `pos/receipts/_post_void_banner`: **POST-VOIDED**, then “This transaction has been post-voided and is no longer valid.” Screen also links “Post-voided by {reference}”. Hide Return items. Source snapshots stay unchanged; the banner is layered on top.

Reversal screen and receipt: **POST-VOID** of original reference (not RETURN); screen links the original. Generated return-direction lines are labeled as post-void reversal, not customer RETURN. Customer copy still omits unnecessary Card/Check references.

Closeout customer-print banners (top of paper, `Post-voided by:` on the printed original, no customer `RETURN` on generated lines) are [receipt-presentation.md](receipt-presentation.md) §§25–26 (implement in 6.8).

---

## 16. Audit

```text
pos.post_void.applied
pos.post_void.denied
inventory.post_void_posted
pos.transaction_completed   # on the reversal, existing completion audit
```

Executed `pos.post_void.applied` includes performer and approver identity alongside reason code. Never passwords or full tender dumps.

---

## 17. Delivery

### 6.6A — Engine

Schema, permissions, lease `command_type`, `PostVoidTransaction`, freeze, integrity, `PostPostVoid`, returnability, Session/Z snapshots, envelope. Merge gate: headless post-void of Cash Standard, Used, mixed tender, and mixed/return sources; linked-return eligibility sees post-voids; Z does not classify post-void as Returns; Phase 5 Cash sale unchanged.

### 6.6B — Operator

History form, approval, per-Card confirm, receipts, cross-links, Session/Z presentation. Merge gate: cashier-usable from history through print and close/Z.

Do not land schema without a completable engine.

---

## 18. Acceptance

1. A cashier can post-void a completed current-Store sale from history when eligible.
2. The source row is unchanged; the reversal is a new completed transaction with a new receipt on the current Register and current Session business date.
3. Generated lines use `post_void_source_line_id`, not `original_transaction_line_id`.
4. Generated return lines have no return reason.
5. Cannot post-void twice (unique + service).
6. Cannot post-void if an effective completed linked return exists against the source.
7. Cannot complete a linked return against a post-voided source.
8. Post-void of a mistaken linked return restores original sale returnability.
9. Inventory is the exact inverse of the source line’s ledger/valuation; later conflicting inventory refuses the post-void.
10. Card reversal confirmation is required per Card tender; original Card reference is not copied.
11. Check payments reverse as Check refunds without `allows_refund`.
12. Session/Z Sales and Returns exclude post-void transactions; post-void snapshots and net include them.
13. Already-finalized Z records remain unchanged.
14. Historical v2 envelopes still verify.
15. Phase 5 all-Cash Standard sale still behaves identically.

---

## 19. Out of 6.6

```text
partial post-void
post-void of a post-void
integrated Card / Stored Value
time windows / cross-Store
Check/Other reversal policy
cancelling foreign working baskets
keyboard map (6.7 — [pos-workflow.md](pos-workflow.md); no selling-surface post-void hotkey)
```
