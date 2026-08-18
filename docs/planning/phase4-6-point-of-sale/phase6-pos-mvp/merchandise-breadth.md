# Phase 6 Slice 6.1 — Merchandise breadth

**Status:** Implemented. Cashier-facing sale of quantity-tracked Standard, individually tracked Used, and non-inventory Standard on the Phase 5 Cash register path.

**Authority:** Cashier-facing sale of quantity-tracked Standard (already works), individually tracked Used, and non-inventory Standard on the Phase 5 Cash register path. Completion, tax, receipt identity, and Cash settlement remain in the [Phase 4 packet](../phase4-point-of-sale/). Envelope v2 keys: [mvp-contract.md](mvp-contract.md). Cash/Z remain Phase 5.

Companions: [phase6-plan.md](phase6-plan.md), [inventory-posting-contract.md](../../phase3-inventory-foundation/inventory-posting-contract.md), [register-workspace.md](../phase5-cash-register/register-workspace.md).

Where this document and [spec.md](../spec.md) §6.1 disagree (open ring), **prefer this document**. Open ring is out of this MVP.

### Actually locked

```text
three tracking forms on one Cash transaction
inventory_unit_id on individually tracked lines only
quantity = 1 for unit lines; QUANTITY must not allow 2
AddMerchandise serializes on the InventoryUnit row (no reserved ledger)
no cross-table partial unique index on working unit lines
unit lifecycle stays on_hand | removed
PostSale posts exact units; skips non-inventory
unit price: unit regular → variant regular → fail
Identifiers::Lookup returns inventory units
SALE_ENTRY scan branches on lookup; no new persisted mode
v2 envelopes for all new completions (unused keys omitted)
Phase 5 all-Cash Standard path stays green
```

---

## 1. Objective

Allow the register to sell every normal merchandise tracking form in the MVP:

```text
quantity-tracked Standard
individually tracked Used
non-inventory Standard
```

The first already works. Tracking is derived from merchandise class + variant type, not chosen at POS:

```text
inventory + standard → quantity
inventory + used     → individual
non_inventory + standard → non_inventory
```

Non-inventory Used variants remain invalid. Open-price merchandise remains rejected.

---

## 2. Schema (this slice)

Add nullable `pos_transaction_lines.inventory_unit_id` (FK → `inventory_units`, restrict). No `line_type` column.

Constraints:

```text
individually tracked line  → inventory_unit_id NOT NULL, quantity = 1
quantity / non-inventory   → inventory_unit_id IS NULL
```

Do **not** add a partial unique index on working `inventory_unit_id`. PostgreSQL cannot predicate that index on `pos_transactions.status`. A global unique index on `inventory_unit_id` would also block a later linked return of the same unit.

The invariant remains:

```text
two working transactions cannot simultaneously contain the same InventoryUnit
```

Enforce it in `AddMerchandise` by serializing on the unit row (§4.4). Completed lines keep `inventory_unit_id` for history. After completion the unit is `removed`, so a later working sale of that identifier fails availability.

Do not add unused discount, override, original-line, or tender-config columns.

---

## 3. Identifier lookup

Today [`Identifiers::Lookup`](../../../../app/services/identifiers/lookup.rb) treats `identifier_kind = inventory_unit` as unknown.

Extend `Result` with `inventory_unit` (and keep `variant` / `product` when a unit is found: `unit.product_variant` / `variant.product`).

```text
normalized identifier
  → Registry.find_any
  → identifier_kind = inventory_unit
  → status: :inventory_unit
```

Lookup is exact on the registry value. Unit identifiers are globally unique 13-digit `220…` values; variant SKUs are `221…`. Do not guess kind by digit length. Retired registry rows stay not-sellable.

`AddMerchandise` (and workspace scan) branches:

```text
:inventory_unit → 6.1A unit path
:variant        → existing variant path (quantity or non-inventory)
:multi_variant  → unchanged (not a unit scan)
:not_found / :retired / :invalid → existing errors
```

Scanning a Used **variant SKU** does not pick an arbitrary unit. The cashier must scan or enter the unit identifier.

