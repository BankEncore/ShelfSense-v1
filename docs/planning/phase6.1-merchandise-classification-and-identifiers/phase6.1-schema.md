# Phase 6.1 — Target schema

Status: **proposed**. This is the schema to implement. It replaces the classification and product-identity portions of [phase-2-database-schema.md](../phase2-financial-classification-and-merchandise-foundation/phase-2-database-schema.md) for new work. Unlisted tables and columns stay as in `db/schema.rb` at the start of the phase.

Conventions match the rest of ShelfSense: UUIDv7 ids (`create_uuid_table` / `id: :uuid, default: nil`), `timestamptz`, `lock_version` on mutable roots, integer cents, integer basis points.

Because data is disposable, migrations may drop obsolete columns in the same change that adds replacements. Prefer explicit `remove_column` / `add_column` (or table rebuilds) over dual-purpose columns. Regenerate `db/schema.rb` from migrations.

---

## 1. `departments`

Top-level reporting category and GL mapping owner. No tax or margin defaults.

| Field | Type | Rules |
|---|---|---|
| `id` | uuid | PK; UUIDv7 |
| `department_number` | string | Required; globally unique |
| `name` | string | Required |
| `code` | string | Required; globally unique; normalized machine key; effectively immutable |
| `description` | text | Optional |
| `inventory_asset_gl_account_id` | uuid | Optional FK; existing type/category/posting validation |
| `cost_of_goods_sold_gl_account_id` | uuid | Optional FK |
| `sales_revenue_gl_account_id` | uuid | Optional FK |
| `sales_returns_gl_account_id` | uuid | Optional FK |
| `receiving_clearing_gl_account_id` | uuid | Optional FK |
| `freight_in_gl_account_id` | uuid | Optional FK |
| `inventory_shrinkage_gl_account_id` | uuid | Optional FK |
| `inventory_adjustment_gain_gl_account_id` | uuid | Optional FK |
| `inventory_adjustment_loss_gl_account_id` | uuid | Optional FK |
| `inventory_write_down_gl_account_id` | uuid | Optional FK |
| `active` | boolean | Required; default `true` |
| `display_order` | integer | Required; default `0` |
| `lock_version` | integer | Required; default `0` |
| timestamps | timestamptz | Required |

### Remove

- `default_tax_class_id`
- `default_target_margin_bps`

### Constraints and indexes

Retain existing GL FK indexes, `code` uniqueness and format check, and GL validation in the `Department` model.

```text
unique (department_number)   -- no longer partial/nullable
unique (code)
```

Deactivation rule (application): blocked while any merchandise class with `active = true` has this `department_id`.

---

## 2. `merchandise_classes`

Department-scoped subdepartment. Owns creation-time defaults and merchandise policies. Does not own GL mappings.

| Field | Type | Rules |
|---|---|---|
| `id` | uuid | PK; UUIDv7 |
| `department_id` | uuid | Required FK to `departments` |
| `merchandise_class_number` | string | Required; unique within `department_id` |
| `name` | string | Required |
| `code` | string | Required; globally unique; normalized; effectively immutable |
| `description` | text | Optional |
| `default_tax_class_id` | uuid | Required FK to `tax_classes`; must be assignable when assigned or reactivated |
| `default_inventory_mode` | string | Required; `inventory` or `non_inventory` |
| `default_pricing_method` | string | Required; `fixed`, `list_price`, `cost_based`, or `open_price` |
| `target_margin_bps` | integer | Optional; `0 <= value < 10000` |
| `used_merchandise_allowed` | boolean | Required; default `false` |
| `buyback_allowed` | boolean | Required; default `false` |
| `default_supplier_returnable` | boolean | Required; default `true` |
| `active` | boolean | Required; default `true` |
| `display_order` | integer | Required; default `0` |
| `lock_version` | integer | Required; default `0` |
| timestamps | timestamptz | Required |

Column rename vs today: `inventory_mode` → `default_inventory_mode`, `pricing_method` → `default_pricing_method` so application code cannot confuse class defaults with variant values.

### Remove

- `default_standard_department_id`
- `default_used_department_id`

### Constraints and indexes

```text
unique (code)
unique (department_id, merchandise_class_number)
index (department_id)
index (default_tax_class_id)
check default_inventory_mode in (inventory, non_inventory)
check default_pricing_method in (fixed, list_price, cost_based, open_price)
check not buyback_allowed or (used_merchandise_allowed and default_inventory_mode = 'inventory')
check target_margin_bps is null or (target_margin_bps >= 0 and target_margin_bps < 10000)
check code format (existing snake_case machine-code pattern)
```

