# Phase 6 Slice 6.0 — MVP completed-operation contract

**Status:** Locked. Planning/contract only. No schema migration in this slice.

**Authority:** Cross-cutting completed-operation shape for the Phase 6 MVP. Dual authority with normalized Core remains [ADR-020](../../../adr/ADR-020-pos-operation-envelope-and-core-facts.md) / [operation-and-core-facts.md](../phase4-point-of-sale/operation-and-core-facts.md). Commercial base is [CompletedPosOperation v1](../phase4-point-of-sale/completed-pos-operation-v1.md).

Companions: [phase6-plan.md](phase6-plan.md), [merchandise-breadth.md](merchandise-breadth.md), [tender-breadth.md](tender-breadth.md), [transaction-history.md](transaction-history.md), [controlled-actions.md](controlled-actions.md), [returns.md](returns.md). Tax: [pos-tax-contract.md](../phase4-point-of-sale/pos-tax-contract.md). Cash/Z: [phase5-plan.md](../phase5-cash-register/phase5-plan.md).

This slice does **not** implement capabilities. It locks meaning so 6.1–6.7 do not each invent a new completion shape. Do not add unused Core columns here ([AGENTS.md](../../../../AGENTS.md) §10). Columns appear in the owning slice.

No new ADR. Envelope versioning already fits ADR-020.

---

## 1. Objective

Make sure the Phase 4 completion architecture can represent everything the MVP adds:

```text
line
  direction
  product_variant
  inventory_unit
  reference price
  selling price
  override
  discount
  return price adjustment
  applied Tax Class
  tax components
  original sale line (return)
```

tender
  tender type
  behavioral category
  direction
  amount applied
  presented / change where Cash
  external reference where applicable

controlled actions
  action
  performer
  approver
  reason
  policy context

correction relationships
  return source
  post-void source
```

`line_type` is **not** required for this MVP. All Phase 6 MVP lines are merchandise (`product_variant_id` present). Open ring stays deferred; do not add a placeholder `line_type` column until that capability exists.

---

## 2. Versioning

```text
schema_version: 1   # envelopes already written (Phase 4/5)
schema_version: 2   # all new completions once 6.1 ships v2 construction
```

Existing stored envelopes stay v1. Material semantic changes (sign rules, tax rate scale, identity fields) already required a new version in v1; v2 is that additive commercial expansion.

Once 6.1 ships v2 construction, **every new** completion is v2 — including ordinary quantity-tracked Cash sales. Unused v2 keys are **omitted**, not null-padded.

Additive keys may appear in later compatible versions. Do not silently reinterpret a v1 field.

Envelope and Core must still match and be written atomically. No required commercial behavior may depend on parsing the stored envelope.

---

## 3. Conceptual envelope shape (v2)

v1 fields remain. v2 adds optional keys on lines, tenders, transaction, and correction/control blocks. Illustrative; Core column names follow the owning slice.

```text
CompletedPosOperation
│
├── schema_version                    # 2
│
├── operation
│   ├── operation_id
│   └── fact_type                     # pos.transaction_completed
│                                     # (later: a post-void completion uses the same
│                                     #  commercial fact_type; relationship lives on
│                                     #  the correction block, not a second envelope type)
│
├── origin                            # v1 + additive 6.3 name
│   ├── (v1 origin ids)
│   └── performed_by_name             # omit when absent; 6.3
├── receipt                           # v1; still assigned only at completion
│
├── transaction
│   ├── transaction_id
│   ├── currency_code
│   ├── occurred_at
│   ├── business_date
│   ├── subtotal_cents                # unsigned sale-side; §5 / [returns.md](returns.md)
│   ├── discount_cents                # unsigned; Σ sale-direction manual line discounts; 6.4
│   ├── tax_cents                     # unsigned sale-side; §5 / [returns.md](returns.md)
│   ├── return_subtotal_cents         # 6.5; omit on pre-6.5 envelopes
│   ├── return_discount_cents         # 6.5
│   ├── return_tax_cents              # 6.5
│   ├── return_total_cents            # 6.5
│   ├── total_cents                   # unsigned settlement amount = abs(signed_net)
│   └── signed_net_cents              # signed; persisted in 6.5 Core
│
├── lines[]
│   ├── (v1 line fields)
│   ├── inventory_unit_id             # omit when absent
│   ├── merchandise_snapshot          # v1 keys plus unit keys when present (§6)
│   ├── override                      # omit when none; 6.4
│   ├── discount                      # omit when none; 6.4
│   ├── return_price_adjustment       # omit when none; unlinked return; 6.5
│   ├── original_transaction_line_id  # omit when not a linked return; 6.5
│   ├── return_reason                 # 6.5; required on return lines
│   └── tax_components[]              # v1 Store Tax determinations
│
├── tenders[]
│   ├── tender_id
│   ├── tender_number                 # dense 1..N; 6.2
│   ├── tender_type                   # identity code snapshot
│   ├── tender_name                   # display-name snapshot; 6.2
│   ├── behavioral_category           # cash | card | check | other; 6.2
│   ├── direction                     # payment | refund
│   ├── amount_cents                  # applied; positive magnitude
│   ├── amount_presented_cents        # Cash payment only; omit otherwise
│   ├── change_cents                  # Cash payment only; omit otherwise
│   └── external_reference            # omit when not captured
│
├── controlled_actions[]              # omit when empty; executed facts only; 6.4
│   ├── action
│   ├── subject.line_id
│   ├── performed_by_user_id / performed_by_name
│   ├── approved_by_user_id / approved_by_name  # omit when direct
│   ├── reason.code / reason.name (/ note when other)
│   ├── policy_context.result / version
│   ├── material_values
│   ├── fingerprint
│   └── executed_at
│
└── corrections                       # omit when none
    ├── original_transaction_id       # linked return source txn and/or post-void source
    ├── post_void_of_transaction_id
    └── return_of_transaction_id      # 6.6 post-void era; omit in 6.5 (line original_transaction_line_id is authority)
