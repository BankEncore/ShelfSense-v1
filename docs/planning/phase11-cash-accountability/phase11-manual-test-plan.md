# Phase 11 — Manual test plan

Status: **Proposed**. Complements automated tests in [phase11-user-stories.md](phase11-user-stories.md). Register and print checks need a browser.

Do not treat this as a substitute for CI.

## 1. Cutover and open

1. New store: Register enter fails until the safe is initialized.
2. Initialize the safe **without** an open POS session. Always a distinct second user with `cash.approve_initialize_safe` — even when the performer also holds that key. Self-approval is rejected. Expected safe cash equals the count.
3. Second initialize rejected. Ordinary reverse of initialization is unavailable.
4. Open session with float less than safe expected; safe decreases; session `opening_float_cents` matches.
5. Open with float greater than safe expected — blocked.
6. Two cashiers race the same register — one open session.
7. Open $0 float; no transfer/operation/entries; cash sale with change still completes; cash refund blocked until replenish.

## 2. Available cash and cash-out

1. Replenish, then cash refund up to available; one cent over blocked.
2. Gift-card cash-out blocked at $0 session; succeeds after replenish; expected cash falls by the cash-out.
3. Two concurrent cash-outs/refunds cannot both take the last cent.
4. Card-only sale still requires the open session.

## 3. Close

1. Blind close: expected hidden until submit (without `cash.view_expected_before_count`).
2. Zero variance: counted transfer to safe equals expected; snapshots match; Z still shows opening float and closing expected as today.
3. Short: variance negative; short movement; safe receives counted amount not expected.
4. Over: safe receives counted amount; over movement on the session.
5. Variance bands (seeded defaults): $0.50 over/short needs a reason code only; $1.00 also needs a free-text note; $10.00 needs a different approver unless the closer has `cash.approve_variance` (`direct`). Never record the same user as both performer and approver.
6. Working ticket blocks close (existing).
7. Manager closes another cashier’s session with reason; cashier unchanged; closer audited; counted cash in safe.
8. Closed session cannot receive drop/paid-in.

## 4. Non-sale (after 11.2)

1. Paid-in reason; expected up; not on the receipt as a tender.
2. Paid-out at/above threshold: performer with `cash.approve_paid_out` is `direct`; otherwise a different user with that key. Insufficient cash blocked.
3. Drop mid-shift; replenish other session from safe; session-to-session rejected.
4. Reverse paid-out once; original paid-out row unchanged; reverse has no new paid-in/paid-out source row; second reverse rejected.

## 5. Safe and deposit (after 11.3)

1. All sessions balanced; safe still short/over — stays a safe variance.
2. Start a safe count, then post an opening float (or drop) before submit — stale count rejected; staff recount.
3. Zero-variance recon: no `cash_reconciliations` row; store-day still shows safe reconciled for that date.
4. Recon then retain overnight; next business date opens.
5. Prepare deposit; safe down; DIT up; no bank screen.
6. Reverse a prepared deposit: safe increases, DIT decreases; original deposit remains immutable and visibly reversed; double reverse fails; reverse fails if DIT expected is insufficient.
7. Store-day report lists that date’s deposits individually; DIT location balance is cumulative and is not treated as cash still in the store. An open session shows incomplete, not a hard error that blocks tomorrow.

## 6. Regression

1. X/Z merchandise and stored-value sections unchanged in meaning.
2. Gift-card cash-out receipt still not a tender line.
3. Ordinary Print receipt still masked for gift-card numbers.
