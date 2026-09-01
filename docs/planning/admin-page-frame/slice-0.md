# Admin Page Frame Program — Slice 0

**Program name:** Admin Page Frame Program (not UDS-6, UDS-7, or UDS-8)

**Status:** **Accepted.** Slice 0 complete. Slice 1 authorized only within [change-allowlist.md](change-allowlist.md).

Authority: [plan.md](plan.md), [choices.md](choices.md). Observations: [slice-0-evidence.md](slice-0-evidence.md).

## Purpose

Confirm the administrative surface inventory against the live repository, capture rendered evidence for representative pages, and lock the contracts Slice 1 may implement. Make no production behavior or presentation changes.

## Two decisions

1. ShelfSense needs a shared Admin page-frame contract.
2. ShelfSense does not yet authorize a page-by-page restyle.

This slice inventories every user-facing administrative flow so later family work has a finite list. Inventory membership is not authorization to migrate those flows.

## Evidence set vs implementation set

### Slice 0 evidence set (observe only)

Render and study at the viewports in [slice-0-evidence.md](slice-0-evidence.md):

| Surface | Why |
|---|---|
| Users index | Bare generation |
| Customers index | Partially composed generation |
| Products index | Composed UDS-5 generation |
| Adjustment Reason show and form | Simple record and short form |
| Store show | Long definition-heavy record |

Viewports: 1920×1080, 1440×900, 1280×720, 200% zoom at 1280 CSS pixels, 768px wide. Use 320px where the existing administrative support contract requires it.

### Slice 1 implementation set (authorized; see [change-allowlist.md](change-allowlist.md))

- Admin layout opt-in width modifier on `main.app-content`
- `admin/shared/page` layout partial
- `AdminPageHelper`
- Narrowly scoped Admin composition CSS
- Adjustment Reasons `index` / `show` (`standard`), `new` / `edit` (`narrow`), `_form` (body only)
- Frame and Adjustment Reasons composition tests, including an unmigrated page

No disposable fixture. Users, Customers, Products, and Store are **non-regression** surfaces, not migrations.

## Current layout facts

Administrative render chain:

```text
application.html.erb
└── .app-shell
    ├── shared/flash
    ├── .app-header
    │   ├── brand and current-store context
    │   └── shared/admin_primary_nav
    └── .app-content
        └── feature view yield
```

`.app-content` applies `width: min(100% - 2rem, var(--content-max))` with `--content-max: 72rem`. That is the unmigrated default. Nested yield cannot exceed it without an opt-in layout hook.

Three visible generations of administrative UI:

1. **Bare CRUD** — raw headings, paragraphs, lists, tables, and forms that rely heavily on browser defaults.
2. **Shared-primitive CRUD** — breadcrumbs, page headers, form sections, definition lists, data tables, empty states, and technical details, but without a consistent outer composition.
3. **Composed UDS-5 surfaces** — principally the Product family.

## Shared composition sources

| Source | Current role | Current limitation |
|---|---|---|
| `shared/_breadcrumbs` | Explicit navigation trail | Adoption is uneven; caller and placement remain view-owned |
| `shared/_page_header` | Eyebrow, title, subtitle, metadata, status, actions | Does not own breadcrumbs, page width, tools, or body rhythm |
| `shared/_form_section` | Grouped form fields and optional grid | Does not choose the form/page width or outer action behavior |
| `shared/_data_table` | Semantic table and scroll boundary | Surrounding result summary, filters, surface, and pagination remain view-owned |
| `.surface` / `.surface--flush` | Padded or edge-to-edge panel boundary | No universal rule determines when a surface is appropriate |
| `.metric-strip` | Compact key facts | Primarily adopted by Product; not a requirement for every record |
| `.admin-form-footer` | Sticky administrative form actions | Adopted by advanced Product forms, not a general form contract |

Slice 1 must compose these, not replace them.

## View API (APF-001)

