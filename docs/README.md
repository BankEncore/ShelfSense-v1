# ShelfSense documentation

This directory contains the project’s technical authority, development guidance, and implementation documentation.

## Start here

| Document | Purpose |
|---|---|
| [Architecture Decision Records](adr/README.md) | Accepted and proposed cross-cutting architecture decisions |
| [Phase 1 plan](planning/phase1-operational-foundation/phase1-plan.md) | Phase 1 scope, slices, and acceptance criteria |
| [Phase 1 schema](planning/phase1-operational-foundation/phase1-schema.md) | Phase 1 tables, fields, and constraints |
| [Phase 1 authorization](planning/phase1-operational-foundation/phase1-authorization.md) | Permission catalog, role grants, and evaluation rules |
| [Phase 2 plan](planning/phase2-financial-classification-and-merchandise-foundation/phase2-plan.md) | Phase 2 scope, slices, and completion criteria |
| [Phase 2 schema](planning/phase2-financial-classification-and-merchandise-foundation/phase-2-database-schema.md) | Phase 2 tables, fields, and constraints |
| [Phase 2 authorization](planning/phase2-financial-classification-and-merchandise-foundation/phase2-authorization.md) | Phase 2 permission catalog and role grants |
| [Phase 2.1 refinements](planning/phase2.1-platform-merchandise-refinement/phase-2.1-platform-and-merchandise-refinements.md) | Implemented merchandise correctness and operability patch before inventory |
| [Phase 2.2 UX foundation](planning/phase2.2-ux-foundation/phase-2.2-ux-foundation.md) | Implemented administrative UX foundation (shell, products reference flow, Stores/Classes adoption) |
| [Phase 3 inventory foundation](planning/phase3-inventory-foundation/phase-3-inventory-foundation.md) | Implemented physical/valuation inventory ledgers, adjustments, units, reconciliation |
| [Inventory posting contract](planning/phase3-inventory-foundation/inventory-posting-contract.md) | Posting boundary later purchasing/POS/transfer workflows must use |
| [Phase 4 POS plan](planning/phase4-6-point-of-sale/phase4-point-of-sale/phase4-plan.md) | Implemented Phase 4 scope, locked decisions, and acceptance |
| [Phase 4 POS schema](planning/phase4-6-point-of-sale/phase4-point-of-sale/phase4-schema.md) | Implemented Phase 4 tables (minimal sessions; tax/receipt/operation locks) |
| [CompletedPosOperation v1](planning/phase4-6-point-of-sale/phase4-point-of-sale/completed-pos-operation-v1.md) | Canonical completed POS operation contract and completion boundary |
| [POS tax contract](planning/phase4-6-point-of-sale/phase4-point-of-sale/pos-tax-contract.md) | Store taxes, rules, calculation, and completed tax snapshots (ADR-019) |
| [Receipt identity](planning/phase4-6-point-of-sale/phase4-point-of-sale/receipt-identity.md) | Compact `S…-R…-T…` transaction reference and receipt header forms (ADR-006) |
| [Register identity](planning/phase4-6-point-of-sale/phase4-point-of-sale/register-identity.md) | Register vs Terminal; pre-Phase-4 `workstations`→`registers` rename (ADR-021) |
| [POS operation and Core facts](planning/phase4-6-point-of-sale/phase4-point-of-sale/operation-and-core-facts.md) | Canonical envelope vs normalized Core dual authority (ADR-020) |
| [Phase 5 cash register plan](planning/phase4-6-point-of-sale/phase5-cash-register/phase5-plan.md) | Implemented Phase 5 cash/Z, Register workspace, print, and close/Z |
| [Phase 5 cash register schema](planning/phase4-6-point-of-sale/phase5-cash-register/phase5-schema.md) | Implemented session close snapshots and reporting-period Z aggregates |
| [Phase 5 register workspace](planning/phase4-6-point-of-sale/phase5-cash-register/register-workspace.md) | Slice 2 open gate, modes, HTTP/retry, focus, completion receipt vs print |
| [Phase 5 register workspace UX](planning/phase4-6-point-of-sale/phase5-cash-register/register-workspace-ux.md) | Slice 2 low-fidelity wireframes (focus, keys, Turbo regions) |
| [Phase 6 POS MVP plan](planning/phase4-6-point-of-sale/phase6-pos-mvp/phase6-plan.md) | Phase 6 slice map, deferrals, merge-to-main, and acceptance (6.0–6.8 implemented) |
| [Phase 6 MVP contract](planning/phase4-6-point-of-sale/phase6-pos-mvp/mvp-contract.md) | Slice 6.0 CompletedPosOperation v2 and cross-cutting locks |
| [Phase 6 merchandise breadth](planning/phase4-6-point-of-sale/phase6-pos-mvp/merchandise-breadth.md) | Slice 6.1 Used/individual and non-inventory sales (implemented) |
| [Phase 6 tender breadth](planning/phase4-6-point-of-sale/phase6-pos-mvp/tender-breadth.md) | Slice 6.2 Cash/Card/Check/Other settlement (implemented) |
| [Phase 6 transaction history](planning/phase4-6-point-of-sale/phase6-pos-mvp/transaction-history.md) | Slice 6.3 completed lookup, detail, reprint (implemented) |
| [Phase 6 controlled actions](planning/phase4-6-point-of-sale/phase6-pos-mvp/controlled-actions.md) | Slice 6.4 price override, line discount, Tax Class override (implemented) |
| [Phase 6 returns](planning/phase4-6-point-of-sale/phase6-pos-mvp/returns.md) | Slice 6.5 linked/unlinked returns, refunds, mixed sale+return (6.5A–D implemented) |
| [Phase 6 post-void](planning/phase4-6-point-of-sale/phase6-pos-mvp/post-void.md) | Slice 6.6 whole-transaction compensating fact (implemented) |
| [Phase 6 POS workflow](planning/phase4-6-point-of-sale/phase6-pos-mvp/pos-workflow.md) | Slice 6.7 cashier Home, keys, pickers, open-price Standard, return entry, X Report (implemented) |
| [Phase 6 MVP closeout](planning/phase4-6-point-of-sale/phase6-pos-mvp/mvp-closeout.md) | Slice 6.8 presentation, regression; no new commercial behavior (implemented) |
| [Phase 6 receipt presentation](planning/phase4-6-point-of-sale/phase6-pos-mvp/receipt-presentation.md) | Customer print/reprint layout (implemented in 6.8) |
| [Phase 6.1 classification and identifiers](planning/phase6.1-merchandise-classification-and-identifiers/README.md) | Implemented classification cutover, live tax inheritance, product industry GTIN, lookup codes, and POS/inventory targeting (disposable-data cutover on `main`) |
| [POS Phases 4–6 plan](planning/phase4-6-point-of-sale/spec.md) | Multi-phase POS sequencing (foundation → cash register → MVP); §6 deferred to the Phase 6 packet |
| [UX conventions](ux-conventions.md) | Shared admin page anatomy, partials, currency boundaries, palette, and Hotwire deferral |
| [Development guide](development.md) | Docker-only local setup, PostgreSQL configuration, application commands, and troubleshooting |
| [Testing and CI](testing.md) | Active GitHub Actions checks and prerequisites for deferred checks |
| [GitHub work management](github-workflow.md) | Issues, PRs, milestones, labels, and release tagging |
| [Project README](../README.md) | Project purpose, status, roadmap, architecture summary, and quick start |
| [Contributor rules](../AGENTS.md) | Required practices for human contributors and coding agents |

## Document authority

Accepted ADRs govern implementation. Proposed ADRs describe unresolved policy and must not be treated as final. When code or another document conflicts with an accepted ADR, resolve the conflict explicitly—normally with a superseding ADR—rather than allowing silent divergence.

Update the relevant documentation in the same change as behavior, schema, terminology, permissions, workflows, deployment requirements, or CI coverage.

## Planned documentation areas

As implementation advances, this index should link the canonical documents for:

- Domain models and boundaries
- Operational workflows
- Schema reference or data dictionary
- Security and privacy
- Glossary
- Roadmap and implementation status
- Deployment and operations

Add a document only when it has a clear owner and purpose. Prefer linking one canonical source over duplicating policy across several files.
