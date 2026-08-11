# Phase 2.1 — Merchandise Correctness and Operability

## Status

Proposed implementation specification

## Purpose

Phase 2.1 is a focused correctness and operability patch between the Phase 2 merchandise foundation and Phase 3 inventory foundation. It fixes merchandise contracts that inventory will depend on, restores essential reference-data lifecycle operations, completes missing product inputs, and makes CSV import discoverable.

This phase does not introduce inventory, purchasing, buyback, customer-return, or POS workflows.

## Deliverable

An authorized administrator can reactivate core financial and merchandise reference data, create products and variants with complete fields and pricing-method-aware defaults, and use a documented CSV import template. The database enforces the merchandise and GL-account invariants required before inventory begins.

## Established conventions

- Retain UUIDv7 primary and foreign keys for all domain tables. Schema examples below describe changes to the existing schema; they do not replace UUIDs with integer IDs.
- Retain `lock_version` on mutable configuration records where already required by the optimistic-locking policy.
- Retain lifecycle history. Configuration records are deactivated and reactivated, not deleted.
- Record administrative changes in `audit_events`.
- Store money as integer cents and percentages as basis points.
- Codes are stable machine-facing identifiers; names are user-facing labels.

## Scope

### Included

1. Reactivation of core financial and merchandise reference records.
2. Shared create-time code generation and normalization, with post-create immutability.
3. GL account category/type consistency.
4. Clarified and enforced merchandise-class policy fields.
5. Completed product form.
6. Product-variant naming and pricing-default corrections.
7. CSV import documentation and downloadable template.
8. An explicit database constraint requiring positive customer-reservation expiration days.
9. Authorization, audit, validation, documentation, and test coverage for these changes.

### Deferred

- Inventory ledger, balances, adjustments, units, and availability.
- Cost-based price calculation.
- POS open-price entry.
- Buyback workflows.
- Supplier return rule resolution beyond the merchandise-class default contract.
- Customer return policies.
- CSV preview and confirmation workflow.
- Dynamic inheritance that rewrites existing variants after a default changes.
- Store schema expansion, including `internal_name` and `shopping_center`.
- Receipt-header/footer inheritance, override, and blank-value semantics.
- Searchable country, region, and timezone widgets.
- Country-dependent region selection.
- Demoting codes into an Advanced UI section or broadly redesigning reference-data screens.
- Reactivation changes for users, roles, workstations, and stores.
- Broad system-settings or store-form redesign.

## 1. Configuration lifecycle and reactivation

### Behavior

The core reference records needed to configure merchandise and inventory must support explicit reactivation. This phase includes:

- GL accounts
- tax classes
- departments
- merchandise classes
- merchandise categories
- merchandise conditions

Reactivation must:

- use the same management permission family as deactivation;
- acquire and validate `lock_version` where optimistic locking applies;
- emit a successful reactivation audit event;
- reactivate only the selected record;
- never recursively reactivate dependencies;
- reject reactivation with an actionable error when the reactivated record would depend on an inactive or invalid record;
- preserve all historical references.

Products and variants retain their domain statuses (`draft`, `active`, and `discontinued`). They do not use the generic configuration reactivation action. A discontinued product or variant may transition back only through an explicit status transition that reruns current completeness validations.

### Dependency checks by record type

Reactivation must validate these relationships against the current schema. Optional foreign keys are checked only when populated. Do not invent required dependencies that create/update does not already enforce.

| Record being reactivated | Active dependencies |
|---|---|
| GL account | When `parent_id` is present, the parent GL account must be active |
| Tax class | None beyond its own validity (Phase 2 tax classes have no component dependencies) |
| Department | Always: active `default_tax_class`. When any GL mapping FK is populated, that GL account must be active and assignable, and must still satisfy the existing type/category expectation for that mapping. Departments have no parent department. |
| Merchandise class | When `default_standard_department_id` is present, that department must be active. When `default_used_department_id` is present, that department must be active. Do not require either department FK to be present solely because `used_merchandise_allowed` is true unless a separate create/update invariant already requires it. |
| Merchandise category | When `parent_id` is present, the parent category must be active. When `default_merchandise_class_id` is present, that class must be active. |
| Merchandise condition | None beyond its own validity |

