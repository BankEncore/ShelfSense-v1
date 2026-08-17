# Register identity contract

**Status:** Accepted (implements [ADR-021](../../../adr/ADR-021-register-and-terminal-identity.md))

**Authority:** Register vs Terminal boundary for Phases 4–6, target `registers` schema, and pre-Phase-4 rename prerequisite. Receipt display forms remain in [receipt-identity.md](receipt-identity.md) / [ADR-006](../../../adr/ADR-006-receipt-numbering.md).

---

## 1. Terms

| Term | Meaning |
|---|---|
| **Store** | Physical/business retail location |
| **Register** | Durable logical checkout position within a Store |
| **Terminal** | Concrete POS client/device; deferred during Rails-native Phases 4–6 |
| **Session** | Cashier’s operating period on a Register |
| **Reporting / Z period** | Register-scoped business-date reporting period |
| **Receipt sequence** | Register-local permanent completed-transaction sequence |

Do not use `workstation` as a synonym for Register or Terminal in new POS documentation or code.

---

## 2. Target `registers` table (after rename)

```text
registers
├── id
├── store_id
├── register_number          # durable human identity within store
├── name                     # editable label
├── description              # optional
├── active
├── deactivated_at / deactivated_by_id
├── receipt_sequence
├── lock_version
└── timestamps
```

Constraints:

```text
UNIQUE(store_id, register_number)
```

`register_number` becomes effectively immutable once the Register has issued a completed transaction.

### Prefer not to keep

| Field | Reason |
|---|---|
| `code` | Prefer drop after review; UUID + `register_number` cover technical and operational identity |
| `activated_at` | Device/client lifecycle → Terminal later |
| `revoked_at` | Device/client lifecycle → Terminal later |
| `last_seen_at` | Device presence → Terminal later |

Keep Register lifecycle via `active` / `deactivated_*`.

---

## 3. Register-scoped POS facts

```text
pos_reporting_periods.register_id
pos_sessions.register_id
pos_transactions.register_id
```

Invariants:

```text
ReportingPeriod.store_id == Register.store_id
Session.register_id == ReportingPeriod.register_id
Session.store_id == Register.store_id
Transaction.register_id == Session.register_id
```

One open reporting/Z period per Register.

Receipt uniqueness:

```text
UNIQUE(store_id, register_id, receipt_sequence)
```

---

## 4. Envelope origin (Phase 4)

```text
origin
├── store_id
├── register_id
├── pos_session_id
├── reporting_period_id
└── performed_by_user_id
```

Do not fabricate a Terminal identity for Rails-native completion.

Later (standalone):

```text
origin.register_id   → commercial origin
origin.terminal_id   → technical provenance only
```

---

## 5. Pre-Phase-4 rename slice (implementation prerequisite)

Complete before migrating `pos_reporting_periods`, `pos_sessions`, or `pos_transactions`:

1. Accept ADR-021; update `AGENTS.md` and ADR-011 / ADR-006 (docs — this packet).
2. Migrate schema: `workstations` → `registers`; FKs `workstation_id` → `register_id` (including `audit_events`).
3. Add `register_number`; backfill from existing `code` where numeric-suitable, or assign new numbers; unique per store.
4. Review/drop `code` if unused after UI switches to `register_number`.
5. Drop unused device fields (`activated_at`, `revoked_at`, `last_seen_at`) if confirmed unused.
6. Rename model/controller/routes/permissions (`registers.*`) / tests / seeds.
7. Update Phase 4–6 docs already aligned to Register (this packet).
8. Only then add POS period/session/transaction migrations.

Until that migration lands, the live database may still say `workstations`; planning documents describe the **target** domain.

---

## 6. Phases 4–6 vs standalone

| Phase | Register | Terminal |
|---|---|---|
| 4–6 Rails POS | Required | Not modeled |
| Standalone offline | Required | Required before offline completion authority |

Terminal enrollment, active Register assignment, and sequence-authority safeguards precede standalone local completion.
