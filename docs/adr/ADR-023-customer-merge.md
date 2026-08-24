# ADR-023: Customer identity merge

- **Status:** Accepted
- **Date:** 2026-08-23
- **Accepted:** 2026-08-24

## Context

Phase 7 introduced a minimal `customers` table and quantity-one `customer_requests` linked by `customer_id`. Staff routinely create customers at the counter and in admin; duplicate accounts (same phone, same email, variant spellings of the same person or household) are expected.

[ADR-003](ADR-003-data-authority.md) places customer master data on the central server. [ADR-012](ADR-012-record-lifecycle.md) allows descriptive customer state to be edited with audit, but completed business facts are not rewritten. [ADR-014](ADR-014-conflict-resolution.md) rejects last-write-wins for business records and requires explicit correction policies per resource.

Phase 8 must let staff **prevent** accidental duplicate creation and **merge** duplicates without losing request history, while preserving durable identity for Phase 10 stored value and later buyback. A merged customer UUID may already appear in audit events, request numbers, and POS pickup context; silent deletion or opaque FK rewriting would break reconstructability.

Today only `customer_requests` references `customers` with `ON DELETE RESTRICT`. Future domains (stored-value accounts, buyback seller records) will add more customer-owned relationships. A generic “update every `customer_id` column” merge is unsafe for financial ledgers and must not become the default pattern.

Repeated merges must remain safe: after `A → B`, staff may later discover that `B` and `C` are the same person. Merging `B → C` must not leave a forbidden chain `A → B → C`.

## Decision

### 1. Canonical identity

- Each `customers` row keeps its UUIDv7 `id` for the life of the deployment ([ADR-002](ADR-002-identifiers.md)).
- **Canonical customer** is a row with `merged_into_customer_id IS NULL`. Application code exposes `Customer#canonical` that returns `self` when canonical, otherwise the referenced survivor.
- **Merge chains are forbidden.** After every successful merge, every alias points **directly** to a canonical survivor (at most one hop). `Customer#canonical` therefore never walks a chain in normal operation; a multi-hop walk is a data-integrity failure, not a supported resolution path.
- Reads that power operational workflows (new requests, duplicate suggestions, financial account creation) resolve aliases to the canonical customer or reject the alias explicitly.

### 2. Merge is a staff-initiated command, not automatic deduplication

- Duplicate detection on create/edit may **suggest** matches on normalized phone, normalized email, and weaker normalized name similarity.
- The system **must not** auto-merge customers.
- Staff choose among: use the existing customer, create anyway, or cancel. Merge is a separate authorized action (`customers.manage`), not an implicit side effect of save.

### 3. Tombstone source, do not delete

- Merge sets `merged_into_customer_id` on the **source** to the **survivor**'s `id`, sets `active: false` on the source, and leaves the source row in place.
- Physical deletion of customers with durable references is out of scope for ordinary workflows ([ADR-012](ADR-012-record-lifecycle.md)).
- Merged sources remain addressable for audit and historical display; UI and APIs must not treat them as targets for new operational work.

### 4. Flatten existing aliases during merge

When the source already has direct aliases, the merge transaction **repoints** every customer whose `merged_into_customer_id` equals the source to the new survivor **before** tombstoning the source. After commit, every merged customer points directly to a canonical survivor.

```text
Before: A → B
Merge:  B → C
After:  A → C
        B → C
```

This is preferred over prohibiting a customer with incoming aliases from becoming a merge source, which would eventually make legitimate cleanup impossible.

Audit records the count of aliases repointed and their IDs (or a separately stored bounded reference when the list is large).

### 5. Profile fields are not combined

- The selected **survivor’s profile remains authoritative** (display name, given/family name, phone, email, preferred contact method, notes, active flag).
- Merge does **not** automatically copy, concatenate, or reconcile profile fields from source onto survivor.
- The merge review screen shows field differences before confirmation.
- Staff may edit the survivor before or after merging.
- The source retains its former fields as alias/search evidence, subject to later privacy policy.
- Source notes do not silently become survivor notes.

