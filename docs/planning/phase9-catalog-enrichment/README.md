# Phase 9 — Catalog and bibliographic enrichment

Status: **Implemented** (August 2026). After Phase 8 on `main`. [Phase 10 stored value](../phase10-stored-value/README.md) is proposed and may start in parallel but is not the primary stream.

Remediation: [phase9-remediation.md](phase9-remediation.md). Product forms: [product-forms-seed.md](product-forms-seed.md).

| Document | Purpose |
|---|---|
| [phase9-plan.md](phase9-plan.md) | Original goal and slice map; shipped persistence is [phase9-remediation.md](phase9-remediation.md) |
| [phase9-schema.md](phase9-schema.md) | Tables, columns, constraints, ISBNdb mapping |
| [phase9-user-stories.md](phase9-user-stories.md) | GitHub-issue-ready stories |
| [phase9-implementation-plan.md](phase9-implementation-plan.md) | Living slice status and locked decisions |
| [phase9-provider-boundary.md](phase9-provider-boundary.md) | Candidate DTO, ISBNdb, secrets, cache, MSRP |

Authority: [ADR-024](../../adr/ADR-024-bibliographic-data-authority.md). Forward summary: [roadmap.md](../roadmap.md) § Phase 9.

Extends Phases 2 and 6.1. Does not replace the product model, change identifier architecture, or create products from POS or receiving misses.
