# Phase 10 — Implementation plan

Status: **Proposed** (not started). Living file: update slice status when work lands.

Authority: [phase10-plan.md](phase10-plan.md), [phase10-schema.md](phase10-schema.md), [ADR-025](../../adr/ADR-025-domain-owned-operational-ledgers.md), [ADR-026](../../adr/ADR-026-gift-card-number-protection.md).

## Locked decisions

1. No universal `financial_events` table. Accounting unification is Phase 14 ([ADR-025](../../adr/ADR-025-domain-owned-operational-ledgers.md)).
2. Gift-card activation/reload is `pos_stored_value_issuances`, not a merchandise SKU and not a tender.
3. Refund-to-credit is a `stored_value` refund tender, not an issuance row.
4. Three system-protected SV tender types: `store_credit`, `trade_credit`, `gift_card`.
5. Ordinary Register SV uses `pos.transact`. Cash-out, adjust, reveal, and program manage are separate keys.
6. `Customers::MergeStoredValueAccounts` is an explicit call from `Customers::MergeCustomers`.
7. Inactive: no new credit; redeem after reactivation; deactivate warns/blocks on nonzero balance.
8. Generate numbers at completion; Active Record encryption + HMAC digest; ordinary reprints masked ([ADR-026](../../adr/ADR-026-gift-card-number-protection.md)).
9. Unused-instrument return is in Phase 10.
10. Same-transaction activate+redeem and reload+redeem (any cards) forbidden in Phase 10.
11. Store `reversal_of_id` only.
12. `register_id` on `gift_card_cash_outs`, not on every operation.
13. Currency snapshot from `system_settings.base_currency_code` only; one customer account per type.
14. Expected cash: float + cash payments − cash refunds − completed gift-card cash-outs + cash-out reversals.
15. Opening-balance migration out. Store/trade cash-out out. Trade-credit cash-out prohibited. Seed trade-credit tender in 10.4.
16. Cash-out policy values: `prohibited`, `permitted_when_eligible`, `required_on_request_when_eligible`.
17. No working-transaction number reservation table.

## Slice status

| Slice | Status |
|---|---|
| 10.1 Stored-value core | Not started |
| 10.2 Customer store/trade credit | Not started |
| 10.3 Gift-card programs and instruments | Not started |
| 10.4 POS issuance, tenders, unused return, post-void | Not started |
| 10.5 Cash-out, closeout, print, nav | Not started |

## Integration notes

- Prefer one issue/PR per user-story cluster; keep signed-net + issuance + envelope together.
- Frozen POS closeout, receipt, and print suites must be extended, not rewritten.
- Local commands remain Docker-only (`./dev/rails-docker`).
