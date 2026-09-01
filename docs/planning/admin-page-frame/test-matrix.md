# Admin Page Frame Program — Test matrix

**Program name:** Admin Page Frame Program (not UDS-6, UDS-7, or UDS-8)

**Status:** **Accepted.** Slice 0 complete. Slice 1 authorized only within [change-allowlist.md](change-allowlist.md).

Authority: [plan.md](plan.md), [change-allowlist.md](change-allowlist.md), [choices.md](choices.md). A UDS change may add visual or accessibility assertions but must not delete, relax, rename, or rewrite existing workflow assertions to make the slice pass.

## Slice 0

Complete. Documentation only. Evidence: [slice-0-evidence.md](slice-0-evidence.md). Choices: [choices.md](choices.md).

## Slice 1 — tests to add

There is no dedicated Adjustment Reasons admin integration suite today. Slice 1 must add composition coverage rather than overloading unrelated authz tests. No fixture tests.

| Layer | Suggested location | Asserts |
|---|---|---|
| View / request | New `test/integration/admin_page_frame_test.rb` (name may vary) | `admin/shared/page` region order; breadcrumbs and page header come from shared partials; empty tools omitted; `standard` / `narrow` modifier on Adjustment Reasons; unmigrated page has no `.app-content--*` modifier and stays at `72rem` |
| Request | Same or `test/integration/admin_adjustment_reasons_composition_test.rb` | Index/show/new/edit render through the frame; index/show `standard`; new/edit `narrow`; validation redisplay; cancel targets unchanged |
| System | New system test if keyboard/zoom cannot be proven at request layer | 320px / 200% zoom: title visible, actions reachable, no two-dimensional page scroll except table overflow |

## Slice 1 — frozen non-regression

Must stay green. Do not rewrite these files to pass frame work.

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
  test/views/data_table_partial_test.rb
```

Also run the corresponding Product composition **system** tests if Slice 1 CSS could affect layout:

```sh
./dev/rails-docker bin/rails test \
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
