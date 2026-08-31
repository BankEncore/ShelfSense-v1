# Slice 7C — Manual verification evidence

Status: **Template** (fill and sign in 7C.2 cutover). Issue [#95](https://github.com/BankEncore/ShelfSense-v1/issues/95). Packet: [slice7c-keyboard-dispatcher-plan.md](slice7c-keyboard-dispatcher-plan.md). Contract: [slice7-keyboard-contract.md](slice7-keyboard-contract.md).

Workstation assumptions: Chrome (or Chromium) on a Register-class display; Keyboard Lock may fail without breaking typed/scanned entry.

## Checklist

| # | Case | Pass criteria | Result | Notes |
|---|---|---|---|---|
| 1 | Dispatcher ownership | One workspace dispatcher; shell owns F10 + Lock; no duplicate window listeners after Turbo | | |
| 2 | SALE F1–F5 | Tender families open expected entry paths; F2 is Card (not Customer) | | |
| 3 | SALE F6–F9 | Price / Discount / Remove selected / Cancel confirmation | | |
| 4 | Focus punctuation | Command field: `/` `-` `+` `*` literal; selected basket row: Search / Return / Tender / Quantity | | |
| 5 | Scanner glyphs | Scans with leading/mid/trailing punctuation + Enter do not open mode overlays when command focused | | |
| 6 | Shell header `+` | Redirected literal into command field; does not open O11 | | |
| 7 | TENDER F8 / `-` | Removes/opens remove for **selected** tender (not last-only) | | |
| 8 | TENDER Enter | Opens selected tender actions / detail; shows reason when edit unavailable | | |
| 9 | TENDER `+` / F1–F5 | Add via O11 or direct family when legal | | |
| 10 | Escape precedence | Closes overlay / return-to-sale path; never cancels transaction | | |
| 11 | Repeat F8 | Held key removes only one record | | |
| 12 | Unavailable announce | Expected-but-disabled action announces existing reason; selection stable | | |
| 13 | Overlay ownership | Overlay owns Tab/Escape/Enter/arrows/input; F10 suppressed with announcement | | |
| 14 | Completion Failed | Enter retries only under existing recovery contract | | |
| 15 | Labels/help | `Tender (+)` / `Return (-)` do not imply shortcuts from focused command field | | |
| 16 | Docs supersession | pos-workflow §6 points at Slice 7 contract; Phase 6.7 empty-field rule gone | | |

## Sign-off

- Date:
- Browser / OS:
- Verified by:
- Follow-ups (if any):
