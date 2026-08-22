# Phase 7 — Target schema

Status: **accepted**. Normative field and constraint extract from [phase7-spec.md](phase7-spec.md) §7. Unlisted tables and columns stay as in `db/schema.rb` unless a later phase changes them.

Conventions match the rest of ShelfSense: UUIDv7 ids (`create_uuid_table` / `id: :uuid, default: nil`), `timestamptz`, `lock_version` on mutable roots, integer cents, integer basis points.

---

## 1. `suppliers`

| Field | Type | Rules |
|---|---|---|
| `id` | uuid | PK; UUIDv7 |
| `code` | string | Required; normalized; unique; immutable after create |
| `name` | string | Required |
| `account_number` | string | Optional |
| `contact_name` | string | Optional |
| `email` | string | Optional |
| `phone` | string | Optional |
| `address_*` | string | Optional; follow existing store address conventions |
| `ordering_notes` | text | Optional |
| `active` | boolean | Required; default `true` |
| `lock_version` | integer | Required; default `0` |
| timestamps | timestamptz | Required |

### Constraints and indexes

```text
unique (code)
```

Do not hard-delete suppliers referenced by orders or receipts; deactivate instead.

---

## 2. `supplier_variant_sources`

| Field | Type | Rules |
|---|---|---|
| `id` | uuid | PK; UUIDv7 |
| `supplier_id` | uuid | Required FK → `suppliers` |
| `product_variant_id` | uuid | Required FK → Standard variant only |
| `supplier_item_number` | string | Optional; unique within supplier when present (normalized) |
| `pricing_method` | string | Required; `discount_from_list` or `direct_unit_cost` |
| `supplier_list_price_cents` | integer | Required for `discount_from_list` |
| `discount_basis_points` | integer | Required for `discount_from_list`; bounded basis points |
| `expected_unit_cost_cents` | integer | Required for `direct_unit_cost`; nonnegative |
| `organization_preferred` | boolean | Required; default `false`; at most one active org-preferred source per variant |
| `active` | boolean | Required; default `true` |
| `lock_version` | integer | Required |
| timestamps | timestamptz | Required |

### Constraints and indexes

```text
index (supplier_id)
index (product_variant_id)
unique (supplier_id, supplier_item_number) where supplier_item_number is not null
unique (product_variant_id) where organization_preferred and active
check pricing_method in (discount_from_list, direct_unit_cost)
```

Reject Used and non-inventory variants.

---

## 3. `store_supplier_source_preferences`

| Field | Type | Rules |
|---|---|---|
| `id` | uuid | PK; UUIDv7 |
| `store_id` | uuid | Required FK → `stores` |
| `product_variant_id` | uuid | Required FK; same Standard variant as the source |
| `supplier_variant_source_id` | uuid | Required FK → active source for that variant |
| `lock_version` | integer | Required |
| timestamps | timestamptz | Required |

```text
unique (store_id, product_variant_id)
index (supplier_variant_source_id)
```

Store preference overrides `organization_preferred`.

---

## 4. `customers`

Minimal identity for requests and pickup.

| Field | Type | Rules |
|---|---|---|
| `id` | uuid | PK; UUIDv7 |
| `display_name` | string | Required |
| `email` | string | Optional |
| `phone` | string | Optional |
| `notes` | text | Optional |
| `active` | boolean | Required; default `true` |
| `lock_version` | integer | Required |
| timestamps | timestamptz | Required |

Application may require email or phone when contact is needed. Duplicate detection may warn; do not auto-merge.

---

## 5. `customer_requests`

| Field | Type | Rules |
|---|---|---|
| `id` | uuid | PK; UUIDv7 |
| `store_id` | uuid | Required FK; immutable |
| `number` | integer | Required; store-scoped sequential; assigned at create; immutable; never reused |
| `customer_id` | uuid | Required FK → `customers` |
| `product_variant_id` | uuid | Required FK; immutable |
| `requested_quantity` | integer | Required; fixed at `1` in Phase 7 |
| `estimated_price_cents` | integer | Optional; informational only |
| `notes` | text | Optional |
| `status` | string | Required; see lifecycle below |
| `location_failed_at` | timestamptz | Optional |
| `location_failed_by_id` | uuid | Optional FK → users |
| `location_failure_notes` | text | Optional |
| `cancelled_at` | timestamptz | Required on cancel |
| `cancelled_by_id` | uuid | Required on cancel |
| `cancellation_reason` | text | Required on cancel |
| `completed_at` | timestamptz | Set on POS pickup completion |
| `lock_version` | integer | Required |
| timestamps | timestamptz | Required |

```text
unique (store_id, number)
index (store_id, status)
index (customer_id)
check requested_quantity = 1
check status in (
  pending_location,
  special_order_pending,
  ordered,
  available,
  completed,
  cancelled
)
```

Statuses: `pending_location`, `special_order_pending`, `ordered`, `available`, `completed`, `cancelled`.

---

## 6. `orders`

