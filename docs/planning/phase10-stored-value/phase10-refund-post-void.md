# Phase 10 — Refund and post-void

Status: **Proposed**. Builds on [returns.md](../phase4-6-point-of-sale/phase6-pos-mvp/returns.md) and [post-void.md](../phase4-6-point-of-sale/phase6-pos-mvp/post-void.md). Gift-card refund destinations: [phase10-pos-issuance-and-tenders.md](phase10-pos-issuance-and-tenders.md). Unused-instrument return is **deferred**.

### Actually locked

```text
for gift-card-funded amounts: original card, else new refund card, or store credit
never trade credit from retail refund as a generic destination
new gift card is not a generic dump for arbitrary refund value
refund gift card receives only the current refund amount
replacement is a separate controlled transfer
ordinary post-void blocked when downstream SV cannot be fully reversed
post-void does not require presenting the bearer card
no partial post-void
elevated correction may be a later story
```

## 1. Refund destinations

The cashier (or policy) builds an explicit allocation before complete. Cash / card / check refunds keep Phase 6 behavior (cash refunds affect expected cash).

For an amount originally paid by gift card:

1. Refund to the matching original card when the customer presents it and it is usable.
2. Otherwise issue a new refund gift card.
3. Alternatively refund to customer store credit when a canonical active customer is attached.
4. Never create trade credit.
5. Do not convert the amount directly to cash except through a separately eligible gift-card cash-out after refund completion.

A new gift card is not a generic destination for arbitrary refund value. It is permitted as a substitute bearer instrument for value originally paid by gift card. Original-card, new-card, and original-trade-credit allocations are capped at the remaining funded portion: original payments of that stored-value type on the linked original transactions, minus completed (non-post-voided) refunds already sent to those destinations. Completion locks the original transactions and revalidates the cap.

Trade-credit-funded portions may return to the **original** trade-credit account (`allows_original_tender_refund`), still capped at the remaining trade-credit-funded portion. Trade credit is not a generic leftover destination.

Store credit may receive leftover refund value (`allows_generic_refund_destination`) when a customer is attached.

Refund tenders, tender details, POS facts, stored-value `refund` operations, and projections commit atomically. Do **not** use `pos_stored_value_issuances` for refunds (that would change amount due). Issuance is customer-paid liability sale only.

### 1.1 Original gift-card status

| Original status | Action |
|---|---|
| Active and presented | Refund original |
| Suspended | New refund card or store credit |
| Replaced | Refund verified replacement when presented; otherwise new card/store credit |
| Closed | New card or store credit |
| Cashed out | New card or store credit |
| Unavailable | New card or store credit |

Refund to an original gift card requires scanning or keying a valid card whose resolved account matches the original gift-card tender. Masked history is not proof of possession.

### 1.2 Refund gift card vs replacement

A refund gift card:

- Receives only the current refund amount.
- Does not transfer the original card’s remaining balance.
- Does not mark the original card replaced.

Replacement remains a separate controlled transfer of remaining balance onto a new instrument.

Missing original card is handled without requiring customer creation (new refund card). Store credit still requires a canonical active customer.

## 2. Post-void

Post-void still appends a reversing POS transaction ([post-void.md](../phase4-6-point-of-sale/phase6-pos-mvp/post-void.md)).

Additionally reverse stored-value operations from the source ticket:

- Redeem reverse restores value
- Refund reverse removes refunded value (including new refund-card liability)
- Activation/reload reverse removes issued value
- Cash-out reverse restores value and expected cash (10.5)

Post-void does **not** require the bearer card to be presented. It corrects the original transaction through stored-value operation lineage.

**Block** ordinary post-void when issued or refunded value was later redeemed, reloaded, transferred, cashed out, or replaced, such that reverse would overdraw or break lineage. UX: state that no partial post-void occurred; list downstream operation ids (masked cards).

Tests: activation, reload, refund to original/new card/store credit, merge transfer, cash-out as blockers.

Elevated correction (force reverse + compensating ops) is **not** required in Phase 10; fail closed.

Register post-void continues to use `PosControlledAction` perform/approve keys.

## 3. Same-transaction prohibitions

Forbidden in one working/completed ticket:

- Activate a card and redeem any stored value
- Reload any card and redeem any stored value

Allow merchandise + activation (customer pays both). Allow merchandise + redeem. Allow split SV tenders without issuance.

## 4. Deferred: unused-instrument return

Returning an unused activated gift card for cash/card (not a merchandise return, not post-void) is a later POS policy slice. Do not add `unused_return` issuance types or signed-net special cases in Phase 10.
