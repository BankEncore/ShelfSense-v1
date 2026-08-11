# Phase 3 — Inventory Foundation

## Status

Proposed implementation specification.

## Purpose

Phase 3 establishes ShelfSense's authoritative inventory model. It must support quantity-tracked standard merchandise and individually tracked used merchandise, establish opening inventory, post auditable corrections, calculate stock availability, and maintain inventory value at cost.

The physical inventory ledger is authoritative for on-hand quantity. Current balances are maintained projections that must be reproducible from authoritative records.

## Deliverable

An authorized user can:

- establish opening inventory;
- add or remove quantity-tracked stock through a single-effect inventory adjustment;
- create, update, and remove individually tracked inventory units through controlled inventory operations;
- classify on-hand stock as available or unavailable;
- view on-hand, reserved, unavailable, and available quantities by store and product variant;
- view current inventory value and the applicable costing basis;
- trace every physical quantity and valuation change to its source; and
- reconcile maintained balances against their authoritative records.

## Locked decisions

### Inventory accounting level

Inventory is accounted for at the `store_id` and `product_variant_id` level. An individually tracked `inventory_unit` is a child of its product variant. A movement involving a unit is recorded against the parent variant and additionally references that unit.

### Physical ledger scope

`inventory_ledger_entries` records only events that change physical on-hand quantity. It does not record reservations or changes between available and unavailable states.

```text
on_hand = sum(inventory_ledger_entries.quantity_delta)
```

Examples that create ledger entries include opening inventory, receiving, sales, returns to stock, shrinkage, disposal, supplier returns, and count corrections.

Examples that do not create ledger entries include reserving stock, releasing a reservation, marking on-hand stock damaged, placing it under inspection, or restoring it to available stock.

### Availability

Availability is calculated as:

```text
available = on_hand - reserved - unavailable
```

The authoritative sources are:

| Quantity | Authoritative source |
|---|---|
| `on_hand` | Physical inventory ledger |
| `reserved` | Active inventory reservations or allocations |
| `unavailable` | Active unavailable allocations for quantity-tracked stock and current unit states for individually tracked stock |
| `available` | Calculated from the invariant; never an independent fact |

Phase 3 establishes these semantics. Reservation-producing workflows may be implemented later, so `reserved` may remain zero until the first such workflow is introduced.

### Adjustments

An inventory adjustment is a single-effect record for one product variant or one inventory unit. Phase 3 does not use adjustment headers and lines.

Opening inventory is posted through ordinary adjustments using an `opening_inventory` reason. Bulk imports, count sessions, and optional batch grouping are deferred until a concrete workflow requires them.

### Valuation

Physical quantity and inventory value are related but distinct dimensions:

- quantity-tracked variants use moving weighted-average cost;
- individually tracked units use specific identification and retain their acquisition cost;
- physical additions and removals normally create both a physical ledger entry and a valuation entry;
- reservations and availability-state changes have no valuation effect; and
- valuation-only corrections may occur without a physical movement.

Formal general-ledger journal entries and financial statement accounting are outside Phase 3.

## Domain invariants

1. Every inventory movement belongs to one store and one product variant.
2. `inventory_unit_id` is absent for quantity-tracked variants and required for movements of individually tracked variants.
3. When an inventory unit is referenced, its `store_id` and `product_variant_id` must agree with the ledger entry.
4. A physical movement for one inventory unit has a `quantity_delta` of `+1` or `-1`.
5. Posted ledger and valuation entries are append-only. Corrections use reversing or correcting entries.
6. A posted adjustment cannot be edited or deleted.
7. Posting an adjustment, creating ledger and valuation entries, changing unit state, and updating projections occur in one database transaction.
8. Posting is idempotent: retrying the same posting operation cannot create duplicate effects.
9. The ledger-derived on-hand quantity for a unit-tracked variant must equal the number of its units currently on hand.
10. `reserved + unavailable` should not exceed `on_hand` during ordinary operations. If policy permits an exceptional overcommitment, it must be visible as an integrity warning rather than silently hidden.
11. `available` is calculated and may be negative only when ShelfSense intentionally permits overselling or an integrity exception exists.
12. All Phase 3 domain tables use UUIDv7 primary keys and Rails optimistic locking where mutable workflow records require it, consistent with earlier architecture decisions.

## Data model

Field lists below describe the required logical data. Exact Rails naming may follow existing repository conventions.

