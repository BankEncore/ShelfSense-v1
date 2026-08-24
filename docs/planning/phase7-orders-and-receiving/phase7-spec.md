# Phase 7 — Orders, Customer Requests, and Receiving

## Status

Accepted for implementation on branch `phase-7-orders-and-receiving`.

## 1. Purpose

Phase 7 implements ShelfSense's minimum viable customer-request and supplier-order workflow. Customer requests begin with one specific variant and are routed from current availability: apparent in-stock merchandise enters a staff location queue; an out-of-stock Standard variant becomes a supplier special order; an out-of-stock Used variant is not requestable in Phase 7.

After this phase, an authorized user can:

- maintain suppliers and optional supplier-specific sources for quantity-tracked merchandise;
- create a quantity-one customer request for any active Standard variant or an apparent in-stock Used variant;
- locate and reserve the physical Standard copy or exact Used inventory unit;
- automatically route an out-of-stock Standard request into supplier special ordering;
- convert an unlocated Standard request to a special order or cancel it, while cancelling an unlocated Used request;
- create an order for store stock or for a Standard customer special order;
- have ShelfSense place each order on the open draft purchase order for the same supplier and store;
- generate and record sending a supplier-facing purchase order;
- record buyer or supplier cancellations and re-source unfilled quantities through linked replacement orders;
- post partial or complete physical receipts against one or more purchase orders from the same supplier and store;
- capture actual merchandise cost and ancillary acquisition charges;
- add received merchandise to physical inventory and moving-average valuation through the established inventory posting boundary;
- reserve received customer-request quantities and complete pickup through POS;
- reverse eligible receipt-line errors or post explicit valuation corrections without rewriting posted history; and
- close purchase orders automatically when every submitted quantity has been received or cancelled.

The Phase 7 vertical slice is:

> Create a stock order or a quantity-one customer request → locate and reserve apparent in-stock merchandise, or route Standard merchandise to supplier ordering → send the purchase order when needed → receive and reserve special-order merchandise → complete customer pickup through POS → close the purchasing commitment.

## 2. Authority and existing contracts

This specification is subordinate to the accepted ADRs and implemented domain contracts, especially:

- [ADR-002 — Identifiers](../../adr/ADR-002-identifiers.md)
- [ADR-007 — Money, rates, dates, and time](../../adr/ADR-007-money-rates-and-time.md)
- [ADR-008 — Audit events](../../adr/ADR-008-audit-events.md)
- [ADR-009 — Optimistic concurrency and idempotency](../../adr/ADR-009-concurrency-and-idempotency.md)
- [ADR-010 — Transactional outbox](../../adr/ADR-010-transactional-outbox.md)
- [ADR-012 — Record lifecycle](../../adr/ADR-012-record-lifecycle.md)
- [ADR-013 — Append-only facts](../../adr/ADR-013-append-only-facts.md)
- [Phase 3 inventory foundation](../phase3-inventory-foundation/phase-3-inventory-foundation.md)
- [Inventory posting service contract](../phase3-inventory-foundation/inventory-posting-contract.md)
- the implemented Phase 4–6 POS contracts under [phase4-6-point-of-sale](../phase4-6-point-of-sale/), including the [Register workspace](../phase4-6-point-of-sale/phase5-cash-register/register-workspace.md)

Phase 7 must extend the inventory posting contract with named purchasing services. Controllers, model callbacks, imports, and purchasing workflows must not update `inventory_balances`, physical ledger rows, or valuation ledger rows directly.

## 3. Locked scope decisions

| Topic | Phase 7 decision |
|---|---|
| Order meaning | One order is one store's demand for one active Standard variant from one supplier. Used variants are never supplier ordered. |
| Stock vs customer | `customer_request_id` present means a customer order; null means a stock order. Do not add an order-type or demand-reason enum. |
| Notes | An optional notes field carries event, promotion, frontlist, or other free-form context. |
| Supplier requirement | Every order requires an active supplier at creation. A supplier-variant source is optional. |
| Supplier eligibility | Only Standard variants may have supplier sources, orders, PO lines, or purchase-receipt lines. Used variants are excluded at every purchasing boundary. |
| Order vocabulary | Keep the user-facing term **Order** for the internal purchasing demand root (`orders`). Disambiguate in UI with **Purchase order** for the supplier document, and with **Stock order** / **Customer special order** when helpful. Do not rename to “demand.” |
| Order-to-PO cardinality | Every order has exactly one dedicated purchase-order line. Lines are not consolidated and an order is not split across lines. Consolidation is deferred; revisit only if buyers choke on long POs. |
| Re-sourcing | Unfilled quantity is re-sourced through a linked replacement order, not by assigning the original order to multiple lines. |
| Availability enforcement | Every stock-depleting command validates resulting availability under lock and rejects Standard `available < 0` or removal of an allocated Used unit unless the same atomic command releases/reverses/transfers that allocation. Ordinary POS hard-stops without a pickup exception until Slice 7.6. Slice 7.6 adds allocation-linked pickup (ordinary capacity = `available`; pickup capacity = `available` + qty on that line). Manual mark-completed is out of Phase 7. Universal hard-stop lands in Slice 7.2 for all existing depleters including `PostSale`. |
| Document numbering | Customer request number and Order number assigned at creation (store-scoped, immutable, never reused). Purchase order number at generate. Purchase receipt number at posting (drafts use UUID; abandoned drafts do not consume numbers). |
| Operator chrome | Location queue, draft PO, and receiving are Register-class ops workspaces (dedicated layout, Importmap + Turbo + Stimulus). Ops chrome minimum: branding; store / document identity / user; exit to Purchasing; no silent draft loss; authz / flash / dialog / a11y. The existing POS Register workspace stays independent—do not fold POS into a shared ops shell in Phase 7. Customer pickup extends the Register workspace. Admin chrome remains for configuration and history. |
| Draft grouping | ShelfSense automatically uses or creates the open draft PO for the order's supplier and store. |
| PO destination | Every Phase 7 PO belongs to one destination store. Central receiving and multi-store POs are deferred. |
| PO numbering | Human-facing PO numbers are sequential within a store and never reused. |
| PO lock point | A sent PO is immutable. An unsent generated document may return to draft under the restrictions in this specification. |
| Transmission | ShelfSense generates a printable/downloadable document; the buyer sends it externally and records the method and time. |
| Supplier acknowledgment | Optional. Receiving does not require an acknowledgment. |
| Partial supply | Partial receipts, backorders, buyer cancellations, supplier cancellations, and linked replacement orders are supported. |
| Cancellation effect | A recorded cancellation reduces open quantity immediately. |
| Receipt meaning | One purchase receipt represents one physical delivery. Separate deliveries require separate receipts. |
| Receipt breadth | One receipt may include lines from multiple POs when supplier and destination store match. |
| Over-shipment | Accepted automatically as unplanned stock; it does not increase submitted order quantity. |
| Receipt costing | Each line requires actual merchandise unit cost. Quantity-tracked inventory uses the existing moving weighted-average rules. |
| Ancillary costs | Freight, handling, supplier tax, and miscellaneous charges are captured on the receipt but not allocated into inventory value in Phase 7. |
| Currency | Organization base currency only. |
| Customer request quantity | One variant and quantity one per request in Phase 7. Multi-quantity and split local/supplier fulfillment are deferred. |
| Request routing | Apparent in-stock Standard or Used merchandise enters a staff location queue. Out-of-stock Standard merchandise becomes a special order. Out-of-stock Used merchandise is not requestable. |
| Physical confirmation | A pending-location request does not reserve inventory. Located Standard quantity or the exact Used inventory unit becomes reserved only after staff confirmation. |
| Not located | An unlocated Standard request may be converted to a special order or cancelled. An unlocated Used request is cancelled. |
| Special-order receipt | A received active customer special order becomes reserved and available for pickup immediately. |
| Customer cancellation | Does not automatically cancel a sent supplier order. Existing allocations are released and later receipts become stock. |
| Corrections | Posted receipt facts are immutable. Corrections use receipt-line reversals, cost-only valuation corrections, or authorized compensating adjustments. |
| Reservation expiration | Not enforced in Phase 7. Existing `system_settings.default_customer_reservation_expiration_days` is configuration-only until a later slice. |

## 4. Explicitly deferred

Phase 7 does **not** implement:

