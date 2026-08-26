# Phase 11 — Manual test plan

Status: **Proposed**. Complements automated tests in [phase11-user-stories.md](phase11-user-stories.md). Register and print checks need a browser.

Do not treat this as a substitute for CI.

## 1. Cutover and open

1. New store: Register enter fails until the safe is initialized.
2. Initialize safe with a count and second user; expected safe cash equals the count.
3. Second initialize rejected.
4. Open session with float less than safe expected; safe decreases; session `opening_float_cents` matches.
5. Open with float greater than safe expected — blocked.
6. Two cashiers race the same register — one open session.
7. Open $0 float; cash sale with change still completes; cash refund blocked until replenish.

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
5. Material variance requires a different approver.
6. Working ticket blocks close (existing).
7. Manager closes another cashier’s session with reason; cashier unchanged; closer audited; counted cash in safe.
8. Closed session cannot receive drop/paid-in.

## 4. Non-sale (after 11.2)

1. Paid-in reason; expected up; not on the receipt as a tender.
2. Paid-out above threshold needs second user; insufficient cash blocked.
3. Drop mid-shift; replenish other session from safe; session-to-session rejected.
4. Reverse paid-out once; second reverse rejected.

## 5. Safe and deposit (after 11.3)

1. All sessions balanced; safe still short/over — stays a safe variance.
2. Safe recon lock: open-float during recon rejected.
3. Recon then retain overnight; next business date opens.
4. Prepare deposit; safe down; DIT up; no bank screen.
5. Store-day report shows open session as incomplete, not a hard error that blocks tomorrow.

## 6. Regression

1. X/Z merchandise and stored-value sections unchanged in meaning.
2. Gift-card cash-out receipt still not a tender line.
3. Ordinary Print receipt still masked for gift-card numbers.
