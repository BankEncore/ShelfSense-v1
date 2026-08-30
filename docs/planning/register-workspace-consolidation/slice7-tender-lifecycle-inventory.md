# Slice 7 — Tender lifecycle inventory

Status: **Complete — dispositions assigned** (including idempotency, issuance-with-tenders, Quick Customer permission, and stored-value capping/revalidation). Gates locking of 7A/7B packets. Does **not** implement [#93](https://github.com/BankEncore/ShelfSense-v1/issues/93) or [#94](https://github.com/BankEncore/ShelfSense-v1/issues/94).

Authority: [slice7-overview.md](slice7-overview.md), [slice7-keyboard-contract.md](slice7-keyboard-contract.md). Verified against POS tender/issuance services, `Pos::CompleteTransaction` / `Pos::CompleteStoredValue`, `Pos::OperationLease`, customer admin create, and attach services (2026-08-30).

## Disposition key

| Disposition | Meaning |
|---|---|
| **7A** | Ordinary tender select / remove / atomic replace in Tender Review |
| **7B** | SV tender / issuance / capping / completion revalidation / customer-required flows / Quick Customer |
| **7A inspect-only** | Row selectable in 7A; Edit/Remove withheld until 7B (code may already allow destroy) |
| **N/A** | Type not cashier-enabled under current seed/config (e.g. check refund when `allows_refund: false`) |

## Core boundary (normative)

```text
Working tender / issuance  → database row only (no stored-value ledger movement)
Transaction completion     → settle tenders + CompleteStoredValue ledger posting
Post-void / recovery       → posted-value reversal (outside ordinary workspace editing)
```

Therefore 7B must **not** describe working tender or issuance correction as an “exact-once stored-value reversal.”

Use:

- **idempotent working removal**
- **atomic working replacement**
- **completion-time stored-value posting and revalidation**
- **posted-value reversal** only for post-void / recovery outside ordinary workspace editing

Creating compensating ledger entries for an **unposted** working tender would be wrong.

---

## Cross-cutting code facts

| Topic | Reality |
|---|---|
| When value moves | Working tenders/issuances are rows only. Settlement and SV ledger post in `Pos::CompleteTransaction` → `settle_tenders!` / `Pos::CompleteStoredValue`. |
| Working removal | `Pos::RemoveWorkingTender`, `Pos::AbandonTender`, `Pos::Support.clear_working_tenders!` — **destroy**; SV detail cascades. **No** `StoredValue::Reverse` while working. |
| Cash upsert | `Pos::TenderCash` upserts the single cash **payment** row. Cash **refund** upserts via cash branch of `Pos::AddRefundTender`. |
| Ordinary non-cash | `Pos::AddTender` / `Pos::AddRefundTender` append new rows (optional `external_reference`). |
| Issuance | `Pos::AddStoredValueIssuance` / `RemoveStoredValueIssuance` — working rows; **clears all working tenders** on add and on remove. |
| Replace orchestration | **`Pos::ReplaceTender` does not exist** — 7A introduces it for ordinary families; 7B for SV/issuance. |
| Completed immutability | Completed tenders/issuances are commercially readonly; correction via post-void / new refund. Posted SV reverse: `Pos::PostVoidStoredValue` / `StoredValue::Reverse`. |
| Add idempotency today | Tender/issuance **add has no idempotency key**. Completion uses `Pos::OperationLease` (`command_type: pos.complete_transaction`). Nested SV post keys under completion operation id. |

---

## Lifecycle matrix

| Type | Add service | When value moves | Removable now | Editable now | Working removal/correction | Locks | Idempotency today | Disposition |
|---|---|---|---|---|---|---|---|---|
| Cash payment | `Pos::TenderCash` | Working row + presented/change; applied/change re-settled at complete | Yes — destroy | Upsert — re-call `TenderCash` | Destroy | Txn `lock!` + `lock_version` | None on add; complete lease | **7A** |
| Cash refund | `Pos::AddRefundTender` (cash) | Working refund row | Yes — destroy | Upsert — re-call for cash | Destroy | Same | None on add; complete lease | **7A** |
| Card payment | `Pos::AddTender` | Working row + optional reference; **no processor post in ShelfSense** | Yes — destroy | None (append) | Destroy | Same | None on add; complete lease | **7A** — remove working row, perform any required **external** reauthorization outside/currently supported by ShelfSense, then record replacement authorization/reference |
| Card refund | `Pos::AddRefundTender` | Working refund + optional reference | Yes — destroy | None | Destroy | Same | None on add; complete lease | **7A** (same family) |
| Check payment | `Pos::AddTender` | Working row + optional reference | Yes — destroy | None (append); replace via 7A orchestration | Destroy | Same | None on add; complete lease | **7A** |
| Check refund | `Pos::AddRefundTender` | Same if type allows refund | Yes if row exists | None | Destroy | Same | None on add; complete lease | **N/A** by default seed (`allows_refund: false`); **7A** when enabled |
| Other payment | `Pos::AddTender` | Working row + reference per type policy | Yes — destroy | None (append); configured manual-reference types via 7A replace | Destroy | Same | None on add; complete lease | **7A** |
| Other refund | `Pos::AddRefundTender` (if `allows_refund`) | Working refund | Yes — destroy | None | Destroy | Same | None on add; complete lease | **7A** when enabled |
| Gift-card payment | `Pos::AddStoredValueTender` | Redeem at `CompleteStoredValue#post_tender!` | Yes while working — destroy | None | Destroy (**not** SV reverse) | Txn lock; account lock at post | Nested tender key at post | **7A inspect-only** → **7B** mutate |
| Store-credit payment | same (`store_credit`) | Redeem at complete | Yes — destroy | None | Destroy | Same | Nested tender key | **7A inspect-only** → **7B** mutate |
| Trade-credit payment | same (`trade_credit`) | Redeem at complete | Yes — destroy | None | Destroy | Same | Nested tender key | **7A inspect-only** → **7B** mutate |
| Gift-card refund (existing) | `Pos::AddStoredValueRefundTender` | Credit at complete | Yes — destroy | None | Destroy | Txn + capacity; account lock at post | Nested tender key | **7A inspect-only** → **7B** mutate |
| Gift-card refund (new card) | same (`new_gift_card`) | Provision + credit at complete | Yes — destroy | None | Destroy | Same + program checks | Nested tender key | **7A inspect-only** → **7B** mutate |
| Store-credit refund | same | Ensure account + credit at complete | Yes — destroy | None | Destroy | Same | Nested tender key | **7A inspect-only** → **7B** mutate |
| Trade-credit refund | same (original-account constrained) | Credit at complete | Yes — destroy | None | Destroy | Same | Nested tender key | **7A inspect-only** → **7B** mutate |
| Gift-card issuance (activate/reload) | `AddStoredValueIssuance` / `RemoveStoredValueIssuance` | Activate/reload at `post_issuance!`; **clears tenders** on add/remove | Yes — remove issuance | None today | Destroy issuance (not SV reverse while working) | Txn lock; card/account lock at post | Nested issuance key at post | **7B** (see issuance-with-tenders) |

---

## Working-tender persistence decision

**Lock:** Working correction uses **audited destroy + add inside one database transaction under the transaction lock**, not a durable supersession relationship on `pos_tenders`.

```text
transaction lock
  ├── validate complete replacement
  ├── prepare removal/replacement audit context
  ├── destroy original
  ├── add replacement
  ├── write audit in the same DB transaction as the successful mutation
  └── commit everything together
```

The audit event must **not** survive a rolled-back replacement. A successful financial mutation must **not** commit without its required audit record.

**Rationale:** No supersession columns exist; destroy is the current working model; inventing supersession schema is out of Slice 7 scope.

### `Pos::ReplaceTender` (7A ordinary / 7B SV)

Authorize → lock txn → verify working membership → validate replacement → destroy original → add replacement → recalc settlement → commit; on failure leave original unchanged. Cash may keep upsert semantics inside the orchestration where behaviorally equivalent.

Card: remove the working row, perform any required **external** reauthorization outside/currently supported by ShelfSense, then record the replacement authorization/reference. ShelfSense does **not** currently operate an integrated card authorization-reversal service for working tenders.

---

## Mutation idempotency (normative)

Recording an idempotency key only in an audit event does **not** make a mutation idempotent. Do not add `idempotency_key` parameters that are merely logged.

| Mutation | Required 7A/7B behavior |
|---|---|
| Remove working tender | Same key returns the original successful outcome |
| Replace working tender | Same key returns the same replacement, not another tender |
| Return to Sale | Retry does not create duplicate audit events or partially repeat clearing |
| Quick Customer create | Retry does not create a second customer |
| Issuance replacement | Retry returns the same resulting issuance |

**Chosen mechanism:** Reuse existing **`Pos::OperationLease` / `PosOperation`** infrastructure with **distinct `command_type` values** for working mutations (the lease already accepts `command_type`; completion uses `pos.complete_transaction`, post-void uses `pos.post_void_transaction`). Register-scoped `source_id`, canonical payload hash, in-flight / completed / failed replay rules apply.

**Quick Customer / `Customers::Create`:** reuse the same class of idempotency pattern used elsewhere for domain commands (e.g. `Idempotency::OperationService` as in `StoredValue::Post`), scoped so a double-submit or lost response cannot create two customers.

Optimistic `lock_version` remains required concurrency protection; it is **not** a substitute for replay-safe idempotency after a lost successful response.

---

## Issuance replacement when tenders exist (normative)

Code fact: adding or removing an issuance **clears all working tenders**.

**Locked behavior:**

```text
No tenders applied
  → edit/remove issuance directly (7B)

Tenders applied
  → explain that changing issuance changes the transaction total
  → confirm Return to Sale / clear all tenders (O17-class)
  → replace issuance and clear tenders atomically
  → or change nothing
```

Do **not** allow an issuance editor to silently clear tenders.

**Required tests (7B):** issuance edit with no tenders; with ordinary tenders; with stored-value tenders; failure after tender clearing begins; concurrent issuance/tender change; idempotent retry.

---

## Return to Sale during staged delivery (normative)

| Stage | Behavior |
|---|---|
| **7A** | Ordinary tenders only → clear atomically. **Any stored-value tender present** → refuse Return to Sale with an explanation that SV correction lands in 7B. Do not expose underlying SV destroy through Return to Sale before 7B. |
| **7B** | All supported working tenders (including SV) can be cleared atomically, or change nothing if any cannot be reversed under policy. |

Not synonymous with Cancel Transaction.

---

## Capability vs UI law (7A)

| Layer | SV / issuance working rows |
|---|---|
| **Code today** | Destroy paths already remove them without ledger reverse |
| **7A product / UI** | Select and inspect allowed; **Edit / Remove / Return-to-Sale clearing unavailable** until 7B |
| **7B** | Idempotent working removal, atomic replacement, capping, completion revalidation, issuance edit with tender-clear confirm |

---

## Stored-value add vs completion (code inventory)

Current code does **not** auto-cap. Overview product lock for 7B remains **auto-apply with prominent feedback**; that is a deliberate change from today’s reject-on-over-balance.

| Question | Current code answer | 7B disposition |
|---|---|---|
| Request exceeds available payment balance | **Rejects** (`stored-value balance is insufficient`) — no cap | Change to **auto-cap** to `min(requested, available, remaining due)` with prominent feedback; persist only applied amount |
| Request exceeds remaining transaction balance | **Rejects** (`amount is greater than remaining due`) | **Keep reject** (do not apply above remainder) |
| Refund exceeds account/program capacity | Detected at **add** (`assert_gift_card_credit_within_maximum!` / capacity remaining) and again at **complete** (`StoredValueRefundCapacity.assert_working_allocation!`) | Keep dual assert; fail recoverably |
| Balance changes after working tender is added | Completion **re-checks** balance; raises if insufficient — **does not** silently shrink the tender | Keep recoverable failure; no silent shrink |
| Account becomes suspended/closed | Completion `resolve_tender_account!` requires `account.active?`; raises if not available | Keep recoverable failure |
| Completion fails after some SV operations post | `CompleteStoredValue` runs inside `CompleteTransaction`’s DB transaction; raise aborts completion (txn stays working). Nested `StoredValue::Post` has its own idempotency — **7B must test** mid-completion failure / sticky nested ops | Require enclosing rollback of POS completion; verify nested replay safety in tests |
| Multiple SV tenders on one account | **Rejected at add** for payments (`duplicate_account?`) | Keep one payment tender per account; post locks accounts in **sorted id** order |
| New-card refund provisioning fails | Raises in `provision_refund_card!`; aborts `CompleteStoredValue` | Whole completion fails; no partial completed txn |
| Stored-value posting replay | Nested key `Pos::Support.nested_stored_value_idempotency_key(completion_operation_id, "tender"\|"issuance", id)`; skip if `stored_value_operation_id` already set | Retain nested keys; completion lease remains outer authority |

---

## Quick Customer reuse checklist

Product decision unchanged: Quick Customer remains **7B.2** (child of shared Register Customer Lookup; Sale + customer-required SV/refund; `open-customer-lookup`; **F2 remains Card**).

| Item | Verdict |
|---|---|
| Authoritative create | **Gap:** admin only — `Admin::CustomersController#create` + `create_and_audit!`. **No** `Customers::Create` service. |
| Reusable now | `Customers::NormalizeContact`, `SuggestDuplicates`, `Search`, `Pos::AttachCustomer` |
| Permission (locked) | Add **`customers.create`** for Quick Customer. Keep **`customers.manage`** for full customer management. Inquiry: `customers.view` / existing POS authority. Attach existing: existing POS attach authority. |
| Service authorization | `Customers::Create` is presentation-neutral. **Admin caller** authorizes `customers.manage`. **Register Quick Customer caller** authorizes `customers.create`. |
| Fields | `display_name` required; email/phone optional on bare `Customer`. Email ∨ phone as **contextual** Quick Customer / credit rule OK without changing base model. |
| Canonical / merge | ADR-023; create yields canonical; duplicates warn + acknowledge; no auto-merge. |
| Idempotency | **Required** on create (see mutation idempotency); none today. |

**Implementation boundary:** 7B.2 extracts `Customers::Create` and has admin + Quick Customer call it. If extraction cannot land without duplicating domain logic, stop with a documented blocker — do **not** invent a Register-only create path. Do **not** grant ordinary cashiers `customers.manage` solely to enable Quick Customer.

---

## Notes for later packets

| Topic | Owner |
|---|---|
| Tender Review selection; ordinary remove/replace; Return to Sale (ordinary-only) | **7A** |
| Nested customer lookup, attach, change-customer guards | **7B.1** |
| Quick Customer + `Customers::Create` + `customers.create` seed | **7B.2** |
| SV capping (auto); idempotent working SV remove/replace; issuance edit with tender-clear confirm; completion revalidation | **7B.3** |
| Activated / completed issuance or tender edit from workspace | **Out** — recovery / post-void only |
| Keyboard dispatcher | **7C** |

## Packet readiness

| Packet | Inventory gate |
|---|---|
| 7A | **Met** |
| 7B | **Met** |
| 7C | Uses 7.0 contract; no further inventory gate |
