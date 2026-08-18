# Phase 6 Slice 6.0 — MVP completed-operation contract

**Status:** Locked. Planning/contract only. No schema migration in this slice.

**Authority:** Cross-cutting completed-operation shape for the Phase 6 MVP. Dual authority with normalized Core remains [ADR-020](../../../adr/ADR-020-pos-operation-envelope-and-core-facts.md) / [operation-and-core-facts.md](../phase4-point-of-sale/operation-and-core-facts.md). Commercial base is [CompletedPosOperation v1](../phase4-point-of-sale/completed-pos-operation-v1.md).

Companions: [phase6-plan.md](phase6-plan.md), [merchandise-breadth.md](merchandise-breadth.md). Tax: [pos-tax-contract.md](../phase4-point-of-sale/pos-tax-contract.md). Cash/Z: [phase5-plan.md](../phase5-cash-register/phase5-plan.md).

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
  applied Tax Class
  tax components
  original sale line (return)

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
├── origin                            # v1
├── receipt                           # v1; still assigned only at completion
│
├── transaction
│   ├── transaction_id
│   ├── currency_code
│   ├── occurred_at
│   ├── business_date
│   ├── subtotal_cents                # unsigned; meaning locked in §5
│   ├── tax_cents                     # unsigned magnitude of tax on the settlement
│   ├── total_cents                   # unsigned settlement amount (v1 meaning kept)
│   └── signed_net_cents              # signed; §5
│
├── lines[]
│   ├── (v1 line fields)
│   ├── inventory_unit_id             # omit when absent
│   ├── merchandise_snapshot          # v1 keys plus unit keys when present (§6)
│   ├── override                      # omit when none; 6.4
│   ├── discount                      # omit when none; 6.4
│   ├── original_transaction_line_id  # omit when not a linked return; 6.5
│   └── tax_components[]              # v1 Store Tax determinations
│
├── tenders[]
│   ├── tender_id
│   ├── tender_type                   # configured identity (cash, card, check, …)
│   ├── behavioral_category           # cash | card | check | other
│   ├── direction                     # payment | refund
│   ├── amount_cents                  # applied; positive magnitude
│   ├── amount_presented_cents        # Cash payment only; omit otherwise
│   ├── change_cents                  # Cash payment only; omit otherwise
│   └── external_reference            # omit when not captured
│
├── controlled_actions[]              # omit when empty; executed facts only
│   ├── action
│   ├── performer_user_id
│   ├── approver_user_id              # omit when direct
│   ├── reason                        # structured identity; optional note
│   └── policy_context                # result + version snapshot; 6.4
│
└── corrections                       # omit when none
    ├── original_transaction_id       # linked return source txn and/or post-void source
    ├── post_void_of_transaction_id
    └── return_of_transaction_id      # when the whole txn is a return against one original
```

Do **not** use `operation_type` on the envelope. Command type lives only on `pos_operations`.

Exact JSON key set for override, discount, controlled_actions, and corrections is locked in the owning slice contract. 6.0 locks that those facts live **in the completed operation**, not as edits to prior rows.

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
| `extended_selling_amount_cents` | Positive magnitude (`selling × quantity` before discount; 6.4 defines discount interaction). |
| Tax Class | Applied Tax Class used for determination. Default equals merchandise Tax Class until 6.4 override. Preserve both default and applied once override exists. |
| `tax_components[]` | Every active Store Tax determination, including `applies = false`. |
| `original_transaction_line_id` | Linked return only. Unlinked returns omit it. |

Do not store negative `line_total_cents` because `direction = return`.

### 4.2 Tenders

| Field | Meaning |
|---|---|
| `amount_cents` | Applied amount; positive. |
| `direction` | `payment` (funds in) or `refund` (funds out). |
| Cash presented / change | Only on Cash **payment** tenders. Not on refunds. Not on Card/Check/Other. |
| External reference | Optional or required per tender configuration (6.2). Stored on the completed tender; customer print may omit it (§11). |

```text
SUM(payments) − SUM(refunds) = signed_net_cents
```

Exact settlement is required to complete. 6.2 enforces:

```text
signed_net_cents > 0  → payment tenders only
signed_net_cents < 0  → refund tenders only
signed_net_cents = 0  → no tender
```

---

## 5. Totals: keep `total_cents`, add signed net

v1 `total_cents` is the unsigned amount the customer pays on a sale-only Cash transaction. **Do not redefine it as net-after-returns.**

Lock:

```text
signed_net_cents
  = SUM(sale line_total_cents)
  − SUM(return line_total_cents)

