# Phase 6 Slice 6.5 — Returns, refunds, and exchanges

**Status:** Contract locked. 6.5A implemented. 6.5B implemented. Next: 6.5C unlinked return.

**Authority:** Linked return, unlinked return, mixed sale+return, refund tenders, and direction-aware Session/Z on the existing POS transaction. Dual authority with Core remains [mvp-contract.md](mvp-contract.md) / [ADR-020](../../../adr/ADR-020-pos-operation-envelope-and-core-facts.md). Tax remains [pos-tax-contract.md](../phase4-point-of-sale/pos-tax-contract.md) §10. Inventory posting remains [inventory-posting-contract.md](../../phase3-inventory-foundation/inventory-posting-contract.md). Settlement extends [tender-breadth.md](tender-breadth.md). Controlled-action policy remains [controlled-actions.md](controlled-actions.md). History initiation extends [transaction-history.md](transaction-history.md).

Companions: [phase6-plan.md](phase6-plan.md), [phase4-schema.md](../phase4-point-of-sale/phase4-schema.md), [phase5-schema.md](../phase5-cash-register/phase5-schema.md), [register-workspace.md](../phase5-cash-register/register-workspace.md).

Draft [returns.md](../../../drafts/specifications/pos/returns.md) is vocabulary. This document is implementation authority for the MVP subset and **supersedes** that draft’s still-pending unlinked-policy questions for Phase 6. Offline returns stay out ([ADR-016](../../../adr/ADR-016-offline-returns.md) remains Proposed). Post-void is [6.6](phase6-plan.md).

### Actually locked

```text
one PosTransaction; no ReturnTransaction / RefundTransaction / Exchange
magnitudes positive; direction supplies economic sign
sale-side subtotal/discount/tax keep Phase 4–6.4 meaning
explicit return_* aggregates + persisted signed_net_cents
total_cents = abs(signed_net_cents)
do not persist or emit sale_total_cents
linked = historical reversal; never Tax::Calculate / recalc_extended!
unlinked = current POS rules; cashier-entered return unit price
unlinked_return creates the line (preallocated UUIDv7; not 6.4-on-a-sale-line)
differing unlinked price is commercial history, not a second controlled action
price_override / line_discount / tax_class_override are sale-direction only
customer refund price ≠ inventory carrying value
linked inventory restore uses original sale valuation (quantity and Used)
expected Cash = float + Cash payments − Cash refunds (may be negative)
signed_net > 0 payment only; < 0 refund only; = 0 no tenders (lines required)
working/cancelled returns do not consume eligibility
line original_transaction_line_id is linkage authority
no envelope corrections.return_of_transaction_id in 6.5
post-void conflict is 6.6
Phase 5 ordinary Cash sale unchanged when unused
```

---

## 1. Objective

Support three ordinary workflows on the existing POS transaction:

```text
linked return
unlinked return
mixed sale + return ("exchange")
```

without introducing `ReturnTransaction`, `RefundTransaction`, or `Exchange`.

```text
PosTransaction
├── sale line
├── return line
├── payment tender
└── refund tender
```

---

## 2. Scope

### In 6.5

**Linked:** initiate from 6.3 completed history; partial/full quantity; exact original `InventoryUnit`; remaining returnable quantity; exact historical price, discount, component-tax, and inventory-value reversal; concurrency at completion.

**Unlinked:** current known merchandise (quantity-tracked Standard, known removed Used unit, non-inventory); current POS reference price and Tax Class; cashier-entered return unit price (`>= 0`, may be above or below reference); one `unlinked_return` controlled action.

**Settlement:** Cash/Card/Check/configured Other refunds; mixed refund tender; mixed sale+return; payment when net positive; refund when net negative; no tender when net zero.

**Operational truth:** receipt, transaction history, expected Cash, Session close, Z, audit, v2 envelope.

### Explicitly out

```text
configurable return windows
merchandise return-policy configuration
customer-specific return policy
gift receipts
cross-Store linked returns
unknown Used intake
buyback
Store Credit / Stored Value
integrated Card refunds
proportional refund-to-original-tenders policy
mandatory original-tender matching
percentage return-price adjustment
separate return_price_adjustment controlled action
return disposition
damaged/quarantine/RTV workflow
transaction-wide discount reversal
promotion clawback
Cash refund ≤ expected Cash as a physical drawer cap
post-void
offline returns
```

---

## 3. Directional totals

Do **not** redefine legacy `subtotal_cents`, `tax_cents`, or `total_cents` into mixed-return fields. `total_cents` remains an unsigned settlement magnitude.

### Existing sale-side fields (unchanged meaning)

