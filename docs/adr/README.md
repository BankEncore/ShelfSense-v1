# ShelfSense Architecture Decision Records

These ADRs capture the architecture decisions reached during the ShelfSense offline-POS architecture discussion. They describe system-wide technical policy; detailed domain workflows remain in their respective domain documentation.

## Status vocabulary

- **Accepted:** the decision has been made and should guide implementation.
- **Proposed:** the preferred starting position is documented, but a business decision is still required.
- **Superseded:** a later ADR replaces the decision.

## Index

| ADR | Title | Status |
|---|---|---|
| [ADR-001](ADR-001-deployment-topology.md) | Single-tenant, multi-store deployment | Accepted |
| [ADR-002](ADR-002-identifiers.md) | UUIDv7 durable identifiers and separate document numbers | Accepted |
| [ADR-003](ADR-003-data-authority.md) | Server and terminal data authority | Accepted |
| [ADR-004](ADR-004-reference-data-replication.md) | Terminal reference-data replication and retention | Accepted |
| [ADR-005](ADR-005-terminal-originated-operations.md) | Offline terminal-originated operations | Accepted |
| [ADR-006](ADR-006-receipt-numbering.md) | Register-scoped receipt numbering and `S…-R…-T…` reference | Accepted |
| [ADR-007](ADR-007-money-rates-and-time.md) | Money, percentages, dates, and timestamps | Accepted |
| [ADR-008](ADR-008-audit-events.md) | Append-only audit events | Accepted |
| [ADR-009](ADR-009-concurrency-and-idempotency.md) | Optimistic concurrency and idempotency | Accepted |
| [ADR-010](ADR-010-transactional-outbox.md) | Transactional outbox and at-least-once delivery | Accepted |
| [ADR-011](ADR-011-naming-conventions.md) | Database and domain naming conventions | Accepted |
| [ADR-012](ADR-012-record-lifecycle.md) | Editing, supersession, reversal, and deletion | Accepted |
| [ADR-013](ADR-013-append-only-facts.md) | Immutable business facts and mutable processing state | Accepted |
| [ADR-014](ADR-014-conflict-resolution.md) | Conflict prevention and reconciliation | Accepted |
| [ADR-015](ADR-015-offline-individual-inventory-units.md) | Offline sale of individually tracked units | Accepted |
| [ADR-016](ADR-016-offline-returns.md) | Offline return policy | Proposed |
| [ADR-017](ADR-017-business-day-closure.md) | Business-day closure with unreported workstations | Proposed |
| [ADR-018](ADR-018-pos-runtime-and-deployment.md) | POS runtime and workstation architecture | Proposed |
| [ADR-019](ADR-019-pos-sales-tax-model.md) | U.S. retail sales-tax model for POS | Accepted |
| [ADR-020](ADR-020-pos-operation-envelope-and-core-facts.md) | Canonical POS operation envelope and normalized Core facts | Accepted |
| [ADR-021](ADR-021-register-and-terminal-identity.md) | Register and Terminal identities | Accepted |
| [ADR-022](ADR-022-warm-parchment-visual-tokens.md) | Warm Parchment visual tokens (supersede Phase 2.2 palette) | Implemented |
| [ADR-023](ADR-023-customer-merge.md) | Customer identity merge | Accepted |

## Governing principle

> Current descriptive state may evolve, but historically consequential facts remain reconstructable.

Server-owned reference data flows down. Terminal-originated completed facts flow up. Mutable workflows have one writer at a time. Scarce shared resources require online authorization or explicit allocation. Completed activity is reconciled through warnings, quarantine, and compensating records rather than silent rewriting.
