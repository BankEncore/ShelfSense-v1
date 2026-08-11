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
* default standard department (for standard variants);  
* default used department (for used variants);  
* inventory mode (`inventory` or `non_inventory`);  
* pricing method;  
* used-merchandise eligibility;  
* buyback eligibility;  
* returnability default;  
* display order.

Quantity versus individual tracking is derived from inventory mode and variant type: inventory + standard ⇒ quantity-tracked; inventory + used ⇒ individually tracked; non-inventory + standard ⇒ not inventory-tracked; non-inventory + used ⇒ invalid.

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

Conditions describe the condition and pricing tier of a **used variant**, such as:

* like new;  
* good;  
* acceptable;  
* collectible.

They do not apply to standard variants. The product itself is neither standard nor used.

Phase 2 includes:

* code and name;  
* active status;  
* display order;  
* `price_adjustment_bps`, when appropriate.

If the field represents a price multiplier, `10000` means 100%, while `6000` means 60%.

A condition may suggest a price for a used variant, but the approved regular price remains stored on the variant.

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
* mandatory unique primary identifier (entered external ID or generated `222` at creation);  
* active or discontinued status;  
* optimistic locking;  
* auditing of material changes.

The model must support books, media, games, gifts, stationery, café items, services, and other bookstore merchandise without making book-specific fields universally required.

### Primary identifier

`products.primary_identifier` is required and unique for every product, including drafts.

It may contain:

* a publisher- or manufacturer-assigned identifier; or  
* a ShelfSense-generated EAN-13-compatible identifier beginning with `222`.

Rules:

* Product creation requires a mutually exclusive choice: enter an external identifier, or generate a ShelfSense identifier.  
* Remove permitted formatting such as spaces and hyphens.  
* Convert valid ISBN-10 input to ISBN-13.  
* Store ISBNs in their canonical 13-digit representation.  
* Normalize UPC-A to GTIN-13 by adding a leading zero.  
* Reject user-entered values in the reserved `222` namespace.  
* Generate `222` identifiers only when that create-time choice is selected.  
* Store entered and generated identifiers in the same field (no source column).  
* Generate a valid check digit.  
* Prevent reuse and collisions via `identifier_registry` and a unique database index.  
* Reserve the identifier in the same transaction as product persistence.

---

## 2.4 Product variants

A product variant is the actual sellable record used by later inventory, purchasing, customer-request, and POS workflows. Each variant is either a **standard variant** or a **used variant**.

Phase 2 should support:

* one or more variants per product, including both types on the same product;  
* required `variant_type` (`standard` or `used`);  
* a required generated SKU;  
* an optional variant-specific industry identifier;  
* merchandise condition only for used variants (prohibited for standard);  
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

* `variant_type`;  
* `merchandise_class_id`;  
* `department_id`;  
* `tax_class_id`;  
* `merchandise_condition_id` when used (null when standard);  
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
2. Merchandise class’s used department when `variant_type` is `used`.  
3. Merchandise class’s standard department when `variant_type` is `standard`.  
4. Otherwise unresolved.

The resolved department is saved on the variant.

### Tax class

1. Explicit variant tax class.  
2. Resolved department’s default tax class.  
3. Otherwise unresolved.

The resolved tax class is saved on the variant.

### Price

Possible price suggestions include:

* product list price (standard variants);  
* list price multiplied by the used variant’s condition adjustment;  
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
* for used variants, has an active condition and a class that allows used merchandise and is inventory-mode;  
* for standard variants, has no condition;  
* has a valid SKU;  
* satisfies the merchandise class pricing-method price rules;  
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
* unique `products.primary_identifier`;  
* unique `product_variants.sku`;  
* unique `product_variants.industry_identifier` when non-null;  
* valid `221` prefix and check digit for generated SKUs;  
* valid `222` prefix and check digit for generated product identifiers;  
* nonnegative monetary values;  
* valid basis-point ranges;  
* no self-parenting categories or GL accounts;  
* required classifications for **active** sellable variants (drafts may omit class/department/tax);  
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
* Every product has a mandatory primary identifier (entered or generated at creation).  
* Product creation offers enter-external or generate-`222` as mutually exclusive choices.  
* Every variant automatically receives an immutable, unique `221` SKU.  
* Variants store approved class, department, tax class, condition, and regular price assignments when activated.  
* A valid variant can be identified as sellable, while incomplete draft variants cannot be activated.  
* Identifier lookup resolves products and variants without ambiguity.  
* Minimal product and variant imports are repeatable without duplicates.  
* Material changes are authorized, audited, and protected against concurrent overwrites.  
* Phase 3 can introduce inventory without redesigning the merchandise or financial-classification contracts.
