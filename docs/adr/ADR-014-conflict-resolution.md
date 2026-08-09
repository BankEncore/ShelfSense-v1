# ADR-014: Conflict prevention and reconciliation

- **Status:** Accepted
- **Date:** 2026-08-09

## Context

No universal merge rule is safe for master-data edits, completed sales, unique units, stored value, and stale configuration. Most conflicts can be prevented by authority and single-writer rules.

## Decision

Choose conflict policy by resource:

- Server-owned master-data edits use aggregate versions and reject stale writes for intentional reconciliation.
- Open workflows have one writer at a time; ownership transfer is explicit and acknowledged.
- Completed facts are never resolved through last-write-wins or silent rewriting.
- Quantity-tracked offline sales are accepted even when consolidated inventory becomes negative; shortages are operationally corrected.
- Transactions using cached price or tax snapshots preserve those snapshots and may be flagged, but are not repriced centrally.
- Strict shared balances, initially stored-value redemption, require online authorization until escrow or another bounded offline allocation exists.
- Structurally invalid, duplicate, or materially unauthorized operations may be quarantined while preserving the originating fact.
- Corrections to accepted consequential facts use compensating records.

Last-write-wins is limited to low-value replaceable preferences, not business records.

## Consequences

- Conflict behavior must be documented per command and resource.
- Reconciliation queues need reason codes, evidence, authorized actions, and audit history.
- Acceptance of an economic event and approval of the actor's conduct are separate decisions; an unauthorized sale may still need inventory and accounting effects.
- Some features remain unavailable offline until their risk is explicitly bounded.
