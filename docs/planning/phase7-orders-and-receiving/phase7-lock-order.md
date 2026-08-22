# Phase 7 — Command lock order

## Status

Accepted for Phase 7 implementation. Reconcile with existing POS and Inventory service kernels during Slice 7.2 before coding reservation-bearing commands.

Authority: [phase7-spec.md](phase7-spec.md) §7.14 / §15, [inventory-posting-contract.md](../phase3-inventory-foundation/inventory-posting-contract.md).

## Principles

- **Standard** serialization point is a locked `InventoryBalance` for the `(store, variant)` pair.
- **Used** keeps the existing `InventoryBalance → InventoryUnit` order.
- Locate and ordinary sale must acquire the **same** inventory serialization before deciding who gets the last available copy or unit.
- Availability is evaluated under those locks; reject Standard `available < 0` or removal of an allocated Used unit unless the same atomic command releases, reverses, or transfers that allocation.
- Outer purchasing/POS aggregates are locked before inventory rows when the command owns those aggregates, in an order that does not invert the inventory kernel.

## Command matrix

| Command | Required locks, in order |
|---|---|
| Confirm Standard location | `InventoryBalance` → `customer_request` → allocation |
| Confirm Used location | `InventoryBalance` → `InventoryUnit` → `customer_request` → allocation |
| Ordinary sale | existing POS aggregate locks → `InventoryBalance` → `InventoryUnit` when Used |
| Customer pickup | existing POS aggregate → `InventoryBalance` → `InventoryUnit` when Used → allocation / request |
| Negative adjustment | `InventoryBalance` → `InventoryUnit` when Used |
| Post special-order receipt | purchasing receipt aggregate → `InventoryBalance` → request / allocation |
| Cancel request | `customer_request` → allocation → `InventoryBalance` when releasing a Standard reservation (and `InventoryUnit` when releasing Used) |
| Reverse receipt | correction / receipt → `InventoryBalance` → request / allocation |
| Depleting post-void | match existing `Inventory::PostPostVoid` order + availability check under balance lock |

## Notes

### Cancel request (chosen order)

Chosen order is **request → allocation → inventory**. Release allocation state first under the request/allocation locks, then take `InventoryBalance` (and `InventoryUnit` when Used) so availability projection and any balance-touching side effects stay consistent with the released allocation. Do not lock inventory before the request if that would invert other cancel paths that only need request-state mutation; when inventory must be touched, always finish with the Standard/Used inventory order above.

### Competing locate vs ordinary sale

Two `pending_location` locates, or a locate racing an ordinary sale, must not decide “last copy” without sharing inventory serialization. First successful command that commits under the locked balance (and unit when Used) wins; losers fail with a current-state explanation.

### Pickup exception (Slice 7.6)

Ordinary sale capacity uses `available` only. Pickup may consume `available` plus the quantity allocated to that POS line, and only after locking the allocation/request after inventory locks as in the matrix. Until 7.6, no pickup path may bypass the ordinary hard-stop.
