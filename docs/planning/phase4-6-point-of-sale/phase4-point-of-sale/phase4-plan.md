# Phase 4 — POS Transaction and Posting Foundation

**Status:** Planning (implementation-ready once companions are followed)

**Authority**

| Document | Role |
|---|---|
| [CompletedPosOperation v1](completed-pos-operation-v1.md) | Canonical completed-operation contract, command/completion boundary, fixtures |
| [POS tax contract](pos-tax-contract.md) | Store Tax / rules / calculator; completed tax facts ([ADR-019](../../../adr/ADR-019-pos-sales-tax-model.md)) |
| [Receipt identity](receipt-identity.md) | Transaction reference and receipt display forms ([ADR-006](../../../adr/ADR-006-receipt-numbering.md)) |
| [Operation and Core facts](operation-and-core-facts.md) | Envelope vs normalized Core ([ADR-020](../../../adr/ADR-020-pos-operation-envelope-and-core-facts.md)) |
| [Phase 4 schema](phase4-schema.md) | Tables, columns, constraints for Phase 4 migrations |
| [Phases 4–6 implementation plan](../spec.md) | Broader Phase 4–6 sequencing; Phase 5–6 detail |
| Accepted ADRs | Cross-cutting policy (`AGENTS.md`, ADR-006, ADR-007, ADR-009, ADR-011, ADR-019, ADR-020, inventory posting contract) |

Where this plan and `../spec.md` §4 disagree on completion semantics, tax representation, session columns, or operation identity, **prefer this document and its companions**. Update `../spec.md` when convenient so the multi-phase plan stays aligned.

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

Rails is the first POS client. A future standalone Register must be able to produce the **same canonical completed fact**; only the location of the completion boundary differs.

---

## 2. Locked decisions

| Topic | Decision |
|---|---|
| Client | Rails-native POS only; standalone/offline Register deferred |
| Transaction model | One `pos_transactions` row transitions working → completed (or cancelled); no separate sale/refund/exchange tables |
| Line directions (Phase 4) | Sale lines only; return lines deferred to Phase 6, but **sign convention is locked now** |
| Monetary signs | Store positive magnitudes; `direction` supplies economic sign (lines and tenders) |
| Completion vs operation | `CompleteTransactionCommand` is the pre-completion Rails command; `CompletedPosOperation` is built **inside** authoritative completion and always includes receipt identity |
| Receipt | Allocated at completion; scoped to store + workstation; human reference `S{store_number}-R{workstation_number}-T{receipt_sequence}` per [receipt-identity.md](receipt-identity.md) / ADR-006; print layout deferred to Phase 5 |
| Tax model | [ADR-019](../../../adr/ADR-019-pos-sales-tax-model.md) / [pos-tax-contract.md](pos-tax-contract.md): Tax Class → Store Tax Rule → Store Tax; Store Tax is the POS component |
| Tax rate storage | `rate_percent` as `numeric(6,3)`; contract strings like `"1.250"`; not basis points |
| Tax applicability | Rule `applies` is `true` / `false` / `NULL` (unresolved); no treatment enum; auto-create rule rows |
| Tax class | Consumes merchandise-domain Tax Classes; line stores `tax_class_id` + code snapshot; no Phase 4 override; no synthetic `nontaxable` result class |
| Completed tax facts | Snapshot **every active** Store Tax determination per line (`applies` true or false); not only applicable taxes |
| Merchandise snapshot | Required JSON at completion (sku, description, tax_class_code minimum) |
| Inventory | Post only through existing Inventory services; no direct balance mutation; no `reserved` effect from open/working transactions |
| Unit tracking | No `inventory_unit_id` in Phase 4; individually tracked merchandise rejected |
| Session shape | Minimal open/close timestamps and FKs; **no** float / closing count / expected cash / variance columns until Phase 5 |
| Operation durability | Durable `pos_operations` with full canonical envelope **and** ADR-009 idempotency; normalized Core is operational authority; see [operation-and-core-facts.md](operation-and-core-facts.md) / ADR-020 |
| Identity separation | `operation_id` ≠ `transaction_id`; never use `transaction_id` as the completion idempotency key |
| Inventory causal `source_type` | Stay consistent with Phase 3 Rails class-name convention (`PosTransactionLine`) unless a later ADR changes inventory source kinds globally |
| Money / IDs / time | Integer cents; UUIDv7; `occurred_at` (UTC) + explicit `business_date`; store IANA timezone retained on store |
| Vocabulary | Use `workstation` for durable POS identity (ADR-011). Parent plan “Register” means that workstation |

