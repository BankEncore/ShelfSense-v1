# Phase 4 — POS schema outline

**Status:** Planning (do not migrate until [phase4-plan.md](phase4-plan.md) semantic locks and [completed-pos-operation-v1.md](completed-pos-operation-v1.md) fixtures are stable)

**Authority:** Field-level intent for Phase 4 POS tables. Prefer this document over conversational outlines in chat or preliminary-specs drafts. Cross-cutting rules remain in `AGENTS.md` and accepted ADRs. Tax configuration and completed tax rows follow [pos-tax-contract.md](pos-tax-contract.md) and [ADR-019](../../../adr/ADR-019-pos-sales-tax-model.md).

Companions: [Phase 4 plan](phase4-plan.md), [POS tax contract](pos-tax-contract.md).

---

## 1. Design principles

- PostgreSQL is authoritative; UUIDv7 for durable POS entities; generate IDs at origin.
- Money as signed-capable integer `_cents` with explicit `currency_code` on the operation/transaction; **Phase 4 line and tender magnitudes are stored positive** (see plan §5.7).
- Sales-tax rates use `numeric(6,3)` (`rate_percent`), not basis points.
- `occurred_at` is the business event instant (UTC); `posted_at` / `created_at` are recording times; `business_date` is stored explicitly.
- Draft/working state may be edited; completed commercial facts are immutable and corrected only by new facts later.
- Optimistic locking via `lock_version` on mutable aggregate roots (`pos_sessions`, working `pos_transactions`, store tax config).
- No Phase 5 Cash-accountability columns on sessions in this phase.
- No Phase 6 return/discount/approval columns required; leave room via `direction` and versioned operation envelopes rather than speculative null columns.

---

## 2. Table set

```text
registers                              # after ADR-021 rename (was workstations)
store_taxes                         # tax configuration (ADR-019)
store_tax_rules
tax_classes                         # existing merchandise domain

pos_reporting_periods
pos_sessions
pos_transactions
pos_transaction_lines
pos_line_tax_components
pos_tenders
pos_operations
(+ receipt sequence on registers — see §12)
```

See [register-identity.md](register-identity.md) for the `registers` target shape and pre-Phase-4 rename prerequisite.

---

## 3. `store_taxes`

| Column | Type | Notes |
|---|---|---|
| `id` | uuid | PK, UUIDv7 |
| `store_id` | uuid | FK, null: false |
| `code` | string | stable; unique per store |
| `name` | string | null: false |
| `rate_percent` | numeric(6,3) | percentage; up to three decimal places |
| `active` | boolean | null: false |
| `calculation_order` | integer | null: false |
| `lock_version` | integer | null: false, default 0 |
| `created_at` / `updated_at` | timestamptz | |

---

## 4. `store_tax_rules`

| Column | Type | Notes |
|---|---|---|
| `id` | uuid | PK, UUIDv7 |
| `store_tax_id` | uuid | FK, null: false |
| `tax_class_id` | uuid | FK → `tax_classes`, null: false |
| `applies` | boolean | **nullable** — `NULL` means unresolved / incomplete |
| `lock_version` | integer | null: false, default 0 |
| `created_at` / `updated_at` | timestamptz | |

Unique `(store_tax_id, tax_class_id)`.

Auto-create rows when Store Taxes or Tax Classes appear (see tax contract). Sell/complete requires `applies IS NOT NULL` for every active Store Tax for the line’s Tax Class.

---

## 5. `pos_reporting_periods`

Logical Z / reporting period for exactly one Register (ADR-021).

| Column | Type | Notes |
|---|---|---|
| `id` | uuid | PK, UUIDv7 |
| `store_id` | uuid | FK, null: false |
| `register_id` | uuid | FK → `registers`, null: false |
| `status` | string | e.g. `open`, `closed` |
| `opened_at` | timestamptz | null: false |
| `closed_at` | timestamptz | null when open |
| `business_date` | date | explicit; null: false for opened periods |
| `lock_version` | integer | null: false, default 0 |
| `created_at` / `updated_at` | timestamptz | |

Invariants: `store_id` matches `registers.store_id`; **at most one open reporting period per Register**. Full Z reporting UI is Phase 5.

---

## 6. `pos_sessions`

Cashier session on a register. **Phase 4 columns only:**

