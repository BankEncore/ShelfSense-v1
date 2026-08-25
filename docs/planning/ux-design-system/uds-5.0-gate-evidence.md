# UDS-5.0 — Compact navigation prototype gate evidence

Status: **Passed** (August 2026) — automated destination-set coverage and Chromium headless height/reflow checks complete. **UDS-5.2 shipped** the preferred `area_row` pattern and retired the disposable prototype.

Authority: [uds-5-plan.md](uds-5-plan.md) § UDS-5.0, [navigation-proposal.md](navigation-proposal.md). Tracker: [#44](https://github.com/BankEncore/ShelfSense-v1/issues/44).

Disposable prototype: `GET /admin/uds5_navigation_prototype?variant=expanded|disclosures|area_row&as_controller=…`  
**Retired in UDS-5.2** after production shipped the preferred `area_row` pattern. Historical coverage below used the prototype tests, which were replaced by production grouped-nav tests.

Measure `.uds-5-nav-prototype`, not the live `.app-header`. The live header remains UDS-4.1 expanded grouped nav.

Use the **live catalog** (including Product forms and Subject schemes). Do not freeze the historical “33 destinations” count.

## Automated coverage

| Check | Evidence |
|---|---|
| Prototype destination hrefs match production `.app-nav-group__list` for Profile A with store, all three variants | [`admin_uds5_navigation_prototype_test.rb`](../../../test/integration/admin_uds5_navigation_prototype_test.rb) |
| Profile A without store omits store-gated ops/POS links | same |
| Profile B (`purchase_receipts.manage` only) sees hub + Receiving ops; omits Orders/Users | same |
| `as_controller=admin/products` marks Products + Merchandise; `admin/users` marks Users + Security | same |
| Disclosures: native `<details>`; current group starts `open`; other destinations remain in the DOM | same |
| Area row: current destinations in `.uds-5-nav-prototype__area-row`; other groups in `<details>` | same |
| Production Product index does not render the prototype | same |
| Compact variants shorter than expanded at 1440×900; destinations present at 320px and 200%/400% zoom; no prototype horizontal scroll at 320px | [`admin_uds5_navigation_prototype_test.rb` (system)](../../../test/system/admin_uds5_navigation_prototype_test.rb) |
| Keyboard: Enter on a closed group summary reveals destinations | same |
| Existing UDS-4.1 Profile A/B layout tests still pass | [`admin_grouped_navigation_test.rb`](../../../test/integration/admin_grouped_navigation_test.rb) |

Run:

```sh
./dev/rails-docker bin/rails test \
  test/integration/admin_uds5_navigation_prototype_test.rb \
  test/integration/admin_grouped_navigation_test.rb \
  test/system/admin_uds5_navigation_prototype_test.rb
```

## Preferred compact pattern

Both compact variants **passed** against expanded.

**Preferred for UDS-5.2:** `area_row` — compact group triggers plus an in-flow row of the current group’s destinations. Non-current groups stay in native `<details>`, so every destination remains in the DOM with JavaScript disabled. Current-area destinations stay visible without an extra disclosure click.

`disclosures` is an acceptable fallback if area-row presentation needs adjustment.

Light parchment chrome only. Do not ship espresso sidebar/topbar or Cmd/Ctrl+K.

## Manual / environment notes

| Item | Result |
|---|---|
| Headed Chromium 390×844 / 768×1024 screenshots | Not captured in this environment (MCP browser could not reach host `:3000`). Template observations below plus headless Chromium system tests stand in. |
| Screen-reader (VoiceOver/NVDA) | Not run here. Prototype uses native `<details>`/`<summary>`, existing `aria-label="UDS-5 prototype primary"`, `aria-current="page"`, and visually hidden “Current area”. |
| JavaScript disabled | Proven by integration tests: destination `<a href>` nodes exist inside closed `<details>`. No Stimulus on the prototype. |

## Gate profiles

Record date, browser, OS, viewport, input method, profile, route, expected/observed destinations, and defects.

### Profile A — system administrator

| Scenario | Viewport | Done | Notes |
|---|---|---|---|
| With current store + multiple stores; all catalog groups; Switch store present | Desktop (~1280 CSS px) | [X] | Integration: destination set matches production |
| `as_controller=admin/products` — Products current, Merchandise Current area | Desktop | [X] | Integration |
| Without current store — store-gated ops omitted | Desktop | [X] | Integration |
| Keyboard-only: Enter on a closed group summary reveals destinations | Desktop | [X] | System: Security summary |
| Reflow 320 CSS px — no destination lost; prototype does not require 2D scroll | 320 CSS px | [X] | System |
| Zoom 200% and 400% — destinations remain in the DOM | Desktop | [X] | System |
| JavaScript disabled — all authorized links still present | — | [X] | Integration (links in HTML) |

### Profile B — `purchase_receipts.manage` only (store selected)

| Scenario | Viewport | Done | Notes |
|---|---|---|---|
| Purchasing hub + Receiving ops; no Orders/Users/Switch store | Desktop | [X] | Integration |
| `as_controller=ops/receiving` marks Current area | Desktop | [X] | Integration |
| Direct URL to Orders denied | — | Covered by existing grouped-nav test | |

## Sign-off

| Role | Name | Date | Gate pass? |
|---|---|---|---|
| Implementer | Automated gate + Chromium headless system tests | August 2026 | Yes |
| Reviewer | Merge review on [PR #57](https://github.com/BankEncore/ShelfSense-v1/pull/57) | August 2026 | Yes |

**Gate passed.** UDS-5.2 shipped compact `area_row` presentation of the existing catalog and retired the disposable prototype. UDS-5.3 is not blocked.

---

## Product and header baselines (UDS-5.0)

Structured observations of **production** screens (not the disposable prototype). Chromium viewports required: 390×844, 768×1024, 1440×900. These describe current composition so 5.1–5.4 can compare; they are not a permission to restyle in 5.0.

### Production application header

| Observation | 390×844 | 768×1024 | 1440×900 |
|---|---|---|---|
| Grouped catalog in `.app-nav--grouped` | Stacks to one column (`max-width: 40rem`) | Multi-column wrap | Multi-column wrap; tall link wall |
| Brand + current-store meta above groups | Present | Present | Present |
| Home and Sign out are utilities, not a domain group | Present | Present | Present |
| Current destination `aria-current="page"` + group “Current area” | Unchanged UDS-4.1 contract | same | same |

Headless Chromium at 1440×900: production `.app-nav--grouped` has positive height and is the expanded control. Compact comparison is the prototype, not a production chrome change.

### Product index (`admin/products`)

| Observation | Notes (all three viewports) |
|---|---|
| Page header | Title “Products”, subtitle “Catalog products and their sellable variants”, solid brand “New product” when permitted |
| Filters | Single `.filters` row: Search, Status, Category, Apply. No composed filter grouping yet |
| Table | `shared/data_table` columns: Name, Primary identifier, Category, Variants (numeric), List price (numeric), Status, optional On hand. Horizontal `.table-scroll` at narrow widths |
| Empty | Distinct empty vs filtered-empty copy |
| Hierarchy | Name is a link; identifier/category are equal-weight cells — no primary/secondary column treatment yet |

### Product details (`admin/products/:id`)

| Observation | Notes |
|---|---|
| Identity | `.product-identity` flex wrap: optional cover (`max-height: 160px`, `max-width: 120px` thumbnail) + `page_header` title (product name), subtitle (contributors + primary identifier), status/actions |
| Long title | `h1.page-header__title` wraps with the header; no clamp/overflow hide |
| Metric strip | `.product-summary` auto-fit grid: primary identifier, list price, variant count, optional on-hand. Not yet a named metric-strip primitive |
| Identity / publication | One `.surface` with stacked `h2` Identity then Publication definition lists; description `h3`; refresh form inline |
| Variants | Separate surface; operational columns (SKU, type, class, department, tax, price, on hand, actions) share one table with identity-ish name/SKU |
| Cover missing | Cover image omitted; heading still renders |
| Large variant collection | Table scrolls horizontally in `.table-scroll`; no pagination of variants |
| Recent activity | Existing audit list when events exist — **no new queries in UDS-5** |

### Product edit with validation errors

| Observation | Notes |
|---|---|
| Header | Title “Edit product”, subtitle primary identifier |
| Form | `shared/form_section` groups: Identity, Bibliographic details, Classification, Cover already inside bibliographic section, contributors/subjects as fieldsets. Fields stack; no related-field CSS grid yet |
| Errors | `shared/form_errors` summary + per-field `.field-error`; invalid name gets `aria-describedby` |
| Actions | Submit in the form flow; **not** a sticky admin-form footer |

### Catalog search (`new_admin_product_catalog_search_path`)

| Observation | Notes |
|---|---|
| Header | Title “Find a book”, subtitle search-then-ISBNdb |
| Form | Single query field + Search + “Create blank product” |
| Results | Sectioned strong/weak matches in `.section.surface` tables when present — not yet composed search hierarchy |

### Bibliographic review

| Observation | Notes |
|---|---|
| Header | Title “Review bibliographic data” |
| Layout | Per-field `<fieldset>` with Current vs Proposed columns (`.bibliographic-review__pair` stacks at narrow CSS) |
| Behavior | Apply/provenance/concurrency **frozen** for UDS-5.4B; this baseline is presentation only |

## Composition gap vs Proposed mockup regions

These gaps are why UDS-5.1–5.4 exist; they are **not** 5.0 work:

- No role-based type / display serif
- Page header has no eyebrow slot; actions share one `.actions` wrap
- Metric strip is Product-specific CSS, not a shared primitive
- Tables lack primary vs secondary column hierarchy
- Forms lack sticky footer and related-field grids
- Header is a tall expanded catalog (compact presentation gated here, shipped in 5.2)
