# Planning packets

This directory holds phase and UX planning packets. **Sequencing and implemented-versus-proposed status** live in the [canonical roadmap](roadmap.md). The full documentation index is [docs/README.md](../README.md).

An early outline in this file numbered Phase 8 as buyback and Phase 9 as financial posting. That numbering is superseded. Do not use it to scope or number new work.

## Canonical sequencing

| Document | Purpose |
|---|---|
| [roadmap.md](roadmap.md) | Implemented milestones, forward phases 10–14, UDS, Terminal program, explicit deferrals |

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
| [Phase 9 — Catalog enrichment](phase9-catalog-enrichment/README.md) | Implemented; persistence in [phase9-remediation.md](phase9-catalog-enrichment/phase9-remediation.md) |

## Cross-phase UX

| Packet | Status |
|---|---|
| [UX design system](ux-design-system/README.md) | UDS-1–3 operationally complete; UDS-4.0–4.2 on `main`; UDS-5 complete on the program branch (Proposed until merge) |
| [UDS-4 plan](ux-design-system/uds-4-plan.md) | Grouped navigation and non-purchasing adoption |
| [UDS-5 plan](ux-design-system/uds-5-plan.md) | Administrative composition; 5.0–5.5 complete on the program branch; 5.0 gate **Passed**; serif adopted |

Further screen migration belongs to the feature phase that materially changes the screen.

## Related

| Document | Purpose |
|---|---|
| [Architecture Decision Records](../adr/README.md) | Accepted and proposed cross-cutting policy |
| [UX conventions](../ux-conventions.md) | Shared admin page anatomy and money UX |
| [Testing and CI](../testing.md) | Active GitHub Actions jobs and system-test workflow |