### 6. Transactional merge command with explicit reassignment calls

- Customer merge is implemented as a single server command (e.g. `Customers::MergeCustomers`) in one database transaction with:
  - authorization check;
  - resolve both submitted IDs to customer rows before mutation;
  - validation (distinct source and survivor; source is not already merged; survivor is canonical and active; neither ID equals the other);
  - pessimistic locks on source, survivor, and direct aliases of the source, acquired in deterministic UUID order;
  - revalidate canonical/merged state after acquiring locks;
  - flatten aliases of the source onto the survivor;
  - **explicit domain-owned reassignment calls** (not reflective discovery);
  - tombstone update on the source;
  - append-only audit event in the same transaction ([ADR-008](ADR-008-audit-events.md)).
- Phase 8’s only reassignment call is `Customers::ReassignActiveRequests` (or equivalent). Each future phase that adds a `customer_id` consumer must document and test its merge behavior, then add an explicit call in the merge command.
- The inventory in [phase8-schema.md](../planning/phase8-customer-foundation/phase8-schema.md) lists consumers for review; it does **not** dynamically discover or execute reassignment.
- **No** reflective or schema-driven “update all foreign keys” mechanism and **no** callback/plugin registry.

### 7. Customer request reassignment policy

`customer_id` on a request records which customer owned the request when the relationship was operationally active. Merge reassigns **active** requests only; completed and cancelled requests retain their originally recorded UUID ([ADR-012](ADR-012-record-lifecycle.md)).

| Request status | Merge behavior |
|---|---|
| `pending_location` | Reassign to survivor |
| `special_order_pending` | Reassign to survivor |
| `ordered` | Reassign to survivor |
| `available` | Reassign to survivor |
| `completed` | Preserve original `customer_id`; resolve via `canonical` for display/grouping |
| `cancelled` | Preserve original `customer_id`; resolve via `canonical` for display/grouping |

Historical displays may show the originally recorded customer plus current canonical identity where useful. Reports may group by canonical identity while retaining the originally recorded UUID on completed/cancelled rows.

### 8. Alias search and visibility

- **Operational lookup** (admin index, request create, POS customer pick): may match former name, phone, or email stored on a merged alias, but **returns the canonical survivor** with a “Matched former customer record” (or equivalent) indication. Merged aliases are excluded as independent duplicate candidates and cannot be selected as operational targets.
- **Admin/audit view:** a source tombstone may be opened directly for history and audit.
- **Historical record:** may show the original identity reference plus current canonical identity where useful.

### 9. Confirmation and reversibility

- Merge requires a review screen showing source, survivor, contact/profile differences, active relationship counts, and proposed reassignment counts.
- Staff must explicitly confirm which record survives.
- A short human-readable **reason** is required.
- Between review and commit, revalidate that source and survivor still satisfy merge preconditions (stale-state rejection).
- Merge is an **irreversible lifecycle action** in the MVP. There is no ordinary “unmerge.” Correction of an erroneous merge requires an elevated, separately designed remediation workflow; staff must not clear `merged_into_customer_id` manually.
- Phase 10 may strengthen confirmation when balances are involved without changing this irreversibility policy.

### 10. Idempotency and concurrency

- Merge accepts a scoped idempotency key per [ADR-009](ADR-009-concurrency-and-idempotency.md). Replaying the same key with the same payload returns the stored outcome; payload mismatch (including reversed source/survivor or changed reason) is an error.
- Optimistic locking on editable survivor fields uses existing `lock_version`.
- Creating a new customer request (or any new customer-owned operational relationship) must lock or revalidate the customer **immediately before persistence** so a concurrent merge cannot leave a new request on a tombstone. Checking `active` earlier in the request is not sufficient.

### 11. Audit

- Record action `customers.merge` with: actor, store context when applicable, source and survivor IDs, human-readable reason, count (and IDs or bounded reference) of aliases repointed, counts of reassigned records per explicit reassignment call, correlation/idempotency reference, and application version.
- Do not place full row dumps, secrets, or payment credentials in audit metadata.

