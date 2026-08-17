# POS operation envelope and Core facts

**Status:** Accepted (implements [ADR-020](../../../adr/ADR-020-pos-operation-envelope-and-core-facts.md))

**Authority:** Boundary between the canonical `CompletedPosOperation` envelope and normalized Core POS tables; command vs envelope hash semantics. Complements [completed-pos-operation-v1.md](completed-pos-operation-v1.md), [phase4-schema.md](phase4-schema.md), [receipt-identity.md](receipt-identity.md), and [pos-tax-contract.md](pos-tax-contract.md).

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
| “What did the origin assert?”, contract version, command/envelope integrity | **Envelope / `pos_operations`** |
| Request IDs, IP, User-Agent, retry attempt, latency, sync batch | **Transport / logs** — not envelope, not commercial txn |

---

## 3. Dual authority

### Normalized Core

Authoritative for: what ShelfSense currently knows about this completed commercial transaction.

Used for receipts, returns, reporting, Inventory linkage, tax, cash reconciliation, transaction lookup.

### Canonical operation

Authoritative provenance for: what exact completed operation the origin asserted (Rails completion path or, later, a Terminal operating a Register).

Used for synchronization, integrity, reconciliation, contract debugging.

Neither is independently editable after acceptance.

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

Required commercial snapshots must be relationally usable. Phase 4 locks **required `merchandise_snapshot` jsonb** with fixed v1 keys (`sku`, `description`, `tax_class_code`) on the line. Normalized Core also stores `tax_class_code_snapshot` (and `tax_class_id`). Envelope field may remain `tax_class_code` because the envelope itself is a completed snapshot.

Also: direction, integer quantity, prices, extended amounts, line tax/total, `line_number`.

### Tax components and tenders

Always normalized per [pos-tax-contract.md](pos-tax-contract.md) and Phase 4 tender columns. Envelope carries the same completed results.

Phase 4 tenders may use `tender_type = cash` (string/enum) without a full tender-type catalog table.

---

## 5. `pos_operations` purpose

Durable completion-command ADR-009 state **and** permanent completed-operation provenance — not a second transaction model.

```text
pos_operations
├── id / operation_id
├── command_type                 # pos.complete_transaction
├── fact_type                    # null until completed; then pos.transaction_completed
├── schema_version               # null until completed envelope exists
│
├── source_id                    # UUID
├── idempotency_key              # UUID
├── command_payload_hash
├── status                       # in_flight | completed | failed
├── lease_expires_at
│
├── pos_transaction_id
├── store_id
├── register_id
│
├── envelope                     # full CompletedPosOperation; completed only
├── envelope_hash                # completed only
│
├── producer_client              # optional
├── producer_version             # optional
│
├── originated_at
├── received_at
├── posted_at
│
├── lock_version
└── timestamps
```

Do **not** store Phase 4 `installation_id`. Future technical provenance uses `terminal_id` when Terminals exist (ADR-021).

> `command_payload_hash` and `envelope_hash` are intentionally different. The first binds a retry to the request that asked ShelfSense to complete the transaction. The second fingerprints the completed fact after receipt allocation and commercial freeze.

Uniqueness: `UNIQUE(source_id, command_type, idempotency_key)`.

### Status rules

| Status | Rules |
|---|---|
| `in_flight` | `lease_expires_at` required; envelope / `fact_type` / `envelope_hash` absent |
| `failed` | completed envelope absent |
| `completed` | `fact_type`, `schema_version`, `pos_transaction_id`, `envelope`, `envelope_hash`, `posted_at` required |

Indexed columns answer: which operation created transaction X, which Register, which schema version, when Core received/posted — without searching JSON.

---

## 6. Envelope contents

The envelope is a **complete** immutable representation of what the origin says happened — not merely metadata.

Include:

- `operation_id`, `fact_type` (`pos.transaction_completed`), `schema_version`
- optional producer (`client`, `version`)
- origin context (store, register, session, operator, occurred_at, business_date)
- full commercial transaction: receipt components, currency, lines with snapshots and tax components, tenders, totals

Receipt numbers use **string snapshots** (e.g. `"003"`, `"02"`).

Exclude:

- `received_at` / `posted_at`
- retry / HTTP / transport metadata

Those must not affect `envelope_hash`.

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
CompleteTransactionCommand
        ↓
begin/reclaim pos_operation
using command_payload_hash
        ↓
BEGIN
  authorize actor and validate Store/Register/Session/period context
  lock working transaction
  validate expected working-transaction lock_version
  validate settlement
  allocate Register receipt sequence (row lock on registers)
  freeze occurred_at / business_date
  freeze commercial facts
  build CompletedPosOperation
      fact_type = pos.transaction_completed
  canonicalize envelope
  compute envelope_hash
  write normalized Core POS facts
  write completed pos_operation envelope/hash
  post paired Inventory physical + valuation effects
  record required audit
  record pos.transaction_completed outbox message
  mark operation completed
COMMIT
```

On failure:

```text
business transaction rolls back
→ no receipt effect
→ no Inventory effect
→ no POS outbox fact
→ operation may transition to failed under ADR-009 retry semantics
```

Rails **constructs** the envelope inside completion.

### Future standalone

```text
Terminal local completion on behalf of a Register
→ canonical CompletedPosOperation (compatible contract)
        ↓
central ingest → validate
        ↓
BEGIN
  persist/complete pos_operations
  materialize normalized Core
  post Inventory / audit / outbox
COMMIT
```

`CompletedPosOperation v1` is the commercial base. Before standalone completion authority, a later compatible version must add Terminal and reference-configuration provenance (ADR-004/005/021).

Accepted envelope and normalized facts must describe the same immutable transaction. Disagreement is an integrity defect.

---

## 9. Phase 4 split matrix

| Fact | Core normalized | Canonical envelope |
|---|:---:|:---:|
| Transaction UUID | ✓ | ✓ |
| Operation UUID | via relationship | ✓ |
| `command_type` / command hash | `pos_operations` | **No** (pre-completion) |
| `fact_type` / schema version | `pos_operations` | ✓ |
| Store / Register / session / operator | ✓ | ✓ |
| `occurred_at` / `business_date` | ✓ | ✓ |
| Receipt sequence + number snapshots | ✓ | ✓ |
| Currency, lines, prices, tax class | ✓ | ✓ |
| Merchandise snapshots | ✓ | ✓ |
| Tax components | ✓ | ✓ |
| Tender facts / totals | ✓ | ✓ |
| `envelope_hash` | `pos_operations` | calculated alongside |
| Client/build version | normally `pos_operations` | ✓ optional producer |
| Central `received_at` / `posted_at` | `pos_operations` only | **No** |
| Retry / HTTP / transport | no | **No** |
| Terminal id | deferred (ADR-021) | deferred (later contract version) |

> The envelope describes the originating completed operation. It does not describe what happened to the operation after transmission.

---

## 10. Contract language

> A Completed POS Operation is the immutable canonical representation of a commercial transaction as established at completion. It contains all commercial facts necessary for Core to validate and materialize the transaction, including origin context, permanent receipt identity, completed lines and economic snapshots, component tax results, tenders, and transaction totals.

> Core persists those commercial facts in normalized POS tables. Normalized tables are used for ordinary business behavior. No required commercial behavior may depend on parsing the stored operation envelope.

> Durable `pos_operations` owns ADR-009 completion-command state (`command_payload_hash`) and permanent completed-operation provenance (`envelope` + `envelope_hash`). Those hashes are not interchangeable.

> Central processing facts (`received_at`, `posted_at`) and transport metadata are not part of the canonical originating operation.

> The canonical operation and normalized completed facts must describe the same immutable transaction. They are created or accepted as part of one authoritative posting boundary and may not diverge.
