# Administrative UX conventions

Status: Implemented (Phase 2.2 architecture; **Warm Parchment palette via UDS-1**). Administrative composition grammar for the Product family and compact grouped nav is recorded in [uds-5-plan.md](planning/ux-design-system/uds-5-plan.md) (**complete** on `main`). The [Admin Page Frame Program](planning/admin-page-frame/README.md) (Slice 1 + Customer core **Implemented on `main`**) is the shared page-frame API for migrated Admin pages. Do not copy inspirational sidebar or Cmd/Ctrl+K chrome.

Concise conventions for ShelfSense server-rendered admin screens. Prefer these patterns over inventing parallel markup or CSS.

## Page anatomy

1. **Application shell** — brand, optional current-store label (only when authoritative `current_store` exists), compact grouped permission-gated nav (current-area row plus native `<details>` for other groups), flash.
2. **Page frame (migrated Admin pages)** — `render layout: "admin/shared/page"` with a semantic `width:` (`narrow` / `standard` / `wide` / `workspace`). The partial captures width through `AdminPageHelper` (views must not set that `content_for` themselves). Optional `tools` is already-rendered HTML, typically from `capture`. Unmigrated pages omit the frame and keep inherited `.app-content` at `--content-max: 72rem`.
3. **Breadcrumbs** — caller-supplied crumb arrays via `shared/breadcrumbs`. Do not infer crumbs from controller or route names.
4. **Page header** — optional eyebrow, title, optional subtitle, metadata, and status, with separately aligned actions via `shared/page_header`. The frame’s `title:` is visible page identity; `content_for :title` remains the document title in the feature view.
5. **Content** — one primary task or record view inside `.app-content`. Panels use `.surface` (padded by default; `.surface--flush` for edge-to-edge contents such as tables).
6. **Technical details** — UUIDs, lock versions, and similar via `shared/technical_details` (`<details>`), never as the first thing users see.

## Shared partials

| Partial | Use when |
|---|---|
| `admin/shared/page` | Migrated Admin pages only. Width, region order, breadcrumbs, and page header. Do not set width `content_for` from the feature view |
| `shared/flash` | Layout flash notices/alerts |
| `shared/page_header` | Optional eyebrow, title, optional subtitle/metadata/status, separately aligned actions |
| `shared/breadcrumbs` | Explicit navigation trail |
| `shared/actions` | Grouped action links/buttons |
| `shared/status_badge` | Lifecycle/status chips (prefer helper wrappers) |
| `shared/definition_list` | Show-page labeled fields |
| `shared/data_table` | Semantic tables in a horizontally scrollable container |
| `shared/empty_state` | Empty collections or empty filter results |
| `shared/form_section` | Grouped form fields (`render layout:`); pass `grid: true` for related-field grids |
| `shared/form_errors` | Error summary with links to fields |
| `shared/currency_field` | Dollar-oriented money inputs |
| `shared/technical_details` | Subordinate technical metadata |

## Status badges

Use `status_badge(status, scheme:)` (or `configuration_status_badge(active)`).

- `:product_variant` — `draft` / `active` / `discontinued`
- `:configuration` — `active` / `inactive`

Map colors only from the scheme table. Never infer meaning from arbitrary strings.

## Money

| Boundary | Representation |
|---|---|
| HTML admin forms | Dollars (`12.50`, `$12.50`, optionally `1,200.00`) |
| Persistence / import / API / CSV | Integer cents |

- **Display:** `format_money_cents`, `money_field_value` in helpers (views only).
- **Parse:** `Money::ParseCents` from controllers/services. Invalid input becomes a **field error**; do not silent-coerce or return `BadRequest` for ordinary typos. Preserve the submitted string for redisplay.

## Forms and validation

