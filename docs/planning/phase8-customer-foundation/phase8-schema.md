# Phase 8 — Customer schema (proposed)

Status: **Accepted** (schema shipped on `phase-8-customer-foundation`). Authoritative with [data dictionary](../../schema/README.md) / `db/schema.rb` after merge to `main`.

Merge policy authority: [ADR-023](../../adr/ADR-023-customer-merge.md).

## `customers` (extend)

| Column | Type | Notes |
|---|---|---|
| `given_name` | string, nullable | Optional; not authoritative label |
| `family_name` | string, nullable | Optional |
| `email_normalized` | string, nullable | Lowercased/trimmed canonical form; index for lookup |
| `phone_normalized` | string, nullable | E.164 or documented domestic normalization; index |
| `preferred_contact_method` | string, NOT NULL, default `none` | `phone`, `email`, `none` — check constraint |
| `merged_into_customer_id` | uuid, nullable, FK → `customers.id` | Tombstone link; at most one hop to canonical |

**Retain:** `display_name` (required), `email`, `phone`, `notes`, `active`, `lock_version`, UUIDv7 `id`.

**Lifecycle encoding:**

- `active: false` + `merged_into_customer_id IS NULL` → inactive
- `merged_into_customer_id IS NOT NULL` → merged (also `active: false` via check constraint)

Do not add a parallel `status` enum unless migration complexity warrants it; merged is structural via FK.

## Database invariants (`merged_into_customer_id`)

| Constraint | Rule |
|---|---|
| FK | Self-referential → `customers.id`, `ON DELETE RESTRICT` |
| Index | On `merged_into_customer_id` |
| Check | `merged_into_customer_id IS NULL OR active = false` |
| Check | `merged_into_customer_id IS NULL OR merged_into_customer_id <> id` |

Service invariants (not DB checks): merge target is canonical; after merge every alias points directly at a canonical survivor (no chains).

## Normalization (application-owned)

- **Email:** strip, downcase, reject empty → `email_normalized`.
- **Phone:** strip non-digits (preserve leading `+` policy in service); store display `phone` as entered where reasonable; `phone_normalized` for match.
- **Display name search:** case-insensitive substring on `display_name` and optionally `given_name` / `family_name`.
- **Duplicate strong match:** equality on `email_normalized` or `phone_normalized` when present.
- **Duplicate weak match:** normalized token overlap on display name (document threshold in service).
- **Alias operational search:** match may use fields on merged rows, but results return the canonical survivor (see ADR-023 §8).

Populate normalized columns in model validation or `before_validation` on write; backfill migration for existing rows.

## Indexes

- Unique partial indexes on `email_normalized` / `phone_normalized` where NOT NULL are **deferred** until merge practice is stable; Phase 8 uses duplicate **suggestions**, not hard DB uniqueness on contact (organizations may legitimately share a household phone until staff merges).

## Merge audit

New audit action `customers.merge` with redacted payload:

- `source_customer_id`, `survivor_customer_id`
- `reason`
- `aliases_repointed_count` (and IDs or bounded reference)
- `customer_requests_reassigned_count` (active statuses only)
- correlation / idempotency reference

## Merge consumers inventory (Phase 8)

Documentary checklist only — execution lives in explicit calls inside `Customers::MergeCustomers` ([ADR-023](../../adr/ADR-023-customer-merge.md) §6).

| Table / domain | Behavior |
|---|---|
| `customer_requests` (active statuses) | `Customers::ReassignActiveRequests` — `UPDATE customer_id` to survivor |
| `customer_requests` (completed, cancelled) | Preserve original `customer_id`; resolve via `canonical` for display/grouping |

Future phases append inventory rows and add explicit commands (`stored_value_accounts`, buyback seller records, etc.) — not a plugin registry.

## Not in Phase 8

- `customer_phones`, `customer_emails`, `customer_addresses` tables
- `receipt_preference`, marketing consent, tax exemption fields
- Automatic profile field reconciliation on merge
