# Product variant attributes — choice packet

**Program name:** Product variant attributes (not a numbered domain phase; not UDS-6, UDS-7, or UDS-8)

**Status:** **Accepted.** Accepting this packet accepts PVA-001–PVA-014. Reopening any choice requires a documentation change in the same PR (or a preceding docs PR) and an explicit callout in review.

Companion: [README.md](README.md).

## Why this packet

ShelfSense already stores up to two product attribute labels and corresponding variant values. Variants are used mainly as Standard vs Used (condition). Staff cannot rely on those fields: labels are unconstrained, values are optional, names are independently editable, duplicate type/condition/attribute combinations are allowed, POS and receipts ignore option values, and Inherit appears for sticky copies.

This packet makes the existing capability operable. It does not add `supports_attributes`, a product subtype, or bulk variant generation.

Today `Products::Create` does **not** create a Standard variant. Staff add variants separately. This packet must not introduce an incomplete auto-created Standard for attributed Products.

## Locked choices (PVA-001–PVA-014)

### PVA-001 — Source of truth, surfaces, and Product create

**Accepted.** Keep existing columns. No new product type. Used inventory units remain individually tracked members of a Used Product Variant grouping.

| Owner | Fields |
|---|---|
| Product | `variant_option_name_1`, `variant_option_name_2` (labels) |
| Product Variant | `option_value_1`, `option_value_2` (values); `name` as persisted **projection**; `variant_type`; `merchandise_condition_id`; sticky operational copies and `tax_class_override_id` unchanged from Phase 6.1 |

**Product create workflow:**

- Unattributed Product (no labels): remain Product-only on create. Do not introduce auto Standard-variant creation.
- Attributed Product (one or more labels): do not create an incomplete Standard or any other placeholder variant. After Product create, redirect staff to create the first complete attributed variant (New Product Variant for that Product).
- Nested initial-variant create on the Product form is **not** in current ShelfSense and is **not** required for MVP. If a later amendment adds it, it must collect complete attribute values and create a complete Standard variant in the same transaction — never an incomplete placeholder.

This program updates surfaces that already select or display a Product Variant. It does not convert Product-only search results into variant-level results. POS or administrative selectors that already return variants must use the new display label.

Implementation (later) writable production includes product and variant models, create/update services, `sellable?`, admin product/variant forms, POS freeze snapshot, receipt/POS/admin labels, schema default for status, and tests. It does **not** migrate Product index, bibliographic review, or catalog search into variant-level results.

### PVA-002 — Attribute labels

**Accepted.** A product is attributable only through populated labels.

| Configuration | Behavior |
|---|---|
| Neither label populated | Not attributable |
| Attribute 1 only | One attribute |
| Attribute 1 and Attribute 2 | Two attributes |
| Attribute 2 without Attribute 1 | Invalid |

Rules:

- Labels are optional. Attribute 2 cannot be stored without Attribute 1.
- Trim before validation and storage. Retain entered capitalization for display.
- The two labels cannot be duplicates after case and whitespace normalization.
- Configured order is significant: Attribute 1 always precedes Attribute 2 in forms, names, search, POS, and receipts.
- Configuring labels does not create variants. The MVP continues to create variants individually.

UI (Product form): a **Variant attributes** section containing Attribute 1 label and Attribute 2 label. No extra explanatory copy. Use the existing columns; do not label the inputs “Variant option name 1”.

### PVA-003 — Structural label changes (MVP)

**Accepted.** Renaming a populated slot (for example `Colour` → `Color`) is allowed; it does not change stored variant values.

Adding or removing a slot is **rejected** if the product already has any product variants. Do not silently discard `option_value_*`.

**Practical consequence:** for MVP, attributes can be configured only before the Product has any variants. Existing Products that already contain variants cannot become attributable through the UI. Conversion support for Products with variants (with or without operational history) is deferred. A later controlled operation may allow adding a slot when every existing variant receives a value in the same transaction, or removing a slot only when no variant holds a value for it and the change cannot collapse logical identities — that work is out of this packet.

Completed POS, inventory, and purchasing facts are not rewritten (ADR-012 / ADR-013).

### PVA-004 — Variant form context and type fields

**Accepted.** The Product Variant form is driven by the parent Product, selected variant type, configured attributes, assigned merchandise category, effective merchandise class, available class defaults, and persisted inheritance state when editing. Fields that cannot apply must not appear.

