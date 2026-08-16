# Phase 4 — POS schema outline

**Status:** Planning (do not migrate until [phase4-plan.md](phase4-plan.md) semantic locks and [completed-pos-operation-v1.md](completed-pos-operation-v1.md) fixtures are stable)

**Authority:** Field-level intent for Phase 4 POS tables. Prefer this document over conversational outlines in chat or preliminary-specs drafts. Cross-cutting rules remain in `AGENTS.md` and accepted ADRs.

Companion: [Phase 4 plan](phase4-plan.md).

---

## 1. Design principles

- PostgreSQL is authoritative; UUIDv7 for durable POS entities; generate IDs at origin.
- Money as signed-capable integer `_cents` with explicit `currency_code` on the operation/transaction; **Phase 4 line and tender magnitudes are stored positive** (see plan §5.7).
- `occurred_at` is the business event instant (UTC); `posted_at` / `created_at` are recording times; `business_date` is stored explicitly.
- Draft/working state may be edited; completed commercial facts are immutable and corrected only by new facts later.
- Optimistic locking via `lock_version` on mutable aggregate roots (`pos_sessions`, working `pos_transactions`).
- No Phase 5 Cash-accountability columns on sessions in this phase.
- No Phase 6 return/discount/approval columns required; leave room via `direction` and versioned operation envelopes rather than speculative null columns.

---

## 2. Table set

```text
pos_reporting_periods
pos_sessions
pos_transactions
pos_transaction_lines
pos_line_tax_components
pos_tenders
pos_operations
(+ receipt sequence support — see §10)
```

---

## 3. `pos_reporting_periods`

Logical Z / reporting period for a store (and eventually workstation association rules as Phase 5 needs them).

| Column | Type | Notes |
|---|---|---|
| `id` | uuid | PK, UUIDv7 |
| `store_id` | uuid | FK, null: false |
| `status` | string | e.g. `open`, `closed` |
| `opened_at` | timestamptz | null: false |
| `closed_at` | timestamptz | null when open |
| `business_date` | date | explicit; null: false for opened periods |
| `lock_version` | integer | null: false, default 0 |
| `created_at` / `updated_at` | timestamptz | |

Phase 4 needs enough structure that sessions and completions can attach to a period. Full Z reporting UI is Phase 5.

---

## 4. `pos_sessions`

Cashier session on a workstation. **Phase 4 columns only:**

| Column | Type | Notes |
|---|---|---|
| `id` | uuid | PK, UUIDv7 |
| `store_id` | uuid | FK, null: false |
| `workstation_id` | uuid | FK → `workstations`, null: false |
| `reporting_period_id` | uuid | FK → `pos_reporting_periods`, null: false |
| `cashier_user_id` | uuid | FK → `users`, null: false |
| `status` | string | e.g. `open`, `closed` |
| `opened_at` | timestamptz | null: false |
| `closed_at` | timestamptz | null when open |
| `lock_version` | integer | null: false, default 0 |
| `created_at` / `updated_at` | timestamptz | |

### Explicitly deferred to Phase 5

Do **not** add in Phase 4:

```text
opening_float_cents
closing_count_cents
expected_cash_cents
variance_cents
```

When Phase 5 adds Cash accountability, prefer close-snapshot names so values are not mistaken for live cash authority:

```text
opening_float_cents              # if needed at open
closing_expected_cash_cents      # derived snapshot at close
closing_count_cents
closing_variance_cents
```

`expected_cash_cents` must not look like a live authoritative counter.

---

## 5. `pos_transactions`

One row for working and completed (or cancelled) commercial state.

| Column | Type | Notes |
|---|---|---|
| `id` | uuid | PK, UUIDv7 (= `transaction_id`) |
| `store_id` | uuid | FK, null: false |
| `workstation_id` | uuid | FK, null: false |
| `pos_session_id` | uuid | FK, null: false |
| `reporting_period_id` | uuid | FK, null: false (denormalized for query convenience; must match session) |
| `cashier_user_id` | uuid | FK, null: false |
| `status` | string | `working`, `completed`, `cancelled` (exact enum locked in migration) |
| `currency_code` | string(3) | null: false |
| `occurred_at` | timestamptz | set/frozen at completion; may be provisional while working |
| `business_date` | date | explicit; frozen at completion |
| `completed_at` | timestamptz | null until completed |
| `cancelled_at` | timestamptz | null until cancelled |
| `receipt_sequence` | bigint | null until completed |
| `receipt_number` | string | null until completed; permanent thereafter |
| `subtotal_cents` | bigint | Phase 4: sum of sale line extended amounts (positive) |
| `tax_cents` | bigint | Phase 4: sum of component tax (positive for sale-only) |
| `total_cents` | bigint | Phase 4: amount due; revisit as `transaction_net_cents` when returns arrive |
| `lock_version` | integer | null: false, default 0 |
| `created_at` / `updated_at` | timestamptz | |

