# Phase 9 — Catalog schema

Status: **Accepted**, updated by the [remediation addendum](phase9-remediation.md). Authoritative with `db/schema.rb`.

Policy: [ADR-024](../../adr/ADR-024-bibliographic-data-authority.md).

UUIDv7 primary keys; `create_uuid_table` / `id: :uuid, default: nil`.

There is no publisher table and no contributor table.

## `product_contributions`

| Column | Type | Notes |
|---|---|---|
| `product_id` | uuid, NOT NULL, FK | |
| `display_name` | string, NOT NULL | Whitespace-normalized; capitalization preserved |
| `role` | string, NOT NULL | `author editor illustrator translator photographer narrator other` |
| `position` | integer, NOT NULL, default 0 | Submitted order |

Unique `(product_id, display_name, role)`.

## `products` (extend)

| Column | Type | Notes |
|---|---|---|
| `imprint` | string, nullable | |
| `product_form_id` | uuid, nullable, FK → product_forms | Assigned format |
| `binding_legacy` | string, nullable | Unmapped leftover binding text |
| `language_code` | string, nullable | Persist `en` when the adapter recognizes English |
| `page_count` | integer, nullable | Positive when present |
| `series_name` | string, nullable | |
| `series_position` | decimal(8,3), nullable | Numeric when parseable |
| `release_date` | date, nullable | |
| `release_date_approximate` | boolean, NOT NULL, default false | Year/month-only provider dates |
| `bibliographic_provider` | string, nullable | e.g. `isbndb` |
| `bibliographic_provider_key` | string, nullable | Canonical ISBN-13 |
| `bibliographic_fetched_at` | timestamptz, nullable | |
| `bibliographic_applied_at` | timestamptz, nullable | |
| `bibliographic_field_sources` | jsonb, NOT NULL, default `{}` | Per-field provenance |

Retain `release_date` and `brand_name` (publisher / brand / manufacturer). Cover images are Active Storage attachments, not a URL column.

## `product_forms`

| Column | Type | Notes |
|---|---|---|
| `code` | char(2), unique, immutable | `^[A-Z]{2}$` |
| `name` | string, NOT NULL | Staff-editable |
| `active` | boolean, NOT NULL | |
| `display_order` | integer, NOT NULL | Seed 10, 20, 30, … |
| `lock_version` | integer, NOT NULL, default 0 | |

See [product-forms-seed.md](product-forms-seed.md).

## `subject_schemes` / `subject_headings` / `product_subject_assignments`

Scheme `key` is unique and immutable. Headings: unique `(subject_scheme_id, code)` when code is present; BISAC requires a code. Assignments: unique `(product_id, subject_heading_id)`; at most one primary per product per scheme. Suggested merchandise class is a prefill hint only.

## `bibliographic_lookup_cache`

| Column | Type | Notes |
|---|---|---|
| `lookup_key` | string, NOT NULL, unique | `isbn:{isbn13}`, `title:{normalized}`, or `candidate:{uuid}` |
| `provider` | string, NOT NULL | |
| `payload` | jsonb, NOT NULL | Normalized candidate hashes including `candidate_id` |
| `fetched_at` | timestamptz, NOT NULL | |
| `expires_at` | timestamptz, NOT NULL | ISBN exact ~24h; title search ~1h |

## ISBNdb → product mapping

| ISBNdb | ShelfSense |
|---|---|
| `isbn13` | `industry_identifier` / provider key |
| `title` | `name` |
| `authors[]` | `product_contributions.display_name` |
| `publisher` | `brand_name` |
| `synopsis` | `description` (plain text) |
| `binding` | candidate `product_form_code` only; never raw `binding` on Product |
| `image` | candidate cover URL; downloaded on reviewed apply |
| `edition` | `product_model` |
| `date_published` | `release_date` + `release_date_approximate` |
| `msrp` | `list_price_cents` |
| `subjects[]` | attach existing headings on catalog match only |
