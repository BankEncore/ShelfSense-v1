# Phase 11 — Session lifecycle

Status: **Implemented** on `main`. Implementation authority for 11.1. Extends [phase5-plan.md](../phase4-6-point-of-sale/phase5-cash-register/phase5-plan.md) and [phase10-reporting-closeout.md](../phase10-stored-value/phase10-reporting-closeout.md).

### Actually locked

```text
session remains open | closed
Register does not hold cash between sessions
opening_float_cents is a snapshot (transfer only when float > 0)
closing_expected_cash_cents is expected before recon and transfer
counted amount transfers to the safe
available cash = expected session cash
gift-card cash-out is not a paid-out
every POS complete still needs an open session
```

## 1. Safe cutover

Each store has one `cash_locations` row with `location_type = safe`. Until `initialize_safe` succeeds, `OpenSession` fails.

Initialization is **one-time**: counted total (denomination lines optional), effective business date, notes, `cash_operations.operation_type = initialize_safe`. Not a paid-in. Always `approval_required`: a distinct user with `cash.approve_initialize_safe` authenticates, regardless of amount and even if the performer also holds that key. It **cannot** be reversed through `Cash::Reverse`. A second initialize is rejected. Mistakes after init are corrected with `cash.reconcile_safe`.

The screen is usable **without** an open POS session. Production rollout is a coordinated maintenance window: migrate (uninitialized locations) → initialize every active store → then cashiers open. Do not infer a safe balance from historical close snapshots. Detail: [phase11-implementation-plan.md](phase11-implementation-plan.md) **Production cutover**.

Bootstrap, demo, and tests initialize the safe before any session open so local Register enter still works.

Historical closed sessions keep their float/close snapshots with **no** backfilled `cash_transfers`.

## 2. Open

`Pos::OpenSession` (same actor = `cashier_user_id`):

1. Lock store safe then create session (deterministic lock order documented in `Cash::Post`).
2. Require initialized safe, active register, open reporting period, no other open session on the register.
3. Accept opening count total (optional denomination lines summing to total when present).
4. If the float is **positive**, post `cash_transfers.transfer_type = opening_float` for that amount: −safe, +session. Persist `opening_float_cents` equal to the transfer.
5. If the float is **zero**, persist `opening_float_cents = 0` and create **no** operation, transfer, or entries.

Insufficient safe expected cash rejects a positive-float open. Concurrent second open on the same register still hits the existing unique open-session index.

A later cash refund or cash-out still requires replenishment first when available cash is zero.

## 3. Expected and available cash

Live (open) `Pos::SessionTotals#expected_cash_cents`:

```text
opening_float_cents
+ completed cash payment tenders
- completed cash refund tenders
- gift_card_cash_outs originals + reversals for this session
+ paid-ins + replenishments posted to this session
- paid-outs - drops posted to this session
```

Do **not** include the close over/short in the live formula before close; that recognition is part of close.

`available_cash_cents = expected_cash_cents` while open.

Must fail (and must not post) when the operation would make expected session cash negative:

- cash **refund** tenders (at complete, under session lock)
- `GiftCards::CashOut`
- paid-outs and drops (11.2)

Must **not** fail solely because a cash **sale** tenders change. Phase 5: `pos_tenders.amount_cents` is net in the drawer.

Operator copy when blocked:

> This register session does not have enough available cash. Replenish it from the safe or choose another permitted payout method.

This is an intentional migration: today’s $0-float cash refund and cash-out paths become illegal until replenishment.

Gift-card cash-out remains `gift_card_cash_outs` + stored-value `cash_out`. Phase 11 only adds the available-cash gate and uses the same session lock. Do not also insert a paid-out.

Cash-out **reversal** still requires physical return of cash onto an **open** session (Phase 10). That session’s expected cash increases; it is not a bookkeeping-only reversal.

## 4. Close

Statuses stay `open` → `closed`. During `CloseSession`, lock the session (and safe when transferring). Revalidate that no new completed cash-affecting fact appeared after the count was taken (lock_version / expected hash of session cash sources). A failed close that posted nothing leaves the session `open`. Do not add `closing` for Terminal sync.

Sequence:

1. Forbid working transactions (existing).
2. Compute expected cash (formula above, still open).
3. Accept closing count total (optional denominations). Ordinary staff are blind until submit. `cash.view_expected_before_count` may reveal expected.
4. Persist `closing_expected_cash_cents`, `closing_count_cents`, `closing_variance_cents` with the **existing** CHECK (`variance = count − expected`).
5. If variance ≠ 0: post `reconcile` (session over/short). **Any nonzero** over/short requires a managed reason code. A free-text note is required when `abs(variance) >=` the effective note threshold. Material variance (`abs(variance) >=` the effective approval threshold) uses `cash.approve_variance`: `direct` when the closer also holds that key; otherwise a different authorized approver authenticates. Never persist `approved_by_id = performed_by_id`. This aligns session expected with counted **after** the snapshot is stored.
6. Post `cash_transfers.transfer_type = session_close` for the **counted** amount: session → safe. Mid-shift `drop` remains 11.2.
7. Set `closed_by_user_id`, `closed_at`, `status = closed`.
8. Session location balance is zero. Closed `SessionTotals` still return the **snapshots**, not zero expected.

Example: expected $500, counted $480 → snapshot expected 500, count 480, variance −20; short $20; transfer $480 to safe. With seeded defaults that $20 is material (reason code + note + approval unless the closer is `direct`). A $0.50 short needs a reason code only; a $1.00 short also needs a free-text note.

## 5. Manager-assisted close

When the assigned cashier cannot close and the open session blocks the register and Z:

- Permission `pos.sessions.close_for_other`.
- `cashier_user_id` unchanged.
- `closed_by_user_id` = manager.
- Reason required.
- Same count, snapshot, over/short, and counted transfer rules.
- Prominently audited (`pos.session.closed` with closer ≠ cashier).
- Does not authorize selling or cash-out on that session (`require_session_cashier!` remains for tenders and `GiftCards::CashOut`).

No takeover state machine.

## 6. Z and reporting periods

Unchanged gates: no open sessions, complete close snapshots. Sums:

- `finalized_opening_float_cents_sum` = sum of session `opening_float_cents`
- `finalized_closing_expected_cash_cents_sum` = sum of pre-recon expected snapshots
- `finalized_closing_count_cents_sum` / variance sum unchanged in meaning

Do not replace Z with store-day finalization. Multiple sessions per period remain allowed (Phase 5 ordinary path is one; manager close may create a second).

## 7. Tests that must move with 11.1

- Existing close/Z snapshot suites: keep snapshot meaning.
- `pos_linked_return_workspace_test` negative expected close: replenish or assert the new available-cash error.
- `GiftCards::CashOut` with insufficient session cash.
- Open fails without initialized safe; open fails when safe expected < float.
- Close transfers counted, not pre-count expected.
- Concurrent refunds/cash-outs cannot both spend the last cent.
- Manager close vs cashier close audit fields.
- Zero-float open creates no transfer row.
- Safe init is available without an open session; always a distinct approver; second init rejected.
