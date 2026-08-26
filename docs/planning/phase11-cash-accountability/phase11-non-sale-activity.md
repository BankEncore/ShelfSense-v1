# Phase 11 — Non-sale cash activity

Status: **Proposed**. Implementation authority for 11.2. Depends on 11.1 posting, session lock, and available-cash.

### Actually locked

```text
paid-in and paid-out are not tenders
gift-card cash-out is not a paid-out
drop and replenishment are atomic completed transfers
no session-to-session transfer
reasons snapshot code and display name
reversals use reversal_of_id and have no source row
```

## 1. Paid-in

Cash enters the open session for a catalog reason other than a POS tender or a transfer. Requires `cash.paid_in`, open session, amount > 0, reason, notes when the reason requires them. Paid-in has **no** amount threshold in MVP.

Increases expected session cash. Does not increase sales.

## 2. Paid-out

Authorized non-sale disbursement from the open session. Requires `cash.paid_out`, permitted reason, available cash, notes when required. Amount at or above the effective store/org paid-out threshold is `approval_required` unless the performer also has `cash.approve_paid_out` (`direct`). `cash.paid_out` does not imply `cash.approve_paid_out`.

Decreases expected session cash. Refunds, gift-card cash-outs, buyback payouts, drops, and session-close transfers are not paid-outs.

## 3. Drop

Mid-shift session→safe transfer (`transfer_type = drop`). Own-session cashier uses `pos.transact`. Amount > 0 and ≤ available session cash. Atomic: −session +safe.

Distinct from `session_close`, which moves **counted** cash at close.

## 4. Replenishment

Safe→open session (`transfer_type = replenishment`). Requires `cash.move`. Safe expected cash must cover the amount. Used when a $0 or low session must pay a refund or cash-out.

## 5. Direct session-to-session

Prohibited. Path is drop (or close) to safe, then replenish the destination session.

## 6. Reasons

`cash_activity_reasons` for paid-in, paid-out, over, short, reverse. Deactivate rather than delete. Posted facts keep `reason_code` and `reason_name_snapshot`.

## 7. Reversal and replacement

Completed Phase 11 operations are never edited.

`Cash::Reverse` posts a new `cash_operations` row with `operation_type = reverse` and `reversal_of_id` pointing at the original operation. Each inverse `cash_entry.reversal_of_id` points at the original entry. Transfers reverse both legs atomically. The original source row is **unchanged**. The reverse has **no** fabricated transfer, paid-in, paid-out, reconciliation, initialization, or deposit source row. Reason and notes live on the reverse operation. The original source exposes reversal through the operation relationship (`reversed_by`). Do not add a `cash_reversals` table in MVP.

Double reverse is rejected. Reverse is refused if it would make a location or open session negative.

Closed sessions stay closed. Close snapshots are never rewritten. Do **not** reverse `session_close` or session over/short in MVP; correct store cash with a later safe reconciliation. Do **not** reverse `initialize_safe`. Paid-in/out, drop, replenishment, and deposit (while still in transit) may be reversed.

## 8. Concurrency

Same as 11.1: lock locations then sessions in UUID order; revalidate available cash after lock; idempotent retries; two drops/payouts cannot share the last cent.
