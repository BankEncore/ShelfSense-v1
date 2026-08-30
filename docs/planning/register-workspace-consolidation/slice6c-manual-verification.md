# Slice 6C — Manual verification evidence

Status: **pending** workstation sign-off. Inventory gate: **complete**. Implementation delivered on `92-reporting-period-surfaces`.

Workstation assumptions: Chrome (or Chromium) on a Register-class display; print preview available.

## Checklist

| # | Case | Pass criteria | Result | Notes |
|---|---|---|---|---|
| 0 | Inventory gate | Every P13 row has disposition; no `$0` for unsupported | Pass | Packet lock 2026-08-30 |
| 1 | X in shell (S20) | Open-session only; expected cash gated; GET immutable | | Shell frame + P13 |
| 2 | Session Details closed-session report | P13 on 6B route; no competing closed_sessions destination | | Redirect from `/closed` |
| 3 | Z status (S9) | Cumulative projection; view rules; structured blockers | | `/reporting_periods/:id/status` |
| 4 | Finalize GET (S10) | Read-only blockers; lock token; no mutate | | `/reporting_periods/:id/finalize` |
| 5 | Finalize POST | Revalidates; locks; once; immutable snapshot | | Reuses FinalizeReportingPeriod |
| 6 | Finalized Z (S11) | Snapshot-only authority; no live fallback | | Shell + omit fine SV |
| 7 | P13 consistency | Screen report + tape use same supported facts | | ShiftEndTape 42-col |
| 8 | Print X/Z/session | No F10, Return, status strips, dialogs | | `.pos-no-print` + print regions |
| 9 | Print receipt/voucher | No interactive shell chrome regression | | voucher hide rules |
| 10 | Print permission | Expected cash absent when unauthorized on print path | | X / current Z gated |

## Sign-off

- Date:
- Browser / OS:
- Verified by:
- Follow-ups (if any):
