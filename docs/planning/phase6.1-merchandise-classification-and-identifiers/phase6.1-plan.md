# Phase 6.1 — Merchandise classification and identifiers

## Status

Proposed. Not implemented.

## Purpose

Product and variant configuration splits responsibilities across departments, merchandise classes, categories, and variants in a way that is hard to operate:

- Departments own tax defaults, target margin, and GL mappings, while classes point at *two* optional departments (standard vs used).
- Variants store `department_id` and `tax_class_id`, but POS and sellability still read `inventory_mode` and `pricing_method` live from the merchandise class.
- Product creation offers enter-external vs generate-`222`, so a manufacturer ISBN can become the product primary identifier.

Phase 6.1 cuts over to a simpler model before purchasing, customers, buyback, or journal posting consume the current contracts.

This is a focused patch after the Phase 6 POS MVP, in the same spirit as Phase 2.1: correct merchandise contracts that later domains will depend on. It does not add purchasing, customers, buyback, or financial posting.

## Compatibility

Existing database rows, seeds, and fixtures are **disposable**. Do not implement expand/contract dual-read, nullable transition columns, production backfill reports, or preservation of enter-external product primaries.

Ship the **final** schema. Rewrite seeds, factories, CSV templates, and tests in the same change that switches application reads. Local and CI databases are rebuilt (`db:prepare` / test reset). There is no requirement to upgrade a representative pre-6.1 schema.

Completed POS and inventory facts already in a developer database may be discarded with that database. After cutover, completed facts remain immutable going forward (ADR-012 / ADR-013); configuration changes affect only future operations.

## Deliverable

An authorized administrator can maintain departments as reporting categories with department-level GL mappings; maintain merchandise classes as single-department subdepartments that own operational defaults; create variants whose inventory mode, pricing method, margin, supplier returnability, department reporting path, and tax class do not change when class or department defaults later change; and create products that always receive an immutable generated `222` identifier, optional lookup code, and manufacturer GTINs on variants.

Cashiers and inventory operators target merchandise by exact identifier in this order:

1. a direct inventory-unit identifier targets the unit;
2. a direct variant identifier (SKU or industry GTIN) targets the variant;
3. a product identifier (`222` primary or unique lookup-code match) with one eligible variant resolves to that variant;
4. a product identifier with multiple eligible variants requires variant selection;
5. an individually tracked variant requires inventory-unit selection.

This phase adds one step: a lookup code that matches **multiple products** requires product selection. After a product is selected, resolution continues through the same product/variant/unit flow. No handler may pick the first product.

## Established conventions

- UUIDv7 primary keys; `lock_version` on mutable aggregates; append-only `audit_events` for material configuration and identity changes.
- Money as integer cents; conventional percentages as integer `_basis_points` with existing range `0 <= value < 10000`.
- Machine `code` values stay normalized immutable keys; UI may label them **Key**.
- Identifier prefixes remain `220` (inventory units), `221` (variant SKUs), `222` (product primaries).
- POS scan/add stays exact-only. Prefix and name matching belong to search screens.
- Permissions stay in the existing merchandise and financial families; this phase does not add permission keys unless a new controlled operation appears (none planned).

## Locked decisions

