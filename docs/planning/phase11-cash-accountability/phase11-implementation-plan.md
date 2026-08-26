# Phase 11 — Implementation plan

Status: **Proposed** (packet not landed). Living file: update slice status when work lands.

Authority: [phase11-plan.md](phase11-plan.md), [phase11-schema.md](phase11-schema.md), [ADR-021](../../adr/ADR-021-register-and-terminal-identity.md), [ADR-025](../../adr/ADR-025-domain-owned-operational-ledgers.md).

## Merge policy

Issue branches PR **directly to `main`**. There is no Phase 11 integration branch.

- Branch naming: `<issue-number>-<short-description>` ([github-workflow.md](../../github-workflow.md)).
- Merge order: 11.0 packet docs → 11.1 → 11.2 → 11.3.
- 11.1 is **one** complete PR (reviewable commits, not independently mergeable): safe init, open transfer, `SessionTotals`, close transfer, available-cash, gift-card cash-out check, manager-assisted close, Z regression.
- Do not ship paid-in/out or deposit before expected cash includes 11.1 transfers and over/short.
- Navigation destinations land in the slice that introduces the screens.

## Locked decisions

1. No `cash_drawers` table. Open `PosSession` is till custody on a Register.
2. Do not use `workstation`. Register / session / Terminal per ADR-021.
3. Do not copy `pos_tenders` or `gift_card_cash_outs` into `cash_entries`.
4. Phase 11 source rows hold `cash_operation_id`. Operations do not hold inverse source FKs.
5. Store `reversal_of_id` only.
6. `opening_float_cents` remains the session snapshot; after 11.1 its source is a transfer.
7. `closing_expected_cash_cents` is expected **before** over/short and the counted transfer. Do not store zero there because the till is empty.
8. Session statuses stay `open` / `closed`. No `closing` / `awaiting_sync`.
9. Every POS completion still requires an open session (`Pos::CompleteTransaction`).
10. Negative expected session cash is forbidden after 11.1. Existing zero-float refund and cash-out tests must be rewritten to replenish or assert the new error.
11. Change on a cash **payment** tender is not an available-cash check. Cash **refunds**, gift-card cash-outs, paid-outs, and drops are.
12. Gift-card cash-out available-cash lands in 11.1, not a later slice. Keep `gift_card_cash_outs` as the domain fact.
13. Manager-assisted close: `cashier_user_id` unchanged; `closed_by_user_id` records the manager; reason required; same count/transfer rules; tenders and cash-out still require the session cashier unless a later decision says otherwise.
14. Drops and replenishments are one atomic completed transfer (ADR-013). No acknowledgement states.
15. One operational safe per store. Schema may allow future extra safes without exposing them in MVP.
16. Store-day finalization is **not** a gate. Next business date opens on retained expected safe cash.
17. Deposit in transit is in 11.3. Bank confirmation is deferred.
18. Session open/close totals stay integer cents. Denomination lines are optional on session counts (must sum to the total when present). Safe/deposit denomination policy is settled in 11.3 implementation.
19. Historical closed sessions are not backfilled with transfers.
20. After 11.1, `OpenSession` fails until that store’s safe is initialized.
21. Currency is `system_settings.base_currency_code` only.
22. Frozen Phase 5/6/10 close, X/Z, and cash-out suites are extended, not rewritten to drop old snapshot meaning.

## Unresolved until implementation (not silent product choice)

- Default organization cents for variance-note, variance-approval, and paid-out-approval thresholds.
- Whether safe and deposit counts **require** denomination lines (session counts do not).

## Slice status

| Slice | Status |
|---|---|
| 11.0 Contract / packet | This document set (not on `main` until the packet PR merges) |
| 11.1 Safe-backed session lifecycle | Not started |
| 11.2 Non-sale cash activity | Not started |
| 11.3 Safe recon, deposit, store-day report | Not started |

## Integration notes

- Extend `Pos::OpenSession`, `Pos::CloseSession`, `Pos::SessionTotals`, `GiftCards::CashOut`, and cash-refund completion/tender paths.
- Add `Cash::Post` (name may vary) with location/session lock order, post-lock revalidation, idempotency, and nonnegative location checks—same shape as `StoredValue::Post`.
- Bootstrap/demo and tests must initialize a safe before opening a session.
- Local commands remain Docker-only (`./dev/rails-docker`).
- Audit and outbox (if any) commit with the business transaction. Failed attempts that must survive rollback are recorded outside it.