```

Do **not** use `operation_type` on the envelope. Command type lives only on `pos_operations`.

Exact JSON key set for override, discount, return_price_adjustment, controlled_actions, and corrections is locked in the owning slice contract. 6.0 locks that those facts live **in the completed operation**, not as edits to prior rows.

---

## 4. Line and tender meaning

### 4.1 Lines

| Field | Meaning |
|---|---|
| `direction` | `sale` or `return`. Phase 4/5 emit `sale` only. |
| `product_variant_id` | Required for MVP merchandise lines. |
| `inventory_unit_id` | Required for individually tracked lines; forbidden otherwise. |
| `quantity` | Positive integer. Individually tracked lines are `1`. |
| `reference_unit_price_cents` | Price before override. |
| `selling_unit_price_cents` | Price after override, before line discount. |
| `extended_selling_amount_cents` | Positive magnitude (`selling × quantity` before discount). |
| `manual_discount_cents` / net | 6.4: net = extended − discount; tax uses net. |
| Tax Class | Applied Tax Class used for determination. Default is the ProductVariant Tax Class at add; preserve both once 6.4D override exists. |
| `tax_components[]` | Every active Store Tax determination, including `applies = false`. |
| `original_transaction_line_id` | Linked return only. Unlinked returns omit it. |
| `return_price_adjustment` | Unlinked-return commercial valuation fact (§4.2). Omit on sales and linked returns. |

Do not store negative `line_total_cents` because `direction = return`.

### 4.2 Return price adjustment (6.5)

An unlinked return is valued under **current** POS rules. The cashier may enter a return unit price (`>= 0`, may be above or below reference). That difference is neither an ordinary sale discount nor a sale `price_override`, and it is **not** a second controlled action.

Exact keys: [returns.md](returns.md) §18. Omit the block when selling = reference.

```text
return_price_adjustment:
  reference_unit_price_cents
  resulting_unit_price_cents
  unit_variance_cents
  line_variance_cents
