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

An authorized administrator can maintain departments as reporting categories and GL posting owners; maintain merchandise classes as department-scoped policy and variant-default groups; create variants whose inventory mode, pricing method, margin, and supplier returnability do not change when class defaults later change; inherit the class’s current default tax class unless a variant override is set; and create products that always receive an immutable generated `222` identifier, an optional manufacturer GTIN at product level, and an optional lookup code.

Cashiers target merchandise by exact identifier in this order:

1. a direct inventory-unit identifier targets the unit;
2. a direct variant identifier (SKU or variant industry GTIN) targets the variant;
3. a product identifier (`222` primary, product industry GTIN, or unique lookup-code match) with one POS-eligible variant resolves to that variant;
4. a product identifier with multiple POS-eligible variants requires variant selection;
5. an individually tracked variant requires inventory-unit selection.

This phase adds one step: a lookup code that matches **multiple products** requires product selection. After a product is selected, POS resolution continues through the same product/variant/unit flow. No handler may pick the first product.

Identifier **matching** is shared. **Eligibility** (sellable, returnable, adjustable) is caller-specific and must not be baked into the matcher as POS `sellable?` for every entry point.

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
4. **Copied at variant create** (explicit input wins; omitted booleans are distinct from `false`): `inventory_mode`, `pricing_method`, `target_margin_bps`, `supplier_returnable`. Later class default changes do not mutate those stored values on existing variants.
5. **Tax class is dynamically inherited.** `merchandise_classes.default_tax_class_id` is the live default. `product_variants.tax_class_override_id` is nullable. Effective tax is the override when present, otherwise the class’s **current** default. Clearing the override resumes inheritance. Changing the class default tax class affects future tax calculation and sellability for every associated variant without an override. An inactive or unassignable new default can make those variants unsellable until remedied. Completed POS lines retain existing tax snapshots.
6. **GL mappings stay on departments.** All merchandise classes within a department share that department’s posting accounts. The class may be used later as an analytic classification, but **separate GL posting by class is not supported**. Reconsider class-level mappings **before implementing journal posting** if any two classes in the same department require different inventory, sales, COGS, shrink, adjustment, or write-down accounts. Do not postpone that decision until after posting exists.
7. Departments keep identity, lifecycle, ordering, description, and GL mappings. They drop `default_tax_class_id` and `default_target_margin_bps` (tax default and target margin move to the merchandise class).
8. Categories suggest **separate** default classes for standard and used variants. No `abbreviation` column.
9. Every new product receives a generated immutable `222` primary identifier. Creation no longer offers enter vs generate. A product may have one optional **industry identifier** (ISBN-10 / ISBN-13 / UPC-A / EAN-13 / GTIN-13), stored as canonical 13 digits and reserved as `product_industry` in `identifier_registry`. Both `222` and product industry GTIN enter the **same product-resolution path**. Variant `industry_identifier` / `variant_industry` remains only when the variant has a **genuinely distinct** manufacturer GTIN. Do not copy the product industry identifier onto a variant. Collision across registry kinds remains a hard error.
10. At most one **lookup code** per product. Lookup codes are optional, stored uppercase, **not globally unique**, and **not** in `identifier_registry`. Saving a duplicate is allowed.
11. Identifier **matching** tries the global registry first (GTIN-normalized input) via `find_any` (any row, including retired). Active row → resolve by kind. Retired row → `retired`. **Only when no registry row exists** may lookup-code fallback run. One lookup-code match yields that product; multiple matches return `multiple_products`. After product selection, POS reuses the existing product/variant/unit flow; do not flatten variants from all matching products into one list.
12. Ordinary edits cannot move a merchandise class to another department after an associated variant has inventory history (balances, ledger entries, valuation entries, or inventory units) or POS transaction-line history. Controlled bulk reclassification UI is deferred; rejected moves must not partially save.
13. Target margin range stays `NULL` or `0 <= value < 10000` basis points (gross margin, same as today’s department constraint).
14. Lookup-code characters after trim and upcase: `A–Z`, `0–9`, `.`, `_`, `/`, `-`. Maximum 64 characters. No spaces. Blank becomes `NULL`.