```text
subtotal_cents   = SUM(sale-direction extended selling)
discount_cents   = SUM(sale-direction manual_discount_cents)
tax_cents        = SUM(sale-direction line_tax_cents)
```

Sale-only transactions keep today’s identity.

### New Core fields

```text
return_subtotal_cents
return_discount_cents
return_tax_cents
return_total_cents
signed_net_cents
```

Do **not** persist `sale_total_cents`. Do **not** emit it on the envelope. Derive it in presentation:

```text
sale_total           = subtotal_cents - discount_cents + tax_cents
return_total_cents   = return_subtotal_cents - return_discount_cents + return_tax_cents
signed_net_cents     = sale_total - return_total_cents
                     = SUM(sale line_total) - SUM(return line_total)
total_cents          = abs(signed_net_cents)
```

`return_discount_cents` is Σ allocated **historical sale-line** `manual_discount_cents` on linked returns. Unlinked price variance is **not** a discount and does not enter this field.

Examples: sale $30 + return $20 → `signed_net = +10`, `total = 10`. Return-only $20 → `signed_net = -20`, `total = 20`. Even exchange → both `0`.

### CHECKs

```text
return_* >= 0
return_total_cents = return_subtotal_cents - return_discount_cents + return_tax_cents
signed_net_cents = (subtotal_cents - discount_cents + tax_cents) - return_total_cents
total_cents = abs(signed_net_cents)
```

Do **not** add these columns to `pos_transactions_status_null_rules`. Working rows carry zeros.

Existing-row backfill:

```text
return_*     = 0
signed_net   = total_cents
```

`Pos::Support.refresh_totals!` becomes directional aggregation (sale vs return lines). It is a major invariant boundary and requires dedicated golden tests.

Empty basket `total = 0` is still **not** completion-pending. Even exchange is mixed sale + return with `signed_net = 0` and no tenders. Sale-only or return-only zero-net retains prior completion-pending / auto-complete.

---

## 4. Return-line schema

Expand `PosTransactionLine::DIRECTIONS` and the DB CHECK from `sale` to `sale | return`.

Add:

```text
original_transaction_line_id                 uuid nullable  # self-FK
return_reason_code                           string nullable
return_reason_name_snapshot                  string nullable
return_reason_note                           text nullable
```

Do **not** add `return_price_adjustment_basis_points` or `return_price_adjustment_cents`. Unlinked commercial value is `reference_unit_price_cents` vs `selling_unit_price_cents`.

Index `original_transaction_line_id`. Unique:

```text
UNIQUE (pos_transaction_id, original_transaction_line_id)
WHERE original_transaction_line_id IS NOT NULL
```

One current transaction has at most one linked-return line against a given original line. Quantity change edits that line; do not add a second line for the same original.

```text
direction = sale
  → original_transaction_line_id NULL
  → no return reason

direction = return + original_transaction_line_id
  → linked

direction = return + original_transaction_line_id NULL
  → unlinked
```

No separate `linked` boolean.

### Useful local CHECKs

```text
direction IN ('sale', 'return')

original_transaction_line_id IS NOT NULL
  → direction = 'return'

direction = 'sale'
  → original_transaction_line_id IS NULL
  → return_reason_code IS NULL
  → return_reason_name_snapshot IS NULL
  → return_reason_note IS NULL

direction = 'return'
  → return_reason_code IS NOT NULL
  → return_reason_name_snapshot IS NOT NULL
```

Leave relational rules to services and completion verification (original is a completed sale line in this Store, remaining quantity, linked tax is historical, unlinked has `unlinked_return` fact). Those require joins or current state and do not belong in a local CHECK.

Unlinked lines have `manual_discount_cents = 0`. Linked lines may carry allocated historical discount cents.

---

## 5. Return reason

Code-defined line-level catalog (not a policy framework):

```text
changed_mind
defective
wrong_item
duplicate_purchase
other
```

Required for linked and unlinked. `other` requires a note (max 200). Snapshot `return_reason_code` and `return_reason_name_snapshot`.

This same `return_reason_code` is the only reason on an unlinked request (material to the `unlinked_return` fingerprint). Do **not** ask for a second adjustment reason.

---

## 6. Linked returns

Preferred ordinary path. The original **completed sale line** is authoritative. Do not evaluate current Product status, regular price, Tax Class, Store Tax rate, merchandise condition, or discount policy.

### Eligibility

```text
remaining_returnable_quantity
  = original quantity
  − SUM(completed linked-return quantities of that original line)
```

Only **completed** return transactions count. Working and cancelled do not.

Individual: original quantity = 1; remaining is 0 or 1.

