# ADR-025: Domain-owned operational ledgers

- **Status:** Accepted
- **Date:** 2026-08-25
- **Accepted:** 2026-08-25

## Context

The canonical roadmap previously titled Phase 10 “Stored value and financial event contract” and defined slice 10.1 as a reconstructable operational financial subledger shared by stored value, cash movements, and buyback, including accounting export/posting status.

ShelfSense already records monetary consequences as domain-specific immutable facts: completed POS transactions, tenders, tax components, inventory ledger and valuation entries, and (in Phase 10) stored-value operations and entries. A universal `financial_events` table would duplicate those facts, invent GL-adjacent columns before cash management and buyback exist, and invite later phases to post through a premature common type instead of their own contracts.

[ADR-013](ADR-013-append-only-facts.md) already requires reconstructable completed facts. [ADR-010](ADR-010-transactional-outbox.md) already provides versioned integration messages. Neither requires a cross-domain operational subledger.

## Decision

ShelfSense will not introduce a universal operational financial-event table before cash management, buyback, and accounting requirements exist. POS, inventory, tax, stored value, cash management, and buyback retain domain-specific immutable facts. A later accounting phase will define the versioned posting/export boundary across those sources.

In particular:

1. Phase 10 is **Stored value**. Its core is accounts, operations, entries, and Register integration—not a general financial-event type.
2. Phase 11 cash movements and Phase 12 buyback each own their own immutable operations and ledgers. They may reference stored-value operations (for example trade-credit issuance) without posting a shared financial-event row.
3. Domain outbox events remain integration messages. They are not a substitute general ledger and must not carry accounting export status.
4. **Phase 14** is the home for unified posting, reconciliation, and reporting across those sources.

Gift-card cash-out in Phase 10 adjusts Register expected cash directly. It does not introduce Phase 11’s cash-movement ledger.

## Consequences

- The roadmap slice formerly called “financial event / posting contract” is withdrawn. Implementers follow the [Phase 10 packet](../planning/phase10-stored-value/README.md).
- Phase 11 depends on stored-value and Register integration, not on a shared financial-event table.
- Phase 12 records buyback payout as buyback facts plus stored-value issue operations where trade credit is paid—not as rows in a Phase 10 subledger.
- Accounting mapping (GL ids, journal direction, export batches) must not appear on stored-value operations or entries in Phase 10.
- A later ADR may introduce an accounting staging or posting contract; it must consume existing domain facts rather than rewrite them.

## Related documentation

- [Phase 10 packet](../planning/phase10-stored-value/README.md)
- [Canonical roadmap](../planning/roadmap.md)
- [ADR-013](ADR-013-append-only-facts.md)
- [ADR-010](ADR-010-transactional-outbox.md)
