# ADR-010: Transactional outbox and at-least-once delivery

- **Status:** Accepted
- **Date:** 2026-08-09

## Context

Publishing after a database commit can lose events if the process fails between commit and publish. Full event sourcing would add complexity beyond ShelfSense's needs.

## Decision

Use ordinary relational state plus a transactional outbox. A business operation updates its aggregate and inserts immutable domain-event messages in the same database transaction. An asynchronous dispatcher delivers them. Delivery is at least once, and every consumer deduplicates by event ID.

Use an outbox on both sides of the offline boundary:

- The workstation outbox carries locally completed operations to the server.
- The server outbox carries accepted events to inventory, financial, reporting, integration, and replication consumers.

Events include a UUID, event type, schema version, aggregate identity and version, occurrence time, correlation and causation IDs, origin, and the minimum immutable facts consumers require. They do not contain indiscriminate copies of mutable records.

## Consequences

- Committed work cannot be lost merely because publication fails.
- Dispatchers, retries, deduplication, schema evolution, monitoring, and dead-letter or review workflows are required.
- Consumers must be idempotent.
- ShelfSense is explicitly not fully event-sourced.
