# Phase 9 — Implementation plan

Status: **Complete** on `main` (August 2026).

Authority: [phase9-plan.md](phase9-plan.md), [phase9-schema.md](phase9-schema.md), [ADR-024](../../adr/ADR-024-bibliographic-data-authority.md).

## Locked decisions

1. One ISBN-13 = one Product. Used copies are variants. Do not ingest `other_isbns` onto this product.
2. Product remains authoritative; ISBNdb returns a candidate DTO only.
3. `brand_name` is the commercial source (publisher / brand / manufacturer).
4. Product form is a catalog code, not a variant option.
5. Book fields are optional.
6. ISBN-10 is input only (existing normalizer).
7. No POS/receiving auto-create.
8. Covers are local Active Storage blobs downloaded on reviewed apply.
9. ISBNdb `msrp` → `list_price_cents` via BigDecimal; merchant `prices` unused.
10. Do not map subjects to merchandise categories.
11. Product search/create/enrich uses existing `products.create` / `products.update`. Product-form and subject catalogs have named configuration keys.
12. Admin stays server-rendered; cashier Register workspace remains the Hotwire surface.
13. Slice PRs may merge independently; freeze `20260824090000` once it is on `main`.

## Slice status

| Slice | Status |
|---|---|
| 9.1 Persistence correction | Complete |
| 9.2 Reviewed apply / match-before-create | Complete |
| 9.3 Product forms | Complete |
| 9.4 Local covers | Complete |
| 9.5 Subject schemes | Complete |