---

## 3. Scope

### 3.1 Included

- Minimal `pos_reporting_periods` and `pos_sessions` (no Cash accountability columns)
- Working and completed `pos_transactions`, lines, line tax components, Cash tenders
- Durable `pos_operations` (completion provenance + idempotency)
- Workstation-scoped receipt sequence allocation at completion
- Merchandise resolution for Standard quantity-tracked sellable variants
- Pricing: reference unit price → selling unit price → extended amount (no overrides/discounts)
- Ordinary tax calculation per [pos-tax-contract.md](pos-tax-contract.md) (Store Taxes, nullable rules, full determination snapshots)
- Cash settlement (presented / applied / change) for a single payment tender
- `Pos::CompleteTransaction` authoritative completion path (see §5)
- Inventory posting for each completed sale line through `Inventory::PostAdjustment` (or equivalent Phase 3 boundary)
- Minimum audit for complete / reject / cancel
- Headless acceptance and failure/idempotency tests

### 3.2 Explicitly out of Phase 4

- Keyboard/scanner Register UI, receipt printing, Session close Cash count, Z reports (Phase 5)
- Opening float / closing expected / variance columns on sessions (Phase 5)
- Returns, mixed-direction transactions, discounts, approvals, suspend/recall, post-void (Phase 6)
- Individually tracked and non-inventory merchandise; open-ring (Phase 6)
- Card / Stored Value / multi-tender beyond single Cash payment
- Offline credential replication, installation enrollment, standalone Register runtime
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
   ├── validate working transaction
   ├── allocate receipt identity
   ├── freeze occurred_at / business_date
   ├── freeze commercial facts
   ├── construct canonical CompletedPosOperation v1
   │         (includes receipt.sequence, number snapshots, optional reference)
   ├── persist normalized Core POS facts
   ├── persist pos_operations (full envelope + payload_hash + idempotency)
   └── post Inventory / reporting effects
        ↓
COMMIT
```

**Invariant:** `CompletedPosOperation` always represents an already-completed originating fact and therefore contains its permanent receipt identity. Rails constructs it inside the same PostgreSQL transaction in which normalized Core facts are written (ADR-020).

Do **not** name the pre-receipt Rails payload `CompletedPosOperation`. Call that internal input `CompleteTransactionCommand` (or equivalent).

### 4.2 Future standalone (compatibility target — not built in Phase 4)

```text
Standalone Register
        ↓
local authoritative completion
   ├── allocate receipt locally
   └── construct canonical CompletedPosOperation
        ↓
synchronize
        ↓
central validation / posting of equivalent facts
```

Both clients ultimately produce the same canonical completed fact. The difference is only where the completion boundary occurs.

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
| Which workstation? | `workstation_id` |
| Which session? | `pos_session_id` |
| Which reporting period? | `reporting_period_id` (via session) |
| Who? | cashier / performed_by user |
| When? | `occurred_at` |
| Which business date? | explicit `business_date` (never reconstructed later from `created_at`) |

Actor identity uses existing central authentication. Phase 4 does not require installation enrollment or offline PIN replication.

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
one workstation
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
reference_unit_price_cents
→ selling_unit_price_cents   (= reference in Phase 4)
→ quantity
→ extended_selling_amount_cents
```

Missing required price blocks the line/completion; it must never become zero implicitly. Integer cents only. Quantity changes recalculate extended amount deterministically.

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

### 5.8 Operation identity and idempotency

- Globally unique `operation_id` (UUIDv7) identifies the **completion operation**.
- `transaction_id` identifies the **commercial transaction**.
- Uniqueness scope follows ADR-009: `(source_id, operation_type, idempotency_key)` with canonical payload hash.
- Same key + same payload → return stored result.
- Same key + different payload → integrity failure.
- Retry must never duplicate completed transaction, receipt number, tender, Inventory movement, or reporting effect.