Do not put a class-level “inventory mode immutable after any child history” constraint. That rule belongs on the **variant** persisted `inventory_mode`.

Ordinary `department_id` changes: reject in application (and optionally a service) when any associated variant has inventory history or POS line history.

---

## 3. `merchandise_categories`

| Field | Type | Rules |
|---|---|---|
| `id` | uuid | PK; UUIDv7 |
| `name` | string | Required; existing sibling/root uniqueness |
| `code` | string | Optional; existing generation/uniqueness |
| `parent_id` | uuid | Optional self-FK; cycles prohibited |
| `default_standard_merchandise_class_id` | uuid | Optional FK to active class |
| `default_used_merchandise_class_id` | uuid | Optional FK to active class with `used_merchandise_allowed` |
| `active` | boolean | Required; default `true` |
| `display_order` | integer | Required; default `0` |
| `lock_version` | integer | Required; default `0` |
| timestamps | timestamptz | Required |

### Remove

- `default_merchandise_class_id`

Do not add `abbreviation`.

Application: used default must allow used merchandise; both defaults must be assignable when present.

---

## 4. `products`

| Field | Type | Rules |
|---|---|---|
| existing descriptive fields | | Unchanged (`name`, `subtitle`, `description`, `brand_name`, `product_model`, `merchandise_category_id`, `list_price_cents`, `release_date`, `status`, option names, `lock_version`, timestamps) |
| `primary_identifier` | string(13) | Required; immutable; unique; always generated `222` EAN-13 |
| `lookup_code` | string(64) | Optional; **nonunique**; canonical uppercase |

### Constraints and indexes

```text
unique (primary_identifier)
check primary_identifier ~ '^[0-9]{13}$'
index (lookup_code) where lookup_code is not null   -- nonunique
check lookup_code is null
  or (
    lookup_code = upper(btrim(lookup_code))
    and char_length(lookup_code) between 1 and 64
    and lookup_code ~ '^[A-Z0-9._/-]+$'
  )
```

A unique index on lookup code is **incorrect**. Shared codes are required for POS product selection.

`identifier_registry` continues to own uniqueness of active `product_primary` values. Lookup codes are **not** registry rows.

---

## 5. `product_variants`

| Field | Type | Rules |
|---|---|---|
| existing identity | | `product_id`, `variant_type`, `sku`, `industry_identifier`, `name`, option values, `merchandise_condition_id`, `status`, `regular_price_cents`, `lock_version`, timestamps |
| `merchandise_class_id` | uuid | Required to activate |
| `inventory_mode` | string | Required to activate; copied at create; `inventory` or `non_inventory` |
| `pricing_method` | string | Required to activate; copied at create; same enum as class default |
| `target_margin_bps` | integer | Optional; copied at create; `0 <= value < 10000` |
| `supplier_returnable` | boolean | Required to activate; copied at create |
| `tax_class_id` | uuid | Required to activate; copied from class default or explicit input |

### Remove

- `department_id`

Reporting and sellability use `merchandise_class.department`.

### Constraints

```text
check inventory_mode in (inventory, non_inventory)
check pricing_method in (fixed, list_price, cost_based, open_price)
check target_margin_bps is null or (target_margin_bps >= 0 and target_margin_bps < 10000)
-- existing: condition matches variant_type; sku/industry shape; status enum
```

Draft rows may still omit class/tax/mode until activation, matching today’s “required when active” pattern. If implementation prefers NOT NULL on the new operational columns for all rows, DefaultResolver must populate them at create even for drafts.

Indexes: existing FKs; no `department_id` index.

---

## 6. `identifier_registry`

No new `identifier_kind`. Kinds remain:

`product_primary`, `variant_sku`, `variant_industry`, `inventory_unit`

Ownership check and unique active `value` unchanged. `product_primary` values are only generated `222` identifiers after cutover.

`value` remains 13-digit GTIN shape. Lookup codes never appear here.

---

## 7. Other tables

No change required to `gl_accounts`, `tax_classes`, `merchandise_conditions`, inventory tables, or POS tables for this phase. POS line tax and pricing snapshots already stored on `pos_transaction_lines` remain the historical authority for completed sales.

Future operational reports that need department should join `product_variants` → `merchandise_classes` → `departments` for **current** classification, and must not rewrite completed facts when a class parent is later changed (parent change is blocked after history).

---

## 8. Seed and fixture expectations

Every seeded merchandise class has a department and class number. Every seeded product primary is a `222` identifier. ISBNs/UPCs live on variant `industry_identifier`. Lookup codes, if seeded, are canonical uppercase and may be shared. Include at least one shared lookup-code fixture for POS/inventory targeting tests. No factory should set `product_variants.department_id` or `identifier_mode`.
