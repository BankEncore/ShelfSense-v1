# Phase 2 Database Schema

Phase 2 establishes the financial classifications and merchandise records required to create, classify, price, and retrieve sellable product variants. It defines the accounting relationships required by ShelfSense's future perpetual-inventory system, but does not post journal entries, calculate tax, or maintain inventory.

## Phase-wide conventions

- Products contain shared catalog identity and descriptive information.
- Product variants are the sellable records used by later inventory, purchasing, customer-request, and POS workflows.
- Every variant receives an immutable, system-generated `221` EAN-13-compatible SKU.
- Every product has exactly one mandatory `primary_identifier` (entered external GTIN/ISBN or system-generated `222` EAN-13) established at creation.
- Defaults assist record creation; approved classifications and prices are stored on each variant and are not dynamically inherited afterward.
- Department GL mappings are explicit nullable foreign-key columns on `departments`.
- ShelfSense uses perpetual inventory accounting: inventory assets and cost of goods sold are separate mappings.
- All primary and foreign keys use `uuid`; application-created identifiers are UUIDv7.
- Timestamps use `timestamptz`.
- Mutable business and configuration records use Rails optimistic locking through `lock_version`.
- Money is stored as integer cents using `bigint`.
- Percentages and multipliers are stored as integer basis points.
- Stable machine-readable codes are normalized to lowercase `snake_case`.
- Reference data is deactivated, and products and variants are discontinued, rather than routinely deleted.
- Database constraints provide final integrity protection; application validations provide useful error messages.

Phase 2 contains nine tables:

1. `gl_accounts`
2. `tax_classes`
3. `departments`
4. `merchandise_classes`
5. `merchandise_categories`
6. `merchandise_conditions`
7. `products`
8. `product_variants`
9. `identifier_registry`

---

## 1. `gl_accounts`

The chart of accounts available for department mappings and future financial posting. Phase 2 administers accounts and their hierarchy; journal entries are deferred.

| **Field** | **Type** | **Constraints** | **Notes** |
|---|---|---|---|
| id | uuid | PK; UUIDv7 | |
| account_number | varchar | null: false; unique | Organization-defined account code |
| name | varchar | null: false | Display name |
| description | text | | |
| account_type | varchar | null: false; check enum | `asset`, `liability`, `equity`, `revenue`, `expense` |
| account_category | varchar | null: false; check supported value | More specific classification used for mapping validation |
| parent_id | uuid | FK: `gl_accounts`; nullable; check `parent_id <> id` | Optional account hierarchy |
| posting_allowed | boolean | null: false; default `true` | False for headings or non-posting control accounts |
| active | boolean | null: false; default `true` | Inactive accounts remain available to historical records |
| display_order | integer | null: false; default `0` | Administrative display order |
| lock_version | integer | null: false; default `0` | Optimistic concurrency |
| created_at | timestamptz | null: false | |
| updated_at | timestamptz | null: false | |

Initial `account_category` values should include:

- `cash`
- `accounts_receivable`
- `inventory`
- `other_current_asset`
- `fixed_asset`
- `accounts_payable`
- `other_current_liability`
- `long_term_liability`
- `equity`
- `sales`
- `sales_returns`
- `cost_of_goods_sold`
- `freight_in`
- `inventory_shrinkage`
- `inventory_adjustment`
- `inventory_write_down`
- `other_revenue`
- `other_expense`

### Rules

- Trim surrounding whitespace from `account_number` before validation.
- Prevent hierarchy cycles in application logic.
- A parent should normally have the same `account_type` as its children.
- Only active, posting-allowed accounts may be newly assigned to department mappings.
- The assigned account type and category must be compatible with the department field's accounting purpose.
- Accounts referenced by departments or future financial records must not be deleted.

Recommended indexes:

```text
unique (account_number)
index (parent_id)
index (active, account_number)
```

---

## 2. `tax_classes`

Classifies the type of merchandise tax treatment without defining a store-specific rate or calculating tax.

Examples include `physical_book`, `physical_general_merchandise`, `newspaper`, `periodical`, `bakery`, `packaged_food`, and `non_taxable_service`.