| Column | Type | Notes |
|---|---|---|
| `id` | uuid | PK, UUIDv7 |
| `store_id` | uuid | FK, null: false |
| `register_id` | uuid | FK → `registers`, null: false |
| `reporting_period_id` | uuid | FK → `pos_reporting_periods`, null: false |
| `cashier_user_id` | uuid | FK → `users`, null: false |
| `status` | string | e.g. `open`, `closed` |
| `opened_at` | timestamptz | null: false |
| `closed_at` | timestamptz | null when open |
| `lock_version` | integer | null: false, default 0 |
| `created_at` / `updated_at` | timestamptz | |

Invariants: `session.store_id` and `session.register_id` match the Register and the Session’s `reporting_period` (`period.register_id == session.register_id`).

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

## 7. `pos_transactions`

One row for working and completed (or cancelled) commercial state.

| Column | Type | Notes |
|---|---|---|
| `id` | uuid | PK, UUIDv7 (= `transaction_id`) |
| `store_id` | uuid | FK, null: false |
| `register_id` | uuid | FK, null: false |
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
| `store_number_snapshot` | string | null until completed; from `stores.store_number` |
| `register_number_snapshot` | string | null until completed; from `registers.register_number` |
| `transaction_reference` | string | optional derived compact `S…-R…-T…`; regenerable from snapshots + sequence |
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

## 8. `pos_transaction_lines`

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
| `tax_class_id` | uuid | FK; merchandise Tax Class used for determination |
| `tax_class_code` | string | snapshot; classification code (`physical_book`), not a treatment |
| `merchandise_snapshot` | jsonb | **required when transaction is completed**; fixed v1 keys (see §8.1); Phase 4 Core shape per ADR-020 — do not also require a competing column set |
| `created_at` / `updated_at` | timestamptz | |

### Explicitly absent on the line

```text
tax_treatment                    # not used; applicability is per Store Tax
default_tax_class_id / applied_  # deferred until Tax Class override
inventory_unit_id                # Phase 6+
discount fields                  # Phase 6
```

### 8.1 Merchandise snapshot (required at completion)

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

## 9. `pos_line_tax_components`

One row per **active Store Tax determination** on a completed line (including `applies = false`). See [pos-tax-contract.md](pos-tax-contract.md).

| Column | Type | Notes |
|---|---|---|
| `id` | uuid | PK, UUIDv7 |
| `pos_transaction_line_id` | uuid | FK, null: false |
| `store_tax_id` | uuid | FK → `store_taxes`; the component identity |
| `store_tax_code_snapshot` | string | null: false |
| `store_tax_name_snapshot` | string | null: false |
| `rate_percent` | numeric(6,3) | snapshot of configured rate |
| `applies` | boolean | null: false on completed rows |
| `taxable_basis_cents` | bigint | basis when applies; else 0 |
| `tax_cents` | bigint | rounded tax when applies; else 0 |
| `calculation_order` | integer | null: false |
| `created_at` / `updated_at` | timestamptz | |

Optional provenance: `store_tax_rule_id` at calculation time.

Do **not** use abstract `tax_component_id`, treatment enums, or `rate_basis_points` / open `rate_value`.

---

## 10. `pos_tenders`

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

## 11. `pos_operations`

Durable completion provenance **and** ADR-009 idempotency. Authority: [operation-and-core-facts.md](operation-and-core-facts.md) and [ADR-020](../../../adr/ADR-020-pos-operation-envelope-and-core-facts.md).

| Column | Type | Notes |
|---|---|---|
| `id` | uuid | PK; prefer `id = operation_id` |
| `operation_id` | uuid | if not identical to `id` |
| `operation_type` | string | e.g. `pos.complete_transaction` |
| `schema_version` | integer | envelope contract version |
| `source_id` | string/uuid | ADR-009 scope |
| `idempotency_key` | string | null: false |
| `payload_hash` | string | hash of canonical commercial envelope (transport excluded) |
| `status` | string | `in_flight`, `completed`, `failed` |
| `lease_expires_at` | timestamptz | required while `in_flight` |
| `pos_transaction_id` | uuid | FK when associated |
| `store_id` | uuid | indexed origin |
| `register_id` | uuid | indexed origin |
| `installation_id` | uuid | optional later technical id only; not POS business vocabulary (ADR-021) |
| `producer_client` | string | optional |
| `producer_version` | string | optional |
| `envelope` | jsonb | **required when completed** — full `CompletedPosOperation` |
| `originated_at` | timestamptz | commercial origin time |
| `received_at` | timestamptz | central receipt (Core only; not in envelope) |
| `posted_at` | timestamptz | central materialization (Core only; not in envelope) |
| `lock_version` | integer | |
| `created_at` / `updated_at` | timestamptz | |

