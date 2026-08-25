# Phase 10 — Authorization contract

Status: **Proposed**. Keys are seeded in `Authorization::PermissionCatalog`. The UI must not invent permission semantics. Controllers and services remain the authorization boundary.

Phase 1–9 keys are unchanged except where this document adds grants to seeded roles.

## Permission catalog

| Permission | scope_type | group_key | Meaning |
|---|---|---|---|
| `stored_value.view_activity` | either | stored_value | View account balances and activity (customer show, admin inquiry) |
| `stored_value.adjust` | either | stored_value | Manual issue/debit of store or trade credit |
| `gift_cards.manage_programs` | global | gift_cards | Create/update gift-card programs |
| `gift_cards.view` | either | gift_cards | Inquiry (masked); not full-number reveal |
| `gift_cards.suspend` | either | gift_cards | Suspend / reinstate instrument |
| `gift_cards.replace` | either | gift_cards | Replacement / controlled transfer of remaining balance |
| `gift_cards.associate_customer` | either | gift_cards | Set or clear optional customer association |
| `gift_cards.cash_out` | either | gift_cards | Register cash-out of eligible gift-card balance |
| `gift_cards.reveal_number` | global | gift_cards | Elevated reveal or full-number reprint of encrypted credential |

Do **not** add `gift_cards.activate`, `gift_cards.reload`, `gift_cards.redeem`, or `stored_value.redeem_customer_credit`. Those are ordinary Register actions.

## Register vs administrative

| Action | Permission |
|---|---|
| Activate / reload gift card | `pos.transact` (open session) |
| Redeem gift card, store credit, or trade credit | `pos.transact` |
| Unused-instrument return | `pos.transact` (same session rules as returns) |
| Refund-to-store-credit | `pos.transact` |
| Gift-card cash-out | `gift_cards.cash_out` **and** open session |
| Balance inquiry at Register (masked) | `pos.transact` |
| Admin/customer activity | `stored_value.view_activity` |
| Manual adjust | `stored_value.adjust` |
| Reveal full number | `gift_cards.reveal_number` (global assignment) |

Store-scoped `pos.transact` authorizes using an organization-wide customer credit **at that store**. It does not grant organization-wide administration of the account.

## Second-user and Register controlled actions

- Manual debit adjustments always require a second user with `stored_value.adjust` (or a dedicated approve key if implementation splits perform/approve). Performer ≠ approver.
- Manual credits at or above the organization threshold require second-user approval.
- Register cash-out approval, when program policy requires it, should reuse `PosControlledAction` (extend `ACTION_TYPES`) rather than a parallel protocol. Performer ≠ approver.
- Ordinary activate/reload/redeem do not use `PosControlledAction`.

## Role grants

| Role | Phase 10 additions |
|---|---|
| `system_administrator` | Entire Phase 10 catalog |
| `store_manager` | `stored_value.view_activity`, `stored_value.adjust`, `gift_cards.view`, `gift_cards.suspend`, `gift_cards.replace`, `gift_cards.associate_customer`, `gift_cards.cash_out` (not `gift_cards.manage_programs`, not `gift_cards.reveal_number`) |
| `associate` | No new keys. Existing `pos.transact` covers ordinary SV at the Register. No cash-out, adjust, reveal, or program manage. |

`gift_cards.manage_programs` and `gift_cards.reveal_number` require a **global** assignment (`system_administrator` or a custom global role). Store-scoped managers cannot rotate programs or recover bearer numbers.

Customer show: displaying balances requires `stored_value.view_activity` in addition to `customers.view`. Do not imply credit balances from customer view alone.

Deactivate-with-balance: `customers.manage` remains the lifecycle permission; the stored-value service supplies the nonzero-balance blocker.

## Seed ownership

| Kind | Contents |
|---|---|
| Production baseline | Permission keys; system-protected tender types `store_credit`, `trade_credit`, `gift_card`; at least two gift-card programs |
| Bootstrap / demo | Example program names/prefixes only if needed for operability |
| Test fixtures | Synthetic encrypted numbers with the documented test encryption key |

Already-initialized databases will need `shelfsense:seed_permissions` when implementation lands.
