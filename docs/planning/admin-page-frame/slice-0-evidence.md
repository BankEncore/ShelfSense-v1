# Admin Page Frame Program — Slice 0 evidence

**Program name:** Admin Page Frame Program (not UDS-6, UDS-7, or UDS-8)

**Status:** **Observations recorded; Slice 0 not complete.** Headed Chromium screenshots were not captured. Page-frame API, width-escape mechanism, and Slice 1 allowlist remain **open**. **No implementation authority.**

Authority: [plan.md](plan.md), [slice-0.md](slice-0.md). Do not treat this file as a Slice 1 start signal.

## Capture context

| Item | Value |
|---|---|
| Date | 31 August 2026 |
| Repository basis | `330fe5e` (`main`) plus the Admin Page Frame packet (uncommitted at capture) |
| App | Local `web` on `:3000` (`GET /up` 200; `GET /session/new` 200) |
| Chromium version | Not recorded (no headed browser session) |
| Method | Live route/template reconciliation; CSS computed geometry at 16px root; template inspection of the evidence set; existing Product composition system tests for 320 CSS px and 200% zoom |
| Screenshots | Not stored. Same limitation as [uds-5.0-gate-evidence.md](../ux-design-system/uds-5.0-gate-evidence.md) (MCP browser not available). Template + CSS geometry stand in for width; Product system tests stand in for composed-family reflow |

`--content-max` is `72rem` (1152px). `.app-content` is `width: min(100% - 2rem, var(--content-max))` and centered. `.form` is additionally `max-width: var(--form-max)` (`40rem` / 640px). `.data-table` has `min-width: 36rem` inside `.table-scroll` (`overflow-x: auto`).

### Shared `.app-content` width at required viewports

These numbers apply to **every** unmigrated administrative page, including the evidence set.

| Viewport | Content width | Approximate leftover canvas (centered) |
|---|---|---|
| 1920×1080 | 1152px (`72rem`) | ~384px each side |
| 1440×900 | 1152px | ~144px each side |
| 1280×720 | 1152px | ~64px each side |
| 200% zoom at 1280 CSS px | 1152px (same CSS layout as 1280) | ~64px each side |
| 768px wide | 736px (`100% - 2rem`) | 1rem gutters; ceiling not binding |
| 320px wide | 288px | 1rem gutters; `.data-table` min-width 36rem forces horizontal table scroll |

## Route inventory

Reconciled [slice-0.md](slice-0.md) inventory paths to `app/views/**/*.html.erb` on this tree (167 inventory entries, 167 matching files). `config/routes.rb` `admin` namespace, `root`, `session`, and `store_selection` were checked for user-facing GET pages.

| Check | Result | Notes |
|---|---|---|
| Every inventory flow has a matching user-facing template | **Pass** | No inventory row is missing a file |
| Every user-facing Admin (plus Home / sign-in / store selection) template appears in the inventory | **Pass** | Zero extra `.html.erb` files under those trees |
| Home, sign-in, and store selection classified | **Pass** | Home `root` hub/entry, deferred purpose; sign-in `sessions#new` form/entry `narrow`; store selection `store_selections#new` workflow/selection `narrow` |
| GET endpoints without a page template | Expected | Supporting actions only: `customers#duplicate_check`; `customer_requests` `customer_lookup` / `merchandise_lookup` (forms POST/GET into `customer_requests/new`); `merchandise_imports#template` (download); member POSTs (reactivate, merge, reverse, …) |
| Ops / Register / print | Out of scope | Not inventoried as Admin page-frame surfaces |

Inventory membership is still not authorization to migrate those flows.

## Evidence set — composition (viewport-independent)

### Users index (bare) — `GET /admin/users`

Template: [`app/views/admin/users/index.html.erb`](../../../app/views/admin/users/index.html.erb).

- No breadcrumbs, no `shared/page_header`. Bare `<h1>Users</h1>`.
- Create is a paragraph `action_link_to`, permission-gated.
- Collection is a `<ul>` of username links, not `shared/data_table`. No filters, empty state, or pagination.
- Generation **bare** confirmed.

