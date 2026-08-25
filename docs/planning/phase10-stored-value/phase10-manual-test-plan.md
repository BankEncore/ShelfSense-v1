# Phase 10 — Manual test plan

Status: **Proposed**. Complements automated tests in [phase10-user-stories.md](phase10-user-stories.md). Register and print checks need a browser; admin checks use current UDS screens once they exist.

Do not treat this as a substitute for CI.

## 1. Register — issuance and tenders

1. Activate a manual-number card with merchandise in one ticket; amount due = merchandise + tax + issuance; receipt shows issuance separately; last four only on reprint.
2. Activate a system-generated card; first print shows full number; reprint is masked.
3. Kill the client after complete before print; retry complete; first-print path still available without a second liability.
4. Reload an existing card; remaining balance increases only after complete; abandon working ticket has no effect.
5. Redeem gift card partial + cash; split SV tenders on two cards.
6. Attach customer; redeem store credit; refuse merged or inactive customer.
7. Redeem trade credit issued by admin adjust.
8. Attempt activate + redeem in one ticket — blocked.
9. Attempt reload + redeem in one ticket — blocked.
10. Two Registers race the last cent on one card — one succeeds.

## 2. Refunds, unused return, post-void

1. Return merchandise; allocate remainder to store credit; customer required; trade credit not offered.
2. Unused-instrument return of a never-spent activation; cash refund; card cannot redeem afterward.
3. Attempt unused return after a redeem — blocked.
4. Post-void a pure cash sale (existing) — still works.
5. Post-void a ticket that activated a card later redeemed — blocked; no partial void; lineage visible.
6. Post-void a ticket whose only SV effect is unused-return — follow fail-closed rules if already returned.

## 3. Cash-out and closeout

1. Cash-out full eligible balance with `gift_cards.cash_out`; associate cannot.
2. Expected cash on open session drops by cash-out; X and Z show the row.
3. Close session; reopen view; expected cash frozen.
4. Reverse/post-void eligible cash-out; expected cash restores.
5. `required_on_request_when_eligible` does not auto-payout without cashier confirmation.

## 4. Admin, merge, security

1. Customer show balances require `stored_value.view_activity`.
2. Manual debit requires second user; self-approve fails.
3. Deactivate customer with nonzero store credit — warn/block.
4. Merge two customers with store credit — one survivor balance; source closed; activity lineage; concurrent redeem does not skip the transfer.
5. Gift-card association follows merge; balance stays on the instrument.
6. Failed inquiry throttle; lists never show full numbers.
7. Reveal requires global permission; audit has last four only.
8. Lookup code colliding with program prefix cannot be saved.

## 5. Navigation and UDS

1. Gift-card programs appear in `Admin::NavigationCatalog` for authorized users only.
2. New admin screens use current composition primitives.
3. Register issuance is on the POS shell, not admin chrome.
