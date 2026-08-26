# Phase 11 — Cash accountability

Status: **Proposed** (11.1–11.3 not started). 11.0 packet is implementation authority. After Phase 10 stored value on `main`. Companions: [ADR-013](../../adr/ADR-013-append-only-facts.md), [ADR-021](../../adr/ADR-021-register-and-terminal-identity.md), and [ADR-025](../../adr/ADR-025-domain-owned-operational-ledgers.md).

The draft [phase-11-register-and-cash-management-spec.md](../../drafts/phase-11-register-and-cash-management-spec.md) is **superseded**. Do not implement from it.

Phase 11 extends existing Register session closeout. It does **not** introduce cash drawers, workstations, a parallel drawer-session model, or a copy of POS tenders into a generic cash ledger.

| Document | Purpose |
|---|---|
| [phase11-plan.md](phase11-plan.md) | Goal, slices 11.0–11.3, deferrals, acceptance |
| [phase11-schema.md](phase11-schema.md) | Locations, operations, entries, source rows, session close columns |
| [phase11-authorization.md](phase11-authorization.md) | Permission keys, scope, role grants |
| [phase11-user-stories.md](phase11-user-stories.md) | GitHub-issue-ready stories |
| [phase11-implementation-plan.md](phase11-implementation-plan.md) | Locked decisions and living slice status |
| [phase11-session-lifecycle.md](phase11-session-lifecycle.md) | Safe-backed open/close, available cash, manager-assisted close |
| [phase11-non-sale-activity.md](phase11-non-sale-activity.md) | Paid-in/out, drop, replenishment, reasons, reversals |
| [phase11-safe-and-reporting.md](phase11-safe-and-reporting.md) | Safe recon, deposit in transit, store-day report |
| [phase11-manual-test-plan.md](phase11-manual-test-plan.md) | Manual Register, safe, deposit, and closeout checks |

Forward summary: [roadmap.md](../roadmap.md) § Phase 11. Glossary: [docs/glossary.md](../../glossary.md).
