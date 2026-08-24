# Phase 9 — Implementation plan

Status: **Complete** (catalog enrichment on this branch; packet accepted August 2026).

Authority: [phase9-plan.md](phase9-plan.md), [phase9-schema.md](phase9-schema.md), [ADR-024](../../adr/ADR-024-bibliographic-data-authority.md).

## Locked decisions

1. One ISBN-13 = one Product. Used copies are variants. Do not ingest `other_isbns` onto this product.
2. Product remains authoritative; ISBNdb returns a candidate DTO only.
3. Do not overload `brand_name` as publisher.
4. Binding/format is a product attribute, not a variant option.
5. Book fields are optional.
6. ISBN-10 is input only (existing normalizer).
7. No POS/receiving auto-create.
8. Covers are URL references (`image`, never `image_original`).
9. ISBNdb `msrp` → `list_price_cents` via BigDecimal; merchant `prices` unused.
10. Do not map subjects to merchandise categories.
11. No new permission keys: `products.create` (search + create-from-candidate), `products.update` (apply/refresh).
12. Admin stays server-rendered; no Hotwire on admin chrome.
13. Slice PRs target `main`.

## Slice status

| Slice | Status |
|---|---|
| 9.1 Bibliographic facts | Complete |
| 9.3 ISBNdb adapter | Complete |
| 9.2 Match-before-create | Complete |
| 9.4 Provenance and refresh | Complete |
| 9.5 Discovery UX | Complete |