| **Field** | **Type** | **Constraints** | **Notes** |
|---|---|---|---|
| id | uuid | PK; UUIDv7 | |
| code | varchar | null: false; unique | Stable machine-readable code |
| name | varchar | null: false | Administrative display name |
| description | text | | Intended merchandise classification |
| active | boolean | null: false; default `true` | |
| display_order | integer | null: false; default `0` | |
| lock_version | integer | null: false; default `0` | Optimistic concurrency |
| created_at | timestamptz | null: false | |
| updated_at | timestamptz | null: false | |

A tax class does not by itself mean that merchandise is taxable. Later store-specific tax rules will associate tax classes with tax components, rates, exemptions, and effective dates.

---

## 3. `departments`

Departments provide stable financial, tax, operational, and reporting classification for merchandise. They also contain the explicit GL mappings used by future posting workflows.

| **Field** | **Type** | **Constraints** | **Notes** |
|---|---|---|---|
| id | uuid | PK; UUIDv7 | |
| code | varchar | null: false; unique | Stable machine-readable code |
| department_number | varchar | unique when present; nullable | Optional user-facing or accounting number |
| name | varchar | null: false | |
| description | text | | |
| default_tax_class_id | uuid | FK: `tax_classes`; null: false | Creation-time default for variants |
| default_target_margin_bps | integer | nullable; check `0 <= value < 10000` | Gross-margin target used for future price suggestions |
| inventory_asset_gl_account_id | uuid | FK: `gl_accounts`; nullable | Inventory asset account |
| cost_of_goods_sold_gl_account_id | uuid | FK: `gl_accounts`; nullable | COGS expense account |
| sales_revenue_gl_account_id | uuid | FK: `gl_accounts`; nullable | Merchandise revenue account |
| sales_returns_gl_account_id | uuid | FK: `gl_accounts`; nullable | Sales-returns contra-revenue account |
| receiving_clearing_gl_account_id | uuid | FK: `gl_accounts`; nullable | Clearing account when receipt and invoice recognition differ |
| freight_in_gl_account_id | uuid | FK: `gl_accounts`; nullable | Inbound freight account when separately mapped |
| inventory_shrinkage_gl_account_id | uuid | FK: `gl_accounts`; nullable | Shrinkage expense account |
| inventory_adjustment_gain_gl_account_id | uuid | FK: `gl_accounts`; nullable | Positive inventory-adjustment offset |
| inventory_adjustment_loss_gl_account_id | uuid | FK: `gl_accounts`; nullable | Negative inventory-adjustment expense |
| inventory_write_down_gl_account_id | uuid | FK: `gl_accounts`; nullable | Inventory write-down expense |
| active | boolean | null: false; default `true` | |
| display_order | integer | null: false; default `0` | |
| lock_version | integer | null: false; default `0` | Optimistic concurrency |
| created_at | timestamptz | null: false | |
| updated_at | timestamptz | null: false | |

### Accounting compatibility

| Department field | Expected account |
|---|---|
| `inventory_asset_gl_account_id` | `asset` / `inventory` |
| `cost_of_goods_sold_gl_account_id` | `expense` / `cost_of_goods_sold` |
| `sales_revenue_gl_account_id` | `revenue` / `sales` |
| `sales_returns_gl_account_id` | `revenue` / `sales_returns` |
| `receiving_clearing_gl_account_id` | Clearing account selected by accounting policy |
| `freight_in_gl_account_id` | Asset, COGS, or freight-in account selected by accounting policy |
| `inventory_shrinkage_gl_account_id` | `expense` / `inventory_shrinkage` |
| `inventory_adjustment_gain_gl_account_id` | Revenue or contra-expense adjustment account |
| `inventory_adjustment_loss_gl_account_id` | `expense` / `inventory_adjustment` |
| `inventory_write_down_gl_account_id` | `expense` / `inventory_write_down` |

Mappings remain nullable in Phase 2. A later workflow must validate the exact mappings required for the event it is about to post. A department therefore does not need every mapping merely to classify a variant.

