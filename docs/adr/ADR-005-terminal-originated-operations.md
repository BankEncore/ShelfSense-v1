# ADR-005: Offline terminal-originated operations

- **Status:** Accepted
- **Date:** 2026-08-09

## Context

Checkout must not depend on real-time access to the central server, but some operations consume scarce shared resources and cannot safely use an unrestricted stale balance.

## Decision

Use a hybrid availability policy defined per operation:

1. **Locally completable:** ordinary sales, permitted cash movements, and receipt-print events complete atomically on the workstation and synchronize later.
2. **Locally completable with reconciliation risk:** explicitly approved operations complete locally, preserve their snapshots, and may be flagged or quarantined centrally.
3. **Online-authorized:** operations involving strict shared balances or unacceptable duplication risk require connectivity until a bounded offline mechanism exists. Stored-value redemption is initially in this class.

Every locally completable operation records an originating workstation, UUIDv7, idempotency key, actor, session, occurrence time, business date, configuration versions, and immutable completed payload. Synchronization state is not part of the immutable business meaning.

## Consequences

- Cashiers can complete ordinary sales during outages.
- Each feature needs a documented offline-availability classification.
- The central server may accept, accept with warnings, or quarantine a fact, but cannot reopen or rewrite a locally completed transaction.
- UI must clearly explain operations that require connectivity.