```

Authorization is the single `unlinked_return` action (requested price is in that fingerprint). Do not encode this as `discount` or as `override`.

### 4.3 Tenders

| Field | Meaning |
|---|---|
| `amount_cents` | Applied amount; positive. |
| `direction` | `payment` (funds in) or `refund` (funds out). |
| `tender_number` | Dense `1..N` per transaction (6.2). Do not order by timestamp or UUID. |
| `tender_name` | Display-name snapshot at add/replace (6.2). Later config renames do not rewrite it. |
| Cash presented / change | Only on Cash **payment** tenders. Not on refunds. Not on Card/Check/Other. |
| External reference | Optional or required per tender configuration (6.2). Stored on the completed tender; customer print may omit it (§14). |

6.1 schema-2 envelopes omit `behavioral_category`, `tender_name`, and `tender_number`. New 6.2+ completions include them. Verification must accept both shapes.

```text
SUM(payments) − SUM(refunds) = signed_net_cents
```

Exact settlement is required to complete. [tender-breadth.md](tender-breadth.md) / [controlled-actions.md](controlled-actions.md):

```text
signed_net_cents > 0  → payment tenders only; exact SUM(payments) = signed_net
signed_net_cents < 0  → refund tenders only ([returns.md](returns.md))
signed_net_cents = 0  → no tender (6.4C sale-only zero-net; 6.5 mixed)
```

---

## 5. Totals: keep `total_cents`, add signed net, do not overload subtotal/tax

v1 `total_cents` is the unsigned amount the customer pays on a sale-only Cash transaction. **Do not redefine it as net-after-returns.**

Locked now:

```text
signed_net_cents
  = SUM(sale line_total_cents)
  − SUM(return line_total_cents)

total_cents
  = abs(signed_net_cents)
  = settlement amount (customer pays or receives)
```

For every Phase 4/5 sale-only completion, `signed_net_cents = total_cents`.

`subtotal_cents`, `discount_cents`, and `tax_cents` keep their **sale-direction Phase 4–6.4 meanings**. Do not overload them as mixed-return fields.

**6.5 lock** ([returns.md](returns.md) §3): persist directional return aggregates and `signed_net_cents`. Do not add a Core `sale_total_cents` column and do not emit it on the envelope.

```text
sale_total           = subtotal_cents - discount_cents + tax_cents   # presentation only; not Core, not envelope
return_subtotal_cents / return_discount_cents / return_tax_cents
return_total_cents   = return_subtotal - return_discount + return_tax
signed_net_cents     = sale_total - return_total                    # persisted
total_cents          = abs(signed_net_cents)
```

Sale-only history is unchanged (`return_* = 0`, `signed_net = total`). Envelope includes `signed_net_cents` on every v2 completion (sale-only: equal to `total_cents`). Pre-6.5 v2 remains valid without return keys.

### 5.1 Session / Z must stay truthful in the owning slice

`finalized_total_cents = SUM(transaction.total_cents)` is correct only while every completed `total_cents` is a sale settlement. A return whose `total_cents` is `abs(signed_net)` would inflate Z if summed as sales:

```text
Sale     total_cents = 100
Refund   total_cents =  25
SUM(total_cents)     = 125   # not net commercial activity
```

**6.5 must make Session/Z calculations direction-aware in the same change that first completes a return** ([returns.md](returns.md) §29). It cannot leave Z treating refund magnitude as positive sales. Additive `finalized_return_*` / refund columns are **not** part of `closed_at_matches_status`.

**6.2 must add basic Card / Check / Other tender totals to Session/Z** when those tenders become completable. Overall sale totals can remain correct without them, but a register that takes Card with only Cash on the Z is not usable.

6.7 may add or reorganize additive snapshot columns and presentation. It does **not** repair knowingly inaccurate intermediate reporting. Already-finalized periods stay immutable.

---

## 6. Merchandise snapshot

v1 required keys remain:

```json
{
  "sku": "2210000000001",
  "description": "Example Book",
  "tax_class_code": "physical_book"
}
```

When `inventory_unit_id` is present, also snapshot (6.1):

```json
{
  "unit_identifier": "2200000000001",
  "condition_code": "good"
}
```

`condition_code` comes from the parent Used variant’s condition at completion. Do not add a unit condition column.

Completed history and reprint use these snapshots. Live Product / variant / unit rows must not rewrite them.

---

## 7. Completion command

v1 command (Phase 4/5 Cash) requires `amount_presented_cents` at command level.

v2 command (from 6.2):

| Field | Required | Notes |
|---|---|---|
| `transaction_id` | yes | Working commercial transaction |
| `operation_id` | yes | Client-generated UUIDv7; `pos_operations.id` / idempotency key |
| `expected_lock_version` | yes | Optimistic concurrency |
| `expected_total_cents` | yes | Unsigned settlement amount the client believes will be collected or refunded |
| `expected_signed_net_cents` | yes from 6.5 | Required in `CompleteTransaction.command_payload`; sale-only equals `expected_total_cents`. Idempotency hash includes both ([returns.md](returns.md) §24). |

`amount_presented_cents` is **not** a command field. Cash presented lives on the Cash tender row. `source_id` remains `register_id` from the working transaction (ADR-009 / ADR-021).

6.1 may keep the v1 command internally (Cash-only, presented still supplied) while emitting v2 envelopes. 6.2 must move presented off the command.

Idempotency is unchanged:

```text
same (source_id, command_type, idempotency_key) + same command_payload_hash → same result
same key + different command_payload_hash → integrity failure
```

Lost-response retries must still produce only one completed set of tenders.

---

## 8. Expected Cash

Phase 5 (until the first Cash refund):

```text
expected = opening_float_cents
         + SUM(cash payment amount_cents)
           on completed session transactions