`default_target_margin_bps` represents gross margin, not markup. For example, `4000` means 40%. With a $6.00 cost, the suggested price is:

\[
\frac{600}{1 - 0.40} = 1000\text{ cents}
\]

This is only a suggestion; the approved regular price is stored on the variant.

Recommended indexes include `default_tax_class_id` and each GL-account foreign key used for reverse lookup.

---

## 4. `merchandise_classes`

Defines operational behavior shared by similar types of merchandise.

Examples include `book`, `recorded_music`, `video`, `greeting_card`, `apparel`, `prepared_food`, `gift_card`, and `service`.

| **Field** | **Type** | **Constraints** | **Notes** |
|---|---|---|---|
| id | uuid | PK; UUIDv7 | |
| code | varchar | null: false; unique | Stable machine-readable code |
| name | varchar | null: false | |
| description | text | | |
| inventory_mode | varchar | null: false; check enum | `inventory` or `non_inventory` |
| pricing_method | varchar | null: false; check enum | `fixed`, `list_price`, `cost_based`, `open_price` |
| default_standard_department_id | uuid | FK: `departments`; nullable | Default for standard variants |
| default_used_department_id | uuid | FK: `departments`; nullable | Default for used variants |
| used_merchandise_allowed | boolean | null: false; default `false` | Whether used variants may use this class |
| buyback_allowed | boolean | null: false; default `false` | Future behavior; buyback is deferred |
| default_returnable | boolean | null: false; default `true` | Default used by later purchasing and return workflows |
| active | boolean | null: false; default `true` | |
| display_order | integer | null: false; default `0` | |
| lock_version | integer | null: false; default `0` | Optimistic concurrency |
| created_at | timestamptz | null: false | |
| updated_at | timestamptz | null: false | |

### Inventory mode and derived tracking

Quantity versus individual tracking is not chosen independently on the merchandise class. It is derived from `inventory_mode` and the variant’s `variant_type`:

| Class `inventory_mode` | Variant type | Derived tracking |
|---|---|---|
| `inventory` | `standard` | Quantity-tracked |
| `inventory` | `used` | Individually unit-tracked |
| `non_inventory` | `standard` | Not inventory-tracked (for example services) |
| `non_inventory` | `used` | Invalid |

| Value | Meaning |
|---|---|
| `inventory` | Participates in merchandise inventory |
| `non_inventory` | Sellable without creating or relieving merchandise inventory |

### Pricing methods

| Value | Meaning |
|---|---|
| `fixed` | An approved regular price is entered directly |
| `list_price` | Product list price is the usual starting point |
| `cost_based` | A future price suggestion uses cost and target margin |
| `open_price` | Price is supplied during a later transaction, subject to policy |

Phase 2 captures these behaviors but does not create inventory balances, inventory units, buybacks, or cost calculations.

---

## 5. `merchandise_categories`

Provides the hierarchical descriptive classification used for browsing, organization, shelving, and reporting. Categories may suggest a merchandise class but do not directly determine accounting treatment.

| **Field** | **Type** | **Constraints** | **Notes** |
|---|---|---|---|
| id | uuid | PK; UUIDv7 | |
| code | varchar | unique when present; nullable | Optional stable machine-readable code |
| name | varchar | null: false | |
| description | text | | |
| parent_id | uuid | FK: `merchandise_categories`; nullable; check `parent_id <> id` | Parent category |
| default_merchandise_class_id | uuid | FK: `merchandise_classes`; nullable | Creation-time suggestion |
| active | boolean | null: false; default `true` | |
| display_order | integer | null: false; default `0` | Ordering among siblings |
| lock_version | integer | null: false; default `0` | Optimistic concurrency |
| created_at | timestamptz | null: false | |
| updated_at | timestamptz | null: false | |

Recommended case-insensitive uniqueness:

```text
unique (parent_id, lower(name)) where parent_id is not null
unique (lower(name)) where parent_id is null
```

Application logic must prevent hierarchy cycles. Changing a category's default class does not reclassify existing variants, and deactivating a category does not automatically discontinue its products.

---

## 6. `merchandise_conditions`