total_cents
  = abs(signed_net_cents)
  = settlement amount (customer pays or receives)

subtotal_cents / tax_cents
  = unsigned components of that settlement for sale-only Phase 4/5 rows
```

For every Phase 4/5 sale-only completion, `signed_net_cents = total_cents`.

Core may derive `signed_net_cents` until 6.5 needs it persisted. The envelope includes it on every v2 completion (sale-only: equal to `total_cents`).

Z `finalized_total_cents` remains `SUM(transaction.total_cents)` until 6.7. 6.7 adds gross / returns / discounts / net columns. It must not later treat `finalized_total_cents` as net-after-returns.

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
| `expected_signed_net_cents` | yes from 6.5 | Sale-only 6.1/6.2 may omit; then it equals `expected_total_cents` |

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

From the first Cash refund (6.5), without waiting for paid-in/out:

```text
expected = opening_float_cents
         + SUM(cash payment amount_cents)
         − SUM(cash refund amount_cents)
```

6.2 must not change the formula. Cancelled and working tenders contribute nothing. Closed-session snapshots remain authoritative after freeze.

---

## 9. Z snapshots (named now, migrated in 6.7)

Already-finalized periods stay immutable. 6.7 adds additive columns; 6.0 names them.

Existing Phase 5 fields keep their meaning:

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

6.7 additive commercial / tender fields (preview names; exact CHECKs in the 6.7 contract):

```text
finalized_gross_sales_cents
finalized_return_cents
finalized_discount_cents
finalized_net_cents
finalized_cash_refund_cents
```

Plus per-category tender payment/refund totals for Card, Check, and configured Other. Cash custody on the Z remains the **sum of independent session snapshots**, including the 6.5 expected-Cash formula.

Do not add paid-in/out, drops, safe, drawer, denomination, or Store Close columns.

---

## 10. Corrections

```text
returns / post-void = new completed transactions
original rows are never updated
```

**Linked return** references `original_transaction_line_id`. Remaining returnable uses only **completed** linked return quantities. Working and cancelled returns do not consume eligibility. Database uniqueness / locking must prevent two Registers from both completing the last eligible quantity.

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

Permission keys: 6.1–6.3 keep `pos.transact` only. Perform/approve keys arrive in 6.4. Z finalize stays on `pos.transact` until a later controlled-action decision (Phase 5 intentionally left this broad).

---

## 12. Tax

- **Sale lines and unlinked returns:** calculate from the applied Tax Class and **current** Store Tax configuration at completion.
- **Linked returns:** reverse original completed component cents. Do not recalculate from current Store Taxes or current merchandise Tax Class ([pos-tax-contract.md](../phase4-point-of-sale/pos-tax-contract.md) §10).
- Tax Class override (6.4) is selection among valid Tax Classes, then current-config calculation. Never cashier-entered rates. Purchaser exemption is out.

Completion must not share one “recalculate tax” helper for historical reversal and current determination without an explicit mode.

---

## 13. Inventory

Inventory movement occurs only at completion, through the named posting boundary ([inventory-posting-contract.md](../../phase3-inventory-foundation/inventory-posting-contract.md)).

Working transactions still do **not** create `reserved`. Unique Used units use working-line uniqueness plus a completion-time lock (6.1). Do not introduce a reservation ledger in this MVP.

Non-inventory lines create **no** ledger, valuation, or balance rows.

---

## 14. Receipt copies

Completed tenders may store Card/Check/Other external references. Customer-facing print and reprint **omit** unnecessary external references. Operator detail (6.3) may show them.

This is a display rule over the same snapshots, not a second commercial envelope.

Reprint never assigns a new receipt number, never mutates `printed_at` as commercial state, and never substitutes live Product descriptions or prices.

---

## 15. Out of 6.0

- Any migration or application code
- Unused Core columns “for later”
- New permission keys
- Changing Phase 5 expected-Cash or Z snapshot CHECKs
- Terminal / standalone provenance (still a later compatible envelope version before offline completion)