| Field | Type | Rules |
|---|---|---|
| `id` | uuid | PK; UUIDv7 |
| `store_id` | uuid | Required FK; immutable |
| `number` | integer | Required; store-scoped sequential; assigned at create; immutable; never reused |
| `product_variant_id` | uuid | Required FK → active Standard variant; immutable |
| `supplier_id` | uuid | Required FK → active supplier; editable only while PO unsent |
| `customer_request_id` | uuid | Optional FK → Standard request; present = customer order |
| `requested_quantity` | integer | Required positive; editable only while unsent |
| `notes` | text | Optional |
| `replaces_order_id` | uuid | Optional self-FK |
| `cancelled_at` / `cancelled_by_id` / `cancellation_reason` | | Optional draft cancellation metadata |
| `lock_version` | integer | Required |
| timestamps | timestamptz | Required |

```text
unique (store_id, number)
unique (id) -- one dedicated purchase_order_line per order (enforced via purchase_order_lines.order_id unique)
index (supplier_id)
index (customer_request_id)
check requested_quantity > 0
```

Do not add `order_type` / `demand_reason`. When `customer_request_id` is present, `requested_quantity` must be `1` and store/variant must match the request.

---

## 7. `purchase_orders`

| Field | Type | Rules |
|---|---|---|
| `id` | uuid | PK; UUIDv7 |
| `store_id` | uuid | Required destination store |
| `supplier_id` | uuid | Required supplier |
| `number` | integer | Nullable in draft; assigned at generate; immutable; never reused |
| `status` | string | `draft`, `sent`, `closed`, or `cancelled` |
| `generated_at` / `generated_by_id` | | Optional until first generation |
| `sent_at` / `sent_by_id` / `transmission_method` | | Required together for `sent`/`closed` |
| `document_revision` | integer | Required; default `0` |
| `notes` | text | Optional |
| `closed_at` | timestamptz | Set when every line open qty is zero |
| `lock_version` | integer | Required aggregate token |
| timestamps | timestamptz | Required |

```text
unique (store_id, number) where number is not null
unique (store_id, supplier_id) where status = 'draft'  -- at most one automatic open draft
check status in (draft, sent, closed, cancelled)
```

---

## 8. `purchase_order_lines`

| Field | Type | Rules |
|---|---|---|
| `id` | uuid | PK; UUIDv7 |
| `purchase_order_id` | uuid | Required FK |
| `order_id` | uuid | Required FK; **unique** (one order → one line) |
| `product_variant_id` | uuid | Required; equals order variant |
| `ordered_quantity` | integer | Required positive; draft mirrors order; frozen at send |
| `supplier_item_number_snapshot` | string | Optional |
| `pricing_method_snapshot` | string | Optional |
| `supplier_list_price_cents_snapshot` | integer | Optional |
| `discount_basis_points_snapshot` | integer | Optional |
| `expected_unit_cost_cents_snapshot` | integer | Required nonnegative before send |
| `notes_snapshot` | text | Optional |
| timestamps | timestamptz | Required |

```text
unique (order_id)
index (purchase_order_id)
```

---

## 9. `purchase_order_line_states`

One mutable processing-state row per sent line.

| Field | Type | Rules |
|---|---|---|
| `purchase_order_line_id` | uuid | PK/FK |
| `confirmed_quantity` | integer | Optional nonnegative |
| `backordered_quantity` | integer | Required; default `0` |
| `expected_on` | date | Optional |
| `supplier_reference` | string | Optional |
| `notes` | text | Optional |
| `lock_version` | integer | Required |
| timestamps | timestamptz | Required |

---

## 10. `purchase_order_line_cancellations`

| Field | Type | Rules |
|---|---|---|
| `id` | uuid | PK; UUIDv7 |
| `purchase_order_line_id` | uuid | Required FK |
| `quantity` | integer | Required positive |
| `source` | string | `buyer` or `supplier` |
| `reason` | text | Required |
| `recorded_by_id` | uuid | Required FK → users |
| `occurred_at` | timestamptz | Required |
| timestamps | timestamptz | Required |

Append-only. Cumulative cancellations + matched receipts cannot exceed ordered quantity.

---

## 11. `purchase_receipts`

| Field | Type | Rules |
|---|---|---|
| `id` | uuid | PK; UUIDv7 |
| `store_id` | uuid | Required destination store |
| `supplier_id` | uuid | Required supplier |
| `number` | integer | **Nullable while draft**; assigned store-scoped sequential integer **at posting**; immutable after posting; never reused. Abandoned drafts do not consume numbers. |
| `status` | string | `draft`, `posted`, or `reversed` |
| `received_at` | timestamptz | Required; no future; backdate needs permission |
| `supplier_document_number` | string | Optional; duplicates warn |
| `supplier_document_date` | date | Optional |
| `freight_cents` | integer | Required; default `0` |
| `handling_cents` | integer | Required; default `0` |
| `supplier_tax_cents` | integer | Required; default `0` |
| `miscellaneous_charges_cents` | integer | Required; default `0` |
| `charge_notes` | text | Required when miscellaneous charges ≠ 0 |
| `notes` | text | Optional |
| `posted_at` / `posted_by_id` | | Required together when posted |
| `lock_version` | integer | Required while draft |
| timestamps | timestamptz | Required |