Original must belong to the **current Store**. Cross-Store is out. Original Register/cashier may differ. Return `business_date` is the current Session’s date (new-period facts).

Cannot return a return line. `original_transaction_line_id` points at sale-direction lines only.

**Post-void (6.6):** 6.5 eligibility does not yet see post-voids. 6.6 will refuse post-void if a completed linked return exists, and refuse a linked return against a post-voided original.

Discontinued merchandise remains returnable.

---

## 7. Linked concurrency

No reservation/claim table.

At line creation: remaining quantity is provisional UX validation.

At **completion**:

1. collect referenced original sale line IDs
2. sort deterministically by id
3. `FOR UPDATE` those original lines
4. recompute completed returned quantity
5. reject if this return exceeds the remainder
6. continue

Register A and B may both prepare the final quantity. A completes; B waits, then fails cleanly.

Lock `InventoryUnit` inside `Inventory::PostReturn`, not before freeze — same as 6.1 sale (`CompleteTransaction` must not hold the unit lock before posting).

Canonical lock order when these resources are acquired together:

```text
PosTransaction
  → original PosTransactionLines (id order)
  → InventoryBalance
  → InventoryUnit
```

Session only where existing open/close/complete lifecycle already requires it. Do not add a Session lock merely for Cash-refund capacity (there is no such rule in 6.5). Test: two Registers racing the last linked quantity; linked Used vs another unit operation; completion vs Session close where applicable.

---

## 8. Linked financial reversal

Reverse **what actually happened**.

```text
reference_unit_price_cents        ← original reference
selling_unit_price_cents          ← original selling
extended_selling_amount_cents     = original selling × returned quantity
manual_discount_basis_points      ← original rate when present
manual_discount_cents             ← allocated historical cents
net_merchandise_amount_cents      = extended − allocated discount
line_tax_cents                    ← allocated historical tax
line_total_cents                  = net + tax
```

Copy default/applied Tax Class IDs and **available** snapshots from the original. Do **not** populate missing historical names from live `TaxClass` rows.

Do **not** create `price_override` / `line_discount` / `tax_class_override` rows on the return. Those approvals authorized the original sale. History can navigate to the original transaction.

Envelope `override` / `discount` blocks **may** describe historical commercial values on a linked return; they do not imply new controlled actions.

---

## 9. Deterministic partial-return cents

One service: `Pos::HistoricalReturnAllocation`.

Amounts that may not divide evenly:

```text
original manual_discount_cents
each original tax component tax_cents
each original tax component taxable_basis_cents
original inventory value relieved
```

```text
if current return consumes all remaining quantity:
    allocation = all remaining historical cents
else:
    allocation = ROUND_HALF_UP(original × current_qty / original_qty)
    capped at remaining historical cents
```

After the original quantity is fully returned:

```text
Σ reversed discount = original discount
Σ reversed tax      = original tax
Σ restored cost     = original cost relieved
```

Do not simplify this for MVP. Repeated partial returns must not lose or create pennies.

---

## 10. Do not use sale-line recalculation on linked returns

`PosTransactionLine#recalc_extended!` recomputes discount from basis points. `Pos::Support.apply_provisional_tax!` always calls current `Pos::Tax::Calculate`.

Linked returns **persist allocated cents** and must never call those sale formulas. Working display uses the same allocation so the cashier sees truthful refund amounts before complete.

6.4 “quantity blocked on override/discount lines” applies to **sale** lines only. Linked returns may `ChangeQuantity` (re-run allocation; cap at remaining, provisionally). Unlinked returns cannot change quantity (fingerprint includes quantity).

---

## 11. Historical tax reversal

Linked return must **not** call `Pos::Tax::Calculate`.

```text
sale                → current Pos::Tax::Calculate
unlinked return     → current Pos::Tax::Calculate
                      on the authorized return unit price
linked return       → historical component allocation
                      NEVER Pos::Tax::Calculate
```

Copy original component identity (`store_tax_id`, code/name snapshots, `rate_percent`, `applies`, `calculation_order`) and allocate `taxable_basis_cents` / `tax_cents`. Include `applies = false` rows (typically zeros).

Do not share one “recalculate tax” helper for historical reversal and current determination without an explicit mode.

---

## 12. Linked inventory restoration

Named boundary `Inventory::PostReturn`, parallel to `Inventory::PostSale`. Joins the caller’s transaction. Do not call `PostAdjustment`. Lock order: `InventoryBalance` then `InventoryUnit`. Skip `non_inventory`. Duplicate protection remains `(source_type, source_id, effect_sequence)` with `source_type = PosTransactionLine` and `source_id =` **return** line id.

