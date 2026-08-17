# ADR-021: Register and Terminal identities

- **Status:** Accepted
- **Date:** 2026-08-16
- **Related:** [ADR-006](ADR-006-receipt-numbering.md), [ADR-011](ADR-011-naming-conventions.md), [Register identity contract](../planning/phase4-6-point-of-sale/phase4-point-of-sale/register-identity.md)

## Context

Earlier ShelfSense documents and Phase 1 schema used **workstation** for the durable POS checkout identity. The same word was also used for the offline computing client that caches reference data and synchronizes completed operations. That conflation becomes expensive once POS reporting periods, sessions, transactions, and receipt sequences hang off the wrong concept.

Cashiers operate a logical checkout position. Hardware, browsers, and future standalone clients are replaceable. Receipt sequences, Z periods, sessions, and cash accountability must survive client replacement.

## Decision

### Register

A **Register** is the durable logical point-of-sale position within a Store. It is a business-domain identity.

A Register owns:

```text
Store association
stable register_number
name / description
receipt_sequence
reporting / Z periods
cashier Sessions
cash accountability
completed transaction commercial origin
active / inactive lifecycle
```

Register identity survives hardware replacement, software reinstallation, browser changes, and migration between POS clients.

### Terminal

A **Terminal** is a concrete POS computing endpoint authorized to operate a Register. It is a technical and synchronization identity.

A Terminal may eventually own device/installation credentials, activation/revocation, software version, last-seen state, reference-data replication, local persistence/outbox, sync state, and recovery/clone-detection state.

> The Register is what the cashier operates. The Terminal is what runs ShelfSense.

### Hierarchies

Business hierarchy:

```text
Store
└── Register
    └── Reporting / Z Period
        ├── Session
        └── Transactions
```

Technical assignment (not ownership of business history):

```text
Terminal → operates Register
```

Terminal does **not** own the Register. Business history does not hang beneath the Terminal.

### Phase scope

- **Phases 4–6 (Rails-native POS):** implement **Registers only**. Do not introduce a `terminals` table, enrollment, or offline client identity.
- **Standalone / offline POS:** a first-class Terminal identity is a **prerequisite** before standalone clients may complete transactions independently, because Register-owned sequences (receipt, Z) need a single active completion authority and clone safeguards.

### Schema target

Rename the existing Phase 1 logical entity before POS tables depend on it:

```text
workstations → registers
workstation_id → register_id
Workstation → Register
workstations.* permissions → registers.*
```

Add durable `register_number` (unique per store). Prefer end-state fields `id`, `register_number`, `name`, plus Register lifecycle (`active`, `deactivated_at`, …). Drop device-only fields (`activated_at`, `revoked_at`, `last_seen_at`) from Register. Prefer dropping `code` unless a distinct consumer remains after review.

Do not create `terminals` merely to relocate device fields.

### Vocabulary

Do not use `workstation` as a POS domain synonym for Register or Terminal in new work. Historical ADR text that said workstation should be read per the interpretation notes on those ADRs (logical checkout → Register; offline client → Terminal).

**Installation** is not primary POS business vocabulary. A later technical `installation_id` may exist without entering cashier-facing language.

### Receipt, reporting, sessions, transactions

All are **Register-scoped**. A future `terminal_id` on a completed operation may record technical provenance only and must never substitute for `register_id` in receipts, reporting, Session ownership, or cash accountability.

## Consequences

- Amend ADR-006, ADR-011, and `AGENTS.md` for Register terminology.
- Document and execute a pre-Phase-4 rename migration before `pos_reporting_periods`, `pos_sessions`, and `pos_transactions` create FKs.
- Phase 4–6 plans and contracts use `register_id` / `register_number`.
- Standalone architecture must introduce Terminal before offline completion authority.
- Detail and migration checklist: [register-identity.md](../planning/phase4-6-point-of-sale/phase4-point-of-sale/register-identity.md).
