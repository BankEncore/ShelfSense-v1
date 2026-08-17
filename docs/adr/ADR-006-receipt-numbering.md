# ADR-006: Register-scoped receipt numbering

- **Status:** Accepted
- **Date:** 2026-08-09
- **Amended:** 2026-08-16 (human-facing reference format); 2026-08-16 (Register terminology per ADR-021)
- **Detail:** [Receipt identity contract](../planning/phase4-6-point-of-sale/phase4-point-of-sale/receipt-identity.md), [ADR-021](ADR-021-register-and-terminal-identity.md)

## Context

A permanent customer-facing receipt identity must be available at offline completion. A server-only sequence cannot satisfy that requirement, while provisional numbers create two identities for one transaction.

Humans also need a self-describing, typeable, scannable reference that is distinct from the transaction UUID and stable after store or register names change.

## Decision

### Sequencing

Receipt sequences are permanently scoped to the store and **Register** and generated when a transaction completes. Each Register maintains a durable, monotonically increasing sequence.

Enforce uniqueness on `(store_id, register_id, receipt_sequence)`. Sequence values are never reused. Gaps are acceptable. Hardware or Terminal replacement preserves the logical Register identity; receipt sequencing belongs to the Register, not the Terminal.

The transaction UUID (`pos_transactions.id`) is the distributed technical identity. The receipt sequence and composite transaction reference are the human-facing lookup identity and never change after assignment or synchronization.

### Human-facing identity

Each completed POS transaction has **one** permanent human-facing identity with two display forms:

```text
Compact transaction reference:
S{store_number}-R{register_number}-T{receipt_sequence}

Receipt header (same identity):
Store: {store_number}   Reg: {register_number}   Trans: {receipt_sequence}
```

Example: store number `3`, register number `2`, sequence `18427`:

```text
S003-R02-T0018427
Store: 003   Reg: 02   Trans: 0018427
```

Display padding is a **minimum**, not a maximum width:

| Component | Minimum zero-padded width |
|---|---|
| Store number | 3 |
| Register number (“Reg”) | 2 |
| Receipt sequence (“Trans”) | 7 |

Larger values simply render more digits (`S1002-R02-T0018427`). Parsing uses the `S` / `R` / `T` labels and `-` separators, not fixed field widths.

Canonical components for the reference are durable **numbers**, not editable names:

- `stores.store_number`
- `registers.register_number`

Those numbers should become effectively immutable once used to issue a completed transaction. Completed transactions snapshot the numbers so the reference can always be reconstructed if configuration is later altered incorrectly.

Authoritative persisted facts are `store_id`, `register_id`, `receipt_sequence`, plus number snapshots. The compact string may be derived and need not be a sole authoritative column.

Do **not** call the receipt sequence `transaction_id` in schemas or APIs; that name is reserved for the UUID. Receipt headers may still label the padded sequence `Trans:` for cashiers and customers.

### Vocabulary

Domain and schema use **Register** (ADR-021). Customer/cashier-facing copy may say `Reg` for the register number component. Do not use Terminal identity in the receipt reference.

## Consequences

- Receipts can be finalized and reprinted consistently offline.
- ShelfSense does not provide a single chronological store-wide receipt sequence.
- Only one sequence writer may act for a logical Register at a time (enforced via Terminal assignment when offline clients exist).
- Register replacement of the physical Terminal, cloning, backup restoration, and sequence recovery need safeguards against reuse.
- Transaction lookup can accept the compact reference, component fields, or progressive partial searches.
- Earlier illustrative format `{store_code}-{workstation_code}-{sequence}` and interim `workstation_number` wording are superseded by Register-scoped `S` / `R` / `T` forms; sequencing scope remains store + logical checkout position.
