# Phase 9 — Bibliographic provider boundary

Status: **Accepted** with [ADR-024](../../adr/ADR-024-bibliographic-data-authority.md).

## Candidate DTO

`Bibliographic::Candidate` (value object, not a table):

- `isbn13`, `title`, `subtitle`
- `contributors` — array of `{ display_name:, role: }` (ISBNdb authors → `author`)
- `publisher_name`, `imprint`
- `edition`, `binding`, `language_code`, `page_count`
- `series_name`, `series_position`
- `publication_year`, `release_date`
- `description`, `cover_image_url`
- `list_price_cents` — integer or nil
- `provider`, `provider_key`, `fetched_at`

## ISBNdb API v2

- Base URL: `https://api2.isbndb.com`
- Auth: header `Authorization: $ISBNDB_API_KEY`
- ISBN: `GET /book/{isbn}` (`with_prices` off)
- Title: `GET /books/{query}?column=title&pageSize=10`
- Timeout: 5 seconds
- 404 → empty candidates
- 401 / 429 / 5xx / timeout → typed unavailable/error for the UI
- Missing key → unavailable, not 500

## MSRP

Convert `msrp` with `BigDecimal` (same rounding as `Money::ParseCents`). Never persist binary float. Organization currency is USD for this deployment. Blank, negative, or unparseable values omit `list_price_cents`.

## Secrets

- Environment variable `ISBNDB_API_KEY` only (see [development.md](../../development.md) and `compose.yml`). Locally, put the key in gitignored `.env` (copy from `.env.example`).
- Never log, fixture, or audit the key or wholesale provider payloads.

## Cache

`bibliographic_lookup_cache`: one provider call per cache miss. ISBN exact TTL 24 hours; title search TTL 1 hour.

## Tests

Injectable HTTP client. Fixture JSON. No live network in CI.
