# Slice 7A — Manual verification evidence

Status: **Complete** on `register-workspace-consolidation`. Implementation [#115](https://github.com/BankEncore/ShelfSense-v1/pull/115); remediation [#116](https://github.com/BankEncore/ShelfSense-v1/pull/116) (card remove-only, arrow scope, selection persistence, O15–O17 Enter/Escape). Issue [#93](https://github.com/BankEncore/ShelfSense-v1/issues/93) closed. Packet: [slice7a-tender-review-plan.md](slice7a-tender-review-plan.md).

Workstation assumptions: Chrome (or Chromium) on a Register-class display; print not required for 7A.

## Checklist

| # | Case | Pass criteria | Result | Notes |
|---|---|---|---|---|
| 1 | Enter Tender Review | ≥1 tender → review chrome; settlement label correct | pass | presenter + system |
| 2 | Selection | One selected; `aria-selected`; survives Turbo; nearest after remove | pass | integration (incl. tender-add) + system |
| 3 | Ordinary remove (O16) | Confirm; tender gone; lease replay safe | pass | service + system Enter/Escape |
| 4 | Cash / check / other replace (O15) | Presented/applied/change where applicable; failure keeps original | pass | service + system (check) |
| 5 | Card | Edit withheld; Remove available; forged replace refused | pass | presenter + service + integration/system (#116) |
| 6 | SV inspect-only | Select/inspect; no Edit/Remove; reason shown | pass | presenter + service refuse |
| 7 | Return to Sale ordinary | O17 clears ordinary tenders atomically | pass | service + system |
| 8 | Return to Sale with SV | Refused with explanation | pass | service |
| 9 | F10 round-trip | Working basket/tenders preserved | pass | prior coverage; unchanged by 7A |
| 10 | Pointer + keyboard | Tab/Enter/pointer select; arrows scoped to tender listbox | pass | system (#116) |
| 11 | No new global shortcuts | No temporary document-level key maps | pass | Phase 6.7 + existing `+`; arrows not global |

## Sign-off

- Date: 2026-08-30
- Browser / OS: CI Chromium system tests + focused Docker suite; manual code review on #115/#116
- Verified by: automated 7A suite + CI green + code review
- Follow-ups (if any): Slice 7B ([#94](https://github.com/BankEncore/ShelfSense-v1/issues/94))