Ledger `entry_type = return`. Valuation increase uses `acquisition` (stock in). Outbox/audit `inventory.return_posted`.

**Every linked return restores inventory using the valuation actually relieved by the original completed sale.** Do not use today’s moving average. Do not treat live `InventoryUnit.carrying_value_cents` as historical authority.

| Return type | Inventory valuation authority |
|---|---|
| Linked quantity | original sale valuation (allocate relieved value) |
| Linked individual | original sale valuation (`value_delta_cents` magnitude) |
| Unlinked quantity | current / last-defensible moving average (§15) |
| Unlinked individual | known unit’s carrying value |

**Quantity tracked:** original completed sale valuation is authoritative (`source_type = PosTransactionLine`, `source_id = original sale line`, depletion `value_delta_cents` magnitude). Allocate that relieved value via `HistoricalReturnAllocation`. `quantity_delta = +returned quantity`.

**Individual:** require original unit id, `lifecycle_state = removed`, variant and Store match. Restore using the original sale’s relieved cents. Set the unit `on_hand`, `removed_at = NULL`, and **write `carrying_value_cents` to that restored amount** so ledger and live unit cannot diverge. A consistency check against the current carrying value is allowed; if they differ, sale valuation wins.

**Non-inventory:** no ledger, valuation, or balance effects.

---

## 13. Unlinked return

Valued under **current** POS rules. It does not claim those were the original historical facts.

```text
current resolved merchandise identity
        ↓
current resolved reference unit price
        ↓
cashier-entered return unit price  (>= 0; may be above or below reference)
        ↓
current Tax Class (no unlinked Tax Class override in 6.5)
        ↓
current Store Tax calculation on the authorized return price
        ↓
return-direction line
```

Never sets `original_transaction_line_id`. Never claims historical price/tax/tender linkage.

Does **not** require the variant to be currently sellable. Does require enough current configuration for identity, reference price, Tax Class, and tax treatment. Missing regular price → reject.

```text
reference_unit_price_cents = current resolved regular / default return basis
selling_unit_price_cents   = authorized return unit price
manual_discount_cents      = 0
```

---

## 14. Unlinked merchandise breadth

**Standard quantity:** resolve known merchandise with current identifier rules. Quantity is chosen when the controlled action is created.

**Used / individual:** existing known `InventoryUnit` with `lifecycle_state = removed` and Store = current Store. Unknown identifier → reject (intake/buyback, not a return). Do not create a new unit. Quantity = 1.

**Non-inventory:** financial return only.

Unlinked lines do **not** merge on rescan (quantity and requested price are authorized). Two unlinked lines of the same variant are separate authorized facts — especially when reason or return price differs.

---

## 15. Unlinked inventory valuation

Customer refund price has **no** effect on inventory carrying value. A small `Inventory::ReturnValuation` helper is enough; do not build a generalized revaluation framework.

**Individual:** restore the known removed unit at its existing `carrying_value_cents`.

**Quantity tracked, on-hand > 0** — proportional current MA, not unit-cost-then-multiply:

```text
incoming_value_cents
  = ROUND_HALF_UP(
      current inventory_value_cents
      × returned_quantity
      / current on_hand_quantity
    )
```

Example: 3 units worth $1.00, return 2 → `ROUND_HALF_UP(100 × 2 / 3) = 67¢`.

**Quantity tracked, on-hand = 0** — inspect only the **latest** `InventoryValuationEntry` for that store+variant (do not walk arbitrarily older rows):

```text
latest InventoryValuationEntry for (store, variant)
if calculation_metadata.prior_quantity > 0
  incoming_value_cents
    = ROUND_HALF_UP(prior_value_cents × returned_quantity / prior_quantity)
else
  reject
```

`PostSale` already stores `prior_quantity` / `prior_value_cents`. If that latest entry has no positive prior quantity, there is no immediately preceding defensible MA.

**No defensible basis:** reject the unlinked inventory return. Do not create zero-cost stock.

---

## 16. Unlinked return is one controlled action

Seed only:

```text
pos.unlinked_return.perform
pos.unlinked_return.approve
```

Do **not** seed `pos.return_price_adjustment.perform` / `.approve` in 6.5. Those identifiers remain reserved in [mvp-contract.md](mvp-contract.md) §11 for a later policy model if operational experience needs authorization separate from allowing the unlinked return itself. `post_void` remains reserved, not seeded.

`scope_type: either`. Same `phase6_permission_tier_v1` (`direct` / `approval_required` / `prohibited`). No policy table. No pending approval rows.

| Role | Perform | Approve |
|---|---|---|
| Associate | Yes | No |
| Store manager | Yes | Yes |
| System administrator | Yes | Yes |