### Rules

- Working transactions may be edited.
- Completed rows are immutable commercially; no generic update/delete of completed facts.
- Cancelled working transactions create no receipt and no Inventory effect.
- No Phase 4 `inventory_unit_id` on the header.

---

## 6. `pos_transaction_lines`

| Column | Type | Notes |
|---|---|---|
| `id` | uuid | PK, UUIDv7 (= `line_id`) |
| `pos_transaction_id` | uuid | FK, null: false |
| `line_number` | integer | stable display/order within transaction |
| `direction` | string | Phase 4: `sale` only; Phase 6 adds `return` |
| `product_variant_id` | uuid | FK, null: false for Phase 4 merchandise lines |
| `quantity` | decimal/numeric | exact scale per merchandise rules; Phase 4 quantity-tracked |
| `reference_unit_price_cents` | bigint | null: false when priced |
| `selling_unit_price_cents` | bigint | equals reference in Phase 4 |
| `extended_selling_amount_cents` | bigint | positive magnitude |
| `line_tax_cents` | bigint | sum of component tax_cents; positive magnitude |
| `line_total_cents` | bigint | extended + tax for Phase 4 sale lines; positive magnitude |
| `tax_class_id` | uuid | FK; classification used for determination |
| `tax_class_code` | string | snapshot; **not** a treatment word (`physical_book`, not `taxable`) |
| `merchandise_snapshot` | jsonb | **required when transaction is completed**; see §6.1 |
| `created_at` / `updated_at` | timestamptz | |

### Explicitly absent on the line

```text
tax_treatment          # belongs on each tax component
inventory_unit_id      # Phase 6+
discount fields        # Phase 6
```

### 6.1 Merchandise snapshot (required at completion)

Minimum v1 shape:

```json
{
  "sku": "2210000000001",
  "description": "Example Book",
  "tax_class_code": "physical_book"
}
```

Optional keys may be added in later operation versions without expanding the relational line schema. While `status = working`, snapshot may be absent or provisional; completion **must** refuse to finish without a valid required snapshot.

---

## 7. `pos_line_tax_components`

One row per tax component determination on a line.

| Column | Type | Notes |
|---|---|---|
| `id` | uuid | PK, UUIDv7 |
| `pos_transaction_line_id` | uuid | FK, null: false |
| `tax_component_id` | uuid | identifies **what tax this was**; null: false when known |
| `tax_rule_id` | uuid | optional; which effective configuration caused the result |
| `component_code_snapshot` | string | null: false |
| `component_name_snapshot` | string | null: false |
| `treatment` | string | e.g. `taxable`, `exempt`, `zero_rated` |
| `rate_value` | — | **fixed-precision representation defined by Tax contract**; do not migrate as `rate_basis_points` |
| `taxable_basis_cents` | bigint | positive magnitude for Phase 4 sale lines |
| `tax_cents` | bigint | positive magnitude for Phase 4 sale lines |
| `calculation_order` | integer | null: false |
| `created_at` / `updated_at` | timestamptz | |

### Rate representation

ADR-007 allows basis points where precision permits and finer fixed-scale integers when required (e.g. `8.875%`). Phase 4 **must not** freeze `rate_basis_points` in this schema.

Until the Tax contract locks scale, document columns as:

```text
rate_value     # fixed-precision representation defined by tax contract
```

Block the tax-component migration (or leave rate untyped in planning only) until that contract chooses an exact integer scale or `numeric` policy.

### Identity

Do not leave “`tax_component_key` **or** `tax_rule_id`” as an implementation choice. Persist component identity; retain rule id when available; always snapshot code/name for receipt/history.

---

## 8. `pos_tenders`