## Relationship to Phase 2

This packet **supersedes** the following Phase 2 / 2.1 implementation contracts:

- Product primary identifier may be an entered manufacturer GTIN/ISBN.
- Merchandise class has separate default standard and used *departments*.
- Variant stores `department_id`.
- POS and sellability read inventory mode and pricing method from the merchandise class at use time.
- Variant tax class is only a stored copy with no live class default.

It **preserves** Phase 2’s rule that inventory mode and pricing method, once stored on the variant, are not live-inherited. Tax is the exception: it is live-inherited from the class unless overridden.

Historical Phase 2 plan and schema documents remain a record of what shipped then. Implement against this packet.

## Terminology

- **Department:** top-level reporting category and **GL posting owner**. Classes in a department share those accounts.
- **Merchandise class:** department-scoped merchandise **policy and variant-default group** (including the live default tax class). Not an independently mapped posting unit.
- **Merchandise category:** hierarchical browsing / shelving taxonomy; not the accounting path.
- **Resolved variant value:** copied from a class default or explicit input and then stored on the variant (inventory mode, pricing method, margin, supplier returnability).
- **Tax override:** nullable variant `tax_class_override_id` that replaces the class’s current default.
- **Effective tax class:** the override when present; otherwise `merchandise_class.default_tax_class`.
- **Product industry identifier:** manufacturer GTIN for the bibliographic/merchandise product (typically the ISBN for a book), canonical 13 digits, registry kind `product_industry`.
- **Variant industry identifier:** manufacturer GTIN for a distinct sellable form, registry kind `variant_industry`. Unused when the product-level GTIN already identifies the edition.
- **Lookup code:** optional, nonunique product search code; may contain letters; not a GTIN; not a registry value.

Avoid calling classes “accounting subdepartments.” They are not independently mapped GL units in this phase.

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

Admin form groups: identity (including parent department and class number), operational defaults, merchandise policies. Explain that inventory, pricing, margin, and supplier-return defaults apply to **newly created** variants only, and that **tax default changes affect existing variants that have no override** (future transactions and sellability).

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
3. Tax: store `tax_class_override` only when the caller **explicitly** selects a tax class. Omitted or blank means inherit (`tax_class_override_id` null).
4. Price suggestion: unchanged list-price / condition adjustment behavior, driven by the **resolved** (soon persisted) pricing method.
5. Do not assign `department_id`.

```ruby
def effective_tax_class
  tax_class_override || merchandise_class&.default_tax_class
end
```

After create, POS, sellability, inventory tracking derivation, and open-price checks read the **variant’s** persisted `inventory_mode` and `pricing_method`. All tax consumers (activation, sellability, POS add, display) call `effective_tax_class`; they must not treat `tax_class_override_id` as the resolved class.

The variant form labels tax as an override and offers **Use merchandise-class default**. Display the currently effective tax class even when no override exists. Assignment and clearing of the override are audited and must distinguish override change from effective-value change.

`derived_inventory_tracking` uses `variant.inventory_mode` and `variant.variant_type` with the same matrix as Phase 2 (inventory+standard → quantity; inventory+used → individual; non_inventory+standard → non_inventory; non_inventory+used invalid).

Inventory-mode or variant-type changes that would change derived tracking are rejected when the variant has inventory history. History-free variants may change when the resulting type, condition, and class policy remain valid.

Activation and sellability require an active assignable merchandise class, that class’s department active/assignable, and an active assignable **effective** tax class. Price rules use the variant’s persisted pricing method.

### Products and identifiers

`Products::Create` always allocates a `222` EAN in the same transaction as registry reservation of `product_primary`. Remove `identifier_mode` and entered-primary handling from UI, controllers, CSV, and services.

