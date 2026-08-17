# ADR-004: Terminal reference-data replication and retention

- **Status:** Accepted
- **Date:** 2026-08-09
- **Interpretation (ADR-021):** “POS workstations” that receive reference-data snapshots are **Terminals**.

## Context

## Decision

Provision a workstation with a versioned full snapshot, then apply ordered incremental change batches. If a replication cursor is invalid, expired, or inconsistent, replace the cache from a new snapshot.

Use deactivation or effective dating for business records with historical meaning. Use tombstones for genuine deletion so delayed changes cannot resurrect removed data. Completed transactions rely on their own snapshots, not the continued presence of cached records.

Cached reference data has no general age-based expiration. A workstation retains and uses the latest successfully synchronized data until a live update is available. Individual records still obey their explicit effective dates, expiration dates, and revocation state already known locally.

For inventory, replicate balance checkpoints plus subsequent relevant movements rather than the complete organization ledger. Locally pending effects must be overlaid so a new checkpoint does not overwrite unsynchronized local activity.

## Consequences

- An extended outage does not arbitrarily disable ordinary sales.
- Transactions must record the source configuration versions and values actually used.
- The server accepts terminal snapshots and does not silently recalculate past receipts using newer rules.
- A disconnected workstation cannot know about a new revocation or emergency change until connectivity returns.
- Snapshot generation, ordered change feeds, tombstone retention, and recovery monitoring are required.
