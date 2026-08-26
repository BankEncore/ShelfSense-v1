# Phase 11 — Safe reconciliation and reporting

Status: **Proposed**. Implementation authority for 11.3. Deposit in transit is in Phase 11; bank confirmation is not.

### Actually locked

```text
safe recon does not require a deposit
safe variance is not allocated onto sessions
next business date may open on retained safe cash
deposit is safe → deposit in transit
store-day is a report, not a finalization gate
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

Beginning reconciliation locks the safe location (optimistic `lock_version` plus transaction lock) so new floats, drops, replenishments, and deposits cannot post until the recon completes or is abandoned. Record the expected balance being counted.

Ordinary staff: blind until submit. `cash.view_expected_before_count` may reveal expected.

## 3. Safe variance

Independent of whether every session balanced. Do not distribute a safe over/short onto `PosSession` rows.

Nonzero accepted variance posts `reconcile` on the safe location (`cash.reconcile_safe`; material ⇒ `cash.approve_variance`). That rebases `expected_balance_cents` so the same difference does not recur.

Zero variance: accept the count, no reconciliation row.

## 4. Retain vs deposit

After recon (or using current expected if the store skips recon that day—recon is **not** mandatory to open tomorrow):

- Retained cash stays on the safe.
- An authorized user may prepare a deposit: count (denominations strongly encouraged; 11.3 decides if required), bag/reference optional, `cash_deposits` + `transfer_type = deposit` safe → deposit in transit.

Deposit preparation is not required to finish the day’s review or to open the next business date.

MVP: each deposit belongs to one store and one `business_date`. No split across dates. No bank-posted amount, no returned-deposit workflow.

Reversing a deposit (still in transit, not bank-confirmed) returns amount to the safe with `cash.reverse`, if expected DIT covers it.

## 5. Store-day cash report

Aggregate underlying facts for a store + business date. Status labels are informational:

- incomplete (open sessions exist)
- sessions closed
- safe reconciled (a recon accepted that date, or none)
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
