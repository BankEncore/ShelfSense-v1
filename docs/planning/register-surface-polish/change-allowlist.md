# Register surface polish — Change allowlist

Status: **Accepted**

Expanding this allowlist requires a documentation change in the same PR (or a preceding docs PR) and an explicit callout in review. “Shared CSS cleanup” is not implicit scope.

## Frozen contracts (must not change behavior)

| Contract | Examples |
|---|---|
| DOM ids | `#pos_workspace`, `#pos_basket`, `#pos-command-field`, `#register-menu`, `#pos_actions` |
| Stimulus | `register-workspace`, `register-shell`, `pos-receipt`, `register_keyboard_dispatcher` targets/actions/values |
| Keyboard | [slice7-keyboard-contract.md](../register-workspace-consolidation/slice7-keyboard-contract.md) |
| Turbo | Workspace stream replacements; form methods; completion paths |
| Shell | F10 ownership, `keyboard.lock`, leave-confirm, menu proxy items / group membership |
| Print content | Thermal section order, labels, barcode encoding, voucher masking |

## Allowed by slice

### S1 — Packet

| Allowed | Forbidden |
|---|---|
| Docs under `docs/planning/register-surface-polish/` | Application code |
| `docs/planning/roadmap.md` pointer | ADR changes beyond cross-links already made |

### S2 — Local font packaging

| Allowed | Forbidden |
|---|---|
| `app/assets/fonts/` — Noto Sans Mono / Plus Jakarta Sans `.woff2` + license texts | New CDN font hosts |
| `application.css` `@font-face` for those families; thermal stack URLs | Changing thermal content partials beyond font-loader removal |
| Remove or empty CDN usage in `app/views/pos/receipts/_thermal_fonts.html.erb` | Changing barcode / receipt section markup |
| `pos_receipt_controller.js` `prepareFonts()` face names | Admin/ops face replacement |
| Tests asserting local faces / absence of `fonts.googleapis.com` | Report/tape font changes |

### S3 — Active workspace polish

| Selectors / areas | Partials / helpers |
|---|---|
| `.pos-body`, `.pos-shell`, `.pos-header*`, `.pos-main`, `.pos-basket-region`, `.pos-summary-rail` | `shell/_header.html.erb`, `_frame.html.erb`, `_feedback.html.erb`, `_status.html.erb` (class/wrapper only) |
| `.pos-command*`, `.pos-basket`, `.pos-lines`, `.pos-line__*`, `.pos-line-flags` | `workspaces/_surface.html.erb`, `_command.html.erb`, `_basket.html.erb` |
| `.pos-issuances`, `.pos-customer*`, `.pos-totals*`, `.pos-tenders*`, `.pos-settlement*`, `.pos-money-row*` | `_issuances.html.erb`, `_customer.html.erb`, `_totals.html.erb`, `_tenders.html.erb` |
| `.pos-actions*`, `.pos-tender-review*`, `.pos-banner`, `.pos-feedback` | `_actions.html.erb` |
| New Register-only selectors named in the PR | `pos_helper.rb` only for presentation helpers (no domain logic) |
| Optional Register `--font-pos-*` adoption on `.pos-body` | `register-workspace` / `register-shell` / keyboard JS behavior |

Enter/closed/selector shells (`shell/_enter_form.html.erb`, `_closed.html.erb`, `_selector.html.erb`, `_occupied.html.erb`, `_own_session.html.erb`, `_between_sessions.html.erb`) may receive **token/class** polish only if needed for visual continuity with the header; do not change open/close/session flows.

### S4 — Menu, overlays, optional history skin

| Selectors / areas | Partials |
|---|---|
| `.pos-register-menu*`, `#register-menu` panel chrome | `shell/_menu.html.erb` (structure only if required for styling; preserve targets/proxy) |
| `.pos-overlay*`, overlay panel headers/actions | `workspaces/_overlays.html.erb` and nested overlay markup **chrome only** |
| Optional `.pos-history*` filter/table skin | `transactions/index.html.erb` class/CSS only; no query/param/link changes |

## Explicitly out of scope (all slices)

| Path / area | Reason |
|---|---|
| `app/javascript/controllers/register_workspace_controller.js` behavior | Frozen interaction |
| `app/javascript/controllers/register_shell_controller.js` behavior | Frozen F10 / lock |
| `app/javascript/**/register_keyboard_dispatcher*` | Slice 7C |
| `completed_transactions/show.html.erb`, `transactions/show.html.erb` | Deferred review redesign |
| `app/views/pos/receipts/thermal/**` content | Receipts packet ownership |
| `app/services/pos/**` domain services | Not visual |
| Admin / ops layouts and Source Sans stacks | ADR-022 |
| `.pos-report-print`, `.pos-shift-end-tape` | Deferred report restyle |

## Markup change rule

Prefer CSS-only. Markup edits are allowed only when required to express card regions or accessibility labels **without** removing or renaming frozen ids/targets. Every markup edit must list frozen selectors preserved in the PR description.