Optional product `industry_identifier` is normalized with the existing GTIN normalizer (ISBN-10 → Bookland `978` ISBN-13, UPC-A → GTIN-13, EAN-13/ISBN-13 validated) and reserved as `product_industry` atomically with the product write. Assignment, replacement, and retirement use a registry-aware service equivalent to the existing variant industry-identifier service. Entered values must not use the reserved `222` namespace.

Product detail shows `primary_identifier` as read-only. Industry identifier is labeled as GTIN/ISBN/UPC with normalization explained. Optional `lookup_code` field; display the stored uppercase value. Saving a lookup code already used by other products is permitted; the UI may warn that scan/add will require product selection.

Variant SKU generation (`221`) and inventory-unit identifiers (`220`) are unchanged. Variant industry identifier remains optional and registry-aware; it is not the place to store the book’s ISBN when that ISBN belongs to the product.

### Identifier matching vs eligibility

Split two layers.

**1. Matching (`Identifiers::Lookup` or a dedicated matcher it calls)**

Return identity only. Do **not** filter variants with `sellable?`.

Statuses from matching:

- `not_found` — no registry row and no lookup-code match
- `invalid` — input cannot be interpreted
- `retired` — a registry row exists and `retired_at` is set
- `inventory_unit` — active `inventory_unit` kind
- `variant` — active `variant_sku` or `variant_industry`
- `product` — active `product_primary` or `product_industry`, or a single lookup-code product match (product record only; include or allow loading of its variants without POS eligibility filtering)
- `multiple_products` — two or more products share the lookup code

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

Matching algorithm:

1. If the raw input can be GTIN-normalized (including ISBN-10 and UPC-A), search `identifier_registry` with `find_any` (allow `222`).
2. If a registry row exists and is retired → `retired`. Stop. Do not fall through to lookup codes.
3. If a registry row exists and is active → resolve by `identifier_kind`:
   - `inventory_unit` → that unit (and its variant/product);
   - `variant_sku` / `variant_industry` → that variant;
   - `product_primary` / `product_industry` → that product.
4. If **no** registry row exists, normalize the raw input as a lookup code (`strip` + `upcase`) and search `products.lookup_code` by exact equality.
5. Letter-containing codes must not fail as invalid GTINs before step 4.
6. A numeric value that is a valid GTIN with **no** registry row may still match a lookup code. Any registry row (active or retired) wins over lookup codes.

**2. Caller eligibility**

| Caller | After a match |
|---|---|
| POS sale (`Pos::ResolveMerchandiseForSale`) | Apply sellability, store, open-price, availability, working-transaction unit-busy. Product match with one POS-eligible variant → add path; several → variant chooser; individually tracked → unit chooser; none eligible → unavailable. `multiple_products` → `product_choice_required`. |
| Linked / unlinked returns | Apply return eligibility and disposition rules to matched identity. Same product-selection rule; never first-match. |
| Inventory adjustments | May target a variant that is discontinued, unsellable, unpriced, or missing a current assignable tax class, when it still requires quantity/value correction. Do not use POS `sellable?` as the matcher. Shared lookup codes must not pick the first product. One product with several variants → require a specific SKU or present an explicit choice; do not invent POS eligibility. |
| Admin merchandise lookup / search | May display records that are not sellable. Never auto-select the first of several products. |

Today’s `Identifiers::Lookup` embeds `sellable?` when resolving `product_primary`. That must move to the POS (and similar) callers. Direct SKU/unit hits stay identity matches; callers still apply their own rules.

### POS targeting (cashier flow)

The existing targeting pattern remains authoritative for **sales**. Lookup codes and product industry GTINs extend it; they do not replace it.

Register workspace: add a product picker in the same style as the existing variant and unit pickers (keyboard list, Enter selects, Escape cancels). Product rows must identify the choice (name, `222`, industry identifier, lookup code, distinguishing subtitle/brand as available). Selecting a product re-invokes **POS eligibility** on that product (equivalent to a unique `222` or product-industry hit).

Cancel of product selection does not add or reserve merchandise.

Do not skip POS sellability, store, availability, open-price, or working-transaction unit-busy rules after product selection.

