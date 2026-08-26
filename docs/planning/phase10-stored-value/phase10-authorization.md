# Phase 10 — Authorization contract

Status: **Proposed**. Keys are seeded in `Authorization::PermissionCatalog`. The UI must not invent permission semantics. Controllers and services remain the authorization boundary.

Phase 1–9 keys are unchanged except where this document adds grants to seeded roles.

## Permission catalog

| Permission | scope_type | group_key | Meaning |
|---|---|---|---|
| `stored_value.view_activity` | either | stored_value | View account balances and activity (customer show, admin inquiry) |
| `stored_value.adjust` | either | stored_value | Manual credit/debit of eligible accounts |
| `stored_value.transfer` | either | stored_value | Same-type administrative transfer and consolidation |
| `stored_value.manage_adjustment_reasons` | global | stored_value | Catalog of adjustment reasons |
| `gift_cards.manage_programs` | global | gift_cards | Create/update gift-card programs |
| `gift_cards.view` | either | gift_cards | Inquiry (masked), including admin prefix + last-four history |
| `gift_cards.suspend` | either | gift_cards | Suspend / reinstate instrument |
| `gift_cards.replace` | either | gift_cards | Replacement / controlled transfer of remaining balance |
| `gift_cards.associate_customer` | either | gift_cards | Set or clear optional customer association |
| `gift_cards.cash_out` | either | gift_cards | Register cash-out of eligible gift-card balance |
| `gift_cards.recover_print` | either | gift_cards | Exceptional recovery of a system-generated credential (reason required) |

Do **not** add `gift_cards.activate`, `gift_cards.reload`, `gift_cards.redeem`, `stored_value.redeem_customer_credit`, or `gift_cards.reveal_number`. Ordinary Register actions use `pos.transact`. Full-number decryption after first-print delivery uses `gift_cards.recover_print`, not a general plaintext-view permission.

## Register vs administrative

| Action | Permission |
|---|---|
| Activate / reload gift card | `pos.transact` (open session) |
| Redeem gift card, store credit, or trade credit | `pos.transact` |
| Refund destinations (original card, new refund card, store credit) | `pos.transact` |
| Gift-card cash-out | `gift_cards.cash_out` **and** open session |
| Balance inquiry at Register (masked) | `pos.transact` |
| Immediate first print after complete | `pos.transact` (same completion, originating session still open, until delivery is recorded); **Print gift card** voucher, not Print receipt |
| Controlled print-recovery / replacement print | `gift_cards.recover_print` (reason required); replacement first-print voucher uses `gift_cards.replace` and only for a `GiftCardReplacement` new card. Store managers may be granted `gift_cards.recover_print`. |
| Admin/customer activity | `stored_value.view_activity` (customer-owned accounts); `gift_cards.view` (gift-card account ledger). Store-scoped viewers see other stores’ amounts with store labeled `Another store`; actor, reason, and POS links are omitted. |
| Manual adjust | `stored_value.adjust` |
| Administrative transfer / consolidation | `stored_value.transfer` |
| Adjustment reason catalog | `stored_value.manage_adjustment_reasons` |
| Customer-merge transfer | Merge authority (`customers.manage`), not `stored_value.transfer` |

Store-scoped `pos.transact` authorizes using an organization-wide customer credit **at that store**. It does not grant organization-wide administration of the account.

| Permission | System administrator | Store manager | Associate |
|---|---:|---:|---:|
| `stored_value.transfer` | Yes | Yes, store-scoped | No |
| `stored_value.adjust` | Yes | Yes, store-scoped | No |
| `stored_value.manage_adjustment_reasons` | Yes | No | No |
| `gift_cards.recover_print` | Yes | Yes, store-scoped | No |

## Second-user and Register controlled actions

- All manual debits require a second user. Performer ≠ approver.
- Credits at or above the organization threshold require second-user approval.
- Administrative and inter-customer transfers require second-user approval. Performer ≠ approver.
- Customer-merge transfer follows merge authority, not `stored_value.transfer`.
- Gift-card cash-out requires `gift_cards.cash_out`. When the program’s `cash_out_approval_required` is true, reuse `PosControlledAction` (extend `ACTION_TYPES`) rather than a parallel protocol.
- Ordinary activate/reload/redeem/refund destinations do not use `PosControlledAction`.

## Role grants

| Role | Phase 10 additions |
|---|---|
| `system_administrator` | Entire Phase 10 catalog |
| `store_manager` | `stored_value.view_activity`, `stored_value.adjust`, `stored_value.transfer`, `gift_cards.view`, `gift_cards.suspend`, `gift_cards.replace`, `gift_cards.associate_customer`, `gift_cards.cash_out`, `gift_cards.recover_print` (not `gift_cards.manage_programs`, not `stored_value.manage_adjustment_reasons`) |
| `associate` | No new keys. Existing `pos.transact` covers ordinary SV at the Register including first print while the originating session is open until delivery is recorded. No cash-out, adjust, transfer, program manage, or print recovery. |

`gift_cards.manage_programs` and `stored_value.manage_adjustment_reasons` require a **global** assignment.

Customer show: displaying balances requires `stored_value.view_activity` in addition to `customers.view`. Do not imply credit balances from customer view alone.

Deactivate-with-balance: `customers.manage` remains the lifecycle permission; the stored-value service supplies the nonzero-balance blocker.

## Seed ownership

| Kind | Contents |
|---|---|
| Production baseline | Permission keys including `gift_cards.recover_print`; system-protected tender types `store_credit`, `trade_credit`, `gift_card`; at least two gift-card programs; adjustment-reason seed without `opening_balance` |
| Bootstrap / demo | Example program names/prefixes only if needed for operability |
| Test fixtures | Synthetic numbers encrypted with the documented Rails test encryption keys |

Already-initialized databases will need `shelfsense:seed_permissions` when implementation lands.