```

From the first Cash refund (6.5), without waiting for paid-in/out ([returns.md](returns.md) §23):

```text
expected = opening_float_cents
         + SUM(cash payment amount_cents)
         − SUM(cash refund amount_cents)
```

Expected Cash may be negative (accounting fact, not a physical drawer cap; [returns.md](returns.md) §23). 6.2 must not change the formula. Cancelled and working tenders contribute nothing. Closed-session snapshots remain authoritative after freeze.

---

## 9. Z snapshots

Already-finalized periods stay immutable. Live Session/Z **previews** and new-period snapshots must represent each slice’s facts truthfully (§5.1). 6.7 consolidates additive `finalized_*` columns and presentation; owning slices (6.2 tenders, 6.4 discounts, 6.5 returns/Cash refunds) change calculations first.

Existing Phase 5 fields keep their sale-only / Cash-payment meanings until the owning slice replaces the **calculation** (not the historical column meaning on already-finalized rows):

```text
finalized_transaction_count
finalized_subtotal_cents
finalized_tax_cents
finalized_total_cents
finalized_cash_payment_cents
finalized_session_count
finalized_*_sum cash custody fields
finalized_by_user_id
```

6.5 additive return/refund snapshot columns ([returns.md](returns.md) §29); NULL on pre-6.5 finalized = not captured; **not** in `closed_at_matches_status`:

```text
finalized_return_subtotal_cents
finalized_return_discount_cents
finalized_return_tax_cents
finalized_return_total_cents
finalized_net_cents
finalized_cash_refund_cents
finalized_card_refund_cents
finalized_check_refund_cents
finalized_other_refund_cents
```

`finalized_discount_cents` is 6.4. Plus per-category tender **payment** totals from 6.2. Cash custody on the Z remains the **sum of independent session snapshots**, including the 6.5 expected-Cash formula.

Do not add paid-in/out, drops, safe, drawer, denomination, or Store Close columns.

---

## 10. Corrections

```text
returns / post-void = new completed transactions
original rows are never updated
```

**Linked return** references `original_transaction_line_id` (line linkage is authority). 6.5 does **not** set envelope `corrections.return_of_transaction_id` ([returns.md](returns.md) §30). Remaining returnable uses only **completed** linked return quantities. Working and cancelled returns do not consume eligibility. Database uniqueness / locking must prevent two Registers from both completing the last eligible quantity.

**Post-void** is 6.6. 6.5 eligibility does not yet see post-voids; 6.6 will refuse post-void if a completed linked return exists, and refuse a linked return against a post-voided original.

**Post-void** creates one compensating completed transaction that reverses the whole original (sale lines → return-direction corrections, return lines → sale-direction corrections, payments ↔ refunds, inventory opposite effects, tax/reporting as **new-period** facts).

Post-void is **prohibited** when:

- a completed linked return already exists against the original, or
- a completed post-void of the original already exists.

Yesterday’s finalized Z is not rewritten. Today’s period receives the compensating fact.

Cannot edit the generated reversal. Partial correction uses return workflows, not partial post-void.

---

## 11. Controlled actions

Persist **executed** approval/audit facts only. Do not persist pending approval requests.

```text
request
  → performer permission
  → policy: direct | approval_required | prohibited
  → if approval_required: second actor authenticates; bind to exact values
  → record executed fact + perform action
