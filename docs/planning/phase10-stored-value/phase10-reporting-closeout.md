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
transfers net to zero organization-wide but remain visible as activity
manual adjustments change liability and must not be grouped with refunds or paid issuance
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

Reversing a gift-card cash-out requires confirmation that the original cash has physically returned to an open Register session. The reversing session receives the positive expected-cash effect. A bookkeeping-only reversal cannot pretend cash was recovered.

## 2. Surfaces that must regress

| Surface | Change |
|---|---|
| Open-session totals / Home | New formula; show cash-out total |
| Session close / blind count | Expected includes cash-outs |
| X report | Issuance, SV tenders by type, cash-outs, refund destinations |
| Z report | Same; finalized period columns |
| Reporting-period finalization | New `finalized_*` cents as needed (issuance, SV payments/refunds, cash-outs); existing merchandise/tax columns unchanged in meaning |
| Reopened page / complete retry | Totals stable |
| Post-void of cash sale | Unchanged cash tender math |
| Post-void or reverse of cash-out | Restores expected cash after physical-cash confirmation on an open Register session |
| Closed-session immutability | No live recompute |

Add tests beside existing Z/close suites; do not rewrite those suites to drop old assertions.

## 3. X/Z and operational reporting

Distinct rows or sections:

- Merchandise subtotal, discounts, tax, returns (existing)
- Stored-value issuance (activation/reload) — **not** sales revenue
- Store-credit / trade-credit / gift-card payments
- Refund to original gift card
- Refund to new gift card
- Refund to store credit
- Gift-card cash-outs (count and cents)
- Manual credits
- Manual debits
- Same-type transfers
- Account consolidation

Transfers net to zero organization-wide but remain visible as activity. Manual adjustments change liability and must not be grouped with refunds or paid issuance.

Do not dump issuance into `other` or merchandise subtotal.

## 4. Liability reporting (admin)

Operational outstanding balances by account type, originating store of activity, date range, and account status. Organization-wide customer/gift-card liability is not split into store-owned sub-balances; store is attribution of activity only.

No GL export status.

## 5. Print

See [phase10-gift-card-numbering.md](phase10-gift-card-numbering.md) and [receipt-presentation.md](../phase4-6-point-of-sale/phase6-pos-mvp/receipt-presentation.md). Customer paper: issuance, redemption, remaining balance (masked), refund destinations, cash-out. Full number only on controlled first print, complete-retry, or print recovery.
