# Slice 7 — Tender lifecycle inventory

Status: **Complete — dispositions assigned.** Working-tender persistence: **audited destroy + add** (no supersession schema). Quick Customer product decision unchanged (**7B.2**); create-path extraction required. Gates locking of 7A/7B packets. Does **not** implement [#93](https://github.com/BankEncore/ShelfSense-v1/issues/93) or [#94](https://github.com/BankEncore/ShelfSense-v1/issues/94).

Authority: [slice7-overview.md](slice7-overview.md), [slice7-keyboard-contract.md](slice7-keyboard-contract.md). Verified against POS tender/issuance services, `Pos::CompleteTransaction` / `Pos::CompleteStoredValue`, customer admin create, and attach services (2026-08-30).

## Disposition key

| Disposition | Meaning |
|---|---|
| **7A** | Ordinary tender select / remove / atomic replace in Tender Review |
| **7B** | SV tender / issuance / capping / completion revalidation / customer-required flows / Quick Customer |
| **7A inspect-only** | Row selectable in 7A; Edit/Remove withheld until 7B (code may already allow destroy) |
| **N/A** | Type not cashier-enabled under current seed/config (e.g. check refund when `allows_refund: false`) |

## Cross-cutting code facts

| Topic | Reality |
|---|---|
| When value moves | Working tenders/issuances are rows only. Settlement and SV ledger post in `Pos::CompleteTransaction` → `settle_tenders!` / `Pos::CompleteStoredValue` (`app/services/pos/complete_transaction.rb`, `complete_stored_value.rb`). |
| Working remove | `Pos::RemoveWorkingTender`, `Pos::AbandonTender`, `Pos::Support.clear_working_tenders!` — **destroy**; SV detail cascades (`PosTender` dependent destroy). **No** `StoredValue::Reverse` while working (nothing posted yet). |
| Cash upsert | `Pos::TenderCash` upserts the single cash **payment** row in place. Cash **refund** upserts via cash branch of `Pos::AddRefundTender`. |
| Ordinary non-cash | `Pos::AddTender` / `Pos::AddRefundTender` append new rows (optional `external_reference`). |
| SV add | `Pos::AddStoredValueTender`, `Pos::AddStoredValueRefundTender` — balance/capacity checks; no ledger post. |
| Issuance | `Pos::AddStoredValueIssuance` / `Pos::RemoveStoredValueIssuance` — working rows; **clears tenders** on add/remove; activate/reload at complete. |
| Replace orchestration | **`Pos::ReplaceTender` does not exist** — 7A introduces it for ordinary families only. |
| Completed immutability | Completed tenders/issuances are commercially readonly; correction via post-void / new refund. Posted SV reverse: `Pos::PostVoidStoredValue` / `StoredValue::Reverse`. |
| Completion idempotency | `Pos::OperationLease` on complete; nested SV keys under completion operation id. Tender **add** has no idempotency key today. |
| Locks | Working mutations: `lock_working_transaction!` + optimistic `lock_version`. SV account `lock` at post time. |

Controller dispatch today: `Pos::WorkspacesController` tender / remove_tender / abandon_tender / stored_value_issuance actions.

---

## Lifecycle matrix

| Type | Add service | When value moves | Removable now | Editable now | Working reversal | Locks | Idempotency | Disposition |
|---|---|---|---|---|---|---|---|---|
| Cash payment | `Pos::TenderCash` (`tender_cash.rb`) | Working row + presented/change; applied/change re-settled at complete | Yes — destroy paths | Upsert — re-call `TenderCash` | Destroy | Txn `lock!` + `lock_version` | None on add; complete lease | **7A** |
| Cash refund | `Pos::AddRefundTender` (cash) | Working refund row | Yes — destroy | Upsert — re-call for cash | Destroy | Same | None on add; complete lease | **7A** |
| Card payment | `Pos::AddTender` | Working row + optional reference; no processor post | Yes — destroy | None (append) | Destroy | Same | None on add; complete lease | **7A** (remove + re-authorize; no field-edit of external auth) |
| Card refund | `Pos::AddRefundTender` | Working refund + optional reference | Yes — destroy | None | Destroy | Same | None on add; complete lease | **7A** (same family) |
| Check payment | `Pos::AddTender` | Working row + optional reference | Yes — destroy | None (append); replace via 7A orchestration | Destroy | Same | None on add; complete lease | **7A** |
| Check refund | `Pos::AddRefundTender` | Same if type allows refund | Yes if row exists | None | Destroy | Same | None on add; complete lease | **N/A** by default seed (`allows_refund: false`); **7A** when enabled |
| Other payment | `Pos::AddTender` (`behavioral_category: other`) | Working row + reference per type policy | Yes — destroy | None (append); configured manual-reference types editable via 7A replace | Destroy | Same | None on add; complete lease | **7A** |
| Other refund | `Pos::AddRefundTender` (if `allows_refund`) | Working refund | Yes — destroy | None | Destroy | Same | None on add; complete lease | **7A** when enabled |
| Gift-card payment | `Pos::AddStoredValueTender` | Redeem at `CompleteStoredValue#post_tender!` | Yes while working — destroy | None | Destroy (**not** SV reverse) | Txn lock; account lock at post | Nested tender key at post | **7A inspect-only** → **7B** mutate |
| Store-credit payment | same (`store_credit`) | Redeem at complete | Yes — destroy | None | Destroy | Same | Nested tender key | **7A inspect-only** → **7B** mutate |
| Trade-credit payment | same (`trade_credit`) | Redeem at complete | Yes — destroy | None | Destroy | Same | Nested tender key | **7A inspect-only** → **7B** mutate |
| Gift-card refund (existing account) | `Pos::AddStoredValueRefundTender` (`existing_account`) | Credit at complete | Yes — destroy | None | Destroy | Txn + capacity; account lock at post | Nested tender key | **7A inspect-only** → **7B** mutate |
| Gift-card refund (new card) | same (`new_gift_card`) | Provision + credit at complete | Yes — destroy | None | Destroy | Same + program checks | Nested tender key | **7A inspect-only** → **7B** mutate |
| Store-credit refund | same (`existing_account` / `customer_store_credit`) | Ensure account + credit at complete | Yes — destroy | None | Destroy | Same | Nested tender key | **7A inspect-only** → **7B** mutate |
| Trade-credit refund | same (`existing_account`; original-account constrained) | Credit at complete | Yes — destroy | None | Destroy | Same | Nested tender key | **7A inspect-only** → **7B** mutate |
| Gift-card issuance (activate/reload) | `Pos::AddStoredValueIssuance` / `RemoveStoredValueIssuance` | Activate/reload at `post_issuance!`; clears tenders on add/remove | Yes — remove issuance service | None today | Destroy issuance (not SV reverse while working) | Txn lock; card/account lock at post | Nested issuance key at post | **7B** (edit/replace while unactivated) |

---

## Working-tender persistence decision

**Lock:** Working correction uses **audited destroy + add under one transaction lock**, not a durable supersession relationship on `pos_tenders`.

**Rationale:** No `superseded_by` / supersession columns exist; destroy is the current working model; inventing supersession schema is out of Slice 7 scope. No second ledger.

**Audit** on replace/remove must capture safe facts: tender type, amounts (and cash presented/change when applicable), actor, reason, source and idempotency identifiers. Do **not** audit full card numbers or full stored-value instrument numbers.

### `Pos::ReplaceTender` (7A target)

```text
authorize → lock transaction → verify working membership
  → validate replacement family/support
  → remove original (destroy) → add replacement
  → recalc settlement → commit
```

On any failure after lock: leave the original tender unchanged. Cash may keep upsert semantics inside the orchestration where behaviorally equivalent. Card: remove + re-authorize only (no field edit of external auth).

### Return to Sale

Atomic clear of all reversible working tenders via `clear_working_tenders!` (or equivalent orchestration), **or** change nothing if any tender cannot be reversed under 7A/7B rules. Not synonymous with Cancel Transaction.

---

## Capability vs UI law (7A)

| Layer | SV / issuance working rows |
|---|---|
| **Code today** | `RemoveWorkingTender` / issuance remove already destroy them without ledger reverse |
| **7A product / UI** | Select and inspect allowed; **Edit / Remove unavailable** until 7B, with a concise reason |
| **7B** | Capping, remove/replace, completion revalidation, issuance edit while unactivated, customer-required flows |

Do not confuse destroy capability with 7A permission to expose mutation.

---

## Quick Customer reuse checklist

Product decision unchanged: Quick Customer remains **7B.2** (child of shared Register Customer Lookup; Sale + customer-required SV/refund; no F2 key — see [slice7-keyboard-contract.md](slice7-keyboard-contract.md) `open-customer-lookup`).

| Item | Verdict |
|---|---|
| Authoritative create | **Gap:** admin only — `Admin::CustomersController#create` + `create_and_audit!` (`admin/customers_controller.rb`, `admin/base_controller.rb`). **No** `Customers::Create` service. |
| Reusable now | `Customers::NormalizeContact`, `Customers::SuggestDuplicates`, `Customers::Search`, `Pos::AttachCustomer` |
| Permission | Catalog: `customers.manage` / `customers.view`. Draft `customers.create` **permission key does not exist**. Audit action string is `customers.create`. |
| Fields | `display_name` required; email/phone optional on bare `Customer`. Email ∨ phone as a **contextual** Quick Customer / credit rule does **not** contradict Phase 8 bare-create policy (contact required on requests, not bare identity). |
| Canonical / merge | ADR-023; create yields active canonical; duplicates warn + acknowledge; no auto-merge. Attach requires active canonical. |
| Idempotency | None on customer create today (merge has keys; create does not). |

### Implementation boundary (not product deferral)

7B.2’s first work extracts **`Customers::Create`** (validate → duplicate gate → persist → audit action `customers.create`) and has **admin + Quick Customer** call it. Authorize create with **`customers.manage`** (align draft wording to the catalog) unless a later ADR adds a distinct `customers.create` permission.

If extraction cannot land without duplicating Customer domain logic, stop with a documented blocker issue. **Do not** invent a Register-only create path.

---

## Notes for later packets

| Topic | Owner |
|---|---|
| Tender Review selection, ordinary remove/replace, Return to Sale (O15–O17) | **7A** |
| Nested customer lookup, attach, change-customer guards | **7B.1** |
| Quick Customer + `Customers::Create` extraction | **7B.2** |
| SV capping; working SV remove/replace; issuance edit while unactivated; completion revalidation that fails recoverably (no silent tender shrink) | **7B.3** |
| Activated / completed issuance or tender edit from workspace | **Out** — recovery / post-void only |
| Keyboard dispatcher binding | **7C** (implements 7.0 contract) |

## Packet readiness

| Packet | Inventory gate |
|---|---|
| 7A | **Met** — ordinary dispositions and persistence decision locked |
| 7B | **Met** — SV/issuance dispositions and Quick Customer boundary locked; create extraction called out |
| 7C | Uses 7.0 contract; no further inventory gate |
