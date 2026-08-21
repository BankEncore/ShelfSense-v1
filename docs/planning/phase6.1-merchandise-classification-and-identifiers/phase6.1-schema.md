# Phase 6.1 — Target schema

Status: **accepted**. This is the schema implemented for Phase 6.1 on `main`. It replaces the classification and product-identity portions of [phase-2-database-schema.md](../phase2-financial-classification-and-merchandise-foundation/phase-2-database-schema.md) for new work. Unlisted tables and columns stay as in `db/schema.rb` unless a later phase changes them.

Conventions match the rest of ShelfSense: UUIDv7 ids (`create_uuid_table` / `id: :uuid, default: nil`), `timestamptz`, `lock_version` on mutable roots, integer cents, integer basis points.

Because data is disposable, migrations may drop obsolete columns in the same change that adds replacements. Prefer explicit `remove_column` / `add_column` (or table rebuilds) over dual-purpose columns. Regenerate `db/schema.rb` from migrations.

---

## 1. `departments`

Top-level reporting category and GL posting owner. No tax or margin defaults. All merchandise classes in a department share these posting accounts; class-level GL columns are not in this schema.

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

Department-scoped merchandise policy and variant-default group, including the live default tax class. Does not own GL mappings.

| Field | Type | Rules |
|---|---|---|
| `id` | uuid | PK; UUIDv7 |
| `department_id` | uuid | Required FK to `departments` |
| `merchandise_class_number` | string | Required; unique within `department_id` |
| `name` | string | Required |
| `code` | string | Required; globally unique; normalized; effectively immutable |
| `description` | text | Optional |
| `default_tax_class_id` | uuid | Required FK to `tax_classes`; live default for variants without an override; must be assignable when assigned or reactivated |
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
| `industry_identifier` | string(13) | Optional; canonical GTIN-13; globally unique via `identifier_registry` (`product_industry`) |
| `lookup_code` | string(64) | Optional; **nonunique**; canonical uppercase |

### Constraints and indexes

```text
unique (primary_identifier)
check primary_identifier ~ '^[0-9]{13}$'
unique (industry_identifier) where industry_identifier is not null
check industry_identifier is null or industry_identifier ~ '^[0-9]{13}$'
index (lookup_code) where lookup_code is not null   -- nonunique
check lookup_code is null
  or (
    lookup_code = upper(btrim(lookup_code))
    and char_length(lookup_code) between 1 and 64
    and lookup_code ~ '^[A-Z0-9._/-]+$'
  )
```

A unique index on lookup code is **incorrect**. Shared codes are required for POS product selection.

`identifier_registry` owns uniqueness of all 13-digit identifier values, including active `product_primary` and `product_industry`. Lookup codes are **not** registry rows. Do not copy `products.industry_identifier` onto a variant.

---

## 5. `product_variants`

| Field | Type | Rules |
|---|---|---|
| existing identity | | `product_id`, `variant_type`, `sku`, `industry_identifier` (only if this variant has a distinct manufacturer GTIN), `name`, option values, `merchandise_condition_id`, `status`, `regular_price_cents`, `lock_version`, timestamps |
| `merchandise_class_id` | uuid | Required to activate |
| `inventory_mode` | string | Required to activate; copied at create; `inventory` or `non_inventory` |
| `pricing_method` | string | Required to activate; copied at create; same enum as class default |
| `target_margin_bps` | integer | Optional; copied at create; `0 <= value < 10000` |
| `supplier_returnable` | boolean | Required to activate; copied at create |
| `tax_class_override_id` | uuid | Optional FK to `tax_classes`; null means inherit class default |

### Remove

- `department_id`
- `tax_class_id` (replaced by `tax_class_override_id`; effective tax is not a stored column)

Reporting and sellability use `merchandise_class.department` and `effective_tax_class`.

### Constraints

```text
check inventory_mode in (inventory, non_inventory)
check pricing_method in (fixed, list_price, cost_based, open_price)
check target_margin_bps is null or (target_margin_bps >= 0 and target_margin_bps < 10000)
-- existing: condition matches variant_type; sku/industry shape; status enum
```

Draft rows may still omit class/mode until activation, matching today’s “required when active” pattern. `tax_class_override_id` remains nullable for inherited tax. If implementation prefers NOT NULL on the copied operational columns for all rows, DefaultResolver must populate them at create even for drafts.

Indexes: existing FKs plus `tax_class_override_id`; no `department_id` index.

---

## 6. `identifier_registry`

Kinds:

`product_primary`, `product_industry`, `variant_sku`, `variant_industry`, `inventory_unit`

Extend `identifier_kind` check, owner-matches-kind check, and unique active owner indexes:

- active `product_primary`: unique `product_id` where kind is `product_primary` and not retired (unchanged intent)
- active `product_industry`: unique `product_id` where kind is `product_industry` and not retired (at most one active product industry identifier per product)
- existing variant SKU, variant industry, and inventory-unit owner indexes unchanged

`value` remains unique across the table (active and retired) and 13-digit GTIN shape. `product_primary` values are only generated `222` identifiers after cutover. Lookup codes never appear here.

Matching uses `find_any` (any row for that value). Retired rows still occupy `value` uniqueness and must return `retired` on lookup; they must not fall through to `products.lookup_code`.

---

## 7. Other tables

No change required to `gl_accounts`, `tax_classes`, `merchandise_conditions`, inventory tables, or POS tables for this phase. POS line tax and pricing snapshots already stored on `pos_transaction_lines` remain the historical authority for completed sales.

Future operational reports that need department should join `product_variants` → `merchandise_classes` → `departments` for **current** classification, and must not rewrite completed facts when a class parent is later changed (parent change is blocked after history).

---

## 8. Seed and fixture expectations

Every seeded merchandise class has a department and class number. Every seeded product primary is a `222` identifier. Book ISBNs/UPCs live on `products.industry_identifier` (`product_industry`). Variant industry identifiers only when the fixture represents a distinct manufacturer GTIN. Lookup codes, if seeded, are canonical uppercase and may be shared. Include at least one shared lookup-code fixture and one retired-registry-vs-lookup-code fixture. No factory should set `product_variants.department_id`, `product_variants.tax_class_id`, or `identifier_mode`.
