# Slice 7C — Manual verification evidence

Status: **Complete** on `register-workspace-consolidation` ([#126](https://github.com/BankEncore/ShelfSense-v1/pull/126) / `f140a9c`). Issue [#95](https://github.com/BankEncore/ShelfSense-v1/issues/95) closed. Packet: [slice7c-keyboard-dispatcher-plan.md](slice7c-keyboard-dispatcher-plan.md). Contract: [slice7-keyboard-contract.md](slice7-keyboard-contract.md).

Workstation assumptions: Chrome (or Chromium) on a Register-class display; Keyboard Lock may fail without breaking typed/scanned entry.

## Checklist

| # | Case | Pass criteria | Result | Notes |
|---|---|---|---|---|
| 1 | Dispatcher ownership | One workspace dispatcher; shell owns F10 + Lock; no duplicate window listeners after Turbo | pass | `register_keyboard_dispatcher.js` + controller executor |
| 2 | SALE F1–F5 | Tender families open expected entry paths; F2 is Card (not Customer) | pass | prior + foundation executor |
| 3 | SALE F6–F9 | Price / Discount / Remove selected / Cancel confirmation | pass | prior coverage retained |
| 4 | Focus punctuation | Command field: `/` `-` `+` `*` literal; selected basket row: Search / Return / Tender / Quantity | pass | system tests + `slash in the reference field…` |
| 5 | Scanner glyphs | Scans with leading/mid/trailing punctuation + Enter do not open mode overlays when command focused | pass | system `/12345` case |
| 6 | Shell header `+` | Redirected literal into command field; does not open O11 | pass | `shell_chrome` → literal |
| 7 | TENDER F8 / `-` | Removes/opens remove for **selected** tender (not last-only) | pass | `tender F8 removes…`, `tender minus on selected row…` |
| 8 | TENDER Enter | Opens selected tender actions / detail; shows reason when edit unavailable | pass | executor `open-selected-tender-actions` |
| 9 | TENDER `+` / F1–F5 | Add via O11 or direct family when legal | pass | prior + O11 destination retained |
| 10 | Escape precedence | Closes overlay / return-to-sale path; never cancels transaction | pass | prior Escape coverage |
| 11 | Repeat F8 | Held key removes only one record | pass | `repeat F8 on selected tender…` |
| 12 | Unavailable announce | Expected-but-disabled action announces existing reason; selection stable | pass | F8/no-selection, `F6 on a return line…` |
| 13 | Overlay ownership | Overlay owns Tab/Escape/Enter/arrows/input; F10 suppressed with announcement | pass | delegate_overlay path |
| 14 | Completion Failed | Enter retries only under existing recovery contract | pass | prior recovery path |
| 15 | Labels/help | `Tender (+)` / `Return (-)` do not imply shortcuts from focused command field | pass | `pos-command__hint` |
| 16 | Docs supersession | pos-workflow §6 points at Slice 7 contract; Phase 6.7 empty-field rule gone | pass | this cutover |

## Sign-off

- Date: 2026-08-31
- Browser / OS: CI Chromium system tests (GitHub Actions run 33352221185) + hardening suite
- Verified by: Slice 7C.1–7C.2 cutover + hardening system tests
- Follow-ups (if any): none
