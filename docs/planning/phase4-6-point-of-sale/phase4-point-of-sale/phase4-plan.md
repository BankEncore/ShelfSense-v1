# Phase 4 — POS Transaction and Posting Foundation

**Status:** Planning — **implementation-ready** once the `workstations` → `registers` rename slice completes and CompletedPosOperation v1 golden fixtures are reviewed

**Authority**

| Document | Role |
|---|---|
| [CompletedPosOperation v1](completed-pos-operation-v1.md) | Canonical completed-operation contract, command/completion boundary, fixtures |
| [POS tax contract](pos-tax-contract.md) | Store Tax / rules / calculator; completed tax facts ([ADR-019](../../../adr/ADR-019-pos-sales-tax-model.md)) |
| [Receipt identity](receipt-identity.md) | Transaction reference and receipt display forms ([ADR-006](../../../adr/ADR-006-receipt-numbering.md)) |
| [Register identity](register-identity.md) | Register vs Terminal; pre-Phase-4 rename ([ADR-021](../../../adr/ADR-021-register-and-terminal-identity.md)) |
| [Operation and Core facts](operation-and-core-facts.md) | Envelope vs normalized Core; two-hash durability ([ADR-020](../../../adr/ADR-020-pos-operation-envelope-and-core-facts.md)) |
| [Phase 4 schema](phase4-schema.md) | Tables, columns, constraints for Phase 4 migrations |
| [Phases 4–6 implementation plan](../spec.md) | Broader Phase 4–6 sequencing; Phase 5–6 detail |
| Accepted ADRs | Cross-cutting policy (`AGENTS.md`, ADR-006, ADR-007, ADR-009, ADR-011, ADR-019, ADR-020, ADR-021, inventory posting contract) |

Where this plan and `../spec.md` §4 disagree on completion semantics, tax representation, session columns, or operation identity, **prefer this document and its companions**. Update `../spec.md` when convenient so the multi-phase plan stays aligned.

**Prerequisite / readiness gate:** Complete the `workstations` → `registers` rename slice ([register-identity.md](register-identity.md) §5 / ADR-021) and review v1 golden fixtures before POS period/session/transaction migrations. Semantic and schema locks in this packet are otherwise closed.

Phase 4 proves that ShelfSense can construct, validate, complete, and authoritatively post one deterministic Cash sale without UI-specific or Rails-specific hidden state. It is an architectural and domain foundation, **not** a complete operational register.

---

## 1. Objective

Deliver a headless Rails vertical slice that:

1. Opens a minimal reporting period and cashier session context.
2. Builds a mutable working Cash sale for Standard quantity-tracked merchandise.
3. Prices and taxes deterministically.
4. Completes through an authoritative PostgreSQL transaction that allocates receipt identity and posts Inventory.
5. Produces a versioned **`CompletedPosOperation` v1** that always includes permanent receipt identity.
6. Retries the same completion without duplicating business effects.

Rails is the first POS client. A future standalone **Terminal operating a Register** must be able to produce a compatible canonical completed fact; only the location of the completion boundary differs. `CompletedPosOperation v1` is the commercial base; Terminal/config provenance arrives in a later compatible version before standalone completion authority.

---

## 2. Locked decisions

