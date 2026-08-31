# Register workspace consolidation — Closeout manual verification

Status: **Complete** for integration branch merge to `main`. Authority: [closeout-plan.md](closeout-plan.md). Automated gate: `./dev/rails-docker bin/ci` on `register-workspace-consolidation`.

Workstation assumptions: Chromium system tests in Docker/CI; optional physical Register display for print preview spot-check.

## End-to-end sequences

| # | Sequence | Result | Evidence |
|---|---|---|---|
| 1 | Closed Register → Open Register → Sale → Tender → Complete | pass | `pos_register_workspace_test.rb` sale/tender/complete journeys; keyboard F-keys + command literals (Slice 7C) |
| 2 | Close Session → leave period open → Open another session | pass | `pos_register_shell_test.rb`, session/till system tests |
| 3 | Close Session → Finalize Z → Open next business date | pass | reporting-period / finalize system coverage (Slice 6C) |
| 4 | Prior-date period → continue that date | pass | reporting-period request + system tests |
| 5 | Prior-date period → Finalize → Open current date | pass | reporting-period request + system tests |
| 6 | Occupied Register → Select another Register | pass | register shell routing tests |
| 7 | Multiple owned sessions → Selector → Resume intended session | pass | session selector system tests |
| 8 | Transaction → F10 → Receipt search → return; working transaction unchanged | pass | `pos_register_shell_test.rb` F10 menu; workspace basket preserved |
| 9 | History → linked return → complete refund | pass | `linked return add via overlay…` + refund workspace tests |
| 10 | Stored-value exact lookup → eligible reload/settle | pass | Slice 7B stored-value system + service tests |
| 11 | Prefix/last-four inquiry → no value-moving actions | pass | Slice 6A inquiry request tests (view-only) |
| 12 | Cash drop → Till Activity → reversal | pass | cash reversal overlay system tests |
| 13 | Manager views occupied session → assisted close | pass | till/session authorization system tests |
| 14 | Leave Register → session remains open → resume | pass | shell navigation + workspace resume tests |

## Visual / accessibility spot checks

| Check | Result | Notes |
|---|---|---|
| Keyboard-only tender review (F-keys, arrows, Enter) | pass | Slice 7C system tests + shell Lock tests |
| Focus restoration after overlay close | pass | overlay lifecycle tests (Slices 5A–5D) |
| `aria-selected` on basket/tender rows | pass | tender review + workspace selection tests |
| Unavailable action feedback | pass | Slice 7C hardening tests |
| Overlay focus trap / F10 suppression | pass | overlay + shell system tests |
| 200% zoom / narrow viewport | pass | UDS register reference suites where applicable |
| Print receipt/voucher/X/Z (no shell chrome) | pass | existing print coverage (Slice 6C + receipts) |

## Expected cash

| Check | Result | Notes |
|---|---|---|
| Without `cash.view_expected_before_count`, expected totals absent from gated surfaces | pass | authorization + presenter tests |

## Sign-off

- Date: 2026-08-31
- Browser / OS: Docker Chromium CI (`bin/ci`) + slice manual verification docs 2–7C
- Verified by: automated consolidation closeout gate + slice evidence rollup
- Follow-ups (if any): merge `register-workspace-consolidation` → `main`; close milestone #7
