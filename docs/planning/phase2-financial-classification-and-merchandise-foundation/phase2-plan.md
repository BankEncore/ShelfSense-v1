# Phase 2 — Financial Classification and Merchandise Foundation

## Objective

Establish the financial classifications and merchandise catalog required to create, price, classify, and retrieve sellable product variants.

Phase 2 will define the relationship between merchandise and ShelfSense’s perpetual-inventory framework, but it will not yet track stock, calculate taxes, or create journal entries.

## Phase deliverable

> An authorized user can configure the financial classifications used by merchandise, create a product with one or more sellable variants, assign or resolve each variant’s department and tax class, establish its regular price, and retrieve it by product identifier, variant SKU, or variant-specific industry identifier.

---

## 2.1 Financial classification foundation

### GL accounts

Implement the chart-of-accounts records that departments will reference.

Suggested fields:

| Field | Purpose |
| :---- | :---- |
| `id` | UUIDv7 primary key |
| `account_number` | Unique account code |
| `name` | Account name |
| `account_type` | Asset, liability, equity, revenue, expense |
| `account_category` | Inventory, COGS, sales, returns, shrinkage, etc. |
| `parent_id` | Optional account hierarchy |
| `active` | Whether the account may be assigned |
| `lock_version` | Optimistic locking |
| timestamps | Record lifecycle |

Phase 2 provides account administration and validation only. It does not post journal entries.

### Tax classes

Tax classes identify the kind of tax treatment associated with merchandise.

Examples include:

* physical book;  
* physical general merchandise;  
* clothing;  
* newspaper;  
* periodical;  
* bakery;  
* packaged food;  
* bottled beverage;  
* non-taxable service.

Phase 2 includes:

* code and name;  
* description;  
* active status;  
* display order;  
* assignment to variants through department defaults or explicit overrides.

Store-specific rates, tax rules, exemptions, and tax calculations are deferred.

### Departments

Departments serve as the stable financial and reporting classification for merchandise.

Suggested fields include:

* department number or code;  
* name and description;  
* active status;  
* display order;  
* default tax class;  
* default target margin, if used for price suggestions;  
* inventory asset GL account;  
* cost-of-goods-sold GL account;  
* sales GL account;  
* sales returns GL account;  
* shrinkage GL account;  
* inventory adjustment GL account;  
* inventory write-down GL account;  
* freight or receiving-clearing accounts where applicable.

Account mappings may initially be nullable. ShelfSense should require the mappings relevant to an event before financial posting is enabled in a later phase.

Because ShelfSense uses perpetual inventory, `inventory_asset_gl_account_id` and `cost_of_goods_sold_gl_account_id` must be modeled separately. A purchases account must not substitute for COGS.

---

## 2.2 Merchandise reference data

### Merchandise classes

A merchandise class describes how a sellable variant behaves operationally.

Phase 2 fields should include:

* code and name;  
* description;  
* active status;  
* default standard department;  
* default used department;  
* inventory tracking mode;  
* pricing method;  
* used-merchandise eligibility;  
* buyback eligibility;  
* returnability default;  
* display order.

Recommended inventory tracking modes:

* `quantity`  
* `individual`  
* `non_inventory`

Later workflows will use these settings, but Phase 2 only needs to capture and validate them.

### Merchandise categories

Categories provide a descriptive hierarchy for browsing, organization, and reporting.

Phase 2 includes:

* code, if useful;  
* name;  
* parent category;  
* active status;  
* display order;  
* default merchandise class;  
* product assignment.

A category’s default merchandise class is a creation-time suggestion. It should not dynamically change existing variants.

### Merchandise conditions

Conditions distinguish merchandise states such as:

* new;  
* used;  
* collectible;  
* damaged;  
* remainder.

Phase 2 includes:

* code and name;  
* active status;  
* display order;  
* `price_adjustment_bps`, when appropriate.

If the field represents a price multiplier, `10000` means 100%, while `6000` means 60%.

A condition may suggest a price, but the approved regular price remains stored on the variant.

---

## 2.3 Products

A product contains the shared catalog identity and descriptive information for an item.

Phase 2 should support:

* manual creation and editing;  
* title or name;  
* optional description;  
* optional list price;  
* optional publication or release metadata;  
* merchandise category;  
* optional unique primary identifier;  
* active or discontinued status;  
* optimistic locking;  
* auditing of material changes.

The model must support books, media, games, gifts, stationery, café items, services, and other bookstore merchandise without making book-specific fields universally required.

### Primary identifier

`products.primary_identifier` is nullable and unique when present.

