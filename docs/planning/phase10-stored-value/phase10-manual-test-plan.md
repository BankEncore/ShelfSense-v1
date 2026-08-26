# Phase 10 — Manual test plan

Status: **Proposed**. Complements automated tests in [phase10-user-stories.md](phase10-user-stories.md). Register and print checks need a browser; admin checks use current UDS screens once they exist.

Do not treat this as a substitute for CI.

## 1. Register — issuance and tenders

1. Activate a manual-number card with merchandise in one ticket; amount due = merchandise + tax + issuance; receipt shows issuance separately; last four only on reprint.
2. Activate a system-generated card; on-screen list and **Print gift card** voucher show the full number; **Print receipt** is masked; refresh or reopen the completed-transaction page is masked; reprint is masked.
3. Kill the client after complete before print; retry complete; first-print path still available without a second liability; after the first successful first print, recovery requires `gift_cards.recover_print`.
4. Reload an existing card; remaining balance increases only after complete; abandon working ticket has no effect.
5. Redeem gift card partial + cash; split SV tenders on two cards.
6. Attach customer via Register search (not UUID paste); change or clear on a working ticket; redeem store credit; refuse merged or inactive customer; pickup does not auto-attach.
7. Redeem trade credit issued by admin adjust.
8. Attempt activate + redeem in one ticket — blocked.
9. Attempt reload + redeem in one ticket — blocked.
10. Two Registers race the last cent on one card — one succeeds.

## 2. Refunds and post-void

1. Original gift card present and matching — refund original; remaining on that card increases.
2. Wrong gift card presented — blocked; masked history is not sufficient.
3. Original gift card unavailable → new generated refund card; first print shows full number; not an issuance; `stored_value_issuance_cents` unchanged; amount cannot exceed remaining gift-card-funded portion.
4. Original unavailable → manually numbered refund card, still capped at remaining gift-card-funded portion.
5. Original unavailable → customer store credit (customer required).
6. New refund card complete retry creates only one instrument/liability.
7. Trade credit is not offered as a generic destination.
8. Trade-credit original-tender portion may return to the original trade account.
9. Post-void a pure cash sale (existing) — still works.
10. Post-void a ticket that activated a card later redeemed — blocked; no partial void; lineage visible; card need not be presented.

## 3. Cash-out and closeout

1. Cash-out full eligible balance with `gift_cards.cash_out`; associate cannot.
2. Expected cash on open session drops by cash-out; X and Z show the row.
3. Close session; reopen view; expected cash frozen.
4. Reverse/post-void eligible cash-out; expected cash restores.
5. `required_on_request_when_eligible` does not auto-payout without cashier confirmation.
6. `cash_out_approval_required` requires second user.

## 4. Transfers

1. Partial same-type transfer.
2. Full transfer.
3. Account consolidation closes source.
4. Customer merge transfer; zero-balance source accounts close without creating a survivor account.
5. Cross-type transfer blocked.
6. Reversal after destination spend blocked.
7. Concurrent destination redemption/transfer serialized.

## 5. Adjustments

1. Customer-service credit.
2. Debit with second user.
3. Threshold credit approval.
4. Self-approval blocked.
5. Active gift-card adjustment.
6. Suspended gift-card elevated adjustment.
7. Replaced/closed gift-card adjustment blocked.
8. Adjustment reversal after spend blocked.

## 6. Encryption and print

1. Database stores ciphertext, not the normalized number.
2. Digest lookup succeeds.
3. Repeated encrypted writes do not rely on ciphertext equality.
4. Logs/audit/outbox/envelope omit full number.
5. Ordinary reprint masked.
6. Controlled retry prints original credential.
7. Print recovery requires reason and `gift_cards.recover_print`; no general reveal screen.

## 7. Admin, merge, security

1. Customer show balances require `stored_value.view_activity`; per-account history paginates; closed accounts remain in history; gift-card show lists masked entries.
2. Deactivate customer with nonzero store credit — warn/block.
3. Gift-card association follows merge; balance stays on the instrument.
4. Failed inquiry throttle; lists never show full numbers. Prefix + last-four unique match opens the card; collisions show a masked candidate list; POS redeem with prefix + last four does not resolve.
5. Lookup code colliding with program prefix cannot be saved.

## 8. Navigation and UDS

1. Gift-card programs appear in `Admin::NavigationCatalog` for authorized users only.
2. New admin screens use current composition primitives.
3. Register issuance is on the POS shell, not admin chrome.
