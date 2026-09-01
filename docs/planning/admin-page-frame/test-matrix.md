# Admin Page Frame Program — Test matrix

**Program name:** Admin Page Frame Program (not UDS-6, UDS-7, or UDS-8)

**Status:** **Accepted.** Slice 0 complete. Slice 1 **Implemented**.

Authority: [plan.md](plan.md), [change-allowlist.md](change-allowlist.md), [choices.md](choices.md). A UDS change may add visual or accessibility assertions but must not delete, relax, rename, or rewrite existing workflow assertions to make the slice pass.

## Slice 0

Complete. Documentation only. Evidence: [slice-0-evidence.md](slice-0-evidence.md). Choices: [choices.md](choices.md).

## Slice 1 tests (new)

```text
test/helpers/admin_page_helper_test.rb
test/views/admin_page_partial_test.rb
test/integration/admin_page_frame_test.rb
test/system/admin_adjustment_reasons_composition_test.rb
```

| Layer | Location | Asserts |
|---|---|---|
| Helper | `test/helpers/admin_page_helper_test.rb` | Symbol/string mapping for all four modes; invalid value stores no capture; second call raises; no class injection |
| View | `test/views/admin_page_partial_test.rb` | Region order; omitted empty context/tools; tools HTML unescaped; missing width/title; partial does not set `content_for :title` |
| Request | `test/integration/admin_page_frame_test.rb` | One `.admin-page`; exact `main` class; index/show `standard`; new/edit `narrow`; frozen `_form` contract; 422 redisplay; unmigrated Users has no modifier; scoped CSS block |
| System | `test/system/admin_adjustment_reasons_composition_test.rb` | 320px / 200% zoom title and actions; at 1920, unmigrated Users used width matches Adjustment Reasons index (`standard`) within 1px |

## Existing frozen regression tests

Must stay green. Do not rewrite these files to pass frame work. Always run for this slice (layout CSS and `application.html.erb` changed):

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

Full CI before Slice 1 handoff: `./dev/rails-docker bin/ci`

## Viewport and space-use gates (Slice 1, Adjustment Reasons plus unmigrated spot-check)

Review at minimum:

- 1920×1080
- 1440×900
- 1280×720
- 200% zoom at 1280 CSS pixels
- 768px wide
- 320px wide where the existing administrative support contract requires it

At each gate:

- Primary content uses available space without excessive empty margins on migrated pages
- Readable text and short forms do not stretch merely because space exists
- Page actions and final form actions remain reachable
- No two-dimensional page scroll except intentional table overflow
- Unmigrated Users, Customers, Products, and Store pages match pre-Slice-1 width except documented shared-CSS impact

Automated coverage: 320, 1280@200% zoom, and 1920 used-width comparison in the system test. Remaining viewports: CSS geometry plus optional headed Chromium (same fallback as APF-008). Evidence: [slice-1.md](slice-1.md).

## Accessibility and keyboard (Slice 1)

- Heading hierarchy is valid; page title remains the sole `h1`
- Landmarks remain meaningful
- Focus order follows visual and task order
- All Adjustment Reasons actions remain keyboard reachable
- Focus indicators are visible against canvas and surfaces
- Status is not communicated by color alone
- Validation summary links focus or identify their fields

## Behavioral non-regression

- Navigation destination membership and permission filtering unchanged
- Adjustment Reasons forms submit the same parameter contract
- Lifecycle commands (deactivate/reactivate, system-protected) unchanged
- Admin remains full-page / server-rendered
- Ops keyboard/dirty-form behavior unchanged
- Register keyboard, shell, receipt, and print contracts unchanged
