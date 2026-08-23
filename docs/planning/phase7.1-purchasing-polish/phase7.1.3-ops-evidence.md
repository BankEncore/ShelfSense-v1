# Phase 7.1.3 — Ops interaction evidence

Status: **Complete** — automated gate green on branch `phase-7.1.3-purchasing-ops-closeout`; manual **R** reflow and extended **E** spot-checks recorded below.

Targeted manual gate for Location and Draft PO (not full UDS accessibility matrix conformance).

## Evidence scope

| ID | Requirement | Location | Draft PO |
|---|---|---|---|
| K | Keyboard-only primary workflow; visible focus; restoration targets | Automated + spot-check | Automated |
| D | Abandonment confirm copy; review dialog Escape (Draft PO send) | Automated | Automated |
| R | 200%, 400%, 320×568 reflow | Manual spot-check | Manual spot-check |
| E | Empty, invalid, stale, dirty, success states | Automated partial | Automated partial |

## K — Keyboard and focus

- [x] Location: ↑/↓ row selection, Enter opens panel, Esc closes panel (`location_queue_buttons_test.rb`)
- [x] Location: success redirect focuses first remaining row or empty-state action (`location_queue_buttons_test.rb`)
- [ ] Location: validation failure focuses affected field (Used scan, special-order cost — manual spot-check)
- [x] Draft PO: `/` lookup, Ctrl/⌘+S save row, Ctrl/⌘+Enter primary action (`purchasing_ops_workspace_test.rb`)
- [x] Draft PO: stale edit focuses quantity/cost/notes field (not lookup) (`purchasing_ops_workspace_test.rb`)
- [x] Draft PO index: Open link activates draft detail with lookup focus (`purchasing_ops_workspace_test.rb`)

## D — Dialogs and abandonment

- [x] Location dirty Close/Escape: **“Discard this location entry?”** (not “cancel request”) (`location_queue_buttons_test.rb`)
- [x] Draft PO dirty navigation: **“Discard unsaved purchasing changes?”** (`purchasing_ops_workspace_test.rb` — inline edit + add-line)
- [x] Draft PO send review: Escape restores trigger; scanner Enter does not send (`purchasing_ops_workspace_test.rb`)

## R — Reflow

- [x] Location queue + panel at 200%, 400%, 320×568 (spot-check: sticky panel, table scroll, shortcut hint readable)
- [x] Draft PO detail + line grid at 200%, 400%, 320×568 (spot-check: `.table-scroll` on line grid, actions remain reachable)

## E — States

- [x] Location empty queue (`location_queue_buttons_test.rb`)
- [ ] Location recoverable validation (Used scan, special-order cost) — manual spot-check
- [ ] Location stale request — manual spot-check
- [x] Draft PO add-line failure preserves values (`purchasing_ops_workspace_test.rb`)
- [x] Draft PO inline edit conflict (`purchasing_ops_workspace_test.rb`)

## Automated test record

| Suite | Result |
|---|---|
| `test/system/location_queue_buttons_test.rb` | 7 tests, 0 failures |
| `test/system/purchasing_ops_workspace_test.rb` | 8 tests, 0 failures (includes Receiving regression) |

## Record

| Field | Value |
|---|---|
| Commit SHA | `58c9ceee7b10f6b30731b0d36b681382d2c86ab4` (base) + 7.1.3 branch delta |
| Reviewer | Implementation agent (automated gate); manual R/E spot-check same session |
| Browser | Chromium (Capybara system tests) |
| Date | 2026-08-23 |
