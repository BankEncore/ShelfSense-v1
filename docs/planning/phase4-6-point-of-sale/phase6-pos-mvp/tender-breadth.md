# Phase 6 Slice 6.2 — Tender breadth

**Status:** Implemented (6.2A–E).

**Authority:** One settlement redesign for Cash, external Card, Check, and admin-created Other on the Phase 5/6.1 register. Envelope v2 tender keys: [mvp-contract.md](mvp-contract.md). Expected Cash and all-Cash Phase 5 equivalence remain [phase5-plan.md](../phase5-cash-register/phase5-plan.md). 6.1 Cash envelopes stay the existing Cash tender representation.

Companions: [phase6-plan.md](phase6-plan.md), [register-workspace.md](../phase5-cash-register/register-workspace.md), [close-z-screens.md](../phase5-cash-register/close-z-screens.md), [phase4-schema.md](../phase4-point-of-sale/phase4-schema.md), [returns.md](returns.md).

Draft [tender.md](../../../drafts/specifications/pos/tender.md) is vocabulary. This document is implementation authority for the MVP subset.

**Do not expose Card / Check / Other on the register until Session/Z can report those categories.** Headless mixed settlement may exist earlier; cashier UI is last (6.2E).

### Actually locked

```text
sale-only / payment-only (no refund columns or direction)
four behavioral categories: cash | card | check | other
seed only protected Cash, Card, Check
admins create genuine Other identities
cashier never free-types a tender type
external Card is a recording (no processor)
exact settlement: SUM(payment amount_cents) = signed_net_cents when signed_net > 0
zero-net (6.4C): signed_net = 0 → no tenders; completion allowed
signed_net < 0 refund-only from 6.5 ([returns.md](returns.md))
at most one Cash payment (partial unique index)
TenderCash replaces Cash in place; remaining due excludes existing Cash
tender_number dense 1..N; tender_name snapshot
v2 command drops amount_presented_cents
every tender mutation advances transaction lock_version
new completions emit 6.2 tender keys; verify! still accepts 6.1 v2 envelopes
expected Cash formula unchanged
Phase 5 all-Cash path stays green
```

---

## 1. Objective

Allow the register to settle ordinary sales with mixed tenders:

```text
Cash (presented / applied / change)
external Card (cashier records after processing outside ShelfSense)
Check
admin-created Other
```

Stored Value, integrated Card processing, and refund tenders are out of **6.2**. Refunds, `allows_refund`, Cash refund Core, and direction-aware remaining due are [returns.md](returns.md) (6.5A Core; 6.5B cashier refund workspace). Until Cash refunds exist, expected Cash stays the Phase 5 formula.

---

## 2. Schema (6.2A)

### 2.1 `tender_types`

UUIDv7 (`create_uuid_table`). Centrally mastered reference data.

| Column | Notes |
|---|---|
| `code` | unique normalized machine code |
| `name` | display name (live config; not historical authority) |
| `behavioral_category` | `cash \| card \| check \| other` |
| `active` | cashier-selectable when active |
| `external_reference_policy` | `omitted \| optional \| required` |
| `system_protected` | true for seeded Cash/Card/Check |
| `lock_version` | optimistic locking |

Do **not** add `allows_payment` in 6.2. 6.5 added `allows_refund` ([returns.md](returns.md) §20). Cash is always refundable and read-only in admin. Card/Check/Other are editable; new Other defaults `false`. Workspace refund F2 uses `TenderType.refund_selectable`.

Seed only:

```text
cash   Cash            category cash   reference omitted    protected
card   External Card   category card   reference optional   protected
check  Check           category check  reference optional   protected
```

Do **not** seed `purchase_order`, `campus_charge`, or `voucher`. Admins create Other identities (`behavioral_category` forced to `other`). Protected rows cannot be deleted or recategorized. Cash cannot be deactivated.

### 2.2 `pos_tenders`

Add owning-slice columns:

| Column | Notes |
|---|---|
| `tender_type_id` | FK → `tender_types`, `on_delete: :restrict` |
| `tender_number` | integer `>= 1`, unique per transaction |
| `tender_name` | display-name snapshot |
| `behavioral_category` | category snapshot (`cash \| card \| check \| other`) |
| `external_reference` | nullable text |
| `tender_type` | keep as identity **code snapshot**; drop the `cash`-only CHECK |
| `amount_presented_cents` / `change_cents` | nullable; required iff `behavioral_category = cash` |
| `direction` | CHECK stays `payment` only |

Cash CHECK: `presented = applied + change`. Non-cash: both presented and change NULL.

**One Cash payment:** partial unique index on `pos_transaction_id` `WHERE behavioral_category = 'cash' AND direction = 'payment'`. The `direction` predicate states the 6.2 invariant so 6.5 can add a Cash refund without dropping this index. It is not a refund feature.

### 2.3 Explicit Core backfill

In the same migration, before NOT NULL:

```text
existing pos_tenders (all current rows are Cash payments)
  → tender_type_id = seeded cash
  → behavioral_category = cash
  → tender_name = Cash
  → tender_number = 1
```

