# POS operation envelope and Core facts

**Status:** Accepted (implements [ADR-020](../../../adr/ADR-020-pos-operation-envelope-and-core-facts.md))

**Authority:** Boundary between the canonical `CompletedPosOperation` envelope and normalized Core POS tables. Complements [completed-pos-operation-v1.md](completed-pos-operation-v1.md), [phase4-schema.md](phase4-schema.md), [receipt-identity.md](receipt-identity.md), and [pos-tax-contract.md](pos-tax-contract.md).

---

## 1. Three layers

```text
Canonical Completed POS Operation
        │
        ├── operation / provenance metadata
        │
        └── complete commercial payload
                    │
                    ▼
        Normalized Core POS facts
                    │
                    ├── pos_transactions
                    ├── pos_transaction_lines
                    ├── pos_line_tax_components
                    ├── pos_tenders
                    ├── inventory effects
                    └── reporting context
```

Transport/processing (HTTP, retries, sync batches, telemetry) is a **third** concern and is not part of the canonical commercial envelope.

---

## 2. Governing rules

> Any fact required to operate ShelfSense after completion must exist in normalized Core data. The canonical operation envelope also preserves the complete originating operation, but Core business workflows do not depend on querying JSON to understand a transaction.

> The envelope must be sufficient to materialize Core; Core must be sufficient to run the business without the envelope; neither is rewritten after acceptance.

| Need | Where |
|---|---|
| Receipt, return, reporting, inventory, tax, cash, lookup, audit/control | **Normalize** |
| “What did the origin assert?”, contract version, client/install, payload integrity | **Envelope / `pos_operations`** |
| Request IDs, IP, User-Agent, retry attempt, latency, sync batch | **Transport / logs** — not envelope, not commercial txn |

---

## 3. Dual authority

### Normalized Core

Authoritative for: what ShelfSense currently knows about this completed commercial transaction.

Used for receipts, returns, reporting, Inventory linkage, tax, cash reconciliation, transaction lookup.

### Canonical operation

Authoritative provenance for: what exact completed operation the originating Register (or Rails completion) asserted.

Used for synchronization, idempotency/integrity, reconciliation, contract debugging.

Avoid saying only “the envelope is authoritative” or only “the tables are authoritative.” They answer different questions. Neither is independently editable after acceptance.

---

## 4. Normalize commercial facts

Core must contain everything needed to use the transaction indefinitely without parsing the envelope.

```text
pos_transactions
pos_transaction_lines
pos_line_tax_components
pos_tenders
```

Later: approvals, return relationships, cash movements, etc.

Example: a return walks transaction → lines → historical tax components. It must **not** parse `pos_operations.envelope`.

### Transaction-level (illustrative)

```text
id, store_id, register_id, pos_session_id, reporting_period_id, cashier_user_id
receipt_sequence, store_number_snapshot, register_number_snapshot
occurred_at, business_date, status, currency_code
merchandise_subtotal_cents / subtotal_cents, tax_cents, total_cents
completed_at
```

Use `register_*` in schema and contracts (ADR-021 / ADR-011). Cashier UI may say Register / `Reg`.

### Lines (Phase 4)

Required commercial snapshots must be relationally usable. Phase 4 locks **required `merchandise_snapshot` jsonb** with fixed v1 keys (`sku`, `description`, `tax_class_code`) on the line, equivalent to first-class snapshot columns for those keys. Do not invent a second competing snapshot shape. Later phases may promote hot keys to columns if query patterns demand it; the envelope always carries the same completed merchandise facts.

Also: direction, quantity, prices, extended amounts, tax class id/code snapshot, line tax/total, position/`line_number`.

### Tax components and tenders

Always normalized per [pos-tax-contract.md](pos-tax-contract.md) and Phase 4 tender columns. Envelope carries the same completed results.

Phase 4 tenders may use `tender_type = cash` (string/enum) without a full tender-type catalog table.

---

## 5. `pos_operations` purpose

Durable completion provenance **and** ADR-009 idempotency — not a second transaction model.

```text
pos_operations
├── id / operation_id
├── operation_type
├── schema_version
├── source_id
├── idempotency_key
├── payload_hash
├── status                    # in_flight | completed | failed
├── lease_expires_at
├── pos_transaction_id
├── store_id
├── register_id
├── installation_id           # optional later technical id only; not business vocabulary
├── producer_client           # optional
├── producer_version          # optional
├── envelope                  # JSONB — full CompletedPosOperation (required when completed)
├── originated_at             # from commercial occurred_at / origin
├── received_at               # central receipt of operation (Core only)
├── posted_at                 # central materialization success (Core only)
├── lock_version
└── timestamps
```