| Topic | Decision |
|---|---|
| Client | Rails-native POS only; standalone/offline Terminal deferred (ADR-021) |
| Transaction model | One `pos_transactions` row transitions working → completed (or cancelled); no separate sale/refund/exchange tables |
| Line directions (Phase 4) | Sale lines only; return lines deferred to Phase 6, but **sign convention is locked now** |
| Monetary signs | Store positive magnitudes; `direction` supplies economic sign (lines and tenders) |
| Completion vs operation | `CompleteTransactionCommand` is the pre-completion Rails command; `CompletedPosOperation` is built **inside** authoritative completion and always includes receipt identity |
| Receipt | Allocated at completion; scoped to store + Register; human reference `S{store_number}-R{register_number}-T{receipt_sequence}` per [receipt-identity.md](receipt-identity.md) / ADR-006; print layout deferred to Phase 5 |
| Register identity | Logical checkout is **Register** (ADR-021); no Terminal table in Phases 4–6; rename `workstations` → `registers` before POS FKs |
| Tax model | [ADR-019](../../../adr/ADR-019-pos-sales-tax-model.md) / [pos-tax-contract.md](pos-tax-contract.md): Tax Class → Store Tax Rule → Store Tax; Store Tax is the POS component |
| Tax rate storage | `rate_percent` as `numeric(6,3)`; contract strings like `"1.250"`; not basis points |
| Tax applicability | Rule `applies` is `true` / `false` / `NULL` (unresolved); no treatment enum; auto-create rule rows |
| Tax class | Consumes merchandise-domain Tax Classes; line stores `tax_class_id` + code snapshot; no Phase 4 override; no synthetic `nontaxable` result class |
| Completed tax facts | Snapshot **every active** Store Tax determination per line (`applies` true or false); not only applicable taxes |
| Merchandise snapshot | Required JSON at completion (sku, description, tax_class_code minimum) |
| Inventory | Post only through `Inventory::PostSale` (or equivalent); paired physical + valuation; `reject_below_zero`; no direct balance mutation; no `reserved` effect from open/working transactions |
| Unit tracking | No `inventory_unit_id` in Phase 4; individually tracked merchandise rejected |
| Session shape | Minimal open/close timestamps and FKs; **no** float / closing count / expected cash / variance columns until Phase 5 |
| Operation durability | Durable `pos_operations` with **distinct** `command_payload_hash` and `envelope_hash`; full envelope when completed; ADR-009 on command identity; see [operation-and-core-facts.md](operation-and-core-facts.md) / ADR-020 |
| Identity separation | `operation_id` ≠ `transaction_id`; never use `transaction_id` as the completion idempotency key |
| Pricing source | Resolve from `product_variants.regular_price_cents`; reject `open_price` and missing regular price (never zero-default) |
| Authorization | Permission `pos.transact` (Store-scoped); enforce Store/Register/Session/period/transaction consistency |
| Outbox | Slim `pos.transaction_completed` recorded in the same completion transaction; no duplicate on replay |
| Inventory causal `source_type` | Stay consistent with Phase 3 Rails class-name convention (`PosTransactionLine`) unless a later ADR changes inventory source kinds globally |
| Money / IDs / time | Integer cents; UUIDv7; `occurred_at` (UTC) + explicit `business_date`; store IANA timezone retained on store |
| Vocabulary | Use `register` / `terminal` per ADR-021 and ADR-011; do not use `workstation` in new POS work |

---

## 3. Scope

### 3.1 Included

- Minimal `pos_reporting_periods` and `pos_sessions` (no Cash accountability columns)
- Working and completed `pos_transactions`, lines, line tax components, Cash tenders
- Durable `pos_operations` (completion provenance + idempotency)
- Register-scoped receipt sequence allocation at completion
- Merchandise resolution for Standard quantity-tracked sellable variants
- Pricing from `product_variants.regular_price_cents` → selling unit price → extended amount (no overrides/discounts; reject `open_price`)
- Ordinary tax calculation per [pos-tax-contract.md](pos-tax-contract.md) (Store Taxes, nullable rules, full determination snapshots)
- Cash settlement (presented / applied / change) for a single payment tender
- `Pos::CompleteTransaction` authoritative completion path (see §5)
- Inventory posting for each completed sale line through `Inventory::PostSale` (paired physical + valuation)
- Slim `pos.transaction_completed` outbox in the same completion transaction
- Authorization via `pos.transact` plus context integrity checks
- Minimum audit for complete / reject / cancel
- Headless acceptance and failure/idempotency tests

### 3.2 Explicitly out of Phase 4

- Keyboard/scanner Register UI, receipt printing, Session close Cash count, Z reports (Phase 5)
- Opening float / closing expected / variance columns on sessions (Phase 5)
- Returns, mixed-direction transactions, discounts, approvals, suspend/recall, post-void (Phase 6)
- Individually tracked and non-inventory merchandise; open-ring (Phase 6)
- Card / Stored Value / multi-tender beyond single Cash payment
- Offline Terminal credentials/replication, enrollment, standalone Terminal runtime (Terminal required later before offline completion — ADR-021)
- Customer display, customer reservation pickup
- Inventory `reserved` from open or suspended transactions
- Tax Class override, purchaser exemption, tax profiles domain, effective-dated Store Tax versions, cashier rate edits

---

## 4. Governing completion model

### 4.1 Rails (Phase 4)