```erb
<%= render layout: "admin/shared/page",
      locals: {
        title: "Adjustment reasons",
        width: :standard,
        breadcrumbs: [
          { name: "Home", path: root_path },
          { name: "Adjustment reasons" }
        ],
        actions: header_actions
      } do %>
  ...
<% end %>
```

The page partial renders `shared/breadcrumbs` and `shared/page_header`, omits unused tools, and invokes the width helper. Views must not `content_for` the layout width capture themselves.

## Surface-family inventory

Groups user-facing templates by flow. Partials are named only when they materially define composition. **Generation** is a provisional presentation assessment to confirm with rendered evidence. Widths are likely assignments, not Slice 1 work.

### Entry and context

| Flow | Surfaces | Family | Likely width | Generation / notes |
|---|---|---|---|---|
| Home | `home/show` | Hub/entry | `wide` | Bare; duplicates store/session facts already present in chrome. **Deferred** — landing purpose is an unresolved product decision |
| Sign-in | `sessions/new` | Form/entry | `narrow` | Standalone short form; should consume foundation without authenticated chrome |
| Store selection | `store_selections/new` | Workflow/selection | `narrow` | Selection task; preserve safe return path |

### Access and administration

| Flow | Surfaces | Family | Likely width | Generation / notes |
|---|---|---|---|---|
| Users | `users/index`, `show`, `new`, `edit`, `_form` | Index, record, form | `wide`, `standard`, `narrow/standard` | Bare legacy. Evidence: index only |
| Roles | `roles/index`, `show`, `new`, `edit`, `_form` | Index, record, form | `wide`, `standard`, `standard` | Bare legacy; record includes permissions |
| Role assignments | `role_assignments/index`, `new` | Index, workflow/form | `wide`, `standard` | Relationship management rather than ordinary entity CRUD |
| Audit events | `audit_events/index`, `show` | History index, history record | `wide`, `wide` | Coordinate with UDS-6; do not invent a parallel history grammar |
| System settings | `system_settings/show`, `edit` | Record, form | `standard`, `standard` | Bare/partial; singleton configuration |

### Stores, tax, registers, and tender configuration

| Flow | Surfaces | Family | Likely width | Generation / notes |
|---|---|---|---|---|
| Stores | `stores/index`, `show`, `new`, `edit`, `_form` | Index, record, form | `wide`, `wide`, `wide` | Shared primitives; show has one long definition list. Evidence: show only |
| Store taxes | `store_taxes/index`, `show`, `new`, `edit`, `_form` | Index, record, form | `wide`, `standard`, `standard` | Bare legacy |
| Tax classes | `tax_classes/index`, `show`, `new`, `edit`, `_form` | Index, record, form | `wide`, `standard`, `standard` | Bare legacy |
| Registers | `registers/index`, `show`, `new`, `edit`, `_form` | Index, record, form | `wide`, `standard`, `standard` | Administrative configuration only, not Register workspace |
| Tender types | `tender_types/index`, `show`, `new`, `edit`, `_form` | Index, record, form | `wide`, `standard`, `standard` | Mixed adoption |

### Financial configuration and cash management

| Flow | Surfaces | Family | Likely width | Generation / notes |
|---|---|---|---|---|
| GL accounts | `gl_accounts/index`, `show`, `new`, `edit`, `_form` | Index, record, form | `wide`, `standard`, `standard` | Bare legacy |
| Cash safes | `cash_safes/show`, `new` | Record, form | `wide`, `narrow/standard` | Shared header; no index view in current tree |
| Store cash day | `cash_store_days/show` | Hub/workspace record | `workspace` | **Deferred** as a Slice 1 reference; too domain-rich |
| Safe reconciliation | `cash_safe_reconciliations/new` | Workflow | `wide/workspace` | Consequential count-and-variance workflow |
| Cash deposits | `cash_deposits/index`, `show`, `new` | Index, record, workflow/form | `wide`, `wide`, `standard` | Preserve lifecycle/consequence distinction |

### Customers and requests

