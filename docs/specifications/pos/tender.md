Yes. Before drafting `tenders.md`, I would lock a few refinements. The existing tender model is already coherent: five behavioral categories, configurable tender types, explicit payment/refund direction, multiple tenders, cash presented/applied/change, external card processing, authoritative stored-value balances, and immutable completed tenders. 

## 1. Tender describes settlement, not what was sold

The fundamental distinction should be:

```text
Transaction lines
    → determine what the customer owes / is owed

Tenders
    → describe how that net obligation is settled
```

A `$50` sale followed by a `$20` return produces a net:

```text
$30 due from customer
```

Tendering settles `$30`.

We should **not** separately tender `$50 payment` and `$20 refund` just because both line directions exist.

For an ordinary mixed sale/return transaction:

> **Lines net first; only the remaining net balance is tendered or refunded.**

That is consistent with the existing exchange model. 

---

# 2. Tender category and tender type should remain separate

I agree strongly with the current five categories:

| Category         | Meaning                                                                       |
| ---------------- | ----------------------------------------------------------------------------- |
| **Cash**         | Physical currency                                                             |
| **Card**         | Externally processed payment card                                             |
| **Check**        | Check instrument                                                              |
| **Stored Value** | ShelfSense-managed value/account                                              |
| **Other**        | Externally valuable or store-specific instrument not fitting another category |

A **tender type** is store-facing configuration assigned to one category.

Examples:

| Tender type         | Category     |
| ------------------- | ------------ |
| Cash                | Cash         |
| Credit/Debit Card   | Card         |
| Personal Check      | Check        |
| Gift Card           | Stored Value |
| Store Credit        | Stored Value |
| Manufacturer Coupon | Other        |
| Campus Voucher      | Other        |

This is preferable to making:

```text
gift_card
store_credit
manufacturer_coupon
visa
check
cash
```

all peer categories.

The category establishes fundamental behavior; the tender type configures the particular method. This is already the direction of the consolidated design. 

---

# 3. Tender amounts should always be positive

I recommend we lock the same pattern we used for line direction:

```text
direction = payment | refund
applied_amount_cents > 0
```

Do **not** use:

```text
payment = +2000
refund  = -2000
```

Direction carries business meaning.

Amount carries magnitude.

That makes the settlement equation much clearer.

---

# 4. We should lock one settlement equation

Assuming the transaction net total is signed:

```text
positive → customer owes ShelfSense
negative → ShelfSense owes customer
zero     → no settlement required
```

then:

```text
Σ payment tender applied amounts
-
Σ refund tender applied amounts
=
transaction net total
```

Examples:

### Sale

```text
Transaction total:          $50

Payment Cash:               $20
Payment Card:               $30
                            ---
Net tender:                 $50
```

### Refund

```text
Transaction total:         -$25

Refund Store Credit:        $25

payment - refund:
0 - 25 = -25
```

### Even exchange

```text
Transaction total:           $0

No tender required
```

This gives us one very clean invariant.

---

# 5. Ordinary settlement should use only the net direction

Although the equation can mathematically represent both directions simultaneously, I recommend the ordinary POS workflow prohibit unnecessary simultaneous payment and refund tenders.

If:

```text
net > 0
```

add payment tenders.

If:

```text
net < 0
```

add refund tenders.

If:

```text
net = 0
```

add none.

This avoids nonsense such as:

```text
$30 refund tender
+
$50 payment tender
```

when the cashier could simply settle `$20 due`.

A specialized future correction workflow could be different, but normal checkout should net first.

---

# 6. `applied_amount` is the settlement value

This should be the universally important tender amount:

```text
applied_amount_cents
```

It answers:

> How much of the transaction obligation did this tender settle?

Other tender-specific values supplement it.

For example, Cash adds:

```text
amount_presented
change
```

Card adds:

```text
external_reference
```

Stored Value adds:

```text
stored_value_account
```

But settlement always uses **applied amount**. The current design already makes this distinction. 

---

# 7. Cash should retain three distinct values

We are aligned on:

```text
amount_applied
amount_presented
change
```

Example:

```text
Remaining due:      $17.24
Cash presented:     $20.00
Cash applied:       $17.24
Change:              $2.76
```

And:

```text
drawer increase = $17.24
```

not `$20`.

The consolidated design explicitly preserves these separately and treats change as part of Cash rather than another tender. 

I would lock:

```text
cash payment:
change = amount_presented - amount_applied
```

