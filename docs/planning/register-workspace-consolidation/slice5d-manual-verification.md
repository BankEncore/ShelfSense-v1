# Slice 5D — Manual verification evidence

Status: **passed** for Slice 5D closeout alongside automated system coverage and green CI ([PR #102](https://github.com/BankEncore/ShelfSense-v1/pull/102), remediation [PR #103](https://github.com/BankEncore/ShelfSense-v1/pull/103)).

Workstation assumptions: Chrome (or Chromium) on a Register-class display; Keyboard Lock optional.

## Checklist

| # | Case | Pass criteria | Result | Notes |
|---|---|---|---|---|
| 1 | Empty-field `+` with merchandise | O11 opens; F10 suppressed | Pass | System suite + CI |
| 2 | `+` empty basket | No O11; existing merchandise feedback | Pass | System suite |
| 3 | F1 Cash | Command-field tender chrome; no O11 | Pass | System suite |
| 4 | F4/F5 many | O11 filtered; Escape restores prior mode | Pass | System suite |
| 5 | Escape from tender-mode O11 | Restores amount / reference / card | Pass | System suite |
| 6 | O11 Choose Tender | Entry chrome only; applied tenders unchanged | Pass | System suite |
| 7 | O10 Add activation | Success clears overlay; list shows issuance | Pass | System suite; Enter from Amount |
| 8 | O10 validation failure | Overlay stays; fields preserved | Pass | System suite |
| 9 | Payment gift-card scan | Tender path; not O10 | Pass | Existing routing preserved |
| 10 | Issuance Remove | Existing remove path | Pass | Domain/service coverage unchanged |
| 11 | O10 system-generated reload | Card required/visible; reload succeeds | Pass | PR #103 |
| 12 | O10 Program/Type Enter | Native select Enter; does not submit | Pass | PR #103 |
| 13 | O10 Tab order | Amount → Program → Type → Card | Pass | PR #103 |
| 14 | O11 numbered rows | Presentational only; no digit shortcuts | Pass | PR #103 |

## Sign-off

- Date: 2026-08-29
- Browser / OS: Automated system suite (Chromium) + CI; owner review of PR #103
- Verified by: Project owner (review passed) + agent closeout
- Follow-ups (if any): Slice 6 inquiry surfaces next on the integration branch.