- separate supplier invoice records, invoice lines, invoice matching, accounts payable, or payment processing;
- placeholder supplier invoice numbering;
- GL journal posting for purchases, freight, taxes, payables, or supplier credits;
- authoritative landed-cost allocation or capitalization of ancillary receipt charges;
- automated days-of-supply replenishment, reorder suggestions, scheduled purchasing proposals, or lost-sale capture;
- formal supplier returns, pending return queues, return authorizations, shipments, or supplier-credit workflows;
- central receiving, transfer from a receiving hub, or multi-store purchase orders;
- electronic supplier transmission, EDI, APIs, or advance shipment notices;
- supplier case packs, order multiples, minimum-order enforcement, or freight optimization;
- multi-currency purchasing or exchange-rate accounting;
- a general CRM, marketing history, customer loyalty, tax exemption, or generalized hold/reservation system;
- multi-quantity customer requests, partial local location, combined local-and-supplier fulfillment, or partial pickup;
- automatic request expiration, abandonment processing, customer notifications, deposits, prepayment, or guaranteed request pricing;
- Note: `system_settings.default_customer_reservation_expiration_days` (and related supplier-cancellation defaults) already exist as Phase 1 configuration. Phase 7 does **not** read or enforce those values. They remain editable organization defaults for a later expiration/abandonment slice and must not be presented as active Phase 7 behavior;
- alternate-store fulfillment, transfers, substitutions, title-level requests, Used-item waitlists, or requests for out-of-stock Used merchandise;
- employee assignment, picking routes, priorities, due times, batch picking, or mobile request fulfillment;
- individually tracked Used merchandise, services, gift cards, or non-inventory variants in supplier ordering;
- attachment/document storage beyond the generated PO representation;
- full accounting reconciliation of a supplier document that covers multiple physical receipts;
- consolidating multiple internal orders onto one purchase-order line (or splitting one order across lines);
- manually marking a customer request completed without a successful POS pickup sale;
- folding the POS Register workspace into a shared purchasing/ops shell; or
- manager override to sell reserved merchandise without releasing the allocation (may be considered in a later slice).

An inventory adjustment with an appropriate reason remains the interim operational path for merchandise returned to a supplier until the formal supplier-return phase.

Phase 6.1 merchandise classification and identifiers is implemented on `main` and is the authority for variant eligibility, lookup, and inventory-mode contracts Phase 7 extends.

## 5. Domain boundaries

### 5.1 Purchasing owns

- suppliers;
- supplier-variant sources and preferred-source selection;
- orders and replacement lineage;
- purchase orders and purchase-order lines;
- purchase-order cancellations and supplier-response state;
- purchase receipts and receipt lines;
- receipt-line correction commands and their purchasing source records;
- PO and receipt document numbering; and
- purchasing audit and outbox events.

### 5.2 Customers owns

- basic customer identity and contact information;
- customer requests;
- location queue and request allocation state; and
- customer-request completion and cancellation.

### 5.3 Inventory owns

- immutable physical and valuation ledger entries;
- the rebuildable inventory balance projection;
- moving weighted-average valuation;
- the derived available-quantity calculation; and
- named receipt posting, reversal, and valuation-correction services.

### 5.4 POS owns

- customer pickup sale construction and completion;
- sale pricing, tax, tender, and receipt behavior; and
- the completed transaction line that consumes reserved merchandise.

Purchasing and customer workflows must call the named Inventory and POS boundaries rather than duplicating their posting logic.

## 6. Core terminology

| Term | Meaning |
|---|---|
| Customer request | A customer's quantity-one request for one exact variant at one store. It may route to physical location or, for Standard merchandise, supplier special ordering. |
| Location queue | Store-scoped work queue for requests whose variant appears available but has not yet been physically confirmed. Presented in the location ops workspace. |
| Request allocation | The reserved Standard quantity or exact Used inventory unit physically confirmed for a request. |
| Special order | A Standard customer request requiring supplier purchasing because the variant was out of stock or could not be located. |
| Order | Internal purchasing demand for one Standard variant, supplier, and store (`orders`). It may satisfy stock demand or a Standard special order. User-facing term remains **Order**; UI may say **Stock order** or **Customer special order** when disambiguating. |
| Replacement order | A new order linked to an earlier order for quantity that the earlier supplier will not fulfill. |
| Purchase order | The supplier-facing document grouping orders for one supplier and destination store. Always say **Purchase order** (or PO) when this document is meant. |
| Purchase-order line | The immutable sent snapshot for exactly one internal order. |
| Purchase receipt | One physical delivery from one supplier to one store. This is distinct from a POS customer receipt. |
| Purchase-receipt line | Received quantity and actual unit cost matched to one PO line. |
| Unplanned stock | Accepted quantity above the matched PO line's open quantity. It enters ordinary stock without increasing the submitted order. |
| Reservation | Located or received on-hand merchandise committed to an active customer request and excluded from general availability. |
| Purchasing ops workspace | Dedicated Register-class UI for location, draft PO, or receiving. Not admin chrome and not the POS Register workspace. |

## 7. Data model

All durable domain tables use UUIDv7 primary and foreign keys under ADR-002. All committed monetary amounts use integer `_cents` fields. Mutable aggregate roots use `lock_version`.

The field lists below are normative for Phase 7 behavior but do not prescribe Rails migration syntax.

### 7.1 `suppliers`

| Field | Requirements |
|---|---|
| `id` | UUIDv7 primary key. |
| `code` | Required, normalized, unique, immutable after creation. |
| `name` | Required. |
| `account_number` | Optional supplier account/reference number. |
| `contact_name` | Optional. |
| `email` | Optional. |
| `phone` | Optional. |
| `address_*` | Optional postal address fields consistent with existing store address conventions. |
| `ordering_notes` | Optional text. |
| `active` | Required boolean, default true. Deactivate/reactivate; do not delete referenced suppliers. |
| `lock_version` | Required optimistic-lock column. |
| timestamps | Required. |

At least one of email, phone, or ordering notes is recommended operationally but is not a database requirement.

### 7.2 `supplier_variant_sources`

| Field | Requirements |
|---|---|
| `id` | UUIDv7 primary key. |
| `supplier_id` | Required FK. |
| `product_variant_id` | Required FK to a Standard variant. Used and non-inventory variants are prohibited. |
| `supplier_item_number` | Optional. Unique within supplier when present after normalization. |
| `pricing_method` | Required enum: `discount_from_list` or `direct_unit_cost`. |
| `supplier_list_price_cents` | Required only for `discount_from_list`. |
| `discount_basis_points` | Required only for `discount_from_list`; valid bounded basis points. |
| `expected_unit_cost_cents` | Required only for `direct_unit_cost`; nonnegative. |
| `organization_preferred` | Required boolean, default false. At most one active organization-preferred source per variant. |
| `active` | Required boolean, default true. |
| `lock_version` | Required. |
| timestamps | Required. |

For `discount_from_list`, expected cost is derived deterministically with the project's rounding rules. Do not store contradictory pricing inputs.

### 7.3 `store_supplier_source_preferences`

| Field | Requirements |
|---|---|
| `id` | UUIDv7 primary key. |
| `store_id` | Required FK. |
| `product_variant_id` | Required FK to the same Standard variant as the selected source. |
| `supplier_variant_source_id` | Required active source for the same variant. |
| `lock_version` | Required. |
| timestamps | Required. |

Unique `(store_id, product_variant_id)`. This optional override wins over `organization_preferred`.

### 7.4 `customers`

Phase 7 implements only the identity needed for requests and pickup.

| Field | Requirements |
|---|---|
| `id` | UUIDv7 primary key. |
| `display_name` | Required. |
| `email` | Optional. |
| `phone` | Optional. |
| `notes` | Optional text. |
| `active` | Required boolean, default true. |
| `lock_version` | Required. |
| timestamps | Required. |

At least one of email or phone should be required by the application when a request will require customer contact. Duplicate detection may warn but must not merge customers automatically.

> **Phase 8:** Contact requirement on request create, normalized lookup, duplicate suggestions, and staff-initiated merge are implemented per [phase8-plan.md](../phase8-customer-foundation/phase8-plan.md) and [ADR-023](../../adr/ADR-023-customer-merge.md). This §7.4 note remains the Phase 7 baseline; Phase 8 is authoritative for those behaviors.

### 7.5 `customer_requests`