Unique index on `(source_id, operation_type, idempotency_key)`.

### Role

```text
generic idempotency  → may expire; protects a request
pos_operations       → durable commercial provenance + idempotency for POS completion
```

Normalized Core tables are used for all ordinary business behavior. The envelope is not optional and is not reconstructed later from tables as a substitute for provenance. No commercial workflow may depend on parsing `envelope`.

### Identity separation

```text
operation_id   → identity of the completion operation
transaction_id → identity of the commercial transaction
```

Do not use `transaction_id` as the completion idempotency substitute.

---

## 12. Receipt sequence and reference support

Authority: [receipt-identity.md](receipt-identity.md) and amended [ADR-006](../../../adr/ADR-006-receipt-numbering.md).

Receipt identity is assigned only during authoritative completion.

Conceptual uniqueness:

```text
(store_id, register_id, receipt_sequence)
```

### Prerequisite: durable register number

`registers` must include a per-store durable number for the `R` component:

| Column | Type | Notes |
|---|---|---|
| `register_number` | string | null: false; unique per `store_id`; parallel to `stores.store_number` |

Do not use editable `name` in the reference. Prefer explicit `register_number` over reusing free-form `code` unless `code` is constrained to be that number.

Numbers become effectively immutable once a completed receipt has been issued for that register.

### Allocation

Implementation options (pick one in migration design):

1. Counter on `registers.receipt_sequence`; increment inside the completion transaction.  
2. Sequence object per register with careful transactional semantics.

Persist on the completed transaction:

```text
receipt_sequence
store_number_snapshot
register_number_snapshot
transaction_reference   # optional derived S003-R02-T0018427
```

Include sequence, number snapshots, and optional `reference` in `CompletedPosOperation.receipt`.

Minimum display padding: store 3, register 2, sequence 7 digits — minima only, not maxima.

Print layout (header `Store` / `Reg` / `Trans`) is Phase 5; identity/reference rules are Phase 4.

---

## 13. Inventory linkage (no new inventory tables)

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

## 14. Indexes and constraints (minimum intent)

- FKs for all store / register / session / period / user / variant / tax references.
- Unique `(store_id, code)` on `store_taxes`.
- Unique `(store_tax_id, tax_class_id)` on `store_tax_rules`.
- Unique `(store_id, register_id)` open reporting period policy (at most one open Z per Register).
- Unique `(store_id, register_id, receipt_sequence)` where sequence is not null.
- Unique `(store_id, register_number)` on `registers`.
- At most one open reporting period per `register_id`.
- Optional unique `transaction_reference` if stored; must match derived form from snapshots.
- `pos_operations` uniqueness on `(source_id, operation_type, idempotency_key)`.
- Check constraints for status enums; `in_flight` requires lease.
- Reject completed transactions without receipt sequence and number snapshots.
- Reject completed lines without required merchandise snapshot keys (DB CHECK and/or application validation).
- Completed `pos_line_tax_components.applies` is non-null.

Exact constraint names follow existing migration conventions.

---

## 15. Phase 4 migration checklist

Before writing POS migrations:

- [x] Tax rate / applicability model locked (ADR-019 + pos-tax-contract)  
- [x] Receipt / transaction reference format locked (ADR-006 + receipt-identity)  
- [x] Envelope vs normalized Core locked (ADR-020 + operation-and-core-facts)  
- [x] Register vs Terminal locked (ADR-021 + register-identity)  
- [ ] **Pre-Phase-4:** `workstations` → `registers` rename (FKs, permissions, audit, tests)  
- [ ] `registers.register_number` added and backfilled  
- [ ] Device-only fields reviewed/dropped on Register  
- [ ] CompletedPosOperation v1 example fixtures reviewed  
- [ ] Session table confirmed **without** Cash close columns  

Then migrate in dependency order: rename slice → `store_taxes` / `store_tax_rules` → periods (with `register_id`) → sessions → transactions → lines → tax components → tenders → operations.