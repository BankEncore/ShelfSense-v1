# UX design system — program plan

Status: **Proposed**

## Goal

Converge ShelfSense screens on one design vocabulary (Warm Parchment tokens + button/action semantics) without rewriting product architecture or collapsing admin, purchasing ops, and Register into a single shell.

## Program slices

Slices are labeled **UDS-*** (UX Design System) so they are not confused with Phase 7 domain slices 7.1–7.7.

```mermaid
flowchart LR
  uds0[UDS-0 Authority]
  uds1[UDS-1 Tokens and primitives]
  uds2[UDS-2 Reference screens]
  uds3[UDS-3 Register visual]
  uds0 --> uds1 --> uds2 --> uds3
```

## Implementation rollout contract

This section is the change-control contract for every UDS pull request. A slice may change only the files and selectors listed for that slice. Expanding the allowlist requires updating this plan in a preceding or same-commit documentation change and calling the expansion out in review; “shared CSS cleanup” is not implicit scope.

Objective migration states, the alias retirement register, and evidence columns live in [migration-matrix.md](migration-matrix.md). Reference-surface accessibility evidence is governed by the three-layer automated gate in [uds-foundation-closeout-plan.md](uds-foundation-closeout-plan.md) and [accessibility-ergonomic-test-matrix.md](accessibility-ergonomic-test-matrix.md) (foundation criterion 10); the viewport/browser gates below do not replace that evidence model.

### Objective migration states

- **Partial** means the surface uses at least one accepted token or primitive, but one or more required action semantics, component states (default, hover, active, focus-visible, disabled, validation, empty, loading where present), responsive checks, accessibility checks, or workflow regression checks are incomplete or failing. The matrix must name the missing requirement; inheriting new colors is partial at most.
- **Verified-automated** means all applicable Layer A (axe), Layer B (workflow), and Layer C (layout smoke) gates pass at a recorded commit SHA for that surface; human and assistive-technology gaps are documented as deferred, not silently passed. See [uds-foundation-closeout-plan.md](uds-foundation-closeout-plan.md).
- **Conforming** means **verified-automated** plus SR-MANUAL, PERF-HUMAN, and independent review evidence where required by the [accessibility and ergonomic test matrix](accessibility-ergonomic-test-matrix.md). All markup uses accepted primitives or documented exceptions; action labels, intent, prominence, and review stages match [button-action-semantics.md](button-action-semantics.md); every applicable component state is visibly distinguishable; the viewport matrix below has no overlap, clipping, or unreachable action. Evidence (commit/PR, observation or screenshot identifier, viewport, and reviewers) must be linked from the matrix. A surface cannot become conforming solely through inherited colors.

### Slice change allowlist

