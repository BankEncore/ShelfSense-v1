# UX design system

Status: **Proposed** (docs packet). Phase 2.2 visual tokens remain **implemented** until the foundation program ships. See [ADR-022](../../adr/ADR-022-warm-parchment-visual-tokens.md) (Proposed) for palette supersession.

This packet is the cross-phase authority for ShelfSense presentation: Warm Parchment visual direction, button and action semantics, surface contracts (Register basket vs history vs print), deferred interaction patterns, and an incremental adoption program.

It is **not** a Phase 7 slice. Phase 7 domain chrome boundaries stay in the [Phase 7 packet](../phase7-orders-and-receiving/README.md). Future phases (Buyback, reporting, and later) cite this packet for UX adoption targets.

## Governing principle

> Warm Parchment is one ShelfSense design system expressed through different shells—not one universal layout imposed on administration, purchasing operations, and the Register.

## Shell boundaries (unchanged)

| Shell | Role | Runtime |
|---|---|---|
| Administrative | Configuration, history, CRUD | Server-rendered Rails; no Hotwire on admin chrome |
| Purchasing ops | Location, draft PO, receiving | Register-class ops layout; Importmap + Turbo + Stimulus |
| Register | Cashier POS | Dedicated POS layout; Importmap + Turbo + Stimulus |
| Printed receipt | Customer/cashier print | Separate constrained presentation; see [surface-contracts.md](surface-contracts.md) |

Do not fold POS into a shared ops shell. Do not replace admin show pages with drawers as a default.

## Document map

| Document | Purpose | Authority |
|---|---|---|
| [program-plan.md](program-plan.md) | Adoption slices UDS-0–UDS-3, deferrals, acceptance | Proposed |
| [warm-parchment.md](warm-parchment.md) | Tokens, typography, density, contrast (AA baseline) | Proposed |
| [button-action-semantics.md](button-action-semantics.md) | Labels, intents, styles, sizes, review dialogs | Proposed |
| [surface-contracts.md](surface-contracts.md) | Basket, transaction history, printed receipt | Proposed |
| [deferred-patterns.md](deferred-patterns.md) | Drawers, global search, density prefs, etc. | Proposed (explicitly deferred) |
| [migration-matrix.md](migration-matrix.md) | Area status: legacy / partial / conforming / locked; UDS-0 path-level inventory | Working tracker |

Daily admin conventions remain in [ux-conventions.md](../../ux-conventions.md) until foundation implementation updates that file’s palette and points here for action semantics.

## Authority labels

Use these labels on mockups and related artifacts:

| Label | Meaning |
|---|---|
| **Inspirational** | Visual reference only; not binding |
| **Proposed** | Preferred direction; not yet accepted for implementation |
| **Accepted** | Binding for new work; may not yet be implemented everywhere |
| **Implemented** | Shipped in application code and conventions |

Draft mockups and Gemini images under [`docs/drafts/phase-7.1-ux-refactor/`](../../drafts/phase-7.1-ux-refactor/) are **inspirational**. That draft folder is **not** implementation authority.

## Relationship to Phase 2.2

Phase 2.2 established Propshaft tokens, shared partials/helpers, money UX, accessibility baseline, and shell architecture. This program **preserves that architecture** and proposes to **supersede the Phase 2.2 color palette** with Warm Parchment tokens ([ADR-022](../../adr/ADR-022-warm-parchment-visual-tokens.md)).

## Out of scope for this packet alone

Implementing CSS, migrating all screens, global search, master-detail drawers, or changing Register keyboard bindings. See [program-plan.md](program-plan.md) and [deferred-patterns.md](deferred-patterns.md).