An inactive optional dependency may remain attached only if the active record is valid without using it. Implementers must not recursively reactivate dependencies.

### Schema changes

No new lifecycle column is required when a table already has `active` or `status`. Add missing indexes only where needed for common active-record queries:

```ruby
add_index :<table>, :active unless index_exists?(:<table>, :active)
```

Do not add `deleted_at` or implement soft deletion as part of this phase.

## 2. Machine-facing codes

### Contract

A code is a stable identifier used by imports, APIs, configuration references, and integrations. The record name remains the normal user-facing value.

### Creation and update behavior

- If code is blank on creation, generate it from the record name.
- If code is supplied, normalize the supplied value.
- Apply the same normalizer to generated and manually supplied values.
- Do not regenerate code when the name later changes.
- Reject a normalized blank value.
- Enforce uniqueness within the scope already defined for that record type.
- After persistence, the code is immutable through ordinary model, form, import, and API updates.
- Correcting a code later requires a separately specified privileged supersede/migration workflow; that workflow is not part of Phase 2.1.

### Normalization

The shared normalizer must:

1. transliterate accented characters where supported;
2. lowercase the value;
3. replace each run of whitespace or punctuation with one underscore;
4. remove leading and trailing underscores;
5. collapse repeated underscores.

Examples:

```text
Used Books & Media  -> used_books_media
Café / Bakery      -> cafe_bakery
```

The canonical validation format is:

```regex
\A[a-z0-9]+(?:_[a-z0-9]+)*\z
```

### UI

- Create forms may accept an optional code and explain that a blank value is generated from the name.
- Edit forms display the persisted code as read-only or omit it.
- Broader changes to where codes appear in lists, selectors, and detail pages are deferred UI polish.

### Schema changes

Retain existing code columns and unique indexes. Where an existing code-bearing table lacks a database constraint, add a check constraint after normalizing existing data. For nullable code columns such as `merchandise_categories.code`, allow NULL explicitly:

```sql
-- required code columns
CHECK (code ~ '^[a-z0-9]+(_[a-z0-9]+)*$')

-- nullable code columns
CHECK (code IS NULL OR code ~ '^[a-z0-9]+(_[a-z0-9]+)*$')
```

Before adding constraints, run a migration preflight that reports normalized collisions. Do not silently choose suffixes for existing duplicates. Do not force codes onto records whose code column is intentionally nullable and currently blank.

## 3. Narrow system-settings constraint correction

The existing database permits `default_customer_reservation_expiration_days = 0`, while the intended contract requires a positive number of days. Phase 2.1 makes that change explicit even though customer reservations are implemented later.

### Schema change

1. Preflight existing settings and fail with an actionable message if the value is `NULL` or less than one; do not silently reinterpret zero.
2. Change the model validation from nonnegative to positive.
3. Replace the existing database constraint with:

```sql
CHECK (default_customer_reservation_expiration_days > 0)
```

All other system-settings schema and form refinements are deferred.

## 4. Stores — unchanged in Phase 2.1

Phase 2.1 makes no store schema or receipt-defaulting changes.

- Keep `stores.country_code` `null: false`.
- Do not add `internal_name` or `shopping_center` in this phase.
- Do not define whether blank receipt header/footer means inherit, suppress, or unset before receipt rendering exists.
- Do not copy receipt text into stores as part of this phase.

When receipt rendering is specified, choose an explicit model that distinguishes organization fallback from an intentional blank override. Locale selectors and international address refinements should be designed with their consuming tax, business-date, and receipt workflows.

## 5. GL accounts

### Contract

Retain both fields:

- `account_type`: fundamental accounting classification (`asset`, `liability`, `equity`, `revenue`, or `expense`).
- `account_category`: operational/reporting classification such as `inventory`, `sales`, `freight_in`, or `inventory_shrinkage`.

Each account category maps to exactly one account type. Users select the category; the application derives and displays the type. Persist only the mapped `account_type`. Ignore or reject a client-supplied `account_type` that conflicts with the selected category. Contradictory combinations are invalid.

Examples:

| Account category | Derived account type |
|---|---|
| `cash`, `accounts_receivable`, `inventory`, `other_current_asset`, `fixed_asset` | `asset` |
| `accounts_payable`, `other_current_liability`, `long_term_liability` | `liability` |
| `equity` | `equity` |
| `sales`, `sales_returns`, `other_revenue` | `revenue` |
| `cost_of_goods_sold`, `freight_in`, `inventory_shrinkage`, `inventory_adjustment`, `inventory_write_down`, `other_expense` | `expense` |

`sales_returns` remains a revenue type even though it is normally contra-revenue. A broader contra-account model is deferred.

### Schema changes

No column change is required. Add a database constraint or equivalent database-enforced mapping so invalid category/type pairs cannot be persisted. A `CHECK` constraint is acceptable for the current fixed enum set. The Rails model and form must use the same single mapping constant.

Before adding the constraint, validate all existing records and stop with a report if inconsistent rows exist.

## 6. Merchandise classes

### `used_merchandise_allowed`

This field remains operational in Phase 2.1. A used variant may be active and sellable only when:

- its merchandise class uses inventory mode;
- the class allows used merchandise; and
- the variant has a merchandise condition.

### `buyback_allowed`

This field records eligibility for a future customer buyback workflow. It does not mean that used merchandise may be sold.

Enforce:

```text
buyback_allowed -> used_merchandise_allowed AND inventory_mode = inventory
```

No buyback transaction behavior is implemented in this phase.

### Supplier returnability

Rename the ambiguous `default_returnable` field to `default_supplier_returnable`.

Its contract is:

> When no supplier-specific product or variant rule exists, merchandise in this class is assumed to be returnable to its supplier.

It does not govern customer returns. Future purchasing resolution order is:

```text
product_variant_supplier.returnable
-> product_supplier.returnable
-> merchandise_class.default_supplier_returnable
```

### Schema changes

```ruby
rename_column :merchandise_classes,
              :default_returnable,
              :default_supplier_returnable
```

Preserve existing values. Update forms, serializers, importer references, tests, seeds, and documentation in the same change.

Add a database check for the buyback implication if supported by the existing enum representation; otherwise enforce it in the model and add a database-level trigger or equivalent constraint. Application-only enforcement is not sufficient for imported/API writes.

### Pricing method

The supported values retain these meanings:

| Method | Phase 2.1 behavior |
|---|---|
| `fixed` | Variant must have an explicitly stored regular price before activation. No automatic product-list-price default. |
| `list_price` | Blank variant price defaults from `product.list_price_cents` when that value is present. If the product has no list price, there is no automatic default; activation and `sellable?` fail until an explicit variant price or product list price exists. Active variants require a resolved price. |
| `cost_based` | Reserved for a later pricing engine. A draft variant may use the class, but activation requires an explicitly stored regular price until calculation is implemented. |
| `open_price` | Variant may have no regular price. Do not default one from product list price. POS price entry is deferred. |

For used variants under `list_price`, apply the merchandise condition adjustment to the product list price using the existing basis-point formula and half-up cent rounding.

This replaces the current creation-time behavior in which all classes may receive a product-list-price default regardless of pricing method. Already-persisted variant prices are left alone; do not backfill or clear existing `regular_price_cents` values as part of this change. Only new creates stop auto-filling from list price for `fixed`, `open_price`, and `cost_based`.

## 7. Products

### Form changes

Add these existing fields to product create and edit forms:

- merchandise category;
- list price.

Display list price as a currency amount and convert it to/from `list_price_cents` at the form boundary. Do not ask users to enter cents directly in the ordinary form.

Explain in help text:

- list price is product-level reference pricing;
- merchandise category supplies the default merchandise class for newly created variants;
- changing category or list price does not rewrite existing variants.

### Schema changes

None. Use existing `merchandise_category_id` and `list_price_cents` columns and constraints.

## 8. Product variants

### Default name

The CSV/import field `variant_name` maps to `product_variants.name`. When that value is blank during creation:

1. for a used variant, use the selected merchandise condition’s name;
2. for a standard variant, use the English UI default `Standard`.

An explicit user/import value takes precedence. The generated name is copied to `product_variants.name` and remains editable. Changing the condition later must not silently rename an existing variant.

Apply the same rule in the UI service and CSV importer by placing it in the shared variant-creation path.

