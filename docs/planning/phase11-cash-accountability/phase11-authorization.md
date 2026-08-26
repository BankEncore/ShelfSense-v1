# Phase 11 — Authorization contract

Status: **Proposed**. Keys are seeded in `Authorization::PermissionCatalog`. The UI must not invent permission semantics. Controllers and services remain the authorization boundary.

Phase 1–10 keys are unchanged except where this document adds grants. Second-user outcomes follow [controlled-actions.md](../phase4-6-point-of-sale/phase6-pos-mvp/controlled-actions.md): `direct` / `approval_required` / `prohibited`. A performer who also holds the matching **approve** permission completes **direct** (no second user; `approved_by` omitted). Never persist `approved_by_id = performed_by_id`.

## Permission catalog

| Permission | scope_type | group_key | Meaning |
|---|---|---|---|
| `cash.initialize_safe` | either | cash | One-time safe opening balance (count) |
| `cash.approve_initialize_safe` | either | cash | Approve safe initialization when the performer lacks this key |
| `cash.paid_in` | either | cash | Non-sale cash into an open session |
| `cash.paid_out` | either | cash | Non-sale cash out of an open session |
| `cash.approve_paid_out` | either | cash | Approve a paid-out at or above the effective threshold |
| `cash.move` | either | cash | Safe→session replenishment (and any later elevated moves) |
| `cash.view_expected_before_count` | either | cash | See expected cash before submitting a blind count |
| `cash.approve_variance` | either | cash | Approve material session or safe over/short |
| `cash.reconcile_safe` | either | cash | Count and accept safe over/short (11.3) |
| `cash.prepare_deposit` | either | cash | Move accepted safe cash to deposit in transit |
| `cash.reverse` | either | cash | Reverse an eligible Phase 11 cash operation |
| `pos.sessions.close_for_other` | either | pos | Close another cashier’s open session (manager-assisted) |

Ordinary own-session open, blind close, drop to safe, cash sale, and cash refund remain `pos.transact`. Gift-card cash-out remains `gift_cards.cash_out` **and** available session cash.

Do **not** add a permission that authorizes negative expected cash.

## Performer and approver

Evaluate policy at the **store** of the cash location or session. The approval actor must be active, authorized at that store (global assignments count in active stores), and authenticate for that exact operation. When `approval_required`, the approver must differ from the performer and is not given the cashier session.

| Action | Performer | Approver (only if `approval_required`) | Direct when performer also has |
|---|---|---|---|
| Initialize safe | `cash.initialize_safe` | `cash.approve_initialize_safe` | `cash.approve_initialize_safe` |
| Paid-out below threshold | `cash.paid_out` | — | — |
| Paid-out at/above threshold | `cash.paid_out` | `cash.approve_paid_out` | `cash.approve_paid_out` |
| Session close, variance below note threshold | `pos.transact` (cashier) or `pos.sessions.close_for_other` | — | — |
| Session close, note-only variance | same | — (reason/note required) | — |
| Session close, material variance | same | `cash.approve_variance` | `cash.approve_variance` |
| Safe recon, variance below note threshold | `cash.reconcile_safe` | — | — |
| Safe recon, material variance | `cash.reconcile_safe` | `cash.approve_variance` | `cash.approve_variance` |
| Paid-in | `cash.paid_in` | — (no amount threshold in MVP) | — |
| Replenish | `cash.move` | — | — |
| Drop (own session) | `pos.transact` | — | — |
| Prepare deposit | `cash.prepare_deposit` | — | — |
| Reverse eligible operation | `cash.reverse` | — | — |
| Manager-assisted close | `pos.sessions.close_for_other` | (variance rules above) | (variance rules above) |

`cash.approve_paid_out` is **not** implied by `cash.paid_out`. A user who can pay out but cannot approve must obtain a distinct approver for large paid-outs.

Reuse `Pos::AuthenticateApprover` / `PosControlledAction` for Register-originated cash actions rather than a parallel password protocol.

## Register vs administrative

| Action | Permission |
|---|---|
| Open own session (safe-backed float) | `pos.transact`; safe must be initialized |
| Close own session | `pos.transact` as session cashier |
| Drop from own open session to safe | `pos.transact` |
| Replenish session from safe | `cash.move` |
| Paid-in / paid-out | `cash.paid_in` / `cash.paid_out` |
| Cash refund | `pos.transact` + available cash |
| Gift-card cash-out | `gift_cards.cash_out` + open session + available cash |
| View expected before count | `cash.view_expected_before_count` (ordinary close stays blind) |
| Manager-assisted close | `pos.sessions.close_for_other`; reason required; `closed_by_user_id` = manager |
| Initialize safe | `cash.initialize_safe` (no open POS session required) |
| Count and reconcile safe | `cash.reconcile_safe` |
| Prepare deposit | `cash.prepare_deposit` |
| Reverse Phase 11 cash | `cash.reverse` |
| Store-day cash report | `pos.sessions.view` |

## Role grants

| Role | Phase 11 additions |
|---|---|
| `system_administrator` | Entire Phase 11 catalog (perform **and** approve → `direct` for controlled cash actions) |
| `store_manager` | All Phase 11 cash perform and approve keys, store-scoped; `pos.sessions.close_for_other` (self-authorizing / `direct` when they perform) |
| `associate` | No new keys. `pos.transact` covers own open/close/drop and ordinary cash tenders. No paid-in/out, replenish, deposit, reverse, close-for-other, view-expected-before-count, or approve keys |

## Seed ownership

| Kind | Contents |
|---|---|
| Production baseline | New permission keys; cash activity reasons without GL codes; organization threshold defaults |
| Bootstrap / demo | One **initialized** safe per seeded store so Register enter still works |
| Tests | Safe init in POS fixtures before `OpenSession` |

Already-initialized databases will need `shelfsense:seed_permissions` when 11.1 lands.