The requested return unit price is part of this **single** request. A differing price is not a second manager-approval action.

`pos_controlled_actions.pos_transaction_line_id` stays **NOT NULL** for 6.5 (still line-scoped). Dropping that CHECK is 6.6 (`post_void`). Expand `action_type` to include `unlinked_return` only (not `return_price_adjustment`).

---

## 17. Unlinked return creates the line

[`Pos::ExecuteControlledAction`](../../../../app/services/pos/execute_controlled_action.rb) mutates an existing **sale** line. Unlinked return **creates** the return line plus the `unlinked_return` fact in one command (`Pos::ExecuteUnlinkedReturn`). Do not build a generic “prospective subject” framework.

Because `pos_transaction_line_id` is NOT NULL, allocate the future line UUID **before** authorization. Do not persist a temporary/pending line while waiting for manager credentials.

```text
ExecuteUnlinkedReturn

1. generate prospective UUIDv7 line_id
2. resolve exact requested merchandise / pricing / tax facts
3. build fingerprint using that line_id
4. evaluate performer policy
5. authenticate approver if required
6. BEGIN transaction
7. create PosTransactionLine using the preallocated line_id
8. create PosControlledAction against that same line_id
9. calculate tax / totals
10. COMMIT
```

If authorization fails, discard the unused UUID. Never insert the line.

Quantity and requested return price are in the fingerprint and **cannot be edited** afterward. Wrong qty or price → remove line, recreate. F8 remove is **direct** (same as sale-line remove); audit `pos.unlinked_return.removed`.

### Fingerprint material (`unlinked_return`)

```text
action_type = unlinked_return
transaction_id
prospective line_id

product_variant_id
inventory_unit_id                 # individual only
quantity

reference_unit_price_cents
requested_return_unit_price_cents

tax_class_id                      # current applied class; no unlinked Tax Class override

return_reason_code
return_reason_note                # iff other
```

Approval for qty 1 / $24 reference / $18 return / defective does not authorize qty 2 / $15 / a different reason.

### Overlay

Visible control: **Return without receipt**. No permanent F-key until 6.7.

One overlay, one submit (identifier already resolved, or resolved in step 1):

1. Scan / enter identifier → resolve and show current reference (scanner Enter here must not authorize)
2. Quantity / return reason / return unit price / approver when required → Add return

Default the return unit price to the current reference. The cashier may change it. Used: scan exact unit; quantity 1.

If policy is `approval_required`, the approver must hold `pos.unlinked_return.approve`.

---

## 18. Return price as a commercial fact

Unlinked only. Distinct from sale price override and sale discount.

When `selling_unit_price_cents != reference_unit_price_cents`, a return-price adjustment **occurred**. Persist that only as Core reference vs selling (and envelope explanation). Do not add a second `pos_controlled_actions` row.

```text
requested_return_unit_price_cents >= 0
```

Above-reference is allowed. Authorization, not the financial model, controls whether that is acceptable. $0.00 is allowed (zero-value merchandise return).

Derived (do not persist as Core columns):

```text
unit_variance_cents = selling_unit_price_cents - reference_unit_price_cents
line_variance_cents = unit_variance_cents × quantity
```

`price_overridden?` / `manually_discounted?` remain **sale-direction** helpers. UI **and services** must reject `price_override`, `line_discount`, and `tax_class_override` on return lines.

Envelope (omit when selling = reference):

```text
return_price_adjustment:
  reference_unit_price_cents
  resulting_unit_price_cents
  unit_variance_cents
  line_variance_cents
```

---

## 19. 6.4 completion integrity (direction-aware)

```text
sale line
  → ordinary 6.4 price / discount / Tax Class controls
  → existing Core ↔ price_override / line_discount / tax_class_override

linked return
  → historical facts only
  → no new 6.4 controls
  → no 6.4 sale controlled-action rows

unlinked return
  → current reference price / current Tax Class
  → unlinked_return row required
  → requested return price may differ from reference
  → that difference is not a sale price_override or line_discount
```

---

## 20. Refund-capable TenderTypes

Add `tender_types.allows_refund boolean NOT NULL default false`.

```text
Cash           true   (cannot be disabled: CHECK code = 'cash' → allows_refund)
External Card  true
Check          false
Other          false
```

Admin may enable/disable refund for Card/Check/Other while the type is active. Any active configured tender with `allows_refund = true` may settle a refund. Refund need **not** match the original tender.

No original-tender matching, proportional original reversal, refund priority, dollar thresholds, alternate-refund approvals, or customer-specific refund policy.

**When the flag is evaluated:**

