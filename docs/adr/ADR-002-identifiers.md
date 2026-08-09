# ADR-002: Use UUIDv7 Primary Keys

* **Status:** Accepted
* **Amended:** 2026-08-09
* **Decision scope:** Central Rails application, offline POS nodes, synchronization, and domain data
* **Supersedes:** Any earlier assumption that identifiers must be generated exclusively by PostgreSQL

## Context

ShelfSense consists of a central Rails application backed by PostgreSQL and may include offline-capable POS applications using a different local database.

Records can originate in either environment:

* The central Rails application may create administrative, merchandise, purchasing, customer, and other centrally managed records.
* An offline POS node may create transactions, line items, tenders, cash movements, reservations, and synchronization events without access to PostgreSQL.
* POS-created records must retain stable identifiers when later synchronized with the central database.
* Synchronization retries must be idempotent and must not require the central application to replace locally assigned identifiers.

Sequential integer identifiers would require centralized allocation or later identifier remapping. Random UUIDv4 identifiers avoid coordination but provide poorer index locality than time-ordered UUIDs.

UUIDv7 provides globally assignable, time-ordered identifiers suitable for independently operating nodes.

## Decision

ShelfSense will use RFC 9562-compatible UUIDv7 values as primary keys for domain records.

The system that first creates a record is responsible for assigning its permanent identifier:

| Record origin                                     | Identifier generator                                            |
| ------------------------------------------------- | --------------------------------------------------------------- |
| Central Rails application                         | PostgreSQL UUIDv7 default or another approved central generator |
| Offline POS application                           | POS application UUIDv7 generator                                |
| Imported record with an established ShelfSense ID | Preserve the supplied UUIDv7                                    |
| Synchronization retry                             | Reuse the originally assigned UUID                              |

A record’s identifier must not be replaced when it is synchronized, imported, or replicated.

PostgreSQL columns will use the native `uuid` type. Foreign keys referencing domain records must also use `uuid`.

POS databases will use a native UUID type when reliably supported. Otherwise, UUIDs may be stored as canonical lowercase text or an exact 16-byte binary representation. The chosen representation must round-trip without altering the 128-bit value.

## Central generation

Centrally created records should normally omit the `id` during insertion and allow the configured PostgreSQL default to generate it:

```sql
id uuid PRIMARY KEY DEFAULT uuidv7()
```

An explicitly supplied identifier must be preserved:

```sql
INSERT INTO pos_transactions (id, ...)
VALUES ('019...', ...);
```

A database default runs only when no value is supplied. It must not overwrite POS-generated identifiers.

### PostgreSQL version requirement

ShelfSense currently targets PostgreSQL 17, which does not provide PostgreSQL 18’s native `uuidv7()` function.

Before the first UUID migration is committed, the project must choose and test one of these implementation profiles:

1. Upgrade to PostgreSQL 18 and use its native `uuidv7()` function.
2. Remain on PostgreSQL 17 and install a reviewed UUIDv7 extension or project-defined database function.
3. Generate UUIDv7 values in Rails until native database support is adopted.

The selected mechanism must produce RFC 9562-compatible UUIDv7 values and must be available in development, test, CI, and production.

Changing the generator implementation later does not change this ADR, provided the generated identifiers remain compatible and existing IDs are preserved.

## Offline POS generation

Each POS application must generate UUIDv7 identifiers locally for records created while online or offline.

The POS must:

* Assign the ID when the record is first created.
* Persist the assigned ID locally.
* Reuse it for every synchronization attempt.
* Assign permanent IDs to child records as well as aggregate roots.
* Use the same ID in local relationships and synchronization payloads.
* Never regenerate an ID merely because a synchronization attempt failed.
* Generate standards-compatible UUIDv7 values using a maintained implementation appropriate to the POS language and runtime.

The POS does not depend on PostgreSQL for identifier creation.

## Identifier semantics

A UUIDv7 is an identifier, not an authoritative business timestamp.

ShelfSense must not derive any of the following solely from the UUID:

* Business-day assignment
* Transaction completion time
* Accounting period
* Event ordering
* Conflict resolution
* Sync precedence
* Audit time
* Receipt sequence
* Legal or operational timestamps

These concepts require explicit fields such as:

```text
created_at
updated_at
occurred_at
opened_at
completed_at
business_day_id
recorded_at
synced_at
```

UUIDv7’s embedded timestamp improves approximate ordering and database index locality, but POS clocks may be incorrect or may move backward.

## Collision and conflict handling

A primary-key collision is expected to be extraordinarily unlikely, but it must not be handled by silently assigning a new identifier.

When synchronization receives an existing UUID:

* If the existing record represents the same creation and the payload is compatible, treat the request as an idempotent retry.
* If the UUID identifies a materially different record, report a synchronization integrity conflict.
* Do not replace either identifier automatically.
* Preserve enough diagnostic information to identify the originating node and synchronization attempt.

Idempotency may require additional operation or synchronization keys; the UUID alone does not necessarily prove that two payloads are semantically identical.

## Scope

UUIDv7 applies to:

* Domain entity primary keys
* Join and assignment records with independent identities
* Audit events
* POS transactions and their child records
* Synchronization records
* Records that may be created by more than one node

Framework-owned or purely internal tables may use their framework defaults when they never cross a domain or synchronization boundary. Examples may include Rails schema metadata and certain job-runner internals.

Any exception for a ShelfSense domain table must be documented.

## Rails migration convention

UUID-backed domain tables must declare their primary and foreign-key types explicitly:

```ruby
create_table :stores, id: :uuid, default: -> { "uuidv7()" } do |t|
  # ...
  t.timestamps
end

create_table :workstations, id: :uuid, default: -> { "uuidv7()" } do |t|
  t.references :store, null: false, type: :uuid, foreign_key: true
  # ...
end
```

The literal default shown above is illustrative until the PostgreSQL 17/18 implementation profile is selected.

The project should provide a shared migration convention or helper so individual migrations do not choose their own generator.

## Validation and testing

The implementation must test that:

* Centrally inserted records receive UUIDv7 IDs.
* Rails preserves an explicitly supplied valid UUIDv7.
* POS-generated UUIDv7 values can be inserted into PostgreSQL.
* Parent and child records retain their relationships after synchronization.
* Retrying the same synchronization does not create duplicate records.
* Generated values contain the RFC-compatible UUID version and variant bits.
* UUID values round-trip through the POS database and sync serialization unchanged.
* Missing generator support causes setup or CI to fail clearly.

## Consequences

### Benefits

* Records can be created offline without centralized ID allocation.
* Synchronization does not require temporary-to-permanent ID remapping.
* Retries can preserve stable record identity.
* UUIDv7 generally provides better index locality than UUIDv4.
* The central application and POS can use different storage engines and generator libraries.

### Costs and risks

* Every environment must have a compatible generator.
* Incorrect POS clocks can affect approximate UUID ordering.
* UUIDs are larger than bigint primary keys and indexes.
* PostgreSQL 17 requires an additional UUIDv7 implementation decision.
* Multiple implementations require conformance and round-trip testing.
* UUID ordering cannot replace explicit business timestamps or synchronization metadata.

## Implementation follow-up

Before Phase 1 migrations land:

1. Select the PostgreSQL 17 implementation or upgrade the project to PostgreSQL 18.
2. Configure Rails migrations to use that generator consistently.
3. Add generator conformance tests.
4. Document the future POS requirement without selecting its programming-language library prematurely.

---

My preference for ShelfSense would be:

* Keep the durable ADR neutral about whether PostgreSQL 17 uses an extension or Rails generation.
* Add a short implementation decision immediately before Slice 1.
* If remaining on PostgreSQL 17, seriously consider application-generated UUIDv7 in Rails as the initial implementation. It avoids introducing a database extension solely for ID generation and gives Rails objects permanent IDs before insertion.
* Revisit native database generation when moving to PostgreSQL 18.

That would slightly revise our earlier recommendation: creator-assigned UUIDv7 is the architectural rule; database-generated versus application-generated is an implementation profile. The offline POS always generates its own IDs.
