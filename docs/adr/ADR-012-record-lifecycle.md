# ADR-012: Editing, supersession, reversal, and deletion

- **Status:** Accepted
- **Date:** 2026-08-09

## Context

Different record categories require different correction behavior. Treating every change as an edit destroys history, while making every descriptive correction append-only creates unnecessary complexity.

## Decision

Apply this governing rule:

> Draft intent may be edited. Effective configuration is superseded. Completed business facts are reversed or corrected through new records.

Descriptive product and customer state may be edited, with audit where material. Future draft prices, tax rules, mappings, and purchasing documents may be edited. Once effective, rules are end-dated and succeeded. Once completed or posted, POS transactions, tenders, cash movements, inventory ledger entries, receipts, journal entries, stored-value entries, and similar consequential facts are not edited; corrections use linked compensating records.

Material changes to a product variant's trade identity, package, unit of sale, tracking mode, or core tax/accounting behavior supersede the variant rather than silently redefining past sales.

Do not apply `deleted_at` indiscriminately. Prefer explicit lifecycle attributes such as inactive, discontinued, revoked, expired, or cancelled. Physical deletion is limited to unused drafts, unreferenced errors, temporary technical data, and authorized privacy cleanup.

## Consequences

- Historical business meaning remains reconstructable.
- Reports must understand successors, reversals, and effective ranges.
- Workflows need explicit correction operations rather than generic edit screens.
- Harmless descriptive corrections remain practical.
