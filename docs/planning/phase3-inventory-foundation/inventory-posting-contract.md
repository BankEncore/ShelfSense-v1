# Inventory posting service contract

Status: Implemented with Phase 3 adjustments and Phase 4 POS sales.

Later purchasing, POS, transfer, reservation, and disposition workflows must post physical and valuation effects only through the named inventory posting services. Controllers, callbacks, imports, and future workflows must not update `inventory_balances` directly.

## Named posting services

| Service | Use | Outbox event |
|---|---|---|
| `Inventory::PostAdjustment` | Manual/reasoned quantity or unit adjustments | `inventory.adjustment_posted` |
| `Inventory::ReverseAdjustment` | Exact compensating reversal of a posted adjustment | (existing reversal outbox/audit) |
| `Inventory::PostSale` | Completed POS sale-line depletion | `inventory.sale_posted` |

`Inventory::PostSale` must not call `Inventory::PostAdjustment`, must not emit `inventory.adjustment_posted`, and must not require `adjustment_reason`. Duplicate protection is the unique `(source_type, source_id, effect_sequence)` constraint on ledger and valuation rows.

## `Inventory::PostSale`

Inner posting kernel. It joins the **caller's** transaction and does not open an independently committable transaction.

Required inputs (received from completion; not re-derived):

- completed sale `line` (`PosTransactionLine`)
- `occurred_at`
- `business_date`
- `actor`

Per line:

```text
quantity_delta = −quantity
reject_below_zero
source_type = "PosTransactionLine"
source_id   = line.id
```

Quantity-tracked Standard merchandise only in Phase 4. Pair integrity after write:

```text
physical.store == valuation.store
physical.variant == valuation.variant
physical.quantity == valuation.quantity
physical.source == valuation.source
physical.occurred_at == valuation.occurred_at
physical.business_date == valuation.business_date
```

`pos.transaction_completed` describes the commercial operation. `inventory.sale_posted` describes the stock/valuation change and is written in the same outer transaction.

## `Inventory::PostAdjustment` required inputs

- `store`, `product_variant`, `adjustment_reason`, signed `quantity_delta`
- ADR-009 `source_id` + `idempotency_key` + canonical payload
- `actor` (Phase 3 UI: user)
- `negative_stock_policy`: `reject_below_zero` only in Phase 3. `allow_below_zero` is an ADR-014 future extension and is rejected if supplied.
- optional: unit fields for individual tracking, notes, `occurred_at` with `allow_backdate` (`inventory.backdate`). Without that permission the server ignores a supplied `occurred_at` and uses current time. Future timestamps are rejected.

## Atomic effects (adjustment)

One transaction writes: posted adjustment, physical ledger entry, valuation ledger entry, unit create/remove when applicable, balance update, audit event, outbox event, and idempotency completion.

## Tracking

Uses `ProductVariant#derived_inventory_tracking`. Rejects `non_inventory` / nil. Does not add a persisted tracking column.
