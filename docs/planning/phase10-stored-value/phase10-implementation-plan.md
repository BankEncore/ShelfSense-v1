# Phase 10 — Implementation plan

Status: **Proposed** (not started). Living file: update slice status when work lands.

GitHub tracker: [milestone Phase 10](https://github.com/BankEncore/ShelfSense-v1/milestone/5) — [#58](https://github.com/BankEncore/ShelfSense-v1/issues/58) packet, [#59](https://github.com/BankEncore/ShelfSense-v1/issues/59) 10.1, [#60](https://github.com/BankEncore/ShelfSense-v1/issues/60) 10.2, [#61](https://github.com/BankEncore/ShelfSense-v1/issues/61) 10.3, [#62](https://github.com/BankEncore/ShelfSense-v1/issues/62) 10.4, [#63](https://github.com/BankEncore/ShelfSense-v1/issues/63) 10.5.

Authority: [phase10-plan.md](phase10-plan.md), [phase10-schema.md](phase10-schema.md), [ADR-025](../../adr/ADR-025-domain-owned-operational-ledgers.md), [ADR-026](../../adr/ADR-026-gift-card-number-protection.md).

## Merge policy

Issue branches PR **directly to `main`**. There is no `phase-10-stored-value` integration branch.

- Branch naming: `<issue-number>-<short-description>` ([github-workflow.md](../../github-workflow.md)).
- Merge order: optional 10.0 packet docs → 10.1 → 10.2 → 10.3 → 10.4 → 10.5.
- 10.1–10.3 are additive. Ordinary Register scan, completion, and amount-due do not change until 10.4.
- 10.4 is **one** complete PR (reviewable commits, not independently mergeable). Signed-net, issuance, tenders, refund destinations, Register scan routing, controlled first print, and post-void land together.
- Do not insert gift-card routing into the Register scan path before 10.4. 10.3 builds the validator/resolver for administrative inquiry only.
- Navigation destinations land in the slice that introduces the screens. 10.5 adds only cash-out/reporting destinations and the final nav audit.

## Locked decisions

1. No universal `financial_events` table. Accounting unification is Phase 14 ([ADR-025](../../adr/ADR-025-domain-owned-operational-ledgers.md)).
2. Gift-card activation/reload is `pos_stored_value_issuances`, not a merchandise SKU and not a tender.
3. POS refunds of stored value are `refund` operations via tenders and `pos_stored_value_tender_details`, not issuance rows.
4. Gift-card-funded refund destinations: original matching card, new refund gift card, or store credit. Never trade credit as a generic destination.
5. Three system-protected SV tender types: `store_credit`, `trade_credit`, `gift_card`.
6. Ordinary Register SV uses `pos.transact`. Cash-out, adjust, transfer, and program manage are separate keys. No `gift_cards.reveal_number`.
7. `Customers::MergeStoredValueAccounts` is an explicit call from `Customers::MergeCustomers`. Zero-balance source accounts close; no survivor account for zero.
8. Inactive: no new credit; redeem after reactivation; deactivate warns/blocks on nonzero balance.
9. Rails `encrypts :number` and `encrypts :pending_card_number`; HMAC digest for lookup; no custom `encryption_key_id`.
10. Same-type administrative transfers and consolidation are in Phase 10. Cross-type conversion is prohibited.
11. Manual adjustments cover store credit, trade credit, and eligible gift cards.
12. Unused-instrument return is **deferred**.
13. Same-transaction activate+redeem and reload+redeem (any cards) forbidden in Phase 10.
14. Store `reversal_of_id` only. Source rows hold `stored_value_operation_id`; operations do not hold source FKs.
15. `register_id` on `gift_card_cash_outs`, not on every operation.
16. Currency snapshot from `system_settings.base_currency_code` only; one customer account per type.
17. Expected cash: float + cash payments − cash refunds − completed gift-card cash-outs + cash-out reversals.
18. Opening-balance migration out. Store/trade cash-out out. Trade-credit cash-out prohibited. Seed trade-credit tender in 10.4.
19. Cash-out policy values: `prohibited`, `permitted_when_eligible`, `required_on_request_when_eligible`, plus `cash_out_approval_required`.
20. No working-transaction number reservation table; pending encrypted identity on working issuance/tender detail.
21. Stored-value tender `stored_value_operation_id` lives on `pos_stored_value_tender_details`, not on `pos_tenders`.
22. Controlled first print of generated activation and generated refund cards ships in 10.4. Exceptional recovery, cash-out receipts, and X/Z print polish wait for 10.5.
23. Every newly started POS transaction snapshots `system_settings.base_currency_code`. Stored value does not introduce a conditional currency path.
24. Value originally paid from trade credit returns to that same trade-credit account. Trade credit is never a generic refund destination.
25. Cash-out reversal requires confirmation that cash physically returned to an open Register session. Bookkeeping-only reversal is prohibited.

## Slice status

| Slice | Status |
|---|---|
| 10.1 Stored-value core | Complete (issue [#59](https://github.com/BankEncore/ShelfSense-v1/issues/59)) |
| 10.2 Customer store/trade credit | Complete (issue [#60](https://github.com/BankEncore/ShelfSense-v1/issues/60)) |
| 10.3 Gift-card programs and instruments | Complete (issue [#61](https://github.com/BankEncore/ShelfSense-v1/issues/61)) |
| 10.4 POS issuance, tenders, refund destinations, post-void | Complete (issue [#62](https://github.com/BankEncore/ShelfSense-v1/issues/62)) |
| 10.5 Cash-out, closeout, print, nav | Complete (issue [#63](https://github.com/BankEncore/ShelfSense-v1/issues/63)); Phase 10 milestone remains open until the [manual test plan](phase10-manual-test-plan.md) is executed |

## Integration notes

- Prefer one issue/PR per slice; keep signed-net + issuance + envelope + first print together in 10.4.
- Frozen POS closeout, receipt, and print suites must be extended, not rewritten.
- Local commands remain Docker-only (`./dev/rails-docker`).
- Successful mutation audit and outbox facts commit with the business transaction. Failed or denied attempts that must survive rollback are recorded outside the rolled-back mutation. Outbox events exist only for committed business facts.