| Field | Requirements |
|---|---|
| `id` | UUIDv7 primary key. |
| `store_id` | Required FK; immutable after creation. |
| `number` | Required store-scoped sequential integer assigned at creation; immutable; never reused. Unique on `(store_id, number)`. |
| `customer_id` | Required FK. |
| `product_variant_id` | Required FK; immutable after creation. |
| `requested_quantity` | Required integer fixed at `1` in Phase 7. |
| `estimated_price_cents` | Optional nonnegative informational amount; never authoritative POS price. |
| `notes` | Optional text. |
| `status` | Required: `pending_location`, `special_order_pending`, `ordered`, `available`, `completed`, or `cancelled`. Status transitions are command-controlled. |
| `location_failed_at`, `location_failed_by_id`, `location_failure_notes` | Optional location-failure metadata. Failure must immediately lead to Standard conversion/cancellation or Used cancellation; it is not a durable status. |
| `cancelled_at`, `cancelled_by_id`, `cancellation_reason` | Required together on cancellation. |
| `completed_at` | Set when fulfilled quantity reaches requested quantity through completed POS pickup. |
| `lock_version` | Required. |
| timestamps | Required. |

An active Standard request is permitted whether or not the variant is currently available. An active Used request is permitted only when at least one unreserved on-hand inventory unit exists at the request store. Services must recheck this under the request command's concurrency boundary. A later variant deactivation does not erase an existing request or sent order; it blocks new commitments and requires an authorized resolution workflow.

Quantities are authoritative; status is a guarded lifecycle summary:

```text
reserved_quantity = sum(active customer request allocations.quantity)
fulfilled_quantity = sum(fulfilled customer request allocations.quantity)
remaining_quantity = 1 - fulfilled_quantity
```

### 7.6 `orders`

| Field | Requirements |
|---|---|
| `id` | UUIDv7 primary key. |
| `store_id` | Required FK; immutable. |
| `number` | Required store-scoped sequential integer assigned at creation; immutable; never reused. Unique on `(store_id, number)`. |
| `product_variant_id` | Required FK to an active Standard variant; immutable. |
| `supplier_id` | Required active supplier. Editable only while the associated PO is unsent. |
| `customer_request_id` | Optional FK to a Standard request in `special_order_pending` or `ordered`. Present means customer order; null means stock order. Immutable after associated PO send. |
| `requested_quantity` | Required positive integer. Editable only while unsent. |
| `notes` | Optional text. |
| `replaces_order_id` | Optional self-FK to the immediate prior order. Same store, variant, and customer request identity. |
| `cancelled_at`, `cancelled_by_id`, `cancellation_reason` | Optional draft-order cancellation metadata. |
| `lock_version` | Required. |
| timestamps | Required. |

Do not add `order_type`, `demand_reason`, or duplicated customer fields.

An order must have exactly one purchase-order line once created. Creation of the order, selection/creation of the open draft PO, and creation of its PO line occur atomically.

When `customer_request_id` is present, `requested_quantity` must equal one and the order variant/store must equal the request variant/store. Stock orders may use any positive quantity.

Replacement invariants:

- replacement quantity may not exceed quantity cancelled from its predecessor for re-sourcing;
- replacement supplier is required and may equal or differ from the predecessor supplier;
- replacement customer identity must match the predecessor;
- a stock order cannot become a customer order or vice versa through replacement; and
- lineage must be acyclic.

### 7.7 `purchase_orders`

| Field | Requirements |
|---|---|
| `id` | UUIDv7 primary key. |
| `store_id` | Required destination store. |
| `supplier_id` | Required supplier. |
| `number` | Nullable in draft; assigned sequentially within store when the document is generated; immutable and never reused. |
| `status` | Required: `draft`, `sent`, `closed`, or `cancelled`. |
| `generated_at`, `generated_by_id` | Optional until first document generation. |
| `sent_at`, `sent_by_id`, `transmission_method` | Required together for `sent` or `closed`. |
| `document_revision` | Required integer, default 0; increment when an unsent generated PO returns to draft and is regenerated. |
| `notes` | Optional text. |
| `closed_at` | Set automatically when every line open quantity reaches zero. |
| `lock_version` | Required aggregate concurrency token; child edits touch it. |
| timestamps | Required. |

Database/application invariant: at most one automatic open `draft` PO per `(store_id, supplier_id)`. Once that PO is sent, the next order creates a new draft.

A generated-but-unsent PO may return to draft only when:

- `sent_at` is null;
- it has no supplier-response state;
- it has no purchase receipts or cancellations; and
- the caller is authorized.

The number remains assigned and is never returned to the sequence.

### 7.8 `purchase_order_lines`

| Field | Requirements |
|---|---|
| `id` | UUIDv7 primary key. |
| `purchase_order_id` | Required FK. |
| `order_id` | Required FK, unique; establishes one order to one line. |
| `product_variant_id` | Required and equal to the order variant. |
| `ordered_quantity` | Required positive integer. Draft mirrors the editable order quantity; frozen at send. |
| `supplier_item_number_snapshot` | Optional. |
| `pricing_method_snapshot` | Optional source method. |
| `supplier_list_price_cents_snapshot` | Optional. |
| `discount_basis_points_snapshot` | Optional. |
| `expected_unit_cost_cents_snapshot` | Required nonnegative value before send, whether sourced or manually entered. |
| `notes_snapshot` | Optional. |
| timestamps | Required. |

Draft line economics may be overridden by the buyer. The sent snapshot never changes when the supplier source or merchandise record changes later.

### 7.9 `purchase_order_line_states`

One mutable processing-state row per sent line.

| Field | Requirements |
|---|---|
| `purchase_order_line_id` | PK/FK. |
| `confirmed_quantity` | Optional nonnegative supplier acknowledgment quantity. |
| `backordered_quantity` | Required nonnegative integer, default 0. Informational; does not itself reduce open quantity. |
| `expected_on` | Optional date. |
| `supplier_reference` | Optional. |
| `notes` | Optional. |
| `lock_version` | Required. |
| timestamps | Required. |

Acknowledgment is optional. Receipt posting does not require this row to have confirmation data.

### 7.10 `purchase_order_line_cancellations`

| Field | Requirements |
|---|---|
| `id` | UUIDv7 primary key. |
| `purchase_order_line_id` | Required FK. |
| `quantity` | Required positive integer. |
| `source` | Required: `buyer` or `supplier`. |
| `reason` | Required text. |
| `recorded_by_id` | Required user FK. |
| `occurred_at` | Required timestamp. |
| timestamps | Required. |

Cancellations are append-only facts and reduce open quantity immediately. Cumulative cancellation plus posted matched receipt quantity cannot exceed ordered quantity. Re-sourcing creates a replacement order in the same transaction as the cancellation when requested.

### 7.11 `purchase_receipts`

| Field | Requirements |
|---|---|
| `id` | UUIDv7 primary key. |
| `store_id` | Required destination store. |
| `supplier_id` | Required supplier. |
| `number` | Nullable while draft; assigned store-scoped sequential integer **at posting**; immutable after posting; never reused. Abandoned drafts do not consume numbers. |
| `status` | Required: `draft`, `posted`, or `reversed`. `reversed` means every posted line has been fully reversed. |
| `received_at` | Required; no future timestamps. Backdating requires explicit permission. |
| `supplier_document_number` | Optional invoice/packing-slip/reference string. Duplicate values warn but do not block. |
| `supplier_document_date` | Optional date. |
| `freight_cents` | Required nonnegative integer, default 0. |
| `handling_cents` | Required nonnegative integer, default 0. |
| `supplier_tax_cents` | Required nonnegative integer, default 0. |
| `miscellaneous_charges_cents` | Required nonnegative integer, default 0. |
| `charge_notes` | Required when miscellaneous charges are nonzero; otherwise optional. |
| `notes` | Optional text. |
| `posted_at`, `posted_by_id` | Required together when posted. |
| `lock_version` | Required while draft; posted business content is immutable. |
| timestamps | Required. |

Ancillary charges are operational cost facts only. They do not create valuation entries or change moving-average inventory value in Phase 7.

### 7.12 `purchase_receipt_lines`

| Field | Requirements |
|---|---|
| `id` | UUIDv7 primary key. |
| `purchase_receipt_id` | Required FK. |
| `purchase_order_line_id` | Required FK. PO supplier/store must match receipt supplier/store. |
| `product_variant_id` | Required; must equal PO line/order variant. |
| `received_quantity` | Required positive integer. |
| `matched_quantity` | Derived/frozen at posting: minimum of received quantity and locked open quantity. |
| `unplanned_quantity` | Derived/frozen at posting: received minus matched quantity. |
| `actual_unit_cost_cents` | Required nonnegative integer. |
| `notes` | Optional text. |
| timestamps | Required. |

The line merchandise value is:

```text
received_quantity × actual_unit_cost_cents
```

