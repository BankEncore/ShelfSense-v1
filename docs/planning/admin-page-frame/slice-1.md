# Admin Page Frame Program — Slice 1 completion

**Program name:** Admin Page Frame Program (not UDS-6, UDS-7, or UDS-8)

**Status:** **Implemented.** Closeout gate complete. Further family adoption is not authorized by this packet.

Authority: [plan.md](plan.md), [choices.md](choices.md), [change-allowlist.md](change-allowlist.md). This note does not rewrite [slice-0-evidence.md](slice-0-evidence.md).

## What shipped

- `admin/shared/page` is the sole public Admin page-frame API. It renders `shared/breadcrumbs` and `shared/page_header`, omits empty context/tools regions, and yields the body.
- `AdminPageHelper#capture_admin_page_width!` is single-use, maps `narrow` / `standard` / `wide` / `workspace` to classes, and is invoked only from the page partial.
- `application.html.erb` applies the capture with `class_names("app-content", content_for(:admin_page_width))`. Unmigrated pages keep `class="app-content"` and `:root --content-max: 72rem`.
- `--standard` uses `var(--content-max)`. `--admin-content-narrow` (44rem) and `--admin-content-wide` (90rem, provisional) are new tokens. `--workspace` is parent-relative `calc(100% - 2rem)`.
- Adjustment Reasons index/show use `standard`; new/edit use `narrow`. `_form` does not declare width and was not edited.

## Tests run

Slice 1:

```sh
./dev/rails-docker bin/rails test \
  test/helpers/admin_page_helper_test.rb \
  test/views/admin_page_partial_test.rb \
  test/integration/admin_page_frame_test.rb \
  test/system/admin_adjustment_reasons_composition_test.rb
```

Frozen composition (always required for this slice):

```sh
./dev/rails-docker bin/rails test \
  test/integration/admin_product_composition_test.rb \
  test/integration/admin_product_search_form_composition_test.rb \
  test/integration/admin_bibliographic_review_composition_test.rb \
  test/integration/admin_grouped_navigation_test.rb \
  test/integration/customers_admin_test.rb \
  test/integration/stores_admin_test.rb \
  test/views/page_header_partial_test.rb \
  test/views/form_section_partial_test.rb \
  test/views/data_table_partial_test.rb \
  test/system/admin_product_composition_test.rb \
  test/system/admin_grouped_navigation_test.rb
```

Handoff `./dev/rails-docker bin/ci` on `b429331` (viewport-gate remediation): RuboCop, bundler-audit, importmap audit, Brakeman, `bin/rails test` (0 failures), seeds, and `bin/rails test:system` (**161 runs, 1659 assertions**, 0 failures, 0 errors) passed in 15m8s. Slice 1 integrates on `apf-development` until a later closeout merge to `main`.

## Viewport and geometry

Automated:

- 320×568: index title, New reason, and `assert_layout_usable` (table scroll allowed); new form Cancel and `assert_layout_usable`.
- 1280×720 at 200% zoom: same gates on index and new (Cancel).
- 1920×1080: used width of unmigrated Users `.app-content` matches Adjustment Reasons index (`standard`) within 1px, and is not greater than `72 * root font-size + 1px`.

The layout gate showed `.form-field input { width: 100% }` stretching checkboxes past the content box at 320px. Slice 1 restores `width: auto` for checkbox/radio inside `.admin-page` only.

CSS geometry (no headed Chromium; same fallback as APF-008):

- Default `.app-content` remains `min(100% - 2rem, var(--content-max))` with `--content-max: 72rem`.
- `.app-content--standard` uses the same token, so migrated ordinary pages match unmigrated width.
- `.app-content--narrow` is `min(100% - 2rem, var(--admin-content-narrow))` (44rem). `.form` stays `--form-max: 40rem` inside that.
- New selector block has no `100vw`, negative margin, or `transform`.

Optional headed Chromium at 1440, 768, and remaining gates was not required to close Slice 1.

## Closeout

- Frame accepted for Adjustment Reasons.
- Product consuming the frame is a separately approved later slice.
- Next adoption is feature-led or an explicitly bounded family packet.
- [adoption-outlook.md](adoption-outlook.md) remains **not authorized**.