---

## 4. 6.1A — Individually tracked / Used

### 4.1 Scan

```text
unit identifier
  → InventoryUnit
  → store_id = current store
  → lifecycle_state = on_hand
  → variant sellable and derived tracking = individual
  → price (§4.3)
  → one transaction line
```

Reject when:

- unit is not at the current store
- unit is `removed`
- variant is not sellable
- derived tracking is not `individual`
- the unit is already on this working transaction
- the unit is on **another** working transaction (lock + existence check, not silent steal)
- price cannot be resolved

Do not merge unit lines on rescan. A second scan of the same unit is an error. A scan of a **different** unit is a new line.

### 4.2 Quantity

```text
inventory_unit_id required
quantity = 1
QUANTITY must not allow 2
```

`ChangeQuantity` rejects any quantity other than `1` on a unit line. The QUANTITY mode should not be offered as a successful path for the selected unit line (disable or error). F8 / line remove remains valid.

### 4.3 Price

Use existing `InventoryUnit#effective_regular_price_cents` (POS-DEC-056):

```text
unit regular_price_cents
  ↓ fallback
variant regular_price_cents
  ↓
failure if neither supplies a price
```

Set both `reference_unit_price_cents` and `selling_unit_price_cents` to that value. No override in this slice.

### 4.4 Working availability

Working transactions still do **not** post `reserved` ([phase4-plan.md](../phase4-point-of-sale/phase4-plan.md)). Do not introduce a reservation ledger or a denormalized working-unit table to solve POS basket concurrency.

Serialize `AddMerchandise` on the `InventoryUnit` row:

```text
BEGIN
  lock InventoryUnit                    # FOR UPDATE
  reject unless on_hand at current store
  reject if any working POS line references this unit
  insert line
COMMIT
```

The lock makes the existence check and insert atomic across Registers. A second cashier waits, then fails with a conflict — not a silent steal. Removing the line (F8) releases the working reference so another Session may add the unit.

Completion re-locks the unit and re-checks `on_hand` at the transaction store so an intervening Phase 3 adjustment cannot complete a sale of a unit that already left on-hand.

### 4.5 Completion

`Pos::CompleteTransaction` currently rejects individually tracked merchandise. Stop rejecting it. For each unit line:

- variant still sellable
- `inventory_unit_id` present, quantity `1`
- lock unit; still `on_hand` at the transaction store
- freeze snapshots (§6)
- post through the inventory posting boundary (§7)

After success the unit is `removed` (`removed_at` set). **Do not add a `sold` lifecycle state.** Phase 3 stays `on_hand | removed`. Distinguish POS sale from an adjustment decrease via ledger `entry_type = sale` and `source_type = PosTransactionLine`.

---

## 5. 6.1B — Non-inventory merchandise

Still a normal merchandise line:

```text
product_variant_id = …
inventory_unit_id  = nil
derived tracking   = non_inventory
```

`AddMerchandise` currently requires `derived_inventory_tracking == "quantity"`. Allow `non_inventory` as well.

Rules:

- SKU / identifier resolution is the existing variant path
- Rescan of a compatible SKU increments quantity (same merge as Standard)
- Pricing from `product_variants.regular_price_cents`; still reject `open_price` and missing regular price
- Tax, tender, receipt participate normally
- **Inventory effect = none.** No ledger, valuation, or balance row. No zero-quantity fake entry.

This is **not** open ring. The item is known merchandise with ProductVariant, SKU, Department, and Tax Class. ShelfSense simply does not track physical inventory.

Completion: skip `Inventory::PostSale` (and any sibling) for `non_inventory` lines. Do not call `PostAdjustment`.

---

## 6. Completed snapshots

Every completed line still has v1 merchandise snapshot keys. Unit lines add:

```text
sku                    # variant SKU
description            # product name at completion
tax_class_code
unit_identifier        # 13-digit inventory unit identifier
condition_code         # parent Used variant condition code
```

Envelope v2 includes `inventory_unit_id` on the line when present ([mvp-contract.md](mvp-contract.md) §6).