- Error summary at the top of the form (`shared/form_errors`), with `autofocus` and links to fields.
- Associate field errors/help with `aria-describedby`.
- Cancel returns to show (edit) or index (new).
- Do not use `data-turbo-confirm`. Turbo/Importmap/Stimulus are not installed. Prefer existing server behavior; if a new consequential action needs confirmation, use a server-rendered confirmation page.

## Tables and empty states

- Tables stay tabular; wrap in the shared scroll container for narrow viewports. Do not reflow to card layouts in this foundation.
- Distinguish empty collections from empty search/filter results (product index is the reference).

## Color tokens

Screen chrome uses the **Warm Parchment** vocabulary on `:root` in `application.css` ([ADR-022](adr/ADR-022-warm-parchment-visual-tokens.md) Implemented). Authoritative token tables, contrast ledger, and density rules: [warm-parchment.md](planning/ux-design-system/warm-parchment.md).

Foundation tokens (abbreviated):

| Token | Role |
|---|---|
| `--color-bg-canvas` | Page canvas (`#FBF9F5`) |
| `--color-bg-surface` | Cards, inputs, table bodies (`#FFFFFF`) |
| `--color-text-primary` / `--color-text-secondary` | Body and secondary text |
| `--color-brand-default` | Primary commit / link (`#A84320`) |
| `--color-border-subtle` / `--color-border-strong` | Decorative vs control borders |
| `--color-focus-ring` | Keyboard focus (`#7C3218`) |

Semantic families (`neutral`, `warning`, `danger`, `info`, `success`) each expose foreground, border, fill, and solid states—see the packet. Temporary Phase 2.2 aliases (`--color-background`, `--color-action`, etc.) remain only while call sites migrate; do not invent new uses of the legacy names.

Action presentation (style / intent / size): use `ActionButtonHelper` per [button-action-semantics.md](planning/ux-design-system/button-action-semantics.md). Keep keyboard focus visible. Do not communicate meaning by color alone (pair badges with text labels).

## Type roles (UDS-5.1)

Apply type through role classes and tokens. Do not set `font-family` in Product (or other) templates.

| Role | Class | Face |
|---|---|---|
| Brand | `.app-brand` (CSS only) / `.type-brand` | `--font-serif` |
| Page title | `.type-page-title` | `--font-serif` |
| Record title | `.type-record-title` | `--font-serif` |
| Section title, eyebrow, subtitle, body, help, metadata | `.type-section-title` / `.type-eyebrow` / `.type-subtitle` / `.type-body` / `.type-help` / `.type-metadata` | `--font-sans` |
| Identifier | `.type-identifier` | `--font-mono` |
| Tabular numeric | `.type-tabular` | inherits face; `tabular-nums` |
| Receipt / print | (POS print contract) | `--font-receipt` (Inconsolata) |

Serif is limited to brand, page title, and record title. Controls, navigation, tables, labels, badges, and ordinary body stay sans. **UDS-5.5 adopted** Source Serif 4 for those display roles ([uds-5.5-closeout-evidence.md](planning/ux-design-system/uds-5.5-closeout-evidence.md)).

Composition utilities: `.metric-strip`, `.data-table td.cell-primary` / `.cell-secondary` / `.cell-identifier` / `.cell-operational`, `.admin-form-footer` (admin forms; sticky). The Product family (index, show, catalog search, form, bibliographic review) consumes them. Content-role table classes apply to `<td>` only (`cell_class`); table chrome stays sans. Compact grouped nav uses a utility strip plus the current-area row; other groups stay in native `<details>`. At `max-width: 40rem` the area catalog collapses under one Areas disclosure and the current destination remains visible.

## Feature-led adoption (UDS-5.5)

- New screens use the current accepted primitives (Warm Parchment tokens, ActionButtonHelper, shared partials, type roles, composition utilities, and compact grouped admin nav).
- Existing screens adopt those primitives when the feature that owns them is next in scope—not through a UDS sweep of neighboring templates.
- Unrelated screens do not enter a feature PR automatically.
- New interaction patterns still need their own specification ([deferred-patterns.md](planning/ux-design-system/deferred-patterns.md)).
- Update [migration-matrix.md](planning/ux-design-system/migration-matrix.md) in the same change as the feature.