Compact read-only product context near the top (operational, not help text):

- Product name
- Primary identifier
- Merchandise category, or `No category assigned`
- Effective merchandise class, or `No merchandise class assigned`

Example:

```text
Logo Tee
1234567890123
Category: Branded Apparel
Class: Apparel
```

**Standard:** do not display Condition; do not persist `merchandise_condition_id` (existing CHECK stands). Display configured attribute value fields.

**Used:** display Condition and require a valid condition. Display configured attribute value fields. Other Used rules remain as established (class `used_merchandise_allowed`, inventory mode, individual units).

On create, changing type must update visible fields immediately (PVA-010). Switching unsaved Used → Standard removes Condition from the form, disables it, clears its unsaved value, and must not persist a condition. Switching back to Used shows and enables Condition **without** restoring the cleared value; staff must select again. Changing type on a persisted variant with operational history remains subject to existing lifecycle restrictions.

Server-side validation is authoritative regardless of which fields were visible.

### PVA-005 — Attribute values, completeness, and uniqueness

**Accepted.**

| Product labels | Variant fields |
|---|---|
| None | No attribute-value inputs |
| Attribute 1 only | Value for slot 1, labeled with the product’s Attribute 1 text |
| Both | Both values, labeled with the product’s texts |

Rules:

- Inputs use the product’s configured labels, never “Attribute 1 Value”.
- When the Product has configured attributes, every Product Variant must contain trimmed values for **all** configured slots before it can be **persisted**. MVP does not support incomplete attributed Product Variant records.
- `active` remains separate from sellability because other conditions may still prevent sale; it is not used to permit missing required attributes.
- A variant cannot persist a value for an unconfigured slot (store `NULL`).
- Values retain entered capitalization. Duplicate comparison is case-insensitive and whitespace-normalized (collapse repeated internal whitespace consistently with existing normalization conventions).

Logical identity (unique per product):

- `product_id`
- `variant_type`
- Condition identity (Standard’s absent condition treated consistently as absent)
- Normalized Attribute 1 value (when configured; otherwise absent)
- Normalized Attribute 2 value (when configured; otherwise absent)

Uniqueness applies to the Product Variant grouping. It does not prevent multiple Used inventory units on the same Used variant. Preserve staff-entered display values; compare a normalized representation.

Database implementation:

- Use stored normalized columns or an equivalent stable database expression.
- Use `NULLS NOT DISTINCT` (or an equivalent construction) so absent values do not permit duplicate unattributed Standard variants.
- Audit existing duplicates before creating the constraint. Fail the migration with an actionable report rather than choosing which duplicate survives.
- Retain application validation for useful form errors.
- Treat the database constraint as the concurrency authority.

### PVA-006 — Derived variant name

**Accepted.** One shared composer. Staff cannot save an independently conflicting `name`. The `name` column is a persisted projection of type, condition, and attribute values.

| Type | Attributes | Derived name |
|---|---|---|
| Standard | None | `Standard` |
| Standard | One | `{Attribute 1 value}` |
| Standard | Two | `{Attribute 1 value} / {Attribute 2 value}` |
| Used | None | `{Condition}` |
| Used | One | `{Condition} · {Attribute 1 value}` |
| Used | Two | `{Condition} · {Attribute 1 value} / {Attribute 2 value}` |

Used condition appears first. The name updates whenever type, condition, or configured values change.

Every operation that can change a contributing value must refresh affected projections, including renaming a merchandise-condition **display name**. Direct database updates that bypass the composer are not supported. (Alternatively, a later accepted choice may make condition labels immutable after use; until then, refresh projections.)

Implementation must audit current custom / non-composer `name` values before backfill. Replacing those names may affect exports, integrations, or staff workflows even though editable naming was never intended. Reports and exports use the complete string.

### PVA-007 — Product and variant display

**Accepted.** When a surface must identify both: `{Product name} — {Variant name}`. When the product is already unambiguous, show only the derived variant name.

This applies to surfaces that already select or display a Product Variant (Product show variants table, variant lists, POS pickers that return variants, basket/inventory/request/purchasing lines that already name a variant, receipts via PVA-008). It does not redesign Product-only search into variant-level results.

