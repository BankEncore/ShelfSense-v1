# Administrative UX conventions

Status: Implemented (Phase 2.2).

Concise conventions for ShelfSense server-rendered admin screens. Prefer these patterns over inventing parallel markup or CSS.

## Page anatomy

1. **Application shell** — brand, optional current-store label (only when authoritative `current_store` exists), permission-gated nav, flash.
2. **Breadcrumbs** — caller-supplied crumb arrays via `shared/breadcrumbs`. Do not infer crumbs from controller or route names.
3. **Page header** — title, optional subtitle, primary actions via `shared/page_header` / `shared/actions`.
4. **Content** — one primary task or record view inside `.app-content`.
5. **Technical details** — UUIDs, lock versions, and similar via `shared/technical_details` (`<details>`), never as the first thing users see.

## Shared partials

| Partial | Use when |
|---|---|
| `shared/flash` | Layout flash notices/alerts |
| `shared/page_header` | Title + optional subtitle/actions |
| `shared/breadcrumbs` | Explicit navigation trail |
| `shared/actions` | Grouped action links/buttons |
| `shared/status_badge` | Lifecycle/status chips (prefer helper wrappers) |
| `shared/definition_list` | Show-page labeled fields |
| `shared/data_table` | Semantic tables in a horizontally scrollable container |
| `shared/empty_state` | Empty collections or empty filter results |
| `shared/form_section` | Grouped form fields (`render layout:`) |
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

Defined on `:root` in `application.css`:

| Token | Role |
|---|---|
| `--color-background` | Page background (`#F8FAFC`) |
| `--color-surface` | Surfaces (`#FFFFFF`) |
| `--color-text` / `--color-text-muted` | Body and secondary text |
| `--color-action` | Primary actions (`#0D6E6E`) |
| `--color-accent` | Accent emphasis (`#7A2E5A`) |
| `--color-warning` | Warnings (`#E09214`) |
| `--color-border` | Borders (`#E2E8F0`) |
| `--color-danger` | Destructive actions (`#B91C1C`) |

Keep keyboard focus visible. Do not communicate meaning by color alone (pair badges with text labels).

## Hotwire

Importmap, Turbo, and Stimulus remain deferred. Phase 2.2 is Propshaft CSS + ERB only. Any Hotwire adoption must be a separately accepted change.

## Phase 3 and later

Reuse this shell, partials, helpers, and money/status conventions for inventory screens. Add domain-specific presentation (ledger language, denser operational tables) without inventing a second design system. Search/filter/pagination may expand beyond products when a phase explicitly requires it; keep `per_page` fixed in application code unless a later decision changes that contract.
