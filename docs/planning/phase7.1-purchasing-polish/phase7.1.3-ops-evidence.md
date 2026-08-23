# Phase 7.1.3 — Ops interaction evidence

Status: **Ready for review** — automated gate on branch `phase-7.1.3-purchasing-ops-closeout` (PR #40). Merge gate items below must be green before merge; manual **R** reflow and deferred **E** spot-checks are not blockers for this slice.

Targeted manual gate for Location and Draft PO (not full UDS accessibility matrix conformance).

## Evidence scope

| ID | Requirement | Location | Draft PO |
|---|---|---|---|
| K | Keyboard-only primary workflow; visible focus; restoration targets | Automated | Automated |
| D | Abandonment confirm copy; review dialog Escape (Draft PO send) | Automated | Automated |
| R | 200%, 400%, 320×568 reflow | Deferred manual spot-check | Deferred manual spot-check |
| E | Empty, invalid, stale, dirty, success states | Automated + deferred manual | Automated |

## K — Keyboard and focus

- [x] Location: ↑/↓ row selection, Enter opens panel, Esc closes panel (`location_queue_buttons_test.rb`)
- [x] Location: success redirect focuses first remaining row or empty-state action (`location_queue_buttons_test.rb`)
- [ ] Location: validation failure focuses affected field (Used scan, special-order cost) — **deferred manual spot-check; not part of automated merge gate**
- [x] Draft PO: `/` lookup, Ctrl/⌘+S save row, Ctrl/⌘+Enter primary action (`purchasing_ops_workspace_test.rb`)
- [x] Draft PO: stale edit focuses quantity/cost/notes field (not lookup) (`purchasing_ops_workspace_test.rb`)
- [x] Draft PO index: Open link activates draft detail with lookup focus (`purchasing_ops_workspace_test.rb`)

## D — Dialogs and abandonment

- [x] Location dirty Close/Escape: **“Discard this location entry?”** (not “cancel request”) (`location_queue_buttons_test.rb`)
- [x] Location dirty mode/request switch requires abandonment before replacing panel state (`location_queue_buttons_test.rb`)
- [x] Draft PO dirty navigation: **“Discard unsaved purchasing changes?”** (`purchasing_ops_workspace_test.rb` — inline edit + add-line)
- [x] Draft PO Escape resets dirty inline edit in one step (`purchasing_ops_workspace_test.rb`)
- [x] Draft PO send review: Escape restores trigger; scanner Enter does not send (`purchasing_ops_workspace_test.rb`)

## R — Reflow

- [ ] Location queue + panel at 200%, 400%, 320×568 — **deferred manual spot-check**
- [ ] Draft PO detail + line grid at 200%, 400%, 320×568 — **deferred manual spot-check**

## E — States

- [x] Location empty queue (`location_queue_buttons_test.rb`)
- [ ] Location recoverable validation (Used scan, special-order cost) — **deferred manual spot-check**
- [ ] Location stale request — **deferred manual spot-check**
- [x] Draft PO add-line failure preserves values (`purchasing_ops_workspace_test.rb`)
- [x] Draft PO inline edit conflict (`purchasing_ops_workspace_test.rb`)

## Automated test record

| Suite | Result |
|---|---|
| `test/system/location_queue_buttons_test.rb` | 11 tests, 0 failures |
| `test/system/purchasing_ops_workspace_test.rb` | 9 tests, 0 failures (includes Receiving regression) |
| `test/integration/purchasing_ops_layout_test.rb` | 1 test, 0 failures |

## Record

| Field | Value |
|---|---|
| Branch | `phase-7.1.3-purchasing-ops-closeout` |
| PR | #40 |
| Evidence head SHA | _set on merge-ready commit_ |
| Reviewer | _pending merge approval_ |
| Browser | Chromium (Capybara system tests) |
| Date | 2026-08-23 |
