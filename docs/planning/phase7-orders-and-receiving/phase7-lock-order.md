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
- Reservation-bearing commands that touch both inventory and request/allocation use **`InventoryBalance` → `InventoryUnit` (Used) → `customer_request` → allocation**.

## Command matrix

| Command | Required locks, in order |
|---|---|
| Confirm Standard location | `InventoryBalance` → `customer_request` → allocation |
| Confirm Used location | `InventoryBalance` → `InventoryUnit` → `customer_request` → allocation |
| Ordinary sale | existing POS aggregate locks → `InventoryBalance` → `InventoryUnit` when Used |
| Customer pickup | existing POS aggregate → `InventoryBalance` → `InventoryUnit` when Used → allocation / request |
| Negative adjustment | `InventoryBalance` → `InventoryUnit` when Used |
| Post special-order receipt | purchasing receipt aggregate (receipt → POs → PO lines → orders) → `InventoryBalance` → request / allocation |
| Cancel request | `PurchaseOrder` before `Order`/`PurchaseOrderLine` when cancelling draft orders (`cancel_draft_order: true`), then `InventoryBalance` → `InventoryUnit` when a reserved Used allocation exists → `customer_request` → allocation when reserved |
| Reverse receipt | correction / receipt → `InventoryBalance` → request / allocation |
| Depleting post-void | match existing `Inventory::PostPostVoid` order + availability check under balance lock |

## Notes

### Cancel request

When releasing a reserved allocation, cancel follows the same inventory-before-request kernel as Confirm and Reverse so concurrent reverse-vs-cancel cannot AB-BA deadlock. **Always** acquire `InventoryBalance` before locking `customer_request`, even when the soft read shows no reserved allocation, so concurrent locate or special-order receipt cannot attach a reservation to a request that is about to be cancelled. Soft-read the request only to decide draft-order paths; do not hold `customer_request` while acquiring `InventoryBalance`. Re-query and lock the current reserved allocation after the request lock rather than relying on the soft read. When `cancel_draft_order: true`, lock `PurchaseOrder` before `Order` and `PurchaseOrderLine` so concurrent send cannot deadlock; revalidate `po.draft?` and `sent_at` after the PO lock and return `SENT_PO_CONFLICT` if the PO was sent.

### Competing locate vs ordinary sale

Two `pending_location` locates, or a locate racing an ordinary sale, must not decide “last copy” without sharing inventory serialization. First successful command that commits under the locked balance (and unit when Used) wins; losers fail with a current-state explanation.

### Pickup exception (Slice 7.6)

Ordinary sale capacity uses `available` only. Pickup may consume `available` plus the quantity allocated to that POS line, and only after locking the allocation/request after inventory locks as in the matrix. Until 7.6, no pickup path may bypass the ordinary hard-stop.