1. **Final schema in the implementing migrations.** No dual-write window.
2. Each merchandise class belongs to **exactly one** department. Department is derived for reporting and sellability through `variant.merchandise_class.department`. Variants do not store `department_id`.
3. Merchandise-class numbers are unique within a department. Class `code` remains globally unique.
4. **Copied at variant create** (explicit input wins; omitted booleans are distinct from `false`): `inventory_mode`, `pricing_method`, `target_margin_bps`, `supplier_returnable`, `tax_class_id`. Later class or department default changes do not mutate existing variants.
5. Tax is **not** dynamically inherited. `product_variants.tax_class_id` remains the effective tax class. Class `default_tax_class_id` is a creation-time default only. Bulk “apply class tax to variants” is deferred.
6. **GL mappings stay on departments.** Class-level GL is deferred until journal posting exists and a class must post differently from its department.
7. Departments keep identity, lifecycle, ordering, description, and GL mappings. They drop `default_tax_class_id` and `default_target_margin_bps` (those defaults move to the merchandise class).
8. Categories suggest **separate** default classes for standard vs used variants. No `abbreviation` column.
9. Every new product receives a generated immutable `222` primary identifier. Creation no longer offers enter vs generate. Manufacturer identifiers are **variant** `industry_identifier` values only (existing GTIN normalizer: ISBN-10, ISBN-13, UPC-A, EAN-13). No `products.industry_identifier` and no `product_industry` registry kind.
10. At most one **lookup code** per product. Lookup codes are optional, stored uppercase, **not globally unique**, and **not** in `identifier_registry`. Saving a duplicate is allowed.
11. Identifier lookup tries the global registry first (GTIN-normalized input). If there is no active registry row, it tries an exact lookup-code match. One match enters the existing product-resolution path. Multiple matches return `multiple_products` and require product selection. After selection, reuse the existing product/variant/unit path; do not flatten variants from all matching products into one list.
12. Ordinary edits cannot move a merchandise class to another department after an associated variant has inventory history (balances, ledger entries, valuation entries, or inventory units) or POS transaction-line history. Controlled bulk reclassification UI is deferred; rejected moves must not partially save.
13. Target margin range stays `NULL` or `0 <= value < 10000` basis points (gross margin, same as today’s department constraint).
14. Lookup-code characters after trim and upcase: `A–Z`, `0–9`, `.`, `_`, `/`, `-`. Maximum 64 characters. No spaces. Blank becomes `NULL`.

## Relationship to Phase 2

This packet **supersedes** the following Phase 2 / 2.1 implementation contracts:

- Product primary identifier may be an entered manufacturer GTIN/ISBN.
- Merchandise class has separate default standard and used *departments*.
- Variant stores `department_id`.
- POS and sellability read inventory mode and pricing method from the merchandise class at use time.

It **preserves** Phase 2’s rule that approved tax class (and, after this phase, inventory mode and pricing method) are stored on the variant and are not live-inherited.

Historical Phase 2 plan and schema documents remain a record of what shipped then. Implement against this packet.

## Terminology

- **Department:** top-level reporting category and GL mapping owner.
- **Merchandise class:** department-scoped subdepartment that owns variant *defaults* and merchandise policies (`used_merchandise_allowed`, `buyback_allowed`).
- **Merchandise category:** hierarchical browsing / shelving taxonomy; not the accounting path.
- **Resolved variant value:** copied from a class default or explicit input and then stored on the variant.
- **Industry identifier:** manufacturer GTIN-compatible identifier on a **variant**, canonical 13 digits, globally unique via `identifier_registry` (`variant_industry`).
- **Lookup code:** optional, nonunique product search code; may contain letters; not a GTIN; not a registry value.

## Behavior

### Departments

Required: `department_number` (globally unique), `name`, `code` (globally unique, effectively immutable), `active`, `display_order`, `lock_version`.

Admin UI presents identity, description, lifecycle, ordering, and the existing GL mapping fields with the same account-type/category/posting validation as today. Do not expose tax or margin defaults after cutover.

Deactivation is blocked while the department has any **active** merchandise class. Deletion remains prohibited once referenced.

Show child merchandise classes on the department detail page (name, number, code, active).

### Merchandise classes

Required: `department_id` (active assignable department), `merchandise_class_number` (unique within department), `name`, `code`, `default_tax_class_id` (active assignable tax class when assigned or reactivated), `default_inventory_mode`, `default_pricing_method`, `used_merchandise_allowed`, `buyback_allowed`, `default_supplier_returnable`, `active`, `display_order`.

Optional: `target_margin_bps` (same range as locked decision 13), `description`.

Retain: buyback implies used merchandise allowed and inventory-capable default inventory mode.

Admin form groups: identity (including parent department and class number), operational defaults, merchandise policies. Explain that defaults apply to **newly created** variants only.

Class selectors that could be ambiguous include department context (name or number).

### Merchandise categories