### `inventory_ledger_entries`

Append-only authoritative history of physical on-hand changes.

| Field | Type | Constraints / notes |
|---|---|---|
| `id` | uuid | UUIDv7 primary key |
| `store_id` | uuid | FK, required |
| `product_variant_id` | uuid | FK, required |
| `inventory_unit_id` | uuid | FK, nullable; required for unit-tracked movements |
| `quantity_delta` | integer | Required, nonzero; `+1` or `-1` when a unit is referenced |
| `movement_type` | string | Required; controlled value |
| `source_type` | string | Required; source record type |
| `source_id` | uuid | Required; source record ID |
| `reverses_entry_id` | uuid | Self-FK, nullable |
| `occurred_at` | datetime | Required; business-effective time |
| `created_by_id` | uuid | User FK, required for user-initiated movements |
| `metadata` | jsonb | Optional non-authoritative context; not a substitute for modeled fields |
| timestamps | datetime | Required |

Required indexes and constraints:

- index by `(store_id, product_variant_id, occurred_at)`;
- index by `inventory_unit_id` when present;
- index by `(source_type, source_id)`;
- prevent duplicate effects for the same idempotent source operation;
- reject zero deltas; and
- validate unit, variant, store, and tracking-mode agreement in the posting service, with database constraints where practical.

Initial movement types should include:

```text
opening_inventory
receipt
sale
customer_return
adjustment_increase
adjustment_decrease
shrinkage
disposal
return_to_vendor
reversal
```

Phase 3 needs to exercise only the movement types supported by its workflows. Later phases may add source-specific types without changing ledger semantics.

### `inventory_balances`

Maintained store-and-variant projection for fast operational reads.

| Field | Type | Constraints / notes |
|---|---|---|
| `id` | uuid | UUIDv7 primary key |
| `store_id` | uuid | FK, required |
| `product_variant_id` | uuid | FK, required |
| `on_hand` | integer | Required, default `0`; projected from physical ledger |
| `reserved` | integer | Required, default `0`; cached projection when reservation records exist |
| `unavailable` | integer | Required, default `0`; cached projection from authoritative availability records/states |
| `inventory_value_cents` | bigint | Required, default `0`; projected from valuation entries |
| `average_unit_cost` | decimal | Nullable; cached at sufficient precision for moving-average variants |
| `lock_version` | integer | Required, default `0` |
| timestamps | datetime | Required |

Required constraints:

- unique `(store_id, product_variant_id)`;
- `reserved >= 0` and `unavailable >= 0`;
- `available` is exposed through a model method, query expression, or database-generated expression rather than mutable application input; and
- balance rows are locked when a posting operation updates them.

Negative `on_hand` may be allowed at the inventory layer to avoid blocking later POS operations, but must be surfaced prominently. A positive adjustment that introduces known stock should supply its cost basis. Negative on-hand has no valid moving-average valuation and therefore requires an explicit costing policy in the posting service.

### `inventory_adjustment_reasons`

Configurable business reasons governing user-entered adjustments.

| Field | Type | Constraints / notes |
|---|---|---|
| `id` | uuid | UUIDv7 primary key |
| `code` | string | Required, unique, stable |
| `name` | string | Required |
| `description` | text | Nullable |
| `direction` | string | `increase`, `decrease`, or `either` |
| `requires_notes` | boolean | Required, default `false` |
| `requires_cost` | boolean | Required, default based on reason |
| `active` | boolean | Required, default `true` |
| timestamps | datetime | Required |

Initial reasons should include opening inventory, found stock, count correction, damage/write-off, shrinkage, disposal, and administrative correction. Reason configuration expresses validation and UI behavior; it does not itself determine ledger deltas without the adjustment quantity and operation.

### `inventory_adjustments`

User-facing instruction to make one inventory effect.

