# Phase 11 — Schema contract

Status: **Proposed**. PostgreSQL is authoritative. Do not edit `db/schema.rb` until migrations land. UUIDv7 via `create_uuid_table` / application-assigned ids ([AGENTS.md](../../../AGENTS.md) §10).

Companions: [phase11-plan.md](phase11-plan.md), [phase11-session-lifecycle.md](phase11-session-lifecycle.md), [phase5-schema.md](../phase4-6-point-of-sale/phase5-cash-register/phase5-schema.md).

## Naming

- User FKs: `performed_by_id`, `approved_by_id`, `closed_by_user_id` (not `actor_id`).
- Compensating: `reversal_of_id` only; inverse association `reversed_by` ([ADR-011](../../adr/ADR-011-naming-conventions.md)).
- No polymorphic `source_type` / `source_id` on cash operations.
- Source rows hold `cash_operation_id`. Operations do **not** store inverse source FKs.
- Do not name tables or columns `workstation` or `cash_drawer`.

## 1. `cash_locations`

Store-level pools. The POS session is **not** a row here.

| Column | Type | Contract |
|---|---|---|
| `id` | uuid | UUIDv7 PK |
| `store_id` | uuid | Required |
| `location_type` | string | `safe`, `deposit_in_transit` |
| `expected_balance_cents` | bigint | Default 0; nonnegative projection; never assigned via generic update |
| `initialized_at` | timestamptz, nullable | Required for `safe` after initialization; null means the store cannot open sessions |
| `lock_version` | integer | Required; default 0 |
| timestamps | timestamptz | Required |

Checks:

- `expected_balance_cents >= 0`
- `location_type` immutable after insert
- Unique `(store_id)` where `location_type = 'safe'` (MVP: one operational safe)
- Unique `(store_id)` where `location_type = 'deposit_in_transit'` (one DIT pool per store)

MVP does not expose a second safe in UI. A later unique partial index change may allow additional safes; do not reuse a location row to mean a drawer.

## 2. `cash_operations`

| Column | Type | Contract |
|---|---|---|
| `id` | uuid | UUIDv7 PK |
| `operation_type` | string | `initialize_safe`, `transfer`, `paid_in`, `paid_out`, `reconcile`, `reverse` |
| `store_id` | uuid | Required |
| `business_date` | date | Required; never reconstructed from `created_at` |
| `occurred_at` | timestamptz | Required |
| `performed_by_id` | uuid | Required |
| `approved_by_id` | uuid, nullable | Set only for `approval_required`; omitted for `direct`; never equal to `performed_by_id` |
| `pos_session_id` | uuid, nullable | When the operation is session-custody (open, close recon, paid-in/out, drop, replenish) |
| `idempotency_operation_id` | uuid | FK to claimed `idempotency_operations` |
| `reversal_of_id` | uuid, nullable | Unique when present |
| `reason_code` | string, nullable | Required for paid-in/out, reconcile, reverse, manager close context as applicable |
| `reason_name_snapshot` | string, nullable | Historic label |
| `notes` | text, nullable | Controlled |
| timestamps | timestamptz | Required |

No `lock_version` (immutable after insert). Unique `reversal_of_id` where not null. Reversals use `operation_type = reverse`.

Do **not** persist `pos_tender_id` or `gift_card_cash_out_id` on this table.

## 3. `cash_entries`

| Column | Type | Contract |
|---|---|---|
| `id` | uuid | UUIDv7 PK |
| `cash_operation_id` | uuid | Required |
| `entry_sequence` | integer | ≥ 0; unique per operation |
| `amount_cents` | bigint | Signed, nonzero |
| `balance_after_cents` | bigint | ≥ 0 snapshot on that target |
| `pos_session_id` | uuid, nullable | Session custody target |
| `cash_location_id` | uuid, nullable | Safe or DIT target |
| `reversal_of_id` | uuid, nullable | Unique when present |
| `created_at` | timestamptz | Required |

XOR: exactly one of `pos_session_id` or `cash_location_id`. Transfer operations have two entries that net to zero. Paid-in/out, initialize_safe, and reconcile are single-sided.

No generic update of `amount_cents` after insert.

## 4. Source rows

Each successful **non-reverse** operation has exactly one source row. Inverse `has_one` from that operation. **Reverse** operations have **no** transfer, paid-in, paid-out, reconciliation, initialization, or deposit source row. Reason and notes live on the reverse `cash_operations` row. The original source row is unchanged and is reached via `cash_operations.reversal_of_id` / `reversed_by`. Do not invent a `cash_reversals` table in MVP.

### 4.1 `cash_transfers`

| Column | Type | Contract |
|---|---|---|
| `id` | uuid | UUIDv7 PK |
| `transfer_type` | string | `opening_float`, `drop`, `replenishment`, `session_close`, `deposit` |
| `amount_cents` | bigint | > 0 |
| `source_pos_session_id` / `source_cash_location_id` | uuid, nullable | XOR; origin |
| `destination_pos_session_id` / `destination_cash_location_id` | uuid, nullable | XOR; destination |
| `cash_operation_id` | uuid | Unique |
| timestamps | timestamptz | Required |

