# Phase 6 Slice 6.3 — Completed transaction history

**Status:** Implemented.

**Authority:** Store-scoped completed-transaction lookup, immutable detail, and customer-receipt reprint for the Phase 5/6 register. Dual authority with Core remains [mvp-contract.md](mvp-contract.md) / [ADR-020](../../../adr/ADR-020-pos-operation-envelope-and-core-facts.md). Receipt identity remains [receipt-identity.md](../phase4-point-of-sale/receipt-identity.md).

Companions: [phase6-plan.md](phase6-plan.md), [register-workspace.md](../phase5-cash-register/register-workspace.md), [phase4-schema.md](../phase4-point-of-sale/phase4-schema.md).

Draft [receipts.md](../../../drafts/specifications/pos/receipts.md) is vocabulary. This document is implementation authority for the MVP subset.

### Actually locked

```text
pos.transact + current Store authorizes history (not original cashier)
no open Session required
search is Store-scoped completed rows only
exact receipt reference is a sufficient lookup
search date means business_date
cashier_name_snapshot on new completions; null displays "Not captured"
history never rebinds session[:pos_register_id]
history Register resume is deterministic (bound Session, else exactly one, else enter)
immediate completion and historical lookup are separate screens
reprint is marked REPRINT, keeps original identity, creates no commercial state
history renders Core snapshots; it does not parse the envelope
Phase 5/6.1/6.2 checkout and close/Z remain unchanged
```

---

## 1. Objective

A user with `pos.transact` at the current Store can:

```text
find a completed transaction
        ↓
inspect exactly what happened
        ↓
reprint its customer receipt as REPRINT
```

even after live Product description, price, tax configuration, tender name, InventoryUnit state, or user display name change.

---

## 2. Authorization

```text
pos.transact + current Store
  → search / view / reprint that Store’s completed transactions
```

No new permission. Do **not** require an open Session, the same Register, or the original cashier.

Another Store’s transaction — including a globally unique `transaction_reference` or a direct UUID — is inaccessible (`404` on show; empty index).

`GET /pos/transactions/:id/completed` (immediate post-completion) **keeps** `require_transaction_cashier!` and may bind `session[:pos_register_id]` to the completing Register.

History is a separate path:

```text
GET /pos/transactions
GET /pos/transactions/:id
```

Historical `show` must **not** set `session[:pos_register_id]`. Viewing another cashier’s sale on Register 2 must not retarget this cashier’s workspace.

Working and cancelled rows are not history. Direct UUID to a non-completed row → `404`.

---

## 3. Immediate completion vs history

| Path | Controller | Meaning |
|---|---|---|
| `GET /pos/transactions/:id/completed` | `CompletedTransactionsController` | “I just completed this sale” (New sale / Close register) |
| `GET /pos/transactions` / `:id` | `TransactionsController` | Historical lookup |

They share the customer-receipt **print** partial. They do not share controller behavior or chrome.

---

## 4. Search

GET form. No fuzzy `q`. Fields:

```text
Receipt reference     [S001-R01-T0000123]
Register              [all Registers for the Store, including inactive]
Transaction #         [receipt_sequence]
Business date         [YYYY-MM-DD]
```

Query object: `Pos::CompletedTransactionSearch`, starting at `PosTransaction.completed.where(store_id:)`.

### 4.1 Precedence

If `transaction_reference` is present after trim + uppercase → **only** that exact match, still scoped to the current Store. Ignore Register, sequence, and date (leftover filters must not hide a pasted reference).

Otherwise AND supplied `register_id`, `receipt_sequence`, and `business_date` (blank ignored).

No auto-redirect to detail. Zero or one row is a normal index result.

### 4.2 Receipt reference

Exact `transaction_reference` after trim and uppercase. No contains/prefix. Uniqueness is global; history still filters `store_id`.

### 4.3 Register + Transaction #

Form label **Transaction #**. Param and column: `receipt_sequence` (integer; `0000123` → `123`).

`register_id` must belong to the current Store. A foreign id is an invalid filter (empty result), not a `404`.

Dropdown lists **all** Registers for the Store (not `active` only), labeled with current number + name. List/detail still render `register_number_snapshot`.

Without Register, sequence matches across the Store’s Registers and may return multiple rows.

### 4.4 Date

Exact `business_date`. Display `completed_at` separately in Store-local time. Do not derive the filter from `completed_at`.

### 4.5 Recent

No filters: most recent 50 completed transactions for the current Store.

```text
completed_at DESC
id DESC
```

Pagination matches [Products::AdminIndexQuery](../../../../app/services/products/admin_index_query.rb): 50 per page, invalid page clamped. Invalid date/sequence fail safely (empty result, no 500).

Preload `pos_tenders` for the index tender column.

---

## 5. Indexes

Partial indexes:

```text
(store_id, completed_at DESC, id DESC) WHERE status = 'completed'
(store_id, business_date, completed_at DESC, id DESC) WHERE status = 'completed'
```

Existing unique `transaction_reference` and `(store_id, register_id, receipt_sequence)` stay. Do not index every filter combination.

---

## 6. Cashier snapshot

Column `pos_transactions.cashier_name_snapshot` (nullable string). Do **not** add it to `pos_transactions_status_null_rules`. Legacy completed rows may remain null.