```text
AddRefundTender
  → validate live active + allows_refund at creation

once the working tender exists
  → snapshots remain valid
  → later admin config change does not retroactively invalidate it
```

Completion validates the stored tender row and settlement, not today’s live `allows_refund`.

---

## 21. Refund tender rows

Expand `PosTender::DIRECTIONS` and CHECK `pos_tenders_direction_valid` to `payment | refund`.

**Cash payment:** unchanged (presented, applied, change). Today’s `cash_presented_matches_applied` applies to **payment** only.

**Cash refund:** `amount_cents`, `direction = refund`, `amount_presented_cents` and `change_cents` NULL.

**Card/Check/Other refund:** `amount_cents`, `direction = refund`, external reference per TenderType policy. External Card remains a recording (no processor).

Keep one Cash **payment** row. Add the same uniqueness for one Cash **refund** row (`WHERE behavioral_category = 'cash' AND direction = 'refund'`).

Keep `TenderCash` / `AddTender` for payments. Add `AddRefundTender`. `RemoveWorkingTender` stays generic. Do not turn payment services into one bidirectional tender engine unless a small internal helper falls out naturally. Public domain commands stay distinct.

Basket mutation still clears **all** working tenders.

---

## 22. Settlement

At completion:

```text
signed_net > 0  → payment tenders only; SUM(payment) = signed_net
signed_net < 0  → refund tenders only; SUM(refund) = abs(signed_net)
signed_net = 0  → no tenders
```

Never complete with both payment and refund tenders. An exchange is net-settled.

`Pos::Support.exact_settlement?` and remaining-due must use `signed_net` and tender `direction`. Workspace: net > 0 → payment tender; net < 0 → refund tender; mixed sale+return with net = 0 → stay in `SALE_ENTRY` (no tender) so more sale lines can be added; `+` confirms the even exchange and completes. Sale-only or return-only `signed_net = 0` remains completion-pending with auto-complete. Auto-complete is for exact payment/refund settlement and non-mixed zero-net, not mixed even exchange.

---

## 23. Expected Cash

```text
expected Cash
  = opening float
  + completed Cash payments
  − completed Cash refunds
```

This Session only. Working/cancelled tenders contribute nothing.

Expected Cash is an **accounting expectation**, not a physical drawer count. **Do not** refuse a Cash refund because it would make expected Cash negative. Do not use expected Cash as drawer-capacity, safe, drop, or manager-override policy. Those belong with a later physical cash-custody model.

If a Cash refund would take expected below zero, the workspace **may show a non-blocking warning**. It must not refuse, require a second actor, or take a Session lock for capacity.

Phase 5 assumed `closing_expected_cash_cents >= 0` and a nonnegative Z expected-sum CHECK. 6.5A dropped those CHECKs so expected (and the Z expected sum) may be negative. `closing_count_cents` stays `>= 0`. Variance remains `count - expected` and may be more positive when expected is negative.

---

## 24. Completion command and freeze

Add required `expected_signed_net_cents` to `CompleteTransaction.command_payload` (sale-only: equals `expected_total_cents`). Idempotency hash includes both. `expected_total_cents` alone cannot distinguish customer-owes-$20 from customer-receives-$20.

Split freeze:

```text
Pos::FreezeSaleLine
Pos::FreezeLinkedReturnLine     # never Tax::Calculate
Pos::FreezeUnlinkedReturnLine   # current Tax::Calculate on authorized return price
```

---

## 25. History initiation (6.5B)

6.3 history is the linked-return entry point. On original detail, each sale line shows qty sold / returned / remaining. Eligible lines can be selected.

```text
completed history
  → Return items
  → select quantities + return reason
  → Add to register
  → current cashier’s working transaction
  → workspace
```

Individual: checkbox / Return; quantity fixed 1; show unit identifier.

No open POS Session → do **not** create one. Show: `Open a register before processing a return.` History itself remains usable without a Session.

If a working transaction already exists on the bound Register Session, add return lines to it. Sale + linked return in the same basket is cashier-operable in 6.5B.

GET history and GET Return items never open a Session, start a transaction, rebind `session[:pos_register_id]`, or reserve quantity. POST is the first allowed side effect. Resolve the selected items first (nothing selected never touches Core). Then `ResumeOrStartTransaction` and `AddLinkedReturnLines` run in one outer database transaction so a failed add does not leave an empty working transaction. Submitted `original_line_id`s must belong to the receipt in the URL.

---

## 26. Mixed sale + return

Sale lines and linked/unlinked return lines remain one working transaction. No Exchange object. Lines may be removed before completion. Any material basket mutation clears working tenders.

---

## 27. Receipt

6.5 must be truthful (6.7 may polish presentation).

