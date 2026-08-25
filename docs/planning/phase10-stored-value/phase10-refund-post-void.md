# Phase 10 — Refund, unused-instrument return, and post-void

Status: **Proposed**. Builds on [returns.md](../phase4-6-point-of-sale/phase6-pos-mvp/returns.md) and [post-void.md](../phase4-6-point-of-sale/phase6-pos-mvp/post-void.md).

### Actually locked

```text
return to original tenders where supported
store credit is the ordinary stored-value refund alternative
no trade credit from retail returns
no new gift card as generic refund destination
unused gift-card return is in Phase 10 and is not a merchandise return
unused = no redeem/reload/cash-out/replacement after the target issuance; remaining equals issued residual
ordinary post-void blocked when downstream SV cannot be fully reversed
no partial post-void
elevated correction may be a later story
```

## 1. Refund-to-credit

The cashier (or policy) builds an explicit allocation before complete:

- Cash / card / check refunds keep Phase 6 behavior (cash refunds affect expected cash).
- Portion originally paid with a gift card ordinarily returns to **that** card (`refund` operation, refund tender `gift_card`) when the instrument is still active.
- Remaining refundable amount may go to **store credit** (refund tender `store_credit` → issue/refund operation on the customer’s store-credit account). Transaction `customer_id` required.
- Retail refunds never create trade credit.
- A brand-new gift card is not an ordinary refund destination.

Refund tenders, POS facts, stored-value posts, and projections commit atomically.

Do **not** use `pos_stored_value_issuances` for refund-to-credit (that would change amount due). Issuance is customer-paid liability sale only.

## 2. Unused-instrument return

Customer wants money back for a gift card that was activated (or a reload increment) and **not subsequently used**.

This is not:

- a `pos_transaction_lines` linked return
- a gift-card **tender** refund of a merchandise sale
- a post-void of a mixed basket (unless the original ticket is wholly unused and post-void is still eligible)

### 2.1 Unused definition

An issuance is unused when **all** of:

1. No later `redeem`, `reload`, `cash_out`, or `transfer`/replacement operations on that account after this issuance (except reversals of this issuance).
2. Current `balance_cents` equals the residual of this issuance (activation: remaining equals activated amount; reload: remaining equals that reload increment when no later activity—if later reloads exist, only the latest unused reload increment may return, or block until policy is explicit: **Phase 10 allows unused return of the entire remaining balance only when the instrument has had no redeem/cash-out/replacement and remaining equals sum of unreverted issuances**).

Spell residual cents: `balance_after` of the last effective entry equals the sum of unreverted issue/activate/reload amounts minus unreverted redeems (here, redeems must be zero).

Reloaded-then-partially-spent cards are **not** unused; cashier uses ordinary post-void (if eligible) or exceptional correction (later).

### 2.2 Mechanics

New completed POS transaction (or mixed ticket that includes this workflow):

1. Lock card and account.
2. Confirm unused.
3. Add `pos_stored_value_issuances` row `issuance_type = unused_return` with `unused_return_of_issuance_id` pointing at the original activation/reload issuance.
4. `StoredValue::Post` `reverse` of the original operation (or a dedicated reverse covering remaining = issued).
5. Instrument: close or leave zero-balance closed/unusable per lifecycle (cannot redeem afterward).
6. Customer receives refund via existing refund tenders (cash/card/check) for `amount_cents`. Signed-net is negative (or netted in a mixed ticket) using issuance reverse **not** as positive `stored_value_issuance_cents`. Unused return **decreases** liability; it must not increase amount due.

Signed-net: unused-return amount is **not** added to `stored_value_issuance_cents`. Treat it as reducing net like a return total component **or** as a dedicated nonnegative `stored_value_unused_return_cents` subtracted in the identity. Prefer a dedicated column if mixing unused return with merchandise sales in one ticket is required; if unused return is always its own ticket, `signed_net = -(refundable cents)` with zero merchandise and zero issuance, settled by refund tenders.

**Phase 10 default:** unused-instrument return is its **own** completed transaction (no merchandise lines). Simpler signed-net: `signed_net = -amount`, refund tenders cover it. Document that mixed unused-return+sale is out of Phase 10.

### 2.3 Presentation

Receipt and history: distinct “Gift card unused return” with masked identity. Not a merchandise title.

## 3. Post-void

Post-void still appends a reversing POS transaction ([post-void.md](../phase4-6-point-of-sale/phase6-pos-mvp/post-void.md)).

Additionally reverse stored-value operations from the source ticket:

- Redeem reverse restores value
- Refund-to-credit reverse removes issued credit
- Activation/reload reverse removes issued value
- Cash-out reverse restores value and expected cash (10.5)

**Block** ordinary post-void when issued value was later redeemed, reloaded, transferred, cashed out, or unused-returned, such that reverse would overdraw or break lineage. UX: state that no partial post-void occurred; list downstream operation ids (masked cards).

Tests: activation, reload, refund-to-credit, merge transfer, cash-out, unused return as blockers.

Elevated correction (force reverse + compensating ops) is **not** required in Phase 10; fail closed.

Register post-void continues to use `PosControlledAction` perform/approve keys.

## 4. Same-transaction prohibitions

Forbidden in one working/completed ticket:

- Activate a card and redeem any stored value
- Reload any card and redeem any stored value
- Unused-return and redeem of the same instrument

Allow merchandise + activation (customer pays both). Allow merchandise + redeem. Allow split SV tenders without issuance.
