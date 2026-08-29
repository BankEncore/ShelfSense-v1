# Slice 5C — Manual verification evidence

Status: required for Slice 5C closeout alongside automated system coverage.

Workstation assumptions: Chrome (or Chromium) on a Register-class display; Keyboard Lock optional.

## Checklist

| # | Case | Pass criteria | Result | Notes |
|---|---|---|---|---|
| 1 | O9 price open (F6) | Action-specific title; background inert | | |
| 2 | Direct-policy Apply | Submits without O18 | | |
| 3 | Approval → O18 → Escape | Parent values restored; password cleared | | |
| 4 | Auth failure | O18 stays; password cleared; username may remain | | |
| 5 | Unlinked → O18 → Authorize | Atomic add; ancestry cleared | | |
| 6 | Cross-parent O18 | Unlinked context after price O18; no leftover credentials | | |
| 7 | Cancel transaction | Presenter consequence copy; Keep restores command | | |
| 8 | F10 while O9 or O18 open | Menu does not open | | |

## Sign-off

- Date:
- Browser / OS:
- Verified by:
- Follow-ups (if any):