It may contain:

* a publisher- or manufacturer-assigned identifier;  
* a ShelfSense-generated EAN-13-compatible identifier beginning with `222`.

Rules:

* Remove permitted formatting such as spaces and hyphens.  
* Convert valid ISBN-10 input to ISBN-13.  
* Store ISBNs in their canonical 13-digit representation.  
* Normalize UPC-A to its 13-digit representation if canonical GTIN-13 storage is adopted.  
* Generate `222` identifiers only when explicitly requested.  
* Store entered and generated identifiers in the same field.  
* Do not store identifier type or provenance.  
* Generate a valid check digit.  
* Prevent reuse and collisions with a unique database index.

Products without identifiers remain valid.

---

## 2.4 Product variants

A product variant is the actual sellable record used by later inventory, purchasing, customer-request, and POS workflows.

Phase 2 should support:

* one or more variants per product;  
* a required generated SKU;  
* an optional variant-specific industry identifier;  
* condition;  
* merchandise class;  
* department;  
* tax class;  
* regular selling price;  
* distinguishing variant attributes;  
* active or discontinued status;  
* sellability validation.

### Variant SKU

Every variant receives an automatically generated SKU.

Rules:

* EAN-13-compatible;  
* begins with `221`;  
* has a valid check digit;  
* globally unique within the installation;  
* immutable after creation;  
* never reused.

### Variant industry identifier

A variant may have an optional industry identifier when that identifier belongs specifically to the variant.

It must be:

* normalized using the applicable product-identifier rules;  
* unique when present;  
* distinct from the generated SKU.

The product’s primary identifier should not be copied to its variants merely to support scanning.

### Stored financial classifications

The variant should store its approved:

* `merchandise_class_id`;  
* `department_id`;  
* `tax_class_id`;  
* `condition_id`;  
* `regular_price_cents`.

These should not remain purely dynamic inherited values. Defaults assist creation, while stored assignments prevent later configuration changes from silently reclassifying existing merchandise.

---

## 2.5 Default resolution and pricing

When creating or editing a variant, ShelfSense should apply defaults in this order.

### Merchandise class

1. Explicitly selected variant class.  
2. Product category’s default merchandise class.  
3. Otherwise unresolved.

A merchandise class is required before the variant can become sellable.

### Department

1. Explicit variant department.  
2. Merchandise class’s used department for a used variant.  
3. Merchandise class’s standard department otherwise.  
4. Otherwise unresolved.

The resolved department is saved on the variant.

### Tax class

1. Explicit variant tax class.  
2. Resolved department’s default tax class.  
3. Otherwise unresolved.

The resolved tax class is saved on the variant.

### Price

Possible price suggestions include:

* product list price;  
* list price multiplied by the condition adjustment;  
* later, cost-based pricing using the department’s target margin.

Phase 2 should store the user-approved `regular_price_cents`. It should not continuously recalculate prices when defaults change.

Cost-based pricing can be fully implemented after purchasing establishes a reliable unit cost.

### Sellability

A variant should be considered sellable only when it:

* is active;  
* belongs to an active product;  
* has an active merchandise class;  
* has an active department;  
* has an active tax class;  
* has an active condition;  
* has a valid SKU;  
* has a valid nonnegative regular price;  
* satisfies any class-specific required attributes.

A product may exist in an incomplete state without having a sellable variant.

---

## 2.6 Identifier lookup

Create one lookup service used by forms, imports, and later barcode workflows.

It should search:

* `products.primary_identifier`;  
* `product_variants.sku`;  
* `product_variants.industry_identifier`.

Expected behavior:

* A SKU resolves directly to its variant.  
* A variant industry identifier resolves directly to its variant.  
* A product identifier resolves to its product.  
* If the product has one eligible sellable variant, the caller may proceed directly to it.  
* If multiple variants are eligible, the user selects one.  
* ISBN-10 input resolves the equivalent stored ISBN-13.  
* Invalid or ambiguous input produces a clear result instead of selecting arbitrarily.

Uniqueness should be enforced across each identifier field. The lookup service should also prevent an identifier from creating ambiguity across product and variant namespaces.

---

## 2.7 Minimal import

Provide a small, controlled import pathway using the same services as manual entry.

Phase 2 import should:

* accept products and variants;  
* normalize identifiers;  
* match products by normalized primary identifier;  
* match variants by SKU or variant industry identifier where appropriate;  
* avoid duplicates when the same file is imported again;  
* apply the normal default-resolution rules;  
* report row-level errors;  
* avoid partially importing an invalid product/variant group.