### 12. Lifecycle interaction

| State | `active` | `merged_into_customer_id` | New requests | Reactivation | Operational edit/select |
|---|---|---|---|---|---|
| Active | true | NULL | allowed | n/a | allowed |
| Inactive | false | NULL | blocked | allowed | limited (reactivate / history) |
| Merged (alias) | false | survivor UUID | blocked; resolve to survivor for reads | **not** allowed | not as operational target |

Inactive and merged are distinct: only inactive customers may be reactivated. Merged customers cannot be edited as operational customers or selected for new ownership.

### 13. Database invariants

The migration enforces what ordinary constraints can:

- Self-referential FK `merged_into_customer_id` → `customers.id` with `ON DELETE RESTRICT`
- Index on `merged_into_customer_id`
- Check: `merged_into_customer_id IS NULL OR active = false`
- Check: `merged_into_customer_id IS NULL OR merged_into_customer_id <> id`

“Target is canonical” and “no chains after flatten” remain **service invariants** with concurrency tests; they are not expressible as simple check constraints.

### 14. Financial and stored-value boundary

- Phase 8 merge **does not** move stored-value balances; no stored-value tables exist yet.
- When Phase 10 introduces customer-owned financial accounts, **balance consolidation or transfer on customer merge** is a separate financial-domain command or explicit reassignment call with explicit policy (survivor receives balance, zeroed source account, compensating ledger entries as required). It is not satisfied by rewriting `customer_id` on ledger rows alone ([ADR-013](ADR-013-append-only-facts.md), [ADR-014](ADR-014-conflict-resolution.md)).
- New financial relationships attach only to an **active, canonical** customer.
- Stored-value redemption remains online-authorized until a later bounded offline decision ([ADR-005](ADR-005-terminal-originated-operations.md)).

### 15. Duplicate prevention vs database uniqueness

- Normalized email and phone support lookup and duplicate **suggestions**; partial unique indexes on contact fields are deferred until operational merge practice is stable. Staff judgment plus merge remains the primary deduplication path for shared household contacts.

## Consequences

- Phase 8 must ship merge tests for:
  - happy path;
  - cycle rejection and self-merge rejection;
  - source with existing aliases flattened onto the new survivor;
  - active vs completed/cancelled request reassignment policy;
  - concurrent request creation versus merge;
  - concurrent merges sharing a source or survivor;
  - search by former alias phone/email returns the canonical survivor once;
  - source and survivor field differences are not silently combined;
  - merge review becomes stale before confirmation;
  - merged customer cannot be reactivated, edited as an operational customer, or selected for new ownership;
  - idempotent retry; repeated key with reversed source/survivor or changed reason is a payload mismatch;
  - audit creation with reassignment and alias-repoint counts.
- Admin and request UIs must surface canonical customers in operational search and block creating requests against merged aliases.
- Each new `customer_id` foreign key requires an explicit merge/reassignment decision and an explicit call in `Customers::MergeCustomers`; the inventory in [phase8-schema.md](../planning/phase8-customer-foundation/phase8-schema.md) is the living checklist until a glossary or data dictionary absorbs it.
- Reports and exports that group by customer should prefer canonical identity or document that historical completed/cancelled rows may cite tombstone UUIDs.
- Phase 10 must supersede or extend the financial subsection of this ADR if balance transfer policy differs from the default described here.

## Related documentation

- [Phase 8 plan](../planning/phase8-customer-foundation/phase8-plan.md) — slices 8.3–8.4
- [Phase 8 schema](../planning/phase8-customer-foundation/phase8-schema.md)
- [Phase 8 stored-value boundary](../planning/phase8-customer-foundation/phase8-stored-value-boundary.md)
- [Phase 7 spec §7.4](../planning/phase7-orders-and-receiving/phase7-spec.md) — minimal customer record and duplicate-warning intent