```

The cashier remains Session owner. Approval is not manager mode and is not transferable Session custody.

MVP action catalog (identifiers reserved; unused until the owning slice):

```text
price_override
line_discount
tax_class_override
unlinked_return
return_price_adjustment
post_void
```

Permission keys: 6.1–6.3 keep `pos.transact` only. Perform/approve keys for `price_override`, `line_discount`, and `tax_class_override` arrive in 6.4 ([controlled-actions.md](controlled-actions.md)). 6.5 seeds only `unlinked_return` ([returns.md](returns.md) §16). `return_price_adjustment` and `post_void` remain reserved. Z finalize stays on `pos.transact` until a later controlled-action decision. Reason is material to the fingerprint. 6.4 completion integrity is sale-direction; 6.5 is direction-aware. 6.4 sale actions are prohibited on return lines.

---

## 12. Tax

- **Sale lines and unlinked returns:** calculate from the applied Tax Class and **current** Store Tax configuration at completion.
- **Linked returns:** reverse original completed component cents. Do not recalculate from current Store Taxes or current merchandise Tax Class ([pos-tax-contract.md](../phase4-point-of-sale/pos-tax-contract.md) §10).
- Tax Class override (6.4) is selection among valid Tax Classes, then current-config calculation. Never cashier-entered rates. Purchaser exemption is out.

Completion must not share one “recalculate tax” helper for historical reversal and current determination without an explicit mode.

---

## 13. Inventory

Inventory movement occurs only at completion, through the named posting boundary ([inventory-posting-contract.md](../../phase3-inventory-foundation/inventory-posting-contract.md)). 6.5 adds `Inventory::PostReturn` ([returns.md](returns.md) §12 / §15).

Working transactions still do **not** create `reserved`. Unique Used units serialize `AddMerchandise` on the `InventoryUnit` row and re-lock at completion ([merchandise-breadth.md](merchandise-breadth.md) §4.4). Do not introduce a reservation ledger in this MVP.

Non-inventory lines create **no** ledger, valuation, or balance rows.

---

## 14. Receipt copies

Completed tenders may store Card/Check/Other external references. Customer-facing print and reprint **omit** unnecessary external references. Operator detail (6.3) may show them.

This is a display rule over the same snapshots, not a second commercial envelope.

Reprint never assigns a new receipt number, never mutates `printed_at` as commercial state, and never substitutes live Product descriptions or prices.

---

## 15. Slice-local representation

Every slice that adds a completed commercial fact must update, in that same slice: completed snapshot, customer-relevant receipt, history/detail, audit, and reporting where totals change. 6.7 consolidates; it does not repair knowingly inaccurate intermediate figures.

---

## 16. Out of 6.0

- Any migration or application code
- Unused Core columns “for later”
- New permission keys
- Changing Phase 5 expected-Cash or Z snapshot CHECKs in this docs slice (6.2 / 6.5 change live calculations; 6.7 may add additive snapshot columns)
- Terminal / standalone provenance (still a later compatible envelope version before offline completion)
