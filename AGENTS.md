# AGENTS.md

This file defines the working rules for human contributors and coding agents in the ShelfSense repository. It applies to the repository root and all descendant paths unless a more specific `AGENTS.md` adds compatible local guidance.

## 1. Start with project authority

Before changing behavior or schema:

1. Read `README.md` for current scope and phase boundaries.
2. Read `docs/adr/README.md` and every ADR relevant to the change.
3. Read the applicable domain, workflow, schema, glossary, security, testing, and roadmap documentation when present.
4. Inspect existing code and tests before proposing a new pattern.

Accepted ADRs are authoritative. Proposed ADRs are not settled policy. If a requested change conflicts with an accepted ADR, stop and identify the conflict; add or request a superseding ADR before implementing the incompatible design.

Do not infer ShelfSense requirements from ShelfStack or another earlier project. Similarity is useful background, not authority.

## 2. Respect the current phase

Implement only the approved phase or task scope. Phase 1 is the operable foundation:

- System settings
- Stores
- Users and server-side authentication sessions
- Roles, permissions, role permissions, and scoped role assignments
- Registers as durable logical POS checkout identities (table may still be named `workstations` until the pre-Phase-4 rename; see ADR-021)
- Authentication and authorization
- Append-only audit events
- Safe bootstrap of the first organization configuration, store, system actor, and administrator

Do not pull later-domain functionality into Phase 1 merely because the schema may eventually need it. In particular, defer POS transactions, business days, POS sessions, drawers, merchandise, inventory, customers, suppliers, purchasing, offline Terminal authentication, and synchronization unless the task explicitly advances that scope.

Build vertical slices that produce demonstrable behavior. Avoid migrations or generic CRUD screens that have no corresponding authorization, validation, audit, and test coverage.

## 3. Use ShelfSense vocabulary exactly

Use the canonical language established by ADR-011, ADR-021, and project documentation:

- `supplier`, not `vendor`
- `register` for a durable logical POS checkout position within a store (ADR-021)
- `terminal` for a concrete POS client/device identity (deferred until standalone/offline POS; ADR-021)
- Do not use `workstation` as a POS domain synonym for Register or Terminal in new work
- `session` for an authenticated or operational period, qualified when ambiguity exists
- `inventory_unit` for an individually tracked physical unit
- `inventory_balance` for a mutable inventory projection
- `reserved`, not `pending`, for inventory commitment
- `return_to_supplier`
- `cancelled`, with two l's
- `completed` unless `finalized` or `posted` is intentionally distinct
- `reversal_of_id` and `reversed_by_id` for compensating relationships

Tables are lowercase plural `snake_case`. Primary keys are `id`; foreign keys use singular `_id`. Add materially distinct terms to the glossary rather than creating local synonyms.

## 4. Preserve data authority and offline boundaries

ShelfSense is single-tenant and multi-store. Do not add a tenant or organization ID to every table unless a later ADR changes the deployment model. Retain `store_id` wherever store scope is meaningful.

The central server owns master data and consolidated projections. A Terminal (when introduced) caches server-owned reference data and must not directly edit those cached records. Register-originated completed operations (produced via an authorized Terminal when offline) synchronize as immutable facts.

Classify new Terminal-originated operations explicitly as one of:

- Locally completable
- Locally completable with reconciliation risk
- Online-authorized

Do not make a shared or scarce resource available offline without an explicit bounded-risk design. Stored-value redemption is online-authorized until a later decision provides such a mechanism.

Never resolve completed business conflicts with last-write-wins. Preserve the originating fact, then accept, flag, quarantine, reverse, or compensate according to documented policy.

## 5. Model identity, money, rates, and time deliberately

- Use UUIDv7 for durable business entities that may be synchronized or externally referenced.
- Generate identifiers at the record's point of origin.
- Keep receipt and other document numbers separate from primary keys.
- Mixed UUID and integer keys are allowed only for a documented reason, such as small static lookups or purely local technical rows.
- Store authoritative money as signed integer minor units with explicit currency context; use `_cents` when cents are the unit.
- Never use binary floating point for authoritative financial calculations.
- Store conventional percentages as integer `_basis_points` when adequate; document any finer fixed-scale representation.
- Define and test allocation and rounding rules. Persist authoritative rounded outcomes.
- Use `_on` for dates and `_at` for timezone-aware timestamps.
- Store event timestamps as UTC instants and retain the store's IANA timezone.
- Store `business_date` explicitly where operationally relevant; never reconstruct it later from `created_at`.

