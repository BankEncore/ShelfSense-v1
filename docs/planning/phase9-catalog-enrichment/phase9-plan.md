# Phase 9 — Catalog and bibliographic enrichment plan

Status: **Implemented** (August 2026).

## Goal

Let staff scan or search for a book ShelfSense has never carried, review trustworthy bibliographic data, match or create the correct product, and preserve locally curated information.

## Exit outcome

> Staff can scan or search for a book ShelfSense has never carried, review trustworthy bibliographic data, match or create the correct product, and preserve locally curated information.

## Scope boundary

| In scope | Out of scope (defer) |
|---|---|
| Optional bibliographic facts on Product | Book STI / work-level grouping |
| Publishers and contributors (find-or-create) | Publisher/contributor merge admin |
| ISBNdb adapter + candidate DTO | Second live provider, ONIX, Ingram |
| Admin match-before-create | POS/receiving/Location/Draft PO auto-create |
| Provenance + staff refresh | Background auto-apply |
| Admin index search by ISBN/contributor | CSV bibliographic columns |
| Cover image URL | Active Storage / file hosting |
| MSRP → `list_price_cents` | Merchant live `prices` |

## Locked decisions

See [phase9-implementation-plan.md](phase9-implementation-plan.md). Policy: [ADR-024](../../adr/ADR-024-bibliographic-data-authority.md).

## Slices

### 9.1 — Optional bibliographic facts

**Build on:** `products` name, subtitle, description, brand_name, product_model, release_date, list_price_cents.

**Add:** publishers, contributors, product_contributions, product bibliographic columns. Nested contributions on the product form. Fields remain optional; sidelines stay valid.

### 9.3 — ISBNdb adapter

Injectable HTTP client. Normalized candidate. Lookup cache. `ISBNDB_API_KEY` from ENV. Tests never hit the network.

### 9.2 — Match-before-create (admin)

Local `Identifiers::Lookup` first. Duplicate ISBN opens the existing product. Unknown ISBN/title searches ISBNdb. Create-from-candidate uses `Products::Create` (generated `222`, reserved industry identifier).

### 9.4 — Provenance and refresh

Provider key, fetched/applied timestamps, curated field names. Default apply fills blanks and non-curated fields. Overwrite curated (including list price) requires confirmation.

### 9.5 — Discovery UX

Admin product index search: name, primary identifier, industry identifier, subtitle, contributor display name. Show contributions, publisher, cover, provenance.

## UX adoption targets

- **Screens created or materially changed:** `admin/products/index`, `admin/products/_form`, `admin/products/show`, `admin/products/new`, `admin/product_catalog_searches/new`, `admin/product_catalog_searches/create` (results)
- **Current migration-matrix state:** `partial` (`admin/products/**`)
- **Accepted primitives:** `page_header`, breadcrumbs, `data_table`, `definition_list`, `ActionButtonHelper`, filters form, `form_section`, `form_errors`
- **Applicable automated evidence:** integration coverage for lookup → candidate → create → refresh; Layer A/B/C not required for `conforming`
- **Matrix rows to update:** `admin/products/**` in [migration-matrix.md](../ux-design-system/migration-matrix.md)

### Rules

- New screens begin with accepted UDS primitives.
- A materially changed legacy screen becomes that phase's migration responsibility.
- Unrelated neighboring screens do not enter scope automatically.
- Evidence and matrix updates ship in the same PR as the feature.

## Sequencing

```text
9.1 bibliographic facts
  → 9.3 ISBNdb adapter
  → 9.2 match-before-create
  → 9.4 provenance and refresh
9.1 → 9.5 discovery search (may land with 9.1–9.4)
```

## Acceptance

1. Staff can record optional publisher, contributors/roles, edition, binding, language, pages, series, cover URL, and publication year without requiring those fields on non-books.
2. Entering an existing industry identifier during catalog search opens the existing product.
3. An unknown ISBN or title can fetch ISBNdb candidates; staff can create via `Products::Create` with a generated `222` and reserved ISBN-13.
4. MSRP maps to integer `list_price_cents` or is omitted when unparseable/negative.
5. Refresh does not overwrite curated fields without confirmation.
6. POS and receiving unknown-scan behavior is unchanged.
7. No live ISBNdb calls in CI.
