# Phase 7.1.3 — Ops interaction evidence

Status: **Complete** — merged to `main` (PR #40, merge `2db6f1d`). Automated merge gate and deferred evidence items below are satisfied.

Targeted manual gate for Location and Draft PO (not full UDS accessibility matrix conformance).

## Evidence scope

| ID | Requirement | Location | Draft PO |
|---|---|---|---|
| K | Keyboard-only primary workflow; visible focus; restoration targets | Automated | Automated |
| D | Abandonment confirm copy; review dialog Escape (Draft PO send) | Automated | Automated |
| R | 200%, 400%, 320×568 reflow | Automated spot-check | Automated spot-check |
| E | Empty, invalid, stale, dirty, success states | Automated | Automated |

## K — Keyboard and focus

- [x] Location: ↑/↓ row selection, Enter opens panel, Esc closes panel (`location_queue_buttons_test.rb`)
- [x] Location: success redirect focuses first remaining row or empty-state action (`location_queue_buttons_test.rb`)
- [x] Location: validation failure focuses affected field (Used scan, special-order cost) (`location_queue_buttons_test.rb`)
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

- [x] Location queue + panel at 200%, 400%, 320×568 (`location_queue_buttons_test.rb` — viewport resize + CSS zoom; queue scrolls in `.table-scroll`, sticky panel remains operable)
- [x] Draft PO detail + line grid at 200%, 400%, 320×568 (`purchasing_ops_workspace_test.rb` — scan section and `.table-scroll` line grid remain reachable)

## E — States

- [x] Location empty queue (`location_queue_buttons_test.rb`)
- [x] Location recoverable validation (Used scan invalid + success) (`location_queue_buttons_test.rb`)
- [x] Location special-order cost validation (`location_queue_buttons_test.rb`)
- [x] Location stale request preserves panel context (`location_queue_buttons_test.rb`)
- [x] Draft PO add-line failure preserves values (`purchasing_ops_workspace_test.rb`)
- [x] Draft PO inline edit conflict (`purchasing_ops_workspace_test.rb`)

## Automated test record

| Suite | Result |
|---|---|
| `test/system/location_queue_buttons_test.rb` | 16 tests, 0 failures |
| `test/system/purchasing_ops_workspace_test.rb` | 10 tests, 0 failures (includes Receiving regression) |
| `test/integration/purchasing_ops_layout_test.rb` | 1 test, 0 failures |

## Record

| Field | Value |
|---|---|
| PR | #40 |
| Merge commit | `2db6f1d` |
| Evidence head SHA | _set on evidence-completion commit_ |
| Reviewer | Approved and merged August 2026 |
| Browser | Chromium (Capybara system tests; reflow via viewport resize + `document.documentElement.style.zoom`) |
| Date | 2026-08-23 |