| Flow | Surfaces | Family | Likely width | Generation / notes |
|---|---|---|---|---|
| Customers | `customers/index`, `show`, `new`, `edit`, `_form`, `merge_review` | Index, record, form, workflow | `wide`, `wide/workspace`, `standard`, `workspace` | Evidence: index only. Merge is a later workflow candidate |
| Customer requests | `customer_requests/index`, `show`, `new` | Index, record/workflow, form/workflow | `wide`, `wide`, `standard` | Operational status/actions must remain prominent |

### Merchandise configuration

| Flow | Surfaces | Family | Likely width | Generation / notes |
|---|---|---|---|---|
| Departments | `departments/index`, `show`, `new`, `edit`, `_form` | Index, record, form | `wide`, `standard`, `standard` | Bare legacy; hierarchy needs intentional table/tree treatment |
| Merchandise classes | `merchandise_classes/index`, `show`, `new`, `edit`, `_form` | Index, record, form | `wide`, `wide`, `wide` | Shared primitives; long classification/GL configuration |
| Merchandise categories | `merchandise_categories/index`, `show`, `new`, `edit`, `_form` | Index, record, form | `wide`, `standard`, `standard` | Bare legacy |
| Merchandise conditions | `merchandise_conditions/index`, `show`, `new`, `edit`, `_form` | Index, record, form | `wide`, `standard`, `standard` | Bare legacy |
| Adjustment reasons | `adjustment_reasons/index`, `show`, `new`, `edit`, `_form` | Index, record, form | `wide`, `standard`, `narrow/standard` | **Slice 1 implementation set.** Shared primitives; low-risk simple CRUD |
| Merchandise lookup | `merchandise_lookups/new` | Search/workflow | `standard` | Search task rather than entity form |
| Merchandise import | `merchandise_imports/new` | Workflow | `standard/wide` | File/intake workflow |

### Products and bibliographic data

| Flow | Surfaces | Family | Likely width | Generation / notes |
|---|---|---|---|---|
| Products | `products/index`, `show`, `new`, `edit`, `_form` | Index, record, form | `wide`, `wide`, `wide` | UDS-5 composed reference. Evidence: index only. Do not migrate in Slice 1 |
| Bibliographic review | `products/bibliographic_review`, `_bibliographic_review_field` | Workflow/comparison | `workspace` | UDS-5 composed workflow; later compatibility slice |
| Catalog search | `product_catalog_searches/new`, `_matches` | Search/workflow | `wide/workspace` | UDS-5 composed search |
| Product variants | `product_variants/index`, `show`, `new`, `edit`, `_form` | Index, record, form | `wide`, `wide`, `wide` | Dense operational fields |
| Product forms | `product_forms/index`, `show`, `edit`, `_form` | Index, record, form | `wide`, `wide`, `wide` | Configures form definitions; not the Product edit family |
| Subject schemes | `subject_schemes/index`, `show`, `edit` | Index, record, form | `wide`, `wide`, `standard/wide` | Shared primitives |
| Subject headings | `subject_headings/show`, `new`, `edit`, `import`, `_form` | Record, form, workflow | `wide`, `standard`, `wide` | No index in tree; import is a distinct workflow |

### Suppliers and purchasing administration

| Flow | Surfaces | Family | Likely width | Generation / notes |
|---|---|---|---|---|
| Suppliers | `suppliers/index`, `show`, `new`, `edit`, `_form` | Index, record, form | `wide`, `wide`, `standard/wide` | UDS-2 reference family |
| Supplier variant sources | `supplier_variant_sources/show`, `new`, `edit`, `_form` | Record, form | `wide`, `standard` | No index in current tree |
| Purchasing hub | `purchasing/show`, `_section` | Hub | `workspace` | **Deferred** as a Slice 1 reference |
| Orders | `orders/index`, `show`, `new` | Index, record/workflow, form/workflow | `wide`, `wide`, `standard/wide` | Operational lifecycle actions |
| Purchase orders | `purchase_orders/index`, `show` | Index, record/workflow | `wide`, `workspace` | Consequential send/cancel remains locked |
| Purchase receipts | `purchase_receipts/index`, `show` | Index, record/workflow | `wide`, `workspace` | Consequence dialogs remain locked |