| Field | Type | Constraints / notes |
|---|---|---|
| `id` | uuid | UUIDv7 primary key |
| `store_id` | uuid | FK, required |
| `product_variant_id` | uuid | FK, required |
| `inventory_unit_id` | uuid | FK, nullable according to tracking mode |
| `inventory_adjustment_reason_id` | uuid | FK, required |
| `quantity_delta` | integer | Required for physical quantity adjustments; nonzero |
| `unit_cost_cents` | integer | Required for applicable positive additions; nullable otherwise |
| `from_availability_state` | string | Nullable; required for a unit state transition when applicable |
| `to_availability_state` | string | Nullable; required for a unit state transition when applicable |
| `notes` | text | Nullable or required by reason |
| `status` | string | `draft`, `posted`, or `cancelled` |
| `created_by_id` | uuid | User FK, required |
| `posted_by_id` | uuid | User FK, nullable until posted |
| `posted_at` | datetime | Nullable until posted |
| `reverses_adjustment_id` | uuid | Self-FK, nullable |
| `idempotency_key` | string | Required for posting; unique within the appropriate scope |
| `lock_version` | integer | Required, default `0` |
| timestamps | datetime | Required |

An availability-only transition that does not change on-hand quantity should update the authoritative availability record or inventory unit state and must not create a physical ledger entry. The adjustment record may still document the authorized user action.

Workflow:

```text
draft -> posted
  |
  +----> cancelled
```

- Draft adjustments are editable and have no inventory effect.
- Posting validates the complete effect and applies it atomically.
- Cancelled drafts have no inventory effect.
- Posted adjustments are corrected by a new reversal or correcting adjustment.

### `inventory_units`

Represents one individually tracked physical item belonging to a unit-tracked product variant.

| Field | Type | Constraints / notes |
|---|---|---|
| `id` | uuid | UUIDv7 primary key |
| `store_id` | uuid | FK, required while owned/held by a store |
| `product_variant_id` | uuid | FK, required; variant must be unit-tracked |
| `identifier` | string | Required; unique system-generated scannable identifier |
| `merchandise_condition_id` | uuid | FK, required for used merchandise |
| `condition_notes` | text | Nullable |
| `lifecycle_state` | string | Required; e.g. `on_hand`, `sold`, `disposed`, `returned_to_vendor` |
| `availability_state` | string | Required while on hand; e.g. `available`, `reserved`, `damaged`, `inspection`, `return_to_vendor` |
| `acquisition_cost_cents` | integer | Required when the unit enters inventory under a cost-bearing event |
| `acquired_at` | datetime | Required once acquired |
| `departed_at` | datetime | Nullable until the unit leaves on-hand inventory |
| `lock_version` | integer | Required, default `0` |
| timestamps | datetime | Required |

Selling price, list price, and condition-based price adjustments are merchandise/pricing concerns and must not be conflated with acquisition cost.

Lifecycle and availability are separate:

| Unit state | On hand contribution | Reserved contribution | Unavailable contribution |
|---|---:|---:|---:|
| On hand / available | 1 | 0 | 0 |
| On hand / reserved | 1 | 1 | 0 |
| On hand / damaged, inspection, or RTV hold | 1 | 0 | 1 |
| Sold, disposed, or returned to vendor | 0 | 0 | 0 |

An acquisition operation creates or activates the unit, writes a `+1` physical ledger entry against its parent variant, writes the valuation entry, and updates the variant balance in one transaction. A sale or disposal performs the inverse using that unit's specific cost.

### Quantity-tracked unavailable allocations

Quantity-tracked stock requires a record explaining why part of the on-hand quantity is unavailable. Use an explicitly named record such as `inventory_unavailable_allocations` rather than storing an unexplained unavailable number only in the balance.

| Field | Type | Constraints / notes |
|---|---|---|
| `id` | uuid | UUIDv7 primary key |
| `store_id` | uuid | FK, required |
| `product_variant_id` | uuid | FK, required; quantity-tracked variant |
| `quantity` | integer | Required, positive |
| `reason` | string | Required; controlled value |
| `source_type` / `source_id` | string / uuid | Optional source association |
| `placed_by_id` | uuid | User FK, required when user initiated |
| `placed_at` | datetime | Required |
| `released_by_id` | uuid | User FK, nullable |
| `released_at` | datetime | Nullable; active while absent |
| `notes` | text | Nullable |
| timestamps | datetime | Required |

For individually tracked merchandise, `inventory_units.availability_state` is authoritative. Do not create a second unavailable-allocation record for the same unit unless a later design explicitly replaces the unit state as authority.

### `inventory_valuation_entries`

Append-only authoritative history of inventory asset value changes.