Long values are not shortened in persisted data. Full management surfaces may wrap. Compact interactive surfaces may visually truncate. Visual truncation must not truncate the underlying text exposed to assistive technology: preserve the complete accessible name or description. A `title` attribute may supplement this but is not sufficient by itself. If CSS ellipsis is applied to complete DOM text, the accessible name may already remain complete without an additional ARIA attribute. Do **not** introduce a tooltip primitive or icon library.

Priority on transactional surfaces: product name, variant identity, quantity, price.

### PVA-008 — Receipts and freeze snapshots

**Accepted.** Extend current Used-condition receipt **detail**, do not invent a receipt-only naming system. Product title on the receipt remains the product name (not `variant.name`).

Receipt **detail** line (not the title):

| Type | Attributes | Detail |
|---|---|---|
| Standard | None | Omit the detail line (do not print `Standard`) |
| Standard | One or two | Same string as the derived name |
| Used | None | `{Condition}` (no `Used ` prefix) |
| Used | One or two | Same string as the derived name |

Additional rules:

- Print attributes for Standard and Used when present, in product-configured order.
- Do not print labels such as `Size:`.
- Use the same delimiters as PVA-006.
- Wrap long detail lines rather than omitting condition or attributes.
- Original receipts and reprints use transaction-time facts.

**Snapshot:** compose and freeze `variant_detail` **independently** from the persisted `product_variants.name`, even though both use the same composer rules. The receipt renderer reads only the frozen snapshot or the historical fallback — never live `variant.name` after the sale. Keep existing `condition_name` / `condition_code` / `unit_identifier` / `description` (product name) on the snapshot. Linked return and post-void continue to copy the original snapshot.

This **amends** [receipts-and-reports-revamp/content-contract.md](../receipts-and-reports-revamp/content-contract.md) in the implementation PR. New snapshots use the table above. Historical lines without `variant_detail` keep the exact legacy output (`Used {condition_name}` or code fallback) so old receipts do not change.

### PVA-009 — Inheritance vs sticky defaults

**Accepted.** Do not reopen Phase 6.1 locked decisions 4–5. Merchandise **category** only suggests default merchandise classes. True live inherit is **tax class** only: `tax_class_override_id IS NULL` → `merchandise_class.default_tax_class`.

Sticky create-time copies (explicit after save; **no** `Inherit` option): `inventory_mode`, `pricing_method`, `target_margin_bps`, `supplier_returnable`, and merchandise class when resolved from category defaults at create.

Form rules:

- Offer `Inherit — {effective tax class}` whenever the Product Variant has an effective merchandise class whose default tax class is populated. Category assignment by itself neither enables nor disables tax inheritance.
- Do not offer Inherit when there is no effective class, or the class has no default tax class; require an explicit tax class (and an explicit class if none is resolved).
- Do not label a system fallback as inherited.
- Do not relabel an explicit value as inherited because it equals the current default.
- Product context shows category and effective class (PVA-004); do not repeat those names inside every Inherit option.
- On edit, show persisted state. If an inherited tax source is no longer valid, do not silently pick another; the user must resolve it before saving other changes to that variant.

### PVA-010 — Form refresh and server authority

**Accepted.** Conditional fields update immediately when variant type changes. Prefer a **full server round-trip** on type change (GET/POST redisplay). If that is too coarse for create UX, a **small deliberate Stimulus controller owned by this packet** is allowed — Admin has no established form-controller pattern for this, so do not claim one. Do not use CSS `:has()` alone to pretend to clear, disable, or restore Condition.

When Standard is selected: hide and disable Condition and clear its unsaved value. When Used is selected: enable and show Condition without restoring a cleared value.

A no-JavaScript path must remain valid via round-trip redisplay. Hidden, disabled, or stale browser fields are not authority. `ProductVariants::Create` / `Update` re-evaluate on submit: product labels, category, class defaults, variant type, condition applicability, attribute completeness, duplicate identity, permitted status. Clear condition for Standard. Reject values for unconfigured slots.

### PVA-011 — APF Product forms

**Accepted.** Reopen [product-show.md](../admin-page-frame/product-show.md) PS-006 for **field semantics**, not chrome. Keep `wide`. Move option labels out of Identity into **Variant attributes**. Do not put a show overview or editorial grid on the form. Product-show overview may omit blank attribute labels; it is not a second naming system. APF composition tests that list Product form section titles gain **Variant attributes** in the implementation PR.

