# Slice 2 — Manual verification evidence

Status: required for Slice 2 closeout alongside automated system coverage.

Workstation assumptions: Chrome (or Chromium) on a Register-class display, keyboard-wedge scanner optional, “Use F1–F12 as standard function keys” (or Fn) available on macOS.

## Checklist

| # | Case | Pass criteria | Result | Notes |
|---|---|---|---|---|
| 1 | High zoom (200%) on selector | Shell body scrolls; last Register **View** / **Resume** reachable by pointer and keyboard | Pass | |
| 2 | High zoom on Switch Register | Table and **Make Preferred** for last row reachable | Pass | |
| 3 | High zoom on closed Open Register with validation error | Opening float error visible; submit control reachable | Pass | |
| 4 | Prior-date warning + opening form | Warning and form both reachable without clipping under cluster | Pass | |
| 5 | Return to ShelfSense (same tab) | Header link stays in-tab; with owned session, confirm states session remains open | Pass | |
| 6 | Screen reader / form controls | Overlay fields (linked return, cancel, control approval) announce labels; command field not stealing while typing in overlay inputs | Pass | |
| 7 | Real browser navigation | Browser Back from ShelfSense return lands predictably; Register session still open | Pass | |
| 8 | Keyboard Lock in supported browser | After a click in the shell, F6–F9 reach Register (not browser chrome); graceful when Lock unavailable | Pass | |
| 9 | Scanner punctuation | `*`, `+`, `/`, `-`, `.` on empty command field still invoke workspace commands; digits in command field remain identifier text | Pass | |

## Sign-off

- Date: 2026-08-28
- Browser / OS: Mac
- Verified by: TSM
- Follow-ups (if any): None
