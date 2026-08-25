# UDS-5.5 — Evidence and closeout

Status: **Complete** on `uds-5-administrative-composition` (August 2026). Tracker: [#50](https://github.com/BankEncore/ShelfSense-v1/issues/50). Authority: [uds-5-plan.md](uds-5-plan.md) § UDS-5.5.

UDS-5 remains **Proposed** until this program branch merges to `main`. This file records closeout evidence for that merge; it does not start UDS-6 or UDS-7.

## Serif decision: **Adopt**

Warm Parchment permitted a display-serif role for brand and top-level titles. UDS-5 packaged Source Serif 4 locally and applied it only through `--font-serif` and role classes.

**Decision:** adopt Source Serif 4 for brand, page title, and record title. Do not extend serif to navigation, tables, controls, labels, badges, or ordinary body.

| Bound | Evidence |
|---|---|
| Local packaging, no runtime CDN | `app/assets/fonts/source-serif-4-latin-{400,600}-normal.woff2`; [`admin_product_composition_test`](../../../test/integration/admin_product_composition_test.rb) asserts no Google Fonts / jsDelivr |
| Role-only application | `.app-brand`, `.type-brand`, `.type-page-title`, `.type-record-title` use `font-family: var(--font-serif)`. Product templates must not set `font-family` (same composition test) |
| Product family titles | Index, show, catalog search, new/edit, and bibliographic review consume `.type-page-title` via `shared/page_header` |
| Narrow / zoom | Composition system tests at 320 CSS px and 200% zoom keep titles visible ([`admin_product_composition_test`](../../../test/system/admin_product_composition_test.rb), search/form, bibliographic review) |
| Receipt remains distinct | `--font-receipt` stays Inconsolata; print templates unchanged vs `main` (see print non-regression) |

**Not chosen:** reject (would drop the packaged face after Product titles already consume it) or adjust (no evidence that additional roles need serif, or that titles need a different face).

## Compact nav and Product family

| Surface | Slice | Commit |
|---|---|---|
| Packet + compact-nav gate | UDS-5.0 | `bb130c6` — [uds-5.0-gate-evidence.md](uds-5.0-gate-evidence.md) **Passed**; preferred pattern `area_row` |
| Type and composition primitives | UDS-5.1 | `945dbd2` — disposable fixture later **retired**; primitives covered by partial tests and Product surfaces |
| Compact area-row production chrome | UDS-5.2 | `a06712f` — `Closes #46`; 5.0 prototype retired |
| Product index and show | UDS-5.3 | `943695f` — `Closes #47` |
| Catalog search and product form | UDS-5.4A | `a2e85e1` — `Closes #48` |
| Bibliographic review comparison | UDS-5.4B | `74fd352` — `Closes #49` |

Catalog membership, permission predicates, destination labels, and group membership are unchanged. `application.html.erb` markup is unchanged. ApplyCandidate, provenance, cover download, subject matching, and `lock_version` handling are unchanged.

## Print and Register non-regression

| Check | Result |
|---|---|
| `app/views/pos/receipts/_print.html.erb` vs `main` | No diff |
| `app/views/pos/shared/_report_print.html.erb` vs `main` | No diff |
| `@media print` / `.pos-receipt__print*` rules | Not rewritten in UDS-5; print still uses `--font-receipt` |
| Register workspace templates / POS layout | Not in any UDS-5 allowlist; not edited for composition |
| Automated | `test/services/pos/customer_receipt_test.rb`; `test/services/pos/receipt_identity_test.rb`; `test/integration/pos_mvp_closeout_test.rb` — 9 runs, 136 assertions, 0 failures (August 2026) |

Printed receipt remains the locked one-line contract in [surface-contracts.md](surface-contracts.md). Warm Parchment is a screen system.

## Standing feature-led adoption

Recorded in [ux-conventions.md](../../ux-conventions.md) and [ux-adoption-template.md](ux-adoption-template.md):

- New screens use the current accepted primitives.
- Existing screens adopt them when the feature that owns those screens is next in scope.
- Do not sweep remaining admin families in a UDS PR.

UDS-6 (staff history composition) and UDS-7 (sidebar / Cmd+K) stay parked. [deferred-patterns.md](deferred-patterns.md) is unchanged on those rows.

## Cross-cutting

| Check | Result |
|---|---|
| Admin / ops / Register shells remain distinct | Compact nav is admin-header only; ops and POS layouts untouched |
| Printed receipt selectors frozen | See print non-regression |
| UDS-7 not scheduled | Sidebar and Cmd/Ctrl+K remain deferred |

## Remaining on this branch

- Merge to `main` after review (one PR for UDS-5).
- Product family matrix rows stay **partial** / presentation-complete, not a conforming a11y gate.

## Review remediation (PR #57)

| Finding | Result |
|---|---|
| Narrow/zoom header as a full-height link wall | At `max-width: 40rem`, one **Areas** disclosure holds the catalog; the current destination stays visible. System tests assert header height vs viewport at 320 CSS px (WCAG 400% reflow width). |
| Table content-role classes restyling `<th>` | `shared/_data_table` distinguishes `header_class` / `cell_class`; `class` remains a both-cell alias. Hierarchy CSS targets `td` only. |
| Disposable 5.1 fixture in the production route set | Route, controller, view, and prototype tests removed. Primitive coverage remains on partial tests and Product surfaces. |
