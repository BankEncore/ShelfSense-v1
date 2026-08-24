# Phase 9 — Catalog schema

Status: **Accepted** with the Phase 9 packet. Authoritative with `db/schema.rb`.

Policy: [ADR-024](../../adr/ADR-024-bibliographic-data-authority.md).

UUIDv7 primary keys; `create_uuid_table` / `id: :uuid, default: nil`. `lock_version` on publishers, contributors, and products.

## `publishers`

| Column | Type | Notes |
|---|---|---|
| `name` | string, NOT NULL | Display name |
| `name_normalized` | string, NOT NULL | Unique; stripped, squeezed, downcased |
| `lock_version` | integer, NOT NULL, default 0 | |

Find-or-create on apply. No standalone publisher admin in this phase. `ON DELETE RESTRICT` from products.

## `contributors`

| Column | Type | Notes |
|---|---|---|
| `display_name` | string, NOT NULL | |
| `name_normalized` | string, NOT NULL | Unique; same normalization as publishers |
| `lock_version` | integer, NOT NULL, default 0 | |

Find-or-create by normalized name. No contributor merge.

## `product_contributions`

| Column | Type | Notes |
|---|---|---|
| `product_id` | uuid, NOT NULL, FK | |
| `contributor_id` | uuid, NOT NULL, FK | |
| `role` | string, NOT NULL | `author`, `illustrator`, `editor`, `translator`, `other` |
| `position` | integer, NOT NULL, default 0 | Display order |

Unique `(product_id, contributor_id, role)`.

## `products` (extend)

| Column | Type | Notes |
|---|---|---|
| `publisher_id` | uuid, nullable, FK → publishers | |
| `imprint` | string, nullable | |
| `edition` | string, nullable | |
| `binding` | string, nullable | Product attribute, not a variant option |
| `language_code` | string, nullable | Prefer ISO 639 when the adapter can normalize |
| `page_count` | integer, nullable | Positive when present |
| `series_name` | string, nullable | Text, not an inventory grouping |
| `series_position` | string, nullable | |
| `cover_image_url` | string, nullable | ISBNdb `image` only |
| `publication_year` | integer, nullable | Year-only provider dates; do not invent 1 January |
| `bibliographic_provider` | string, nullable | e.g. `isbndb` |
| `bibliographic_provider_key` | string, nullable | Canonical ISBN-13 |
| `bibliographic_fetched_at` | timestamptz, nullable | |
| `bibliographic_applied_at` | timestamptz, nullable | |
| `bibliographic_curated_fields` | string[], NOT NULL, default `{}` | Field names staff have saved |

**Retain:** `release_date` for full dates; `brand_name` for general merchandise (not publisher).

Check: `page_count IS NULL OR page_count > 0`. Check: `publication_year IS NULL OR (publication_year >= 1400 AND publication_year <= 2100)`.

## `bibliographic_lookup_cache`

| Column | Type | Notes |
|---|---|---|
| `lookup_key` | string, NOT NULL, unique | `isbn:{isbn13}` or `title:{normalized}` |
| `provider` | string, NOT NULL | |
| `payload` | jsonb, NOT NULL | Array of normalized candidate hashes |
| `fetched_at` | timestamptz, NOT NULL | |
| `expires_at` | timestamptz, NOT NULL | ISBN exact ~24h; title search ~1h |

Not a catalog source of truth. Replace on expiry.

## ISBNdb → product mapping

| ISBNdb | ShelfSense |
|---|---|
| `isbn13` (ISBN-10 input normalized) | `industry_identifier` / provider_key |
| `title` | `name` |
| `authors[]` | contributions, role `author` |
| `publisher` | `publishers` find-or-create |
| `edition` | `edition` |
| `binding` | `binding` |
| `language` | `language_code` |
| `pages` | `page_count` |
| `date_published` YYYY-MM-DD | `release_date` |
| `date_published` year-only | `publication_year` |
| `synopsis` (else `overview`) | `description` |
| `image` | `cover_image_url` |
| `msrp` | `list_price_cents` via BigDecimal |
| `other_isbns` | ignored for this product |
| `image_original` | never stored |
| `prices` / `with_prices` | unused |
| `subjects` | unused |
