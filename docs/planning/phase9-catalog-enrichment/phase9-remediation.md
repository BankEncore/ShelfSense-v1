# Phase 9 remediation addendum

This addendum records the persistence correction and closeout slices that replaced the first Phase 9 implementation.

## Persistence

- There is no `publishers` or `contributors` table. Contribution rows store `display_name`, `role`, and `position` on `product_contributions`.
- Provider publisher text maps to `products.brand_name`. Provider edition text maps to `products.product_model`.
- `bibliographic_field_sources` is the provenance document. Unknown keys are rejected. Staff edits of one field leave other entries unchanged.
- Immediate refresh is gone. Refresh fetches a candidate, then staff review and apply selected fields.

## Provenance

Allowed keys: `name subtitle description brand_name imprint product_model language_code page_count series_name series_position release_date list_price_cents industry_identifier binding contributions product_form cover_image subjects`.

`release_date_approximate` travels with `release_date`. Collection keys (`contributions`, `subjects`) are one entry for the whole collection.

Manual create records staff provenance only for populated bibliographic allowlist fields. CSV import may still update name/status/lookup/industry identifier and records staff provenance for those bibliographic fields only. CSV does not gain Phase 9 bibliographic columns.

## Deferred (verbatim)

> Phase 9 stores provider/staff edition display text in `product_model`. Structured edition type and edition number are deferred until a workflow requires filtering, validation, or reporting by edition.

> Publication lifecycle status is deferred. `products.status` remains ShelfSense record lifecycle and must not store publishing-industry status.

Also deferred: second provider / ONIX, full BISAC universe, mapping subjects onto merchandise categories, durable remote cover URLs, automatic product merge.

## Status

**Phase 9 implemented.** Product-form normalization, durable local covers, and subject classification shipped as closeout slices after reviewed apply.
