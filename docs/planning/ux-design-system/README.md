# UX design system

Status: **UDS-1 Implemented**; **UDS-2 Implemented** for reference screens; **UDS-3 Implemented** for Register visual refinement (basket hierarchy, shortcut groups, overlays) with ActionButtonHelper. Matrix rows remain **partial** until [accessibility-ergonomic-test-matrix.md](accessibility-ergonomic-test-matrix.md) evidence is attached. Phase 2.2 **architecture** remains; teal/plum palette superseded. Grouped admin navigation: UDS-4.0 gate **Passed**; **UDS-4.1 in progress**.

This packet is the cross-phase authority for ShelfSense presentation: Warm Parchment visual direction, button and action semantics, administrative navigation grouping, surface contracts (Register basket vs history vs print), deferred interaction patterns, and an incremental adoption program.

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
| [program-plan.md](program-plan.md) | Adoption slices UDS-0–UDS-4, rollout contract, deferrals, acceptance | Proposed |
| [uds-1-plan.md](uds-1-plan.md) | UDS-1 implementation plan (tokens, ActionButtonHelper, shared primitives; not a Phase N.M) | Implemented (UDS-1a–1d) |
| [uds-1-user-stories.md](uds-1-user-stories.md) | Issue-ready backlog stories for UDS-1a–1d | Implemented (acceptance checked) |
| [uds-2-plan.md](uds-2-plan.md) | UDS-2 representative screen convergence (Suppliers, Receiving, history, review dialogs) | Implemented (partial matrix; a11y evidence pending) |
| [uds-2-user-stories.md](uds-2-user-stories.md) | Issue-ready backlog stories for UDS-2a–2d | Implemented |
| [uds-3-plan.md](uds-3-plan.md) | UDS-3 Register visual refinement (basket hierarchy, shortcut groups, overlays) | Implemented (partial matrix; a11y evidence pending) |
| [uds-4-plan.md](uds-4-plan.md) | UDS-4 grouped navigation and cross-cutting adoption; gated by [phase7.1-uds-coordination.md](../phase7.1-purchasing-polish/phase7.1-uds-coordination.md) | Proposed; **UDS-4.2 in progress** |
| [uds-4.0-gate-evidence.md](uds-4.0-gate-evidence.md) | Prototype gate checklist and evidence for Profiles A/B | **Passed** |
| [uds-4.2-plan.md](uds-4.2-plan.md) | Non-purchasing ActionButtonHelper adoption and cross-links (4.2a–4.2d) | **In progress** |
| [uds-3-user-stories.md](uds-3-user-stories.md) | Issue-ready backlog stories for UDS-3a–3c | Implemented |
| [accessibility-ergonomic-test-matrix.md](accessibility-ergonomic-test-matrix.md) | Manual a11y/ergonomic gate + timed cashier scenarios for UDS-2/UDS-3 | Proposed acceptance gate |
| [warm-parchment.md](warm-parchment.md) | Tokens, typography, density, contrast (AA baseline) | Implemented (UDS-1) |
| [warm-parchment-palette-mockup.html](warm-parchment-palette-mockup.html) | Static HTML demo of the contrast-complete palette | Inspirational |
| [receipt-overview-mockup.html](receipt-overview-mockup.html) | Inspirational completed-transaction / history layout | Inspirational |
| [shelvesense-warm-parchment-product-mockups.html](shelvesense-warm-parchment-product-mockups.html) | Inspirational product admin chrome (sidebar/Cmd+K shown are deferred) | Inspirational |
| [button-action-semantics.md](button-action-semantics.md) | Labels, intents, styles, sizes, review dialogs | Implemented helper (UDS-1b); broad adoption UDS-2 |
| [navigation-proposal.md](navigation-proposal.md) | Permission-gated administrative destinations, canonical groups, accessible responsive pattern, and prototype gate | Accepted inventory; UDS-4.0 gate Passed; UDS-4.1 ships chrome |
| [surface-contracts.md](surface-contracts.md) | Basket, transaction history, printed receipt | Proposed |
| [deferred-patterns.md](deferred-patterns.md) | Drawers, global search, density prefs, etc. | Proposed (explicitly deferred) |
| [migration-matrix.md](migration-matrix.md) | Area status: legacy / partial / conforming / locked; UDS-0 path-level inventory | Working tracker |

Daily admin conventions: [ux-conventions.md](../../ux-conventions.md) (Warm Parchment palette; Phase 2.2 architecture). Action semantics and tokens remain authoritative in this packet.

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

Phase 2.2 established Propshaft tokens, shared partials/helpers, money UX, accessibility baseline, and shell architecture. UDS-1 **preserves that architecture** and **supersedes the Phase 2.2 color palette** with Warm Parchment tokens ([ADR-022](../../adr/ADR-022-warm-parchment-visual-tokens.md) Implemented).

## Out of scope for this packet alone

Implementing CSS, migrating all screens, global search, master-detail drawers, or changing Register keyboard bindings. See [program-plan.md](program-plan.md) and [deferred-patterns.md](deferred-patterns.md).
