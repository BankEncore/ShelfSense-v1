# Phase 7 — Orders, customer requests, and receiving

Status: **application slices 7.1–7.7 complete** on integration branch `phase-7-orders-and-receiving`. **Not implemented on `main`.** Pending [manual test gate](phase7-manual-test-gate.md), review, and final integration → `main` merge.

| Document | Purpose |
|---|---|
| [phase7-plan.md](phase7-plan.md) | Goal, locked decisions, branch policy, slices 7.0–7.7, manual gate, out of scope |
| [phase7-spec.md](phase7-spec.md) | Normative behavior, data model, authorization, acceptance, and tests |
| [phase7-schema.md](phase7-schema.md) | Target tables, fields, and constraints |
| [phase7-workflows.md](phase7-workflows.md) | Operator workflow companion (streams, mermaid, chrome notes) |
| [phase7-lock-order.md](phase7-lock-order.md) | Command lock matrix for inventory / request concurrency |
| [phase7-user-stories.md](phase7-user-stories.md) | Concise backlog stories and acceptance bullets for slices 7.1–7.7 |
| [phase7-manual-test-gate.md](phase7-manual-test-gate.md) | Expanded checklist required before merge to `main` |

Phase 7 ships the bookstore-operable path: configure suppliers → create stock or quantity-one customer requests → locate/reserve or special-order Standard merchandise → send POs → receive → withhold reserved stock → complete pickup on the existing Register → close POs → correct posted receipts without rewriting facts.

Drafts under `docs/drafts/orders-and-receiving/` are superseded stubs. Implement against this packet and the inventory posting contract’s Phase 7 section.

Presentation convergence (Warm Parchment, button semantics, shared primitives) is tracked in the cross-phase [UX design system](../ux-design-system/README.md)—not as a Phase 7 domain slice. Phase 7 ops chrome minimum and shell boundaries in this packet remain authoritative for purchasing workspaces.
