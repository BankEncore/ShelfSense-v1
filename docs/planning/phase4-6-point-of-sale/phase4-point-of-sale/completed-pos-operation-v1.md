# CompletedPosOperation v1

**Status:** Planning contract (Phase 4)

**Authority:** Canonical shape of a completed POS commercial fact for Phase 4 Cash sales under Rails. Dual authority with normalized Core: [operation-and-core-facts.md](operation-and-core-facts.md) / [ADR-020](../../../adr/ADR-020-pos-operation-envelope-and-core-facts.md).

v1 establishes the **commercial base** only. It is **not** asserted to contain all provenance required for standalone Terminal completion. A later compatible contract version must add Terminal and reference-configuration provenance (ADR-004, ADR-005, ADR-021) before standalone completion authority is enabled.

Companions: [Phase 4 plan](phase4-plan.md), [Phase 4 schema](phase4-schema.md), [operation-and-core-facts.md](operation-and-core-facts.md).

---

## 1. Purpose

`CompletedPosOperation` is the **immutable canonical representation** of a commercial transaction as established at completion. It is a complete commercial payload plus operation provenance — not mere metadata.

It always describes an **already-completed** originating fact and therefore **always includes permanent receipt identity**.

Normalized Core tables materialize the same commercial facts for ordinary business use. No required commercial behavior may depend on parsing the stored envelope. The envelope must remain sufficient to rematerialize Core; Core must remain sufficient to run the business without the envelope.

It is not the Rails UI form payload. It is not a draft. It is not “almost complete pending receipt.”

---

## 2. Command vs completed operation

### 2.1 Types and hashes

| Concern | Type | Hash on `pos_operations` |
|---|---|---|
| Pre-completion request | `command_type = pos.complete_transaction` | `command_payload_hash` |
| Completed fact | `fact_type = pos.transaction_completed` | `envelope_hash` |

Those hashes are intentionally different. The command hash binds a retry to the request that asked ShelfSense to complete. The envelope hash fingerprints the completed fact after receipt allocation.

### 2.2 `CompleteTransactionCommand` (internal / client request)

Input that asks the authority to complete a working transaction. Phase 4 hashed command material (no receipt, no completion-only timestamps):

| Field | Required | Notes |
|---|---|---|
| `transaction_id` | yes | Working commercial transaction |
| `operation_id` | yes | Client-generated UUIDv7; also `pos_operations.id` and `idempotency_key` |
| `expected_lock_version` | yes | Optimistic concurrency on the working transaction |
| `expected_total_cents` | yes | Amount due the client believes will be charged |
| `amount_presented_cents` | yes | Cash presented |

`source_id` is **not** client-supplied. Rails Phase 4 sets `source_id = register_id` from the working transaction (ADR-009 scope). Actor and store/register/session/period context are already bound on the working transaction.

This payload **does not** claim to be a completed operation and **does not** contain the permanent receipt until completion succeeds. Golden hashing fixtures live under `test/fixtures/files/pos/`.

### 2.3 `CompletedPosOperation` (canonical fact)

For Rails, constructed **inside** the authoritative completion transaction after receipt allocation and commercial freeze (not submitted as a pre-built external envelope).

```text
CompleteTransactionCommand
        ↓
authoritative completion
   ├── authorize + lease on command_payload_hash
   ├── allocate receipt
   ├── freeze commercial facts
   ├── construct CompletedPosOperation v1
   │         fact_type = pos.transaction_completed
   ├── persist normalized Core facts
   ├── persist pos_operations.envelope + envelope_hash
   ├── post paired Inventory effects
   ├── audit + pos.transaction_completed outbox
   └── mark operation completed
```

Envelope and Core must match; written atomically.

### 2.4 Future standalone

```text
Terminal local completion on behalf of a Register
   ├── allocate receipt locally
   └── construct CompletedPosOperation (compatible later version)
        ↓
synchronize
        ↓
central validation / posting
```

v1 commercial semantics remain the base; Terminal/config provenance is required in a later version before this path is authorized.

---

## 3. Versioning

```text
schema_version: 1
```

Additive keys may appear in later versions. Material semantic changes (sign rules, tax rate scale, identity fields) require a new version and explicit migration/compatibility notes.

---

## 4. Identity rules

| Field | Meaning |
|---|---|
| `operation.operation_id` | Identity of the **completion operation** |
| `operation.fact_type` | `pos.transaction_completed` (not the command type) |
| `transaction.transaction_id` | Identity of the **commercial transaction** |
| `receipt.sequence` / number snapshots / optional `reference` | Permanent human-facing receipt identity (`S…-R…-T…`) assigned at completion |

Never overload `transaction_id` as the completion idempotency key.

Idempotency (ADR-009 style on `pos_operations`):

```text
same (source_id, command_type, idempotency_key) + same command_payload_hash → same result
same key + different command_payload_hash → integrity failure
accepted envelope must match envelope_hash
```

---

## 5. Monetary and sign semantics

