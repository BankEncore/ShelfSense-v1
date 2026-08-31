# Slice 7B — Stored value, issuance, and Quick Customer

Status: **Complete** on `register-workspace-consolidation` ([#94](https://github.com/BankEncore/ShelfSense-v1/issues/94) / PRs [#118](https://github.com/BankEncore/ShelfSense-v1/pull/118)–[#121](https://github.com/BankEncore/ShelfSense-v1/pull/121)). Inventory gate was met ([slice7-tender-lifecycle-inventory.md](slice7-tender-lifecycle-inventory.md)). Evidence: [slice7b-manual-verification.md](slice7b-manual-verification.md).

Authority: [plan.md](plan.md), [implementation-plan.md](implementation-plan.md), [slice7-overview.md](slice7-overview.md), [slice7-tender-lifecycle-inventory.md](slice7-tender-lifecycle-inventory.md), [slice7-keyboard-contract.md](slice7-keyboard-contract.md), [slice7a-tender-review-plan.md](slice7a-tender-review-plan.md), [slice5a-lookup-overlays-plan.md](slice5a-lookup-overlays-plan.md), [slice5d-tender-issuance-plan.md](slice5d-tender-issuance-plan.md), [textual-wireframes.md](textual-wireframes.md) P10 / O14–O17, [user-stories.md](user-stories.md), [routing-and-authority.md](routing-and-authority.md).

Issue: [#94](https://github.com/BankEncore/ShelfSense-v1/issues/94).

## Outcome

Extend Tender Review and customer-required Register flows: nested Customer Lookup for store/trade credit and refund destinations; Quick Customer as a child of that lookup; auto-capped stored-value payment add with lease replay; idempotent working SV remove/replace and Return to Sale including SV; issuance edit/remove with tender-clear confirmation; completion revalidation that recovers into Completion Failed / Tender Review without silent shrink or auto-clear.

## Boundary statement

> Slice 7B adds nested customer-required lookup and Quick Customer (identity only), lease-backed auto-capped stored-value tender add, idempotent working stored-value remove/replace and Return to Sale including stored-value, issuance mutation with explicit tender-clear confirmation, and recoverable completion-time stored-value revalidation. Working correction remains audited destroy plus add under one transaction lock with OperationLease — not a stored-value ledger reversal and not a supersession schema on `pos_tenders`. Quick Customer does not provision trade credit, grant balances, or create redeemable accounts. No temporary global shortcuts; runtime keys remain Phase 6.7 (plus Slice 5D `+` → O11) until 7C.

## Scope

| In | Out |
|---|---|
| Nested Customer Lookup from customer-required SV/refund paths (`open-customer-lookup`) | Second customer-maintenance UI |
| Refuse change/detach while dependent working SV present | Combining customer reassignment with tender clear in 7B.1 |
| Quick Customer child overlay; `customers.create`; `Customers::Create` | Granting cashiers `customers.manage` solely for Quick Customer |
| Auto-cap SV payment add + lease; Cap `Result`; refund-add lease | Silent complete-time shrink of tenders |
| Lift 7A SV refuse on remove / replace / Return to Sale | Temporary document-level key handlers (7C) |
| Issuance edit/remove with O17-class confirm when tenders exist | Merging issuances into merchandise lines |
| Completion Failed / Tender Review recovery; keep working tenders | Working-tender `StoredValue::Reverse` |
| Masked card data only in audit / facts / envelopes | Field-edit of externally authorized card tenders |
| F2 remains Card Tender | Activating / editing completed posted SV from workspace |

## Locked decisions

| Decision | Choice |
|---|---|
| Delivery | **Four merges** under [#94](https://github.com/BankEncore/ShelfSense-v1/issues/94): packet → 7B.1 → 7B.2 → 7B.3 (+ closeout) |
| Working correction | Audited **destroy + add** under txn lock + `Pos::OperationLease`; **not** `StoredValue::Reverse` while working |
| Customer same attach | Idempotent when already attached to that customer |
| Customer change/detach | **Refuse** while any dependent working SV tender/refund destination exists; cashier must remove the dependent tender or Return to Sale first |
| Customer dependency | (1) store-credit or trade-credit tender whose account belongs to the customer; (2) pending customer-store-credit refund; (3) another destination explicitly bound to the customer. A gift-card issuance merely associated with the transaction customer is **not** automatically dependent unless its destination/account contract requires that customer |
| Quick Customer | Creates and attaches a canonical customer identity only. Does **not** open trade credit, grant stored value, or create a redeemable balance. After attachment, the originating flow must re-resolve account eligibility and explain when no eligible account exists |
| Contact rule | Email ∨ phone is **contextual** UI/service validation for the chosen flow — not a global `Customer` model requirement |
| SV payment add over-balance | Reject `requested > remaining due`. Else apply `min(requested, available)`. Refuse when applied is zero. Persist only `applied_cents` on `PosTender`. Requested/available may appear in operation result and audit context; they are not additional financial facts |
| Cap Result | `Data.define(:transaction, :tender, :requested_cents, :available_cents, :applied_cents, :remaining_due_cents, :capped, :replayed)` |
| One payment tender per account | Keep; on replace, duplicate-account detection **excludes** the original tender |
| SV add lease | `pos.add_working_stored_value_tender` under `Pos::OperationLease`. Payload: requested amount, tender identity (when known), transaction `lock_version`, destination mode, safe account/card identity — **never** a full card number |
| SV refund add lease | Same replay class: `pos.add_working_stored_value_refund_tender` (or shared pattern) |
| Issuance with tenders | Confirm against current basis → lock + `lock_version` → validate full proposed issuance **before** destroy/clear → clear tenders + mutate issuance + audit + complete lease in one DB transaction; rollback everything on failure |
| Sensitive data | Audit snapshots, operation facts, validation feedback, and idempotency envelopes must **never** contain a full pending gift-card number. Use masked number, digest, program, authority, and last four only |
| Completion failure | If completion-time stored-value revalidation fails: retain the working transaction and all working tenders; enter Completion Failed / Tender Review; select the affected tender where identifiable; provide Remove/Edit or customer/account correction. Do **not** automatically clear tenders or Return to Sale |
| Return to Sale | Lift 7A SV refuse; clear all supported working tenders atomically or change nothing |
| Keyboard (7B) | Buttons, accessible controls, controller actions, semantic events only. **No** temporary global shortcuts. F2 remains Card |
| Overlays | Customer Lookup / Quick Customer / O15–O17 on shared 5A blocking-overlay lifecycle |
| Wireframe O16 SV copy | Working remove does **not** restore ledger value; consequence text must say so |

### PR split

| Branch / PR | Scope |
|---|---|
| `94-slice7b-packet` | This packet + manual stub + routing docs (docs only) |
| `94-slice7b1-customer-nesting` | Nested customer-required lookup/attach; refuse change/detach while dependent SV present |
| `94-slice7b2-quick-customer` | Quick Customer child; seed `customers.create`; extract `Customers::Create` (admin + Register); idempotent create |
| `94-slice7b3-stored-value-correction` | Lease-backed auto-cap add (+ refund lease); lift SV remove/replace/Return-to-Sale; O15/O16 SV copy; issuance edit + tender-clear confirm; completion recovery tests |

Each branches from the updated integration branch after its predecessor merges.

---

## 7B.1 — Nested customer-required flows

**Current:** `Pos::AttachCustomer` / `Pos::DetachCustomer`, `#pos_customer_overlay`, `Customers::Search` operational mode. No dependency guards.

**Deliver:**

- Open Customer Lookup from customer-required store-credit / trade-credit / refund-destination paths via semantic `open-customer-lookup` and a visible control.
- Same-customer attach remains idempotent.
- Change or detach is **refused** while any working stored-value tender or refund destination depends on that customer (dependency definition above). Message must tell the cashier to remove the dependent tender or Return to Sale first.
- Nested overlay lifecycle per Slice 5A (Escape closes child then parent).

**Tests:** required-customer payment/refund blocks without customer; attach enables continue; change/detach with dependent SV refused; gift-card issuance association alone does not block detach unless contractually dependent.

No Quick Customer create in 7B.1.

---

## 7B.2 — Quick Customer

**Current gap:** admin-only create under `customers.manage`; no `Customers::Create`; no `customers.create` permission.

**Deliver:**

- Extract presentation-neutral `Customers::Create` (reuse `NormalizeContact` / `SuggestDuplicates` patterns).
- Seed `customers.create`. Admin create authorizes `customers.manage`. Register Quick Customer authorizes `customers.create`.
- Idempotent create (`Idempotency::OperationService` or equivalent scoped pattern) so retry does not create a second customer.
- Quick Customer is a **child** of Customer Lookup (not a second maintenance UI). Fields: `display_name` required; email/phone optional; contextual email∨phone for the originating credit flow only.
- After create+attach: originating flow re-resolves account eligibility and explains when no eligible payment account exists.
- Does **not** open trade credit, grant a balance, or create a redeemable account.

**Extraction boundary:** If extraction would duplicate domain logic, stop with a documented blocker — no Register-only create path; do not grant cashiers `customers.manage` solely for this.

---

## 7B.3 — SV / issuance correction

### Lift 7A gates

Lift SV refuse in:

- `Pos::RemoveWorkingTender`
- `Pos::ReplaceTender` (extend for SV; keep card refuse — remove + external reauth)
- `Pos::ReturnToSaleClearTenders`
- `WorkspacePresenter#tender_affordances`
- O15 / O16 / O17 copy and enablement

Working SV remove does **not** restore ledger value (nothing posted yet). O16 copy must say so.

### Lease-backed auto-cap add

Change `Pos::AddStoredValueTender` from reject-on-insufficient-balance to:

```text
authorize → OperationLease begin (pos.add_working_stored_value_tender)
  → lock working transaction
  → reject if requested > remaining due
  → resolve account; refuse duplicate account (exclude original on replace)
  → applied = min(requested, available)
  → refuse if applied == 0
  → persist tender with amount_cents = applied only
  → audit + complete lease (requested/available in context, not as financial facts)
  → return Cap Result (capped / replayed flags)
```

Workspace shows prominent feedback when `capped`. Lost-response retry must replay the Cap Result, not raise “account already on transaction.”

Apply the same lease/replay class to `Pos::AddStoredValueRefundTender`.

### Atomic SV replace

Authorize → lease → lock → verify working membership → validate full replacement (cap rules; exclude original from duplicate-account check) → destroy original → add replacement → audit → complete lease. On failure, original unchanged.

### Issuance edit / remove when tenders exist

```text
No tenders applied
  → edit/remove issuance directly (lease-backed)

Tenders applied
  → explain that changing issuance changes the transaction total
  → confirm clear all tenders (O17-class) against current basis
  → lock + lock_version
  → validate full proposed issuance BEFORE destroy/clear
  → clear tenders + mutate issuance + audit + complete lease in one DB transaction
  → or change nothing
```

Stop silent `clear_working_tenders!` on add/remove without confirmation when tenders exist. Never put a full pending gift-card number in audit, facts, validation feedback, or idempotency envelopes.

### Completion recovery

Keep `Pos::CompleteStoredValue` balance/capacity/account revalidation (no silent shrink). On failure:

- Retain working transaction and all working tenders
- Enter Completion Failed / Tender Review
- Select the affected tender where identifiable
- Offer Remove/Edit or customer/account correction
- Do **not** auto-clear tenders or auto Return to Sale

**Required tests:**

- Balance reduced below applied amount
- Account suspended/closed
- Customer no longer matches the account
- Refund capacity reduced
- Failure after an earlier nested SV post attempted
- Retry after rollback produces exactly one posted operation per final tender/issuance
- Issuance edit with no tenders; with ordinary tenders; with SV tenders; failure after tender clearing begins; concurrent change; idempotent retry
- Cap: over-balance caps; over remaining due rejects; applied zero refuses; lease replay restores capped Result
- Replace same-account allowed (excludes original)

---

## Idempotency command types

| Mutation | Example `command_type` |
|---|---|
| Add working SV payment tender | `pos.add_working_stored_value_tender` |
| Add working SV refund tender | `pos.add_working_stored_value_refund_tender` |
| Remove working tender (incl. SV) | `pos.remove_working_tender` (reuse) |
| Replace working tender (incl. SV) | `pos.replace_working_tender` (reuse / extend) |
| Return to Sale clear (incl. SV) | `pos.return_to_sale_clear_tenders` (reuse) |
| Replace / mutate working issuance | `pos.replace_working_issuance` (or sibling types as needed) |
| Quick Customer create | domain idempotency key via `Idempotency::OperationService` (or equivalent) |

Register-scoped `source_id`, canonical payload hash, in-flight / completed / failed replay per `Pos::OperationLease` where that infrastructure applies. Optimistic `lock_version` remains required and is not a substitute for lost-response replay.

## Authorization

Existing POS transact / cashier / active-context rules. New permission: **`customers.create`** for Register Quick Customer only. Admin create continues under **`customers.manage`**. Server must enforce refuse-on-dependent-customer, SV gates, and masked-card redaction even if the client is crafted.

## Testing (implementation)

Cover service, request, and system boundaries as applicable for 7B.1–7B.3 contracts above. Preserve completion, custody, auth, concurrency, and cross-store coverage. Do not add a JavaScript unit test framework.

## Assert no change to

Reporting periods; sessions; completed transactions; posted tenders; posted stored-value ledger (except through existing completion/post-void paths); cash operations; receipt numbering; Phase 6.7 runtime keys beyond existing 5D `+` exception; F2 Card binding.

## Explicit non-goals

Second customer-maintenance UI; merging gift-card issuances into merchandise lines; temporary global shortcuts; working-tender ledger reverse; silent complete-time shrink; auto-provisioning credit/accounts via Quick Customer; granting `customers.manage` to ordinary cashiers for Quick Customer; combining customer reassignment with tender clearing in 7B.1.

## Full-lock criterion

Met when this packet landed on `register-workspace-consolidation` ([#118](https://github.com/BankEncore/ShelfSense-v1/pull/118)). Implementation landed as [#119](https://github.com/BankEncore/ShelfSense-v1/pull/119) (7B.1), [#120](https://github.com/BankEncore/ShelfSense-v1/pull/120) (7B.2), [#121](https://github.com/BankEncore/ShelfSense-v1/pull/121) (7B.3).
