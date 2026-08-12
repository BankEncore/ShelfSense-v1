# Inventory posting service contract

Status: Implemented with Phase 3.

Later purchasing, POS, transfer, reservation, and disposition workflows must post physical and valuation effects only through `Inventory::PostAdjustment` (and related services such as `Inventory::ReverseAdjustment`). Controllers, callbacks, imports, and future workflows must not update `inventory_balances` directly.

## Required inputs

- `store`, `product_variant`, `adjustment_reason`, signed `quantity_delta`
- ADR-009 `source_id` + `idempotency_key` + canonical payload
- `actor` (Phase 3 UI: user)
- `negative_stock_policy`: `reject_below_zero` only in Phase 3. `allow_below_zero` is an ADR-014 future extension and is rejected if supplied.
- optional: unit fields for individual tracking, notes, `occurred_at` with `allow_backdate` (`inventory.backdate`). Without that permission the server ignores a supplied `occurred_at` and uses current time. Future timestamps are rejected.

## Atomic effects

One transaction writes: posted adjustment, physical ledger entry, valuation ledger entry, unit create/remove when applicable, balance update, audit event, outbox event, and idempotency completion.

## Tracking

Uses `ProductVariant#derived_inventory_tracking`. Rejects `non_inventory` / nil. Does not add a persisted tracking column.
