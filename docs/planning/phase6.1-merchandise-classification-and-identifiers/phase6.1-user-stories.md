# Phase 6.1 — User stories

Status: **accepted** backlog for [phase6.1-plan.md](phase6.1-plan.md). Acceptance criteria must not be weakened if a story is split across PRs.

Existing product, variant, inventory-unit, and POS resolution behavior (unit → variant → product → variant choice → unit choice) is a regression boundary. This backlog **adds** product selection when a lookup code matches multiple products, product-level industry GTIN as a product identifier, and live tax inheritance with an optional override.

Stories deferred from the earlier expand/contract draft (class-level GL, staged production migration) are listed under [Deferred](#deferred).

---

## Epic A — Department and class organization

### A1 — Maintain top-level departments

**As an administrator,** I want to maintain departments as reporting categories with accounting mappings **so that** financial posting stays at the department level and the hierarchy stays understandable.

#### Acceptance criteria

- A department requires a department number, name, and key/code.
- Department number is unique across departments.
- Key/code is normalized, globally unique, and effectively immutable after creation.
- Department configuration exposes the existing GL mappings with current validation.
- Department configuration does not expose tax defaults or margin defaults.
- Help or documentation states that all merchandise classes in the department share these posting accounts.
- An administrator can activate or deactivate a department subject to lifecycle restrictions.
- A department with active merchandise classes cannot be deactivated.
- A department detail page identifies its child merchandise classes.
- Department changes are audited.

### A2 — Maintain merchandise classes as department-scoped policy groups

**As a merchandise administrator,** I want every merchandise class to belong to one department **so that** each sellable item has an unambiguous reporting path.

#### Acceptance criteria

- A merchandise class requires exactly one parent department.
- A merchandise class requires a class number, name, and key/code.
- The class number is unique within its parent department.
- The same class number may be used in a different department.
- The key/code remains globally unique so imports can identify a class without department context.
- Class selectors display department context where class names could otherwise be ambiguous.
- A class cannot be assigned to an inactive department.
- Class identity and parent changes are audited.

### A3 — Prevent unsafe class reclassification

**As a financial administrator,** I want historically used merchandise classes protected from ordinary department reassignment **so that** reporting is not silently reclassified.

#### Acceptance criteria

- An ordinary edit cannot move a merchandise class to another department after an associated variant has inventory history or POS transaction-line history.
- The administrator receives a clear explanation that a controlled reclassification process is required (that process is not in this phase).
- A rejected move does not partially update the class.
- The attempt and outcome are auditable where existing policy records failed controlled changes.
- Classes without qualifying history may be reassigned when all other validations pass.

---

## Epic B — Merchandise-class defaults and variant behavior

### B1 — Configure variant defaults on a merchandise class

**As a merchandise administrator,** I want to configure operational defaults on a merchandise class **so that** new variants are created consistently and tax policy can be applied centrally.

#### Acceptance criteria

- A class includes default tax class, default inventory mode, default pricing method, optional target margin in basis points, and default supplier-returnable status.
- The class also records whether used merchandise and buyback are allowed.
- Default tax class must be active and assignable.
- Margin, when present, is an integer `0` through `9999` basis points (`< 10000`).
- Buyback cannot be enabled unless used merchandise is allowed and the class default inventory mode is inventory-capable.
- The form explains that inventory, pricing, margin, and supplier-return defaults are copied to new variants only, and that tax default changes affect existing variants without an override.
- Changes are audited.

### B2 — Persist operational defaults when creating a variant

**As a merchandise manager,** I want new variants to retain resolved inventory, pricing, margin, and supplier-return settings **so that** later class-default changes do not alter those values on existing merchandise.

#### Acceptance criteria

- Omitted inventory mode, pricing method, target margin, and supplier returnability are copied from the class at create.
- Explicitly supplied values take precedence.
- Explicit `false` supplier returnability is distinguished from an omitted value.
- Later changes to these class defaults do not mutate existing variants.
- The variant detail page displays the persisted values.
- CSV and service-based creation follow the same resolution rules as the administrative UI.

### B3 — Protect inventory tracking after history exists

**As an inventory manager,** I want a variant’s inventory behavior protected after inventory activity begins **so that** ledger and unit history stay consistent.

#### Acceptance criteria

- A variant stores its inventory mode rather than dynamically reading the current class default.
- A class default inventory-mode change affects only future variants.
- A variant inventory-mode or variant-type change is rejected when it would change effective tracking after inventory history exists.
- Inventory history includes balances, ledger entries, valuation entries, and inventory units.
- A rejected change leaves the variant unchanged and explains why it is prohibited.
- A history-free variant may be changed when the resulting variant type, condition, and class policy are valid.

### B4 — Inherit the current class tax by default

**As a tax administrator,** I want variants to use their merchandise class’s current default tax class unless specifically overridden **so that** tax-policy changes can be applied centrally.

#### Acceptance criteria

- A variant with no tax override uses its merchandise class’s current default tax class.
- Changing a class default tax class changes the effective tax class for future transactions involving non-overridden variants.
- The change does not require editing each associated product or variant.
- A variant must have an active, assignable effective tax class before it can be activated or sold.
- An inactive or unassignable new class default can make non-overridden variants unsellable until remedied.
- Administrative displays show the effective tax class and indicate that it is inherited.
- Completed transactions retain their original tax snapshots after a class default changes.

### B5 — Override tax for an exceptional variant

**As a merchandise administrator,** I want to assign a variant-specific tax override **so that** exceptional merchandise can receive the correct treatment without changing its class.

#### Acceptance criteria

- The variant form offers an explicit **Use merchandise-class default** option.
- Selecting a tax class stores a variant override.
- An override must reference an active, assignable tax class when assigned.
- The override remains effective when the class default changes.
- Clearing the override immediately returns the variant to the class’s current default.
- The UI distinguishes the override from the effective inherited value.
- Assignment and clearing are audited.

### B6 — Preserve historical sale calculations

**As a financial reviewer,** I want completed sales to retain the tax and pricing basis used at completion **so that** later merchandise configuration changes do not alter historical receipts.

#### Acceptance criteria

- Completed transaction lines retain the tax and pricing snapshots already required by POS completion.
- Changing a class tax default or any copied new-variant default does not change completed transaction data.
- Reprints and historical views use stored transaction snapshots rather than current class configuration.

---

## Epic C — Merchandise-category defaults

### C1 — Choose separate standard and used class defaults

**As a merchandise administrator,** I want a merchandise category to suggest different classes for standard and used variants **so that** each type receives appropriate defaults.

#### Acceptance criteria

- A category may specify a default standard merchandise class and a default used merchandise class.
- Either default may be blank.
- A selected class must be active and assignable.
- The used default must allow used merchandise.
- Category forms and detail pages display each selected class with its department context.
- Existing parent, sibling-name, and cycle validation remains intact.
- When variant creation begins from a categorized product, the class suggested corresponds to the requested variant type.
- A user may explicitly choose another valid class.

---

## Epic D — ShelfSense and industry identifiers

### D1 — Automatically identify every product

**As a merchandise user,** I want ShelfSense to assign every product its own identifier automatically **so that** product creation does not depend on a manufacturer identifier.

#### Acceptance criteria

- Every newly created product receives a valid, unique `222`-prefixed EAN-13 primary identifier.
- Product primary identifier is required and immutable.
- Product creation does not ask the user to enter or generate the primary identifier.
- A manufacturer identifier is not stored as the product primary identifier.
- Product detail pages display the ShelfSense primary identifier as read-only.
- Existing `221` variant SKU and `220` inventory-unit namespaces remain unchanged.
- Identifier allocation and product creation are atomic.

### D2 — Record a product industry identifier

**As a merchandise user,** I want to record a product’s valid ISBN, UPC, or EAN on the product **so that** a scan identifies the bibliographic/merchandise item and then uses the existing product → variant-choice flow (standard vs used).

#### Acceptance criteria

- A product may have one optional industry identifier.
- ISBN-10 input is validated and converted to a `978` Bookland EAN-13.
- Valid UPC-A input is validated and normalized to GTIN-13.
- ISBN-13/EAN-13/GTIN-13 input is check-digit validated and stored as 13 digits.
- Formatting characters permitted by the normalizer do not affect the canonical stored value.
- Invalid or unsupported identifiers are rejected with a useful error.
- Entered values may not use the reserved `222` namespace.
- The normalized identifier must not collide with any active registry value (product primary, product industry, variant SKU, variant industry, inventory unit).
- Assignment, replacement, and retirement use a registry-aware atomic service (`product_industry`) and are audited.
- A product industry identifier enters the same product-resolution path as the `222` primary (then POS or other caller eligibility).
- The product industry identifier is not copied onto a variant.

### D3 — Record a variant industry identifier only for a distinct manufacturer GTIN

**As an inventory operator,** I want a variant-level industry identifier only when that variant has its own manufacturer GTIN **so that** a scan can target that form without stealing the product’s ISBN.

#### Acceptance criteria

- A variant may have one optional industry identifier.
- The same normalization and collision rules as product industry identifiers apply.
- Direct variant industry-identifier scans continue to resolve to that variant (identity match), after which the caller applies eligibility.
- Assigning a variant industry identifier equal to the parent product’s industry identifier is rejected.

### D4 — Continue identifying variants and units in separate namespaces

**As an inventory operator,** I want variants and individually tracked units to retain distinct ShelfSense identifiers **so that** scans target the appropriate level of merchandise.

#### Acceptance criteria

- Every new variant receives a valid, unique `221`-prefixed SKU.
- Every new inventory unit receives a valid, unique `220`-prefixed identifier.
- Product, variant, and unit identifiers remain globally collision-free in the registry.
- Direct variant and unit scans continue through existing identity matching.
- The phase does not reinterpret an existing `220`, `221`, or `222` identifier as another record type.

---

## Epic E — Product lookup codes and POS/inventory targeting

### E1 — Assign a lookup code to a product

**As a merchandise user,** I want to assign a familiar lookup code to a product **so that** staff can locate merchandise using a store-defined code.

#### Acceptance criteria

- A product may have zero or one lookup code.
- Permitted characters after normalization: uppercase letters, digits, period, underscore, slash, hyphen.
- Leading and trailing whitespace is removed; letters are stored uppercase; blank becomes no lookup code.
- Maximum 64 characters.
- The same lookup code may be assigned to more than one product.
- Saving a duplicate lookup code is permitted and does not overwrite another product.
- The UI may warn that a shared code will require product selection at scan/add.
- The stored uppercase value is displayed in UI and exports.
- Lookup-code changes are audited.

### E2 — Find a product by lookup code without regard to case

**As a cashier or merchandise user,** I want lookup-code searches to ignore letter case **so that** typed case does not matter.

#### Acceptance criteria

- Search input is trimmed and converted to uppercase before lookup-code comparison.
- `abc-12`, `ABC-12`, and input padded with surrounding spaces produce the same lookup-code matches.
- Comparison is exact after normalization.
- Distinguish registry row **absent**, **active**, and **retired**.
- An active registry match takes precedence over the same raw value used as a lookup code.
- A retired registry match returns `retired` and does **not** fall through to lookup codes, even if a product uses that string as a lookup code.
- Lookup-code fallback runs only when **no** registry row exists.
- Letter-containing codes are not rejected as invalid GTINs before the lookup-code path runs.
- Prefix or name search does not silently add an item through exact scan/add behavior.

### E3 — Select a product when a lookup code is shared

**As a cashier,** I want to choose the intended product when a lookup code matches multiple products **so that** ShelfSense never adds an arbitrary item.

#### Acceptance criteria

- One lookup-code match enters the POS product-resolution flow without an unnecessary product chooser.
- Multiple lookup-code matches present a deterministic product-selection list.
- No handler automatically chooses the first product.
- Product choices contain enough identifying information (name, `222`, industry identifier, lookup code, other distinguishing fields) for the cashier to tell them apart.
- Selecting a product resumes POS eligibility on that product (variant chooser, unit chooser, open-price as applicable).
- If the selected product has one POS-eligible variant, existing single-variant behavior applies.
- If it has multiple POS-eligible variants, the existing variant chooser appears.
- If the chosen variant is individually tracked, the existing inventory-unit chooser appears.
- Cancelling product selection does not add or reserve merchandise.

### E4 — Preserve direct product, variant, and unit targeting

**As a cashier,** I want existing identifier scans to behave as they do today **so that** lookup codes do not change checkout for GTIN/SKU/unit scans.

#### Acceptance criteria

- A direct inventory-unit identifier continues targeting that unit.
- A direct variant SKU or variant industry identifier continues targeting that variant.
- A direct product primary or product industry identifier continues entering the POS product-resolution path.
- Retired, invalid, and missing identifiers retain their existing outcomes (`retired` is not remapped to a lookup-code hit).
- Lookup-code fallback occurs only when no registry record exists.
- Existing store, sellability, availability, open-price, working-transaction, variant-choice, and unit-choice rules remain enforced **in the POS caller**, not in the shared matcher.

### E5 — Target inventory adjustments without POS sellability

**As an inventory operator,** I want identifier entry on inventory adjustments to match identity first **so that** I can correct on-hand for variants that are not currently sellable, without applying a shared lookup code to the wrong product.

#### Acceptance criteria

- Unit `220`, variant SKU, and variant industry identifier continue to select that unit’s variant or that variant regardless of POS `sellable?`.
- Product `222`, product industry GTIN, and unique lookup code match the product; the operator may then select among that product’s variants, including discontinued or unsellable ones that still require adjustment.
- A shared lookup code does not select the first matching product or variant.
- The operator either chooses among matching products or receives an error that names the ambiguity and asks for a more specific identifier.
- Matching does not hide a discontinued on-hand variant because it fails `sellable?`.

---

## Epic F — Import and cutover

### F1 — Import merchandise under the new model

**As a merchandise administrator,** I want CSV import to follow the same classification and identifier rules as the UI **so that** bulk-created merchandise behaves consistently.

#### Acceptance criteria

- Ordinary imports cannot assign product primary identifiers; new products always receive generated `222` identifiers.
- Existing products are located by `222` primary identifier, unambiguous product industry identifier, variant SKU, or variant industry identifier. `product_lookup_code` locates a product only when exactly one product matches; multiple matches fail the group.
- Imports support `product_industry_identifier` and `product_lookup_code`; lookup codes are normalized; duplicate lookup codes across products are allowed on write.
- Product and variant industry identifiers use the same GTIN normalizer as the UI.
- Variant inventory mode, pricing method, margin, and supplier returnability use explicit input or class defaults at creation.
- Blank tax override means inherit the class default; an explicit tax class code stores an override.
- Omitted boolean input is distinguished from explicit `false`.
- Class references use unambiguous stable codes.
- Import errors identify the affected row or group and explain remediation.

### F2 — Rebuild catalog fixtures for the new model

**As a developer,** I want seeds, factories, and tests rewritten for the final schema **so that** CI does not depend on disposable legacy rows.

#### Acceptance criteria

- No application code reads removed columns.
- Seeds and tests create classes with a single parent department and class numbers.
- Product factories generate `222` primaries and do not offer `identifier_mode`.
- Product factories may set industry identifier through the registry-aware path.
- Variant factories persist operational fields and optional tax override; they do not set `department_id` or legacy `tax_class_id`.
- `db/schema.rb`, CSV documentation, and this planning packet match the implemented schema.

---

## Technical enablers

### T1 — Centralize variant behavior reads

Use variant columns for persisted inventory mode, pricing method, target margin, and supplier returnability. Use `effective_tax_class` for tax. Resolve department through `merchandise_class.department`. Repository-wide search must clear leftover reads of `merchandise_class.inventory_mode` / `pricing_method` and of `tax_class_id` as if it were the resolved tax class.

### T2 — Split matching from eligibility

Shared identifier matching returns unit, variant, product, `multiple_products`, `retired`, `not_found`, or `invalid` without POS `sellable?` filtering. POS, returns, inventory adjustments, and admin lookup each apply their own eligibility after a match.

### T3 — Enforce lookup-code canonical storage

Application normalization, a **nonunique** partial index, and a database check ensuring a stored lookup code is either null or equal to its trimmed uppercase representation.

### T4 — Extend the identifier registry

Add `product_industry` ownership while preserving unique active identifier values, owner/kind consistency, retirement, atomic reservation, and collision handling across products, variants, and inventory units.

### T5 — Snapshot effective tax at transaction time

Verify POS line snapshots retain the effective tax class, components/rates, taxable basis, and calculated amounts after configuration changes.

---

## Suggested delivery order

1. Slice A: A1–A3, B1–B6, C1, F2 (classification), T1, T5.
2. Slice B: D1–D4, E1–E5, F1, T2, T3, T4.

---

## Deferred

Not in Phase 6.1. Track later only if a real catalog requires them:

- GL mappings on merchandise classes (reopen **before** journal posting if two classes in one department need different posting accounts).
- Multiple lookup codes per product.
- Controlled bulk reclassification UI.
- Expand/contract production migrations and pre-6.1 schema upgrade tests.
- Rejecting lookup codes that equal a registry `value` (retirement already wins on scan).

---

## Definition of done

- Acceptance criteria above have automated coverage at the appropriate level.
- Existing POS product/variant/unit resolution tests remain green, plus product-selection tests for shared lookup codes and product-industry GTIN.
- Matcher tests distinguish registry absent, active, and retired.
- Administrative copy distinguishes copied variant defaults from inherited tax class.
- Audit events cover required configuration and identity changes.
- Planning and schema documentation match the implementation.