| Field | Type | Constraints / notes |
|---|---|---|
| `id` | uuid | UUIDv7 primary key |
| `inventory_ledger_entry_id` | uuid | FK, nullable only for valuation-only corrections |
| `store_id` | uuid | FK, required |
| `product_variant_id` | uuid | FK, required |
| `inventory_unit_id` | uuid | FK, nullable according to tracking mode |
| `value_delta_cents` | bigint | Required, nonzero except where an explicit zero-cost movement is valid |
| `unit_cost` | decimal | Cost applied, stored at sufficient precision |
| `cost_method` | string | `moving_average` or `specific_identification` |
| `valuation_type` | string | Acquisition, relief, correction, landed-cost adjustment, reversal, etc. |
| `source_type` / `source_id` | string / uuid | Required source association |
| `reverses_entry_id` | uuid | Self-FK, nullable |
| `occurred_at` | datetime | Required |
| timestamps | datetime | Required |

```text
inventory_value = sum(inventory_valuation_entries.value_delta_cents)
```

Whole inventory value remains stored in integer cents. Moving-average unit cost must retain more precision than whole cents so repeated receipts and reliefs do not accumulate avoidable rounding errors.

## Costing behavior

### Quantity-tracked variants

Positive additions use their supplied acquisition cost and recalculate moving weighted average:

```text
new inventory value = existing inventory value + added value
new average cost    = new inventory value / new on-hand quantity
```

Negative movements relieve inventory at the current average cost. The posting service owns rounding and must ensure the final removal that brings on-hand to zero also brings inventory value to zero, absorbing any residual rounding amount.

### Individually tracked variants

Each unit carries `acquisition_cost_cents`. Removing that exact unit relieves its remaining carrying value. The variant's total value equals the combined carrying value of its on-hand units and must reconcile with valuation entries.

### Availability changes

Reservations, damage classification, inspection, and other on-hand availability changes do not change inventory value. Disposal or another event that physically removes the item relieves its carrying value.

### Cost corrections

A cost correction may create a valuation entry without a physical ledger entry. It must identify its source and, when correcting a prior entry, reference the reversed or corrected valuation entry. Cost corrections for specific units must also update the unit's carrying/acquisition cost representation consistently.

## Application services

Implementation should centralize inventory mutations in services rather than model callbacks. At minimum:

- `PostInventoryAdjustment`: validates and posts a single-effect adjustment atomically;
- `ApplyInventoryMovement`: writes the physical ledger entry and updates the balance under lock;
- `ApplyInventoryValuation`: applies moving-average or specific-identification valuation;
- `ChangeInventoryAvailability`: manages quantity allocations or unit availability state without writing a physical ledger entry; and
- `ReconcileInventory`: independently rebuilds expected quantities and values and reports discrepancies.

Service names may follow repository conventions, but all inventory-changing workflows must use the same transactional posting path.

## Reconciliation

Phase 3 must provide an administrative command or service that checks, without relying on the cached balance values:

```text
expected on_hand
  = sum of physical ledger quantity deltas

expected reserved
  = sum of active reservations, plus reserved on-hand units

expected unavailable
  = sum of active quantity allocations, plus unavailable on-hand units

expected inventory value
  = sum of valuation entry value deltas
```

For unit-tracked variants it must also verify:

```text
ledger on_hand
  = count of inventory units whose lifecycle state is on_hand
```

The reconciliation operation reports discrepancies. A separate explicit rebuild or repair action may replace cached projections; reconciliation must not silently mutate authoritative history.

## User interface requirements

Phase 3 requires functional server-rendered Rails interfaces consistent with the existing UI approach:

- inventory overview by store and variant;
- display of on-hand, reserved, unavailable, available, inventory value, and cost method;
- variant inventory history with links to source adjustments and unit records;
- single-adjustment entry and confirmation;
- inventory-unit detail and history;
- controlled availability-state changes with reason and notes;
- clear warnings for negative on-hand, negative available, or reconciliation failures; and
- immutable posted-adjustment and ledger history views.

The UI must not permit direct editing of balance, ledger, or valuation rows.

## Authorization and audit

- Viewing inventory may use the existing inventory or merchandise permission boundary.
- Creating, posting, reversing, and cancelling adjustments must be separately authorized as appropriate to the existing authorization model.
- Availability changes and cost corrections require explicit authorization.
- Posted records capture the acting user and effective time.
- Application audit events complement, but do not replace, the physical and valuation ledgers.
- Attempts to mutate immutable entries must fail and be auditable where the existing audit framework supports it.

## Concurrency and transaction safety

