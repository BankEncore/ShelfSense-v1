# CompletedPosOperation v1

**Status:** Planning contract (Phase 4)

**Authority:** Canonical shape of a completed POS originating fact for Phase 4 Cash sales. Used by Rails completion today and by a future standalone Register after local completion.

Companions: [Phase 4 plan](phase4-plan.md), [Phase 4 schema](phase4-schema.md).

---

## 1. Purpose

`CompletedPosOperation` is the **interoperability and provenance boundary** for completed POS work.

It always describes an **already-completed** originating fact. Therefore it **always includes permanent receipt identity**.

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

Constructed **inside** the authoritative completion transaction after receipt allocation and commercial freeze.

```text
CompleteTransactionCommand
        ↓
authoritative completion
   ├── allocate receipt
   ├── freeze commercial facts
   └── construct CompletedPosOperation v1
        ↓
persist facts + Inventory + operation result
```

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
| `receipt.sequence` / `receipt.number` | Permanent receipt identity assigned at completion |

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

### Line

Preserves merchandise tax **classification**:

```text
tax_class_id
tax_class_code   # e.g. physical_book — never a treatment synonym
```

No line-level `tax_treatment`.

### Each tax component

```text
tax_component_id
tax_rule_id                 # if useful/available
component_code_snapshot
component_name_snapshot
treatment                   # taxable | exempt | zero_rated | …
rate_value                  # fixed-precision per Tax contract — not rate_basis_points
taxable_basis_cents
tax_cents
calculation_order
```

One tax class may yield different treatments under different components.

### Rate precision

Do not assume basis points. Rates such as `8.875%` require a Tax-contract-defined fixed scale. Until that contract locks, fixtures may express decimal percentages in test helpers, but persisted/canonical fields use `rate_value` as specified by Tax.

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
│   ├── sequence
│   └── number
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
│         ├── tax_component_id
│         ├── tax_rule_id
│         ├── component_code_snapshot
│         ├── component_name_snapshot
│         ├── treatment
│         ├── rate_value
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

Illustrative only; IDs and rates are placeholders. `rate_value` encoding must match the Tax contract when locked.

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
    "sequence": 1042,
    "number": "1-01-0001042"
  },
  "transaction": {
    "transaction_id": "01920000-0000-7000-8000-000000000100",
    "currency_code": "USD",
    "occurred_at": "2026-08-16T18:04:22Z",
    "business_date": "2026-08-16",
    "subtotal_cents": 1999,
    "tax_cents": 177,
    "total_cents": 2176
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
      "line_tax_cents": 177,
      "line_total_cents": 2176,
      "tax_class_id": "01920000-0000-7000-8000-000000000400",
      "tax_class_code": "physical_book",
      "merchandise_snapshot": {
        "sku": "2210000000001",
        "description": "Example Book",
        "tax_class_code": "physical_book"
      },
      "tax_components": [
        {
          "tax_component_id": "01920000-0000-7000-8000-000000000500",
          "tax_rule_id": "01920000-0000-7000-8000-000000000510",
          "component_code_snapshot": "state_sales",
          "component_name_snapshot": "State sales tax",
          "treatment": "taxable",
          "rate_value": "TAX_CONTRACT_SCALE_FOR_8.875_PERCENT",
          "taxable_basis_cents": 1999,
          "tax_cents": 177,
          "calculation_order": 1
        }
      ]
    }
  ],
  "tenders": [
    {
      "tender_id": "01920000-0000-7000-8000-000000000600",
      "tender_type": "cash",
      "direction": "payment",
      "amount_cents": 2176,
      "amount_presented_cents": 2500,
      "change_cents": 324
    }
  ]
}
```

Replace `rate_value` placeholder with the locked Tax encoding before calling fixtures implementation-ready.

---

## 10. Golden fixture set (minimum)

Portable fixtures (JSON preferred) covering:

| # | Case |
|---|---|
| 1 | No-tax / exempt or empty components as designed |
| 2 | One taxable component |
| 3 | Multiple non-compounded components |
| 4 | Fractional-cent rounding (half-up to cents) |
| 5 | Quantity > 1 |
| 6 | Exempt treatment on a component |
| 7 | Zero-rated treatment on a component |
| 8 | Rate needing finer precision than 0.01% (depends on Tax scale) |
| 9 | Full envelope including receipt after successful completion |
| 10 | Idempotent replay: same `operation_id` + payload → identical envelope / result |

These become the eventual Ruby / .NET parity suite.

---

## 11. Construction checklist (Rails completion)

Inside one PostgreSQL transaction:

1. Validate working transaction and Cash settlement.  
2. Begin or reclaim `pos_operations` lease (ADR-009 semantics).  
3. Allocate `receipt.sequence` / `receipt.number`.  
4. Freeze `occurred_at`, `business_date`, line snapshots, tax components, tender.  
5. Build `CompletedPosOperation` v1 (must include receipt).  
6. Persist completed POS rows.  
7. Post Inventory effects for each sale line.  
8. Store operation result / envelope reference.  
9. Commit.  

On validation or commit failure: no completed transaction, no receipt consumption that escapes the failed transaction, no Inventory effect.

---

## 12. Non-goals for v1

- Return lines, discounts, approvals, suspend/recall, post-void  
- Card / Stored Value tenders  
- Customer identity  
- Receipt print layout  
- Offline sync transport framing (envelope remains the business payload later)  

Extensibility is preserved by versioning and by locking sign, tax-component, and receipt rules now—not by stuffing unused Phase 6 columns into v1.