Describes the condition and pricing tier of a **used variant** (for example `like_new`, `good`, `acceptable`). Conditions belong only to used variants; standard variants must not reference a condition. A future `inventory_unit` represents each physical used copy assigned to that variant.

| **Field** | **Type** | **Constraints** | **Notes** |
|---|---|---|---|
| id | uuid | PK; UUIDv7 | |
| code | varchar | null: false; unique | Examples: `like_new`, `good`, `acceptable`, `collectible` |
| name | varchar | null: false | |
| description | text | | |
| price_adjustment_bps | integer | null: false; default `10000`; check `>= 0` | Price multiplier for used-variant suggestions; `10000` means 100% |
| active | boolean | null: false; default `true` | |
| display_order | integer | null: false; default `0` | |
| lock_version | integer | null: false; default `0` | Optimistic concurrency |
| created_at | timestamptz | null: false | |
| updated_at | timestamptz | null: false | |

The condition adjustment produces only a suggested price for used variants:

\[
\text{suggested price} = \text{base price} \times \frac{\text{price adjustment bps}}{10000}
\]

The approved result is stored as `product_variants.regular_price_cents`. Department defaults are selected from the variant’s `variant_type`, not from the condition.

---

## 7. `products`

Stores shared catalog identity and descriptive information. A product may exist without a variant, but every product—including draft—must have a primary identifier.