`Standard` is an initial English presentation default, not a domain enum or immutable constant. A CSV row that creates a standard variant with blank `variant_name` persists this default on `product_variants.name` rather than `NULL`.

### Default resolution

Defaults remain creation-time snapshots:

| Variant field | Resolution order |
|---|---|
| merchandise class | explicit value -> product category default |
| department | explicit value -> merchandise class standard/used default department |
| tax class | explicit value -> department default tax class |
| regular price | explicit value -> pricing-method-specific rule |

Editing a variant does not rerun all defaults. Clearing a persisted value does not mean “inherit again.” The edit form must not label blank values as dynamically inherited.

### Pricing resolution

- `fixed`: no automatic price.
- `list_price`, standard: product list price when present; otherwise no default.
- `list_price`, used: product list price adjusted by condition basis points when product list price is present; otherwise no default.
- `cost_based`: no automatic price until cost-based pricing exists.
- `open_price`: no automatic price.

Activation and `sellable?` validations must be consistent with the merchandise-class pricing-method table above.

### Schema changes

None unless `product_variants.name` incorrectly prevents the shared creation service from supplying the default. Do not add provenance flags for defaulted versus explicit values in this phase.

## 9. CSV merchandise import

### Import screen

Add:

- a downloadable UTF-8 CSV template;
- a column dictionary;
- required/conditional/optional indicators;
- allowed enum values;
- explanation of reference codes;
- explanation that `regular_price_cents` uses integer cents;
- examples for product-only, standard variant, used variant, and multiple variants;
- grouping and rollback behavior;
- generated-identifier limitations.

### Template columns

The downloadable template must use the importer’s canonical header order:

```csv
primary_identifier,name,generate_primary_identifier,status,sku,variant_type,variant_name,industry_identifier,variant_condition_code,merchandise_class_code,department_code,tax_class_code,regular_price_cents
```

The documentation must state:

- `primary_identifier` is required unless `generate_primary_identifier` is true;
- `name` is required for a new product;
- `sku` identifies an existing variant for update and cannot assign a SKU to a new variant;
- `variant_type` is `standard` or `used` for new variants;
- `variant_name` maps to `product_variants.name`;
- `variant_condition_code` is required for used variants and prohibited for standard variants;
- reference codes must exactly match persisted canonical codes;
- new variant SKUs are generated by ShelfSense;
- rows sharing a normalized entered product identifier are one transaction group;
- a failure rolls back that product group;
- blank generated product identifiers cannot group multiple rows into one new product;
- reimporting a blank generated-identifier row is not idempotent.

The template should contain headers and commented documentation only if the parser explicitly ignores comments. Otherwise provide a header-only template plus separate examples on the page.

### Behavior changes

- Preserve exact-match lookup for reference codes. Do not normalize, fuzzy-match, transliterate, or otherwise reinterpret an imported reference code during lookup. An unknown code must produce an actionable row error.
- Apply variant-name defaults through the same shared creation service used by the UI.
- Apply pricing-method-specific defaults through the shared default resolver.
- Preserve existing per-product transaction grouping and row-level error reporting.

CSV preview and confirmation remain deferred.

### Schema changes

None.

## 10. Authorization

No new broad permission families are required. New actions use the closest existing management permission:

| Action | Permission policy |
|---|---|
| Reactivate configuration record | Same permission required to deactivate/manage it |
| Download import template | Same read/import-page access as merchandise import |
| Run import | Existing merchandise-import permission |

Authorization must be enforced at controller/service boundaries, not only by hiding UI controls.

## 11. Auditing

Record successful changes for:

- reactivation;
- code assigned during record creation when material to the created record;
- GL account category/type changes;
- merchandise-class policy changes;
- product category and list-price changes;
- variant creation with resolved defaults;
- successful CSV-created or updated records.

Audit metadata should identify changed fields and before/after values where consistent with the existing audit policy. Failed validations and rolled-back import groups must not emit success events.

## 12. Migration plan

Implement schema changes in small reversible migrations:

1. Normalize existing codes and report collisions.
2. Add code format constraints, enforce post-create immutability in application paths, and add any missing active-record indexes.
3. Rename `merchandise_classes.default_returnable`.
4. Validate and add GL category/type database enforcement.
5. Validate and add merchandise-class buyback consistency enforcement.
6. Preflight and tighten `default_customer_reservation_expiration_days` from `>= 0` to `> 0` in both model and database constraints.

