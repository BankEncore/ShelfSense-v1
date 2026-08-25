# Phase 10 — POS issuance and tenders

Status: **Proposed**. Implementation authority for how stored value joins completed POS facts.

Companions: [phase10-schema.md](phase10-schema.md), [mvp-contract.md](../phase4-6-point-of-sale/phase6-pos-mvp/mvp-contract.md), [operation-and-core-facts.md](../phase4-6-point-of-sale/phase4-point-of-sale/operation-and-core-facts.md), [ADR-020](../../adr/ADR-020-pos-operation-envelope-and-core-facts.md).

### Actually locked

```text
issuance is not a line and not a tender
signed_net includes stored_value_issuance_cents
issuance is not taxable merchandise revenue
refund-to-credit is a stored_value refund tender
three protected SV tender types
customer_id on pos_transactions required at complete for store/trade tenders
Core FKs required; envelope snapshots masked facts
command hash must not include generated secrets
nested SV idempotency keyed by POS operation + issuance/tender id
same-tx activate/reload + redeem forbidden (any cards)
multiple SV payment tenders allowed
one cash payment constraint unchanged
```

## 1. Amount due

Live identity today:

```text
signed_net = subtotal - discount + tax - return_total
total = abs(signed_net)
```

Phase 10:

```text
signed_net = subtotal - discount + tax + stored_value_issuance_cents - return_total
total = abs(signed_net)
```

`Pos::Support.refresh_totals!`, `sale_total_cents` (merchandise+tax only — do not silently fold issuance into “sales”), `CompleteTransaction` expected totals, `CompletedTransactionFacts`, customer receipt, operator/X/Z, and reporting-period `finalized_*` must all agree. Issuance-only and mixed merchandise+issuance examples are required tests.

Tender coverage still uses `signed_net` / remaining-due rules from Phase 6, now including issuance in the amount the customer pays.

## 2. What belongs where

| Flow | POS fact | Stored-value operation |
|---|---|---|
| Customer pays to activate or reload a gift card | `pos_stored_value_issuances` (`activation` / `reload`) | `activate` / `reload` |
| Customer spends store credit, trade credit, or gift card | `pos_tenders` payment `stored_value` | `redeem` |
| Retail refund remaining to store credit | `pos_tenders` refund `stored_value` (`store_credit`) | `issue` or `refund` as specified in [phase10-refund-post-void.md](phase10-refund-post-void.md) |
| Original gift-card tender portion returned to the same card | `pos_tenders` refund `stored_value` (`gift_card`) | `refund` |
| Unused gift-card return | reverse issuance + refund tenders | `reverse` of the original activate/reload |
| Gift-card cash-out | `gift_card_cash_outs` (not a tender) | `cash_out` |

Do not model gift-card sale of liability as a `non_inventory` product variant.

## 3. Working transaction

Commands (names illustrative): add/remove issuance; set generate-from-program or manual number; add/remove SV tenders. Each mutates `lock_version`.

Working generate-at-complete activation: `gift_card_id` null; command carries `gift_card_program_id`. No reservation row; no liability.

Working manual activation: advisory digest uniqueness; completion revalidates.

Register basket: distinct issuance section (UDS-3 hierarchy), not a merchandise line. Scan routing: [phase10-gift-card-numbering.md](phase10-gift-card-numbering.md).

## 4. Customer on the transaction

`pos_transactions.customer_id` is new and optional.

At completion, if any tender has `stored_value_account_type` in (`store_credit`, `trade_credit`):

- Customer present, not merged, satisfies active policy
- Each such tender’s account belongs to that customer
- Revalidate customer and accounts under lock

Gift-card tenders do not require a transaction customer.

## 5. Tender types

See [phase10-schema.md](phase10-schema.md) §10.3. Affected contracts: `TenderType::CATEGORIES`, DB checks on `tender_types` and `pos_tenders`, cashier ordering, envelope validation, session totals, X/Z, post-void, seeds/fixtures.

## 6. Completion sequence

Inside the existing complete transaction (inventory, tax, envelope, outbox):

1. Lock stored-value accounts in deterministic UUID order (and gift-card instrument rows that control access).
2. Revalidate programs, cards, customers, issuance rows, tenders, and totals.
3. Reject same-transaction activate/reload of a card (or newly generated identity) together with any redemption of that or another stored-value instrument as specified in locked decisions (Phase 10: **any** activate/reload plus **any** SV redeem in one ticket is forbidden).
4. Generate system numbers only now; encrypt; digest; persist instrument + account.
5. Persist Core issuance/tender FKs to new operations.
6. `StoredValue::Post` nested idempotency keys: `pos.complete_transaction` outcome id + issuance id or tender id.
7. Build envelope from persisted Core (masked numbers only).
8. Commit atomically. Failure rolls back POS and SV.

Command payload includes expected signed_net, issuance cents, tender plan, and “generate from program X” — not the resulting number.

Complete-retry (ADR-009): same command hash returns stored envelope **and** may decrypt for the controlled first-print channel. The public envelope still has last four only.

## 7. Envelope vs Core

Core (required):

- `PosTender.stored_value_operation_id`
- `PosStoredValueIssuance.stored_value_operation_id`
- `GiftCardCashOut` → operation (10.5)
- Post-void source tender/issuance FKs

Envelope snapshots those ids, account types, masked identity, amounts, balance-after when appropriate. Bump completed-operation schema version; keep verify accepting prior versions for historical rows.

## 8. Split tender

Multiple stored-value payment tenders permitted. Reject two tenders against the same account when one amount would suffice. Concurrent requests redeeming the same gift card serialize on the account lock; uniqueness on digest prevents double activation of the same manual number.