New completions set it from the completing actor’s `display_name` in the same update that marks `completed`, and emit envelope `origin.performed_by_name` with the same string.

`verify!` accepts v2 envelopes **without** `performed_by_name`. If the key is present, it must be non-blank. Do not bump `schema_version`. Do not rewrite stored envelopes.

History list/detail display the snapshot. Null → `Not captured`. Never fall back to live `User#display_name`.

Backfill (same migration, best-effort): `pos.transaction_completed` succeeded audit `actor_label` for `subject_type = PosTransaction`.

---

## 7. Index columns

```text
Receipt        transaction_reference
Business date  completed fact
Completed      completed_at, Store-local
Register       register_number_snapshot
Cashier        cashier_name_snapshot
Total          total_cents
Tender         tender_name by tender_number, joined with " + "
```

Row/reference opens detail. No live Product / TenderType / User joins except compatibility that does not rewrite displayed facts.

---

## 8. Historical detail

Header from receipt snapshots (`store_number_snapshot`, `register_number_snapshot`, `receipt_sequence`, `transaction_reference`), cashier snapshot, `business_date`, Store-local `completed_at`.

Lines from Core + `merchandise_snapshot`: line number, `direction` (always `sale` in 6.3), quantity, description, SKU, Used `condition_code` / `unit_identifier` when present, reference unit price, selling unit price, extended, line tax, line total.

Do **not** join live Product / InventoryUnit / MerchandiseCondition for historical description. Absent or blank snapshot description displays `Description not captured`; never substitute today’s Product name.

Default tax: line tax + transaction tax. Collapsed details: stored `PosLineTaxComponent` rows where `applies` is true (name, rate, taxable basis, tax). Omit non-applicable determinations.

Tenders in `tender_number` order. Operator detail **may** show `external_reference`. Customer print omits it.

Fact-driven sections only. Do not render empty override / discount / return / post-void blocks or disabled fake actions. Line IDs remain the 6.5 hook.

---

## 9. Reprint

Immediate completion Print is the original copy (`reprint: false`). History Print is `REPRINT` (`reprint: true`). Same print partial; same receipt identity; no new commercial records, inventory, outbox, or receipt sequence.

No reprint table. No reprint audit in 6.3 (`window.print` stays client-side).

---

## 10. Navigation

- Application nav (next to Register): `pos.transact` + current store — lookup without opening a Session.
- Register workspace header: Transactions. Does not cancel or complete a working basket.
- Immediate completion actions may include Transactions (POS layout has no application nav).
- History pages: Store, signed-in user, Transactions, Register. Register resumes the bound Register when `session[:pos_register_id]` has an open Session owned by this cashier; otherwise the cashier’s sole open Session at this Store; otherwise enter. No New sale / Close register / scan field. Multiple open Sessions never pick an arbitrary Register.

History stays under `/pos` with the POS importmap. No 6.3 keyboard shortcut (6.7). Do not add Hotwire to admin chrome.

---

## 11. Out of 6.3

```text
linked return execution
return eligibility / returned-to-date
post-void
cancelled-transaction history
working-transaction history
product/SKU / InventoryUnit / cashier / tender / amount-range search
arbitrary date ranges
export / reporting
receipt print-attempt persistence / reprint audit
electronic receipt delivery
cross-Store history
live User display-name fallback for cashier
auto-redirect from search to detail
rebinding session[:pos_register_id] from historical detail
envelope-driven UI
```

---

## 12. Authorization, audit, envelope

Register/history: `pos.transact` at the current Store. Completion audit is unchanged. History reads are not audited in 6.3.

Envelope remains durable provenance. Required history behavior uses normalized Core. New completions emit `performed_by_name`; old v2 envelopes without it still `verify!`.

---

## 13. Acceptance

1. A Store cashier can view recent completed Store transactions without opening a Register Session.
2. Exact full receipt reference finds the row (leftover other filters ignored).
3. Register + Transaction # finds the row; sequence without Register may return multiple Store rows.
4. Business date and Register filters AND together when no reference is supplied.
5. History never exposes another Store.
6. A cashier may view another cashier’s completed transaction at the same authorized Store.
7. Historical detail shows line, unit, tax, tender, cashier, timing, receipt, and total facts from completed snapshots.
8. History remains materially unchanged after live Product / Tender / User changes; Used unit identity survives unit removal.
9. Null `cashier_name_snapshot` displays `Not captured`, not the live user name.
10. Absent or blank `merchandise_snapshot` description displays `Description not captured`, never the live Product name.
11. Historical print uses the original receipt identity and a visible **REPRINT** marker; customer print omits external tender references.
12. Reprint creates no commercial / inventory / tender / receipt-sequence effects.
13. Historical show does not set `session[:pos_register_id]`.
14. History Register resumes the bound open Session when present; the cashier’s sole open Session otherwise; enter when several Sessions are open and none is bound.
15. 6.5 can later attach Return items to historical line IDs without redesigning this surface.
16. Phase 5/6.1/6.2 checkout and close/Z remain green.

---

## 14. Rollout

`db:migrate` only. No new permission; `shelfsense:seed_permissions` is not required for 6.3.

Rollback of the history indexes and `cashier_name_snapshot` is supported. Do not delete completed facts to roll back. Legacy `cashier_name_snapshot` may remain null.