| **Field** | **Type** | **Constraints** | **Notes** |
|---|---|---|---|
| id | uuid | PK; UUIDv7 | |
| primary_identifier | char(13) | null: false; unique | Canonical manufacturer-assigned GTIN/ISBN or system-generated 222 EAN-13 |
| name | varchar | null: false | Title or product name |
| subtitle | varchar | | Optional subtitle or secondary name |
| description | text | | |
| brand_name | varchar | | Publisher, brand, manufacturer, or equivalent free-text name |
| product_model | varchar | | Optional model, edition, series, or format designation (column is `product_model` to avoid Active Record's `model_name`) |
| merchandise_category_id | uuid | FK: `merchandise_categories`; nullable | Descriptive classification |
| list_price_cents | bigint | nullable; check `>= 0` | Publisher or manufacturer list price |
| release_date | date | | Publication, release, or on-sale date |
| status | varchar | null: false; default `draft`; check enum | `draft`, `active`, `discontinued` |
| variant_option_name_1 | varchar | | Example: `size`, `format`, `color` |
| variant_option_name_2 | varchar | | Optional second distinguishing dimension |
| lock_version | integer | null: false; default `0` | Optimistic concurrency |
| created_at | timestamptz | null: false | |
| updated_at | timestamptz | null: false | |

### Primary identifier rules

- Product creation requires a mutually exclusive choice: enter an external identifier, or generate a ShelfSense `222` identifier. Generation is part of creation, not a later optional action.
- Remove permitted spaces and hyphens before validation.
- Convert a valid ISBN-10 to its equivalent ISBN-13.
- Store ISBNs only in their canonical 13-digit form.
- Normalize UPC-A to GTIN-13 by adding a leading zero.
- Validate the GTIN/EAN check digit.
- Reject a user-entered value in the reserved `222` namespace.
- A generated identifier must have exactly 13 digits, begin with `222`, have a valid check digit, remain globally unique, and never be reused.
- Do not store identifier type or provenance; audit events may record entered versus generated.
- Reserve the value in `identifier_registry` in the same transaction as product persistence.

The database enforces the 13-digit shape and uniqueness. The shared identifier service performs formatting removal, ISBN conversion, check-digit validation, and registry reservation.

Recommended indexes:

```text
unique (primary_identifier)
index (merchandise_category_id)
index (status, name)
```

---

## 8. `product_variants`

Represents the actual sellable SKU used by later inventory, purchasing, customer-request, and POS workflows. A product is condition-neutral and may own both **standard variants** and **used variants**.

| **Field** | **Type** | **Constraints** | **Notes** |
|---|---|---|---|
| id | uuid | PK; UUIDv7 | |
| product_id | uuid | FK: `products`; null: false | |
| variant_type | varchar | null: false; check enum | `standard` or `used` |
| sku | char(13) | null: false; unique; immutable | System-generated `221` EAN-13-compatible SKU |
| industry_identifier | char(13) | unique when present; nullable | Trade identifier belonging specifically to this variant |
| name | varchar | | Optional distinguishing display name |
| option_value_1 | varchar | | Corresponds to `products.variant_option_name_1` |
| option_value_2 | varchar | | Corresponds to `products.variant_option_name_2` |
| merchandise_condition_id | uuid | FK: `merchandise_conditions`; nullable | Required for used variants; must be null for standard variants |
| merchandise_class_id | uuid | FK: `merchandise_classes`; nullable in draft; required when active | Approved operational behavior |
| department_id | uuid | FK: `departments`; nullable in draft; required when active | Stored financial and reporting classification |
| tax_class_id | uuid | FK: `tax_classes`; nullable in draft; required when active | Stored tax classification |
| regular_price_cents | bigint | nullable; check `>= 0` | Activation requirements depend on merchandise class pricing method |
| status | varchar | null: false; default `draft`; check enum | `draft`, `active`, `discontinued` |
| lock_version | integer | null: false; default `0` | Optimistic concurrency |
| created_at | timestamptz | null: false | |
| updated_at | timestamptz | null: false | |

Database invariant:

```sql
CHECK (
  (variant_type = 'standard' AND merchandise_condition_id IS NULL)
  OR
  (variant_type = 'used' AND merchandise_condition_id IS NOT NULL)
)
```

### SKU rules

- Generate the SKU automatically when the variant is created.
- Store exactly 13 digits beginning with `221` and ending in a valid EAN-13 check digit.
- Enforce installation-wide uniqueness.
- Do not expose an ordinary form field for choosing or editing the SKU.
- Do not change or reuse a SKU after assignment, including after discontinuation or deletion of an otherwise deletable draft.

### Variant industry identifier rules

- The identifier is optional and must belong specifically to the variant.
- Normalize and validate it through the shared identifier service.
- It must differ from the variant's SKU.
- It must not be copied from `products.primary_identifier` merely to support scanning.
- It must not collide with any product primary identifier or any other variant identifier.

### Default resolution

When creating or explicitly reclassifying a variant, resolve values in this order:

| Assignment | Resolution order |
|---|---|
| Merchandise class | Explicit selection; product category's default class; unresolved |
| Department | Explicit selection; class used department when `variant_type` is `used`; class standard department when `variant_type` is `standard`; unresolved |
| Tax class | Explicit selection; resolved department's default tax class; unresolved |
| Price | Explicit price; for used variants, list price × condition adjustment; for standard variants, list price as-is; later cost-based suggestion |

The user approves the resolved values before activation. ShelfSense stores those values on the variant. Changing a category, class, condition, or department default later does not silently modify existing variants.

### Sellability

Sellability should be a model or domain-service predicate, not a duplicated stored boolean. A variant is ordinarily sellable only when:

- its status is `active`;
- its product is active;
- its SKU is valid;
- its merchandise class, department, and tax class are active;
- for used variants, its merchandise condition is active and the class allows used merchandise (`used_merchandise_allowed`);
- for used variants, the merchandise class `inventory_mode` is `inventory` (non-inventory used variants are invalid);
- for standard variants, `merchandise_condition_id` is null;
- its regular price satisfies the merchandise class's pricing method;
- required option values and any class-specific attributes are present.

A draft may be incomplete. Activation must fail with clear errors if the sellability contract is not satisfied.

Recommended indexes:

```text
unique (sku)
unique (industry_identifier) where industry_identifier is not null
index (product_id, status)
index (product_id, variant_type)
index (merchandise_class_id)
index (merchandise_condition_id)
index (department_id)
index (tax_class_id)
```

Do not impose a general uniqueness constraint on `(product_id, option values, condition)` until the option model is proven sufficient for every merchandise class. Individually distinguishable physical copies belong in future `inventory_units` under a used variant, not as duplicate variant records.

---

## 9. `identifier_registry`

Reserves operational identifiers across product and variant namespaces so that a scanned or typed value can never resolve ambiguously. This is an internal integrity table, not a user-administered resource.

| **Field** | **Type** | **Constraints** | **Notes** |
|---|---|---|---|
| id | uuid | PK; UUIDv7 | |
| value | char(13) | null: false; unique | Normalized lookup value |
| identifier_kind | varchar | null: false; check enum | `product_primary`, `variant_sku`, `variant_industry` |
| product_id | uuid | FK: `products` ON DELETE SET NULL; nullable | Owner for `product_primary` when present |
| product_variant_id | uuid | FK: `product_variants` ON DELETE SET NULL; nullable | Owner for either variant kind when present |
| retired_at | timestamptz | nullable | Set when an identifier is removed from ordinary lookup but must remain reserved |
| created_at | timestamptz | null: false | |
| updated_at | timestamptz | null: false | |

Registry ownership invariants:

- An **active** registry row (`retired_at` null) has exactly one owner, and that owner must match `identifier_kind`:
  - `product_primary` → `product_id` only
  - `variant_sku` / `variant_industry` → `product_variant_id` only
- A **retired** registry row may have zero or one owner.
- An unowned registry row must have `retired_at` populated.
- `value` remains globally unique for both active and retired rows.

Before deleting an eligible draft product or variant, retire its registry rows in the same transaction.

Required checks and indexes:

```text
check exactly one of product_id or product_variant_id is present
check product_primary requires product_id
check variant_sku and variant_industry require product_variant_id

unique (value)
unique (product_id) where identifier_kind = 'product_primary' and retired_at is null
unique (product_variant_id) where identifier_kind = 'variant_sku'
unique (product_variant_id) where identifier_kind = 'variant_industry' and retired_at is null
```

The registry protects the namespace, while the identifier columns on `products` and `product_variants` remain the business-facing values. Assignment, replacement, retirement, and owner updates must occur in one transaction so the registry and owner cannot diverge.

- A current product or variant industry identifier has an active registry row.
- Replacing or removing one retires the old row rather than deleting it, preventing reuse.
- A generated `221` SKU registry row is never retired during the retained life of its variant and its value is never reused.
- Foreign-key delete behavior must preserve reservations for identifiers that cannot be reused. If draft deletion is supported, use a retained tombstone owner or make the owner foreign key nullable on retirement rather than cascading deletion.

## Unified identifier lookup

The lookup service normalizes input once and consults the registry.

| Match | Result |
|---|---|
| `variant_sku` | Resolve directly to the variant |
| `variant_industry` | Resolve directly to the variant |
| `product_primary` | Resolve to the product; proceed directly only when exactly one eligible variant exists |

If a product has multiple eligible variants, the user selects one. ISBN-10 input is converted before lookup. Invalid, retired, missing, or otherwise ambiguous input produces an explicit result and never an arbitrary selection.

## Identifier generation

The shared generator should:

1. allocate the next nine-digit payload from a non-cycling PostgreSQL sequence (`MINVALUE 0`, `MAXVALUE 999999999`, `NO CYCLE`) for prefix `221` or `222`;
2. zero-pad the payload to nine digits and calculate the EAN-13 check digit;
3. attempt to reserve the complete value in `identifier_registry`;
4. retry only on a unique conflict (not on sequence exhaustion);
5. assign the identifier to the owner in the same transaction.

Sequence exhaustion must raise a clear operational error and must not wrap.

---

# Cross-table lifecycle rules

- GL accounts, tax classes, departments, merchandise classes, categories, and conditions are deactivated.
- Products and variants use `draft`, `active`, and `discontinued` statuses.
- New assignments may use only active reference records and active posting accounts.
- Deactivation does not automatically mutate or discontinue dependent records.
- Activation of a product or variant validates the complete current contract.
- Draft products or variants may be physically deleted only if unreferenced and policy permits it.
- Generated or previously assigned operational identifiers remain reserved after deletion or replacement.
- Referenced records must not be physically deleted.
- Completed future journal lines will store the actual `gl_account_id` used; later department mapping changes will not reinterpret historical postings.

# Audited Phase 2 changes

Material audit events should include:

- GL account activation, deactivation, or hierarchy changes;
- department default-tax or GL-mapping changes;
- merchandise-class behavior and department-default changes;
- category default-class changes;
- product primary-identifier assignment, replacement, or removal;
- generation of a `222` product identifier;
- generation of a variant SKU;
- variant industry-identifier assignment, replacement, or removal;
- variant price changes;
- variant merchandise-class, condition, department, or tax-class changes;
- product or variant activation or discontinuation;
- explicit bulk application of changed defaults.

Ordinary descriptive edits may rely on the general record-change audit mechanism rather than requiring a separate named business event.

# Minimal Phase 2 import contract

CSV import should use the same normalization, resolution, validation, registry, authorization, and auditing services as manual entry.

It should:

- accept products and variants;
- normalize identifiers before matching;
- group rows by normalized product primary identifier and persist each group atomically;
- match products by normalized primary identifier;
- match variants by SKU or variant industry identifier where appropriate;
- apply ordinary creation defaults without overwriting explicit imported assignments;
- treat blank codes as defaults, but reject explicitly supplied unknown reference codes;
- remain idempotent when the same file is imported again for rows that include a durable product identifier;
- treat `generate_primary_identifier=true` with a blank primary identifier as create-only (not idempotent across reimports);
- reuse ordinary audited create/update services for product and variant writes;
- report row-level (or group-level) errors;
- avoid partially importing an invalid product-and-variant group.

No separate staging table is required for the minimal Phase 2 importer. If later import volume, resumability, or review requirements justify persisted import jobs, those tables can be added without changing the merchandise contract.

# Testing priorities

Phase 2 should specifically test:

- UUIDv7 assignment for all Phase 2 records;
- concurrent `221` and `222` generation without collisions;
- correct EAN-13 check digits and prefixes;
- ISBN-10 conversion and canonical identifier normalization;
- multiple `NULL` values under partial unique indexes;
- prevention of cross-namespace identifier ambiguity;
- preservation of retired identifier reservations;
- merchandise-class resolution from category defaults;
- standard-versus-used department resolution;
- tax-class resolution from the selected department;
- explicit overrides at each resolution level;
- changes to defaults not altering stored variant assignments;
- GL account compatibility for every department mapping field;
- sellability and activation validation;
- inactive reference records not being assigned to new variants;
- import idempotency and atomic product/variant groups;
- authorization and material audit-event creation;
- optimistic-lock conflicts.

# Explicitly deferred

- Journal entries, journal lines, and automatic financial posting
- Store-specific tax components, rates, rules, calculation, and exemptions
- Inventory balances, ledger entries, reservations, and unavailable quantities
- Moving weighted-average cost calculations
- Individually tracked inventory units
- Suppliers and supplier-product relationships
- Purchase orders, receiving, invoice matching, and returns to vendor
- Store-specific prices and assortment
- Promotions, price histories, and advanced pricing
- Customer requests and fulfillment
- POS transactions, tenders, stored value, and gift cards
- Buyback
- Contributor, publisher, and external classification subsystems
- Historical or vendor-specific identifier aliases
- External bibliographic enrichment and full ONIX ingestion

# Completion criteria

Phase 2 is complete when:

- GL accounts, tax classes, departments, merchandise classes, categories, and conditions can be securely administered.
- Departments can hold explicit account mappings required by future perpetual-inventory and sales posting.
- Products always have a mandatory primary identifier (entered or generated at creation).
- Users enter a valid external identifier or explicitly generate a unique `222` identifier during product creation.
- Every variant automatically receives an immutable, unique `221` SKU.
- Cross-namespace identifier collisions and reuse are prevented.
- Variants store approved class, condition, department, tax class, and regular-price assignments.
- Defaults produce predictable creation suggestions without dynamically reclassifying existing variants.
- Valid variants can be activated as sellable, while incomplete variants cannot.
- Typed and scanned identifiers resolve predictably without ambiguity.
- Minimal product and variant imports are repeatable without duplicates.
- Material changes are authorized, audited, and protected against concurrent overwrites.
- Phase 3 can introduce inventory without redesigning the merchandise or financial-classification contracts.
