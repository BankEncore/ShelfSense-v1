# Product variant attributes

**Program name:** Product variant attributes (not a numbered domain phase; not UDS-6, UDS-7, or UDS-8)

**Status:** **Accepted.** Implemented on feature branch `product-variant-attributes-impl` (PR targeting `main`).

Companions: [plan.md](plan.md) (PVA-001–PVA-014). Authority this packet does not reopen: [Phase 6.1](../phase6.1-merchandise-classification-and-identifiers/README.md) (sticky operational copies vs live tax), [Admin Page Frame Product show](../admin-page-frame/product-show.md) (chrome at `wide`; this packet reopens form **semantics** only), [Receipts and reports content contract](../receipts-and-reports-revamp/content-contract.md) (thermal authority; implementation amends merchandise detail grammar).

The columns already exist (`products.variant_option_name_1` / `variant_option_name_2`, `product_variants.option_value_1` / `option_value_2`, nullable `product_variants.name`, status default `"draft"`). What is missing is authority: validations, uniqueness, derived names, sellability, form grammar, POS/receipt snapshots, and creation-time status defaults.

This is a focused merchandise correction in the spirit of Phase 6.1. It does not introduce a second product model, change the Product → Product Variant → Used inventory unit relationship, or generate an attribute matrix. Product create remains Product-only today; attributed Products must not leave an incomplete auto Standard.

## Deliverable

> Authorized staff can configure up to two ordered product attribute labels (before variants exist), create distinguishable Standard and Used variants whose names and receipt details follow a shared composition rule, see only applicable variant fields and true class-based inheritance, and have new products and variants default to active — without a second product model, an attribute matrix, or incomplete placeholder variants.

## Document map

| Document | Purpose |
|---|---|
| [plan.md](plan.md) | Locked choices PVA-001–PVA-014, forbidden list, later implementation bar |

## Later amend targets (implementation PR, not this packet)

When Accepted, the implementing change must update these contracts in the same PR as behavior:

- [receipts-and-reports-revamp/content-contract.md](../receipts-and-reports-revamp/content-contract.md) — merchandise detail line (drop `Used ` prefix; print derived variant-detail; wrap; snapshot `variant_detail`)
- [admin-page-frame/product-show.md](../admin-page-frame/product-show.md) PS-006 — Product `_form` section list gains **Variant attributes**; variant new/edit field semantics
- Phase 2 schema notes for option labels/values and status defaults (descriptive; schema already has the columns)

## Next action

Accept [plan.md](plan.md) (or amend it) before any application code. Implementation is a separate PR after **Accepted**.