## 6. Enforce lifecycle and immutability

Apply this rule:

> Draft intent may be edited. Effective configuration is superseded. Completed business facts are reversed or corrected through new records.

Do not add generic edit or delete behavior to completed transactions, tenders, cash movements, inventory ledger entries, posted financial records, receipts, audit events, or immutable event payloads.

Use explicit lifecycle fields and operations—active/inactive, revoked, expired, discontinued, cancelled, superseded—rather than applying `deleted_at` indiscriminately. Hard deletion is limited to unreferenced mistakes, disposable drafts, technical data, or authorized privacy cleanup.

Keep mutable delivery, acknowledgment, retry, and reconciliation state separate from immutable business content when it has a real lifecycle.

## 7. Treat authorization as application behavior

Authorization must be enforced in application or service logic, not only through hidden buttons or routes.

- Permissions are additive.
- `role_assignments.store_id IS NULL` means global authority.
- A populated `store_id` scopes the assignment to that store.
- Global assignments contribute authority in active stores.
- Store-scoped assignments never grant organization-wide administration.
- Organization-wide administration requires the relevant permission through a global assignment.
- `system_administrator` is a normal role populated through `role_permissions`; it is not a bypass.
- Preserve at least one active, sign-in-capable user with an effective global `system_administrator` assignment.
- Permission keys are defined and seeded by code. Do not create arbitrary runtime permission semantics.

Every authenticated request should resolve the current user, current store when applicable, and effective permissions. Test direct unauthorized requests, not only navigation visibility.

## 8. Audit material actions safely

Create append-only audit events for material security, configuration, pricing, tax, POS, returns, inventory, cash, purchasing, financial, synchronization, and sensitive-access activity as applicable.

Audit events should capture the actor, outcome, action, subject, occurrence and recording times, relevant store/register/session context, reason, correlation, selective before/after values, and application version. Snapshot human-readable labels where later renaming would obscure history.

Write an audit event in the same database transaction as a successful server-side change whenever possible. Record failed authentication and denied sensitive actions independently when no business transaction exists.

Never place passwords, password digests, bearer tokens, reset tokens, private keys, complete payment credentials, or indiscriminate row dumps in audit data, logs, fixtures, exceptions, or event payloads.

## 9. Design for concurrency, retries, and delivery

Use Rails optimistic locking via an integer `lock_version` on mutable aggregate roots. Updates must compare the expected `lock_version` and increment it atomically. Child changes increment the root `lock_version`. Do not use `updated_at` as a concurrency token.

Retryable commands require a scoped idempotency key, operation type, source identity, canonical payload hash, status, and stored outcome or response reference. Reusing a key with different input is an error.

Use database uniqueness constraints to prevent duplicate business effects. Do not rely on an application-level existence check where concurrent requests can race.

Business changes and outbox messages commit in the same database transaction. Delivery is at least once; consumers deduplicate by event ID and must be idempotent. Event schemas are versioned and contain the minimum immutable facts consumers need.

## 10. Database and migration rules

- PostgreSQL is authoritative. Do not introduce SQLite-specific behavior or assumptions.
- Do not edit `db/schema.rb` directly; change the schema through migrations and commit the regenerated schema.
- Use the project's UUIDv7 policy for new durable business entities. Domain models assign UUIDv7 through the shared Rails concern (`SecureRandom.uuid_v7` before validation on create). Migrations use `create_uuid_table` / `id: :uuid, default: nil` so PostgreSQL does not install `gen_random_uuid()`.
- Prefer explicit foreign keys and database constraints for durable invariants.
- Use polymorphic references only when the open-ended relationship is intentional, such as audit subjects.
- Name constraints and indexes consistently when the framework permits it.
- Add indexes that support foreign keys, uniqueness, authorization checks, synchronization, and documented query patterns.
- Normalize case-insensitive keys before or as part of uniqueness enforcement.
- Make migrations reversible when safe. For irreversible data changes, document the recovery plan.
- Separate destructive migrations from application rollout when compatibility requires staged deployment.
- Never repurpose or silently reinterpret a field that appears in historical facts.
- Seed stable permissions and protected roles deterministically and idempotently.

Schema changes must update the schema reference or data dictionary in the same change.

## 11. Testing expectations

