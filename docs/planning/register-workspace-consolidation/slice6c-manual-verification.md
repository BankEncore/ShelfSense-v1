# Slice 6C — Manual verification evidence

Status: **pending** workstation evidence until 6C.1–6C.3 land. Inventory gate: **complete** ([report-content-inventory.md](report-content-inventory.md); 2026-08-30; snapshot extensions: none).

Workstation assumptions: Chrome (or Chromium) on a Register-class display; print preview available.

## Checklist

| # | Case | Pass criteria | Result | Notes |
|---|---|---|---|---|
| 0 | Inventory gate | Every P13 row has disposition; no `$0` for unsupported | Pass | Packet lock 2026-08-30 |
| 1 | X in shell (S20) | Open-session only; expected cash gated; GET immutable | | |
| 2 | Session Details closed-session report | P13 on 6B route; no competing closed_sessions destination | | |
| 3 | Z status (S9) | Cumulative projection; view rules; structured blockers | | |
| 4 | Finalize GET (S10) | Read-only blockers; lock token; no mutate | | |
| 5 | Finalize POST | Revalidates; locks; once; immutable snapshot | | |
| 6 | Finalized Z (S11) | Snapshot-only authority; no live fallback | | |
| 7 | P13 consistency | Screen report + tape use same supported facts | | |
| 8 | Print X/Z/session | No F10, Return, status strips, dialogs | | |
| 9 | Print receipt/voucher | No interactive shell chrome regression | | |
| 10 | Print permission | Expected cash absent when unauthorized on print path | | |

## Sign-off

- Date:
- Browser / OS:
- Verified by:
- Follow-ups (if any):