- All money fields are integer **cents** (or documented minor units) for the stated `currency_code`.
- **Magnitudes are positive.**
- `direction` on lines and tenders supplies economic sign.
- Line `quantity` is a JSON **integer** (not a decimal string) for Phase 4 quantity-tracked merchandise.

```text
sale line   → +extended / +tax toward amount due
return line → −extended / −tax (Phase 6; same magnitude fields)
payment     → funds in
refund      → funds out (later)
```

Do not store negative `line_total_cents` merely because `direction = return`.

Phase 4 examples use sale + payment only. The sign rule is locked now for Phase 6 compatibility.

---

## 6. Tax semantics

Authority: [pos-tax-contract.md](pos-tax-contract.md) and [ADR-019](../../../adr/ADR-019-pos-sales-tax-model.md).

### Line

```text
tax_class_id
tax_class_code   # merchandise classification, e.g. physical_book (envelope field name)
```

Normalized Core stores the same snapshot as `tax_class_code_snapshot`. Phase 4: applied Tax Class always equals merchandise Tax Class. No line-level treatment enum.

### Each Store Tax determination (`tax_components[]`)

Snapshot **every active** Store Tax for the store, including non-applicable:

```text
store_tax_id
store_tax_code
store_tax_name
rate_percent              # decimal string, e.g. "5.000" (numeric(6,3))
applies                   # boolean; non-null on completed facts
taxable_basis_cents       # basis when applies; else 0
tax_cents                 # rounded tax when applies; else 0
calculation_order
```

Do not omit `applies = false` rows. Do not use abstract `tax_component_id` or `treatment` enums.

### Rate precision

Sales-tax rates use `numeric(6,3)` / exact decimal strings. Not basis points. Not binary float.

---

## 7. Merchandise snapshot

Required on every completed line:

```json
{
  "sku": "2210000000001",
  "description": "Example Book",
  "tax_class_code": "physical_book"
}
```

Completed transactions and receipts must survive later merchandise renames and reclassifications.

---

## 8. Conceptual envelope shape

```text
CompletedPosOperation
│
├── schema_version
│
├── operation
│   ├── operation_id
│   └── fact_type                 # pos.transaction_completed
│
├── origin
│   ├── store_id
│   ├── register_id
│   ├── pos_session_id
│   ├── reporting_period_id
│   └── performed_by_user_id
│
├── receipt
│   ├── sequence                  # receipt_sequence
│   ├── store_number              # integer snapshot
│   ├── register_number           # integer snapshot (“Reg”)
│   └── reference                 # optional derived S003-R02-T0018427
│
├── transaction
│   ├── transaction_id
│   ├── currency_code
│   ├── occurred_at
│   ├── business_date
│   ├── subtotal_cents
│   ├── tax_cents
│   └── total_cents
│
├── lines[]
│   ├── line_id
│   ├── line_number
│   ├── direction                 # sale
│   ├── product_variant_id
│   ├── quantity                  # integer
│   ├── reference_unit_price_cents
│   ├── selling_unit_price_cents
│   ├── extended_selling_amount_cents
│   ├── line_tax_cents
│   ├── line_total_cents
│   ├── tax_class_id
│   ├── tax_class_code
│   ├── merchandise_snapshot
│   └── tax_components[]
│         ├── store_tax_id
│         ├── store_tax_code
│         ├── store_tax_name
│         ├── rate_percent            # "5.000"
│         ├── applies
│         ├── taxable_basis_cents
│         ├── tax_cents
│         └── calculation_order
│
└── tenders[]
    ├── tender_id
    ├── tender_type               # cash
    ├── direction                 # payment
    ├── amount_cents
    ├── amount_presented_cents
    └── change_cents
```

Do **not** use `operation_type` on the envelope; the completed fact uses `fact_type`. Command type lives only on the durable command/idempotency record.

---

## 9. Example (Phase 4 Cash sale)

Illustrative only. Includes both applicable and non-applicable Store Tax determinations.

