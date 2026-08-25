# Phase 10 — Reporting and closeout

Status: **Proposed**. Extends frozen Phase 5/6 closeout; do not invent Phase 11’s cash-movement ledger.

Companions: [phase5-plan.md](../phase4-6-point-of-sale/phase5-cash-register/phase5-plan.md), [Pos::SessionTotals](../../../app/services/pos/session_totals.rb), [phase10-pos-issuance-and-tenders.md](phase10-pos-issuance-and-tenders.md).

### Actually locked

```text
expected cash = opening float + cash payments - cash refunds
                - completed gift-card cash-outs + cash-out reversals
closed-session snapshots immutable
X/Z and reporting-period finalized_* extended, not replaced
issuance is not merchandise subtotal
SV tenders report under stored_value category
cash-out is not a tender and not a refund
```

## 1. Expected cash

Open session (`Pos::SessionTotals#expected_cash_cents` when not closed):

```text
opening_float_cents
+ cash payment tenders (completed transactions)
- cash refund tenders
- posted gift_card_cash_outs for this pos_session (not reversed)
+ cash-out reversals posted to this session (post-void or reverse of cash-out)
```

Closed session: return `closing_expected_cash_cents` as today. Never rewrite closed snapshots.

## 2. Surfaces that must regress

| Surface | Change |
|---|---|
| Open-session totals / Home | New formula; show cash-out total |
| Session close / blind count | Expected includes cash-outs |
| X report | Issuance, SV tenders by type, cash-outs |
| Z report | Same; finalized period columns |
| Reporting-period finalization | New `finalized_*` cents as needed (issuance, SV payments/refunds, cash-outs); existing merchandise/tax columns unchanged in meaning |
| Reopened page / complete retry | Totals stable |
| Post-void of cash sale | Unchanged cash tender math |
| Post-void or reverse of cash-out | Restores expected cash |
| Closed-session immutability | No live recompute |

Add tests beside existing Z/close suites; do not rewrite those suites to drop old assertions.

## 3. X/Z content

Distinct rows or sections:

- Merchandise subtotal, discounts, tax, returns (existing)
- Stored-value issuance (activation/reload) — **not** sales revenue
- Store-credit / trade-credit / gift-card payments and refunds
- Gift-card cash-outs (count and cents)
- Unused-instrument return refunds (cash effect via refund tenders)

Do not dump issuance into `other` or merchandise subtotal.

## 4. Liability reporting (admin)

Operational outstanding balances by account type, originating store of activity, date range, and account status. Organization-wide customer/gift-card liability is not split into store-owned sub-balances; store is attribution of activity only.

No GL export status.

## 5. Print

See [phase10-gift-card-numbering.md](phase10-gift-card-numbering.md) and [receipt-presentation.md](../phase4-6-point-of-sale/phase6-pos-mvp/receipt-presentation.md). Customer paper: issuance, redemption, remaining balance (masked), cash-out, unused return. Full number only on controlled activation print / reveal.
