# Phase 11 — Authorization contract

Status: **Proposed**. Keys are seeded in `Authorization::PermissionCatalog`. The UI must not invent permission semantics. Controllers and services remain the authorization boundary.

Phase 1–10 keys are unchanged except where this document adds grants.

## Permission catalog

| Permission | scope_type | group_key | Meaning |
|---|---|---|---|
| `cash.initialize_safe` | either | cash | One-time safe opening balance (count + approval) |
| `cash.paid_in` | either | cash | Non-sale cash into an open session |
| `cash.paid_out` | either | cash | Non-sale cash out of an open session |
| `cash.move` | either | cash | Safe→session replenishment (and any later elevated moves) |
| `cash.view_expected_before_count` | either | cash | See expected cash before submitting a blind count |
| `cash.approve_variance` | either | cash | Second user for material over/short |
| `cash.reconcile_safe` | either | cash | Count and accept safe over/short (11.3) |
| `cash.prepare_deposit` | either | cash | Move accepted safe cash to deposit in transit |
| `cash.reverse` | either | cash | Reverse a Phase 11 cash operation |
| `pos.sessions.close_for_other` | either | pos | Close another cashier’s open session (manager-assisted) |

Ordinary own-session open, blind close, drop to safe, cash sale, and cash refund remain `pos.transact`. Gift-card cash-out remains `gift_cards.cash_out` **and** available session cash.

Do **not** add a permission that authorizes negative expected cash.

## Register vs administrative

| Action | Permission |
|---|---|
| Open own session (safe-backed float) | `pos.transact`; safe must be initialized |
| Close own session (count, over/short, transfer counted to safe) | `pos.transact` as session cashier |
| Drop from own open session to safe | `pos.transact` |
| Replenish session from safe | `cash.move` |
| Paid-in / paid-out | `cash.paid_in` / `cash.paid_out` |
| Cash refund | `pos.transact` + available cash |
| Gift-card cash-out | `gift_cards.cash_out` + open session + available cash |
| View expected before count | `cash.view_expected_before_count` (ordinary close stays blind) |
| Material variance approval | `cash.approve_variance`; performer ≠ approver |
| Manager-assisted close | `pos.sessions.close_for_other`; reason required; `closed_by_user_id` = manager |
| Initialize safe | `cash.initialize_safe` + second user |
| Count and reconcile safe | `cash.reconcile_safe`; material variance uses `cash.approve_variance` |
| Prepare deposit | `cash.prepare_deposit` |
| Reverse Phase 11 cash | `cash.reverse` |
| Store-day cash report | `pos.sessions.view` or store-scoped cash view; do not require `cash.reverse` |

If 11.3 needs additional report-only keys, add them then; do not invent them in UI first.

## Role grants

| Role | Phase 11 additions |
|---|---|
| `system_administrator` | Entire Phase 11 catalog |
| `store_manager` | All Phase 11 cash keys, store-scoped; `pos.sessions.close_for_other` |
| `associate` | No new keys. `pos.transact` covers own open/close/drop and ordinary cash tenders. No paid-in/out, replenish, deposit, reverse, close-for-other, or view-expected-before-count |

`cash.initialize_safe` may be global-only if stores must not self-init in production; default is **either** so a store manager can init that store’s safe at cutover.

## Second-user

- Safe initialization: performer ≠ approver.
- Material session or safe variance: performer ≠ approver when above threshold.
- Paid-out above threshold: performer ≠ approver.
- Manager-assisted close does **not** by itself require a third user; the manager is not the assigned cashier.
- Reuse `PosControlledAction` / existing second-user authentication where the action is Register-originated, rather than a parallel password protocol.

## Seed ownership

| Kind | Contents |
|---|---|
| Production baseline | New permission keys; cash activity reasons without GL codes |
| Bootstrap / demo | One initialized safe per seeded store so Register enter still works |
| Tests | Safe init in POS fixtures before `OpenSession` |

Already-initialized databases will need `shelfsense:seed_permissions` when 11.1 lands.