Do not rewrite stored 6.1 envelopes.

Update [phase4-schema.md](../phase4-point-of-sale/phase4-schema.md) in the same PR as the migration.

---

## 3. Envelope and command

### 3.1 New completions (6.2A+)

Every **new** `schema_version: 2` completion emits 6.2 tender keys. Unused keys are omitted.

```text
tender_id
tender_number
tender_type                 # identity code snapshot
tender_name                 # display-name snapshot
behavioral_category
direction
amount_cents
amount_presented_cents      # Cash payment only
change_cents                # Cash payment only
external_reference          # omit when not captured
```

Order tenders by `tender_number`. Do not use `created_at` or UUID order.

Receipt, reprint, history, and operator completed views use `tender_name`. Later admin renames must not rewrite stored snapshots. Customer print omits `external_reference` ([mvp-contract.md](mvp-contract.md) §14).

### 3.2 Historical v2 compatibility

6.1 schema-2 envelopes legitimately lack `behavioral_category`, `tender_name`, and `tender_number`. [`CompletedTransactionFacts#verify!`](../../../../app/services/pos/completed_transaction_facts.rb) must keep accepting them.

Require the 6.2 tender shape only when the envelope uses it: if any tender has a 6.2 key, every tender must be 6.2-shaped. Do not make `behavioral_category` mandatory for all schema 2.

Keep golden fixtures `completed_pos_operation_v2/cash_sale` and `used_unit` as historical. Add new fixtures for 6.2-shaped tenders.

### 3.3 Completion command (6.2B)

Drop `amount_presented_cents` from `CompleteTransaction` / `FindCompletionOperation`. Presented lives on the Cash tender row.

```text
transaction_id
operation_id
expected_lock_version
expected_total_cents
```

Keep the v1 command golden fixture as historical. Add a v2 command fixture without presented.

---

## 4. Settlement (6.2B)

Headless mixed settlement. **Workspace stays Cash-only until 6.2E.**

```text
SUM(payment amount_cents) = signed_net_cents
signed_net_cents > 0
payment tenders only
```

`signed_net_cents = total_cents` on sale-only transactions.

**6.4C amendment** ([controlled-actions.md](controlled-actions.md)): a 100% discount or $0 override may produce `signed_net_cents = 0`. Then **no tender is permitted** and completion is allowed. Do not record a fake `Cash $0.00` tender. `signed_net_cents < 0` is [returns.md](returns.md). Positive-total Phase 5/6.2 path is unchanged.

### 4.1 Remaining due

```text
remaining_due = signed_net_cents − SUM(payment amount_cents)
```

**Replacement remaining due for Cash excludes the existing Cash row:**

```text
remaining_for_cash = signed_net_cents − SUM(other payment amount_cents)
```

### 4.2 `TenderCash`

- Replace the existing Cash row **in place** (same `id` / `tender_number`); do not destroy Card/Check/Other.
- If no Cash row exists, insert one with the next `tender_number`.
- Snapshot `tender_name` / `tender_type` / `behavioral_category` from the Cash identity at replace/add time.
- All-Cash (no other payments): `presented < total` is still an error (Phase 5).
- Other payments present and `presented >= remaining_for_cash`: `applied = remaining_for_cash`, `change = presented − applied`.
- Other payments present and `presented < remaining_for_cash`: partial Cash, `applied = presented`, `change = 0`.
- Always increment transaction `lock_version` (including presented-only replace).

### 4.3 `AddTender`

Card/Check/Other only. Reject Cash identity (use `TenderCash`). Reject inactive type, over-remaining, blank required reference. Assign next `tender_number`. Snapshot name/code/category. Increment `lock_version`.

### 4.4 Remove / abandon

`RemoveWorkingTender` removes one working tender, dense-renumbers `1..N`, increments `lock_version` when a row was removed.

`AbandonTender` still clears **all** working tenders (Return to sale). Increment `lock_version` only when a tender was removed. Basket mutation and `CancelTransaction` still clear all working tenders.

### 4.5 Completion freeze

Do not re-read live `tender_types.name` at complete. After line freeze and `refresh_totals!`:

- If a Cash payment exists: remaining after non-cash must be `>= 0` and `presented >= remaining`; set Cash `applied = remaining`, `change = presented − applied` (Cash absorbs tax-freeze cents, same as Phase 5).
- If no Cash payment: `SUM(non-cash applied) = total_cents`.

`FindCompletionOperation` restores a token when the working transaction has **exact settlement**, not merely a Cash row.

Inventory posting, receipt allocation, and tax stay in `CompleteTransaction`. Do not change `CloseSession` expected-Cash math.

---

## 5. Admin (6.2C)

Permission `pos.manage_tender_types` (global), same pattern as `inventory.manage_adjustment_reasons`. Register stays `pos.transact`.

- Index/edit system Cash/Card/Check: name, active (not Cash), reference policy.
- Create/edit/deactivate Other: category fixed `other`; code unique and immutable after create.
- Cannot create a second Cash/Card/Check or recategorize.
- Audit material changes.

