# Phase 6.1 — Merchandise classification and identifiers

Status: **proposed**. Data is disposable; this packet does not require backward compatibility with the Phase 2–6 schema.

| Document | Purpose |
|---|---|
| [phase6.1-plan.md](phase6.1-plan.md) | Scope, locked decisions, behavior, delivery slices, tests, acceptance |
| [phase6.1-schema.md](phase6.1-schema.md) | Target tables, fields, and constraints |
| [phase6.1-user-stories.md](phase6.1-user-stories.md) | Issue backlog and acceptance criteria |

This packet includes live tax inheritance with a variant override, product-level industry GTIN (`product_industry`), lookup codes (including shared codes and product selection), and POS/inventory targeting with matching separated from caller eligibility.

It still defers class-level GL mappings (with an explicit posting trigger), production dual-write, and a bulk reclassification UI. Earlier drafts under `docs/drafts/merchandise-classification-and-identifers/` that assumed expand/contract migration are not implementation authority.
