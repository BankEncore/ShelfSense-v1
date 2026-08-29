# Slice 5C — Manual verification evidence

Status: **passed** for Slice 5C closeout alongside automated system coverage and green CI.

Workstation assumptions: Chrome (or Chromium) on a Register-class display; Keyboard Lock optional.

## Checklist

| # | Case | Pass criteria | Result | Notes |
|---|---|---|---|---|
| 1 | O9 price open (F6) | Action-specific title; background inert | Pass | |
| 2 | Direct-policy Apply | Submits without O18 | Pass | |
| 3 | Price → O18 → Escape | Parent values restored; password cleared | Pass | |
| 4 | Auth failure | O18 stays; password cleared; username may remain | Pass | |
| 5 | Unlinked → O18 → Authorize | Atomic add; ancestry cleared | Pass | |
| 6 | Cross-parent O18 | Unlinked context after price O18; no leftover credentials | Pass | |
| 7 | Cancel transaction | Presenter consequence copy; Keep restores command | Pass | |
| 8 | F10 while O9 or O18 open | Menu does not open | Pass | |

## Sign-off

- Date: 2026-08-29
- Browser / OS: Register workstation (manual walkthrough)
- Verified by: Project owner
- Follow-ups (if any): Tender / gift-card issuance overlays remain Slice 5D (#89).