Replace `default_merchandise_class_id` with:

- `default_standard_merchandise_class_id` (optional, active class)
- `default_used_merchandise_class_id` (optional, active class that allows used merchandise)

Retain parent, sibling-name uniqueness, cycle prevention, and code rules. Display selected classes with department context.

### Variant create and update

`ProductVariants::DefaultResolver` (or successor) at create:

1. Class: explicit class, else category default for the requested `variant_type`, else unresolved.
2. Copy class defaults for inventory mode, pricing method, target margin, and supplier returnability unless the caller submitted those fields.
3. Tax class: explicit tax class, else class `default_tax_class_id`, else unresolved.
4. Price suggestion: unchanged list-price / condition adjustment behavior, driven by the **resolved** (soon persisted) pricing method.
5. Do not assign `department_id`.

After create, POS, sellability, inventory tracking derivation, and open-price checks read the **variant’s** persisted `inventory_mode` and `pricing_method`, not the class current defaults.

`derived_inventory_tracking` uses `variant.inventory_mode` and `variant.variant_type` with the same matrix as Phase 2 (inventory+standard → quantity; inventory+used → individual; non_inventory+standard → non_inventory; non_inventory+used invalid).

Inventory-mode or variant-type changes that would change derived tracking are rejected when the variant has inventory history. History-free variants may change when the resulting type, condition, and class policy remain valid.

Activation and sellability require an active assignable merchandise class, that class’s department active/assignable, and an active assignable `tax_class` on the variant. Price rules use the variant’s persisted pricing method.

### Products and identifiers

`Products::Create` always allocates a `222` EAN in the same transaction as registry reservation. Remove `identifier_mode` and entered-primary handling from UI, controllers, CSV, and services.

Product detail shows `primary_identifier` as read-only. Optional `lookup_code` field; display the stored uppercase value. Saving a lookup code already used by other products is permitted; the UI may warn that scan/add will require product selection.

Variant SKU generation (`221`) and inventory-unit identifiers (`220`) are unchanged. Variant industry identifier assignment remains registry-aware, atomic, and audited.

### Identifier resolution

Preserve current result statuses and add product ambiguity:

- `not_found`, `invalid`, `retired`
- `product` — product resolved; no eligible sellable variant
- `multiple_products` — **new;** caused only by a nonunique lookup-code match; `products` carries the choices
- `variant`, `multi_variant`, `inventory_unit`

Compatible result shape:

```ruby
Result = Struct.new(
  :status,
  :product,
  :products,
  :variant,
  :variants,
  :inventory_unit,
  :message,
  keyword_init: true
)
```

Algorithm:

1. If the raw input can be GTIN-normalized (including ISBN-10 and UPC-A), search `identifier_registry` (allow `222`). On an active hit, follow the existing kind-specific path (unit, variant SKU/industry, product primary → existing single/multi-variant logic).
2. Otherwise, or if normalization succeeds but no **active** registry row exists, normalize the raw input as a lookup code (`strip` + `upcase`) and search `products.lookup_code` by exact equality.
3. No products: `not_found`.
4. One product: feed it into the existing product-primary resolution path (eligible sellable variants → `variant`, `multi_variant`, or `product`).
5. Multiple products: `multiple_products` with a deterministic product list (stable sort, e.g. name then `222` then id). Do not auto-select.
6. Letter-containing lookup codes must not fail as invalid GTINs before the lookup-code path runs.
7. A numeric value that is syntactically a valid GTIN may still be tried as a lookup code when no active registry record matches. A registered unique identifier always wins.

Scan/add remains exact-only. Prefix and name matching belong to interactive search (`Pos::SearchMerchandise` and admin search) and must not silently select merchandise.

### POS and inventory targeting

The existing targeting pattern is authoritative and must keep working. Lookup codes extend it; they do not replace it.

**Entry points that must use the same `Identifiers::Lookup` contract:**

