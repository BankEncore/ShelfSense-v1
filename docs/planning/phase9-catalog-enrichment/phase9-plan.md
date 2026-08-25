# Phase 9 — Catalog and bibliographic enrichment plan

Status: **Implemented** (August 2026). The first persistence design (publisher/contributor authorities, remote cover URLs, immediate refresh overwrite) was replaced. Shipped contracts: [phase9-remediation.md](phase9-remediation.md), [phase9-schema.md](phase9-schema.md), [ADR-024](../../adr/ADR-024-bibliographic-data-authority.md).

## Goal

Let staff scan or search for a book ShelfSense has never carried, review trustworthy bibliographic data, match or create the correct product, and preserve locally curated information.

## Exit outcome

> Staff can scan or search for a book ShelfSense has never carried, review trustworthy bibliographic data, match or create the correct product, and preserve locally curated information.

## Scope boundary

| In scope | Out of scope (defer) |
|---|---|
| Optional bibliographic facts on Product | Book STI / work-level grouping |
| Product-specific contribution display names and roles | Publisher or contributor authority tables |
| ISBNdb adapter + candidate DTO | Second live provider, ONIX, Ingram |
| Admin match-before-create | POS/receiving/Location/Draft PO auto-create |
| Field provenance + reviewed selected-field apply | Background auto-apply; immediate refresh overwrite |
| Admin index search by ISBN/contributor | CSV bibliographic columns |
| Local Active Storage covers | Durable remote cover URLs |
| Product forms; scheme-aware subjects | Mapping subjects onto merchandise categories |
| MSRP → `list_price_cents` | Merchant live `prices` |

## Locked decisions

See [phase9-implementation-plan.md](phase9-implementation-plan.md). Policy: [ADR-024](../../adr/ADR-024-bibliographic-data-authority.md).

## Slices

### 9.1 — Optional bibliographic facts

**Build on:** `products` name, subtitle, description, brand_name, product_model, release_date, list_price_cents.

**Add:** imprint, language, page count, series, approximate release date, product form, `product_contributions` (`display_name`, `role`, `position`). Publisher text maps to `brand_name`. Edition text maps to `product_model`. Nested contributions on the product form. Fields remain optional; sidelines stay valid.

### 9.3 — ISBNdb adapter

Injectable HTTP client. Normalized candidate. Lookup cache. `ISBNDB_API_KEY` from ENV. Tests never hit the network.

### 9.2 — Match-before-create (admin)

Local `Identifiers::Lookup` first. Duplicate ISBN opens the existing product. Unknown ISBN/title searches ISBNdb. Create-from-candidate uses `Products::Create` (generated `222`, reserved industry identifier).

### 9.4 — Provenance and reviewed apply

Provider key, fetched/applied timestamps, `bibliographic_field_sources`. Refresh fetches a candidate; staff select fields on the review screen. Unedited selected values keep provider provenance; edited or cleared values are staff-authored or removed. Immediate overwrite is not used.

### 9.5 — Discovery UX

Admin product index search: name, primary identifier, industry identifier, subtitle, contributor display name. Show contributions, publisher/brand, local cover, provenance.

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

1. Staff can record optional brand/publisher text, contributions/roles, edition display text, product form, language, pages, series, local cover, and publication date without requiring those fields on non-books.
2. Entering an existing industry identifier during catalog search opens the existing product.
3. An unknown ISBN or title can fetch ISBNdb candidates; staff can create via `Products::Create` / `CreateFromCandidate` with a generated `222` and reserved ISBN-13 when present.
4. MSRP maps to integer `list_price_cents` or is omitted when unparseable/negative.
5. Refresh opens review; unselected fields stay unchanged; unedited selected values keep provider provenance.
6. POS and receiving unknown-scan behavior is unchanged.
7. No live ISBNdb calls in CI.
