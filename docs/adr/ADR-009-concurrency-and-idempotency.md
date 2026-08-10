# ADR-009: Optimistic concurrency and idempotency

- **Status:** Accepted
- **Date:** 2026-08-09
- **Amended:** 2026-08-09

## Context

Concurrent edits and retried commands are different failure modes. A single mechanism cannot safely solve both.

## Decision

Use optimistic concurrency control on mutable aggregate roots. Updates include the expected concurrency token and increment it atomically. A mismatch rejects the stale edit for intentional reconciliation. Child edits increment the aggregate root concurrency token. Do not use `updated_at` as a concurrency token.

In the Rails application, the physical column implementing this policy is `lock_version` (`integer`, `null: false`, default `0`), which Active Record recognizes for optimistic locking. Earlier drafts of this ADR referred to the conceptual field as `version`; that name is not required in the schema.

Every retryable business command uses a scoped idempotency record containing an idempotency key, operation type, source identity, payload hash, processing status, stored result or response reference, and completion time. Enforce uniqueness on `(source_id, operation_type, idempotency_key)`. Reuse of a key with a different payload hash is an error.

Database uniqueness constraints additionally prevent duplicated business effects, including duplicate central acceptance, inventory movements, financial postings, tenders, and receipt identities.

## Consequences

- Stale editors cannot silently overwrite current aggregate state.
- Rails raises `ActiveRecord::StaleObjectError` on conflicting updates when `lock_version` is present and submitted with the edit.
- Network retries return the original outcome rather than repeat the effect.
- Idempotency records require retention and cleanup rules long enough to cover all possible retries.
- Commands must define their aggregate boundary, payload canonicalization, and result semantics.