```text
Example Book                 $20.00
RETURN Example Book         -$15.00
```

Linked: `Return from S001-R01-T000123`. Unlinked, when return price ≠ reference: show reference, authorized return unit price, and variance.

Totals keep directional presentation and tax visibility. Omit a direction that has no lines:

```text
Sales subtotal / Sales discount / Sales tax / Sales total
Return subtotal / Discount reversal / Tax reversal / Returns total
Net
```

Then payment **or** refund tenders — never a misleading positive `$20 Total` on a return-only receipt without identifying it as a refund.

---

## 28. History display

List shows **signed** commercial result (`+$25.00` / `-$20.00` / `$0.00`), not merely unsigned `total_cents`.

Detail: sale subtotal/discount/tax/total; return subtotal/discount reversal/tax reversal/total; net. Return lines: linked (original receipt + line) or `Unlinked return`; reason; return-price variance when selling ≠ reference; unit identifier when applicable. Original sale detail also shows completed returns against each line.

---

## 29. Session / Z

Must ship with the first completable return.

Keep existing finalized **sale-side** fields. For 6.5+ finalized periods, `finalized_total_cents` is the **sale-direction customer total** (what it meant before returns). Do not `SUM(transaction.total_cents)` across mixed/return rows as sales.

Add (NULL on pre-6.5 finalized = not captured; new finalize writes `0` when no activity). Do **not** add them to `closed_at_matches_status`:

```text
finalized_return_subtotal_cents
finalized_return_discount_cents
finalized_return_tax_cents
finalized_return_total_cents
finalized_net_cents                 # signed
finalized_cash_refund_cents
finalized_card_refund_cents
finalized_check_refund_cents
finalized_other_refund_cents
```

Minimum close/Z presentation: Sales total, Returns, Net; Cash/Card/Check/Other payments and refunds. Expected Cash remains the sum of Session snapshots, now including refunds, and **may be negative**.

---

## 30. Envelope v2 (no schema_version bump)

New 6.5 completions include directional transaction keys (`return_*`, `signed_net_cents`). Do **not** emit `sale_total_cents`. Return lines add `direction = return`, `original_transaction_line_id` when linked, `return_reason`, and `return_price_adjustment` when unlinked selling ≠ reference.

Tender `direction = refund` omits presented/change.

Do **not** set `corrections.return_of_transaction_id` in 6.5. Line `original_transaction_line_id` is the authority (one receipt, several receipts, mixed linked/unlinked, mixed sale+return). Transaction-level correction linkage waits for 6.6 `post_void_of_transaction_id`.

Pre-6.5 v2 envelopes remain valid without return keys. If return keys are present, they must be well-formed.

---

## 31. Audit

```text
pos.linked_return.added | removed
pos.unlinked_return.applied | removed
inventory.return_posted
```

Unlinked uses the existing 6.4 performer/approver structure (reason, requested return price, reference). Do not emit a separate `pos.return_price_adjustment.*` stream in 6.5. Inventory audit: current return line, original sale line when linked, quantity, unit, value restored, linked/unlinked valuation basis. Never passwords.

---

## 32. Delivery

Do not land a foundation-only PR. Rollout: `db:migrate` plus `shelfsense:seed_permissions` (6.5C seeds the two `unlinked_return` keys; 6.5A may migrate Core without those keys if unlinked is not yet callable).

### 6.5A — Directional Core + linked return engine

Directional totals; return lines/linkage; return reasons; `HistoricalReturnAllocation`; returnability/concurrency; `Inventory::PostReturn`; linked-return completion; refund-direction tender Core; settlement; `expected_signed_net_cents`; direction-aware Session/Z **calculations**; expected-Cash CHECKs that allow negative; lock-order tests.

May be headless. Merge gate: a linked quantity (and Used) return can complete in tests with truthful Core, envelope, inventory restore, expected Cash, and Z math. Phase 5 all-Cash sale still identical.

Implementation notes: dropped `pos_sessions_closing_expected_nonnegative` and `pos_reporting_periods_finalized_closing_expected_sum_nonnegativ` so expected Cash (and the Z expected sum) may be negative. Cash `allows_refund` is protected by `tender_types_cash_allows_refund`.

### 6.5B — Linked-return operator workflow

History remaining quantity; Return items; basket return lines; partial quantity; Used-unit linked return; return receipt; return history/detail; refund tender workspace. Sale + linked return may share one working basket.

**Implemented.** Merge gate: cashier-usable linked return from history through refund, receipt, and visible Session/Z.

Implementation notes:

- `cashier_target_session` is shared by Register resume and Return items. GET history / GET Return items never create a Session, working transaction, or register binding.
- Return items POST resolves selected items first (nothing selected never touches Core), scopes `original_line_id`s to the receipt in the URL, then runs `ResumeOrStartTransaction` and `AddLinkedReturnLines` in one outer database transaction. A failed add does not leave an empty working transaction.
- `AddLinkedReturnLines` is the atomic batch; `AddLinkedReturnLine` is a one-item wrapper. Duplicate originals, remaining quantity, tenders cleared once, totals refreshed once.
- `PosTransaction#even_exchange?` is mixed sale + return with `signed_net = 0`. Sale-only or return-only zero-net retains 6.4C completion-pending / auto-complete and is not labeled Even exchange.
- Customer print, immediate completion, and history detail share directional totals with tax (`pos/receipts/_directional_totals`). Omit a direction that has no lines.
- F5/F6/F7 are disabled for return lines. Stimulus quantity uses `data-linked-return` so a future unlinked return is not treated as quantity-editable in JS. `ChangeQuantity` already rejects unlinked quantity changes.
- Cancel overlay copy is transaction-generic. Completion-retry copy is tender-generic.

### 6.5C — Unlinked return

**Next.** `unlinked_return` permissions; `ExecuteUnlinkedReturn`; prospective line UUID; current-rule price/tax; cashier-entered return unit price; known removed Used unit; unlinked quantity valuation; single approval overlay; history/audit/envelope. No separate RPA permission framework.

Do not redo 6.5B workspace settlement, even-exchange hold-open, directional receipts, or Return items. 6.5C adds the unlinked command and its permission keys. `Inventory::PostReturn` currently requires a linked return line; this slice must extend it with the unlinked valuation rules in §15. `pos.unlinked_return.perform` / `.approve` are not seeded yet. `FreezeUnlinkedReturnLine` is specified in §24 and is not yet callable.

### 6.5D — Mixed transaction and closeout hardening

Comprehensive mixed/unlinked/closeout hardening: sale + unlinked; net positive/negative/zero with unlinked; mixed refund tender; Session close; Z finalize; receipt/reprint; concurrency; completion retry/idempotency; full Phase 5–6.4 regression. Sale + linked return is already cashier-operable in 6.5B. No new domain model.

---

## 33. Acceptance

1. A cashier can initiate a linked return from a completed transaction belonging to the current Store.
2. Another cashier at that Store may process the return.
3. Partial linked returns cannot exceed the completed remaining quantity.
4. Two Registers racing for the final quantity cannot both complete it.
5. Working/cancelled returns do not consume historical returnability.
6. A linked return reverses historical selling price, discount cents, and tax components rather than current configuration.
7. Full return after multiple partial returns reverses the original cents exactly.
8. A linked quantity return restores the original inventory value relieved.
9. A linked Used return restores the exact original `InventoryUnit` using the original sale valuation.
10. Non-inventory returns create no physical or valuation entries.
11. An unlinked return uses current reference price and current tax without claiming historical linkage.
12. Unlinked Used requires a known removed unit; unknown units are rejected.
13. Unlinked return requires the controlled-action permission tier.
14. An unlinked return begins at the current resolved reference price and may use an explicitly entered return unit price. A differing return price is preserved as a first-class commercial adjustment but is authorized as part of the single `unlinked_return` controlled action, not as a separate sale price override or discount.
15. `signed_net > 0` completes with exact payment tenders.
16. `signed_net < 0` completes with exact refund tenders.
17. Mixed sale+return with `signed_net = 0` completes with no tender after the cashier confirms with `+`. Sale-only or return-only zero-net auto-completes with no tender and is not labeled Even exchange.
18. Cash refunds reduce expected Cash using `opening float + Cash payments − Cash refunds`; expected Cash reflects accounting facts and is not used as a physical drawer-capacity control in the MVP.
19. Card refund is externally processed and merely recorded by ShelfSense.
20. Session/Z reports sales, returns, net, payments, and refunds directionally.
21. Already-finalized pre-6.5 Z records remain unchanged.
22. Historical v2 envelopes still verify.
23. Phase 5 all-Cash Standard sale still behaves identically.
24. 6.1 Used/non-inventory, 6.2 mixed tender, 6.3 history/reprint, and 6.4 controlled-sale actions remain green.

---

## 34. Out of 6.5

```text
post-void
offline returns
Store Credit / integrated Card
return windows / merchandise exclusions
unknown Used intake / buyback
cross-Store linked returns
return disposition / RTV
transaction-wide discount / promotion clawback
percentage return-price adjustment
separate return_price_adjustment perform/approve
Cash refund as physical drawer-capacity control
keyboard map lock (6.7)
```