| Entry point | After `multiple_products` | After a single product |
|---|---|---|
| Register scan/add (`Pos::ResolveMerchandiseForSale` and workspace) | Product-selection overlay; cancel adds nothing | Existing product path (variant chooser, unit chooser, open-price, sellability) |
| Linked and unlinked returns | Same product-selection rule; then existing return eligibility | Existing return path |
| Admin merchandise lookup | Product list or require a more specific identifier; never the first match | Existing path |
| Inventory adjustment variant identifier | Do not pick a product or variant arbitrarily. Present product choices or reject with a message that names the ambiguity and asks for a `221` SKU, unit `220`, or `222` primary | If the product has one eligible variant, that variant; if several, require a specific SKU (same as today’s `multi_variant` adjustment behavior) |

**Target-specific coverage** (accepted lookup *entry* points, not a promise of uniqueness):

- Product lookup: product `222` primary, product lookup code.
- Variant lookup: those inputs plus variant SKU and variant industry identifier.
- Inventory-unit lookup: those inputs plus inventory-unit `220` identifier.

Register workspace: add a product picker in the same style as the existing variant and unit pickers (keyboard list, Enter selects, Escape cancels). Product rows must identify the choice (name, `222`, lookup code, distinguishing subtitle/brand as available). Selecting a product re-invokes resolution with that product (equivalent to a unique product-primary hit), including:

- one eligible sellable variant → add or open-price / unit choice as today;
- several eligible variants → existing variant chooser;
- individually tracked variant → existing unit chooser;
- no eligible variant → existing unsellable/not-found messaging.

Do not skip sellability, store, availability, open-price, or working-transaction unit-busy rules after product selection.

POS `ResolveMerchandiseForSale` must gain an outcome such as `product_choice_required` (carrying `products`) in addition to today’s `variant_choice_required` and `unit_choice_required`. Exhaustive `case` handlers that currently treat unknown lookup statuses as `not_found` must handle `multiple_products` / `product_choice_required` explicitly.

### CSV

Template and importer:

- New products always generate `222`. Ordinary import cannot assign a primary identifier. `generate_primary_identifier` and entered `primary_identifier` on **create** are removed.
- Stable update keys: existing `222` `product_primary_identifier`, variant `sku`, variant `industry_identifier`. `product_lookup_code` may locate an existing product only when the match is **one** product; multiple matches fail the row/group and must not update an arbitrary product.
- Headers include `product_lookup_code`, `merchandise_class_code`, and variant operational columns when supplied: `inventory_mode`, `pricing_method`, `target_margin_bps`, `supplier_returnable`, `tax_class_code` (stored on the variant; blank tax means apply class default at create).
- Variant `industry_identifier` uses the same normalizer as the UI.
- Lookup codes uppercase; duplicate lookup codes on different products are allowed on write.
- Omitted booleans vs explicit `false` must be distinguished.

### Auditing

Audit at least: department and class identity/lifecycle; class parent-department change attempts (including rejected moves); class default and policy changes; GL mapping changes on departments; variant persisted operational and tax-class changes; product lookup-code changes; variant industry-identifier assignment/replacement/retirement.

Do not put secrets or full row dumps in payloads. Use `before_values` / `after_values` for the fields that changed.

## Delivery

Prefer **two pull requests** on `main` (no long-lived phase branch). Each PR includes tests, audit, admin/CSV/POS updates, seeds/fixtures, `db/schema.rb`, and documentation.

### Slice A — Classification cutover

Schema and behavior for departments, classes, categories, and persisted variant operational fields. POS and sellability read variant inventory mode and pricing method. Seeds and factories rebuilt. Department and class admin UX.

### Slice B — Product identity, lookup codes, and targeting

Always-generate `222`, remove enter/generate, add lookup codes (nonunique), extend `Identifiers::Lookup` with lookup-code fallback and `multiple_products`, Register product picker, POS sale/return handlers, inventory-adjustment and admin lookup handlers, CSV identity rules.

If a single PR stays reviewable, combining A and B is acceptable because data is disposable. Do not split tests from the behavior they cover.

## Test plan

### Model and database

