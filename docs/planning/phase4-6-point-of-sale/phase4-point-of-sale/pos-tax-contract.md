# POS tax contract

**Status:** Accepted for Phase 4 planning (implements [ADR-019](../../../adr/ADR-019-pos-sales-tax-model.md))

**Authority:** Ordinary U.S. retail sales-tax configuration and POS calculation. Prefer this document and ADR-019 over earlier generalized tax-treatment drafts and over conflicting Phase 4 outline wording.

Companions: [phase4-plan.md](phase4-plan.md), [phase4-schema.md](phase4-schema.md), [completed-pos-operation-v1.md](completed-pos-operation-v1.md).

---

## 1. Purpose

POS tax answers, for each transaction line:

> Which taxes configured for this store apply to this merchandise, and how much tax does each applicable tax produce?

Calculation is line-based, deterministic, and historically preserved. A completed transaction must explain tax without consulting current configuration.

---

## 2. Governing model

```text
Tax Class
    ↓
What kind of merchandise is this for tax purposes?

Store Tax
    ↓
What independently calculated tax exists at this store?

Store Tax Rule
    ↓
Does this Store Tax apply to this Tax Class? (true / false / unresolved)
```

**Store Tax is the tax component.** There is no separate abstract `tax_component` model.

Example (illustrative Schaumburg store): several independent Store Taxes (state, county, local, home rule, prepared food, …). A `physical_book` class may apply to some and not others. Any displayed combined rate (e.g. 10.000%) is **derived** and not authoritative configuration.

---

## 3. Tax Classes

- Owned by the merchandise domain (`tax_classes` already exists).
- Classify merchandise; they do **not** store a tax percentage.
- Product variants carry a default Tax Class.
- Phase 4 **consumes** existing merchandise Tax Classes. It does not add speculative POS-only classes.
- Do **not** introduce a synthetic `nontaxable` class merely to encode a tax result. Non-applicability is expressed with Store Tax Rules (`applies = false`), keeping the real merchandise classification (e.g. `physical_periodicals`).

---

## 4. Store Taxes

Each store defines the individual taxes that may apply there.

| Field | Notes |
|---|---|
| `id` | UUIDv7 |
| `store_id` | FK |
| `code` | stable store-scoped code |
| `name` | display name |
| `rate_percent` | `numeric(6,3)` |
| `active` | inactive taxes are not used for new calculations |
| `calculation_order` | deterministic evaluation / display order |
| `lock_version` | mutable config concurrency |
| timestamps | |

Store Taxes are separately calculated components. ShelfSense does not reduce them to one synthetic combined store rate for authority.

---

## 5. Tax rates

Maximum precision: three decimal places of percentage.

```text
PostgreSQL    numeric(6,3)
Ruby          BigDecimal
.NET          decimal
POS contracts "1.250"   # exact decimal string field rate_percent
```

Binary floating point must not be used for authoritative tax calculation. Do not store sales-tax rates as basis points.

---

## 6. Store Tax Rules

```text
Store Tax + Tax Class → applies TRUE | FALSE | NULL
```

| `applies` | Meaning |
|---|---|
| `true` | Intentionally applies |
| `false` | Intentionally does not apply |
| `NULL` | Not reviewed; configuration incomplete |

A missing decision must not silently mean tax-free.

### Auto-create rows

When a Store Tax is created:

```text
for each active Tax Class
→ create store_tax_rule (applies NULL unless a controlled seed sets otherwise)
```

When a Tax Class becomes available for sale configuration:

```text
for each store
  for each active Store Tax
  → create store_tax_rule if absent (applies NULL)
```

Unique constraint: `(store_tax_id, tax_class_id)`.

### Sellability / completion

For a line’s Tax Class at a store:

```text
every active Store Tax must have a rule with applies IS NOT NULL
```

Otherwise reject add-to-transaction or completion (implementation may choose the earliest hard gate; completion must always enforce it).

---

## 7. Calculation

### Phase 4 taxable basis

```text
taxable basis = extended_selling_amount_cents
```

Discounts and price overrides are not in Phase 4. Documented durable order for later:

```text
selling amount → discounts → net taxable basis → component tax
```

### Per active Store Tax (calculation_order)

```text
rule = rule_for(store_tax, tax_class)
reject if rule.applies IS NULL

if rule.applies
  basis = line taxable basis
  tax_cents = half_up(basis × rate_percent / 100)
else
  basis = 0
  tax_cents = 0

snapshot component determination (including applies = false)
```