A CSV import is sufficient. External catalog enrichment and full ONIX ingestion are deferred.

---

## 2.8 Administration, authorization, and audit

Phase 2 should follow the conventions established in Phase 1:

* UUIDv7 primary and foreign keys;  
* Rails optimistic locking through `lock_version`;  
* server-rendered Rails HTML;  
* policy-based authorization;  
* active/inactive lifecycle management;  
* consistent validation and error handling;  
* audit events for material changes.

Material audited events should include:

* assigning or replacing a product identifier;  
* generating a `222` identifier;  
* generating a variant SKU;  
* changing a regular price;  
* changing department, tax class, merchandise class, or condition;  
* activating or discontinuing a product or variant;  
* changing department GL mappings.

Routine edits to descriptive text do not necessarily need individual business-level audit events if ordinary record-change auditing already captures them.

---

## Implementation sequence

| Slice | Scope | Demonstrable outcome |
| :---- | :---- | :---- |
| 2.1 | GL accounts and tax classes | Financial and tax classifications can be administered |
| 2.2 | Departments and account mappings | A department can define tax, reporting, and future perpetual-inventory posting behavior |
| 2.3 | Merchandise classes, categories, and conditions | Merchandise defaults and operational behavior can be configured |
| 2.4 | Products and primary identifiers | Products can be created, normalized, and found by identifier |
| 2.5 | Variants and resolved assignments | A fully classified and priced sellable variant can be created |
| 2.6 | Unified identifier lookup | Typed or scanned identifiers resolve predictably |
| 2.7 | Minimal import | Products and variants can be imported idempotently |
| 2.8 | Hardening and documentation | Authorization, auditing, constraints, tests, and documentation are complete |

Each slice should include migrations, models, policies, interfaces, tests, audit integration, and documentation rather than leaving those concerns until the end.

## Key database constraints

At minimum, enforce:

* unique GL account numbers;  
* unique department codes or numbers;  
* unique reference-data codes;  
* unique `products.primary_identifier` when non-null;  
* unique `product_variants.sku`;  
* unique `product_variants.industry_identifier` when non-null;  
* valid `221` prefix and check digit for generated SKUs;  
* valid `222` prefix and check digit for generated product identifiers;  
* nonnegative monetary values;  
* valid basis-point ranges;  
* no self-parenting categories or GL accounts;  
* required classifications for sellable variants;  
* immutable variant SKUs.

Application validation should provide usable messages, but database constraints remain the final protection.

## Testing priorities

Phase 2 should specifically test:

* concurrent `221` and `222` generation without collisions;  
* ISBN-10 conversion and identifier normalization;  
* partial unique indexes with multiple `NULL` values;  
* prevention of cross-namespace identifier ambiguity;  
* merchandise-class-to-department resolution;  
* department-to-tax-class resolution;  
* standard versus used department selection;  
* explicit overrides;  
* changes to defaults not altering stored variant assignments;  
* sellability validation;  
* inactive reference records not being assigned to new variants;  
* import idempotency;  
* authorization and audit-event creation;  
* optimistic-lock conflicts.

## Explicitly deferred

* Inventory balances and ledger entries  
* Moving weighted-average cost calculations  
* Individually tracked inventory units  
* Inventory reservations and unavailable quantities  
* Suppliers and supplier-product relationships  
* Purchase orders and receiving  
* Journal entries and automatic posting  
* Store-specific tax rates and rules  
* Tax calculation and exemptions  
* Customer requests and fulfillment  
* POS transactions  
* Promotions and advanced pricing  
* Stored value and gift cards  
* Buyback  
* Contributor, publisher, and external classification subsystems  
* Historical and vendor-specific identifier aliases  
* External bibliographic enrichment

## Completion criteria

Phase 2 is complete when:

* Financial classifications, tax classes, and departments can be administered securely.  
* Departments can hold the account mappings required by perpetual inventory.  
* Merchandise categories, classes, and conditions can provide creation defaults.  
* Products may exist with or without a primary identifier.  
* Users can enter an identifier or explicitly generate a unique `222` identifier.  
* Every variant automatically receives an immutable, unique `221` SKU.  
* Variants store approved class, department, tax class, condition, and regular price assignments.  
* A valid variant can be identified as sellable, while incomplete variants cannot.  
* Identifier lookup resolves products and variants without ambiguity.  
* Minimal product and variant imports are repeatable without duplicates.  
* Material changes are authorized, audited, and protected against concurrent overwrites.  
* Phase 3 can introduce inventory without redesigning the merchandise or financial-classification contracts.