```text
Cashier / headless client
        ↓
Working POS transaction (mutable)
        ↓
CompleteTransactionCommand
        ↓
BEGIN authoritative completion (PostgreSQL)
   ├── authorize actor (`pos.transact`) and validate Store/Register/Session/period context
   ├── begin/reclaim pos_operation on command_payload_hash
   ├── lock working transaction; validate expected lock_version
   ├── validate settlement
   ├── allocate Register receipt sequence (row lock on registers)
   ├── freeze occurred_at / business_date
   ├── freeze commercial facts
   ├── construct canonical CompletedPosOperation v1
   │         fact_type = pos.transaction_completed
   │         (includes receipt.sequence, number snapshots, optional reference)
   ├── persist normalized Core POS facts
   ├── persist completed pos_operations (envelope + envelope_hash)
   ├── post paired Inventory physical + valuation effects (Inventory::PostSale)
   ├── record required audit
   └── record pos.transaction_completed outbox message
        ↓
COMMIT
```

**Invariant:** `CompletedPosOperation` always represents an already-completed originating fact and therefore contains its permanent receipt identity. Rails constructs it inside the same PostgreSQL transaction in which normalized Core facts are written (ADR-020).

Do **not** name the pre-receipt Rails payload `CompletedPosOperation`. Call that internal input `CompleteTransactionCommand` (or equivalent).

### 4.2 Future standalone (compatibility target — not built in Phase 4)

```text
Standalone Terminal operating a Register
        ↓
local authoritative completion
   ├── allocate receipt locally
   └── construct canonical CompletedPosOperation (compatible contract)
        ↓
synchronize
        ↓
central validation / posting of equivalent facts
```

Both clients ultimately produce compatible commercial completed facts. v1 is the commercial base; Terminal/config provenance is a later contract version before standalone completion authority.

### 4.3 Forbidden shortcut

```text
❌  CompleteTransaction → builds CompletedPosOperation without receipt → PostCompletion assigns receipt
```

Receipt assignment is part of constructing the completed operation, not a downstream afterthought.

---

## 5. Requirements by area

### 5.1 Execution context

Every completion must answer:

| Question | Source |
|---|---|
| Where? | `store_id` |
| Which register? | `register_id` |
| Which session? | `pos_session_id` |
| Which reporting period? | `reporting_period_id` (via session) |
| Who? | cashier / performed_by user |
| When? | `occurred_at` |
| Which business date? | explicit `business_date` (never reconstructed later from `created_at`) |

Actor identity uses existing central authentication. Phase 4 does not require Terminal enrollment or offline PIN replication.

### 5.2 Working transaction

Explicit application commands (names illustrative):

```text
StartTransaction
AddMerchandise
ChangeQuantity
RemoveOrVoidWorkingLine
CancelTransaction
TenderCash
CompleteTransaction
```

POS business actions are expressed as commands/services, not arbitrary model mutation from controllers.

Initial commercial scope:

```text
one store
one register
one active session
Standard quantity-tracked merchandise
sale-directed lines only
single Cash payment tender
```

### 5.3 Merchandise lookup

Support primary product identifier and variant SKU under existing normalized identifier rules.

Reject unknown, inactive/unsellable, individually tracked, and non-inventory merchandise.

### 5.4 Pricing

```text
product_variants.regular_price_cents
→ reference_unit_price_cents
→ selling_unit_price_cents   (= reference in Phase 4)
→ quantity (integer)
→ extended_selling_amount_cents
```

Resolve price from `product_variants.regular_price_cents`. Reject variants with pricing mode `open_price` and variants missing a required regular price. Missing required price blocks the line/completion; it must **never** become zero implicitly. Integer cents only. Quantity changes recalculate extended amount deterministically.

### 5.5 Tax

Authority: [pos-tax-contract.md](pos-tax-contract.md) and [ADR-019](../../../adr/ADR-019-pos-sales-tax-model.md).

```text
tax_class = merchandise tax class on the line
for each active Store Tax (calculation_order):
  require store_tax_rule.applies IS NOT NULL
  snapshot determination (applies true → half_up tax; false → basis 0, tax 0)
```

Phase 4 taxable basis = `extended_selling_amount_cents`. Independent component rounding; sum of rounded components. No combined-rate authority. No Tax Class override or exemption.

Golden fixtures: see tax contract §14.

### 5.6 Cash settlement