- Department number and code uniqueness; required number.
- Class number unique within department; same number allowed in another department; `code` globally unique.
- Class requires one parent department; cannot assign an inactive department.
- Buyback implication unchanged.
- Used category default rejects a class that does not allow used merchandise.
- Variant create copies class defaults; explicit values win; explicit `false` supplier returnability is kept.
- Later class default changes do not mutate existing variants.
- Variant tax is the stored `tax_class_id`; changing class default tax does not change existing variants.
- Inventory-mode / tracking changes blocked after inventory history.
- Lookup code trimmed, uppercased, nullable when blank, and permitted to duplicate another product; database check rejects noncanonical storage.
- Invalid lookup-code characters rejected.

### Services

- Product create always assigns `222`; enter-external path is gone.
- Variant create assigns `221` and persists resolved defaults.
- Unit create still assigns `220`.
- Unique registry match beats lookup code.
- Lowercase lookup input matches stored uppercase code.
- One lookup-code match enters existing product resolution.
- Multiple lookup-code matches return `multiple_products` deterministically; no handler selects the first product.
- Product selection after `multiple_products` reuses existing variant and unit resolution.
- GTIN normalizer behavior for variant industry identifiers unchanged (ISBN-10, UPC-A, EAN-13, check-digit failures, reserved `222` on *entered* industry IDs as today).

### POS / inventory targeting integration

- Direct unit, variant, single-variant product, multi-variant product, and individual-unit-selection flows unchanged.
- A unique lookup code with one eligible variant adds or advances as a product primary would.
- A unique lookup code with multiple eligible variants uses the existing variant chooser.
- A unique lookup code whose variant is individually tracked uses the existing unit chooser.
- A duplicated lookup code presents product choices; cancel does not add or reserve merchandise.
- Selecting a product then follows the same variant/unit/open-price outcomes as a direct `222` hit.
- Linked and unlinked return identifier entry handles `multiple_products` without arbitrary selection.
- Inventory adjustment identifier entry does not apply a lookup-code match to an arbitrary product or variant.
- Completed transaction tax and pricing snapshots still reconstruct after class default changes (because variants and lines store their own values).

### Cutover

- Test database schema matches `phase6.1-schema.md`.
- No remaining application reads of `product_variants.department_id`, class standard/used department FKs, category `default_merchandise_class_id`, or live `merchandise_class.inventory_mode` / `pricing_method` for POS/sellability/tracking.
- Seeds boot; CSV template documents the new headers.

## Acceptance criteria

1. Departments are reporting + GL configuration; no tax or margin defaults on the department.
2. Every merchandise class has exactly one parent department and a department-scoped unique number.
3. Categories can specify separate standard and used default classes.
4. Existing variants (after cutover, in tests/seeds) keep persisted inventory, pricing, margin, supplier-return, and tax values when class defaults change.
5. Every product has an immutable generated `222` primary identifier.
6. Manufacturer GTINs are variant industry identifiers in the registry.
7. Lookup codes are optional, stored uppercase, may be shared by multiple products, and resolve only after a registry miss.
8. Multiple lookup-code matches require product selection and then resume the established POS product/variant/unit flow.
9. Existing identifier-based POS flows continue to pass without behavioral regression.
10. Inventory adjustment and other identifier handlers never apply a shared lookup code to an arbitrary product.
11. Documentation (this packet, README roadmap, CSV template) matches the implemented behavior.

## Out of scope

- Backward-compatible migrations or preserving disposable developer data.
- Live tax inheritance or variant `tax_class_override_id`.
- Product-level industry identifier / `product_industry` registry kind.
- Moving GL mappings onto merchandise classes.
- Multiple lookup codes per product.
- Non-GTIN industry identifier types.
- Redesigning the established POS product/variant/unit targeting workflow (this phase only *adds* product selection for shared lookup codes).
- Automatically rewriting historical POS department reporting (no variant `department_id`; future reports join through class, or use snapshots already on completed lines if present).
- General-purpose bulk reclassification UI.
- Changing the `220` / `221` / `222` namespaces.
- Purchasing, journal posting, customers, buyback workflows.
- Category `abbreviation`.
