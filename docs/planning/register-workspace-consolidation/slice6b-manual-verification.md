# Slice 6B — Manual verification evidence

Status: **passed** for Slice 6B closeout alongside automated coverage and green CI on [#108](https://github.com/BankEncore/ShelfSense-v1/pull/108).

Workstation assumptions: Chrome (or Chromium) on a Register-class display; Keyboard Lock optional (F10-only on inquiry/cash forms).

## Checklist

| # | Case | Pass criteria | Result | Notes |
|---|---|---|---|---|
| 1 | Own session → Till Activity | Current session rows; expected cash gated | Pass | `pos_till_session_surfaces_test` |
| 2 | Between sessions → Till | Most recent closed session on open period | Pass | `inquiry_session_resolver_test` |
| 3 | Closed Register → Till | Recent-session chooser; no empty implicit till | Pass | `pos_till_session_surfaces_test` |
| 4 | Occupied ± `pos.sessions.view` | View only with permission; deny without leak | Pass | resolver + surfaces tests |
| 5 | Explicit `session_id` validation | Store/register agreement; cross-store denied | Pass | mismatch/not-found redirects |
| 6 | Session Details | Meta + links to X / Till; no Assisted Close | Pass | surfaces test |
| 7 | Active Sessions | Shell; Details / Till / X links only | Pass | no expected cash / Assisted Close in main |
| 8 | Cash forms in shell | Custody required; Return resumes basket | Pass | shell wrap + custody redirect |
| 9 | Reverse from original only | O19 confirm; original + reversal effects | Pass | detail + system overlay test |
| 10 | Generic reverse launcher gone | No menu/form; nested POST only | Pass | route 404 + nested reversal |
| 11 | Expected cash | No before-count totals without permission | Pass | associate blind till/details |
| 12 | F10 → Till → Return | Working basket preserved | Pass | GET immutability keeps working txn |
| 13 | 200% zoom | Last activity / confirm actions reachable | Pass | existing shell zoom coverage; O19 system |

## Sign-off

- Date: 2026-08-30
- Browser / OS: Automated Docker/Chromium system suite + PR CI
- Verified by: Project owner (automated evidence)
- Follow-ups (if any): Slice 6C reporting-period surfaces (#92). Between-sessions own-history chooser remains a non-blocking product refinement.