Width: leftover canvas at 1440+ does not help a short list. `wide` is not useful until this becomes a table. Likely migrated width later: `standard` or `wide` only after a tabular index. Not a Slice 1 migration.

### Customers index (partial) — `GET /admin/customers`

Template: [`app/views/admin/customers/index.html.erb`](../../../app/views/admin/customers/index.html.erb).

- Breadcrumbs + `shared/page_header` + create action. Matches region order except tools are not a named frame region.
- Multi-control GET filters (search, lifecycle, submit) use `.filters` on the canvas — **not** one padded tools surface (the canvas/surface rule for multi-control filters).
- `shared/data_table` with empty-collection vs empty-filter copy.
- Four columns; no content-role cells; no pagination.
- Generation **partial** confirmed.

Width: four columns fit inside 72rem. Leftover at 1920 is unused margin, not clipped columns. `wide` would be a mild improvement, not a requirement. Tools-region grouping would help more than width.

### Products index (composed) — `GET /admin/products`

Template: [`app/views/admin/products/index.html.erb`](../../../app/views/admin/products/index.html.erb).

- Breadcrumbs, extended `page_header` (eyebrow, subtitle, create).
- Multi-control filters in `section.surface.product-filters` (correct surface use).
- Distinct empty vs filtered-empty states.
- Flush `surface--flush` around `data_table` with `cell-primary` / `cell-identifier` / `cell-secondary`.
- Pagination.
- Generation **composed UDS-5** confirmed.

Width: this is the evidence set’s best argument for `wide`. Six or seven columns (optional on-hand) plus identifier cells sit in a 1152px column with large empty canvas at 1920. Horizontal scroll is reserved for the 36rem table minimum at narrow widths, not for using a 1920px screen.

Reflow: [`test/system/admin_product_composition_test.rb`](../../../test/system/admin_product_composition_test.rb) already asserts index/show usable at 320×568 and 1280×720 at 200% zoom. Do not migrate Product in Slice 1.

### Adjustment Reason show (simple record) — `GET /admin/adjustment_reasons/:id`

Template: [`app/views/admin/adjustment_reasons/show.html.erb`](../../../app/views/admin/adjustment_reasons/show.html.erb).

- Breadcrumbs + `page_header` (title, code subtitle, status badge, Edit / Deactivate / Reactivate).
- One `.section.surface` with a five-row definition list. No metric strip. No `shared/technical_details`.
- Generation **shared-primitive CRUD**. Suitable Slice 1 record: fully consuming the frame does **not** mean adding technical details or metrics.

Width: `standard` (72rem) is wider than the content needs; `narrow` would also be readable. Prefer **`standard`** so Slice 1 show matches the unmigrated default visually except for region orchestration. `wide` would add empty margin only.

### Adjustment Reason new/edit (short form) — `GET /admin/adjustment_reasons/new` and `.../:id/edit`

Templates: [`new.html.erb`](../../../app/views/admin/adjustment_reasons/new.html.erb), [`edit.html.erb`](../../../app/views/admin/adjustment_reasons/edit.html.erb), [`_form.html.erb`](../../../app/views/admin/adjustment_reasons/_form.html.erb).

- Breadcrumbs + `page_header` + `form.form` with `shared/form_errors`, unlabeled stacked fields (no `form_section`), Cancel to show (edit) or index (create).
- `.form { max-width: 40rem }` already enforces readable measure **inside** the 72rem page. Fields stretch to that 40rem, not to 72rem.
- No sticky footer. Short enough that sticky must stay opt-in (already the plan).

Width: page-level `narrow` (~44rem) is close to `--form-max` (40rem). Slice 1 can use **`narrow`** for new/edit, or keep **`standard`** and let `.form` keep 40rem. Do not stretch the fields to `wide`. Aligning `narrow` with `--form-max` (40rem) is a rem-tuning option; not required to start Slice 1.

Index (not in the evidence-set table, but required for Slice 1): breadcrumbs, header, four-column `data_table`, no filters/tools/empty-state distinction. **`standard`** is enough; `wide` does not earn its keep on four columns.

### Store show (long record) — `GET /admin/stores/:id`