All received quantity posts to inventory. Only `matched_quantity` fulfills the order. `unplanned_quantity` becomes ordinary stock.

### 7.13 `purchase_receipt_line_corrections`

| Field | Requirements |
|---|---|
| `id` | UUIDv7 primary key. |
| `purchase_receipt_line_id` | Required FK. |
| `correction_type` | Required: `quantity_reversal`, `cost_correction`, or `compensating_adjustment_reference`. |
| `quantity` | Positive for quantity reversal; null for cost-only correction. |
| `value_delta_cents` | Required signed amount for cost correction; otherwise derived/recorded as appropriate. |
| `reason` | Required text. |
| `recorded_by_id` | Required user FK. |
| `recorded_at` | Required timestamp. |
| `inventory_source_type`, `inventory_source_id` | Required reference to the resulting posting source/effect. |
| timestamps | Required. |

Corrections are append-only. Cumulative reversal quantity cannot exceed the receipt line's posted quantity. Whole-receipt reversal is a command that creates one eligible correction per line atomically; it is not a separate editable receipt.

### 7.14 `customer_request_allocations`

| Field | Requirements |
|---|---|
| `id` | UUIDv7 primary key. |
| `customer_request_id` | Required FK. |
| `allocation_type` | Required: `standard_quantity` or `used_unit`. Must match the request variant type. |
| `purchase_receipt_line_id` | Optional FK. Present when a Standard special-order receipt created the allocation. Null for located in-store merchandise. |
| `inventory_unit_id` | Required and unique for `used_unit`; null for `standard_quantity`. Unit must be on hand at the request store and match the request variant. |
| `quantity` | Required and fixed at `1` in Phase 7. |
| `status` | Required: `reserved`, `fulfilled`, or `released`. |
| `fulfilled_pos_transaction_line_id` | Required only when fulfilled. |
| `released_at`, `released_by_id`, `release_reason` | Required together when released. |
| `lock_version` | Required while reserved. |
| timestamps | Required. |

Exactly one active allocation may exist per request. A Standard allocation reserves one unit of aggregate quantity. A Used allocation reserves the exact inventory unit. The active allocation contributes to availability but does not change physical on-hand:

```text
standard_quantity → quantity = 1 AND inventory_unit_id IS NULL
used_unit         → quantity = 1 AND inventory_unit_id IS NOT NULL
```

```text
available = on_hand - active_reserved - unavailable
```

Phase 7 implements `active_reserved` for customer requests. Used availability also excludes inventory units with an active allocation. `unavailable` remains zero unless another implemented workflow provides it. Do not add speculative balance columns; derive the reservation component from active allocation records or a rebuildable projection whose authority is those records.

Availability is an application contract, not a UI hint.

1. **Universal stock-depletion rule.** Every stock-depleting command—including `Inventory::PostAdjustment`, `Inventory::PostSale`, depleting post-void paths, and Used-unit removal—validates resulting availability under lock. Reject Standard `available < 0` or removal of an allocated Used unit unless the same atomic command releases, reverses, or transfers that allocation.
2. **Allocation-aware POS exception formulas** (documented here; implemented in Slice 7.6). Ordinary Standard capacity = `available`. Pickup Standard capacity = `available` + quantity allocated to that POS line. Ordinary Used sale requires no active allocation on the unit. Used pickup requires the allocation to belong to that line.
3. **Slice timing.** Slice 7.2 installs the universal hard-stop without a pickup exception. Slice 7.6 adds the allocation-linked pickup exception and fulfillment lifecycle.
4. **Competing `pending_location` requests.** When multiple requests compete for the same last available Standard copy or Used unit, the first successful locate under the published lock order wins; later locates fail with a current-state explanation.

## 8. Eligibility and validation

### 8.1 Merchandise eligibility

New supplier sources, orders, PO lines, and purchase receipts accept only variants that are:

- active;
- inventory-bearing;
- Standard and derived as quantity-tracked; and
- otherwise orderable under current merchandise state.

Reject Used and non-inventory variants at every purchasing boundary, including direct service calls and database-supported invariants where feasible. Revalidate eligibility when sending the PO, not only at draft creation.

Customer request eligibility is different:

- an active Standard variant may be requested whether currently available or out of stock;
- an active Used variant may be requested only when an unreserved on-hand unit exists at the request store;
- an out-of-stock Used variant is not requestable in Phase 7; and
- a Used request can never be converted into an order or associated with a supplier source, PO line, or purchase receipt.

### 8.2 Supplier/source rules

- An active supplier is mandatory on every order.
- A supplier source is optional.
- Source defaults may populate the draft PO line but never remain dynamic after send.
- Preferred-source resolution order is store override, then organization preferred, then none.
- Lack of a preferred source never blocks a manual order if the buyer selects an active supplier and supplies expected cost.
- Supplier deactivation must not strand affected draft orders. Use an unambiguous active fallback or block deactivation until buyers reassign the affected drafts.
- Source deactivation does not cancel an order when its supplier remains active because sources are optional. Clear the draft's live source association, retain its editable expected-economics values for buyer review, and block send until the line again has a valid expected unit cost.
- Sent POs remain historically valid if a supplier or source later becomes inactive.

### 8.3 Store authorization

Every command authorizes the resolved target store, not merely the current UI store. Cross-store IDs in requests must not bypass authorization.

## 9. Lifecycle and workflows

### 9.1 Create stock order

1. Buyer selects store, eligible variant, active supplier, quantity, and optional notes.
2. ShelfSense resolves or creates the single automatic open draft PO for supplier/store.
3. ShelfSense creates the order and its dedicated PO line in one transaction.
4. Source economics default the line when available; otherwise the buyer enters expected unit cost before send.
5. Audit the creation.

### 9.2 Create and route customer request

1. User selects or creates a customer.
2. User selects store, one active variant, optional estimated price, and notes. Quantity is fixed at one.
3. Under the request command's concurrency boundary, ShelfSense evaluates current request availability.
4. For a Standard variant with available quantity, create the request as `pending_location` and add it to the store location queue without reserving inventory.
5. For a Standard variant with no available quantity, create the request as `special_order_pending`; resolve the store-preferred or organization-preferred supplier, or require the user to choose an active supplier; then create the order, draft PO selection/creation, and dedicated line atomically.
6. For a Used variant with an unreserved on-hand unit, create the request as `pending_location` without assigning or reserving a unit yet.
7. Reject an out-of-stock Used request. Phase 7 does not create a waitlist or supplier order.

Availability routing is a current operational decision, not a permanent claim about whether inventory physically exists. A request routed to location can still fail when staff searches for the item.

### 9.3 Confirm located merchandise

The staff queue is store scoped and ordered by age by default. Confirmation requires physical evidence:

- for Standard, staff confirms one physical copy of the requested variant; or
- for Used, staff scans or selects the exact matching on-hand `inventory_unit`.

The confirmation command revalidates availability under lock, creates the appropriate `customer_request_allocation`, and transitions the request to `available`. Standard on-hand does not change but active reserved quantity increases. The Used unit remains `on_hand` but is unavailable to ordinary sale or another request while allocated.

If another operation consumes availability before confirmation, the locate command fails with a current-state explanation and returns the request to an explicit not-located resolution; it must not create an allocation against nonexistent availability.

When two or more `pending_location` requests compete for the same last available Standard copy or Used unit, **first successful locate wins**. Competing locates serialize on the same inventory locks published in [phase7-lock-order.md](phase7-lock-order.md).

### 9.4 Resolve not-located request

Record `location_failed_at`, actor, and optional notes. Then resolve immediately:

- Standard: user chooses **Convert to special order** or **Cancel request**.
- Used: cancellation is mandatory; supplier conversion is prohibited.

Standard conversion preserves the same customer request, transitions it to `special_order_pending`, requires/resolves an active supplier, and creates its order, automatic supplier/store draft PO, and dedicated line atomically. No second customer request is created.

Not-located does not automatically post an inventory adjustment. The UI should link to the existing inventory investigation/adjustment workflow because the physical discrepancy may represent misplaced rather than missing merchandise.

### 9.5 Edit draft

Before send:

- order quantity, supplier, and notes may change;
- customer/store/variant identity may not change;
- expected line economics may change;
- changing supplier atomically moves the order/line to the appropriate supplier/store draft PO;
- when the last line leaves a draft PO (move, cancel, or destroy), ShelfSense removes the empty draft shell so supplier deactivation and draft hygiene do not retain lineless placeholders; and
- optimistic locking rejects stale edits.

