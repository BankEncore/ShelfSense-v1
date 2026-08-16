# ADR-020: Canonical POS operation envelope and normalized Core facts

- **Status:** Accepted
- **Date:** 2026-08-16
- **Related:** [ADR-003](ADR-003-data-authority.md), [ADR-005](ADR-005-terminal-originated-operations.md), [ADR-009](ADR-009-concurrency-and-idempotency.md), [ADR-013](ADR-013-append-only-facts.md), [Operation and Core facts contract](../planning/phase4-6-point-of-sale/phase4-point-of-sale/operation-and-core-facts.md)

## Context

A completed POS sale must be usable indefinitely for receipts, returns, tax reporting, inventory linkage, cash reconciliation, and lookup. It must also preserve exactly what the originating Register (or Rails completion path) asserted, including contract version and payload integrity, especially once a standalone Register synchronizes after the fact.

Treating only normalized tables as “the truth” loses portable originating provenance. Treating only a JSON envelope as operational storage forces business workflows to parse documents. Neither alone is adequate.

## Decision

1. **Three layers**
   - Canonical `CompletedPosOperation` envelope — complete immutable commercial payload plus operation/provenance metadata as asserted at origin.
   - Normalized Core POS tables — transactions, lines, tax components, tenders, and downstream effects (inventory, reporting context).
   - Transport/processing records — logs, sync attempts, retries, HTTP metadata; not part of the commercial envelope.

2. **Dual authority by question**
   - Normalized Core is authoritative for: what ShelfSense knows about the completed commercial transaction for ordinary business behavior.
   - The accepted canonical operation is authoritative provenance for: what exact completed operation the origin asserted (sync, idempotency/integrity, reconciliation, contract debugging).
   - Neither is independently editable after acceptance.

3. **Governing rule**
   - Any fact required to operate after completion (receipt, return, reporting, inventory, tax, cash, lookup, control) must exist in normalized Core. No required commercial behavior may depend on parsing the stored envelope.
   - The envelope must still contain the complete commercial payload so Core can validate and materialize without reconstructing from current prices, taxes, or merchandise.
   - **The envelope must be sufficient to materialize Core; Core must be sufficient to run the business without the envelope; neither is rewritten after acceptance.**

4. **Durable `pos_operations`** stores the accepted envelope, schema version, payload hash, ADR-009 idempotency fields (key, status, lease), origin indexes, and central processing times (`received_at`, `posted_at`). It is not a second transaction model and is distinct from generic request-only idempotency cleanup tables.

5. **Transport metadata** (request IDs, IP, User-Agent, retry attempt counts, sync batch numbers, tokens, latency) must not enter the canonical commercial envelope or affect payload hash. The same completed operation must hash identically whether delivered in-process or via sync.

6. **Atomicity:** envelope acceptance and normalized materialization occur in one authoritative posting boundary. Divergence is an integrity defect.

7. **Rails vs standalone:** Rails constructs the envelope inside the same PostgreSQL completion transaction that writes Core. A future Register completes locally (builds the envelope), then central validates and materializes. Same envelope contract either way.

## Consequences

- Commercial facts are deliberately duplicated: relational for use, envelope for provenance.
- `occurred_at` and `business_date` live on the commercial transaction and in the envelope; central `received_at` / `posted_at` live only on `pos_operations`.
- Phase 4 must persist a full envelope, not an optional reconstructable stub.
- Detail and Phase 4 column guidance live in the [operation and Core facts contract](../planning/phase4-6-point-of-sale/phase4-point-of-sale/operation-and-core-facts.md).
