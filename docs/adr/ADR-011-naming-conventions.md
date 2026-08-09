# ADR-011: Database and domain naming conventions

- **Status:** Accepted
- **Date:** 2026-08-09

## Context

Inconsistent terminology creates schema ambiguity and makes APIs, documentation, and code harder to align.

## Decision

Use lowercase plural `snake_case` table names and business-oriented nouns. Primary keys are `id`; foreign keys are singular `_id`. Use `_cents` for cent-based money, `_basis_points` for basis points, `_quantity` for quantities, `_number` for human document numbers, `_external_id` for external identifiers, `_on` for dates, and `_at` for timestamps.

Stored status values are lowercase and machine-stable. UI labels may vary without changing stored values.

Standardize these terms:

- `supplier`, not alternating with vendor
- `cancelled`, with double “l”
- `return_to_supplier`
- `inventory_unit` for individually tracked physical stock
- `inventory_balance` for the mutable inventory projection
- `reserved`, not pending, for inventory commitment
- `completed` unless finalized or posted represents a genuinely distinct state
- `reversal_of_id` and `reversed_by_id` for compensating relationships

Prefer explicit foreign keys. Reserve polymorphic references mainly for audit and event subjects where the open-ended relationship is intentional.

## Consequences

- Schema and documentation have predictable vocabulary.
- Existing inconsistent names should be migrated deliberately rather than perpetuated.
- New terms must be added to the project glossary when their distinction is material.
