# Phase 6.1 — Merchandise classification and identifiers

Status: **accepted / implemented** on branch `phase-6.1-classification-and-identifiers` (PR toward `main`). Data was disposable; this packet did not require backward compatibility with the Phase 2–6 schema.

| Document | Purpose |
|---|---|
| [phase6.1-plan.md](phase6.1-plan.md) | Scope, locked decisions, behavior, delivery slices, tests, acceptance |
| [phase6.1-schema.md](phase6.1-schema.md) | Target tables, fields, and constraints |
| [phase6.1-user-stories.md](phase6.1-user-stories.md) | Issue backlog and acceptance criteria |

This packet includes live tax inheritance with a variant override, product-level industry GTIN (`product_industry`), lookup codes (including shared codes and product selection), and POS/inventory targeting with matching separated from caller eligibility.

**Supersession:** For merchandise classification and product identity, this packet supersedes the Phase 2 blanket rule that *all* approved classifications are stored on the variant and never dynamically inherited. **Tax class is the exception:** it is dynamically inherited from the merchandise class unless a variant tax override is set. Inventory mode, pricing method, target margin, and supplier returnability remain copied at create and sticky. See [phase6.1-plan.md](phase6.1-plan.md) locked decisions 4–5.

It still defers class-level GL mappings (with an explicit posting trigger), production dual-write, and a bulk reclassification UI. Earlier drafts under `docs/drafts/merchandise-classification-and-identifers/` that assumed expand/contract migration are not implementation authority.
