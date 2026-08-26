# Phase 11 — Implementation plan

Status: **Proposed** (11.3 in this PR). Living file: update slice status when work lands.

Authority: [phase11-plan.md](phase11-plan.md), [phase11-schema.md](phase11-schema.md), [ADR-021](../../adr/ADR-021-register-and-terminal-identity.md), [ADR-025](../../adr/ADR-025-domain-owned-operational-ledgers.md).

## Merge policy

Phase 11 uses a long-lived integration branch because 11.1 makes `OpenSession` fail until every active store safe is initialized. Incomplete slices must stay off `main`.

- Integration branch: `phase-11-cash-accountability` (from `main`). This is the only long-lived Phase 11 branch.
- Slice branches: `<issue-number>-<short-description>` ([github-workflow.md](../../github-workflow.md)).
- Slice PRs target **`phase-11-cash-accountability`**, not `main`. Do not start slice N+1 until slice N is reviewed and merged into the integration branch.
- Merge order: 11.0 merge-policy docs → 11.1 → 11.2 → 11.3.
- 11.1 is **one** complete PR (reviewable commits, not independently mergeable): safe init, open transfer, `SessionTotals`, close transfer, available-cash, gift-card cash-out check, manager-assisted close, Z regression.
- Do not ship paid-in/out or deposit before expected cash includes 11.1 transfers and over/short.
- Navigation destinations land in the slice that introduces the screens.
- Do **not** merge `phase-11-cash-accountability` to `main` until [phase11-manual-test-plan.md](phase11-manual-test-plan.md) is executed.

GitHub tracker: [milestone Phase 11](https://github.com/BankEncore/ShelfSense-v1/milestone/6) — [#72](https://github.com/BankEncore/ShelfSense-v1/issues/72) 11.0, [#73](https://github.com/BankEncore/ShelfSense-v1/issues/73) 11.1, [#74](https://github.com/BankEncore/ShelfSense-v1/issues/74) 11.2, [#75](https://github.com/BankEncore/ShelfSense-v1/issues/75) 11.3.

## Locked decisions

1. No `cash_drawers` table. Open `PosSession` is till custody on a Register.
2. Do not use `workstation`. Register / session / Terminal per ADR-021.
3. Do not copy `pos_tenders` or `gift_card_cash_outs` into `cash_entries`.
4. Each successful **non-reverse** operation has exactly one source row that holds `cash_operation_id`. Operations do not hold inverse source FKs. Reverse operations have **no** fabricated transfer, paid-in, paid-out, reconciliation, initialization, or deposit source row.
5. Store `reversal_of_id` only (operations and inverse entries). Reason/notes for a reverse live on the reverse operation.
6. `opening_float_cents` remains the session snapshot. A **positive** opening float posts a balanced safe→session transfer. A **zero-float** opening retains `opening_float_cents = 0` and creates **no** zero-valued operation or entries.
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
17. Deposit in transit is in 11.3. Bank confirmation is deferred. Daily reporting lists deposits for the selected date; the DIT location balance is cumulative outstanding ledger cash and does **not** mean that cash is still physically in the store.
18. Denomination lines are **never required** (session, safe, deposit, or initialization). When present, they must sum to `total_cents`.
19. Historical closed sessions are not backfilled with transfers. No safe balance is inferred from historical closing snapshots.
20. After 11.1 **enforcement** is active, `OpenSession` fails until that store’s safe is initialized. See **Production cutover** below.
21. Currency is `system_settings.base_currency_code` only.
22. Frozen Phase 5/6/10 close, X/Z, and cash-out suites are extended, not rewritten to drop old snapshot meaning.
23. Safe reconciliation uses snapshot/`lock_version` revalidation on submit. Cash activity **may continue** while a count is being entered. Do not hold a database row lock across HTTP requests. MVP has no durable freeze/reconciliation-in-progress record.
24. Safe initialization is one-time. It cannot be reversed through `Cash::Reverse`. Mistakes are corrected by privileged safe reconciliation. No second initialization.
25. Do not reverse `session_close` or session over/short in MVP.
26. Controlled cash actions follow Phase 6 outcomes except **safe initialization**: performer with perform+approve is `direct` (no second user; `approved_by` omitted). Safe initialization is always `approval_required` with a distinct `cash.approve_initialize_safe` actor, regardless of amount. Never persist `approved_by_id = performed_by_id`. Approver (when `approval_required`) must differ from the performer, be authorized in the same store scope, and authenticate for that exact operation.
27. Dedicated approve keys: `cash.approve_initialize_safe`, `cash.approve_paid_out`, `cash.approve_variance`. Perform keys do not imply approve keys. Seeded `store_manager` and `system_administrator` receive both so they can self-authorize variance and paid-outs as `direct`; they still cannot self-approve safe initialization.
28. Variance-note, variance-approval, and paid-out-approval thresholds are **organization-level configurable defaults** with nullable store overrides (`COALESCE(store, org)`). They are not permanent policy constants. Seeded defaults: note `100` ($1.00), variance approval `1000` ($10.00), paid-out approval `5000` ($50.00). Comparisons are inclusive (`>=`). Variance uses `abs(variance_cents)`. Session close and safe recon share the same variance settings. Any nonzero over/short requires a managed reason code; the note threshold only adds required free-text.

## Production cutover

11.1 creates a real Register-enter hazard if code lands while a store has no initialized safe. Bootstrap/demo/test coverage does not solve production.

**Chosen path: coordinated maintenance-window activation** (fits single-tenant). Same 11.1 release both ships initialization and **enforces** `OpenSession` requires init.

Before cashiers open after 11.1:

1. Migration creates the store **safe** and **deposit-in-transit** locations in an **uninitialized** state (`initialized_at` null on the safe; expected balances 0). Historical sessions are untouched.
2. Run `shelfsense:seed_permissions` so Phase 11 permission keys and cash activity reasons exist on existing installations.
3. Safe initialization is an administrative (or dedicated) screen usable **without** an open POS session.
4. Authorized staff initialize every **active** operational store after migrate, **before** cashiers open. Initialization always requires a distinct `cash.approve_initialize_safe` actor.
5. Deployment verification confirms every active store has `cash_locations.initialized_at` set on its safe.
6. Do **not** infer a safe balance from historical closing snapshots.

If a later release needs to delay enforcement, that would be a feature gate or two-step deploy; this packet locks the maintenance-window path unless a superseding note is added here.

## Slice status

| Slice | Status |
|---|---|
| 11.0 Contract / packet | **Complete** on `main` (planning packet). Merge-policy lock: this PR on `phase-11-cash-accountability` |
| 11.1 Safe-backed session lifecycle | **Complete** on `phase-11-cash-accountability` |
| 11.2 Non-sale cash activity | **Complete** on `phase-11-cash-accountability` |
| 11.3 Safe recon, deposit, store-day report | This PR |

## Integration notes

- Extend `Pos::OpenSession`, `Pos::CloseSession`, `Pos::SessionTotals`, `GiftCards::CashOut`, and cash-refund completion/tender paths.
- Add `Cash::Post` (name may vary) with location/session lock order, post-lock revalidation, idempotency, and nonnegative location checks—same shape as `StoredValue::Post`.
- Reuse `Pos::AuthenticateApprover` / `PosControlledAction` for Register-originated cash actions.
- Bootstrap/demo and tests must initialize a safe before opening a session so Docker Register enter still works. Initialization still uses a distinct performer and approver.
- Local commands remain Docker-only (`./dev/rails-docker`).
- Audit and outbox (if any) commit with the business transaction. Failed attempts that must survive rollback are recorded outside it.
