# Phase 6.1 — Merchandise classification and identifiers

Status: **proposed**. Data is disposable; this packet does not require backward compatibility with the Phase 2–6 schema.

| Document | Purpose |
|---|---|
| [phase6.1-plan.md](phase6.1-plan.md) | Scope, locked decisions, behavior, delivery slices, tests, acceptance |
| [phase6.1-schema.md](phase6.1-schema.md) | Target tables, fields, and constraints |
| [phase6.1-user-stories.md](phase6.1-user-stories.md) | Issue backlog and acceptance criteria |

Earlier drafts under `docs/drafts/merchandise-classification-and-identifers/` described a larger expand/contract refactor (live tax inheritance, product-level GTIN, class-level GL, staged column drops). This packet keeps **lookup codes and POS/inventory targeting** (including shared codes and product selection). It still defers live tax inheritance, product-level GTIN, class-level GL, and production dual-write.