Template: [`app/views/admin/stores/show.html.erb`](../../../app/views/admin/stores/show.html.erb).

- Breadcrumbs + `page_header` (subtitle number/code, status, Edit/Deactivate).
- **One** `.section.surface` wrapping a 20-row definition list (identity, address, cash thresholds, receipt header/footer). This is the prohibited “long undifferentiated definition list” target.
- `shared/technical_details` correctly subordinate (id, timestamps, lock version).
- Generation **shared-primitive**; definition-heavy. Non-regression only in Slice 1.

Width: `standard` is adequate for a definition list. `wide` would make a single two-column dl worse, not better. The defect is panel split by subject, not ceiling. Confirms Store as an evidence record, not a Slice 1 consumer.

## Evidence set — per-viewport notes

Because every evidence page shares `.app-content`, leftover canvas at large CSS widths is a **layout** fact. Differences below are content, not a second width policy.

### Users index (bare)

| Viewport | Observation | Artifact |
|---|---|---|
| 1920×1080 | `h1` + list in 1152px column; large empty parchment sides; no table overflow | CSS + template |
| 1440×900 | Same 1152px column; sides smaller | CSS + template |
| 1280×720 | Column nearly full width; list still readable | CSS + template |
| 200% at 1280 | Same CSS layout as 1280; list and New user remain in flow | CSS |
| 768px | Ceiling not binding; list stacks; actions remain in document order | CSS + template |
| 320px (support contract) | No table; no 2D scroll expected from this template | CSS + template |

### Customers index (partial)

| Viewport | Observation | Artifact |
|---|---|---|
| 1920×1080 | Header + wrap-capable `.filters` + 4-col table capped at 1152px; unused sides; filters not in a tools surface | CSS + template |
| 1440×900 | Table still inside 72rem; no column clip expected | CSS + template |
| 1280×720 | Filters wrap (`.filters` flex-wrap); table `min-width: 36rem` may start inner scroll if columns are tight | CSS |
| 200% at 1280 | Header actions wrap (`.page-header` flex-wrap); filters wrap | CSS |
| 768px | Filters stack; table-scroll owns overflow | CSS + template |
| 320px | Table horizontal scroll via `.table-scroll`; page should not need 2D scroll beyond the table | CSS |

### Products index (composed)

| Viewport | Observation | Artifact |
|---|---|---|
| 1920×1080 | Strongest leftover-canvas case; filter surface + flush table trapped in 72rem | CSS + template |
| 1440×900 | Same ceiling; still unused sides | CSS + template |
| 1280×720 | Filters wrap (`.form-field--grow`); table uses full 1152px | CSS + template |
| 200% at 1280 | Titles and panels remain (system test at 1280×720 zoom 2) | [`admin_product_composition_test`](../../../test/system/admin_product_composition_test.rb) |
| 768px | Ceiling not binding; composed regions stack | CSS + template |
| 320px | Title and composition remain usable | same system test |

### Adjustment Reason show (simple record)

| Viewport | Observation | Artifact |
|---|---|---|
| 1920×1080 | Short dl in one surface; 72rem is loose; unused sides are empty, not missing panels | CSS + template |
| 1440×900 | Same | CSS + template |
| 1280×720 | Header actions wrap if needed; dl readable | CSS + template |
| 200% at 1280 | Single `h1` via page header; actions wrap | CSS + template |
| 768px | Stacked header + surface | CSS + template |
| 320px | No table; no 2D scroll expected | CSS + template |

### Adjustment Reason new/edit (short form)

| Viewport | Observation | Artifact |
|---|---|---|
| 1920×1080 | Page 72rem but fields capped at 40rem (`--form-max`); extra page canvas beside the form | CSS + template |
| 1440×900 | Same dual ceiling (page 72rem, form 40rem) | CSS |
| 1280×720 | Form 640px inside ~1152px page | CSS |
| 200% at 1280 | Stacked labeled fields; submit/cancel in `.actions` flex-wrap | CSS + template |
| 768px | Form still 40rem max, so nearly full column | CSS |
| 320px | Form 100% of 288px content; no sticky footer to obscure fields | CSS + template |

