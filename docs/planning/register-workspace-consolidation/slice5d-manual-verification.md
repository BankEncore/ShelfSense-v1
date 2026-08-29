# Slice 5D — Manual verification evidence

Status: required for Slice 5D closeout alongside automated system coverage.

Workstation assumptions: Chrome (or Chromium) on a Register-class display; Keyboard Lock optional.

## Checklist

| # | Case | Pass criteria | Result | Notes |
|---|---|---|---|---|
| 1 | Empty-field `+` with merchandise | O11 opens; F10 suppressed | | |
| 2 | `+` empty basket | No O11; existing merchandise feedback | | |
| 3 | F1 Cash | Command-field tender chrome; no O11 | | |
| 4 | F4/F5 many | O11 filtered; Escape restores prior mode | | |
| 5 | Escape from tender-mode O11 | Restores amount / reference / card | | |
| 6 | O11 Choose Tender | Entry chrome only; applied tenders unchanged | | |
| 7 | O10 Add activation | Success clears overlay; list shows issuance | | |
| 8 | O10 validation failure | Overlay stays; fields preserved | | |
| 9 | Payment gift-card scan | Tender path; not O10 | | |
| 10 | Issuance Remove | Existing remove path | | |

## Sign-off

- Date:
- Browser / OS:
- Verified by:
- Follow-ups (if any):
