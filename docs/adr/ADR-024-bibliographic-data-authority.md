# ADR-024: External bibliographic data is non-authoritative

- **Status:** Accepted
- **Date:** 2026-08-24
- **Accepted:** 2026-08-24

## Context

Phase 9 adds catalog enrichment so staff can look up an unfamiliar book and create or update a ShelfSense product from provider data. The first adapter is ISBNdb API v2.

[ADR-003](ADR-003-data-authority.md) places catalog master data on the central server. [ADR-014](ADR-014-conflict-resolution.md) forbids last-write-wins for business records. Provider records are incomplete, delayed, and occasionally wrong. Staff already curate titles, list prices, and descriptions.

A provider must never become a second product aggregate.

## Decision

1. **The Product aggregate remains authoritative.** External adapters return a normalized `Bibliographic::Candidate` DTO. Only an explicit staff command (`Products::Create` from a candidate, or `Bibliographic::ApplyCandidate` / refresh) writes product rows.
2. **Adapters are replaceable.** ISBNdb is the first implementation. Later providers must map into the same candidate DTO. Provider payloads are not a source of truth.
3. **Apply is reviewed.** Provider data is never written until staff select fields on the review screen. Unedited selected values keep provider provenance. Edited selected values receive staff provenance. Immediate refresh overwrite is not used.
4. **Field sources are required** for bibliographic allowlist fields in `bibliographic_field_sources`.
5. **Lookup cache is a projection.** `bibliographic_lookup_cache` stores normalized candidates, including opaque `candidate_id`, with an expiry. Cache misses may call the provider; cache hits must not be treated as catalog identity. Expired or unknown candidate IDs require a new search.
6. **Secrets and raw dumps stay out of audit.** The API key is environment-only (`ISBNDB_API_KEY`). Audit events record provider name, provider key (ISBN-13), field names applied, and actor—not credentials, authorization headers, wholesale provider JSON, or the provenance document.
7. **POS and receiving stay fail-closed** on unknown identifiers. Catalog create from a miss is an admin workflow.
8. **Cover images are local.** Provider cover URLs are downloaded onto Active Storage during reviewed apply. Remote URLs are not the product image of record.

## Consequences

- Match-before-create must consult `Identifiers::Lookup` and existing products before calling the provider.
- Tests stub the HTTP client; CI never calls ISBNdb.
- Cover images are stored locally (Active Storage). Provider `image` URLs may be fetched during reviewed apply; expiring `image_original` URLs must not be stored as the product image.
- ISBNdb `msrp` maps to integer `list_price_cents` via `BigDecimal`; merchant live prices are unused.
- A missing or invalid API key is an unavailable-provider condition, not an unhandled 500.
- `brand_name` is the commercial source (publisher / brand / manufacturer). There is no publisher table.
