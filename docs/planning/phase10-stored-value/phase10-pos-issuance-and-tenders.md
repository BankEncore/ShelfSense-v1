# Phase 10 — POS issuance and tenders

Status: **Proposed**. Implementation authority for how stored value joins completed POS facts.

Companions: [phase10-schema.md](phase10-schema.md), [phase10-refund-post-void.md](phase10-refund-post-void.md), [mvp-contract.md](../phase4-6-point-of-sale/phase6-pos-mvp/mvp-contract.md), [operation-and-core-facts.md](../phase4-6-point-of-sale/phase4-point-of-sale/operation-and-core-facts.md), [ADR-020](../../adr/ADR-020-pos-operation-envelope-and-core-facts.md).

### Actually locked

```text
issuance is not a line and not a tender
signed_net includes stored_value_issuance_cents
issuance is not taxable merchandise revenue
refund destinations are stored_value refund tenders + tender details
new refund gift card does not increase stored_value_issuance_cents
three protected SV tender types
customer_id on pos_transactions required at complete for store/trade tenders and store-credit refund
source rows hold stored_value_operation_id; operations do not hold source FKs
envelope snapshots masked facts
command hash must not include generated secrets
nested SV idempotency keyed by POS operation + issuance/tender id
same-tx activate/reload + redeem forbidden (any cards)
multiple SV payment tenders allowed
one cash payment constraint unchanged
transfer is never debit plus credit adjustments
refund is never a manual adjustment
known erroneous operations are reversed rather than offset
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

Tender coverage still uses `signed_net` / remaining-due rules from Phase 6, now including issuance in the amount the customer pays. Refund gift cards are tenders, not issuance.

## 2. What belongs where

| Flow | POS fact | Stored-value operation |
|---|---|---|
| Customer pays to activate or reload a gift card | `pos_stored_value_issuances` (`activation` / `reload`) | `activate` / `reload` |
| Customer spends store credit, trade credit, or gift card | Stored-value payment tender + detail targeting existing account | `redeem` |
| Refund to presented original gift card | Stored-value refund tender + detail targeting original account | `refund` |
| Refund to customer store credit | Stored-value refund tender + detail targeting customer account | `refund` |
| Refund to new gift card | Stored-value refund tender + pending new-card detail | `refund` |
| Trade-credit-funded portion returned to original account | Stored-value refund tender targeting original trade account | `refund` |
| Gift-card cash-out | `gift_card_cash_outs` (not a tender) | `cash_out` |

Do not model gift-card sale of liability as a `non_inventory` product variant.

**Possession:** refund to an original gift card requires scanning or keying a valid card whose resolved account matches the original gift-card tender. Transaction history’s masked identity is insufficient proof of possession.

## 3. Working transaction

Commands (names illustrative): add/remove issuance; set generate-from-program or manual pending number; add/remove SV tenders and destination details. Each mutates `lock_version`.

Working generate-at-complete activation: `gift_card_id` null; command carries `gift_card_program_id`. No reservation row; no liability.

Working manual activation: persist encrypted `pending_card_number` and digest on the issuance; `gift_card_id` stays null until completion.

Working new refund card: encrypted pending identity on `pos_stored_value_tender_details`; no gift-card row until completion.

Register basket: distinct issuance section (UDS-3 hierarchy), not a merchandise line. Scan routing: [phase10-gift-card-numbering.md](phase10-gift-card-numbering.md).

## 4. Customer on the transaction

`pos_transactions.customer_id` is optional. Gift-card-only tickets do not require a customer.

Cashiers attach a customer through operational Register search (`Customers::Search` mode `:operational` and `GET register/customer_search`), not by pasting a UUID. Working tickets may change or clear the customer with the same lock and cashier rules as attach. Pickup remains a request allocation and does **not** set `customer_id` unless a later packet decides otherwise. Creating a customer from the Register is out of this slice.

The attached customer name appears on the completed-transaction screen and on the customer receipt header. It is not a CRM dump.

At completion, if any tender is store/trade credit or destination mode is `customer_store_credit`:

- Customer present, not merged, satisfies active policy
- Each such tender’s account belongs to that customer
- Revalidate customer and accounts under lock

Gift-card payment tenders and new-refund-card destinations do not require a transaction customer. If store/trade tender is attempted with no customer, the server still rejects; the Register surfaces the customer-search overlay.

## 5. Tender types

See [phase10-schema.md](phase10-schema.md) §11.3. Affected contracts: `TenderType::CATEGORIES`, DB checks on `tender_types` and `pos_tenders`, cashier ordering, envelope validation, session totals, X/Z, post-void, seeds/fixtures.

## 6. Completion sequence

Inside the existing complete transaction (inventory, tax, envelope, outbox):

1. Lock stored-value accounts in deterministic UUID order (and gift-card instrument rows that control access).
2. Revalidate programs, cards, customers, issuance rows, tenders, tender details, and totals.
3. Reject same-transaction activate/reload together with any stored-value redeem in one ticket.
4. For activations: generate system numbers or consume pending manual identity; `encrypts :number`; digest; persist instrument + account.
5. For new-gift-card refunds: generate or consume pending identity; create gift card and account; post positive `refund` entry; link tender detail, card, account, and operation. **Do not** add the amount to `stored_value_issuance_cents`.
6. Persist `stored_value_operation_id` on issuance, tender, cash-out, and related source rows.
7. `StoredValue::Post` nested idempotency keys: `pos.complete_transaction` outcome id + issuance id or tender id.
8. Build envelope from persisted Core (masked numbers only).
9. Commit atomically. Failure rolls back POS and SV.

Command payload includes expected signed_net, issuance cents, tender plan, destination modes, and “generate from program X” — not the resulting number or generated `gift_card_id` on activations and new refund cards.

Complete-retry (ADR-009): same command hash returns stored envelope **and** may decrypt for the controlled first-print channel until delivery is recorded **and** the originating session is still open. The public envelope still has last four only. After first-print delivery, or after the session closes, later views stay masked; recovery uses `gift_cards.recover_print`.

## 7. Envelope vs Core

Core (required):

- `PosTender.stored_value_operation_id` and `PosStoredValueTenderDetail`
- `PosStoredValueIssuance.stored_value_operation_id`
- `GiftCardCashOut.stored_value_operation_id` (10.5)
- Post-void source tender/issuance FKs

Envelope snapshots those ids, destination modes, account types, masked identity, amounts, balance-after when appropriate. Bump completed-operation schema version; keep verify accepting prior versions for historical rows.

## 8. Split tender

Multiple stored-value payment tenders permitted. Reject two tenders against the same account when one amount would suffice. Concurrent requests redeeming the same gift card serialize on the account lock; uniqueness on digest prevents double activation of the same manual number.
