# Slice 7A — Manual verification evidence

Status: **automated coverage landed** with 7A.1–7A.3 (presenter, mutation services, integration, system). Workstation sign-off optional for residual UX. Packet: [slice7a-tender-review-plan.md](slice7a-tender-review-plan.md).

Workstation assumptions: Chrome (or Chromium) on a Register-class display; print not required for 7A.

## Checklist

| # | Case | Pass criteria | Result | Notes |
|---|---|---|---|---|
| 1 | Enter Tender Review | ≥1 tender → review chrome; settlement label correct | automated | presenter + system |
| 2 | Selection | One selected; `aria-selected`; survives Turbo; nearest after remove | automated | integration/system |
| 3 | Ordinary remove (O16) | Confirm; tender gone; lease replay safe | automated | service + system |
| 4 | Cash replace (O15) | Presented/applied/change; failure keeps original | automated | service |
| 5 | Card / check / other replace | Per family rules; card is remove + re-record | automated | service |
| 6 | SV inspect-only | Select/inspect; no Edit/Remove; reason shown | automated | presenter + service refuse |
| 7 | Return to Sale ordinary | O17 clears ordinary tenders atomically | automated | service + system |
| 8 | Return to Sale with SV | Refused with explanation | automated | service |
| 9 | F10 round-trip | Working basket/tenders preserved | prior coverage | unchanged by 7A |
| 10 | Pointer + keyboard | Tab/Enter/pointer can select and open actions | automated | system selection/arrows |
| 11 | No new global shortcuts | No temporary document-level key maps | reviewed | Phase 6.7 + existing `+` only |

## Sign-off

- Date: 2026-08-30
- Browser / OS: CI Chromium system tests + focused Docker suite
- Verified by: automated 7A suite
- Follow-ups (if any): optional live Register workstation pass before closeout to `main`
