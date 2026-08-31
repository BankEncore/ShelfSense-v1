# Slice 5B — Manual verification evidence

Status: **passed** for Slice 5B closeout alongside automated system coverage and green CI.

Workstation assumptions: Chrome (or Chromium) on a Register-class display; Keyboard Lock optional.

## Checklist

| # | Case | Pass criteria | Result | Notes |
|---|---|---|---|---|
| 1 | Return chooser open (`−`) | Continue focused path; background inert | Pass | |
| 2 | Linked Escape ladder | lines → receipts → lookup → chooser → command | Pass | |
| 3 | Unlinked Escape to chooser | Not command; chooser selection restored | Pass | |
| 4 | Pointer Add Return / Add Unlinked Return | Completable without keyboard | Pass | |
| 5 | Failed unlinked commit | Overlay stays; fields preserved; password cleared | Pass | |
| 6 | Successful return add | No return overlay; line selected | Pass | |
| 7 | F10 while return overlay open | Menu does not open | Pass | |

## Sign-off

- Date: 2026-08-28
- Browser / OS: Register workstation (manual walkthrough)
- Verified by: Project owner
- Follow-ups (if any): Controlled-action / confirmation chrome remains 5C; tender/issuance remains 5D.