| Slice | Shared selectors allowed to change | Helpers / partials / layouts allowed to change | Reference views allowed to change |
|---|---|---|---|
| UDS-0 | None | None | None; documentation and baseline capture only |
| UDS-1 | `:root`; base `body`, `a`, and the existing `:focus-visible` control list; `.app-shell`, `.app-header`, `.app-brand`, `.app-header-meta`, `.app-content`; `.ops-header`, `.ops-content`, `.ops-shortcuts`, `.ops-shortcuts__buttons`, `.ops-shortcuts__help`, `.ops-empty-state`; `.btn`, `.button`, `button`, `input[type="submit"]`, `.btn--secondary`, `.button-secondary`, `.btn--danger`, `.button-danger`, `.btn--ghost`; new `btn--solid` / `btn--outline` / `btn--link` / `btn--brand` / `btn--neutral` / `btn--warning` / size classes from the action matrix; `.flash`, `.flash--notice`, `.flash--alert`; `.status-badge` and existing status modifiers; `.muted`, `.missing-value`, `.definition-list`, `.section`, `.section__title`, `.section__help`, `.form`, `.form-field`, `.form-errors`, `.table-scroll`, `.data-table`, `.empty-state`, `.empty-state__title`, `.technical-details`, `.pagination`, `.filters`; `.review-dialog` and existing severity/body/facts/consequences/actions variants; new token/primitive selectors named individually in the PR. **Grouped navigation selectors** (e.g. `.app-nav`, `.app-nav-group`) only after the [navigation prototype gate](navigation-proposal.md#required-prototype-gate) passes and this allowlist is updated to name them. | `app/helpers/application_helper.rb` (including `ActionButtonHelper` when introduced); `app/views/shared/_actions.html.erb`, `_breadcrumbs.html.erb`, `_currency_field.html.erb`, `_data_table.html.erb`, `_definition_list.html.erb`, `_empty_state.html.erb`, `_flash.html.erb`, `_form_errors.html.erb`, `_form_section.html.erb`, `_page_header.html.erb`, `_status_badge.html.erb`, `_technical_details.html.erb`; `app/views/layouts/application.html.erb`, `app/views/layouts/ops.html.erb` (token/chrome only; **no** grouped-nav IA change until the navigation prototype gate) | None except a minimal fixture/use-site change needed to exercise a shared primitive; name it in the PR |
| UDS-2 | UDS-1 primitives plus `.request-next-action`, `.request-summary__heading`, `.fulfillment-timeline*`, `.ops-queue` (as used by Receiving), `.pos-history*`, `.pos-receipt__actions`, `.review-dialog` variants listed in UDS-1, and new selectors named individually and scoped to an allowlisted reference view | UDS-1 shared partials; `app/helpers/purchasing_helper.rb`, `app/helpers/pos_helper.rb`; `app/views/ops/shared/_error_summary.html.erb`, `_inline_row_error.html.erb`; `app/views/pos/receipts/_directional_totals.html.erb`, `_post_void_banner.html.erb`; layouts may be consumed but not structurally changed | `app/views/admin/suppliers/{index,show,new,edit,_form}.html.erb`; **Receiving only:** `app/views/ops/receiving/{index,show,review,_line_grid,_line_scanner}.html.erb` (Location and Draft PO are post-UDS-2); `app/views/pos/completed_transactions/show.html.erb`; `app/views/pos/transactions/show.html.erb`, `_line.html.erb` (history Line details); existing consequence-dialog markup within those views |
| UDS-3 | `.pos-body`, `.pos-shell`, `.pos-header*`, `.pos-main`, `.pos-basket`, `.pos-lines`, `.pos-line__title`, `.pos-line__meta`, `.pos-line__id`, `.pos-line__provenance`, `.pos-line-flags`, `.pos-totals*`, `.pos-feedback`, `.pos-actions`, `.pos-actions__group`, `.pos-actions__group--escape`, `.pos-command*`, `.pos-picker`, `.pos-banner`, `.pos-overlay*`, `.pos-hidden`; UDS-1 `.review-dialog` and button/token primitives only when a Register state exposes a defect; new Register selectors named individually in the PR | `app/helpers/pos_helper.rb`; `app/views/layouts/pos.html.erb`; `app/views/pos/transactions/_chrome.html.erb`, `_line.html.erb`; `app/views/pos/workspaces/_surface.html.erb` | `app/views/pos/workspaces/show.html.erb` and Turbo stream replacements for that workspace; no printed receipt view or print selector |
| **Phase 7.1.1** | UDS-1 primitives only on hub surfaces; no grouped-nav selectors | `app/controllers/admin/purchasing_controller.rb`; `app/helpers/purchasing_helper.rb` (hub read-model helpers only); `app/views/admin/purchasing/show.html.erb`; `app/views/layouts/application.html.erb` (**flat** “Purchasing” link only—no group markup) | `app/views/admin/purchasing/show.html.erb` |
| **Phase 7.1.2** | UDS-1 primitives; `.filters`, `.data-table`, `.page-header`, `.breadcrumbs` as consumed | `app/helpers/purchasing_helper.rb` (cross-link helpers); shared partials listed under UDS-1 when templates adopt them | `app/views/admin/orders/**`; `app/views/admin/purchase_orders/**`; `app/views/admin/purchase_receipts/{index,show}.html.erb` (receipt detail bare `table` stays explicit—no global `table` selector) |
| **Phase 7.1.3** | UDS-1/UDS-2 ops tokens; `.ops-queue`, `.ops-shortcuts*`, `.ops-shortcuts--location`, `.location-*`, draft-PO workspace selectors named in PR; `app/helpers/ops_helper.rb`; contextual shortcut partial | `app/helpers/ops_helper.rb`; `app/views/ops/shared/_shortcuts.html.erb`; `app/views/layouts/ops.html.erb`; `app/javascript/controllers/{location_queue,escape_cancel,dirty_form}_controller.js` when workspace-aware; `app/views/ops/locations/**`; `app/views/ops/draft_pos/**`; `app/views/ops/shared/_error_summary.html.erb`, `_inline_row_error.html.erb` when touched | `app/views/ops/locations/show.html.erb`; `app/views/ops/draft_pos/{index,show}.html.erb` and related partials |
| **UDS-4.0** | None (complete; disposable prototype retired) | Gate evidence only — [uds-4.0-gate-evidence.md](uds-4.0-gate-evidence.md) | Historical; catalog reused by UDS-4.1 |
| **UDS-4.1** | `.app-nav`, `.app-nav--grouped`, `.app-nav-group`, `.app-nav-group__heading`, `.app-nav-group__list`, `.app-nav-utilities`, `.visually-hidden` | `app/helpers/admin_navigation_helper.rb`; `app/services/admin/navigation_catalog.rb`; `app/services/admin/navigation_view_model.rb`; `app/views/shared/_admin_primary_nav.html.erb`; `app/views/layouts/application.html.erb` (grouped primary nav only—no domain screens) | `test/services/admin/navigation_view_model_test.rb`; `test/integration/admin_grouped_navigation_test.rb` |
| **UDS-4.2** | UDS-1 primitives on allowlisted non–Phase-7.1 matrix rows only; `AdminCrossLinksHelper` | Shared partials; `app/helpers/admin_cross_links_helper.rb`; family templates listed in [uds-4.2-plan.md](uds-4.2-plan.md) | Matrix paths explicitly listed in PR (exclude `admin/orders/**`, `admin/purchase_orders/**`, `admin/purchase_receipts/**`, `admin/purchasing/**`, `ops/locations/**`, `ops/draft_pos/**`) |
| **UDS-5.0** | New selectors under `.uds-5-nav-prototype` only | Disposable `Admin::Uds5NavigationPrototypesController` and views; `config/routes.rb` one GET. Must not change `application.html.erb`, `_admin_primary_nav.html.erb`, `Admin::NavigationCatalog`, or `Admin::NavigationViewModel` behavior | None; docs, mockup labels, historical prototype tests. Product templates observation-only. **Retired in UDS-5.2.** |
| **UDS-5.1** | `:root` `--font-serif` / `--font-mono`; Source Serif 4 `@font-face`; `.app-brand` serif via CSS only; `.type-*` role classes; `.surface` / `.surface--flush`; `.page-header*` extensions; `.form-section__head` / `__body` / `__grid`; `.form-field--span-2`; `.metric-strip*`; `.data-table td.cell-primary` / `.cell-secondary` / `.cell-identifier`; `.admin-form-footer` | `shared/_page_header.html.erb`; `shared/_form_section.html.erb`; `app/assets/fonts/source-serif-4-latin-{400,600}-normal.woff2`; `application.css`. Historical disposable fixture **retired**. Do not change `application.html.erb` markup, `Admin::NavigationCatalog`, or Product family templates | Primitive coverage: `test/views/page_header_partial_test.rb`; `test/views/form_section_partial_test.rb`; `test/views/data_table_partial_test.rb`; Product composition tests |
| **UDS-5.2** | `.app-nav--grouped`, `.app-nav__strip`, `.app-nav__wide-groups`, `.app-nav__current-destination`, `.app-nav__areas`, `.app-nav__area-row`, `.app-nav-group`, `.app-nav-group__heading`, `.app-nav-group__list`, `.app-nav-utilities` | `app/views/shared/_admin_primary_nav.html.erb`; `application.css`; `config/routes.rb` (remove 5.0 prototype GET). Must not change `Admin::NavigationCatalog`, permission predicates, route inventory, destination labels, or group membership. `application.html.erb` unchanged | None. Production compact chrome. `test/integration/admin_grouped_navigation_test.rb`; `test/system/admin_grouped_navigation_test.rb` |
| **UDS-5.3** | UDS-5.1 primitives consumed on Product index/show; `.product-filters`; `.product-metrics`; `.product-panels`; `.product-variants`; `.data-table td.cell-operational` | `admin/products/{index,show}.html.erb`; `shared/_data_table.html.erb` (`header_class` / `cell_class`). Do not change ProductsController queries, catalog search, product form, or bibliographic review. `application.html.erb` and `Admin::NavigationCatalog` unchanged | `admin/products/{index,show}.html.erb`. `test/integration/admin_product_composition_test.rb`; `test/system/admin_product_composition_test.rb`; `test/views/data_table_partial_test.rb` |
| **UDS-5.4A** | UDS-5.1 primitives on catalog search and product form; `.catalog-search-query`; `.catalog-search-results`; `.product-form`; `.product-cover--thumb` | `admin/product_catalog_searches/**`; `admin/products/{new,edit,_form}.html.erb`. Do not change catalog-search params, ranking, ProductsController validation, or bibliographic review. `application.html.erb` and `Admin::NavigationCatalog` unchanged | `admin/product_catalog_searches/new.html.erb`; `admin/products/{new,edit,_form}.html.erb`. `test/integration/admin_product_search_form_composition_test.rb`; `test/system/admin_product_search_form_composition_test.rb` |
| **UDS-5.4B** | `.bibliographic-review`; `.bibliographic-review__field`; `.bibliographic-review__pair`; `.bibliographic-review__current`; `.bibliographic-review__proposed`; `.bibliographic-review__selected`; `.bibliographic-review__label`; UDS-5.1 form-section and `.admin-form-footer` on the review surface | `admin/products/bibliographic_review.html.erb`; `admin/products/_bibliographic_review_field.html.erb`. Do not change ApplyCandidate, provenance, cover download, subject matching, or lock_version handling. `application.html.erb` and `Admin::NavigationCatalog` unchanged | same views. `test/integration/admin_bibliographic_review_composition_test.rb`; `test/system/admin_bibliographic_review_composition_test.rb` |
| **UDS-5.5** | None | Docs, matrix, conventions, adoption template, [uds-5.5-closeout-evidence.md](uds-5.5-closeout-evidence.md). Do not change production templates, print, Register, or catalog membership | Evidence only |

Ownership split: [phase7.1-uds-coordination.md](../phase7.1-purchasing-polish/phase7.1-uds-coordination.md) (Accepted August 2026). Phase 7.1 owns purchasing hub, purchasing admin indexes, and Location/Draft PO ops interaction closeout. UDS-4 owns grouped nav chrome and non-purchasing adoption. A needed change to one of these is a separate behavior slice, not incidental UDS work.

### Baseline evidence and browser/viewport gate

UDS-0 records either committed screenshots or the following reproducible structured observation for each shell before implementation. Evidence uses seeded deterministic data, browser zoom 100%, no extensions, and records the route, commit, Chromium version, viewport, and state (normal plus validation/dialog/empty state as applicable).

| Shell / baseline route | Representative baseline observation | Required viewport checks |
|---|---|---|
| Admin — `/admin/suppliers` plus new/edit | Phase 2.2 white surface on blue-gray canvas; teal primary and plum secondary actions; wrapping global navigation; horizontally scrolling data table; stacked labeled form errors | Chromium at 390×844, 768×1024, and 1440×900 |
| Operations — `/ops/receiving` (selected reference) | Separate ops header, sticky shortcut strip, compact grid/row errors, keyboard-first primary action; table may scroll rather than compress | Chromium at 1280×720 (supported minimum) and 1440×900 |
| History — `/pos/completed_transactions/:id` | Screen receipt/history chrome and action group are distinct from fixed-width print markup; historical totals and post-void/return affordances depend on stored state | Chromium at 1280×720 and 1440×900; print preview at the existing receipt paper target |
| Register — active `/pos/workspace` | Fixed minimum 1280-wide cashier shell; basket, selected line, totals, feedback and modal overlays compete within 720px height; scan field regains focus | Chromium at 1280×720 (release gate) and 1440×900 |

Chromium is the automated and supported browser for this program's visual/regression baselines. Responsive admin checks below 1280 do not imply that the ops or Register workstation shells support a phone viewport. The [accessibility and ergonomic test matrix](accessibility-ergonomic-test-matrix.md) additionally requires Firefox, 320×568, 200%/400% zoom, assistive-technology, forced-colors, and timed Register evidence for foundation completion—do not treat the table above as a substitute.

**Read order for implementers:** (1) satisfy this section’s Chromium baselines and frozen suites on every UDS PR; (2) for reference-surface **conforming** status and foundation criterion 10, also complete the applicable rows of the [accessibility and ergonomic test matrix](accessibility-ergonomic-test-matrix.md).

At each required viewport above, manually check initial, hover, focus-visible, active, disabled, error, empty, long-label/long-identifier, and open dialog states when the surface contains them. Store screenshots outside the repo as PR artifacts unless the slice explicitly adds a small, approved baseline fixture.

### Behavior and indirect-impact gates

The following behavior suites are frozen expectations: a UDS change may add visual or accessibility assertions, but must not delete, relax, rename, or rewrite existing workflow assertions to make the slice pass.

| Slice | Behavioral tests that must remain unchanged and pass | Manual checks for indirect shared-CSS impact |
|---|---|---|
| UDS-1 | `test/helpers/application_helper_test.rb`; `test/integration/suppliers_admin_test.rb`; `test/integration/purchasing_ops_layout_test.rb`; `test/integration/pos_register_test.rb`; `test/integration/pos_transaction_history_test.rb`; all existing `test/system/` tests | Sign-in/store selection; one non-reference admin index/show/form with errors and empty state; inventory adjustment confirmation; ops shortcut help and inline error; completed transaction and post-void review; Register workspace; customer receipt print preview |
| UDS-2 | UDS-1 list plus `test/integration/receiving_line_lookup_test.rb`, `test/integration/purchase_orders_admin_test.rb`, `test/system/purchasing_ops_workspace_test.rb`, and `test/system/location_queue_buttons_test.rb` | Products and Stores CRUD; customer request consequence dialog; location queue; Draft PO (not the UDS-2 reference); Register sale/return; printed receipt compared with its locked one-line contract |
| UDS-3 | UDS-1 list plus `test/system/pos_register_workspace_test.rb`, `test/system/pos_linked_return_test.rb`, `test/system/pos_unlinked_return_test.rb`, `test/system/pos_mixed_return_test.rb`, `test/system/pos_close_z_test.rb`, and `test/system/store_receipt_messages_test.rb` | Admin supplier form and data table; ops receiving grid and shortcut strip; transaction history/reprint; opening, sale, controlled price action, linked and unlinked return, mixed tender, cancel, close, and focus restoration using keyboard/scanner flow; receipt print preview |
| Phase 7.1.1 | UDS-1 indirect-impact list | Hub sections per permission profile; Purchasing hub in grouped nav; no Hotwire on admin chrome |
| Phase 7.1.2 | UDS-1 list plus existing `test/integration/purchase_orders_admin_test.rb` where indexes change | Orders/PO/receipt index filters and cross-links; PO review dialog focus unchanged |
| Phase 7.1.3 | UDS-2 ops list (`purchasing_ops_workspace_test.rb`, `location_queue_buttons_test.rb`, receiving tests) | Location and Draft PO keyboard/dirty/focus interaction closeout per [phase7.1.3-ops-evidence.md](../phase7.1-purchasing-polish/phase7.1.3-ops-evidence.md) |
| UDS-4.1 | UDS-1 list plus navigation helper/view tests added in PR | Navigation-proposal profiles A and B; JavaScript-disabled baseline; 320px and 200%/400% zoom reflow |
| UDS-4.2 | UDS-1 list plus `test/helpers/admin_cross_links_helper_test.rb` and family integration tests named in each 4.2x PR | Touched admin family index/show/form; narrow-user cross-link absence; Chromium viewport spot-check |
| UDS-5.0 | UDS-1 list plus `test/integration/admin_grouped_navigation_test.rb`; add prototype integration and system tests without rewriting catalog/view-model tests | Historical: disposable prototype vs production destination set. Prototype retired in UDS-5.2 |
| UDS-5.2 | UDS-1 list plus `test/integration/admin_grouped_navigation_test.rb` and `test/services/admin/navigation_view_model_test.rb` unchanged in catalog/predicate assertions | Compact area-row chrome; narrow Areas disclosure; JavaScript-disabled links present in HTML; 320px header-height vs viewport and 200%/400% zoom; no dark utility row |
| UDS-5.3 | Frozen Product suites: `test/integration/phase22_product_ux_test.rb`; `test/integration/product_catalog_enrichment_test.rb`; `test/integration/product_inventory_display_test.rb`. Add composition tests without rewriting those files | Product index/show identity header, filters, metric strip, panels, thumbnail cover, operational variant columns; 320px and 200% zoom |
| UDS-5.4A | Frozen Product suites: `test/integration/phase22_product_ux_test.rb`; `test/integration/product_catalog_enrichment_test.rb`. Add search/form composition tests without rewriting those files | Catalog search query grouping and candidate table; product form sections/grids/sticky footer; 320px and 200% zoom |
| UDS-5.4B | Frozen `test/services/bibliographic/apply_candidate_test.rb`; `test/integration/product_catalog_enrichment_test.rb`; `test/system/uds_bibliographic_review_test.rb`. Add composition tests without rewriting those files | Review families, Current/Proposed/Selected columns, sticky footer; 320px and 200% zoom |
| UDS-5.5 | Frozen print/receipt suites: `test/services/pos/customer_receipt_test.rb`; `test/services/pos/receipt_identity_test.rb`; `test/integration/pos_mvp_closeout_test.rb`. Do not rewrite Register or print assertions | Print templates and `.pos-receipt__print*` unchanged vs `main`; serif decision recorded; no UDS-6/UDS-7 implementation |

Across all slices (including Phase 7.1 and UDS-4), `app/views/pos/receipts/_print.html.erb`, `.pos-receipt__print*`, service/controller/domain code (except Phase 7.1 read-only hub queries), Stimulus key bindings, Turbo target IDs, form actions/methods, and authorization conditions are locked unless the slice explicitly owns that behavior.

The slice PR records each manual result, viewport, and reviewer. Any indirectly affected surface that fails returns to `partial`, even if its own templates did not change.

### Review ownership

No person is permanently named in this proposed packet; ownership is enforced as three independent review disciplines, with the reviewer identity recorded in the PR. Map these to evidence IDs in the [accessibility and ergonomic test matrix](accessibility-ergonomic-test-matrix.md) when that gate applies (`K`/`SR`/`D`/`C` → accessibility; `I`/`E` and timed scenarios → domain-workflow; `R`/`S`/`T`/`M` → visual-consistency / UX, with accessibility co-sign where specified).

- **Accessibility reviewer:** keyboard-only traversal, focus visibility/order and restoration, native dialog behavior, accessible names/labels, landmarks, zoom, non-color cues, measured WCAG AA contrast, and (for reference surfaces) the matrix evidence they own. This reviewer must not be the implementing author.
- **Domain-workflow reviewer:** an owner familiar with the affected admin, purchasing, or POS contract executes the manual workflow and confirms action wording/severity, authorization visibility, historical facts, shortcuts, scanning, totals, print behavior, and timed cashier scenarios remain correct.
- **Visual-consistency reviewer:** the UDS maintainer (or a reviewer applying this packet) compares all shell baselines at matched viewport/state and checks tokens, hierarchy, density, component states, and cross-shell consistency. This reviewer may also fill one of the other roles only when the PR records both checklists.

### Token rollback

UDS-1 lands token values and alias mappings in a dedicated commit, separate from reference-view markup. Before merge, preserve the prior `:root` values as a named `legacy-phase-2-2` mapping in the PR description (not as a second live theme). If shared tokens cause widespread regressions: (1) stop later UDS slices, (2) revert the token/alias commit as a unit, (3) retain safe view-local migrations only if they pass against the restored tokens, (4) return affected matrix entries and aliases to their previous status, and (5) open a focused correction with before/after evidence across all four shell baselines. Do not patch regressions with scattered one-off hex values, `!important`, or silent alias reinterpretation.

### UDS-0 — UX authority and inventory

Documentation and inventory only:

- Inventory shells, partials, button classes, table patterns, forms, dialogs, and one-off markup in [migration-matrix.md](migration-matrix.md).
- Inventory the flat permission-gated application navigation and validate canonical task/domain groups per [navigation-proposal.md](navigation-proposal.md).
- Classify inconsistencies as: theme-only; missing shared primitive; misuse of an existing primitive; interaction redesign; domain presentation problem.
- Keep this packet and [ux-conventions.md](../../ux-conventions.md) aligned on status (Proposed vs Implemented).
- Label every mockup: inspirational, proposed, accepted, or implemented.
- Record conflicts with Phase 2.2 palette and resolve via [ADR-022](../../adr/ADR-022-warm-parchment-visual-tokens.md).

**Deliverable:** accepted planning authority; path-level inventory in [migration-matrix.md](migration-matrix.md) sufficient to start UDS-1.

Administrative navigation remains a proposal at this point. Before assigning it to UDS-1 or UDS-2, pass the proposal's prototype gate with a fully privileged administrator and a narrowly scoped store user, including permission/current-store filtering, one-destination groups, active state, keyboard/screen-reader operation, JavaScript-disabled use, and narrow-width/high-zoom reflow.

### UDS-1 — Tokens and shared visual primitives

**Implementation plan:** [uds-1-plan.md](uds-1-plan.md) (UDS-1a–1d **complete**). Slice id stays **UDS-1**—not a Phase 7 domain number. [ADR-022](../../adr/ADR-022-warm-parchment-visual-tokens.md) is **Implemented**.

High-leverage, low-behavior changes:

- Warm Parchment canvas, surface, text, border, semantic, and interaction tokens ([warm-parchment.md](warm-parchment.md)).
- Controlled migration / aliases so existing components update consistently.
- Typography hierarchy using **locally packaged or system fonts** (no runtime Google Fonts dependency). Face packaging / stack choice is owned by **UDS-1c** (see [uds-1-plan.md](uds-1-plan.md)); not UDS-1a/1b.
- Tabular numerals and identifier treatments.
- Button matrix per [button-action-semantics.md](button-action-semantics.md) via `ActionButtonHelper` (`action_link_to` / `action_button_to` / `action_submit` / `action_button`); no free-form class lists for new work.
- Map legacy `btn--secondary` → outline/neutral; preserve `btn--ghost` (style) and `btn--danger` (intent) tokens during the documented alias → deprecation sequence.
- Solid modal surfaces; consequence dialog headers/footers; focus restoration unchanged.
- Tables, definition lists, cards, forms, validation, flashes, badges, empty states, focus rings.
- Standard and compact **density classes by screen type**—not a persisted user toggle.
- Navigation may enter this slice as a shared semantic/responsive primitive only after the [navigation prototype gate](navigation-proposal.md#required-prototype-gate) passes; no Hotwire, permanent sidebar, or global search. Grouped admin nav remains **out of UDS-1** until that gate passes (see implementation plan).

**Deliverable:** many screens improve without rewriting each template; conventions palette section updated when tokens ship. **Met in UDS-1** (tokens, helper, shared primitives, docs exit). Broad helper adoption and reference-screen conforming status remain UDS-2.

### UDS-2 — Representative screen convergence

**Implementation plan:** [uds-2-plan.md](uds-2-plan.md) (sub-slices UDS-2a–2d; backlog [uds-2-user-stories.md](uds-2-user-stories.md)).

Migrate a small reference set:

1. One administrative CRUD resource (e.g. Suppliers).
2. One data-heavy purchasing workspace (**Receiving** — the accessibility/ergonomic gate reference; Draft PO may still adopt patterns later).
3. Transaction history/show (receipt summary presentation per [surface-contracts.md](surface-contracts.md)).
4. Existing consequential-action review dialogs.

For transaction/receipt detail:

- Preserve existing totals and historical contracts.
- Separate Sales / Returns / Net / Tenders only when supported by stored facts.
- Explicit **Line details** disclosures (not “audit logs”).
- Keep return/post-void eligibility server-authoritative.
- Leave printed receipt markup unchanged unless separately specified.

**Deliverable:** reference surfaces conforming; [migration-matrix.md](migration-matrix.md) updated. **UDS-2a–2d code landed** (helper adoption on allowlisted views); mark matrix **conforming** only after a11y-matrix evidence.

### UDS-3 — Register visual refinement

Separate implementation slice:

- Two-level basket hierarchy; printed receipt stays one-line.
- Functional shortcut **visual** grouping (bindings unchanged).
- Clear selected-line styling; consistent totals and feedback.
- Improved overlay/modal separation.
- Preserve shortcuts, scanning, focus restoration, controlled-action flows, and minimum workstation layout.
- No global search or master-detail drawers.

Validate with the [accessibility and ergonomic test matrix](accessibility-ergonomic-test-matrix.md), including timed cashier workflows—not visual review alone.

**Deliverable:** Register uses revised patterns without behavior regressions. **UDS-3 code landed**; mark matrix **conforming** only after a11y-matrix evidence.

### UDS-4 — Information architecture and adoption

**Implementation plan:** [uds-4-plan.md](uds-4-plan.md). Coordination with Phase 7.1: [phase7.1-uds-coordination.md](../phase7.1-purchasing-polish/phase7.1-uds-coordination.md) (**Accepted** August 2026).

- **UDS-4.0** — Complete; gate **Passed** ([uds-4.0-gate-evidence.md](uds-4.0-gate-evidence.md)).
- **UDS-4.1** — Ship grouped admin nav in `application.html.erb` via catalog/view-model; regroup existing links only; Phase 7.1 hub under Purchasing.
- **UDS-4.2** — Cross-cutting adoption on migration-matrix rows **not** owned by Phase 7.1; non-purchasing cross-link standardization.

**Out of scope for UDS-4:** purchasing hub logic, orders/PO/receipt admin templates, Location/Draft PO ops parity (Phase 7.1). Canonical group names: [navigation-proposal.md](navigation-proposal.md).

**Deliverable:** grouped, permission-filtered admin navigation without JavaScript-only destinations; non-purchasing screens migrated per coordination table.

### UDS-5 — Administrative composition

**Implementation plan:** [uds-5-plan.md](uds-5-plan.md). Tracker: GitHub milestone UDS-5 ([#44](https://github.com/BankEncore/ShelfSense-v1/issues/44)–[#50](https://github.com/BankEncore/ShelfSense-v1/issues/50)).

- **UDS-5.0** — Packet, mockup region labels, Product/header baselines, disposable compact-nav prototype gate **Passed**. **No production chrome change.**
- **UDS-5.1** — Typography and composition primitives **complete** on `main` (local Source Serif 4, type roles, page-header/form-section extensions, metric strip, table hierarchy, admin-form footer). Product family composition shipped in 5.3. Disposable composition fixture **retired**.
- **UDS-5.2** — Compact **area_row** presentation of the existing grouped catalog **complete** on `main`. Narrow widths use one **Areas** disclosure plus the current destination. Disposable 5.0 prototype route retired. Catalog membership unchanged.
- **UDS-5.3** — Product index and details composition **complete** on `main`.
- **UDS-5.4A** — Product catalog search and form composition **complete** on `main`.
- **UDS-5.4B** — Bibliographic review comparison layout **complete** on `main`. ApplyCandidate and provenance tests remain frozen.
- **UDS-5.5** — Evidence and closeout **complete** on `main`. Serif **adopted** for brand/page/record titles. Standing feature-led adoption recorded. Print non-regression recorded ([uds-5.5-closeout-evidence.md](uds-5.5-closeout-evidence.md)).

**Out of scope for UDS-5:** persistent sidebar, Cmd/Ctrl+K, NavigationCatalog/permission/route changes, Register, purchasing-ops, printed receipt, enrichment policy. Staff history composition is UDS-6.

**Deliverable:** Product reference family and compact admin header use the composition grammar without changing catalog membership or domain behavior.

## After the foundation program

- When a feature phase touches a screen, migrate that screen to accepted primitives per [phase7.1-uds-coordination.md](../phase7.1-purchasing-polish/phase7.1-uds-coordination.md) ownership (Phase 7.1 vs UDS-4).
- Give each phase explicit “UX adoption targets” citing this packet.
- Avoid opportunistic global redesign inside domain PRs.
- Keep [migration-matrix.md](migration-matrix.md) current.
- New interaction patterns in [deferred-patterns.md](deferred-patterns.md) require their own specifications.
- **UDS-4** defers purchasing screens to Phase 7.1 per [phase7.1-uds-coordination.md](../phase7.1-purchasing-polish/phase7.1-uds-coordination.md); see [uds-4-plan.md](uds-4-plan.md).
- **UDS-5** is complete on `main` (PR #57; [uds-5-plan.md](uds-5-plan.md)). Do not pull UDS-6 history or UDS-7 sidebar/search into leftover UDS-5 work.
- The [Admin Page Frame Program](../admin-page-frame/README.md) is **Accepted** (Slice 1 **Implemented on `apf-development`**, PR [#133](https://github.com/BankEncore/ShelfSense-v1/pull/133)). Further family adoption is not authorized. It is not leftover UDS-5 work and is not UDS-6, UDS-7, or UDS-8. It supersedes feature-led-only adoption only for the shared page-frame API, width modes, and explicitly authorized reference migrations in that packet.

## Explicitly deferred

See [deferred-patterns.md](deferred-patterns.md). Summary: universal master-detail drawers, global Cmd/Ctrl+K search, persisted density preference, collapsible global sidebar, Enter-on-row expand as default grid behavior, replacing admin show pages with drawers, fetching `audit_events` for every line, and broad conversion of all screens in one PR.

## Acceptance criteria (foundation program)

The UDS foundation (UDS-0 through UDS-3) is complete when:

1. Warm Parchment tokens are documented and consistently used on migrated components.
2. Existing one-off hex colors are removed from migrated components.
3. Admin, operations, and Register remain distinct shells using the same token vocabulary.
4. Primary, secondary, danger, warning, and informational feedback (badges/flashes) plus button intents (brand / neutral / warning / danger) are distinguishable without color alone ([button-action-semantics.md](button-action-semantics.md), [warm-parchment.md](warm-parchment.md)).
5. Existing native review dialogs have opaque, clearly separated surfaces and correct focus behavior.
6. Supplier administration (or chosen admin reference), one purchasing workspace, transaction detail, and the Register use the revised patterns.
7. The Register retains existing shortcuts, scanner flow, command semantics, and focus restoration.
8. Printed receipt behavior—including its one-line description contract—is unchanged unless separately specified.
9. Transaction history displays historical snapshots and does not depend on current mutable merchandise values.
10. Supplier administration, the selected **Receiving** workspace, transaction history/detail, native review dialogs (shared contract), and Register reach **`verified-automated`** per [uds-foundation-closeout-plan.md](uds-foundation-closeout-plan.md): Layer A (axe critical/serious clean), Layer B (keyboard/scanner/dialog/state workflow contracts), and Layer C (viewport/zoom/layout smoke). Deferred manual categories (SR-MANUAL, PERF-HUMAN, UX-INDEPENDENT, touch, Firefox, Lighthouse) remain open for **`conforming`** and are mapped in the [accessibility and ergonomic test matrix](accessibility-ergonomic-test-matrix.md).
11. Existing authorization, command-service, audit, idempotency, and append-only behavior is unchanged.
12. Remaining legacy screens are listed in [migration-matrix.md](migration-matrix.md) rather than silently declared complete.
13. If grouped administrative navigation is included, both required permission profiles pass its documented prototype gate and no destination depends on pointer interaction or JavaScript.
14. Future feature phases that create or materially change screens include the [UX adoption targets](ux-adoption-template.md) section and update [migration-matrix.md](migration-matrix.md) when validation completes.

The UDS foundation program is **operationally complete** when criterion 10 is satisfied at `verified-automated` per [uds-foundation-closeout-plan.md](uds-foundation-closeout-plan.md); full `conforming` certification remains a later goal.