### Store show (long record)

| Viewport | Observation | Artifact |
|---|---|---|
| 1920×1080 | One long dl in one surface; unused sides; splitting panels matters more than `wide` | CSS + template |
| 1440×900 | Same | CSS + template |
| 1280×720 | dl readable; technical details collapsed at bottom | CSS + template |
| 200% at 1280 | Header wraps; dl remains one column | CSS |
| 768px | Full-width content column; still one undifferentiated list | CSS + template |
| 320px | dl stacks; technical details stay last | CSS + template |

## Width-mode validation

| Question | Result |
|---|---|
| Does unmigrated `72rem` remain acceptable as the inherited default? | **Yes.** Changing `.app-content` globally would stretch Adjustment Reason / Store forms and bare Users lists on every unmigrated page. Keep 72rem until a page opts in. |
| Do provisional `narrow` 44rem / `standard` 72rem / `wide` 90rem / `workspace` full-width values hold? | **Keep provisional; tune later.** `standard` = today’s 72rem is confirmed. `narrow` 44rem is close to existing `--form-max` 40rem — consider matching 40rem when locking rem values. `wide` 90rem (1440px) is justified by Product index at 1920, not by Adjustment Reasons. `workspace` has **no** evidence-set consumer. |
| Can Adjustment Reasons exercise `wide` (index) and `standard`/`narrow` (show/form) without a fixture? | **`standard` and `narrow` yes; `wide` not meaningfully.** Index is four columns. Show is a short dl. Form is already 40rem. Assign Slice 1 **index/show `standard`, new/edit `narrow`** (or standard page + existing `.form` cap). Do not force `wide` onto this flow. |
| Is a disposable fixture required for `workspace` or tools? | **No production fixture.** Ship optional tools/`workspace` slots in the API unused, or defer those primitives until a later approved consumer. Do not add `GET /admin/uds5_composition_prototype`-style routes. Do not wrap Product. |

## Recommendations (not locked)

These inform Slice 0 closeout; they do not authorize Slice 1.

| Topic | Recommendation |
|---|---|
| Page-frame API | Layout partial `admin/page` with locals (title, width, breadcrumbs, actions, optional tools slot, yield body) that **renders** `shared/breadcrumbs` and `shared/page_header`. `content_for` only for the layout width hook. |
| Width-escape | Opt-in on `application.html.erb`: e.g. `content_for(:admin_page_width)` sets a class on `main.app-content` (or a wrapper) so only opted-in pages leave 72rem. Default markup unchanged. No `100vw`. Ops `.ops-content` untouched. |
| Fixture | Not needed if Slice 1 does not require a live `workspace` or tools demo. |
| Rem values | Leave provisional until a headed pass or Slice 1 implementation review. Do not make `wide` the authenticated default. |
| Slice 1 allowlist | Still provisional in [change-allowlist.md](change-allowlist.md). Do not lock until API and width-escape are written into this table as chosen, not recommended. |

## Decisions to record here when taken

| Decision | Choice | Date / commit |
|---|---|---|
| Page-frame API shape | _open_ (recommendation: layout partial + layout `content_for` width hook) | |
| Width-escape mechanism | _open_ (recommendation: opt-in class on `main.app-content`) | |
| Fixture needed | **Recommended no** pending lock | 31 Aug 2026 evidence pass |
| Rem values locked or still provisional | **Still provisional** | 31 Aug 2026 evidence pass |

## Slice 1 allowlist lock

**Not locked.** [change-allowlist.md](change-allowlist.md) Slice 1 table stays provisional. Until API shape and width-escape are decided, Slice 1 has **no implementation authority**.

## Remaining before Slice 0 complete

- [x] Reconcile inventory to live templates/routes
- [x] Record evidence-set composition and CSS viewport geometry
- [ ] Headed Chromium captures at the named viewports (optional if this geometry pass is accepted as the width gate)
- [ ] Choose and record page-frame API shape
- [ ] Choose and record width-escape mechanism
- [ ] Lock Slice 1 file/test list in the allowlist
- [ ] Accept region order and canvas/surface rules as-is (they matched the evidence set)