Once 6.1 ships v2 construction, **all new** completions use `schema_version: 2`. Quantity-only Cash sales omit unit keys.

Receipt / on-screen completion confirmation shows unit identifier and condition on Used lines. Print remains the Phase 5 browser path over the same snapshots.

---

## 7. Inventory posting

Update [inventory-posting-contract.md](../../phase3-inventory-foundation/inventory-posting-contract.md) **in the 6.1 implementation PR**, not in this docs-only packet beyond this contract.

Extend `Inventory::PostSale` (preferred) or add a sibling named service in the **same** posting boundary:

| Tracking | Effect |
|---|---|
| `quantity` | Existing moving-average depletion (`quantity_delta = −quantity`) |
| `individual` | Specific-identification: physical + valuation on the exact `inventory_unit`; transition `on_hand` → `removed`; `quantity_delta = −1`; `source_type = PosTransactionLine` |
| `non_inventory` | **Do not call the posting service** |

Must not call `Inventory::PostAdjustment`. Must not emit `inventory.adjustment_posted`. Duplicate protection remains unique `(source_type, source_id, effect_sequence)`.

`reject_below_zero` remains. A missing or already-removed unit is a completion failure: no receipt consumption, no commercial freeze that escapes the transaction.

---

## 8. Workspace

No new persisted UI mode. `SALE_ENTRY` / `QUANTITY` / `TENDER` stay ephemeral ([register-workspace.md](../phase5-cash-register/register-workspace.md)).

Scan in `SALE_ENTRY` uses the extended Lookup. Selected Used line display:

```text
description
condition
unit identifier
qty 1
price
```

QUANTITY is not a successful path for a selected unit line. Mixed baskets still tender and complete through existing `TenderCash` / `CompleteTransaction` (Cash only until 6.2). `expected_total_cents` / presented remain the v1 command internally; the **envelope** is v2.

Controllers still only orchestrate services. No inventory mutation in Stimulus.

Keyboard-first: unit identifier entry is the same primary field as SKU (scanner Enter). No mouse-only unit picker is required in 6.1. If a scanned identifier is a Used variant SKU rather than a unit, show an explicit error (“scan the unit identifier”), not a chooser.

---

## 9. Authorization, audit, retry

Permission remains `pos.transact` at the current store. Session cashier for basket/tender/complete.

Audit with the existing completion event. Include `inventory_unit_id` in after-values where a unit line completed. Never dump full unit cost rows into audit metadata.

Idempotent completion retries must not double-post inventory or double-remove a unit (existing `pos_operations` + ledger uniqueness).

---

## 10. Acceptance

A cashier can complete **one Cash transaction** that sells:

```text
2 × quantity-tracked Standard
1 × exact Used InventoryUnit
1 × non-inventory Standard
```

and:

1. Completion generates inventory effects for the first two categories and **none** for non-inventory.
2. The Used unit is `removed`; ledger `entry_type = sale`, `source_type = PosTransactionLine`, `inventory_unit_id` set.
3. The Standard quantity-tracked variant on-hand decreased by 2.
4. Completed snapshots retain unit identifier and condition after the variant is later renamed or the unit is no longer on hand.
5. A second working transaction cannot add the same `on_hand` unit (serialized `AddMerchandise` on the unit row).
6. QUANTITY cannot set a unit line to 2.
7. Scanning a Used variant SKU does not add a line.
8. Completion fails if the unit left `on_hand` after it was added (Phase 3 adjustment), with no receipt and no inventory effect.
9. The Phase 5 all-Cash Standard path remains green (unit tests + system/browser tests).
10. New completions are `schema_version: 2`.

Headless coverage for posting, concurrent unit add, and idempotency. System coverage for mixed-basket scan → Cash tender → complete → receipt shows the Used unit.

---

## 11. Out of Slice 6.1

```text
open ring
unknown Used-item intake / buyback
transfers between Stores
reserved quantity / unit reservation ledger
sold as a distinct lifecycle state
Card / Check / mixed tender (6.2)
returns of units (6.5)
price override / discount (6.4)
```
