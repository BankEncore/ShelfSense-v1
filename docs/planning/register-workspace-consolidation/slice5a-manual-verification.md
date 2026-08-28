# Slice 5A — Manual verification evidence

Status: **passed** for Slice 5A closeout alongside automated system coverage and green CI.

Workstation assumptions: Chrome (or Chromium) on a Register-class display; Keyboard Lock optional.

## Checklist

| # | Case | Pass criteria | Result | Notes |
|---|---|---|---|---|
| 1 | Search open (`/`) | First search field focused; background inert | Pass | |
| 2 | Nested product → variant Escape | Focus returns to prior stage, not command | Pass | |
| 3 | Pointer product confirm | Click result then Choose Product commits | Pass | |
| 4 | Pickup / customer pointer | Completable without keyboard | Pass | |
| 5 | Escape during search | Late response does not steal focus | Pass | |
| 6 | Open-price zero edit | Field shows `0.00` selected | Pass | |
| 7 | F10 while lookup open | Menu does not open; header not interactive | Pass | |

## Sign-off

- Date: 2026-08-28
- Browser / OS: Register workstation (manual walkthrough)
- Verified by: Project owner
- Follow-ups (if any): Return / controlled / tender overlay content remains 5B–5D; gift-card issuance inline focus remains deferred to 5D.
