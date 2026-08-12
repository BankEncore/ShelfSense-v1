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
