# Slice 7A — Manual verification evidence

Status: **pending** until 7A.1–7A.3 land and workstation/CI evidence is recorded. Packet: [slice7a-tender-review-plan.md](slice7a-tender-review-plan.md).

Workstation assumptions: Chrome (or Chromium) on a Register-class display; print not required for 7A.

## Checklist

| # | Case | Pass criteria | Result | Notes |
|---|---|---|---|---|
| 1 | Enter Tender Review | ≥1 tender → review chrome; settlement label correct | | |
| 2 | Selection | One selected; `aria-selected`; survives Turbo; nearest after remove | | |
| 3 | Ordinary remove (O16) | Confirm; tender gone; lease replay safe | | |
| 4 | Cash replace (O15) | Presented/applied/change; failure keeps original | | |
| 5 | Card / check / other replace | Per family rules; card is remove + re-record | | |
| 6 | SV inspect-only | Select/inspect; no Edit/Remove; reason shown | | |
| 7 | Return to Sale ordinary | O17 clears ordinary tenders atomically | | |
| 8 | Return to Sale with SV | Refused with explanation | | |
| 9 | F10 round-trip | Working basket/tenders preserved | | |
| 10 | Pointer + keyboard | Tab/Enter/pointer can select and open actions | | |
| 11 | No new global shortcuts | No temporary document-level key maps | | |

## Sign-off

- Date:
- Browser / OS:
- Verified by:
- Follow-ups (if any):
