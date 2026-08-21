# Phase 6.1 — User stories

Status: **proposed** backlog for [phase6.1-plan.md](phase6.1-plan.md). Acceptance criteria must not be weakened if a story is split across PRs.

Existing product, variant, inventory-unit, and POS resolution behavior (unit → variant → product → variant choice → unit choice) is a regression boundary. This backlog **adds** product selection only when a lookup code matches multiple products; after that, the established flow resumes.

Stories dropped from the earlier draft (live tax inheritance, product-level GTIN, class-level GL, staged migration) are listed under [Deferred](#deferred).

---

## Epic A — Department and subdepartment organization

### A1 — Maintain top-level departments

**As an administrator,** I want to maintain departments as reporting categories with accounting mappings **so that** financial configuration stays at the department level and the hierarchy stays understandable.

#### Acceptance criteria

- A department requires a department number, name, and key/code.
- Department number is unique across departments.
- Key/code is normalized, globally unique, and effectively immutable after creation.
- Department configuration exposes the existing GL mappings with current validation.
- Department configuration does not expose tax defaults or margin defaults.
- An administrator can activate or deactivate a department subject to lifecycle restrictions.
- A department with active merchandise classes cannot be deactivated.
- A department detail page identifies its child merchandise classes.
- Department changes are audited.

### A2 — Maintain merchandise classes as subdepartments

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

**As a merchandise administrator,** I want to configure operational defaults on a merchandise class **so that** new variants are created consistently.

#### Acceptance criteria

- A class includes default tax class, default inventory mode, default pricing method, optional target margin in basis points, and default supplier-returnable status.
- The class also records whether used merchandise and buyback are allowed.
- Default tax class must be active and assignable.
- Margin, when present, is an integer `0` through `9999` basis points (`< 10000`).
- Buyback cannot be enabled unless used merchandise is allowed and the class default inventory mode is inventory-capable.
- The form explains that these settings are copied to new variants and do not rewrite existing variants.
- Changes are audited.

### B2 — Persist operational defaults when creating a variant

**As a merchandise manager,** I want new variants to retain resolved inventory, pricing, margin, supplier-return, and tax settings **so that** later class-default changes do not alter existing merchandise.

#### Acceptance criteria

- Omitted inventory mode, pricing method, target margin, supplier returnability, and tax class are copied from the class at create.
- Explicitly supplied values take precedence.
- Explicit `false` supplier returnability is distinguished from an omitted value.
- Later changes to class defaults do not mutate existing variants.
- The variant detail page displays the persisted values, including tax class as the variant’s tax class (not an “override” control).
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

### B4 — Preserve historical sale calculations

**As a financial reviewer,** I want completed sales to retain the tax and pricing basis used at completion **so that** later merchandise configuration changes do not alter historical receipts.

#### Acceptance criteria

- Completed transaction lines retain the tax and pricing snapshots already required by POS completion.
- Changing class defaults does not change completed transaction data.
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

### D2 — Record manufacturer identifiers on variants

**As an inventory operator,** I want ISBN, UPC, and EAN values stored on the variant **so that** a scan targets the edition or format, not an ambiguous product.

#### Acceptance criteria

- A variant may have one optional industry identifier (existing field).
- ISBN-10, UPC-A, ISBN-13/EAN-13/GTIN-13 normalization and check-digit rules remain those of the shared identifier normalizer.
- The normalized identifier must not collide with an active product primary, variant SKU, other variant industry identifier, or inventory-unit identifier.
- Assignment, replacement, and retirement use the existing registry-aware variant industry-identifier path and are audited.
- Direct variant industry-identifier scans continue to resolve to that variant.

### D3 — Continue identifying variants and units in separate namespaces

**As an inventory operator,** I want variants and individually tracked units to retain distinct ShelfSense identifiers **so that** scans target the appropriate level of merchandise.

#### Acceptance criteria

- Every new variant receives a valid, unique `221`-prefixed SKU.
- Every new inventory unit receives a valid, unique `220`-prefixed identifier.
- Product, variant, and unit identifiers remain globally collision-free in the registry.
- Direct variant and unit scans continue through existing behavior.
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
- A valid active global identifier-registry match takes precedence over the same raw value used as a lookup code.
- If no active registry row matches, a numeric input may still be attempted as a lookup code.
- Letter-containing codes are not rejected as invalid GTINs before the lookup-code path runs.
- Prefix or name search does not silently add an item through exact scan/add behavior.

### E3 — Select a product when a lookup code is shared

**As a cashier,** I want to choose the intended product when a lookup code matches multiple products **so that** ShelfSense never adds an arbitrary item.

#### Acceptance criteria

- One lookup-code match enters the existing product-resolution flow without an unnecessary product chooser.
- Multiple lookup-code matches present a deterministic product-selection list.
- No handler automatically chooses the first product.
- Product choices contain enough identifying information (name, `222`, lookup code, other distinguishing fields) for the cashier to tell them apart.
- Selecting a product resumes the existing product-resolution flow.
- If the selected product has one eligible variant, existing single-variant behavior applies.
- If it has multiple eligible variants, the existing variant chooser appears.
- If the chosen variant is individually tracked, the existing inventory-unit chooser appears.
- Cancelling product selection does not add or reserve merchandise.

### E4 — Preserve direct product, variant, and unit targeting

**As a cashier,** I want existing identifier scans to behave as they do today **so that** lookup codes do not change checkout for GTIN/SKU/unit scans.

#### Acceptance criteria

- A direct inventory-unit identifier continues targeting that unit.
- A direct variant SKU or industry identifier continues targeting that variant.
- A direct product primary identifier continues entering the existing product-resolution path.
- Retired, invalid, and missing identifiers retain their existing outcomes.
- Lookup-code fallback occurs only when no active registry record matches.
- Existing store, sellability, availability, open-price, working-transaction, variant-choice, and unit-choice rules remain enforced.

### E5 — Target inventory adjustments without arbitrary matches

**As an inventory operator,** I want identifier entry on inventory adjustments to use the same lookup rules as POS **so that** a shared lookup code cannot post against the wrong variant.

#### Acceptance criteria

- Unit `220`, variant SKU, and variant industry identifier continue to select that unit’s variant or that variant.
- A unique lookup code or `222` primary with one eligible variant selects that variant.
- A unique lookup code or `222` with multiple variants requires a specific variant SKU (same idea as today’s multiple-variant rejection).
- A shared lookup code does not select the first matching product or variant.
- The operator either chooses among matching products or receives an error that names the ambiguity and asks for a more specific identifier.

---

## Epic F — Import and cutover

### F1 — Import merchandise under the new model

**As a merchandise administrator,** I want CSV import to follow the same classification and identifier rules as the UI **so that** bulk-created merchandise behaves consistently.

#### Acceptance criteria

- Ordinary imports cannot assign product primary identifiers; new products always receive generated `222` identifiers.
- Existing products are located by `222` primary identifier, variant SKU, or variant industry identifier when unambiguous. `product_lookup_code` locates a product only when exactly one product matches; multiple matches fail the group.
- Imports support `product_lookup_code`; values are normalized; duplicate codes across products are allowed on write.
- Variant industry identifiers use the same GTIN normalizer as the UI.
- Variant inventory mode, pricing method, margin, supplier returnability, and tax class use explicit input or class defaults at creation.
- Omitted boolean input is distinguished from explicit `false`.
- Class references use unambiguous stable codes.
- Import errors identify the affected row or group and explain remediation.

### F2 — Rebuild catalog fixtures for the new model

**As a developer,** I want seeds, factories, and tests rewritten for the final schema **so that** CI does not depend on disposable legacy rows.

#### Acceptance criteria

- No application code reads removed columns.
- Seeds and tests create classes with a single parent department and class numbers.
- Product factories generate `222` primaries and do not offer `identifier_mode`.
- Variant factories persist operational fields and tax class; they do not set `department_id`.
- `db/schema.rb`, CSV documentation, and this planning packet match the implemented schema.

---

## Technical enablers

### T1 — Centralize persisted variant behavior

Use variant columns (not live class reads) for inventory mode, pricing method, target margin, supplier returnability, and tax class. Resolve department through `merchandise_class.department`. Repository-wide search must clear leftover reads of `merchandise_class.inventory_mode` / `pricing_method` in POS, sellability, and tracking.

### T2 — Extend the lookup result contract

Preserve current lookup results and add `multiple_products` carrying product choices. Update POS sale, POS returns, Register workspace, admin merchandise lookup, and inventory-adjustment identifier entry so the new outcome cannot fall through to a generic error or arbitrary selection.

### T3 — Enforce lookup-code canonical storage

Application normalization, a **nonunique** partial index, and a database check ensuring a stored lookup code is either null or equal to its trimmed uppercase representation.

---

## Suggested delivery order

1. Slice A: A1–A3, B1–B4, C1, F2 (classification), T1.
2. Slice B: D1–D3, E1–E5, F1, T2, T3.

---

## Deferred

Not in Phase 6.1. Track later only if a real catalog requires them:

- Dynamically inherited tax class with variant override (`effective_tax_class`).
- Product-level industry identifier and `product_industry` registry kind.
- GL mappings on merchandise classes.
- Multiple lookup codes per product.
- Controlled bulk reclassification UI.
- Expand/contract production migrations and pre-6.1 schema upgrade tests.

---

## Definition of done

- Acceptance criteria above have automated coverage at the appropriate level.
- Existing POS product/variant/unit resolution tests remain green, plus product-selection tests for shared lookup codes.
- Administrative copy states that class defaults apply to new variants only.
- Audit events cover required configuration and identity changes.
- Planning and schema documentation match the implementation.