Preserve `amount_due`, `amount_presented`, `amount_applied`, `change`.

For ordinary single Cash payment: `presented = applied + change` and `applied = amount due`. Reject `presented < amount due`. Change is not a refund tender.

Tender amounts are positive magnitudes; `direction = payment` (refund deferred).

### 5.7 Sign convention (locked for Phase 6 compatibility)

> Line and tender monetary fields are stored as **positive magnitudes**; `direction` determines economic sign.

```text
sale line:    direction = sale,    line_total_cents = 2118  → contributes +2118
return line:  direction = return,  line_total_cents = 2118  → contributes -2118  (Phase 6)
payment:      direction = payment, amount_cents = …         → customer pays in
refund:       direction = refund,  amount_cents = …         → customer receives (Phase 6+)
```

Do **not** encode sign twice (`direction = return` and negative `line_total_cents`). Renaming transaction totals to `transaction_net_cents` may wait until the contract version that introduces returns.

### 5.8 Operation identity and idempotency (two hashes)

- Globally unique `operation_id` (UUIDv7) identifies the **completion operation**.
- `transaction_id` identifies the **commercial transaction**.
- Uniqueness scope follows ADR-009: `(source_id, command_type, idempotency_key)`.
- `command_type = pos.complete_transaction`; when completed, `fact_type = pos.transaction_completed`.
- `command_payload_hash` fingerprints the canonical `CompleteTransactionCommand` (no receipt / final completion timestamps).
- `envelope_hash` fingerprints the canonical `CompletedPosOperation` after receipt allocation; it is **not** the command hash.
- Same key + same `command_payload_hash` → return stored result.
- Same key + different `command_payload_hash` → integrity failure.
- Retry must never duplicate completed transaction, receipt number, tender, Inventory movements, outbox fact, or reporting effect.

### 5.9 Inventory posting (sale boundary)

For each completed quantity-tracked sale line, post through **`Inventory::PostSale`** (or equivalent)—**not** `Inventory::PostAdjustment`:

```text
paired physical effect  (delta −quantity)
paired valuation effect
reject_below_zero
source_type = "PosTransactionLine"
source_id   = line.id
```

Causal chain:

```text
operation_id → transaction_id → line_id → paired inventory ledger effects
```

### 5.10 Outbox

In the same authoritative completion transaction, record a slim domain outbox message:

```text
event_type = pos.transaction_completed
```

Minimum facts: operation id, transaction id, store id, register id, receipt identity references as needed by consumers. Delivery is at least once; consumers deduplicate by event id. Idempotent completion replay must not enqueue a second business-effect outbox fact for the same completed operation.

### 5.11 Authorization and context integrity

Require permission **`pos.transact`** through an effective Store-scoped (or global) assignment for the actor’s current store.

Before completing, enforce consistency:

```text
transaction.store_id           == current store
transaction.register_id        == session.register_id == period.register_id
transaction.pos_session_id     == open session
transaction.reporting_period_id == session.reporting_period_id
period.status                  == open
session.status                 == open
```

Deny direct unauthorized completion attempts; do not rely on UI hiding alone.

### 5.12 Receipt identity

Authority: [receipt-identity.md](receipt-identity.md) and amended [ADR-006](../../../adr/ADR-006-receipt-numbering.md).

```text
UNIQUE(store_id, register_id, receipt_sequence)

Compact reference:
S{store_number}-R{register_number}-T{receipt_sequence}
  min pad 3 / 2 / 7

Header form (same identity):
Store: 003   Reg: 02   Trans: 0018427
```

Persist `receipt_sequence` plus `store_number_snapshot` and `register_number_snapshot`. Allocate by incrementing `registers.receipt_sequence` under Register row lock in the completion transaction. Derive the compact reference; do not treat a formatted string alone as authority. Requires durable `registers.register_number` (see schema). Rendering/printing deferred to Phase 5.

### 5.13 Audit

Record enough to explain: operation completed, operation rejected, transaction cancelled, actor, register, session. Full controlled-action audit waits for Phase 6.

### 5.14 UI prohibition

Rails UI (when added in Phase 5) must not assign receipt sequences or mutate Inventory balances directly. Controllers call completion/posting services only.

---

## 6. Build order

Schema is subordinate to the contract. Do **not** discover the contract from columns created first.