POS `ResolveMerchandiseForSale` must gain an outcome such as `product_choice_required` (carrying `products`) in addition to today’s `variant_choice_required` and `unit_choice_required`. Exhaustive `case` handlers must handle `multiple_products` / `product_choice_required` and `retired` explicitly.

**Target-specific coverage** (accepted lookup *entry* points, not a promise of uniqueness):

- Product lookup: product `222`, product industry identifier, product lookup code.
- Variant lookup: those inputs plus variant SKU and variant industry identifier.
- Inventory-unit lookup: those inputs plus inventory-unit `220` identifier.

### CSV

Template and importer:

- New products always generate `222`. Ordinary import cannot assign a primary identifier. `generate_primary_identifier` and entered `primary_identifier` on **create** are removed.
- Stable update keys: existing `222` `product_primary_identifier`, unambiguous `product_industry_identifier`, variant `sku`, variant `industry_identifier`. `product_lookup_code` locates a product only when the match is **one** product; multiple matches fail the row/group.
- Headers include `product_industry_identifier`, `product_lookup_code`, `merchandise_class_code`, `inventory_mode`, `pricing_method`, `target_margin_bps`, `supplier_returnable`, `tax_class_override_code` (blank means inherit).
- Product and variant industry identifiers use the same GTIN normalizer as the UI. Ambiguous industry-identifier matches are rejected.
- Lookup codes uppercase; duplicate lookup codes on different products are allowed on write.
- Omitted booleans vs explicit `false` must be distinguished.

### Auditing

Audit at least: department and class identity/lifecycle; class parent-department change attempts (including rejected moves); class default tax-class changes; other class default and policy changes; GL mapping changes on departments; variant persisted operational-value changes; variant tax-override assignment and clearing; product industry-identifier assignment, replacement, or retirement; product lookup-code changes; variant industry-identifier assignment/replacement/retirement.

Audit payloads must use `before_values` and `after_values` sufficient to distinguish a changed override from a changed effective tax class.

Do not put secrets or full row dumps in payloads.

## Delivery

Prefer **two pull requests** on `main` (no long-lived phase branch). Each PR includes tests, audit, admin/CSV/POS updates, seeds/fixtures, `db/schema.rb`, and documentation.

### Slice A — Classification cutover

Schema and behavior for departments, classes, categories, persisted variant operational fields, and `effective_tax_class` / tax override. POS and sellability read variant inventory mode and pricing method and effective tax. Seeds and factories rebuilt. Department and class admin UX.

### Slice B — Product identity, lookup codes, and targeting

Always-generate `222`, product industry GTIN and `product_industry` registry kind, lookup codes (nonunique), matcher vs eligibility split, lookup-code fallback that respects retired registry rows, `multiple_products`, Register product picker, POS sale/return handlers, inventory-adjustment and admin lookup handlers, CSV identity rules.

If a single PR stays reviewable, combining A and B is acceptable because data is disposable. Do not split tests from the behavior they cover.

## Test plan

### Model and database

- Department number and code uniqueness; required number.
- Class number unique within department; same number allowed in another department; `code` globally unique.
- Class requires one parent department; cannot assign an inactive department.
- Buyback implication unchanged.
- Used category default rejects a class that does not allow used merchandise.
- Variant create copies inventory, pricing, margin, and supplier-return defaults; explicit values win; explicit `false` supplier returnability is kept.
- Later class default changes for those copied fields do not mutate existing variants.
- Variant effective tax uses the class default when no override exists.
- Variant effective tax uses the override when present.
- Changing a class tax default changes effective tax only for non-overridden variants.
- Inventory-mode / tracking changes blocked after inventory history.
- Lookup code trimmed, uppercased, nullable when blank, and permitted to duplicate another product; database check rejects noncanonical storage.
- Invalid lookup-code characters rejected.
- Product and variant industry identifiers: ISBN-10, UPC-A, EAN-13 normalization and check-digit failures; reserved `222` rejected on entered industry IDs; registry collisions across kinds.

