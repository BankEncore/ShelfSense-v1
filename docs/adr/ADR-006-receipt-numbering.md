# ADR-006: Workstation-scoped receipt numbering

- **Status:** Accepted
- **Date:** 2026-08-09

## Context

A permanent customer-facing receipt identity must be available at offline completion. A server-only sequence cannot satisfy that requirement, while provisional numbers create two identities for one transaction.

## Decision

Receipt numbers are permanently scoped to the store and workstation and generated locally when a transaction completes. Each workstation maintains a durable, monotonically increasing sequence. A displayed format may be:

```text
{store_code}-{workstation_code}-{sequence}
```

For example: `DT-03-00018427`.

Enforce uniqueness on `(store_id, workstation_id, receipt_sequence)`. Sequence values are never reused. Gaps are acceptable. Hardware replacement preserves the logical workstation identity when it replaces the same workstation role. Historical workstation codes are immutable or separately snapshotted.

The transaction UUID is the distributed technical identity. The receipt number is the human-facing lookup identity and never changes after synchronization.

## Consequences

- Receipts can be finalized and reprinted consistently offline.
- ShelfSense does not provide a single chronological store-wide receipt sequence.
- Only one sequence writer may act for a logical workstation at a time.
- Workstation replacement, cloning, backup restoration, and sequence recovery need safeguards against reuse.