Rounding: decimal half-up to whole cents per component. No binary float.

```text
line.tax_cents = Σ component.tax_cents
transaction.tax_cents = Σ line.tax_cents
```

Never: sum rates → one aggregate tax as authority.

### Snapshot set

For each completed line, persist a determination for **every Store Tax that was active for that store at calculation time**, not only applicable ones.

Applicable:

```text
applies = true
taxable_basis_cents = <basis>
tax_cents = <rounded tax>
```

Non-applicable:

```text
applies = false
taxable_basis_cents = 0
tax_cents = 0
```

Rate and name/code snapshots are retained in both cases so history explains the determination.

---

## 8. Phase 4 line classification

```text
tax_class_id
tax_class_code_snapshot
```

Always:

```text
applied Tax Class = merchandise Tax Class
```

Do **not** add `default_tax_class_id` / `applied_tax_class_id` until Tax Class override exists.

---

## 9. Explicitly out of Phase 4 (compatible later)

| Deferred | Notes |
|---|---|
| Tax Class override | Controlled action: reason, permission, approval, UX, recalc, audit |
| Purchaser / certificate exemption | Distinct from Tax Class; do not fake with a nontaxable class |
| Tax profiles / templates | Seed helpers OK; no `tax_profiles` domain yet |
| Effective-dated / superseded Store Tax versions | Completed snapshots already protect history |
| Arbitrary cashier rate entry | Forbidden |
| Component toggle at Register | Forbidden |
| VAT/GST zero-rating semantics, tax-inclusive pricing, compounding | Out of initial model |
| Remittance journals / filing | Out of POS completion |

---

## 10. Returns (Phase 6+)

Linked returns reverse **original completed component facts**. They do not recalculate using current Store Taxes or current merchandise Tax Class.

Partial returns consume original per-component `tax_cents` and residual cents through `Pos::HistoricalReturnAllocation` ([returns.md](../../phase6-pos-mvp/returns.md) §11). The final eligible return takes leftover cents. Unlinked returns use current `Pos::Tax::Calculate` (6.5C).

---

## 11. Configuration tables (Phase 4)

```text
tax_classes                 # existing merchandise domain

store_taxes
├── id, store_id, code, name
├── rate_percent numeric(6,3)
├── active, calculation_order
├── lock_version, timestamps

store_tax_rules
├── id, store_tax_id, tax_class_id
├── applies boolean NULL-able
├── lock_version, timestamps
└── UNIQUE(store_tax_id, tax_class_id)
```

---

## 12. Completed component rows

```text
pos_line_tax_components
├── id
├── pos_transaction_line_id
├── store_tax_id
├── store_tax_code_snapshot
├── store_tax_name_snapshot
├── rate_percent numeric(6,3)
├── applies boolean              # non-null on completed rows
├── taxable_basis_cents
├── tax_cents
├── calculation_order
└── timestamps
```

Optional: persist `store_tax_rule_id` used at calculation time for provenance; not required if snapshots are complete.

---

## 13. Contract / envelope fields

In `CompletedPosOperation` v1, each line’s `tax_components[]` entries use Store Tax identity:

```text
store_tax_id
store_tax_code
store_tax_name
rate_percent          # decimal string, e.g. "5.000"
applies               # boolean
taxable_basis_cents
tax_cents
calculation_order
```

---

## 14. Golden fixtures (minimum)

1. All active Store Taxes `applies = false` → line tax 0 with full determination rows  
2. One applicable component  
3. Multiple independent applicable components  
4. Mix of applicable and non-applicable components on one line  
5. Fractional-cent half-up rounding  
6. Quantity > 1  
7. `applies IS NULL` blocks completion  
8. Rate with three decimal places (e.g. `0.250`, `1.750`)  
9. Idempotent completion replay preserves identical component facts  

---

## 15. Governing principles

> Each store defines the individual taxes that may be charged there. Rules explicitly determine which of those taxes apply to each merchandise Tax Class. POS calculates every active Store Tax determination from the line’s taxable basis, rounds each component independently, and preserves applicable and non-applicable results when the transaction completes.

> Tax Class describes merchandise. It is not a place to encode tax results. Purchaser exemptions and cashier classification overrides are separate future concepts.

> Completed tax is historical fact. Current rates, classes, and rules must never recalculate a completed transaction or linked return.