Purchasing Ops views remain under the Ops shell. Do not make Admin and Ops composition identical.

### Inventory administration

| Flow | Surfaces | Family | Likely width | Generation / notes |
|---|---|---|---|---|
| Inventory balances | `inventory_balances/index`, `show`, `history`, `rebuild` | Index, record, history, workflow | `wide`, `wide`, `workspace`, `standard` | History coordinates with UDS-6 |
| Inventory adjustments | `inventory_adjustments/new`, `show`, `confirm`, `reverse` | Workflow/form, record, workflow, workflow | `wide`, `wide`, `standard/wide`, `standard/wide` | Preserve review semantics |
| Inventory reconciliation | `inventory_reconciliations/show` | Workflow/workspace | `workspace` | Management workspace candidate |

### Stored value administration

| Flow | Surfaces | Family | Likely width | Generation / notes |
|---|---|---|---|---|
| Gift cards | `gift_cards/index`, `show`, `inquiry`, `associate`, `replace`, `credential`, `print_recovery` | Index, record, search/workflow, workflows | `wide`, `wide/workspace`, `standard/workspace` | Full-number access and voucher recovery retain security/audit boundaries |
| Gift-card programs | `gift_card_programs/index`, `show`, `new`, `edit`, `_form` | Index, record, form | `wide`, `wide`, `standard/wide` | Mixed shared adoption |
| Gift-card adjustment | `gift_card_adjustments/new` | Workflow | `standard/wide` | Consequential money workflow |
| Stored-value adjustment reasons | `stored_value_adjustment_reasons/index`, `show`, `new`, `edit`, `_form` | Index, record, form | `wide`, `standard`, `standard` | Shared/simple configuration |
| Stored-value adjustment | `stored_value_adjustments/new` | Workflow | `standard/wide` | Consequential money workflow |
| Stored-value transfer | `stored_value_transfers/new` | Workflow | `wide` | Source/destination comparison |
| Stored-value reporting | `stored_value_reports/show` | Hub/report | `workspace` | **Deferred**; may later align with reporting |
| Account activity partial | `stored_value/_account_activity` | Supporting history region | Inherits record | Align with canonical history/activity region; do not create a second page frame |

## Slice 0 decisions

Resolved in [choices.md](choices.md). None remain blocking.

- Program name is **Admin Page Frame Program** (not UDS-6, UDS-7, or UDS-8).
- API is `admin/shared/page` plus width helper / `content_for` plumbing (APF-001).
- Width escape is a modifier on `main.app-content`; `:root --content-max` unchanged (APF-002).
- Slice 1 widths: index/show `standard`, new/edit `narrow` (APF-002).
- Semantic modes locked; rem values provisional (APF-003).
- No disposable fixture (APF-004).
- Region order and canvas/surface rules accepted (APF-005, APF-006).
- Inventory likely-widths remain hypotheses (APF-007).
- CSS geometry is the width gate (APF-008).
- Home landing purpose is deferred.
- Stylesheet extraction is a separately sequenced maintenance program.

## Slice 0 work

- [x] Confirm every user-facing administrative route against this inventory ([slice-0-evidence.md](slice-0-evidence.md))
- [x] Capture evidence-set composition and CSS viewport geometry (headed Chromium optional per APF-008)
- [x] Confirm page family and width mode for the Slice 1 flow; remaining inventory widths stay provisional (APF-007)
- [x] Accept region order and canvas/surface rules (APF-005, APF-006)
- [x] Record width-escape and API decisions (APF-001, APF-002)
- [x] Selector ownership: Admin page-frame and `.app-content` modifiers only; Ops/POS/print frozen ([change-allowlist.md](change-allowlist.md))
- [x] Lock the Slice 1 allowlist and test inventory
- [x] No production behavior or presentation changes in Slice 0

## Definition of Slice 0 complete

Met. See [choices.md](choices.md) and [change-allowlist.md](change-allowlist.md).
