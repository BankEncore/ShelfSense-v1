# Register workspace consolidation — Closeout

Status: **Complete** — evidence in [closeout-manual-verification.md](closeout-manual-verification.md). Integration branch merged to `main` ([#129](https://github.com/BankEncore/ShelfSense-v1/pull/129) / `a563e0c`).

Complements automated tests. Register zoom, print, and keyboard-only checks need a browser.

## Domain regression

All existing service/model tests for reporting periods, sessions, transactions, returns, tendering, stored value, cash, completion, receipts, X/Z, authorization, and concurrency must remain green (`./dev/rails-docker bin/ci`).

## End-to-end request / manual sequences

1. Closed Register → Open Register → Sale → Tender → Complete
2. Close Session → leave period open → Open another session
3. Close Session → Finalize Z → Open next business date
4. Prior-date period → continue that date
5. Prior-date period → Finalize → Open current date
6. Occupied Register → Select another Register
7. Multiple owned sessions → Selector → Resume the intended session
8. Transaction → F10 → Receipt search → return; working transaction unchanged
9. History → linked return → complete refund
10. Stored-value exact lookup → eligible reload/settle
11. Prefix/last-four inquiry → no value-moving actions
12. Cash drop → Till Activity → reversal
13. Manager views occupied session → assisted close
14. Leave Register (Return to ShelfSense) → session remains open → resume

## Visual / accessibility evidence

Supported Register resolution; 200% zoom; narrow viewport; long content; large basket; many tenders; keyboard-only; pointer-only; focus restoration; print receipt/voucher/X/Z (shell controls excluded from print). Physical drawer/printer where automation cannot establish output.

## Expected cash

Without `cash.view_expected_before_count`, expected till totals are absent from shell, Till Activity, X/session details, cash forms, and close-before-submit. Operation effect lines may still appear.