| Column | Type | Notes |
|---|---|---|
| `id` | uuid | PK, UUIDv7 |
| `pos_transaction_id` | uuid | FK, null: false |
| `tender_type` | string | Phase 4: `cash` |
| `direction` | string | Phase 4: `payment` |
| `amount_cents` | bigint | positive magnitude (amount applied) |
| `amount_presented_cents` | bigint | Cash presented |
| `change_cents` | bigint | positive; not a separate refund tender |
| `created_at` / `updated_at` | timestamptz | |

Phase 4: one Cash payment tender per completed sale is sufficient.

---

## 9. `pos_operations`

Durable POS completion provenance implementing ADR-009 idempotency semantics.

| Column | Type | Notes |
|---|---|---|
| `id` | uuid | PK; may equal `operation_id` or hold it separately—prefer `id = operation_id` |
| `operation_id` | uuid | globally unique completion identity if not identical to `id` |
| `operation_type` | string | e.g. `pos.complete_transaction` |
| `source_id` | string/uuid | scoped source identity per ADR-009 |
| `idempotency_key` | string | null: false |
| `payload_hash` | string | canonical hash of material completion input |
| `status` | string | `in_flight`, `completed`, `failed` |
| `lease_expires_at` | timestamptz | required while `in_flight` |
| `pos_transaction_id` | uuid | FK; set when associated |
| `result_reference` | jsonb/text | stored outcome / response reference |
| `completed_envelope` | jsonb | optional storage of canonical `CompletedPosOperation` v1 |
| `completed_at` | timestamptz | |
| `lock_version` | integer | |
| `created_at` / `updated_at` | timestamptz | |

Unique index on `(source_id, operation_type, idempotency_key)`.

### Why not only `idempotency_operations`?

ADR-009 retention is “long enough to cover retries,” not necessarily permanent commercial provenance.

```text
generic idempotency  → protects an application request
POS completed operation → durable business provenance
```

Reuse ADR-009 **mechanics** (status, lease, payload hash, uniqueness). Prefer a dedicated `pos_operations` table unless `idempotency_operations` is explicitly adopted as never-expiring archival storage for POS. That choice must be locked **before** migration—not “decide while coding.”

### Identity separation

```text
operation_id   → identity of the completion operation
transaction_id → identity of the commercial transaction
```

Do not use `transaction_id` as the completion idempotency substitute. Initial one-to-one relationship is incidental; later correction operations need the distinction.

---

## 10. Receipt sequence support

Receipt identity is assigned only during authoritative completion.

Conceptual uniqueness:

```text
(store_id, workstation_id, receipt_sequence)
```

Implementation options (pick one in migration design):

1. Counter table keyed by store + workstation; increment inside the completion transaction.  
2. Sequence object per workstation with careful transactional semantics.

Persist on the transaction:

```text
receipt_sequence
receipt_number
```

and include both in `CompletedPosOperation.receipt`.

Printable formatting of `receipt_number` may be finalized in Phase 5; sequence authority is Phase 4.

---

## 11. Inventory linkage (no new inventory tables)

Post through existing Inventory services. Ledger / valuation entries reference:

```text
source_type = "PosTransactionLine"   # consistent with Phase 3 class-name convention
source_id   = pos_transaction_lines.id
```

Traceability must still support:

```text
operation_id → transaction_id → line_id → ledger entry
```

Do not invent a POS-only domain `source_type` string unless a global inventory ADR changes causal reference conventions.

---

## 12. Indexes and constraints (minimum intent)

- FKs for all store / workstation / session / period / user / variant / tax references.
- Unique `(store_id, workstation_id, receipt_sequence)` where sequence is not null.
- Unique completed receipt_number policy as designed (global or scoped—lock with number format).
- `pos_operations` uniqueness on `(source_id, operation_type, idempotency_key)`.
- Check constraints for status enums; `in_flight` requires lease.
- Reject completed transactions without receipt fields.
- Reject completed lines without required merchandise snapshot keys (DB CHECK and/or application validation).

Exact constraint names follow existing migration conventions.

---

## 13. Phase 4 migration checklist

Before writing migrations:

- [ ] Tax contract defines `rate_value` scale  
- [ ] `pos_operations` vs generic idempotency retention locked  
- [ ] CompletedPosOperation v1 example fixtures reviewed  
- [ ] Sign/direction conventions documented in contract  
- [ ] Session table confirmed **without** Cash close columns  

Then migrate in dependency order: periods → sessions → transactions → lines → tax components → tenders → operations → receipt counter (as needed).