Every behavior change should include tests at the lowest useful level and at the boundary where the behavior matters.

At minimum, cover as applicable:

- Domain invariants and validation
- Database constraints and uniqueness
- Global versus store-scoped authorization
- Direct access denial
- Final-administrator and protected-system-actor safeguards
- Authentication, session expiry, revocation, and deactivation
- Optimistic-concurrency failures
- Idempotent retries and payload mismatch
- Audit creation and sensitive-field redaction
- Transactional rollback, including business change plus audit/outbox records
- Timezone and business-date boundaries
- Monetary allocation and rounding
- Synchronization duplication, reordering, and retry behavior
- Immutability and compensating workflows

Use deterministic clocks, identifiers, and test data when supported. Do not weaken production constraints merely to simplify fixtures.

Run the smallest relevant test set during development and the full project validation required by CI before handoff.

Local development is Docker-only. Do not require contributors to install Ruby, Rails, Bundler, or PostgreSQL on the host. Use the project helper for application commands:

```sh
./dev/rails-docker bin/rails test
./dev/rails-docker bin/rubocop
./dev/rails-docker bin/brakeman --no-pager
./dev/rails-docker bin/bundler-audit
./dev/rails-docker bin/rails db:prepare
```

Build and initialize the environment with `docker compose build` and `docker compose run --rm web bin/setup --skip-server`. Run the application with `docker compose up`. The helper uses `docker compose exec` when `web` is running and `docker compose run --rm` otherwise.

GitHub Actions is a separate controlled environment and may invoke the same committed `bin/` commands directly after setting up Ruby and PostgreSQL.

System tests and JavaScript dependency auditing are intentionally deferred. Do not add either CI check until the prerequisites in `docs/testing.md` are satisfied.

## 12. Security and privacy

- Use the selected framework's proven password hashing and session facilities; do not invent cryptography.
- Store only a digest of a server-side session token, never the usable bearer token.
- Revoke active sessions after user deactivation and according to the password-change policy.
- Use least privilege for database, register, Terminal, integration, and deployment credentials.
- Keep secrets out of source, fixtures, logs, audit metadata, screenshots, and documentation.
- Validate all authorization server-side and scope store queries explicitly.
- Treat customer, payment, employee, and audit data as sensitive.
- Store only approved card metadata; never store full card data or security codes.

Escalate security-sensitive design uncertainty instead of creating an undocumented exception.

## 13. Documentation and ADR discipline

Update documentation in the same change when behavior, schema, terminology, permissions, operational workflows, or deployment requirements change.

Create an ADR when a decision is cross-cutting, difficult to reverse, affects offline authority, changes data ownership, introduces infrastructure, or supersedes an accepted architectural policy. Do not use an ADR for routine implementation details that fit existing decisions.

An ADR should include status, context, decision, and consequences. Mark unresolved choices `Proposed`; do not describe them as accepted elsewhere.

Keep README setup instructions executable and current. Development procedures belong in `docs/development.md`; CI coverage and deferred checks belong in `docs/testing.md`. Issue, PR, milestone, and release conventions belong in `docs/github-workflow.md`.

Use Rails-native patterns unless an accepted ADR or an established project pattern requires otherwise. The frontend dependency strategy is not yet settled: do not assume the presence of `importmap-rails`, Turbo, or Stimulus in the Gemfile means those tools have been installed or adopted.

## 14. Change discipline

- Keep each change focused on one coherent outcome.
- Preserve unrelated user changes in a dirty worktree.
- Do not perform broad refactors while implementing a narrow feature without explicit agreement.
- Prefer clear domain services or commands over callbacks that hide consequential behavior.
- Avoid speculative abstractions and infrastructure not required by an accepted decision or current phase.
- Include validation, authorization, audit, tests, and documentation as part of the feature—not as optional cleanup.
- Explain assumptions and unresolved policy in the handoff.
- Do not claim a command or test passed unless it was run successfully.

## 15. Definition of done

A change is complete when:

- It satisfies the approved scope and accepted ADRs.
- Domain terminology and ownership are correct.
- Database and application invariants agree.
- Authorization is enforced at the request and service boundaries.
- Material actions are audited with redaction.
- Concurrency, idempotency, and event delivery are handled where applicable.
- Relevant tests pass.
- Schema and behavior documentation are updated.
- Any migration and rollback considerations are documented.
- The handoff identifies remaining risks or unresolved proposed decisions.
