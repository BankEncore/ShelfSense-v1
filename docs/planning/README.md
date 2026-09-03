# Planning packets

This directory holds phase and UX planning packets. **Sequencing and implemented-versus-proposed status** live in the [canonical roadmap](roadmap.md). The full documentation index is [docs/README.md](../README.md).

An early outline in this file numbered Phase 8 as buyback and Phase 9 as financial posting. That numbering is superseded. Do not use it to scope or number new work.

## Canonical sequencing

| Document | Purpose |
|---|---|
| [roadmap.md](roadmap.md) | Implemented milestones, forward phases 11–14, UDS, Terminal program, explicit deferrals |

## Implemented domain packets

| Packet | Status |
|---|---|
| [Phase 1 — Operable foundation](phase1-operational-foundation/phase1-plan.md) | Implemented |
| [Phase 2 — Financial classification and merchandise](phase2-financial-classification-and-merchandise-foundation/phase2-plan.md) | Implemented |
| [Phase 2.1 — Merchandise correctness](phase2.1-platform-merchandise-refinement/phase-2.1-platform-and-merchandise-refinements.md) | Implemented |
| [Phase 2.2 — Administrative UX foundation](phase2.2-ux-foundation/phase-2.2-ux-foundation.md) | Implemented |
| [Phase 3 — Inventory foundation](phase3-inventory-foundation/phase-3-inventory-foundation.md) | Implemented |
| [Phases 4–6 — Point of sale](phase4-6-point-of-sale/spec.md) | Implemented (4, 5, 6.0–6.8) |
| [Phase 6.1 — Classification and identifiers](phase6.1-merchandise-classification-and-identifiers/README.md) | Implemented |
| [Phase 7 — Orders, requests, and receiving](phase7-orders-and-receiving/README.md) | Implemented on `main` |
| [Phase 7.1 — Purchasing polish](phase7.1-purchasing-polish/README.md) | Complete on `main` (7.1.1–7.1.3; 7.1.4 deferred) |
| [Phase 8 — Customer foundation](phase8-customer-foundation/README.md) | Complete on `main` |
| [Phase 9 catalog enrichment](phase9-catalog-enrichment/README.md) | Implemented; persistence in [phase9-remediation.md](phase9-catalog-enrichment/phase9-remediation.md) |
| [Phase 10 — Stored value](phase10-stored-value/README.md) | Implemented on `main`; [ADR-025](../adr/ADR-025-domain-owned-operational-ledgers.md), [ADR-026](../adr/ADR-026-gift-card-number-protection.md), [ADR-027](../adr/ADR-027-admin-gift-card-prefix-last-four-inquiry.md) |

## Proposed domain packets

| Packet | Status |
|---|---|
| [Phase 11 — Cash accountability](phase11-cash-accountability/README.md) | Implemented on `main`; [ADR-021](../adr/ADR-021-register-and-terminal-identity.md), [ADR-025](../adr/ADR-025-domain-owned-operational-ledgers.md) |

Phases 12–14 and the Terminal program are sequenced in [roadmap.md](roadmap.md). They do not yet have planning packets.

## Cross-phase UX

| Packet | Status |
|---|---|
| [Register workspace consolidation](register-workspace-consolidation/README.md) | **Accepted packet** (Slice 1 on `main`); slices 2–7 on `register-workspace-consolidation` |
| [UX design system](ux-design-system/README.md) | UDS-1–3 operationally complete; UDS-4.0–4.2 on `main`; UDS-5 complete on `main` (PR #57) |
| [UDS-4 plan](ux-design-system/uds-4-plan.md) | Grouped navigation and non-purchasing adoption |
| [UDS-5 plan](ux-design-system/uds-5-plan.md) | Administrative composition; 5.0–5.5 complete on `main`; 5.0 gate **Passed**; serif adopted |
| [Admin Page Frame Program](admin-page-frame/README.md) | **Accepted.** Slice 1 + Customer core **Implemented on `main`**; [Product show](admin-page-frame/product-show.md) Accepted. Not a restyle sweep |

Further screen migration belongs to the feature phase that materially changes the screen, except the bounded frame infrastructure and Adjustment Reasons reference in the [Admin Page Frame Program](admin-page-frame/README.md) locked allowlist. That program does not authorize a general restyle.

## Related

| Document | Purpose |
|---|---|
| [Architecture Decision Records](../adr/README.md) | Accepted and proposed cross-cutting policy |
| [UX conventions](../ux-conventions.md) | Shared admin page anatomy and money UX |
| [Glossary](../glossary.md) | Canonical domain terms |
| [Testing and CI](../testing.md) | Active GitHub Actions jobs and system-test workflow |