where the cash tender settles the remaining balance.

---

# 8. A cash tender producing change must finish settlement

This is a useful additional invariant.

Suppose:

```text
Remaining due: $30
```

Cashier may apply:

```text
Cash $10
Card $20
```

if `$10` cash is actually presented and no change is due.

But this makes no sense:

```text
Cash presented $20
Cash applied   $10
Change         $10

then Card $20
```

If cash produces change, it has effectively settled the remaining obligation.

So I recommend:

> **A Cash payment that produces change must be the final payment tender and must settle the remaining positive balance.**

That gives the POS a straightforward mixed-tender interaction.

---

# 9. Cash refund is simpler

For a Cash refund:

```text
direction = refund
applied_amount = amount physically given to customer
```

There is no meaningful `amount_presented` or `change`.

Expected drawer effect is:

```text
payment cash applied
-
refund cash applied
```

Cash tender facts should drive drawer expectation; we should not duplicate sale/refund cash into generic cash-movement records.

---

# 10. Non-cash tender cannot produce change

I recommend hard category constraints initially:

| Category     | Overtender |      Change |
| ------------ | ---------: | ----------: |
| Cash         |  May allow | May provide |
| Card         |         No |          No |
| Check        |         No |          No |
| Stored Value |         No |          No |
| Other        |         No |          No |

A tender type can be **more restrictive** than its category, but not contradict fundamental category behavior.

For example, a store could disable cash overtender if it wanted.

But it could not configure:

```text
Card provides change = true
```

The current design already says configuration cannot contradict category behavior. 

---

# 11. Tender type configuration should add offline capability

The current conceptual configuration includes:

```text
code
name
category
payment_enabled
refund_enabled
allows_over_tender
provides_change
requires_reference
reference_label
active
display_order
```

I recommend we add an explicit concept such as:

```text
offline_allowed
```

or, perhaps better semantically:

```text
requires_authoritative_online_state
```

because tender availability is not determined solely by category.

Examples:

| Tender               | ShelfSense-server offline?                |
| -------------------- | ----------------------------------------- |
| Cash                 | Yes                                       |
| Check                | Potentially yes                           |
| Standalone Card      | Potentially yes; processor is independent |
| Manufacturer voucher | Policy-dependent                          |
| Gift Card redemption | **No initially**                          |

This makes offline eligibility explicit instead of spreading special cases throughout the UI.

---

# 12. Card is a record of external payment

This is important enough to make an invariant:

> **ShelfSense does not process cards in the initial Card model.**

The cashier:

```text
Select Card
→ ShelfSense displays amount
→ cashier processes external terminal
→ external system approves
→ cashier confirms result in ShelfSense
→ ShelfSense records tender
```

ShelfSense should not model itself as having:

```text
authorize
capture
settle
```

processor states when it does not control those operations.

The consolidated design explicitly says card processing is external and ShelfSense records the result for reconciliation. 

---

# 13. I would keep card metadata intentionally minimal

Initially I would preserve only what is operationally useful, such as:

```text
card type/brand       optional
external reference   optional/configurable
```

I would **not require**:

* PAN;
* CVV;
* expiration;
* cardholder data.

And I would probably avoid storing last-four unless we have a demonstrated reconciliation/receipt need.

The less payment-card data ShelfSense stores, the cleaner the boundary remains.

---

# 14. External Card introduces one special working-state problem

This is the biggest tender issue I think we need to acknowledge before drafting.

Suppose:

```text
External terminal approves $50
        ↓
Cashier confirms tender in ShelfSense
        ↓
ShelfSense attempts CompleteTransaction
        ↓
local database completion fails
```

The `$50` card transaction exists externally even though the ShelfSense transaction did not complete.

We cannot silently discard that fact.

So I recommend the domain establish:

> **Externally confirmed tender activity must remain durably visible until the POS transaction either completes or the external tender is explicitly resolved/voided.**

We don't need a full processor authorization-state machine.

But we do need enough working-tender state to distinguish:

```text
cash entry that can simply be discarded before completion
```

from:

```text
externally approved card activity that already exists outside ShelfSense
```

Detailed status names can wait until Card implementation.

---

# 15. This argues against one giant generic tender-status enum now

Older designs used things like:

```text
pending
authorized
completed
declined
voided
refunded
failed
removed
```

I would **not lock that universal state machine yet**.

Cash does not have an authorization lifecycle.

Check does not have the same lifecycle as Card.

