# ADR-019: U.S. retail sales-tax model for POS

- **Status:** Accepted
- **Date:** 2026-08-16
- **Related:** [ADR-007](ADR-007-money-rates-and-time.md), [POS tax contract](../planning/phase4-6-point-of-sale/phase4-point-of-sale/pos-tax-contract.md)

## Context

POS must answer, for each transaction line: which taxes configured for this store apply to this merchandise, and how much tax each applicable tax produces.

Completed transactions must retain enough tax detail to explain the result without consulting current configuration. Linked returns must reverse historical component facts, not recalculate from current rates.

A generalized international tax engine (VAT treatments, tax-inclusive pricing, compounding, cashier-entered rates) is not required for the initial ShelfSense POS. An earlier draft considered separate abstract tax components and multi-valued treatments (`taxable` / `exempt` / `zero_rated`). That over-generalized the U.S. sales-tax case and left rate precision unsettled relative to ADR-007 basis points.

## Decision

1. **Three configuration concepts only**
   - `Tax Class` — merchandise classification for tax purposes (merchandise-domain authority; not a tax percentage).
   - `Store Tax` — an independently calculated tax that may apply at a store (code, name, `rate_percent`, order, active).
   - `Store Tax Rule` — whether a given Store Tax applies to a given Tax Class.

2. **Store Tax is the POS tax component.** There is no separate abstract `tax_component` entity. Completed line tax rows snapshot the resolved Store Tax.

3. **Applicability is a nullable boolean**, not a treatment enum:
   - `applies = true` — configured applicable
   - `applies = false` — configured not applicable
   - `applies IS NULL` — not reviewed; configuration incomplete; that Tax Class must not be sold/completed at the store until resolved

   Auto-create rule rows when Store Taxes or Tax Classes appear so incompleteness is explicit rows, not missing joins. Prefer unresolved (`NULL`) defaults over silently defaulting `true` or `false`.

4. **Tax rates** use ADR-007’s finer-precision path: PostgreSQL `numeric(6,3)` (percentage with up to three decimal places). Application math uses exact decimals (`BigDecimal` / .NET `decimal`). Versioned POS contracts serialize rates as exact decimal strings (e.g. `"1.250"`). Do not use basis points or binary floating point for authoritative sales-tax rates.

5. **Calculation:** independently for each active Store Tax, half-up to whole cents on the line taxable basis; transaction tax is the sum of rounded component amounts. Never sum rates then compute one aggregate tax as authority. Derived combined rates are informational only.

6. **Completed history snapshots every active Store Tax determination** for the line (including `applies = false` with zero basis/tax), so absence of a component is not later ambiguous.

7. **Phase 4 scope locks:** ordinary sale tax only; taxable basis = extended selling amount; applied Tax Class equals merchandise Tax Class; no Tax Class override, purchaser exemption, tax profiles domain, effective-dated rates, or cashier rate edits in the initial implementation. Those remain compatible extensions.

## Consequences

- Admin configuration is a store tax list plus an explicit class matrix; sellability can require all active Store Taxes to have non-null `applies` for the line’s Tax Class.
- POS, audit, remittance explanation, and future standalone Registers share one component model.
- Returns reverse stored component economics; rate or Tax Class changes after sale do not rewrite history.
- ADR-007 remains general money/percentage policy; this ADR specializes sales-tax rate storage and POS applicability semantics.
- Detailed calculator, schema outline, fixtures, and deferred work live in the [POS tax contract](../planning/phase4-6-point-of-sale/phase4-point-of-sale/pos-tax-contract.md).
