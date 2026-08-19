# Inventory posting service contract

Status: Implemented with Phase 3 adjustments, Phase 4 quantity-tracked POS sales, and Phase 6 Slice 6.1 individual unit sales. Slice 6.5 `Inventory::PostReturn` is specified in [returns.md](../phase4-6-point-of-sale/phase6-pos-mvp/returns.md) and is not yet implemented.

Later purchasing, POS, transfer, reservation, and disposition workflows must post physical and valuation effects only through the named inventory posting services. Controllers, callbacks, imports, and future workflows must not update `inventory_balances` directly.

## Named posting services

| Service | Use | Outbox event |
|---|---|---|
| `Inventory::PostAdjustment` | Manual/reasoned quantity or unit adjustments | `inventory.adjustment_posted` |
| `Inventory::ReverseAdjustment` | Exact compensating reversal of a posted adjustment | (existing reversal outbox/audit) |
| `Inventory::PostSale` | Completed POS sale-line depletion | `inventory.sale_posted` |
| `Inventory::PostReturn` | Completed POS return-line restore (6.5) | `inventory.return_posted` |

`Inventory::PostSale` and `Inventory::PostReturn` must not call `Inventory::PostAdjustment`, must not emit `inventory.adjustment_posted`, and must not require `adjustment_reason`. Duplicate protection is the unique `(source_type, source_id, effect_sequence)` constraint on ledger and valuation rows.

## `Inventory::PostSale`

Inner posting kernel. It joins the **caller's** transaction and does not open an independently committable transaction.

Required inputs (received from completion; not re-derived):

- completed sale `line` (`PosTransactionLine`)
- `occurred_at`
- `business_date`
- `actor`

Per line:

```text
quantity tracking     quantity_delta = −quantity; moving-average depletion
individual tracking   quantity_delta = −1; specific-identification on the exact inventory_unit;
                      on_hand → removed; ledger/valuation inventory_unit_id set
non_inventory         do not call PostSale
reject_below_zero
source_type = "PosTransactionLine"
source_id   = line.id
```

`Pos::CompleteTransaction` skips `Inventory::PostSale` for `non_inventory` lines. Calling `PostSale` directly with non-inventory merchandise is an error. Do not call `Inventory::PostAdjustment` from the sale path.

Quantity-tracked Standard, individually tracked Used, and skip-for-non-inventory are the Phase 6 Slice 6.1 sale posting set. Pair integrity after write:

```text
physical.store == valuation.store
physical.variant == valuation.variant
physical.inventory_unit_id == valuation.inventory_unit_id
physical.quantity == valuation.quantity
physical.source == valuation.source
physical.occurred_at == valuation.occurred_at
physical.business_date == valuation.business_date
```

`pos.transaction_completed` describes the commercial operation. `inventory.sale_posted` describes the stock/valuation change and is written in the same outer transaction.

Individual-sale lock order matches `PostAdjustment`:

```text
InventoryBalance   # FOR UPDATE (lock_or_create)
InventoryUnit      # FOR UPDATE
```

`CompleteTransaction` must not hold an `InventoryUnit` row lock before posting. Freeze-time unit checks are non-locking; posting is the authoritative locked validation. A unit that leaves `on_hand` between freeze and posting rolls the whole completion back.

## `Inventory::PostReturn`

Named 6.5 boundary, parallel to `PostSale`. Joins the **caller's** transaction. Do not call `PostAdjustment`. Authority: [returns.md](../phase4-6-point-of-sale/phase6-pos-mvp/returns.md) §12 / §15.

Required inputs (received from completion; not re-derived):

- completed return `line` (`PosTransactionLine`, `direction = return`)
- `occurred_at`
- `business_date`
- `actor`

Lock order matches `PostSale`:

```text
InventoryBalance   # FOR UPDATE (lock_or_create)
InventoryUnit      # FOR UPDATE when individual
```

Lock the unit **inside** `PostReturn`, not before freeze.

Per line:

```text
quantity tracking, linked     quantity_delta = +returned qty;
                              restore allocated original sale depletion
                              (source_type = PosTransactionLine, source_id = original sale line)
quantity tracking, unlinked   on_hand > 0 → ROUND_HALF_UP(inventory_value × qty / on_hand)
                              on_hand = 0 → latest valuation entry only:
                              iff calculation_metadata.prior_quantity > 0
                              incoming = ROUND_HALF_UP(prior_value × qty / prior_quantity);
                              else reject
individual                    restore using original sale valuation when linked
                              (write that restored amount onto carrying_value_cents);
                              unlinked: restore the known removed unit at carrying_value_cents;
                              removed → on_hand; removed_at = NULL
non_inventory                 do not call PostReturn
source_type = "PosTransactionLine"
source_id   = return line.id
entry_type  = return
valuation   = acquisition (stock in)
```

`Pos::CompleteTransaction` skips `Inventory::PostReturn` for `non_inventory` lines. Customer refund price never writes inventory value. Outbox/audit `inventory.return_posted`.

## `Inventory::PostAdjustment` required inputs

- `store`, `product_variant`, `adjustment_reason`, signed `quantity_delta`
- ADR-009 `source_id` + `idempotency_key` + canonical payload
- `actor` (Phase 3 UI: user)
- `negative_stock_policy`: `reject_below_zero` only in Phase 3. `allow_below_zero` is an ADR-014 future extension and is rejected if supplied.
- optional: unit fields for individual tracking, notes, `occurred_at` with `allow_backdate` (`inventory.backdate`). Without that permission the server ignores a supplied `occurred_at` and uses current time. Future timestamps are rejected.

## Atomic effects (adjustment)

One transaction writes: posted adjustment, physical ledger entry, valuation ledger entry, unit create/remove when applicable, balance update, audit event, outbox event, and idempotency completion.

## Tracking

Uses `ProductVariant#derived_inventory_tracking`. `PostAdjustment` rejects `non_inventory` / nil. `PostSale` and `PostReturn` accept `quantity` and `individual` and reject `non_inventory` / nil. Does not add a persisted tracking column. Unit lifecycle remains `on_hand | removed`; POS sales are distinguished by ledger `entry_type = sale` and `source_type = PosTransactionLine`; POS returns use `entry_type = return`.
