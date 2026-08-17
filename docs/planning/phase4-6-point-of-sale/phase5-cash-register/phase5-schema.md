# Phase 5 — Cash accountability schema

**Status:** Implemented (slice 1). Register UI does not add tables.

**Authority:** Column and constraint intent for Phase 5 session cash and reporting-period Z snapshots. Phase 4 tables stay as migrated; this document only adds the deferred cash/Z fields. Cross-cutting rules remain in `AGENTS.md` and accepted ADRs.

Companions: [Phase 5 plan](phase5-plan.md), [Phase 4 schema](../phase4-point-of-sale/phase4-schema.md).

---

## 1. Design principles

- Money is signed-capable integer `_cents`. Opening float, expected, and count are `>= 0`. Variance may be negative.
- Close and finalize persist **snapshots**. Do not add live cash counters.
- Open session: closing snapshots NULL. Closed session: closing snapshots NOT NULL.
- Open period: all `finalized_*` fields and `finalized_by_user_id` NULL. Finalized period: those fields NOT NULL.
- `NULL` means **not yet frozen**. Zero is a legitimate finalized result.
- Closed sessions and finalized periods are immutable in application code (`readonly?`) and by CHECK pairing.
- Calculation produces the close/Z snapshot. After close/finalize, the snapshot is authority; do not treat a later recomputation as a replacement.

---

## 2. `pos_sessions` additions

| Column | Type | Notes |
|---|---|---|
| `opening_float_cents` | bigint | null: false, default 0; `>= 0`; set at open; retained after close |
| `closing_expected_cash_cents` | bigint | null while open; `>= 0` when closed; **server-derived** at close |
| `closing_count_cents` | bigint | null while open; `>= 0` when closed; cashier-entered count only |
| `closing_variance_cents` | bigint | null while open; `count - expected` when closed; may be negative |

Existing columns (`status`, `opened_at`, `closed_at`, `lock_version`, FKs) are unchanged.

### CHECKs

Replace `pos_sessions_closed_at_matches_status` with a pairing that includes snapshots:

```text
(status = 'open' AND closed_at IS NULL
  AND closing_expected_cash_cents IS NULL
  AND closing_count_cents IS NULL
  AND closing_variance_cents IS NULL)
OR
(status = 'closed' AND closed_at IS NOT NULL
  AND closing_expected_cash_cents IS NOT NULL
  AND closing_count_cents IS NOT NULL
  AND closing_variance_cents IS NOT NULL)
```

Additional CHECKs:

```text
opening_float_cents >= 0
closing_expected_cash_cents IS NULL OR closing_expected_cash_cents >= 0
closing_count_cents IS NULL OR closing_count_cents >= 0
```

Closing columns are all-null or all-present (implied by the status pairing). Variance has no sign CHECK.

---

## 3. `pos_reporting_periods` additions

Z cash columns are **sums of independent session custody intervals**. They do not claim a single drawer held that amount at Z close.

### Commercial (from completed transactions)

| Column | Type | Notes |
|---|---|---|
| `finalized_transaction_count` | integer | null while open; `>= 0` when finalized |
| `finalized_subtotal_cents` | bigint | null while open; sum of completed `subtotal_cents` |
| `finalized_tax_cents` | bigint | null while open; sum of completed `tax_cents` |
| `finalized_total_cents` | bigint | null while open; sum of completed `total_cents` |
| `finalized_cash_payment_cents` | bigint | null while open; sum of completed cash payment `amount_cents` |

### Session-custody aggregates (from closed session snapshots)

| Column | Type | Notes |
|---|---|---|
| `finalized_session_count` | integer | null while open; `>= 0` when finalized |
| `finalized_opening_float_cents_sum` | bigint | null while open; sum of session `opening_float_cents` |
| `finalized_closing_expected_cash_cents_sum` | bigint | null while open; sum of session `closing_expected_cash_cents` |
| `finalized_closing_count_cents_sum` | bigint | null while open; sum of session `closing_count_cents` |
| `finalized_closing_variance_cents_sum` | bigint | null while open; `SUM(session.closing_variance_cents)`; may be negative |

### Actor

| Column | Type | Notes |
|---|---|---|
| `finalized_by_user_id` | uuid | FK → `users`; null while open; required when finalized |

`closed_at` remains the finalize timestamp (already required when `status = finalized`).

### CHECKs

Replace `pos_reporting_periods_closed_at_matches_status` with a pairing that includes every snapshot and `finalized_by_user_id`:

```text
(status = 'open' AND closed_at IS NULL
  AND finalized_by_user_id IS NULL
  AND all finalized_* snapshot columns IS NULL)
OR
(status = 'finalized' AND closed_at IS NOT NULL
  AND finalized_by_user_id IS NOT NULL
  AND all finalized_* snapshot columns IS NOT NULL)
```

Non-negative CHECKs on count, money, and sum fields when present, except `finalized_closing_variance_cents_sum` (signed).

---

## 4. Backfill

Existing closed sessions (dev/test) receive `opening_float_cents = 0` (column default) and closing snapshots of `0`. Existing finalized periods should not exist in production Phase 4 data; a reconstructive backfill is not required. If a finalized row is present in a local database while this migration is amended in place, drop and re-migrate rather than inventing drawer-chain totals.

---

## 5. Not in this schema

- Live `expected_cash_cents` on an open session
- A single-drawer `finalized_expected_cash_cents` (use `*_sum` aggregates)
- Drawer / till tables
- Z sequence number
- Paid-in / paid-out / transfer rows
- Session or period UI tables
