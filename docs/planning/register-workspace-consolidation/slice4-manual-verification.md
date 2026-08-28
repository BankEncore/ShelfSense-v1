# Slice 4 — Manual verification evidence

Status: **passed** for Slice 4 closeout alongside automated system coverage and green CI.

Workstation assumptions: Chrome (or Chromium) on a Register-class display; Keyboard Lock optional.

## Checklist

| # | Case | Pass criteria | Result | Notes |
|---|---|---|---|---|
| 1 | High zoom (200%) basket + summary rail | Merchandise, gift cards, summary, and tenders reachable; summary rail stacks as one unit | Pass | |
| 2 | Tax groups readable | Named tax groups appear; Net reconciles; no Sales row | Pass | |
| 3 | Tenders region distinct | `#pos_tenders` sibling of `#pos_totals`; settlement footer outside formula | Pass | |
| 4 | F1–F9 / overlays | Existing workspace keys and blocking overlays unchanged | Pass | |
| 5 | Issuance Remove | Remove remains available for gift-card issuances in sale entry; no Edit | Pass | |
| 6 | Close Session proxy | Empty basket Close Session works; F10 menu discovers live proxy | Pass | |

## Sign-off

- Date: 2026-08-28
- Browser / OS: Register workstation (manual walkthrough)
- Verified by: Project owner
- Follow-ups (if any): Gift-card issuance inline field focus remains deferred (scan-routing / 5D); not a Slice 4 blocker.
