# ADR-007: Money, percentages, dates, and timestamps

- **Status:** Accepted
- **Date:** 2026-08-09

## Context

Financial correctness requires exact arithmetic, explicit rounding, and a distinction between business dates and event instants.

## Decision

Store authoritative monetary values as signed integer minor units, normally cents, with currency context at the installation or document level. Use names such as `unit_price_cents` and `tax_amount_cents`. Binary floating point is prohibited for authoritative financial calculations. Division, allocation, and rounding rules must be explicit, and authoritative rounded outcomes are stored.

Store conventional percentages as integer basis points where precision permits: 10,000 basis points equals 100 percent. Use fixed-scale decimals or finer integer units when a rule genuinely requires more precision.

Use database `date` values for calendar concepts such as `business_date`, effective dates, and expected delivery dates. Use timezone-aware timestamps stored as UTC instants for events. Retain the store's IANA timezone and the applicable business date where operationally relevant. Partial publication dates retain their precision rather than inventing missing components.

## Consequences

- Equality and addition remain exact.
- Currency scale and rounding behavior must be known by every calculating component.
- Credits and reversals use signed amounts where meaningful; constraints follow business meaning rather than blanket non-negativity.
- A business date is assigned explicitly and is not later inferred from `created_at`.
- U.S. retail sales-tax rates for POS use `numeric(6,3)` percentage storage per [ADR-019](ADR-019-pos-sales-tax-model.md) rather than basis points.
