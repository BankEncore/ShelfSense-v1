# ADR-002: UUIDv7 durable identifiers and separate document numbers

- **Status:** Accepted
- **Date:** 2026-08-09

## Context

Records may originate on disconnected workstations and must synchronize without relying on a central numeric-sequence allocator. Human-facing numbers have different usability and sequencing requirements from technical identity.

## Decision

Use UUIDv7 for durable business-entity primary keys. Generate an entity's UUID at its point of origin. Human-facing identifiers—receipt numbers, purchase-order numbers, journal numbers, and similar document numbers—are separate attributes with their own scopes and allocation policies.

Mixed UUID and bigint primary keys are acceptable only when intentional. Durable distributed business entities use UUIDv7; small static lookup tables and purely local technical tables may use integer keys when synchronization and external reference are not concerns.

## Consequences

- Workstations can create globally unique records offline.
- UUIDv7 provides useful time ordering without making the identifier a business timestamp.
- Foreign keys to distributed entities use UUIDs and consume more storage than bigint keys.
- Document-number rules can change without changing record identity.
- UUID ordering or embedded time must not replace explicit business timestamps.