Register does not list Other until at least one active Other identity exists **and** 6.2E has shipped.

---

## 6. Session / Z (6.2D)

Before cashier non-Cash.

Live [`SessionTotals`](../../../../app/services/pos/session_totals.rb) / [`PeriodTotals`](../../../../app/services/pos/period_totals.rb) add Card / Check / Other **payment** sums. Expected Cash is unchanged (`float + SUM(cash payment amount_cents)`).

Additive nullable period columns, written on **new** finalize only:

```text
finalized_card_payment_cents
finalized_check_payment_cents
finalized_other_payment_cents
```

Do **not** add these to the existing `closed_at_matches_status` pairing (already-finalized periods stay valid with NULL). NULL on a finalized Z means “not captured” (pre-6.2). New finalize writes `0` when the category had no tenders.

Closed-session and Z views show the breakdown. Blind count still exposes no totals. All-Cash Session/Z figures remain Phase 5-equivalent.

---

## 7. Workspace (6.2E)

Only after 6.2D. Extend [register-workspace.md](../phase5-cash-register/register-workspace.md); do not invent a new chrome.

**6.7 supersedes F2 cycling and the `+` default path** ([pos-workflow.md](pos-workflow.md) §12): F1 Cash / F2 Card / F3 Check / F4 Other; `+` is Cash with remaining prefilled.

Until 6.7 ships, 6.2E remains:

- `+` still enters TENDER; default identity **Cash** (Phase 5 keyboard: amount → Enter → `TenderCash` → auto-complete when Cash closes the sale).
- Cycle among **active** types (F2). Other appears only when an active Other identity exists.
- Cashier identities are one JSON array (`id`, `name`, `category`, `reference_policy`), not delimiter-separated strings.
- Reference field: `omitted` hidden; `optional` labeled `Reference (optional)`; `required` labeled `Reference (required)`. The server remains authoritative.
- Remaining due and working tender list (by `tender_number`, snapshot names) in `pos_totals`.
- Enter adds the selected tender. Remaining `> 0` stays TENDER. Remaining `= 0` → completion-pending + existing auto-complete.
- Escape before any tender: SALE_ENTRY. After tenders: Return to sale is still `AbandonTender`.
- Completion command no longer posts `amount_presented_cents`.
- Controllers/Stimulus orchestrate services only.

Receipt / completed screen / print: list tenders in `tender_number` order with `tender_name`. Customer print omits `external_reference`. Operator completed view may show it.

**6.2E merge gate:** ordinary all-Cash behavior remains Phase 5-equivalent (one Cash tender, presented/change, expected Cash, `finalized_cash_payment_cents`).

---

## 8. Authorization, audit, retry

Register: `pos.transact` at the current store; Session cashier for basket/tender/complete.

Audit existing completion events. Tender-type admin uses dedicated actions. Never put payment credentials in audit.

Idempotent completion retries must still produce only one completed set of tenders. After presented leaves the command hash, a presented change with an unchanged `lock_version` is an integrity hole — tender mutations must bump `lock_version`.

---

## 9. Acceptance

1. Existing Cash `pos_tenders` are backfilled with `tender_type_id`, `behavioral_category`, `tender_name`, `tender_number`.
2. A second Cash payment on the same transaction fails at the database.
3. `verify!` still passes historical 6.1 v2 fixtures.
4. New all-Cash completions include `tender_number`, `tender_name`, `behavioral_category`.
5. `TenderCash` remaining due ignores the existing Cash row; presented-only replace bumps `lock_version`.
6. Headless mixed Card+Cash completes with exact settlement; Card does not inflate expected Cash.
7. Admins can create Other; cannot recategorize Cash.
8. Session/Z shows Card/Check/Other payment totals on live previews and new finalize; already-finalized Z columns stay NULL / immutable.
9. Cashier Card/Check/Other exists only after Session/Z can report them.
10. Phase 5 all-Cash scan → tender → complete remains green.

---

## 10. Out of Slice 6.2

```text
refund tenders and refund columns/flags     # 6.5 [returns.md](returns.md)
signed-net = 0 / no-tender completion       # 6.4C
Stored Value / gift cards / store credit
integrated Card processing
original-tender refund policy
paid-in / paid-out
drawer / denomination count
customer display of mixed tender
6.3 history search
seeded dummy Other identities
new perform/approve keys
changing CloseSession expected-Cash formula
```

---

## 11. Rollout

Already-initialized databases need `./dev/rails-docker bin/rails shelfsense:seed_permissions` so `pos.manage_tender_types` exists and is granted to `system_administrator`. `db:migrate` alone does not add the permission or grant.

Schema rollback of `20260818020000_add_tender_types_and_pos_tender_snapshots` is only supported **before non-Cash tender facts exist**. The `down` path restores `tender_type IN ('cash')`, which cannot represent completed Card, Check, or Other rows. Do not delete or transform that history to make `db:rollback` succeed.