### Services

- Product create always assigns `222`; enter-external path is gone.
- Product industry assignment is atomic with registry reservation/retirement.
- Variant create assigns `221` and persists resolved copied defaults; tax override only when explicit.
- Unit create still assigns `220`.
- Matcher: registry row absent vs active vs retired are distinct; retired does not fall through to lookup codes.
- Unique registry match (including product industry) beats lookup code.
- Lowercase lookup input matches stored uppercase code.
- One lookup-code match yields that product without POS eligibility filtering in the matcher.
- Multiple lookup-code matches return `multiple_products` deterministically; no handler selects the first product.
- POS eligibility after a product match reuses existing variant and unit resolution.
- Inventory adjustment can match a product/variant that is not POS-sellable.

### POS / inventory targeting integration

- Direct unit, variant, single-variant product, multi-variant product, and individual-unit-selection flows unchanged for **sellable** merchandise.
- Product industry GTIN enters the same POS product path as `222`.
- A unique lookup code with one POS-eligible variant adds or advances as a product primary would.
- A unique lookup code with multiple POS-eligible variants uses the existing variant chooser.
- A unique lookup code whose chosen variant is individually tracked uses the existing unit chooser.
- A duplicated lookup code presents product choices; cancel does not add or reserve merchandise.
- Linked and unlinked return identifier entry handles `multiple_products` and `retired` without arbitrary selection.
- Inventory adjustment identifier entry does not apply a lookup-code match to an arbitrary product or variant and does not hide discontinued on-hand variants behind POS `sellable?`.
- Completed transactions retain tax and pricing snapshots after class tax or other defaults change.

### Cutover

- Test database schema matches `phase6.1-schema.md`.
- No remaining application reads of `product_variants.department_id`, class standard/used department FKs, category `default_merchandise_class_id`, legacy variant `tax_class_id` as the effective class, or live `merchandise_class.inventory_mode` / `pricing_method` for POS/sellability/tracking.
- Seeds boot; CSV template documents the new headers.

## Acceptance criteria

1. Departments are reporting + GL configuration; no tax or margin defaults on the department; classes in a department share the department’s posting accounts.
2. Every merchandise class has exactly one parent department and a department-scoped unique number.
3. Categories can specify separate standard and used default classes.
4. Existing variants keep persisted inventory, pricing, margin, and supplier-return values when those class defaults change.
5. Non-overridden variants use the merchandise class’s current default tax class for future transactions and sellability; overridden variants keep their override.
6. Every product has an immutable generated `222` primary identifier.
7. A product may have one optional industry GTIN in the registry (`product_industry`); both product identifiers enter the product-resolution path. Variant industry identifiers are only for a distinct manufacturer GTIN.
8. Lookup codes are optional, stored uppercase, may be shared, and resolve only when **no** registry row exists (active or retired).
9. Multiple lookup-code matches require product selection and then resume the established POS product/variant/unit flow.
10. Identifier matching does not embed POS `sellable?`; callers apply their own eligibility.
11. Existing identifier-based POS flows continue to pass without behavioral regression for sellable merchandise.
12. Documentation (this packet, README roadmap, CSV template) matches the implemented behavior.

## Out of scope

- Backward-compatible migrations or preserving disposable developer data.
- Moving GL mappings onto merchandise classes (see locked decision 6 for when to reopen).
- Multiple lookup codes per product.
- Non-GTIN industry identifier types.
- Redesigning the established POS product/variant/unit targeting workflow (this phase adds product selection for shared lookup codes and product-level industry GTIN).
- Automatically rewriting historical POS department reporting (no variant `department_id`; future reports join through class, or use snapshots already on completed lines if present).
- General-purpose bulk reclassification UI.
- Changing the `220` / `221` / `222` namespaces.
- Purchasing, journal posting, customers, buyback workflows.
- Category `abbreviation`.
- Forbidding lookup codes that equal a registry `value` (optional later; retirement already wins on scan).