```text
unique (store_id, number) where number is not null
check status in (draft, posted, reversed)
check freight_cents >= 0 and handling_cents >= 0
check supplier_tax_cents >= 0 and miscellaneous_charges_cents >= 0
```

Ancillary charges never enter inventory valuation in Phase 7.

---

## 12. `purchase_receipt_lines`

| Field | Type | Rules |
|---|---|---|
| `id` | uuid | PK; UUIDv7 |
| `purchase_receipt_id` | uuid | Required FK |
| `purchase_order_line_id` | uuid | Required FK; PO supplier/store must match receipt |
| `product_variant_id` | uuid | Required; equals PO line/order variant |
| `received_quantity` | integer | Required positive |
| `matched_quantity` | integer | Frozen at post: min(received, locked open qty) |
| `unplanned_quantity` | integer | Frozen at post: received − matched |
| `actual_unit_cost_cents` | integer | Required nonnegative |
| `notes` | text | Optional |
| timestamps | timestamptz | Required |

Merchandise value = `received_quantity × actual_unit_cost_cents`. All received qty posts to inventory; only matched fulfills the order.

---

## 13. `purchase_receipt_line_corrections`

| Field | Type | Rules |
|---|---|---|
| `id` | uuid | PK; UUIDv7 |
| `purchase_receipt_line_id` | uuid | Required FK |
| `correction_type` | string | `quantity_reversal`, `cost_correction`, or `compensating_adjustment_reference` |
| `quantity` | integer | Positive for quantity reversal; null for cost-only |
| `value_delta_cents` | integer | Required signed for cost correction |
| `reason` | text | Required |
| `recorded_by_id` | uuid | Required FK → users |
| `recorded_at` | timestamptz | Required |
| `inventory_source_type` / `inventory_source_id` | | Required reference to resulting posting effect |
| timestamps | timestamptz | Required |

Append-only. Cumulative reversal qty cannot exceed posted line qty.

---

## 14. `customer_request_allocations`

| Field | Type | Rules |
|---|---|---|
| `id` | uuid | PK; UUIDv7 |
| `customer_request_id` | uuid | Required FK |
| `allocation_type` | string | `standard_quantity` or `used_unit` |
| `purchase_receipt_line_id` | uuid | Optional FK; set when special-order receipt created the allocation |
| `inventory_unit_id` | uuid | Required + unique for `used_unit`; null for `standard_quantity` |
| `quantity` | integer | Required; fixed at `1` in Phase 7 |
| `status` | string | `reserved`, `fulfilled`, or `released` |
| `fulfilled_pos_transaction_line_id` | uuid | Required when fulfilled |
| `released_at` / `released_by_id` / `release_reason` | | Required together when released |
| `lock_version` | integer | Required while reserved |
| timestamps | timestamptz | Required |

```text
unique (inventory_unit_id) where allocation_type = 'used_unit' and status = 'reserved'
-- at most one active allocation per request (application + partial unique)
check quantity = 1
check allocation_type in (standard_quantity, used_unit)
check status in (reserved, fulfilled, released)
```

Availability:

```text
available = on_hand - active_reserved - unavailable
```

Phase 7 implements `active_reserved` from active allocations. Used availability also excludes units with an active allocation. `unavailable` is 0 unless another workflow provides it.

---

## 15. `pos_transaction_lines` (pickup extension)

Slice 7.6 adds a nullable FK for allocation-linked Register pickup:

| Field | Type | Rules |
|---|---|---|
| `customer_request_allocation_id` | uuid | Optional FK → `customer_request_allocations`; set on pickup sale lines only |

Ordinary merchandise lines leave this null and hard-stop against `available`. Pickup lines may consume only the referenced allocation (see [phase7-spec.md](phase7-spec.md) §9.10).

---

## Numbering summary

| Document | Column | Assigned | Reuse |
|---|---|---|---|
| Customer request | `customer_requests.number` | At creation via `store_document_sequences` (`document_kind = customer_request`) | Never |
| Order | `orders.number` | At creation via `store_document_sequences` (`document_kind = order`) | Never |
| Purchase order | `purchase_orders.number` | At generate via `store_document_sequences` (`document_kind = purchase_order`) | Never (retained if returned to draft) |
| Purchase receipt | `purchase_receipts.number` | At posting via `store_document_sequences` (`document_kind = purchase_receipt`) | Never; abandoned drafts do not consume |

### `store_document_sequences`

Phase 7 numbering infrastructure (Slice 7.2+):

| Field | Type | Rules |
|---|---|---|
| `id` | uuid | PK; UUIDv7 |
| `store_id` | uuid | Required FK → `stores` |
| `document_kind` | string | `customer_request`, `order`, `purchase_order`, or `purchase_receipt` |
| `next_value` | integer | Required; positive; next number to allocate |
| timestamps | timestamptz | Required |

```text
unique (store_id, document_kind)
```