```text
1. Lock v1 semantic decisions (this document + companions)
   - magnitude / sign convention
   - tax model (ADR-019 / pos-tax-contract)
   - receipt semantics
   - operation / idempotency ownership (pos_operations)

2. Write CompletedPosOperation v1 examples + golden fixtures (including tax)

3. Design / migrate
   - store_taxes / store_tax_rules (if not already present)
   - reporting_periods
   - sessions (minimal)
   - transactions
   - lines
   - tax components
   - tenders
   - operations
   - receipt sequence support

4. Pricing + tax calculators

5. Working transaction commands

6. Authoritative completion
   - authorize + context integrity
   - receipt allocation on registers.receipt_sequence
   - canonical CompletedPosOperation
   - persist transaction facts + envelope_hash
   - Inventory::PostSale (paired effects)
   - audit + pos.transaction_completed outbox

7. Idempotency / failure tests

8. Headless vertical acceptance
```

---

## 7. Failure and retry tests (required)

| Scenario | Expected |
|---|---|
| Completion validation failure | No completed transaction, no receipt, no Inventory effects, no POS outbox fact |
| Database commit failure | Transaction remains incomplete; no partial authoritative effects |
| Duplicate same operation | One transaction, one receipt, one paired Inventory effect set per line; same result returned; no second outbox fact |
| Lost-response retry | Server already committed; retry returns stored result |
| Payload mismatch on same key | Integrity failure; no second effect |

---

## 8. Acceptance criteria

Phase 4 is complete when a headless/application-level scenario can:

1. Establish store / register / reporting period / session / actor context.  
2. Start a working transaction.  
3. Resolve a Standard quantity-tracked variant.  
4. Add quantity and resolve regular price from `product_variants.regular_price_cents`.  
5. Calculate tax with component-level facts.  
6. Create Cash settlement.  
7. Complete through authoritative completion (`pos.transact` authorized).  
8. Observe a persisted `CompletedPosOperation` v1 that includes receipt identity.  
9. Observe completed POS facts and exactly one **paired** Inventory physical + valuation effect set per sale line.  
10. Observe one `pos.transaction_completed` outbox message for the completion.  
11. Retry the same operation and observe no duplicate business effect.  

Plus: companions remain consistent with migrated schema; golden tax/pricing fixtures pass; vocabulary uses `register` / `supplier` / etc. per ADR-011 and ADR-021.

---

## 9. Relationship to later phases

| Later need | Phase 4 stance |
|---|---|
| Phase 5 Cash close | Session table stays minimal; Phase 5 adds `closing_*` snapshot columns, not live cash counters |
| Phase 6 return lines | Same line table + `direction`; magnitudes stay positive |
| Standalone offline POS | Compatible `CompletedPosOperation` commercial base; later version adds Terminal/config provenance; **Terminal** required before offline completion authority (ADR-021); envelope + Core dual authority (ADR-020) |
| Discounts / approvals | Contract may reserve extensibility; no Phase 4 columns or algorithms required |

---

## 10. Open items (must resolve before migration where noted)

| Item | Status |
|---|---|
| Tax rate / applicability model | **Locked** — ADR-019 + [pos-tax-contract.md](pos-tax-contract.md) |
| Receipt / transaction reference format | **Locked** — ADR-006 (amended) + [receipt-identity.md](receipt-identity.md); print layout still Phase 5 |
| Envelope vs normalized Core + two hashes | **Locked** — ADR-020 + [operation-and-core-facts.md](operation-and-core-facts.md) |
| Register vs Terminal | **Locked** — ADR-021 + [register-identity.md](register-identity.md); Phases 4–6 Registers only |
| Schema constraints (qty, uniques, receipt counter, status NULL rules) | **Locked** — [phase4-schema.md](phase4-schema.md) |
| Pricing / sale inventory / outbox / authz | **Locked** — this plan §§5.4, 5.9–5.11 |
| Pre-Phase-4 `workstations` → `registers` migration | **Required** before POS period/session/transaction migrations |
| Durable `registers.register_number` + `receipt_sequence` | **Required** as part of rename slice / before completed receipts |
| CompletedPosOperation v1 golden fixtures review | **Required** before migrate |
| Tax component / rule model IDs from new `store_taxes` / `store_tax_rules` | Implement with Phase 4 (or immediately preceding) migrations |

Unresolved items must not silently default sales-tax rates to basis points or make merchandise snapshots optional at completion.