Indexed columns answer: which operation created transaction X, which Register, which schema version, when Core received/posted — without searching JSON.

Some duplication with `pos_transactions` is intentional.

---

## 6. Envelope contents

The envelope is a **complete** immutable representation of what the origin says happened — not merely metadata.

Include:

- operation identity, type, schema version
- optional producer (`client`, `version`; optional later technical install id)
- origin context (store, register, session, operator, occurred_at, business_date)
- full commercial transaction: receipt components, currency, lines with snapshots and tax components, tenders, totals

Receipt numbers in the envelope use **string snapshots** consistent with display padding rules (e.g. `"003"`, `"02"`), not bare integers that drop leading zeros.

Exclude from the envelope:

- `received_at` / `posted_at` (central processing)
- retry attempt counts, HTTP/request IDs, IP, User-Agent, latency, sync batch numbers, tokens

Those must not affect payload hash. Hash identity must be identical for in-process Rails delivery and standalone sync of the same completed fact.

---

## 7. Time fields

| Field | Meaning | Where |
|---|---|---|
| `occurred_at` | When the origin completed the sale | Envelope + `pos_transactions` |
| `business_date` | Origin reporting date | Envelope + `pos_transactions` |
| `received_at` | When central Core received the operation | `pos_operations` only |
| `posted_at` | When central materialization committed | `pos_operations` only |

Reporting must not treat `received_at` as sale time.

---

## 8. Atomic posting

### Rails (Phase 4)

```text
BEGIN
  validate working transaction
  allocate receipt
  construct canonical CompletedPosOperation
  validate operation / payload hash
  write normalized completed facts
  write pos_operations (envelope + hash + idempotency completion)
  post inventory effects
COMMIT
```

Rails **constructs** the envelope inside completion; it does not require a pre-existing external Register submission.

### Future standalone

```text
Register local completion → canonical operation
        ↓
central ingest → validate
        ↓
BEGIN
  persist pos_operations
  materialize normalized Core
  post inventory/etc.
COMMIT
```

Accepted envelope and normalized facts must describe the same immutable transaction. Disagreement is an integrity defect.

---

## 9. Phase 4 split matrix

| Fact | Core normalized | Canonical envelope |
|---|:---:|:---:|
| Transaction UUID | ✓ | ✓ |
| Operation UUID | via relationship | ✓ |
| Schema version | `pos_operations` | ✓ |
| Store / Register / session / operator | ✓ | ✓ |
| `occurred_at` / `business_date` | ✓ | ✓ |
| Receipt sequence + number snapshots | ✓ | ✓ |
| Currency, lines, prices, tax class | ✓ | ✓ |
| Merchandise snapshots | ✓ | ✓ |
| Tax components | ✓ | ✓ |
| Tender facts / totals | ✓ | ✓ |
| Payload hash | `pos_operations` | calculated alongside |
| Client/build version | normally `pos_operations` | ✓ (optional producer) |
| Installation / producer technical ids | later / optional | ✓ optional |
| Central `received_at` / `posted_at` | `pos_operations` only | **No** |
| Retry / HTTP / transport | no commercial table | **No** |
| Terminal id | deferred (ADR-021) | deferred |

> The envelope describes the originating completed operation. It does not describe what happened to the operation after transmission.

---

## 10. Contract language

> A Completed POS Operation is the immutable canonical representation of a commercial transaction as established by the originating Register (or Rails completion path). It contains all commercial facts necessary for Core to validate and materialize the transaction, including origin context, permanent receipt identity, completed lines and economic snapshots, component tax results, tenders, and transaction totals.

> Core persists those commercial facts in normalized POS tables. Normalized tables are used for ordinary business behavior including receipt rendering, transaction lookup, returns, reporting, Inventory integration, and reconciliation. No required commercial behavior may depend on parsing the stored operation envelope.

> Core also preserves the accepted canonical operation and its payload hash on a durable `pos_operations` record with ADR-009 idempotency semantics. The operation record provides immutable origin and contract provenance and is distinct from generic request-idempotency infrastructure that may expire.

> Operation metadata may include schema version, operation identity, and optional producing client. Central processing facts such as receipt time, posting time, retry attempts, request IDs, and transport information are not part of the canonical originating operation and are recorded separately where required.

> The canonical operation and normalized completed facts must describe the same immutable transaction. They are created or accepted as part of one authoritative posting boundary and may not diverge.
