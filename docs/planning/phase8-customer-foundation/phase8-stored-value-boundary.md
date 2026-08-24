# Phase 8 — Stored-value identity boundary

Status: **Proposed contract** for Phase 10. Phase 8 implements guards and canonical resolution only; no ledger.

Policy authority for merge: [ADR-023](../../adr/ADR-023-customer-merge.md).

## Phase 8 guarantees

1. **Durable identity** — `customers.id` (UUIDv7) is the long-lived customer key.
2. **Canonical customer** — `Customer#canonical` returns the survivor when `merged_into_customer_id` is set. After every successful merge, aliases point **directly** to a canonical survivor (at most one hop; chains are forbidden and flattened away).
3. **Active eligibility** — new customer-owned financial relationships may only attach to an **active, canonical** customer (`active: true`, not merged).
4. **Merge tombstone** — merged sources remain addressable for audit and old references; they do not accept new operational work.
5. **Deactivation** — `active: false` blocks new requests and future financial account **creation**; it does not erase historical facts or future balance read models.

## Phase 10 responsibilities (explicitly not Phase 8)

- Stored-value account creation, ledger entries, redemption, and POS tender integration.
- **Financial merge semantics:** consolidating or transferring balances when customers merge must be implemented as an explicit financial-domain command (or an explicit call from `Customers::MergeCustomers`) with documented policy—not blind `customer_id` FK rewrites across financial tables, and not a plugin/callback registry.
- Stronger merge confirmation when balances are involved (irreversibility policy unchanged).
- Online-authorized redemption ([ADR-005](../../adr/ADR-005-terminal-originated-operations.md), [ADR-014](../../adr/ADR-014-conflict-resolution.md)).

## Test hooks in Phase 8

- Unit/integration tests that a merged alias cannot be used for `Customers::CreateRequest` (or equivalent), including concurrent create-vs-merge.
- Unit tests for canonical resolution and alias flattening (`A → B` then `B → C` yields `A → C`, `B → C`).
- Inventory row + explicit Phase 10 command for balance transfer documented in the merge consumers checklist ([phase8-schema.md](phase8-schema.md)), not a dynamic reassigner registry.
