# Product variant attributes — choice packet

**Program name:** Product variant attributes (not a numbered domain phase; not UDS-6, UDS-7, or UDS-8)

**Status:** **Proposed.** Accepting this packet accepts PVA-001–PVA-014. Reopening any choice requires a documentation change in the same PR (or a preceding docs PR) and an explicit callout in review.

Companion: [README.md](README.md).

## Why this packet

ShelfSense already stores up to two product attribute labels and corresponding variant values. Variants are used mainly as Standard vs Used (condition). Staff cannot rely on those fields: labels are unconstrained, values are optional, names are independently editable, duplicate type/condition/attribute combinations are allowed, POS and receipts ignore option values, and Inherit appears for sticky copies.

This packet makes the existing capability operable. It does not add `supports_attributes`, a product subtype, or bulk variant generation.

## Locked choices (PVA-001–PVA-014)

### PVA-001 — Source of truth and surfaces

**Proposed.** Keep existing columns. No new product type. Used inventory units remain individually tracked members of a Used Product Variant grouping.

| Owner | Fields |
|---|---|
| Product | `variant_option_name_1`, `variant_option_name_2` (labels) |
| Product Variant | `option_value_1`, `option_value_2` (values); `name` as persisted **projection**; `variant_type`; `merchandise_condition_id`; sticky operational copies and `tax_class_override_id` unchanged from Phase 6.1 |

Implementation (later) writable production includes product and variant models, create/update services, `sellable?`, admin product/variant forms, POS freeze snapshot, receipt/POS/admin labels, schema default for status, and tests. It does **not** migrate Product index, bibliographic review, or catalog search except where a search result already names a variant.

### PVA-002 — Attribute labels

**Proposed.** A product is attributable only through populated labels.

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

**Proposed.** Renaming a populated slot (for example `Colour` → `Color`) is allowed; it does not change stored variant values.

Adding or removing a slot is **rejected** if the product already has any product variants. Do not silently discard `option_value_*`. A full conversion workflow is deferred.

Completed POS, inventory, and purchasing facts are not rewritten (ADR-012 / ADR-013).

### PVA-004 — Variant form context and type fields

**Proposed.** The Product Variant form is driven by the parent Product, selected variant type, configured attributes, assigned merchandise category, available class defaults, and persisted inheritance state when editing. Fields that cannot apply must not appear.

Compact read-only product context near the top (operational, not help text):

- Product name
- Primary identifier
- Assigned merchandise category, or `No category assigned`

**Standard:** do not display Condition; do not persist `merchandise_condition_id` (existing CHECK stands). Display configured attribute value fields.

**Used:** display Condition and require a valid condition. Display configured attribute value fields. Other Used rules remain as established (class `used_merchandise_allowed`, inventory mode, individual units).

On create, changing type must update visible fields immediately (PVA-010). Switching unsaved Used → Standard removes Condition from the form and must not persist a condition. Switching back requires a new condition selection. Changing type on a persisted variant with operational history remains subject to existing lifecycle restrictions.

Server-side validation is authoritative regardless of which fields were visible.

### PVA-005 — Attribute values, completeness, and uniqueness

**Proposed.**

| Product labels | Variant fields |
|---|---|
| None | No attribute-value inputs |
| Attribute 1 only | Value for slot 1, labeled with the product’s Attribute 1 text |
| Both | Both values, labeled with the product’s texts |

Rules:

- Inputs use the product’s configured labels, never “Attribute 1 Value”.
- Every configured attribute requires a trimmed value before the variant is complete and **sellable**. Lifecycle `active` does not bypass completeness (`sellable?` stays distinct from status).
- A variant cannot persist a value for an unconfigured slot (store `NULL`).
- Values retain entered capitalization. Duplicate comparison is case-insensitive and whitespace-normalized (collapse repeated internal whitespace consistently with existing normalization conventions).
- Temporary incomplete rows during a deferred conversion are out of MVP; incomplete attributed variants must not be presented as sellable.

Logical identity (unique per product):

- Variant type
- Condition, when Used
- Attribute 1 value, when configured
- Attribute 2 value, when configured

Uniqueness applies to the Product Variant grouping. It does not prevent multiple Used inventory units on the same Used variant. Preserve staff-entered display values; compare a normalized representation. Implementation uses a database uniqueness constraint (NULL-safe) plus application validation.

### PVA-006 — Derived variant name

**Proposed.** One shared composer. Staff cannot save an independently conflicting `name`. If `name` remains a column, it is maintained as a projection of type, condition, and attribute values.

| Type | Attributes | Derived name |
|---|---|---|
| Standard | None | `Standard` |
| Standard | One | `{Attribute 1 value}` |
| Standard | Two | `{Attribute 1 value} / {Attribute 2 value}` |
| Used | None | `{Condition}` |
| Used | One | `{Condition} · {Attribute 1 value}` |
| Used | Two | `{Condition} · {Attribute 1 value} / {Attribute 2 value}` |

Used condition appears first. The name updates whenever type, condition, or configured values change. Implementation backfills existing `name` values to this rule. Reports and exports use the complete string.

### PVA-007 — Product and variant display

**Proposed.** When a surface must identify both: `{Product name} — {Variant name}`. When the product is already unambiguous, show only the derived variant name.

Long values are not shortened in persisted data. Full management surfaces may wrap. Compact interactive surfaces may visually truncate; the full string remains available via accessible text (`title` and/or `aria-label`) on that control. Do **not** introduce a tooltip primitive or icon library.

Priority on transactional surfaces: product name, variant identity, quantity, price.