Stored Value will eventually have an authoritative balance protocol of its own.

Instead, I suggest the domain principle:

```text
Working tender information
        ↓
category-specific external/authoritative state where necessary
        ↓
transaction completion
        ↓
Completed tender fact
```

Only a **completed tender** is final financial settlement.

Then Card can add the minimum working state it genuinely needs without pretending Cash has an `authorized` state.

---

# 16. Tender entry can constrain transaction editing

This follows from the previous point.

Cash entered but not completed can often be discarded safely.

But externally confirmed Card activity cannot simply disappear because the cashier decides to change the basket.

So:

> **A transaction may return from tendering to commercial editing only when all recorded tender activity can be safely discarded or reversed.**

That is primarily a workflow rule, but the Tender domain needs to support it.

This behavior is also reflected in the POS presentation material. 

---

# 17. Check should remain deliberately simple

Initial Check behavior:

```text
payment enabled
refund configurable
reference/check number required
no overtender
no change
```

We should not store bank account/routing details.

Any future:

```text
check cash-back
```

would be an explicit new capability rather than a consequence of turning on overtender.

That matches the current consolidated model. 

---

# 18. Stored Value is one category, not several

I agree with the existing design:

```text
Category:
Stored Value

Tender types/programs:
Gift Card
Store Credit
```

They share the same fundamental infrastructure but have different program behavior.

For example:

| Type         | Payment/redemption | Refund destination |
| ------------ | -----------------: | -----------------: |
| Gift Card    |                Yes |        Normally no |
| Store Credit |                Yes |                Yes |

The consolidated design explicitly uses this model. 

---

# 19. Stored-value redemption requires authoritative balance

This is fundamentally different from ordinary quantity inventory.

If a gift card has:

```text
balance = $20
```

two disconnected terminals cannot each safely spend `$20` and merely reconcile later.

Therefore:

> **Stored-value redemption requires authoritative shared balance access until we deliberately design a bounded offline mechanism.**

The existing architecture already makes this decision. 

I would preserve it strongly in `tenders.md`.

---

# 20. Stored-value refund is different from redemption

This is worth making explicit.

### Redemption/payment

```text
Stored Value balance decreases
```

and:

```text
applied amount <= authoritative available balance
```

### Refund to Store Credit

```text
Stored Value balance increases
```

It is issuance of additional liability/value, so it is not limited by the pre-existing balance.

The tender direction still captures:

```text
payment
refund
```

but the associated stored-value ledger effect goes in opposite directions.

---

# 21. Stored Value needs a separate execution contract later

The **business semantics** belong in `tenders.md`.

But I would not pretend the technical protocol is solved.

Because the authoritative balance is central, we eventually need to specify:

```text
reserve/authorize value
→ POS completion
→ commit redemption/credit
→ retry/recovery
```

and what happens if either system fails between those steps.

That deserves a dedicated Stored Value contract/workflow before implementation.

It should not complicate Phase 5 Cash tendering.

---

# 22. Selling a gift card is not a tender

Another boundary worth preserving:

```text
Customer buys $25 gift card
```

The **gift-card issuance** is something being sold/issued.

The Cash/Card the customer gives us is the **tender**.

Later:

```text
Customer spends the gift card
```

the gift card becomes a Stored Value tender.

So we should avoid treating issuance itself as a payment method.

The eventual stored-value specification should own issuance/reload semantics.

---

# 23. `Other` should not become a miscellaneous dumping ground

`Other` is appropriate for genuinely valuable settlement instruments such as:

```text
manufacturer reimbursable coupon
campus voucher
```

It should not be used for:

* store-funded discount coupons;
* store credit;
* gift cards;
* cash-like drawer movements.

The economic function determines the model.

This remains consistent with our Discount distinction between store-funded and reimbursable coupons. 

---

# 24. Mixed tender should exist in the model from the beginning

Even though the first operational sale is Cash only, I agree that transaction/tender cardinality should be:

```text
Transaction
    1
    │
    └── 0..N Tenders
```

not:

```text
transaction.tender_type
transaction.tender_amount
```

The consolidated design already establishes multiple-tender support in the model. 

---

# 25. Tender sequence should be preserved

I recommend retaining a stable tender sequence/order.

Example:

```text
1. Gift Card        $20.00
2. Voucher           $5.00
3. Card             $30.00
4. Cash             $17.40
```

Even though applied cents can be summed mathematically, sequence matters for:

* cashier reconstruction;
* cash change behavior;
* receipts;
* troubleshooting;
* refund recommendations.

It should therefore be historically reproducible.

---

# 26. Refund eligibility and refund selection are different

A tender type can declare:

```text
refund_enabled = true
```

meaning:

> This tender type is capable of giving value to the customer.

But **which** refund tender should be used belongs primarily to Returns policy.

For linked returns, we already decided:

* preserve original tender history;
* recommend original-compatible tender where appropriate;
* don't require mathematically proportional refund across original mixed tenders;
* alternate methods may require approval. 

So `tenders.md` should define capability.

`returns.md` should define refund-selection policy.

---

# 27. Completed tenders are immutable

We are already aligned here.

After completion:

```text
applied amount
direction
type/category
cash presented/change
external reference
stored-value relationship
```

are historical facts.

If the cashier recorded the wrong tender:

```text
do not edit original tender
```

Use a future explicit:

```text
tender correction
tender reversal
post-void
refund/correction workflow
```

The current design already states this explicitly. 

---

# 28. Completed tender snapshots are needed

Just as with prices and tax, I recommend completed tenders retain both reference and snapshot information.

For example:

```text
tender_type_id
tender_type_code_snapshot
tender_type_name_snapshot
category_snapshot
```

so renaming:

```text
Credit Card
→ Card
```

later does not rewrite old receipts/reports.

Tender configuration used at completion should also be versionable where relevant.

---

# 29. Stale tender configuration follows our normal offline rule

Suppose:

```text
POS cached:
Campus Voucher active

central:
Campus Voucher disabled while POS offline
```

If it was legitimately usable offline under cached policy and the transaction completes:

* preserve the tender;
* don't rewrite settlement;
* classify stale configuration through reconciliation.

This is the same principle as stale price/tax/authority.

Stored Value is different because it explicitly requires authoritative shared balance and therefore would not qualify for this ordinary offline path.

---

# 30. Recommended model to carry into `tenders.md`

I would summarize the domain this way:

> **A tender is a positive-valued, explicitly directed settlement fact associated with a POS transaction. Transaction lines first determine the signed net amount owed; payment or refund tenders then settle that net amount using their applied values. Configurable tender types belong to one of five behavior-constraining categories—Cash, Card, Check, Stored Value, or Other. Cash additionally preserves presented amount and change; Card records externally processed value without making ShelfSense a card processor; Stored Value requires authoritative shared-balance control; completed tenders are immutable and corrections create new facts.**

## Decisions I think we should explicitly lock before drafting

| Question                                 | Recommended answer                                            |
| ---------------------------------------- | ------------------------------------------------------------- |
| Five categories                          | **Cash, Card, Check, Stored Value, Other**                    |
| Tender type vs category                  | **Separate**                                                  |
| Tender amount sign                       | **Always positive**                                           |
| Direction                                | **Explicit `payment` / `refund`**                             |
| Settlement                               | **Payment applied − refund applied = signed transaction net** |
| Mixed sale/return                        | **Net lines first, tender only net difference**               |
| Multiple tenders                         | **Supported structurally from beginning**                     |
| Tender sequence                          | **Preserve**                                                  |
| Cash values                              | **Applied + presented + change**                              |
| Cash drawer effect                       | **Applied amount, signed by tender direction**                |
| Change                                   | **Cash only; never separate tender**                          |
| Cash with change                         | **Must finish positive settlement**                           |
| Card                                     | **External processing only**                                  |
| Sensitive card data                      | **Do not store**                                              |
| External card approval before POS commit | **Must remain durably visible if completion fails**           |
| Universal tender status enum             | **Do not lock yet**                                           |
| Check                                    | **No overtender/change; reference required initially**        |
| Stored Value                             | **One category; Gift Card/Store Credit as types/programs**    |
| Stored Value offline redemption          | **Not initially allowed**                                     |
| Gift-card issuance                       | **Not a tender; separate stored-value issuance behavior**     |
| Other                                    | **External/store-specific value, not generic miscellaneous**  |
| Refund selection                         | **Returns policy; Tender defines capability**                 |
| Completed tenders                        | **Immutable**                                                 |
| Offline eligibility                      | **Make explicit in tender configuration/authority model**     |
| Completed tender type snapshots          | **Preserve**                                                  |

If those positions match your intent, `tenders.md` can be written with relatively few unresolved fundamentals; the biggest later contract will be **Stored Value**, not ordinary tender settlement.