| `transfer_type` | Source | Destination |
|---|---|---|
| `opening_float` | store safe | open session |
| `drop` | open session | store safe |
| `replenishment` | store safe | open session |
| `session_close` | closing session | store safe |
| `deposit` | store safe | deposit in transit |

### 4.2 `cash_paid_ins` / `cash_paid_outs`

Amount > 0; `pos_session_id`; reason snapshots; `cash_operation_id` unique. Not tenders. Not gift-card cash-outs.

### 4.3 `cash_reconciliations`

| Column | Type | Contract |
|---|---|---|
| `direction` | string | `over`, `short` |
| `expected_cents` | bigint | Snapshot of expected **before** recognition |
| `counted_cents` | bigint | ≥ 0 |
| `variance_cents` | bigint | `counted_cents - expected_cents`; over ⇒ positive; short ⇒ negative |
| `pos_session_id` / `cash_location_id` | uuid, nullable | XOR; session close vs safe recon |
| `cash_count_id` | uuid | Count that was accepted |
| `cash_operation_id` | uuid | Unique |

Zero variance does not create a reconciliation row.

### 4.4 `cash_safe_initializations`

One row per store safe: unique `cash_location_id`. Count, notes, `cash_operation_id`. Typed as initialization, not paid-in. **Not** reversible through `Cash::Reverse`. A second initialize is rejected. Mistakes after init are corrected with `cash.reconcile_safe`.

### 4.5 `cash_deposits`

Store, business date, deposit number, optional bag/reference, total, prepared_by, `approved_by` only if a later policy requires it, timestamps, `cash_operation_id` unique. MVP: one business date per deposit. Bank-posted amount is **not** a column. Do **not** put `reversal_of_id` on this row; reverse via `cash_operations`.

## 5. `cash_counts`

Immutable observations. They do not change expected cash until a reconciliation or transfer accepts them.

| Column | Type | Contract |
|---|---|---|
| `purpose` | string | `session_open`, `session_close`, `safe_reconciliation`, `deposit`, `safe_initialization` |
| `total_cents` | bigint | ≥ 0; authoritative |
| `expected_cents_snapshot` | bigint, nullable | Required for `safe_reconciliation` and `deposit` (the location being counted): expected balance when the count **started** |
| `location_lock_version_snapshot` | integer, nullable | Required with `expected_cents_snapshot`: that location’s `lock_version` at count start |
| `pos_session_id` / `cash_location_id` | uuid, nullable | As applicable |
| `status` | string | `discarded`, `accepted` |
| `superseded_count_id` | uuid, nullable | Replacement before acceptance |

Optional `cash_count_denomination_lines` (`quantity`, `denomination_cents`). When any line exists, lines must sum to `total_cents`. Denomination lines are **never required** (session, safe, deposit, or initialization).

## 6. `cash_activity_reasons`

Stable catalog: `code`, `name`, `operation_kind` (`paid_in`, `paid_out`, `over`, `short`, `reverse`), `notes_required`, `active`. Facts snapshot `reason_code` / `reason_name_snapshot`. No GL mapping columns.

## 7. `pos_sessions` additions

| Column | Type | Contract |
|---|---|---|
| `closed_by_user_id` | uuid, nullable | Closer; equals cashier on ordinary close; manager on assisted close |
| `close_reason_code` / `close_reason_name_snapshot` | string, nullable | Required when closer ≠ cashier |

Existing `opening_float_cents`, `closing_expected_cash_cents`, `closing_count_cents`, `closing_variance_cents`, and open/closed CHECKs remain. Variance CHECK stays `closing_variance_cents = closing_count_cents - closing_expected_cash_cents`.

Do not add a live `expected_cash_cents` column on the session. Do not add `status = closing`.

## 8. Thresholds (`system_settings` and `stores`)

Organization defaults on `system_settings` (integer cents, `>= 0`):

| Column | Default | Meaning |
|---|---|---|
| `cash_variance_note_threshold_cents` | `0` | Absolute variance at or above this requires a reason/note (`0` = any nonzero) |
| `cash_variance_approval_threshold_cents` | `5000` | Absolute variance at or above this is material (`approval_required` unless the performer is `direct`) |
| `cash_paid_out_approval_threshold_cents` | `5000` | Paid-out amount at or above this uses `cash.approve_paid_out` unless the performer is `direct` |

Store overrides on `stores` (nullable). **Null means inherit the organization value.** Effective threshold at a store is `COALESCE(store.column, system_settings.column)`.

Paid-in has no amount threshold in MVP. Preferred retained-till cash is out of MVP (available cash = expected session cash).

## 9. Projections

- `cash_locations.expected_balance_cents` locked like `stored_value_accounts.balance_cents`.
- Session expected cash is **not** stored while open; `Pos::SessionTotals` remains the live formula. After close, snapshots win.
- Verification job/command: location projection vs sum of effective entries; session closed snapshots vs formula at close time (regression), not a silent repair.

## 10. Outbox

Versioned events, minimum facts, no tender copies: `cash.safe_initialized`, `cash.transferred`, `cash.paid_in`, `cash.paid_out`, `cash.reconciled`, `cash.deposit_prepared`, `cash.reversed`. Same transaction as the business change ([ADR-010](../../adr/ADR-010-transactional-outbox.md)).
