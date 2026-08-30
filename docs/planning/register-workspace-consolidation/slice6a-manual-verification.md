# Slice 6A — Manual verification evidence

Status: **pending** until 6A.1–6A.3 land and workstation/CI evidence is recorded.

Workstation assumptions: Chrome (or Chromium) on a Register-class display; Keyboard Lock optional (F10-only on inquiry).

## Checklist

| # | Case | Pass criteria | Result | Notes |
|---|---|---|---|---|
| 1 | F10 → Transactions & Receipts | Opens inside shell; Close returns per ownership rules | | |
| 2 | History without open session | View OK; GET creates no session/period | | |
| 3 | Occupied Register → history Close | Returns to occupied state; never other cashier workspace | | |
| 4 | Own session → history → Close | Returns to owned workspace; basket preserved | | |
| 5 | Receipt detail entry chrome | Post-void / Return items link to existing flows | | |
| 6 | Print / reprint receipt | No F10, Return, or shell status in print output | | |
| 7 | S14 exact-number POST | Balance/activity; no full number in URL/HTML/history | | |
| 8 | S14 store credit | Customer path; no possession Lookup | | |
| 9 | S14 prefix/last-four | Masked only; no tender/reload/cash-out actions | | |
| 10 | S14 continuations | Tender/reload/cash-out only when context legal; invoke existing flows | | |
| 11 | S15 Customer Summary | Read-only; Open Customer when authorized; no attach | | |
| 12 | S16 Pickup Queue | View-only; no Add to Transaction | | |
| 13 | Inquiry Keyboard Lock | F10 only; F1–F9 not claimed | | |
| 14 | Menu register_id | Inquiry links preserve register context | | |
| 15 | Expected cash | No before-count expected totals without permission | | |

## Sign-off

- Date:
- Browser / OS:
- Verified by:
- Follow-ups (if any):
