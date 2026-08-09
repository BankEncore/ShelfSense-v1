# ADR-013: Immutable business facts and mutable processing state

- **Status:** Accepted
- **Date:** 2026-08-09

## Context

Distributed processing must update acknowledgment and delivery state without granting permission to alter completed monetary or inventory facts.

## Decision

Freeze business content at completion or posting. Separate mutable processing state into dedicated records when it has a meaningful lifecycle; otherwise permit only a small, explicitly enumerated set of technical metadata columns on the fact record.

Completed POS transactions, finalized tenders, cash movements, inventory ledger entries, posted financial lines, audit events, receipt-print events, and domain-event payloads are immutable. Inventory balances are mutable projections. Reservations and open transactions are mutable under their single-writer lifecycle until completion or cancellation. Outbox payloads are immutable while delivery status and attempts may progress separately.

Append-only records still require idempotency and uniqueness constraints. Reversals reference their targets, and cumulative reversed quantity or amount cannot exceed policy limits.

## Consequences

- Historical facts are protected while synchronization can progress.
- Additional processing-state tables and joins may be required.
- Database permissions, application APIs, and tests should enforce the business/processing boundary.
- “Metadata” cannot become a loophole for altering business meaning.
