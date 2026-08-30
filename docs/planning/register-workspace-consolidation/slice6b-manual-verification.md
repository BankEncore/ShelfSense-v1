# Slice 6B — Manual verification evidence

Status: **pending** until Slice 6B implementation lands.

Workstation assumptions: Chrome (or Chromium) on a Register-class display; Keyboard Lock optional (F10-only on inquiry).

## Checklist

| # | Case | Pass criteria | Result | Notes |
|---|---|---|---|---|
| 1 | Till Activity own session | Current till; expected cash gated | | |
| 2 | Till Activity historical | Between/closed shows history without inventing till | | |
| 3 | Reverse from original only | No reverse on reversal; confirm shows effect | | |
| 4 | Reverse commit revalidation | Custody + cash availability; idempotent | | |
| 5 | Generic reverse launcher gone | No menu/route UI; service remains | | |
| 6 | Cash forms in shell | Paid-in/out/drop/replenish/cash-out fit | | |
| 7 | Session Details / Active Sessions | Permission + ownership rules | | |
| 8 | Print/detail expected cash | No before-count leak without permission | | |

## Sign-off

- Date:
- Browser / OS:
- Verified by:
- Follow-ups (if any):