### PVA-008 — Receipts and freeze snapshots

**Proposed.** Extend current Used-condition receipt **detail**, do not invent a receipt-only naming system. Product title on the receipt remains the product name (not `variant.name`).

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

**Snapshot:** freeze `variant_detail` (the detail string above) on `merchandise_snapshot` at sale/return freeze, keeping existing `condition_name` / `condition_code` / `unit_identifier` / `description` (product name). Reprints must not re-read live product or variant configuration. Linked return and post-void continue to copy the original snapshot.

This **amends** [receipts-and-reports-revamp/content-contract.md](../receipts-and-reports-revamp/content-contract.md) in the implementation PR. Today’s print of `Used {condition_name}` is replaced by the table above for **new** snapshots. Historical lines without `variant_detail` keep today’s fallback (`Used {condition_name}` or code) so old receipts do not change.

### PVA-009 — Inheritance vs sticky defaults

**Proposed.** Do not reopen Phase 6.1 locked decisions 4–5. Merchandise **category** only suggests default merchandise classes. True live inherit is **tax class** only: `tax_class_override_id IS NULL` → `merchandise_class.default_tax_class`.

Sticky create-time copies (explicit after save; **no** `Inherit` option): `inventory_mode`, `pricing_method`, `target_margin_bps`, `supplier_returnable`, and merchandise class when resolved from category defaults at create.

Form rules:

- Show `Inherit — {effective tax class}` only when a class default tax class exists.
- Do not offer Inherit when there is no class, or the class has no default tax class; require an explicit tax class (and an explicit class if none is resolved).
- Do not label a system fallback as inherited.
- Do not relabel an explicit value as inherited because it equals the current default.
- Product context shows category or `No category assigned`; do not repeat the category name inside every Inherit option.
- On edit, show persisted state. If an inherited tax source is no longer valid, do not silently pick another; the user must resolve it before saving other changes to that variant.

### PVA-010 — Form refresh and server authority

**Proposed.** Conditional presentation responds when variant type changes. Admin remains server-rendered. Prefer native radios (or a select plus round-trip) and CSS `:has()` so Condition appears only for Used. Do not add Stimulus or incidental Hotwire unless a later accepted choice says so.

Hidden or stale submitted fields are not authority. `ProductVariants::Create` / `Update` re-evaluate on submit: product labels, category, class defaults, variant type, condition applicability, attribute completeness, duplicate identity, permitted status. Clear condition for Standard. Reject values for unconfigured slots.

### PVA-011 — APF Product forms

**Proposed.** Reopen [product-show.md](../admin-page-frame/product-show.md) PS-006 for **field semantics**, not chrome. Keep `wide`. Move option labels out of Identity into **Variant attributes**. Do not put a show overview or editorial grid on the form. Product-show overview may omit blank attribute labels; it is not a second naming system. APF composition tests that list Product form section titles gain **Variant attributes** in the implementation PR.

### PVA-012 — Default lifecycle status

**Proposed.** New Products and Product Variants default to `active` in the New forms, create services (when status is omitted), and the database column default. Explicit valid status wins. A submitted blank must not persist an invalid state. Existing rows are **not** backfilled. Product status and variant status remain independent. `active` does not bypass `sellable?`.

### PVA-013 — Tests (implementation PR)

**Proposed.** Cover at the lowest useful level and at the request/POS boundary:

- Label validation (Attribute 2 without 1; duplicate normalized labels; trim)
- Structural add/remove rejected when variants exist; rename allowed
- Condition required/forbidden by type (app + existing CHECK)
- Attribute fields and labels; values required for sellable; illicit values rejected
- Duplicate normalized identity rejected (including concurrent uniqueness)
- Name composer for all six rows in PVA-006; name not independently editable
- Inherit only for tax when a class default exists; sticky fields have no Inherit
- Status default `active` on omitted create paths; existing fixtures unchanged
- Receipt: new snapshots print `variant_detail`; Standard with no attributes omits detail; reprints do not follow later catalog edits; pre-change snapshots keep `Used {condition}` fallback
- APF Product form section list; frozen Product UX/enrichment/inventory suites stay green
- POS picker / basket surfaces distinguish attributed variants

Always run `./dev/rails-docker bin/ci` before handoff.

### PVA-014 — Compatibility

**Proposed.** Existing products with blank labels remain non-attributable. Unattributed Standard variants remain named `Standard`; unattributed Used variants remain named from condition. Do not broadly change statuses to `active`. Inconsistent existing attribute/condition data is reported or remediated deliberately, not silently discarded.

## Forbidden

- Attribute matrix or bulk variant generation
- A second product model or change to Used-unit identity
- Copying this form grammar onto other families
- Reopening APF-003 widths, Product index, bibliographic review, or catalog search (except variant naming where a result already names a variant)
- Changing Phase 6.1 sticky-vs-live tax rules
- Recalculating historical receipts from current catalog
- Defaulting existing records to `active`
- Phosphor, a new tooltip primitive, description clamp, or Stimulus on these admin forms unless PVA-010 is superseded

## Implementation bar

Unchecked until an **Accepted** packet is implemented.

- [ ] Packet Accepted and pointers updated
- [ ] Attribute labels, values, uniqueness, `sellable?`, derived name projection and backfill
- [ ] Variant form context, type/attribute conditionality, inheritance UX
- [ ] Status defaults (forms, services, DB) without backfill
- [ ] POS snapshot `variant_detail` and receipt grammar amendment
- [ ] Tests and `./dev/rails-docker bin/ci` green
