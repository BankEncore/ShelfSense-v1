# ADR-020: Canonical POS operation envelope and normalized Core facts

- **Status:** Accepted
- **Date:** 2026-08-16
- **Amended:** 2026-08-16 (command vs envelope hashes; Terminal wording; v1 standalone scope)
- **Related:** [ADR-003](ADR-003-data-authority.md), [ADR-004](ADR-004-reference-data-replication.md), [ADR-005](ADR-005-terminal-originated-operations.md), [ADR-009](ADR-009-concurrency-and-idempotency.md), [ADR-013](ADR-013-append-only-facts.md), [ADR-021](ADR-021-register-and-terminal-identity.md), [Operation and Core facts contract](../planning/phase4-6-point-of-sale/phase4-point-of-sale/operation-and-core-facts.md)

## Context

A completed POS sale must be usable indefinitely for receipts, returns, tax reporting, inventory linkage, cash reconciliation, and lookup. It must also preserve exactly what the originating completion path asserted, including contract version and payload integrity, especially once a standalone Terminal synchronizes after the fact.

Treating only normalized tables as “the truth” loses portable originating provenance. Treating only a JSON envelope as operational storage forces business workflows to parse documents. Neither alone is adequate.

A single hash cannot both (a) identify a pre-completion `CompleteTransactionCommand` for ADR-009 retry and (b) fingerprint the post-receipt `CompletedPosOperation`.

## Decision

1. **Three layers**
   - Canonical `CompletedPosOperation` envelope — complete immutable commercial payload plus operation/provenance metadata as asserted at origin.
   - Normalized Core POS tables — transactions, lines, tax components, tenders, and downstream effects (inventory, reporting context).
   - Transport/processing records — logs, sync attempts, retries, HTTP metadata; not part of the commercial envelope.

2. **Dual authority by question**
   - Normalized Core is authoritative for: what ShelfSense knows about the completed commercial transaction for ordinary business behavior.
   - The accepted canonical operation is authoritative provenance for: what exact completed operation the origin asserted (sync, integrity, reconciliation, contract debugging).
   - Neither is independently editable after acceptance.

3. **Governing rule**
   - Any fact required to operate after completion (receipt, return, reporting, inventory, tax, cash, lookup, control) must exist in normalized Core. No required commercial behavior may depend on parsing the stored envelope.
   - The envelope must still contain the complete commercial payload so Core can validate and materialize without reconstructing from current prices, taxes, or merchandise.
   - **The envelope must be sufficient to materialize Core; Core must be sufficient to run the business without the envelope; neither is rewritten after acceptance.**

4. **Durable `pos_operations` combines POS completion-command idempotency with permanent completed-operation provenance, but those concerns use distinct hashes.**

   Before completion, the operation records the ADR-009 command identity and execution state:

   ```text
   command_type
   source_id
   idempotency_key
   command_payload_hash
   status
   lease_expires_at
   ```

   `command_payload_hash` fingerprints the canonical `CompleteTransactionCommand` material used for retry comparison. It does **not** contain server-assigned completion facts such as receipt sequence or final completion timestamps.

   When completion succeeds, the same durable operation additionally records:

   ```text
   fact_type
   schema_version
   envelope
   envelope_hash
   transaction/origin indexes
   received_at
   posted_at
   ```

   `envelope_hash` fingerprints the canonical immutable `CompletedPosOperation`. It is distinct from `command_payload_hash`.

   Initial types:

   ```text
   command_type = "pos.complete_transaction"
   fact_type    = "pos.transaction_completed"
   ```

   Reusing an idempotency key with a different `command_payload_hash` is an ADR-009 integrity error. An accepted completed operation whose stored envelope does not match `envelope_hash` is a provenance/integrity defect.

   `pos_operations` is not a second transaction model and is distinct from generic request-only idempotency cleanup tables that may expire.

5. **Transport metadata** (request IDs, IP, User-Agent, retry attempt counts, sync batch numbers, tokens, latency) must not enter the canonical commercial envelope or affect `envelope_hash`. The same completed commercial fact must hash identically whether delivered in-process or via sync.

6. **Atomicity:** envelope acceptance and normalized materialization occur in one authoritative posting boundary. Divergence is an integrity defect. Successful completion also records required audit and a slim POS domain outbox event in that same transaction.

7. **Rails vs standalone:** Rails constructs the envelope inside the PostgreSQL completion transaction that writes Core. A future standalone **Terminal operating a Register** completes locally and constructs a compatible canonical operation, then central Core validates and materializes it. `register_id` remains the commercial origin; future `terminal_id` is technical provenance.

## Consequences

- Commercial facts are deliberately duplicated: relational for use, envelope for provenance.
- `occurred_at` and `business_date` live on the commercial transaction and in the envelope; central `received_at` / `posted_at` live only on `pos_operations`.
- Phase 4 must persist a full envelope when completed, not an optional reconstructable stub.
- `CompletedPosOperation v1` establishes the initial commercial semantics but is **not** asserted to contain all provenance required for standalone operation. Before standalone completion authority is enabled, a later compatible contract version must add the Terminal and reference-configuration provenance required by ADR-004, ADR-005, and ADR-021.
- Detail and Phase 4 column guidance live in the [operation and Core facts contract](../planning/phase4-6-point-of-sale/phase4-point-of-sale/operation-and-core-facts.md).