### 5.9 Inventory posting

For each completed quantity-tracked sale line: physical delta `−quantity` through the Inventory posting boundary.

Causal chain:

```text
operation_id → transaction_id → line_id → inventory ledger entry
```

Phase 4 inventory source fields stay consistent with existing convention:

```text
source_type = "PosTransactionLine"
source_id   = line.id
```

### 5.10 Receipt identity

Authority: [receipt-identity.md](receipt-identity.md) and amended [ADR-006](../../../adr/ADR-006-receipt-numbering.md).

```text
UNIQUE(store_id, workstation_id, receipt_sequence)

Compact reference:
S{store_number}-R{workstation_number}-T{receipt_sequence}
  min pad 3 / 2 / 7

Header form (same identity):
Store: 003   Reg: 02   Trans: 0018427
```

Persist `receipt_sequence` plus `store_number_snapshot` and `workstation_number_snapshot`. Derive the compact reference; do not treat a formatted string alone as authority. Requires durable `workstations.workstation_number` (see schema). Rendering/printing deferred to Phase 5.

### 5.11 Audit

Record enough to explain: operation completed, operation rejected, transaction cancelled, actor, workstation, session. Full controlled-action audit waits for Phase 6.

### 5.12 UI prohibition

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
   - receipt allocation
   - canonical CompletedPosOperation
   - persist transaction facts
   - Inventory posting

7. Idempotency / failure tests

8. Headless vertical acceptance
```

---

## 7. Failure and retry tests (required)

| Scenario | Expected |
|---|---|
| Completion validation failure | No completed transaction, no receipt, no Inventory effect |
| Database commit failure | Transaction remains incomplete; no partial authoritative effects |
| Duplicate same operation | One transaction, one receipt, one Inventory effect; same result returned |
| Lost-response retry | Server already committed; retry returns stored result |
| Payload mismatch on same key | Integrity failure; no second effect |

---

## 8. Acceptance criteria

Phase 4 is complete when a headless/application-level scenario can:

1. Establish store / workstation / reporting period / session / actor context.  
2. Start a working transaction.  
3. Resolve a Standard quantity-tracked variant.  
4. Add quantity and resolve regular price.  
5. Calculate tax with component-level facts.  
6. Create Cash settlement.  
7. Complete through authoritative completion.  
8. Observe a persisted `CompletedPosOperation` v1 that includes receipt identity.  
9. Observe completed POS facts and exactly one Inventory effect per sale line.  
10. Retry the same operation and observe no duplicate business effect.  

Plus: companions remain consistent with migrated schema; golden tax/pricing fixtures pass; vocabulary uses `workstation` / `supplier` / etc. per ADR-011.

---

## 9. Relationship to later phases

| Later need | Phase 4 stance |
|---|---|
| Phase 5 Cash close | Session table stays minimal; Phase 5 adds `closing_*` snapshot columns, not live cash counters |
| Phase 6 return lines | Same line table + `direction`; magnitudes stay positive |
| Standalone Register | Same `CompletedPosOperation` contract; sync posts equivalent central facts; envelope + Core dual authority (ADR-020) |
| Discounts / approvals | Contract may reserve extensibility; no Phase 4 columns or algorithms required |

---

## 10. Open items (must resolve before migration where noted)

| Item | Status |
|---|---|
| Tax rate / applicability model | **Locked** — ADR-019 + [pos-tax-contract.md](pos-tax-contract.md) |
| Receipt / transaction reference format | **Locked** — ADR-006 (amended) + [receipt-identity.md](receipt-identity.md); print layout still Phase 5 |
| Envelope vs normalized Core | **Locked** — ADR-020 + [operation-and-core-facts.md](operation-and-core-facts.md); full envelope required; Core for all commercial workflows |
| Durable `workstations.workstation_number` | **Required** before issuing completed receipts under the new reference form |
| Tax component / rule model IDs from new `store_taxes` / `store_tax_rules` | Implement with Phase 4 (or immediately preceding) migrations |

Unresolved items must not silently default sales-tax rates to basis points or make merchandise snapshots optional at completion.