**Accepted exception (frame not yet Implemented):** the [Admin Page Frame Program](planning/admin-page-frame/README.md) supersedes this feature-led-only rule only for establishing the shared page-frame API, semantic width modes, and the bounded reference migrations that packet explicitly authorizes ([choices.md](planning/admin-page-frame/choices.md), [change-allowlist.md](planning/admin-page-frame/change-allowlist.md)). Slice 0 is complete. Slice 1 may implement the allowlisted frame and Adjustment Reasons only. It does not authorize a general restyle of unrelated templates. After the Slice 1 closeout gate, remaining surfaces still adopt through separately approved family or feature slices.

Staff history composition is UDS-6. Persistent sidebar and Cmd/Ctrl+K remain parked (UDS-7). Do not number the Admin Page Frame Program as UDS-6, UDS-7, or UDS-8.

## Design system evolution

Phase 2.2 **architecture** (shells, shared partials, money UX, Hotwire boundaries) remains. The Phase 2.2 **teal/plum palette is superseded** for screen chrome by Warm Parchment (UDS-1). Printed receipt/report contracts stay locked separately.

Authority:

- [UX design system](planning/ux-design-system/README.md) — Warm Parchment, adoption program (UDS-0–UDS-5), migration matrix
- [Admin Page Frame Program](planning/admin-page-frame/README.md) — Accepted shared Admin page-frame contract (Slice 1 + Customer core **Implemented on `main`**; further family adoption not authorized)
- [Warm Parchment](planning/ux-design-system/warm-parchment.md) — tokens, typography, density (WCAG AA baseline)
- [Button and action semantics](planning/ux-design-system/button-action-semantics.md) — wording, intent, style, size, review dialogs
- [UDS-1 implementation plan](planning/ux-design-system/uds-1-plan.md) — foundation delivery (complete through UDS-1d)
- [ADR-022](adr/ADR-022-warm-parchment-visual-tokens.md) — Implemented palette supersession

UDS-2 migrates representative screens onto `ActionButtonHelper` and full action semantics; UDS-3 refines Register visuals without changing bindings.

## Hotwire

Admin screens remain Propshaft CSS + ERB (Phase 2.2). The admin layout loads `application.js` (no Turbo/Stimulus) and sets `data-turbo="false"` so admin forms stay full-page POSTs. `application.js` may import small vanilla helpers for Admin-only enable/disable behavior, such as Store receipt-message textareas. Phase 5 Slice 2 uses Importmap + Turbo + Stimulus for the cashier Register workspace only (`pos.js` via the POS layout; [register-workspace.md](planning/phase4-6-point-of-sale/phase5-cash-register/register-workspace.md)). Do not add Hotwire to admin chrome as a side effect of POS work.

## Phase 3 and later

Reuse this shell, partials, helpers, and money/status conventions for inventory screens. Add domain-specific presentation (ledger language, denser operational tables) without inventing a second design system. Search/filter/pagination may expand beyond products when a phase explicitly requires it; keep `per_page` fixed in application code unless a later decision changes that contract.

## Consequential Phase 7 actions

Sending purchase orders, cancelling or re-sourcing quantity, cancelling customer requests, and correcting posted receipts use native modal review dialogs rather than browser confirmation prompts. The server-rendered dialog content summarizes the affected records and domain consequences; the submitted form continues to invoke the existing command/service and idempotency boundary. Each review uses a consequence-specific background, receives initial focus, relies on native modal focus containment, supports Escape, restores focus to its visible trigger, and provides an explicit visible cancel button. Final action labels state the exact business effect rather than using generic “Confirm” wording.

Trigger vs final-action visual treatment and label rules: [button-action-semantics.md](planning/ux-design-system/button-action-semantics.md).