- Lock the affected `inventory_balance` row during posting.
- Create a missing balance row safely under the unique store/variant constraint.
- Use an idempotency key or equivalent unique source-effect constraint.
- Lock an `inventory_unit` while changing its lifecycle or availability state.
- Validate the expected prior unit state to prevent double sale, double disposal, or stale transitions.
- Write all effects of one operation in a single database transaction.
- Avoid business-critical inventory mutation in asynchronous jobs unless the job uses the same locking and idempotency guarantees.

## Validation rules

At posting time, validate at least:

- store and variant are active and compatible;
- tracking mode matches the presence or absence of an inventory unit;
- referenced unit belongs to the store and variant;
- adjustment reason allows the requested direction;
- required notes and cost are present;
- unit state transition is valid and begins from the persisted current state;
- quantity is valid for the tracking mode;
- valuation method matches the tracking mode;
- reversal has not already been applied; and
- idempotency/source uniqueness has not already produced the same effect.

## Tests

### Model and database tests

- UUIDv7 identifiers and foreign keys;
- unique balance per store and variant;
- nonzero physical deltas;
- unit movements restricted to `+1` and `-1`;
- reason and workflow validations;
- immutable posted and ledger records;
- unit/variant/store agreement; and
- authoritative-record constraints for active unavailable allocations.

### Service tests

- opening quantity-tracked inventory with cost;
- positive and negative adjustments;
- moving-average receipt and relief calculations;
- acquisition and removal of a specifically costed unit;
- availability-only changes creating no physical or valuation movement;
- posting rollback when any effect fails;
- duplicate posting/idempotent retry;
- concurrent updates to the same balance;
- reversal of a posted adjustment;
- rounding behavior, including relief of the final quantity;
- negative-on-hand policy behavior; and
- valuation-only correction.

### Reconciliation tests

- clean quantity and value reconciliation;
- detection of tampered balance projections;
- unit-count mismatch detection;
- reserved and unavailable projection mismatch detection; and
- explicit rebuild restores only projections, not authoritative entries.

### Request/system tests

- authorized adjustment workflow;
- unauthorized posting rejection;
- inventory overview calculations;
- unit detail and movement history;
- posted records cannot be edited; and
- integrity and negative-stock warnings are visible.

## Acceptance criteria

Phase 3 is complete when:

1. Opening inventory can be posted for both quantity-tracked and unit-tracked variants.
2. A posted physical adjustment creates an immutable physical ledger entry and, when applicable, an immutable valuation entry.
3. The affected balance is updated atomically and agrees with independently calculated authoritative totals.
4. An individual unit's physical movement appears under its parent variant and references the exact unit.
5. Availability-only changes affect `reserved`, `unavailable`, or `available` without changing physical on-hand or inventory value.
6. `available = on_hand - reserved - unavailable` holds for every balance displayed by the application.
7. Quantity-tracked stock is valued by moving weighted average and unit-tracked stock by specific identification.
8. Posted adjustments and ledger entries cannot be edited or deleted through normal application paths.
9. Retrying a posting request cannot duplicate inventory or valuation effects.
10. Reconciliation detects discrepancies in quantity, value, availability projections, and unit counts.

## Explicitly out of scope

- purchase orders, receiving documents, supplier terms, discounts, freight, and landed-cost allocation;
- POS transaction processing and sale completion;
- customer reservations and POS reservation workflows;
- transfers between stores;
- comprehensive cycle-count or physical-inventory sessions;
- multi-line adjustment documents and adjustment batches;
- CSV import/export workflows unless separately approved;
- general-ledger journal entries and COGS posting;
- retail inventory accounting, lower-of-cost-or-market write-downs, and other advanced accounting policies;
- physical sublocation accounting within a store; and
- automated repair of immutable ledger history.

Later phases must create their inventory effects through the Phase 3 posting services rather than directly changing balances.

## Implementation sequence

1. Add adjustment reasons, physical ledger, balances, and single-effect adjustments.
2. Implement transactional quantity posting, locking, idempotency, reversal, and reconciliation.
3. Add valuation entries and moving-average costing.
4. Add inventory units and specific-identification costing.
5. Add quantity unavailable allocations and unit availability transitions.
6. Build inventory overview, history, adjustment, unit, and integrity-warning interfaces.
7. Complete authorization, audit integration, concurrency tests, and acceptance tests.

