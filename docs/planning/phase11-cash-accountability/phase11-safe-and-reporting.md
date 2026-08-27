# Phase 11 — Safe reconciliation and reporting

Status: **Implemented** on `main`. Deposit in transit is in Phase 11; bank confirmation is not.

### Actually locked

```text
safe recon does not require a deposit
safe variance is not allocated onto sessions
next business date may open on retained safe cash
deposit is safe → deposit in transit
safe recon uses snapshot/lock_version revalidation
store-day is a report, not a finalization gate
DIT accumulates until a later bank-confirmation phase
```

## 1. Safe expected cash

```text
initialize_safe
+ session_close and drop transfers in
+ (not opening_float or replenishment out)
- opening_float and replenishment
- deposits
± safe over/short
± reversals
```

`Cash::SafeTotals` (name may vary) rebuilds from `cash_entries` on the safe location. Do not include POS tenders or gift-card cash-outs (those never hit the safe except via session transfers).

## 2. Safe count integrity

Do **not** hold a database row lock while a manager counts across HTTP requests. MVP has no durable freeze record.

Optimistic contract:

1. Starting a count records the location’s expected balance and `lock_version` on `cash_counts` (`expected_cents_snapshot`, `location_lock_version_snapshot`).
2. Cash activity **may continue** while the count is being entered (opens, drops, replenishments, deposits, other posts).
3. On submission, lock the location row in the posting transaction.
4. Compare current `lock_version` and expected balance with the count’s snapshot.
5. If either changed, the count is stale and cannot be accepted; staff must verify or recount.
6. If unchanged, lock the starting `cash_counts` row. It must still be the discarded snapshot and must not already be referenced by an accepted count (`superseded_count_id` unique where not null). Then reconciliation (or zero-variance acceptance) posts atomically. Reusing the same start row with a new command id is rejected even when expected cash did not move.

Ordinary staff: blind until submit. `cash.view_expected_before_count` may reveal expected.

Deposit counts against the safe use the same snapshot/revalidation contract.

## 3. Safe variance

Independent of whether every session balanced. Do not distribute a safe over/short onto `PosSession` rows.

Nonzero accepted variance posts `reconcile` on the safe location (`cash.reconcile_safe`). **Any nonzero** over/short requires a managed reason code. Free-text note and material-approval bands use the same organization/store variance settings as session close ([phase11-schema.md](phase11-schema.md) §8). Material uses `cash.approve_variance` with `direct` / `approval_required` as in [phase11-authorization.md](phase11-authorization.md). That rebases `expected_balance_cents` so the same difference does not recur.

Zero variance: accept the count, no `cash_reconciliations` row. Store-day **safe reconciled** is derived from an accepted `cash_counts` with `purpose = safe_reconciliation` for that store and business date, **whether variance was zero or nonzero**—not from existence of a reconciliation row.

## 4. Retain vs deposit

After recon (or using current expected if the store skips recon that day—recon is **not** mandatory to open tomorrow):

- Retained cash stays on the safe.
- An authorized user may prepare a deposit: count (denomination lines optional), bag/reference optional, `cash_deposits` + `transfer_type = deposit` safe → deposit in transit.

Deposit preparation is not required to finish the day’s review or to open the next business date.

MVP: each deposit belongs to one store and one `business_date`. No split across dates. No bank-posted amount, no returned-deposit workflow.

Reversing a deposit (still in transit, not bank-confirmed) posts `operation_type = reverse` with no new deposit source row; inverse entries increase the safe and decrease DIT if expected DIT covers it. The original `cash_deposits` row stays immutable and is visibly reversed via the operation.

Because bank confirmation is deferred, the deposit-in-transit location **accumulates** prepared deposits and never clears during Phase 11. That is acceptable:

- Daily reporting presents **individual deposits for the selected date**.
- The DIT location balance is **cumulative outstanding cash under the operational ledger**.
- Phase 11 does **not** imply that cumulative DIT equals cash still physically in the store.
- A later financial phase will clear deposits against bank confirmation.

## 5. Store-day cash report

Aggregate underlying facts for a store + business date. Status labels are informational:

- incomplete (open sessions exist)
- sessions closed
- safe reconciled (an accepted `safe_reconciliation` cash count exists for that store and business date, zero or nonzero variance)
- deposit prepared (zero or more)

Not a stored `finalized` store-day row and **not** a blocker for `OpenSession` on a later date.

Minimum columns/sections:

- sessions opened/closed; opener/closer; manager-assisted flag
- opening floats; POS cash received and cash refunds; gift-card cash-outs
- paid-ins/outs by reason; drops; replenishments
- expected/counted/variance per session (from snapshots)
- safe expected/counted/over-short; retained; deposits and references
- corrections/reversals
- open sessions outstanding

A unified timeline projection may interleave tenders, cash-outs, and Phase 11 operations by `occurred_at` without copying tender amounts into `cash_entries`.

## 6. Phase 12 hook

`Cash::AvailableCash` (or `Pos::SessionTotals#available_cash_cents`) is the payout eligibility check. Buyback cash payout posts a buyback fact plus a cash movement Phase 12 defines; it must not invent a second till model.