```json
{
  "schema_version": 1,
  "operation": {
    "operation_id": "01920000-0000-7000-8000-000000000001",
    "fact_type": "pos.transaction_completed"
  },
  "origin": {
    "store_id": "01920000-0000-7000-8000-000000000010",
    "register_id": "01920000-0000-7000-8000-000000000020",
    "pos_session_id": "01920000-0000-7000-8000-000000000030",
    "reporting_period_id": "01920000-0000-7000-8000-000000000040",
    "performed_by_user_id": "01920000-0000-7000-8000-000000000050"
  },
  "receipt": {
    "sequence": 18427,
    "store_number": 3,
    "register_number": 2,
    "reference": "S003-R02-T0018427"
  },
  "transaction": {
    "transaction_id": "01920000-0000-7000-8000-000000000100",
    "currency_code": "USD",
    "occurred_at": "2026-08-16T18:04:22Z",
    "business_date": "2026-08-16",
    "subtotal_cents": 1999,
    "tax_cents": 105,
    "total_cents": 2104
  },
  "lines": [
    {
      "line_id": "01920000-0000-7000-8000-000000000200",
      "line_number": 1,
      "direction": "sale",
      "product_variant_id": "01920000-0000-7000-8000-000000000300",
      "quantity": 1,
      "reference_unit_price_cents": 1999,
      "selling_unit_price_cents": 1999,
      "extended_selling_amount_cents": 1999,
      "line_tax_cents": 105,
      "line_total_cents": 2104,
      "tax_class_id": "01920000-0000-7000-8000-000000000400",
      "tax_class_code": "physical_book",
      "merchandise_snapshot": {
        "sku": "2210000000001",
        "description": "Example Book",
        "tax_class_code": "physical_book"
      },
      "tax_components": [
        {
          "store_tax_id": "01920000-0000-7000-8000-000000000500",
          "store_tax_code": "state_illinois",
          "store_tax_name": "Illinois State",
          "rate_percent": "5.000",
          "applies": true,
          "taxable_basis_cents": 1999,
          "tax_cents": 100,
          "calculation_order": 1
        },
        {
          "store_tax_id": "01920000-0000-7000-8000-000000000510",
          "store_tax_code": "county_cook",
          "store_tax_name": "Cook County",
          "rate_percent": "0.250",
          "applies": true,
          "taxable_basis_cents": 1999,
          "tax_cents": 5,
          "calculation_order": 2
        },
        {
          "store_tax_id": "01920000-0000-7000-8000-000000000520",
          "store_tax_code": "local_schaumburg_prepared_food",
          "store_tax_name": "Schaumburg Prepared Food",
          "rate_percent": "2.000",
          "applies": false,
          "taxable_basis_cents": 0,
          "tax_cents": 0,
          "calculation_order": 3
        }
      ]
    }
  ],
  "tenders": [
    {
      "tender_id": "01920000-0000-7000-8000-000000000600",
      "tender_type": "cash",
      "direction": "payment",
      "amount_cents": 2104,
      "amount_presented_cents": 2500,
      "change_cents": 396
    }
  ]
}
```

Component taxes above assume half-up on `1999 × rate / 100` (`5.000%` → 100, `0.250%` → 5). Golden fixtures must compute with the same decimal rules.

---

## 10. Golden fixture set (minimum)

Portable fixtures live under `test/fixtures/files/pos/`:

| Path | Case |
|---|---|
| `tax_cases.json` | Tax cases from [pos-tax-contract.md](pos-tax-contract.md) §14, including `applies IS NULL` blocking completion |
| `completed_pos_operation_v1/cash_sale.json` | Full envelope including receipt after successful completion |
| `complete_transaction_command.json` plus `.canonical.json` / `.sha256` | Canonical command bytes and `command_payload_hash` |
| `completed_pos_operation_v1/cash_sale.canonical.json` / `.sha256` | Canonical envelope bytes and `envelope_hash` |

Quantity is a JSON integer. Replay uses the same command identity + `command_payload_hash` and must produce the same envelope hash.

These become the eventual Ruby / .NET parity suite.

---

## 11. Construction checklist (Rails completion)

Inside one PostgreSQL transaction (matches [operation-and-core-facts.md](operation-and-core-facts.md) §8):

1. Authorize actor (`pos.transact`) and validate Store/Register/Session/period/transaction consistency.  
2. Begin or reclaim `pos_operations` lease using `command_payload_hash` (ADR-009).  
3. Lock working transaction; validate expected `lock_version` and Cash settlement.  
4. Allocate `registers.receipt_sequence` under Register row lock; snapshot store/register numbers; derive optional compact `reference`.  
5. Freeze `occurred_at`, `business_date`, line snapshots, tax components, tender.  
6. Build `CompletedPosOperation` v1 with `fact_type = pos.transaction_completed` (must include receipt sequence and number snapshots).  
7. Canonicalize envelope; compute `envelope_hash`.  
8. Persist completed POS rows.  
9. Post paired Inventory physical + valuation effects via `Inventory::PostSale` (`reject_below_zero`).  
10. Record required audit and slim `pos.transaction_completed` outbox message.  
11. Store completed `pos_operations` with full envelope, `envelope_hash`, `fact_type`, and processing times (`received_at` / `posted_at`).  
12. Commit.  

On validation or commit failure: no completed transaction, no receipt consumption that escapes the failed transaction, no Inventory effect, no POS outbox fact. Envelope and Core must not partially diverge.

---

## 12. Non-goals for v1

- Return lines, discounts, approvals, suspend/recall, post-void  
- Card / Stored Value tenders  
- Customer identity  
- Receipt print layout (header presentation is specified in [receipt-identity.md](receipt-identity.md); rendering is Phase 5)  
- Offline sync transport framing (envelope remains the business payload; transport metadata must not enter the envelope — see [operation-and-core-facts.md](operation-and-core-facts.md))  
- Required Terminal / producer enrollment / reference-config provenance (later compatible version before standalone)  

Extensibility is preserved by versioning and by locking sign, tax-component, receipt, Register/Terminal, and envelope/Core dual-authority rules now—not by stuffing unused Phase 6 columns into v1.