Migrations must work both on a fresh database and on a database containing valid Phase 2 data. Data migrations must be deterministic and must fail with actionable diagnostics rather than silently rewriting ambiguous records.

## 13. Testing requirements

### Unit and service tests

- Code normalization for blank, punctuation, whitespace, accents, digits, and normalized collisions.
- Code generation only on creation when blank.
- No code regeneration after name change and rejection of ordinary post-create code changes.
- Reactivation success, inactive dependency failure, authorization, optimistic locking, and auditing.
- Positive customer-reservation expiration validation, including rejection of zero at the model and database layers.
- GL category-to-type derivation and rejection of invalid pairs.
- Used-merchandise and buyback invariants.
- Supplier-returnability rename preserves values.
- Product form currency conversion.
- Variant names for standard, used, explicit override, and later condition change.
- Pricing defaults and activation rules for all four pricing methods.
- UI and CSV creation use the same variant defaults.

### Request/system tests

- Authorized users can reactivate each supported record type.
- Unauthorized direct requests are rejected.
- Persisted codes cannot be changed through edit forms, direct update requests, ordinary service calls, or imports.
- Product form includes category and list price.
- Variant form shows resolved creation defaults without implying ongoing inheritance on edit.
- Import page downloads the exact documented template.
- Import examples succeed against seeded reference codes.
- Invalid imports produce actionable row-level errors and no partial writes within the failed group.

### Database tests

- Fresh schema load succeeds.
- Phase 2 database migrates to Phase 2.1.
- New constraints reject invalid direct SQL writes.
- All new indexes and foreign keys exist.
- Migration rollback is tested where safe; any intentionally irreversible data migration is documented.

## 14. Documentation requirements

Update:

- Phase roadmap to identify Phase 2.1 as a refinement between merchandise foundation and inventory foundation.
- Data dictionary for changed columns and clarified field semantics.
- Authorization matrix for reactivation.
- Merchandise documentation for pricing methods and creation-time defaults.
- Purchasing notes to use `default_supplier_returnable` and the future precedence rule.
- Buyback notes to distinguish buyback eligibility from used-merchandise eligibility.
- CSV import guide and downloadable template.

## 15. Acceptance criteria

Phase 2.1 is complete when:

1. Supported inactive configuration records can be reactivated by authorized users and the action is audited.
2. All machine-facing codes are generated and normalized consistently on creation and are immutable through ordinary post-create workflows.
3. `default_customer_reservation_expiration_days` is explicitly constrained to a positive value at both model and database layers.
4. GL account category determines a compatible account type in both application and database enforcement.
5. Merchandise-class flags have the documented meanings and enforced invariants.
6. `default_returnable` has been renamed to `default_supplier_returnable` without data loss, and future contracts use supplier terminology consistently.
7. Pricing defaults respect `pricing_method`; `fixed`, `open_price`, and `cost_based` no longer receive unintended list-price defaults on create. Existing persisted variant prices are unchanged. `list_price` defaults only when `product.list_price_cents` is present.
8. Product forms expose merchandise category and human-readable list price.
9. New variants receive predictable names and creation-time merchandise defaults through one shared service path; blank CSV names persist the appropriate generated name.
10. CSV reference codes use exact canonical matching, and the import page provides an accurate downloadable template and complete field guidance.
11. Fresh database creation, Phase 2-to-2.1 migration, automated tests, static analysis, and security checks pass.
12. Documentation matches the final schema and behavior.

## 16. Out of scope for the merge gate

The absence of these features must not block Phase 2.1:

- calculated cost-based prices;
- POS prompting for open prices;
- buying merchandise from customers;
- supplier return transactions;
- customer return policies;
- inventory quantities or valuation;
- CSV dry-run preview and confirmation;
- receipt inheritance and intentional-blank semantics;
- store identity/address expansion and locale-selector polish;
- broad lifecycle changes for users, roles, workstations, and stores;
- a privileged code-supersession workflow.

They must, however, honor the contracts established here when implemented in later phases.