### PVA-012 — Default lifecycle status

**Accepted.** New Products and Product Variants default to `active` when status is omitted, in:

- New Product / New Product Variant forms
- Model construction outside the HTML form
- `Products::Create`, `ProductVariants::Create`, and nested or bibliographic-candidate Product creation
- Imports and any other create service that currently supplies `draft` implicitly
- Test factories and fixtures where status is intentionally omitted (inventory those paths before changing the DB default)

Also agree the database column default with application initialization. Explicit valid status wins.

**Blank handling:** omitted status defaults to `active`. A blank submitted status is normalized to omission or rejected consistently before persistence; it must not rely accidentally on the database default, because an explicit `NULL` does not necessarily invoke that default.

Existing rows are **not** backfilled. Product status and variant status remain independent. `active` does not bypass `sellable?` or attribute completeness (PVA-005).

### PVA-013 — Tests (implementation PR)

**Accepted.** Cover at the lowest useful level and at the request/POS boundary:

- Label validation (Attribute 2 without 1; duplicate normalized labels; trim)
- Structural add/remove rejected when variants exist; rename allowed; Products with no variants / with variants / with operational history behave per PVA-003
- Attributed Product create does not create an incomplete default Standard; unattributed Product create remains Product-only; first attributed variant defaults to `active`
- Condition required/forbidden by type (app + existing CHECK)
- Switching Used → Standard clears and disables Condition; switching Standard → Used does not restore the prior unsaved Condition
- Attribute fields and labels; values required on **persistence**, not only in `sellable?`; illicit values rejected
- Duplicate normalized identity rejected (two unattributed Standards; case-only attributed clash; same Used condition+attrs; different conditions OK; concurrent insert)
- Database migration detects preexisting normalized duplicates and fails with a report
- Name composer for all six rows in PVA-006; name not independently editable; condition rename refreshes projections (or documents immutability)
- Product context shows category and effective merchandise class
- Tax inheritance with effective class and no category (if permitted); category without effective class does not offer Inherit; sticky fields have no Inherit
- Status default `active` on all non-form omitted create paths; blank submission handling; existing fixtures unchanged unless intentionally omitted-status paths are updated
- Receipt: new snapshots print `variant_detail` composed independently of live name; Standard with no attributes omits detail; linked returns and post-voids retain original `variant_detail`; historical snapshots without `variant_detail` preserve exact legacy `Used {condition}` output
- APF Product form section list; frozen Product UX/enrichment/inventory suites stay green
- POS picker / basket surfaces that already return variants use the new display label

Always run `./dev/rails-docker bin/ci` before handoff.

### PVA-014 — Compatibility

**Accepted.** Existing products with blank labels remain non-attributable. Unattributed Standard variants remain named `Standard`; unattributed Used variants remain named from condition. Do not broadly change statuses to `active`. Inconsistent existing attribute/condition/name data is reported or remediated deliberately, not silently discarded.

## Forbidden

- Attribute matrix or bulk variant generation
- A second product model or change to Used-unit identity
- Auto-creating an incomplete Standard (or any placeholder) when attribute labels are configured
- Nested Product+variant create that leaves incomplete attributed variants
- Copying this form grammar onto other families
- Reopening APF-003 widths, Product index, bibliographic review, or catalog search into variant-level results
- Changing Phase 6.1 sticky-vs-live tax rules
- Recalculating historical receipts from current catalog
- Defaulting existing records to `active`
- Phosphor, a new tooltip primitive, description clamp, or CSS-only Condition state mutation
- Incidental Admin Hotwire outside the deliberate PVA-010 round-trip or owned Stimulus choice

## Implementation bar

- [x] Packet Accepted and pointers updated
- [x] Attribute labels, values, persistence completeness, uniqueness (audit + constraint), `sellable?`, derived name projection and backfill
- [x] Product create redirect for attributed Products; no incomplete auto variants
- [x] Variant form context (category + class), type/attribute conditionality, inheritance UX
- [x] Status defaults (forms, services, DB, inventoriable create paths) without backfill
- [x] POS snapshot `variant_detail` and receipt grammar amendment
- [x] Tests and `./dev/rails-docker bin/ci` green