Incorrect store, variant, or customer identity requires cancelling the draft order and creating a new one.

### 9.6 Generate and send PO

Generation:

1. Validate every line, supplier, store, variant, quantity, and expected cost.
2. Assign the next store-scoped PO number if absent.
3. Freeze a reproducible document revision.
4. Record generation audit metadata.

An unsent generated PO may return to draft only under §7.7. The number remains consumed and document revision increments on regeneration.

Send:

1. Buyer confirms external transmission method.
2. In one transaction, set `sent_at`, `sent_by_id`, `transmission_method`, and status `sent`.
3. Freeze all supplier-facing line business content.
4. Transition linked customer requests from `special_order_pending` to `ordered` as applicable.
5. Emit audit and outbox events.

### 9.7 Record backorder or cancellation

Backordered quantity is informational and remains open. The buyer may:

- wait;
- record cancellation and create a replacement order; or
- record cancellation without replacement.

Cancellation/re-source command:

1. Lock PO, line state, order lineage, and relevant customer request.
2. Validate cancellation quantity against current open quantity.
3. Append the cancellation fact; open quantity decreases immediately.
4. When re-sourcing, require a replacement supplier and create the linked replacement order, appropriate draft PO, and dedicated line atomically.
5. Recompute automatic PO closure.
6. Audit and emit outbox events.

### 9.8 Create and post physical receipt

Draft receipt creation requires supplier and store. Lines may select open PO lines across multiple POs only when supplier/store match.

Posting locks all affected records in a deterministic order, including receipt, purchase orders/lines, orders/customer requests, and inventory balances. For each line:

1. Recompute open quantity under lock.
2. Freeze matched and unplanned quantities.
3. Require actual unit cost.
4. Call `Inventory::PostReceipt` with the complete received quantity and total merchandise value.
5. Fulfill only the matched order quantity.
6. If the order has an active customer request, create its single Standard allocation for the matched requested copy; overage and quantities for cancelled or already fulfilled requests remain ordinary stock.
7. Recompute line/order/request/PO lifecycle summaries.

The outer command posts the receipt, all inventory effects, allocations, audit events, outbox events, and idempotency completion atomically.

### 9.9 Customer cancellation

Customer cancellation:

- requires a reason and actor;
- always serializes through the store/variant `InventoryBalance` before locking the request so concurrent locate or special-order receipt cannot attach a reserved allocation to a request that is about to be cancelled;
- re-queries and locks any current reserved allocation after the request lock, then releases it;
- does not cancel sent supplier quantities or rewrite sent PO, line, or cancellation history;
- when an unsent special order exists, requires an explicit buyer decision via `cancel_draft_order: true` or `false` (no silent keep/cancel);
- when `cancel_draft_order: true`, cancels only the soft-read **unsent** draft candidates—sent predecessor orders from re-source lineage are ignored and preserved;
- when `cancel_draft_order: true`, locks each unsent candidate's `PurchaseOrder` before its `Order` and `PurchaseOrderLine`, revalidates `po.draft?` and `sent_at` after the PO lock, and returns a domain conflict if that candidate was sent concurrently;
- causes later receipts to become ordinary stock; and
- preserves all order and receipt history.

### 9.10 Customer pickup through POS

Pickup is an extension of the existing Register workspace—not a purchasing ops workspace and not a free-standing “mark completed” admin action.

The cashier selects an `available` customer request/allocation and adds its reserved Standard copy or exact Used unit to the working transaction.

Required behavior:

- line pricing and tax use normal POS rules at transaction time; estimated request price is informational;
- the transaction line references the customer request allocation;
- allocation remains active while the sale is merely being composed unless an existing POS reservation mechanism explicitly owns the working hold;
- only successful transaction completion changes the allocation to `fulfilled`;
- normal `Inventory::PostSale` reduces on-hand;
- cancellation or failed completion does not falsely fulfill the request;
- request becomes `completed` when its quantity-one allocation is fulfilled; and
- Phase 7 does not provide a command to mark a request completed without that POS completion path.

Concurrent pickup attempts must lock/validate the allocation so it cannot be fulfilled twice.

**Ordinary vs pickup capacity.** An ordinary POS line hard-stops against reserved availability: Standard capacity = `available`; an allocated Used unit is never sellable on an ordinary line. A pickup line (Slice 7.6) may consume only its own allocation: Standard pickup capacity = `available` + quantity allocated to that line; Used pickup must use the exact unit owned by that allocation. Until Slice 7.6, no pickup exception exists—ordinary hard-stop applies to every Register sale path.

### 9.11 Receipt correction

#### Eligible quantity reversal

`Inventory::ReverseReceiptLine` writes exact inverse physical and valuation entries tied to the original receipt-line effects. It must fail if exact inversion is unsafe under the implemented valuation and downstream-allocation rules.

The command also reverses/reconciles matched order fulfillment and any still-active allocation created by that receipt line. It must not silently undo a completed customer pickup.

#### Cost-only correction

When quantity is correct but actual unit cost was wrong, `Inventory::CorrectReceiptLineCost` writes a valuation-only delta tied to the original receipt line and correction record. It does not alter physical quantity or rewrite the posted receipt.

#### Downstream conflict

If later sale/pickup activity prevents exact reversal, require a separately authorized compensating adjustment with explicit reason and cross-reference. Do not force an approximate receipt reversal.

## 10. Quantity and status derivation

For a sent PO line:

```text
posted_matched_quantity =
  sum(posted receipt-line matched quantity)
  - sum(eligible matched quantity reversals)

cancelled_quantity = sum(purchase_order_line_cancellations.quantity)

open_quantity = ordered_quantity - posted_matched_quantity - cancelled_quantity
```

Constraints:

```text
posted_matched_quantity >= 0
cancelled_quantity >= 0
open_quantity >= 0
posted_matched_quantity + cancelled_quantity <= ordered_quantity
```

Unplanned receipt quantity does not enter these equations.

PO closure is automatic when every line has `open_quantity = 0`. A backordered quantity remains open until received or cancelled.

Customer request lifecycle:

- `pending_location`: variant appeared available and awaits physical confirmation; no allocation exists;
- `special_order_pending`: Standard request requires supplier purchasing but its PO has not yet been sent;
- `ordered`: associated supplier PO was sent and no received allocation exists;
- `available`: one located or received copy/unit is actively allocated for pickup;
- `completed`: the allocation was fulfilled through a successfully completed POS transaction;
- `cancelled`: explicitly cancelled, regardless of any remaining sent supplier commitment.

There is no `partially_available` state because Phase 7 customer requests are quantity one. `location_failed` is recorded metadata followed immediately by conversion/cancellation, not a durable status.

## 11. Inventory posting extension

Add these named services to the inventory posting contract. Until their implementing slices land, each is **Planned for Phase 7; not implemented**.

| Service | Purpose | Required source | Status |
|---|---|---|---|
| `Inventory::PostReceipt` | Add purchase-received quantity and merchandise value using moving weighted average | `PurchaseReceiptLine` | Planned for Phase 7; not implemented |
| `Inventory::ReverseReceiptLine` | Exact inverse of eligible posted receipt-line physical and valuation effects | `PurchaseReceiptLineCorrection` | Planned for Phase 7; not implemented |
| `Inventory::CorrectReceiptLineCost` | Valuation-only delta for a cost error with correct quantity | `PurchaseReceiptLineCorrection` | Planned for Phase 7; not implemented |

When customer-request allocations exist, the reservation hard-stop from §7.14 applies to **all** stock-depleting posting paths—including already-implemented `Inventory::PostAdjustment`, `Inventory::PostSale`, and depleting post-void—not only to the new purchasing services.

`Inventory::PostReceipt`:

- accepts only quantity-tracked eligible merchandise in Phase 7;
- joins the caller's transaction;
- does not call `Inventory::PostAdjustment`;
- locks `InventoryBalance` through the established lock/create boundary;
- posts `quantity_delta = received_quantity`;
- posts `value_delta_cents = received_quantity × actual_unit_cost_cents`;
- uses source type/id and effect sequence uniqueness for duplicate protection;
- writes paired physical and valuation entries with identical store, variant, source, time, business date, and quantity;
- updates the rebuildable projection; and
- emits `inventory.receipt_posted` in the same outer transaction.

Receipt ancillary charges never enter `value_delta_cents` in Phase 7.

## 12. Money and landed-cost boundary

Phase 7 records:

```text
merchandise_total_cents =
  sum(received_quantity × actual_unit_cost_cents)

ancillary_total_cents =
  freight_cents
  + handling_cents
  + supplier_tax_cents
  + miscellaneous_charges_cents

operational_acquisition_total_cents =
  merchandise_total_cents + ancillary_total_cents
```

Only `merchandise_total_cents` affects inventory carrying value.

This is deliberate—not a claim that ancillary costs are never capitalizable. Phase 7 preserves the inputs needed for later landed-cost allocation while deferring allocation basis, late-arriving charges, correction rules, and GL consequences.

## 13. Authorization

Suggested permission catalog:

| Permission | Scope/purpose |
|---|---|
| `suppliers.view` | View suppliers and sources. |
| `suppliers.manage` | Create/edit/reactivate/deactivate suppliers and sources. |
| `customers.view` | Find customers and requests. |
| `customers.manage` | Create/edit customer identity. |
| `customer_requests.manage` | Create, edit, cancel, and convert requests. |
| `customer_requests.locate` | Confirm located Standard merchandise or exact Used units and resolve not-located requests. |
| `orders.view` | View orders and POs. |
| `orders.manage` | Create/edit/cancel draft orders and PO lines. |
| `purchase_orders.send` | Generate/send PO and record transmission. |
| `purchase_orders.cancel` | Record cancellation against sent quantity. |
| `purchase_receipts.view` | View receipts. |
| `purchase_receipts.manage` | Create/edit receipt drafts. |
| `purchase_receipts.post` | Post a receipt and inventory effects. |
| `purchase_receipts.backdate` | Supply permitted past received time/date. |
| `purchase_receipts.correct` | Reverse eligible lines and post cost-only corrections. |
| `purchase_receipts.compensate` | Authorize a compensating adjustment when exact reversal is unsafe. |
| `customer_requests.pickup` | Select and fulfill an available customer allocation through POS. |

Every permission is evaluated against the resolved target store when the record is store-scoped. Supplier configuration may be global; store preference mutation requires authorization for that store.

## 14. Audit requirements

Audit at minimum:

- supplier/source creation, material edit, activation, and deactivation;
- preferred-source changes;
- customer request creation, routing, location success/failure, conversion, cancellation, and completion;
- order creation, draft reassignment, cancellation, and replacement;
- PO number assignment, regeneration, send, cancellation, and automatic closure;
- receipt creation when material, posting, reversal, cost correction, and compensating adjustment reference;
- ancillary receipt charge changes before posting;
- supplier document duplicate-warning acknowledgment if implemented;
- customer allocation creation, release, and fulfillment; and
- all permission-sensitive overrides.

Audit metadata should include before/after quantities and costs, reason, source record IDs, actor, store, and lineage/correction references without duplicating immutable payloads unnecessarily.

## 15. Idempotency, concurrency, and lock ordering

At minimum, these commands are retryable business operations under ADR-009:

- create and route customer request;
- confirm located merchandise;
- resolve not-located request;
- create stock order;
- send PO;
- cancel/re-source quantity;
- post receipt;
- reverse receipt line/whole receipt;
- correct receipt-line cost;
- cancel customer request; and
- complete customer pickup allocation.

Each defines canonical payload hashing and stable result semantics. Database uniqueness remains the final duplicate-effect defense.

Mutable roots use `lock_version`. Child edits increment/touch their aggregate root token.

The authoritative Phase 7 command lock matrix is [phase7-lock-order.md](phase7-lock-order.md). It covers locate, ordinary sale, customer pickup, negative adjustment, special-order receipt posting, cancel request, reverse receipt, and depleting post-void. Standard serialization is via locked `InventoryBalance`; Used keeps `InventoryBalance → InventoryUnit`. Locate and ordinary sale must share that inventory serialization before deciding who gets the last available copy.

The exact order must be reconciled with the already implemented POS and Inventory service lock orders during Slice 7.2. No caller may pre-lock an inventory row in an order that conflicts with the named posting kernel.

## 16. Outbox events

Suggested events:

- `purchasing.order_created`
- `purchasing.order_replaced`
- `purchasing.purchase_order_sent`
- `purchasing.purchase_order_quantity_cancelled`
- `purchasing.purchase_order_closed`
- `purchasing.receipt_posted`
- `purchasing.receipt_line_reversed`
- `purchasing.receipt_cost_corrected`
- `customer.request_created`
- `customer.request_routed_to_location`
- `customer.request_converted_to_special_order`
- `customer.request_allocation_created`
- `customer.request_cancelled`
- `customer.request_available`
- `customer.request_completed`
- `inventory.receipt_posted`
- `inventory.receipt_reversed`
- `inventory.receipt_cost_corrected`

Commercial and inventory events are distinct descriptions of effects but are committed atomically with their source command.

## 17. Administrative and operator UX

Phase 7 uses three presentation surfaces:

1. **Admin chrome** — suppliers, sources, customers, request history, posted PO/receipt review, and other configuration or after-the-fact lookup. Server-rendered Rails; do not add Hotwire to admin chrome as a side effect of Phase 7.
2. **Purchasing ops workspaces** — location queue, draft PO builder, and receiving. These are Register-class surfaces: dedicated layout, Importmap + Turbo + Stimulus, keyboard- and scanner-first focus rules, and system/browser tests where the project’s testing strategy already requires them for Register. They are siblings of the POS Register workspace, not pages inside the admin shell.
3. **POS Register workspace** — remains the existing Phase 5/6 contract. Phase 7 extends it for customer-request pickup and reservation-aware ordinary sales. Do **not** fold Register into a shared purchasing/ops shell in Phase 7.

Optional shared Stimulus/helpers (scan buffer, sticky primary input, ambiguous-match picker, row focus, Escape-to-cancel-mode, recoverable validation) may be extracted for reuse across purchasing ops workspaces. Extracting a unified “ops shell” that also hosts POS is deferred.

Authority for the Register pattern: [register-workspace.md](../phase4-6-point-of-sale/phase5-cash-register/register-workspace.md). Purchasing ops workspaces follow the same governing UX principle: where are the operator’s eyes, where is keyboard focus, and what will the next keystroke do?

### 17.1 Purchasing navigation

Purchasing is a first-class top-level area in admin chrome for configuration and history:

```text
Purchasing
├── Orders
├── Purchase Orders
├── Receiving
├── Customer Requests
└── Suppliers
```

High-frequency work opens the dedicated ops workspace rather than a dense admin table:

- **Locate** → location ops workspace;
- **Open draft PO** / continue building → draft PO ops workspace;
- **Receive delivery** → receiving ops workspace.

The purchasing landing page may still prioritize active-work summaries (requests awaiting location, draft POs, open sent POs, receipt drafts, exceptions) with links into the correct workspace. Supplier configuration remains available but visually secondary to active work.

### 17.2 Product and variant integration

It must be easy to begin purchasing/request work from existing merchandise screens without creating an alternate simplified business model.

Product show:

- each variant row shows Standard/Used identity, on hand, reserved, available, open stock-order quantity, and open customer-order quantity;
- **Order stock** appears only for eligible Standard variants;
- **Create customer request** is the single customer-facing action: it appears for any active Standard variant and for an in-stock Used variant, then routes automatically from availability;
- out-of-stock Used variants do not offer a request action in Phase 7;
- supplier/preferred-cost information appears only for Standard variants; and
- when a product has one eligible target variant, a product-level action may choose it automatically; otherwise show a compact keyboard-selectable variant chooser.

Variant show includes a prominent operational panel:

- on hand, reserved, available, and on order;
- preferred supplier and expected cost for Standard only;
- active request/order summaries; and
- context-appropriate actions under the eligibility rules above.

Quick stock-order form is prepopulated with current store, variant, preferred supplier when available, expected-cost preview, quantity, and optional notes. Quick customer-request form is prepopulated with store and variant, fixes quantity at one, and begins with customer lookup/create. After creation, confirmation states the routing result and links to the location queue/request or draft PO ops workspace. Quick actions call the same domain commands as full workspaces.

### 17.3 Location ops workspace

Dedicated ops layout for the store-scoped location queue. Defaults to oldest request first and shows:

- request age;
- customer/contact summary;
- title, variant, identifiers, and Standard/Used badge;
- shelving/category information available from merchandise;
- apparent availability;
- **Locate** and **Not located** actions.

Locate Standard asks for physical confirmation of the copy. Locate Used requires scanning/selecting the exact matching inventory unit. Not located immediately presents the valid resolution: Standard converts to special order or cancels; Used cancels.

Required workspace behavior:

- persistent primary scan/input restored after successful actions;
- keyboard focus, row movement, identifier scanning, Enter to open the primary action, Escape to return without changing state;
- visible button equivalents for every shortcut; and
- no assignment, priority, SLA, or route-optimization chrome in Phase 7.

### 17.4 Draft PO ops workspace

Because orders automatically enter the supplier/store draft PO, building the PO is primarily a review and fast-entry workflow in a dedicated ops layout.

Persistent header:

- supplier;
- destination store;
- number when generated;
- lifecycle status;
- line count and expected merchandise total;
- validation summary; and
- generate/send action.

Editable grid columns include identifier/title, quantity, list price, discount, expected unit cost, customer indicator, and notes. Every row remains backed by its own order and dedicated PO line.

Required keyboard behavior:

- `/` focuses identifier/title lookup;
- scanner input followed by Enter resolves a Standard variant;
- Used matches are excluded rather than displayed as orderable results;
- Enter accepts the current field/adds a line;
- Tab and Shift+Tab traverse editable cells predictably;
- arrow-key grid navigation is supported where it does not interfere with text editing;
- `Ctrl/Command+Enter` saves the current line/draft or invokes the clearly labeled primary action according to workspace state;
- primary lookup focus is restored after successful line entry; and
- a visible shortcut-help control lists bindings.

Scanning from a fixed supplier/store draft creates the underlying stock order and dedicated line; it never bypasses `orders`. Customer lines display a compact customer badge. Inline validation identifies missing cost, invalid quantity, inactive supplier/source, ineligible variant, or stale edit and can focus the affected row.

### 17.5 Receiving ops workspace

Receiving is the most keyboard-optimized Phase 7 ops workspace and uses a dedicated layout.

Start receipt by selecting destination store and supplier, then optionally entering supplier document number/date. ShelfSense limits matching to open Standard PO lines for that supplier/store.

Layout:

1. persistent header for supplier, store, delivery date, supplier reference, and draft/posted state;
2. always-available scan/search and current-line editor; and
3. received-lines grid with match and cost detail.

The grid visibly shows item, PO, open quantity, received quantity, matched quantity, unplanned quantity, actual unit cost, and customer-request indicator.

Fast path:

1. scan identifier;
2. resolve open matching PO lines;
3. automatically select the single match, or show a keyboard-selectable list with PO, customer, open quantity, expected cost, and date;
4. default received quantity to open quantity and display expected cost as an editable starting value—not as actual authority;
5. require confirmation/entry of actual quantity and unit cost;
6. Enter adds the draft line and restores scan focus.

At minimum, Enter confirms, Escape exits the current lookup without abandoning the receipt, `Ctrl/Command+S` saves the draft, and `Ctrl/Command+Enter` opens posting review. Additional function-key bindings should align with existing POS conventions and always have visible button equivalents.

Ancillary charges live in a compact receipt section that does not interrupt scan entry. Posting uses a substantial review surface—not a generic browser confirmation—and summarizes received, matched, unplanned, and customer-reserved units; merchandise value; each ancillary charge category; operational acquisition total; and all warnings. The final action is explicitly labeled **Post receipt**.

### 17.6 Customer request admin views and POS pickup

Request show (admin) links the location outcome, active allocation, supplier order/replacement lineage, PO, purchase receipt, and completed POS pickup as applicable. It emphasizes the current operator action rather than exposing raw status editing. It does not offer “mark completed” without POS.

Pickup lives on the Register workspace:

- POS lookup supports customer name, phone, request identifier, and merchandise identifier;
- only `available` requests can be added;
- the UI clearly identifies Standard aggregate reservation versus exact Used unit and prevents substitution of another Used unit; and
- ordinary Register merchandise entry continues to hard-stop against reserved availability as in §7.14 / §9.10.

### 17.7 Shared interaction rules

Ops chrome minimum (location, draft PO, receiving):

- branding;
- store, document identity, and signed-in user;
- explicit exit to Purchasing admin navigation;
- no silent draft loss (recoverable save, confirm before discard, or equivalent);
- authorization enforcement, flash/dialog feedback, and accessibility for keyboard and visible controls;
- shared helpers allowed; a shared shell that also hosts POS is not.

Additional shared rules:

- Preserve entered data and focus after recoverable errors.
- Keep primary identity and status visible while scrolling dense workspaces.
- Do not hide high-frequency actions in overflow menus.
- Place validation beside the affected row/field, with an aggregate exception summary before send/post.
- Give every keyboard shortcut a visible and accessible control equivalent.
- Do not require hover or pointer interaction.
- Use a clearly surfaced dialog/panel with its own background for consequential review and confirmation.
- Optimize ops workspaces for desktop keyboard and barcode scanners without weakening accessibility.
- Quick actions shorten navigation only; they call the same domain commands and create the same records as full workspaces.
- Server owns business truth; Turbo replaces grids/panels; Stimulus owns focus and key bindings.
- Retryable workspace POSTs use ADR-009 idempotency so double-Enter or scan retries do not double-apply effects.

The UI must visibly distinguish expected from actual cost, matched from unplanned receipt quantity, merchandise carrying value from ancillary acquisition costs, available from customer-reserved stock, backordered from cancelled quantity, and a replacement order from its predecessor.

## 18. Implementation slices

### Slice 7.0 — Planning packet (docs only)

Amend and promote the Phase 7 planning packet. No application code.

Deliverable: authoritative docs under `docs/planning/phase7-orders-and-receiving/`; drafts reduced to stubs; README and docs index link Phase 7 as proposed / in progress on the integration branch.

### Slice 7.1 — Suppliers and sources

- tables: `suppliers`, `supplier_variant_sources`, `store_supplier_source_preferences`;
- Standard-only sources; preferred resolution (store override → org preferred → none);
- permissions `suppliers.*`; audit; admin CRUD.

Deliverable: configure suppliers/sources without a source required for later orders.

### Slice 7.2 — Customers, requests, locate, and universal availability enforcement

First reservation-bearing slice. After this slice, every commit preserves the reservation invariant.

- minimal `customers`, quantity-one `customer_requests` (store-scoped request number), `customer_request_allocations`;
- location ops workspace; locate/reserve Standard and Used;
- shared Availability kernel serialized with [phase7-lock-order.md](phase7-lock-order.md);
- **hard-stop in every currently implemented stock-depleting path**, including `Inventory::PostAdjustment` (negative / unit removal), `Inventory::PostSale`, depleting post-void paths, and Register merchandise-add validation with authoritative re-check at posting;
- ordinary Register sale respects reserved Standard qty and allocated Used units;
- **no** allocation-linked pickup exception yet (pickup cannot succeed until 7.6);
- competing `pending_location`: first successful locate wins; concurrency/deadlock tests in this slice;
- intentionally incomplete / coherent: in-stock Standard and Used create + locate work; unlocated Used cancellation works; OOS Standard create and Standard not-located→convert are **feature-gated** until 7.3; UI must not create `special_order_pending` without order+PO line; no orphaned “waiting for purchasing” request state.

Deliverable: reserve in-store stock safely; ordinary POS and adjustments cannot steal it.

### Slice 7.3 — Orders and draft PO workspace

- `orders` (store-scoped order number at create), draft `purchase_orders` / lines;
- auto open draft PO per `(store_id, supplier_id)`; one order ↔ one line;
- scan/search from fixed supplier/store draft **atomically creates stock order + dedicated PO line** (never a bare PO line);
- atomically enable: OOS Standard → request + order + draft line; unlocated Standard convert → order + draft line; preferred-supplier resolution;
- customer cancel with **unsent** special order: explicit buyer decision whether to cancel the draft order (no silent keep/cancel);
- Used rejected at every purchasing boundary.

Deliverable: stock or Standard special order is a draft PO line; special-order paths live.

### Slice 7.4 — Generate, send, cancel, re-source

- PO number at generate; send lock; immutable snapshots; line states; cancellations; replacement orders; auto-close.

Deliverable: send immutable PO; cancel/re-source without rewriting history.

### Slice 7.5 — Receiving and `Inventory::PostReceipt`

- receipts/lines; multi-PO same supplier/store; matched vs unplanned; ancillary cents not in valuation;
- receipt **number assigned at post**; `Inventory::PostReceipt` (mark Implemented in the inventory posting contract);
- receiving ops workspace; special-order receipt → Standard allocation when request active.

Deliverable: post a physical delivery; inventory + open quantities update.

### Slice 7.6 — Allocation-linked Register pickup

Hard-stop already exists from 7.2. This slice adds only:

- allocation-linked POS transaction lines;
- ordinary line capacity = `available`; pickup line may consume only its own allocation;
- exact Used-unit ownership for pickup;
- fulfillment only on successful POS completion; failed/cancelled TX leaves allocation available;
- no admin completion path.

Deliverable: customer pickup completes the request on Register.

### Slice 7.7 — Corrections and phase closeout

- `Inventory::ReverseReceiptLine`, `Inventory::CorrectReceiptLineCost`; compensating path when unsafe; whole-receipt convenience;
- expanded manual gate; final PR integration → `main`;
- after merge: mark Phase 7 implemented in README / docs index.

Deliverable: correct without editing posted facts; phase closed.

## 19. Acceptance criteria

Phase 7 is complete when all of the following are demonstrated.

### Suppliers and sources

- Used variants cannot have supplier sources or store source preferences.
- Active supplier is required for an order.
- Missing source does not block a manually priced draft line.
- Source defaults populate but do not dynamically alter sent lines.
- Store preference overrides organization preference.
- Supplier deactivation cannot strand draft orders without an active deterministic replacement or explicit buyer reassignment.
- Source deactivation leaves the supplier order intact, removes the inactive source as a default, and requires buyer review before send.

### Orders and POs

- Used variants cannot create orders or PO lines through UI, service, import, or direct persisted association.
- Stock order has no customer request; customer order has exactly one.
- Each order has exactly one dedicated PO line.
- Orders for the same supplier/store automatically share the open draft PO but remain separate lines.
- Changing supplier while unsent moves the order/line atomically.
- Sent POs and line snapshots reject business-content edits.
- Customer request numbers and order numbers are assigned at creation, unique per store, immutable, and never reused.
- PO numbers are unique and sequential within store, assigned at generate, and never reused.
- Partial cancellation can atomically create a correctly linked replacement order.
- Open quantity never becomes negative.
- PO closes automatically when all lines are fully received/cancelled.

### Receiving

- One receipt can post lines from multiple matching POs.
- Supplier/store mismatch is rejected.
- Receipt line requires actual unit cost.
- Over-shipment posts as unplanned stock without changing ordered quantity.
- Receipt numbers are assigned at posting, unique per store, immutable after post, and never reused; abandoned drafts do not consume numbers.
- Receipt posting is idempotent and atomic across receipt, inventory, valuation, allocations, audit, and outbox.
- Freight, handling, supplier tax, and miscellaneous charges appear in operational totals but do not change inventory carrying value.
- Posted receipt business content cannot be edited.

### Customers and pickup

- Customer request quantity is exactly one.
- In-stock Standard and Used requests enter the location queue without reserving inventory.
- Out-of-stock Standard requests route to special ordering; out-of-stock Used requests are rejected.
- Standard physical confirmation creates one aggregate allocation; Used confirmation requires the exact matching on-hand inventory unit.
- Competing `pending_location` requests: first successful locate wins; later locates fail with current-state explanation.
- Unlocated Standard request converts to a special order or cancels; unlocated Used request cancels and cannot be supplier ordered.
- Posted special-order receipt immediately creates the Standard allocation.
- Active allocation is excluded from general availability without reducing on-hand.
- From Slice 7.2 onward, every stock-depleting path hard-stops against reserved Standard availability and allocated Used units (including `Inventory::PostSale` and negative adjustments).
- Customer cancellation releases the active allocation and does not cancel sent PO quantity.
- Customer cancellation with `cancel_draft_order: true` cancels only unsent draft orders; sent predecessor orders and their cancellation history from re-source lineage remain intact.
- Later receipt for a cancelled request becomes ordinary stock.
- Slice 7.6 pickup: ordinary capacity = `available`; pickup capacity = `available` + allocation on that line; Used pickup must own the allocation.
- POS completion consumes the allocation and completes the request only after successful tendered transaction completion.
- There is no Phase 7 command to mark a request completed without POS pickup.
- Concurrent pickup cannot fulfill the same allocation twice.

### Corrections

- Eligible receipt line can be exactly reversed once up to its remaining posted quantity.
- Whole-receipt reversal creates per-line corrections atomically or fails without partial effect.
- Cost-only correction changes valuation without changing physical quantity.
- Unsafe exact reversal is blocked and requires separately authorized compensation.
- Original receipt, ledger, valuation, customer, and PO history remain reconstructable.

### Chrome and operator UX

- Admin chrome covers suppliers, sources, customers, history, and posted-document review without Hotwire.
- Location, draft PO, and receiving use dedicated Register-class ops workspaces with ops chrome minimum (branding; store/doc/user; exit to Purchasing; no silent draft loss; authz/flash/dialog/a11y); POS Register remains a separate workspace and is not folded into a shared ops shell in Phase 7.
- Customer pickup extends the existing Register workspace.
- Product and variant views expose only eligibility-correct Order stock and Create customer request actions.
- Used variants never appear in supplier-source, order-entry, PO-line, or receiving lookup results.
- Quick actions create the same domain records as full purchasing workspaces.
- Location, draft PO, and receiving primary flows can be completed without a pointer.
- Barcode scan followed by Enter preserves a predictable add/confirm/refocus loop in PO and receiving workspaces.
- Receiving review shows matched, unplanned, customer-allocation, merchandise-value, and ancillary-charge totals before posting.
- Validation preserves recoverable input, identifies the affected row, and does not strand keyboard focus.
- Every shortcut has a visible accessible control equivalent.

### Security and operations

- Every store-scoped command authorizes the resolved target store.
- Stale mutable edits are rejected through `lock_version`.
- Retry with same idempotency key/payload returns the original result; mismatched payload is rejected.
- Required audit and outbox records commit with the business operation.
- Projection rebuild reproduces the same physical quantity and valuation after purchasing effects.
- Command lock order matches [phase7-lock-order.md](phase7-lock-order.md) (reconciled with POS/Inventory kernels in Slice 7.2).

## 20. Required tests

At minimum:

- model/database constraint tests for every check, partial unique index, and one-to-one relationship;
- numbering tests: request/order at create, PO at generate, receipt at post; uniqueness; abandoned draft receipts do not consume numbers;
- service tests for stock order and customer-order creation;
- request routing tests for in-stock/out-of-stock Standard and Used variants;
- pending-location no-reservation tests;
- Standard locate and exact Used-unit allocation tests;
- competing locate / first-wins concurrency tests;
- not-located conversion/cancellation tests;
- hard Used exclusion tests for sources, orders, POs, receipts, services, and lookup results;
- Slice 7.2 universal hard-stop tests for `Inventory::PostAdjustment`, `Inventory::PostSale`, depleting post-void, and Register add validation;
- supplier change and draft-PO reassignment tests;
- source default/snapshot tests;
- sent immutability tests;
- cancellation and multi-generation replacement-lineage tests;
- partial, full, cancelled, and backordered quantity arithmetic tests;
- multi-PO same-supplier/store receipt tests;
- cross-supplier and cross-store receipt rejection tests;
- over-shipment/unplanned-stock tests;
- moving-average receipt valuation and ancillary-cost exclusion tests;
- receipt retry, stale edit, and concurrent receipt tests;
- special-order allocation, cancellation, and later-stock receipt tests;
- concurrent POS pickup tests;
- ordinary vs pickup capacity tests (ordinary blocked by reservation; pickup exception only on allocation-linked lines);
- keyboard/workspace request tests for scan focus, ambiguous matches, inline validation, and posting review where supported by the project's test strategy;
- receipt reversal, cost correction, and downstream-conflict tests;
- authorization tests for global and store-scoped assignments, including hostile cross-store IDs;
- audit/outbox atomicity tests; and
- inventory projection rebuild/reconciliation tests including posted and reversed receipts.

## 21. Completion boundary

Phase 7 is an operational purchasing and customer-special-order phase, not an accounting or automated replenishment phase.

The completed system must know:

- which quantity-one customer requests routed to location versus Standard special ordering;
- what staff physically located and allocated, including the exact Used unit;
- why an unlocated request converted or cancelled;
- what was requested from suppliers for stock or a Standard customer request;
- what was sent to which supplier;
- what the supplier did not fulfill;
- what physically arrived;
- what merchandise cost at receipt;
- which ancillary acquisition charges were recorded;
- what entered inventory and valuation;
- what is reserved for a customer;
- what the customer picked up; and
- what purchasing quantity remains open.

It is not required to prove a supplier invoice, calculate landed cost, produce accounts-payable entries, automate reordering, or manage supplier returns.
