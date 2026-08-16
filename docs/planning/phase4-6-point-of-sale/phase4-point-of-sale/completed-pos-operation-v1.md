# CompletedPosOperation v1

**Status:** Planning contract (Phase 4)

**Authority:** Canonical shape of a completed POS originating fact for Phase 4 Cash sales. Used by Rails completion today and by a future standalone Register after local completion. Dual authority with normalized Core: [operation-and-core-facts.md](operation-and-core-facts.md) / [ADR-020](../../../adr/ADR-020-pos-operation-envelope-and-core-facts.md).

Companions: [Phase 4 plan](phase4-plan.md), [Phase 4 schema](phase4-schema.md), [operation-and-core-facts.md](operation-and-core-facts.md).

---

## 1. Purpose

`CompletedPosOperation` is the **immutable canonical representation** of a commercial transaction as established by the originating Register (or Rails completion path). It is a complete commercial payload plus operation provenance — not mere metadata.

It always describes an **already-completed** originating fact and therefore **always includes permanent receipt identity**.

Normalized Core tables materialize the same commercial facts for ordinary business use. No required commercial behavior may depend on parsing the stored envelope. The envelope must remain sufficient to rematerialize Core; Core must remain sufficient to run the business without the envelope.

It is not the Rails UI form payload. It is not a draft. It is not “almost complete pending receipt.”

---

## 2. Command vs completed operation

### 2.1 `CompleteTransactionCommand` (internal / client request)

Input that asks the authority to complete a working transaction. May include:

- working `transaction_id`
- `operation_id` / idempotency key (client-generated UUIDv7)
- expected totals / tender presentation for validation
- actor and context already bound on the working transaction

This payload **does not** claim to be a completed operation and **does not** contain the permanent receipt until completion succeeds.

### 2.2 `CompletedPosOperation` (canonical fact)

For Rails, constructed **inside** the authoritative completion transaction after receipt allocation and commercial freeze (not submitted as a pre-built external envelope).

```text
CompleteTransactionCommand
        ↓
authoritative completion
   ├── allocate receipt
   ├── freeze commercial facts
   ├── construct CompletedPosOperation v1
   ├── persist normalized Core facts
   ├── persist pos_operations.envelope + payload_hash
   └── post Inventory / reporting effects
```

Envelope and Core must match; written atomically.

### 2.3 Future standalone

```text
local CompleteTransaction
   ├── allocate receipt locally
   └── construct CompletedPosOperation v1
        ↓
synchronize
        ↓
central validation / posting
```

Both origins produce materially the same completed fact.

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
| `transaction.transaction_id` | Identity of the **commercial transaction** |
| `receipt.sequence` / number snapshots / optional `reference` | Permanent human-facing receipt identity (`S…-R…-T…`) assigned at completion |

Never overload `transaction_id` as the completion idempotency key.

Idempotency (ADR-009 style on `pos_operations`):

```text
same operation identity + same material payload hash → same result
same operation identity + different payload hash → integrity failure
```

---

## 5. Monetary and sign semantics

- All money fields are integer **cents** (or documented minor units) for the stated `currency_code`.
- **Magnitudes are positive.**
- `direction` on lines and tenders supplies economic sign.

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
tax_class_code   # merchandise classification, e.g. physical_book
```

Phase 4: applied Tax Class always equals merchandise Tax Class. No line-level treatment enum.

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
│   └── operation_type          # e.g. pos.complete_transaction
│
├── origin
│   ├── store_id
│   ├── workstation_id
│   ├── pos_session_id
│   ├── reporting_period_id
│   └── performed_by_user_id
│
├── receipt
│   ├── sequence                  # receipt_sequence
│   ├── store_number              # snapshot
│   ├── workstation_number        # snapshot (“Reg”)
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
│   ├── quantity
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

---

## 9. Example (Phase 4 Cash sale)

Illustrative only. Includes both applicable and non-applicable Store Tax determinations.

```json
{
  "schema_version": 1,
  "operation": {
    "operation_id": "01920000-0000-7000-8000-000000000001",
    "operation_type": "pos.complete_transaction"
  },
  "origin": {
    "store_id": "01920000-0000-7000-8000-000000000010",
    "workstation_id": "01920000-0000-7000-8000-000000000020",
    "pos_session_id": "01920000-0000-7000-8000-000000000030",
    "reporting_period_id": "01920000-0000-7000-8000-000000000040",
    "performed_by_user_id": "01920000-0000-7000-8000-000000000050"
  },
  "receipt": {
    "sequence": 18427,
    "store_number": "003",
    "workstation_number": "02",
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
      "quantity": "1",
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

Portable fixtures (JSON preferred) covering tax cases in [pos-tax-contract.md](pos-tax-contract.md) §14, plus:

| # | Case |
|---|---|
| … | Full envelope including receipt after successful completion |
| … | Idempotent replay: same `operation_id` + payload → identical envelope / result |

These become the eventual Ruby / .NET parity suite.

---

## 11. Construction checklist (Rails completion)

Inside one PostgreSQL transaction:

1. Validate working transaction and Cash settlement.  
2. Begin or reclaim `pos_operations` lease (ADR-009 semantics).  
3. Allocate `receipt_sequence`; snapshot store/workstation numbers; derive optional compact `reference`.  
4. Freeze `occurred_at`, `business_date`, line snapshots, tax components, tender.  
5. Build `CompletedPosOperation` v1 (must include receipt sequence and number snapshots).  
6. Persist completed POS rows.  
7. Post Inventory effects for each sale line.  
8. Store `pos_operations` with full envelope, payload hash, and idempotency completion (`received_at` / `posted_at` as Core processing times).  
9. Commit.  

On validation or commit failure: no completed transaction, no receipt consumption that escapes the failed transaction, no Inventory effect. Envelope and Core must not partially diverge.

---

## 12. Non-goals for v1

- Return lines, discounts, approvals, suspend/recall, post-void  
- Card / Stored Value tenders  
- Customer identity  
- Receipt print layout (header presentation is specified in [receipt-identity.md](receipt-identity.md); rendering is Phase 5)  
- Offline sync transport framing (envelope remains the business payload; transport metadata must not enter the envelope — see [operation-and-core-facts.md](operation-and-core-facts.md))  
- Required `installation_id` / producer fields (optional until installations exist)  

Extensibility is preserved by versioning and by locking sign, tax-component, receipt, and envelope/Core dual-authority rules now—not by stuffing unused Phase 6 columns into v1.
