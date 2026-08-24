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
3. **Overwrite is staff-controlled.** Default apply fills blank and non-curated fields only. Overwriting a curated field (including `list_price_cents` after staff edit or prior apply-and-save) requires explicit confirmation.
4. **Lookup cache is a projection.** `bibliographic_lookup_cache` stores normalized candidates with an expiry. Cache misses may call the provider; cache hits must not be treated as catalog identity. Expired rows may be replaced.
5. **Secrets and raw dumps stay out of audit.** The API key is environment-only (`ISBNDB_API_KEY`). Audit events record provider name, provider key (ISBN-13), field names applied, and actor—not credentials, authorization headers, or wholesale provider JSON.
6. **POS and receiving stay fail-closed** on unknown identifiers. Catalog create from a miss is an admin workflow.

## Consequences

- Match-before-create must consult `Identifiers::Lookup` and existing products before calling the provider.
- Tests stub the HTTP client; CI never calls ISBNdb.
- Cover URLs from ISBNdb `image` may be stored; expiring `image_original` URLs must not.
- ISBNdb `msrp` maps to integer `list_price_cents` via `BigDecimal`; merchant live prices are unused.
- A missing or invalid API key is an unavailable-provider condition, not an unhandled 500.
