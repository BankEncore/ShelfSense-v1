# Slice 6B — Manual verification evidence

Status: **pending** until 6B.1–6B.3 land and workstation/CI evidence is recorded.

Workstation assumptions: Chrome (or Chromium) on a Register-class display; Keyboard Lock optional (F10-only on inquiry/cash forms).

## Checklist

| # | Case | Pass criteria | Result | Notes |
|---|---|---|---|---|
| 1 | Own session → Till Activity | Current session rows; expected cash gated | | |
| 2 | Between sessions → Till | Most recent closed session on open period | | |
| 3 | Closed Register → Till | Recent-session chooser; no empty implicit till | | |
| 4 | Occupied ± `pos.sessions.view` | View only with permission; deny without leak | | |
| 5 | Explicit `session_id` validation | Store/register agreement; cross-store denied | | |
| 6 | Session Details | Meta + links to X / Till; no Assisted Close | | |
| 7 | Active Sessions | Shell; Details / Till / X links only | | |
| 8 | Cash forms in shell | Custody required; Return resumes basket | | |
| 9 | Reverse from original only | O19 confirm; original + reversal effects | | |
| 10 | Generic reverse launcher gone | No menu/form; nested POST only | | |
| 11 | Expected cash | No before-count totals without permission | | |
| 12 | F10 → Till → Return | Working basket preserved | | |
| 13 | 200% zoom | Last activity / confirm actions reachable | | |

## Sign-off

- Date:
- Browser / OS:
- Verified by:
- Follow-ups (if any):
