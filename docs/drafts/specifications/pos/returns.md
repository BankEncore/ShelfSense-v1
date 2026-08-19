# POS Domain Specification: Returns

**Design status:** Core linked-return, historical-reversal, exchange, and inventory behavior decided; eligibility, unlinked-return basis, offline breadth, and post-void details remain pending in this draft
**Implementation status:** Phase 6 MVP contract locked in [returns.md](../../../planning/phase4-6-point-of-sale/phase6-pos-mvp/returns.md); not yet implemented
**Required decision gate:** Finalize/supersede ADR-016 before **offline** returns; online MVP does not wait on ADR-016
**Related specifications:** Transactions, Transaction Lines, Pricing, Discounts, Tax, Tenders, Approvals, Inventory Integration, Receipts, Operation Synchronization, Reconciliation
**Related workflows:** Linked Return, Partial Return, Individually Tracked Return, Unlinked Return, Exchange, Post-Void

> **Phase 6 MVP:** implementation authority for linked/unlinked returns, refunds, and mixed sale+return is [returns.md](../../../planning/phase4-6-point-of-sale/phase6-pos-mvp/returns.md). That contract **supersedes** this draft’s still-pending unlinked-policy questions for the MVP. This file remains vocabulary.

---

## 1. Purpose

This specification defines the ShelfSense POS return domain.

It establishes:

* what a return represents;
* the distinction among returns, refunds, exchanges, and post-voids;
* linked versus unlinked returns;
* return-line identity and direction;
* remaining returnable quantity;
* historical price reversal;
* historical discount reversal;
* historical tax reversal;
* inventory reversal;
* individually tracked returns;
* partial-return behavior;
* refund relationship;
* return authorization and approval;
* offline-return constraints;
* completed-return immutability;
* reporting and receipt requirements.

This specification does **not** define:

* detailed refund-tender selection;
* tender-category behavior;
* price calculations for new sales;
* tax calculation for new sales;
* inventory damage/RTV disposition;
* exact return-window policy;
* a post-void implementation;
* card-processor refund protocols.

Those rules belong to their owning specifications and workflows.

---

# 2. Governing principle

A return is a **new POS business fact** that reverses some or all of an earlier sale.

It does not modify the original transaction.

Conceptually:

```text
Original completed sale
        ↓
remains immutable
        ↓
New return transaction/line
        ↓
reverses applicable historical effects
```

The original sale continues to describe what originally happened.

The return describes what happened later.

---

# 3. Return, refund, exchange, and post-void are different

ShelfSense distinguishes four concepts.

## 3.1 Return

A return reverses the economic and inventory effects associated with merchandise previously sold.

```text
merchandise comes back
→ return
```

## 3.2 Refund

A refund describes how value owed to the customer is settled.

```text
return transaction produces $20 owed to customer
        ↓
Cash / Card / Store Credit / other permitted refund tender
```

Return and refund are therefore not synonyms.

## 3.3 Exchange

An exchange is an ordinary POS transaction containing both:

```text
return-direction lines
+
sale-direction lines
```

The transaction's net value determines whether:

* customer pays;
* ShelfSense refunds;
* no tender is needed.

## 3.4 Post-void

A post-void reverses a completed transaction because the original completion itself should not have occurred.

It is not an ordinary merchandise return.

The consolidated design explicitly treats post-void as a separate correction concept. 

---

# 4. Return lines use the normal transaction-line model

Returns do not require a parallel line architecture.

A return line uses:

```text
line_type = merchandise | open_ring
direction = return
quantity > 0
```

Quantity remains positive.

Direction carries the reversal meaning.

Incorrect:

```text
quantity = -2
```

Correct:

```text
direction = return
quantity  = 2
```

---

# 5. Return transactions use the normal transaction lifecycle

A transaction containing return lines follows the same lifecycle as any other POS transaction:

```text
open
→ completed
```

or:

```text
open
→ cancelled
```

Before completion, return work is mutable.

After completion, it is immutable.

There is no separate mutable historical-return state after completion.

---

# 6. Linked versus unlinked return

ShelfSense distinguishes:

```text
linked return
```

from:

```text
unlinked return
```

based on whether the return line references an authoritative original completed sale line.

---

# 7. Linked return

A linked return references the original completed transaction line being reversed.

Conceptually:

```text
return_line.original_transaction_line_id
```

or equivalent.

The original line supplies authoritative historical facts such as:

* merchandise identity;
* exact inventory-unit identity where applicable;
* original quantity;
* selling price;
* price-override result;
* completed discounts;
* transaction-discount allocations;
* tax components;
* inventory effect;
* original tender history through the transaction.

Linked return is the preferred return path. 

---

# 8. Why linkage matters

A product identifier alone cannot prove the economics of an original sale.

For example:

```text
Current price:        $20
Original selling:     $15
Original discount:     $2
Original net:         $13
Original tax:        $0.78
```

Scanning the product today proves merchandise identity.

It does **not** prove:

* which price the customer paid;
* which discount they received;
* what tax they paid;
* how much quantity has already been returned;
* which tender was originally used.

The original completed line does.

---

# 9. Original transaction remains immutable

Creating a linked return does not update the original line to reduce:

```text
quantity
sales amount
discount amount
tax amount
```

The original transaction stays unchanged.

Returnability is determined from the original fact plus completed reversals.

---

# 10. Remaining returnable quantity

For a linked quantity-tracked sale line:

```text
remaining_returnable_quantity
=
original completed quantity
-
quantity already returned by completed linked returns
-
other completed reversals that consume returnability
```

The exact treatment of post-void/reversal operations belongs to their future specification.

The central invariant is:

```text
completed return quantity
<=
remaining returnable quantity
```

---

# 11. Only completed returns consume returnability

Working or cancelled return transactions do not permanently consume the original line's returnable quantity.

Conceptually:

```text
return line added
→ provisional claim

return transaction cancelled
→ no historical quantity consumed

return transaction completed
→ returned quantity consumed
```

Local reservation/claim mechanics may be required to prevent simultaneous working returns, but historical returnability changes only through completed business facts.

---

# 12. Full return

A full linked return reverses the complete remaining returnable quantity of the original line.

When the entire original line has been returned:

```text
remaining_returnable_quantity = 0
```

Additional ordinary linked returns against that original quantity are prohibited.

---

# 13. Partial return

A linked return may reverse less than the original quantity where the merchandise tracking model permits it.

Example:

```text
Original:
Qty 3

Return #1:
Qty 1

Remaining:
Qty 2
```

A later return may consume the remaining quantity.

---

# 14. Individually tracked return

An individually tracked original sale line always has:

```text
quantity = 1
```

and identifies the exact inventory unit.

A linked return must therefore identify the same exact unit.

Conceptually:

```text
Original:
Variant A
Inventory Unit 220-X
Qty 1

Return:
Variant A
Inventory Unit 220-X
Qty 1
```

ShelfSense must not substitute another unit of the same variant. 

---

# 15. Individually tracked returnability

An exact unit sold on a completed line can ordinarily be returned only once through normal linked-return semantics.

After its completed linked return:

```text
remaining returnable quantity = 0
```

A later attempted return of the same original unit must be rejected or reconciled as a duplicate/conflict.

---

# 16. Historical financial reversal

A linked return reverses what actually happened on the original sale.

It does not calculate what the merchandise would sell for now.

The return derives its financial basis from:

```text
original selling price
-
historical discounts
+
historical tax
```

for the returned quantity.

---

# 17. Historical selling price

Pricing for a linked return begins with the original completed **selling price**.

Example:

```text
Original reference price: $20
Original selling price:   $16
Current regular price:    $22
```

Return basis:

```text
$16
```

not:

```text
$20
```

and not:

```text
$22
```

The original price override, if any, is already reflected in the historical selling price.

---

# 18. Reference-price variance is not separately refunded

Suppose:

```text
Reference price: $20
Selling price:   $16
```

The customer only paid against the `$16` selling basis.

The `$4` override variance is an internal pricing/reporting fact.

It does not create another `$4` refund entitlement.

---

# 19. Historical discounts

A linked return reverses the historical discount value assigned to the returned quantity.

It does not run the returned line through current:

* manual discount rules;
* promotions;
* membership programs;
* employee programs.

The completed original discount allocations are authoritative.

---

# 20. No ordinary promotion requalification

ShelfSense does not ordinarily ask:

> Would the original customer still have qualified for this promotion if they had originally bought only what they kept?

Instead:

```text
original historical allocation
        ↓
proportional/deterministic reversal
```

The consolidated design specifically rejects routine retroactive promotion requalification/clawback. 

Advanced clawback behavior, if needed later, must be designed explicitly.

---

# 21. Historical transaction-discount allocation

A transaction-level discount remains logically transaction-scoped, but its completed allocations determine the return basis of individual lines.

Example:

```text
Original $10 transaction discount:

Line A allocation = $6
Line B allocation = $4
```

Returning all of Line A reverses the historical `$6` assigned to that line.

ShelfSense does not redistribute the original `$10` across the merchandise the customer kept.

---

# 22. Partial-return discount cents

When an original multi-quantity line contains indivisible historical discount cents, partial returns consume those cents deterministically.

Invariant:

```text
Σ historical discount reversed
<=
original completed discount allocation
```

When all original quantity has been returned:

```text
Σ reversed discount
=
original completed discount allocation
```

exactly.

The precise residual-cent rule belongs to the shared calculation contract.

---

# 23. Historical tax

A linked return reverses the original completed tax components.

It does not run the return through today's tax rules.

Example:

```text
Original:
State Tax 6%   → $0.96
```

Current tax rate:

```text
7%
```

Full linked return reverses:

```text
$0.96
```

not a newly calculated 7% amount.

---

# 24. Component-level tax reversal

Each original completed tax component is reversed independently.

For example:

```text
Original:
State Sales Tax      $0.96
Food/Beverage Tax    $0.20
```

Full return reverses:

```text
State Sales Tax      $0.96
Food/Beverage Tax    $0.20
```

Historical component identity remains available for reporting.

---

# 25. Partial-return tax cents

Partial returns consume historical tax cents deterministically.

For an original tax component:

```text
Σ tax reversed
<=
original completed component tax
```

and after complete return of all original quantity:

```text
Σ tax reversed
=
original completed component tax
```

exactly.

Current rate calculation must not be used to resolve residual cents.

---

# 26. Return financial amount

Conceptually, the value contributed by a linked return line derives from:

```text
historical selling amount
-
historical discount reversal
+
historical tax reversal
```

for the returned quantity.

The return line contributes that value in the `return` economic direction.

Exact signed arithmetic representation belongs to the calculation contract.

---

# 27. Historical reversal must reconcile

A full return of an original line must reverse the original customer financial effect exactly.

Ignoring later unrelated business actions:

```text
full historical return value
=
original completed line customer value
```

No cent may be lost through:

* discount allocation;
* tax allocation;
* rounding;
* repeated partial returns.

---

# 28. Inventory reversal

A completed merchandise return reverses the original sale's inventory effect.

The POS return establishes the physical fact:

> Merchandise previously sold has been returned into store custody.

The Inventory domain owns the resulting authoritative inventory records.

---

# 29. Quantity-tracked inventory

For quantity-tracked merchandise:

```text
completed sale
→ decreases on-hand

completed linked return
→ restores returned quantity to on-hand
```

The return does not create an unrelated inventory adjustment.

Its inventory effect is causally linked to the POS return.

---

# 30. Individually tracked inventory

For individually tracked merchandise:

```text
completed sale
→ exact unit leaves inventory custody/sellable stock

completed linked return
→ exact original unit returns to store inventory
```

ShelfSense never replaces the returned unit with another unit of the same variant.

---

# 31. Non-inventory merchandise

A recognized non-inventory merchandise return reverses the financial sale but has no inventory effect.

It remains a merchandise return because ShelfSense knows the merchandise identity.

---

# 32. Open-ring return

A linked return of an original open-ring line may reverse the historical financial facts of that line.

Because the original open ring had no known merchandise identity:

```text
inventory effect = none
```

The return must not invent a product variant after the fact.

---

# 33. No POS return disposition

ShelfSense does **not** ask the cashier to select:

```text
return_to_stock
damaged
inspection_required
return_to_vendor
discard
```

as part of the POS return.

The newer POS design explicitly removed return disposition from checkout. 

---

# 34. Why disposition is separate

The POS return answers:

> Did the physical merchandise come back from the customer?

If yes, the return reverses the original inventory effect.

If staff then determine that the item is:

* damaged;
* unsellable;
* quarantined;
* awaiting RTV;
* discarded;

that is a subsequent Inventory workflow.

This keeps customer return economics separate from inventory-condition management.

---

# 35. Inventory availability after return

The exact post-return sellability status belongs to Inventory Integration.

The key POS invariant is:

> **The recognized physical return restores the original inventory custody/on-hand effect; subsequent availability classification is an inventory concern.**

POS must not silently destroy inventory because the cashier judges it damaged.

---

# 36. Refund

A return line establishes customer value owed through its economic reversal.

A **refund tender** settles that resulting negative transaction net.

Conceptually:

```text
return line(s)
        ↓
transaction net < 0
        ↓
refund tender(s)
```

Returns determines eligibility/policy.

Tenders records the settlement fact.

---

# 37. Return does not necessarily produce refund tender

A transaction may contain both return and sale lines.

Example:

```text
Returned item     $20
New item          $30
                  ---
Customer owes     $10
```

There is no customer refund tender.

Instead:

```text
payment tender = $10
```

The return still occurred and remains separately reportable.

---

# 38. Even exchange

Example:

```text
Return value      $20
New sale value    $20
                  ---
Net                $0
```

No tender is required.

The transaction still records:

* gross return activity;
* gross sale activity;
* inventory reversal;
* new sale inventory effect.

---

# 39. Net customer refund

Example:

```text
Return value      $30
New sale value    $10
                  ---
Customer owed     $20
```

The transaction is settled through eligible:

```text
refund tender(s) = $20
```

---

# 40. Original tender history

For a linked return, ShelfSense preserves access to the original transaction's tender history.

That history may inform:

* recommended refund method;
* allowed refund methods;
* approval requirements;
* external reconciliation.

The original tender itself is not edited or partially rewritten by the return.

---

# 41. No required proportional refund across original tenders

Suppose the original sale used:

```text
Cash $40
Card $60
```

A `$20` partial return does not inherently require:

```text
Cash refund $8
Card refund $12
```

The existing return model explicitly does not require mathematically proportional refund across original tenders. 

Refund-selection policy determines eligible methods.

---

# 42. Refund capability versus refund policy

Tenders owns whether a tender type supports refund direction.

Returns owns whether that tender is appropriate for a specific return.

For example:

```text
Cash
refund capable = yes
```

does not necessarily mean every return may be refunded in Cash.

---

# 43. Alternate refund method

Using a refund method different from the recommended/original-compatible method may be a controlled action.

Possible outcome:

```text
direct
approval_required
prohibited
```

according to Approval policy.

Returns supplies the proposed refund context.

Approvals owns authorization.

---

# 44. Card refund

Where Card refund is used:

* the external processor performs the actual card refund;
* ShelfSense records the resulting tender/reference;
* ShelfSense does not pretend to be the card processor.

If the external refund succeeds but POS completion fails, the unresolved-external-tender rules from Tenders apply.

---

# 45. Store Credit refund

Store Credit is a Stored Value refund destination.

A completed refund to Store Credit:

```text
direction = refund
```

and results in an authoritative Stored Value credit.

Its exact atomic protocol belongs to the Stored Value contract.

---

# 46. Linked-return authorization

A normal linked return should require the permission appropriate to linked-return processing.

Additional Approval policy may consider factors such as:

* return age;
* refund amount;
* refund tender;
* policy exceptions.

The exact return-window and threshold rules remain configurable/pending.

---

# 47. Return reason

ShelfSense may require structured return reasons for:

* reporting;
* fraud/loss prevention;
* operational analysis.

Examples might eventually include:

```text
changed mind
defective
duplicate purchase
wrong item
```

The exact catalog is not locked here.

Reason and approval remain independent concepts.

---

# 48. Return eligibility

The return domain must eventually evaluate eligibility using explicit policy.

Potential inputs include:

* original transaction date;
* elapsed time;
* merchandise class;
* line type;
* returnable quantity;
* exact-unit identity;
* original tender;
* customer context;
* return reason.

This specification deliberately does not invent initial policy values such as “30 days.”

Those belong to configuration/product policy.

---

# 49. Eligibility outcome versus approval outcome

Return eligibility and Approval policy should remain conceptually distinct.

For example:

```text
return within normal policy
→ eligible
→ direct

outside normal window
→ exception candidate
→ approval_required

non-returnable merchandise
→ prohibited
```

The exact mapping belongs to the eventual return-policy model.

---

# 50. Returnability snapshots

If return eligibility depends on merchandise policy that may change after sale, ShelfSense should eventually preserve enough original policy context to determine historical/customer rights correctly.

This could include:

```text
return-policy identity/version
```

or equivalent.

The exact return-policy model remains pending.

---

# 51. Unlinked return

An unlinked return has no authoritative original completed sale-line reference.

It is therefore an **exception workflow**, not merely another way of searching for the same return. 

---

# 52. What an unlinked return cannot prove

Without an original line, ShelfSense cannot automatically prove:

* whether ShelfSense originally sold the item;
* original quantity;
* original selling price;
* original price override;
* historical discounts;
* historical tax;
* previous returns;
* original tender;
* exact original inventory effect.

Even when current merchandise identity is known, historical economics are not.

---

# 53. Unlinked return is not current-price historical reversal

ShelfSense must not simply do:

```text
no receipt
→ current regular price
→ pretend that was original selling price
```

Current price is not evidence of historical sale value.

The organization must explicitly choose the refund-basis policy for unlinked returns.

---

# 54. Unlinked-return refund basis is pending

Possible future policy might use:

* documented current price;
* lowest recent price;
* manager-entered value;
* store-credit-only basis;
* another defined method.

This specification does not choose among them.

The choice must be explicit before unlinked returns are implemented.

---

# 55. Unlinked-return tax is also exceptional

Without an original sale line, there are no authoritative historical tax components to reverse.

Therefore unlinked-return tax behavior must be explicitly defined with the unlinked refund-basis policy.

ShelfSense must not pretend current tax calculation is equivalent to historical reversal.

---

# 56. Unlinked-return discounts are unknown

Likewise, ShelfSense cannot know whether the customer originally received:

* no discount;
* manual discount;
* promotion;
* transaction-level allocation.

An unlinked return must not fabricate historical discount detail.

---

# 57. Unlinked return requires stronger control

Because historical evidence is weaker, unlinked returns should generally require stronger:

* permission;
* reason;
* approval;

than ordinary linked returns.

The exact thresholds/policy belong to Approvals and return policy.

---

# 58. Unlinked individually tracked merchandise

An exact inventory-unit identifier may provide useful evidence, but absence of an original transaction-line link still leaves unresolved historical questions.

Whether ShelfSense permits an unlinked return of individually tracked merchandise, and under what authority, must be explicitly decided before implementation.

It must not substitute another inventory unit or fabricate original sale history.

---

# 59. Exchanges

An exchange does not require a special transaction type.

Conceptually:

```text
Transaction
├── Return line(s)
└── Sale line(s)
```

Each side keeps its own direction and historical/current calculation rules.

---

# 60. Exchange pricing

Return lines use:

```text
historical selling price
historical discounts
```

New sale lines use:

```text
current resolved selling price
current applicable discounts
```

These may differ substantially.

ShelfSense does not force equal merchandise values simply because the workflow is called an exchange.

---

# 61. Exchange tax

Return lines:

```text
reverse historical tax components
```

Sale lines:

```text
calculate current tax
```

An exchange can therefore legitimately contain different tax rates/configuration versions on its return and sale portions.

---

# 62. Exchange inventory

Return lines reverse their original inventory effects.

Sale lines create current sale inventory effects.

Both must commit atomically with transaction completion.

---

# 63. Exchange reporting

An exchange must preserve gross economic activity.

Example:

```text
Return       $20
New sale     $25
Net payment   $5
```

Reporting should retain:

```text
gross returns = $20
gross sales   = $25
```

rather than reporting merely:

```text
net sale = $5
```

The consolidated return design explicitly requires gross sale/return visibility. 

---

# 64. Atomic return completion

Return completion follows the same atomicity principle as ordinary sales.

Conceptually:

```text
validate returnability
validate historical reversal
validate current sale lines if exchange
validate approvals
validate settlement/refund
        ↓
BEGIN SQLITE
        ↓
freeze return lines
freeze historical price/discount/tax reversal
freeze refund/payment tenders
record inventory consequences
record applicable approvals
assign transaction/receipt completion facts
create durable outbound operation
mark completed
        ↓
COMMIT
```

A completed return must not exist with only some of its required effects.

---

# 65. Completion invariant

Where applicable, these become one completed operation:

```text
return line
financial reversal
historical discount reversal
historical tax reversal
refund/payment tender
inventory reversal
approval evidence
outbox operation
```

The consolidated design explicitly requires return completion to be immutable and atomic. 

---

# 66. Crash before return commit

If local completion has not committed:

* the return is not completed;
* original returnable quantity is not historically consumed;
* no completed inventory reversal exists;
* no completed refund tender exists within ShelfSense.

External tender activity may require separate resolution if it already occurred.

---

# 67. Crash after return commit

If local commit succeeded:

* return remains completed;
* original returnability has been consumed;
* historical reversal remains fixed;
* inventory consequences remain recorded;
* outbox operation remains available;
* receipt/refund documentation can be reproduced.

Printer or network failure does not reopen the return.

---

# 68. Completed return immutability

After completion:

* original-line linkage cannot change;
* returned quantity cannot change;
* historical selling-price basis cannot change;
* discount reversal cannot change;
* tax reversal cannot change;
* exact unit cannot change;
* refund tender cannot be edited.

Corrections require additional explicit business facts.

---

# 69. Receipt identity

A completed return or exchange is itself a completed POS transaction and receives the applicable permanent receipt identity.

It does not reuse the original sale receipt identity as its own receipt.

The return may reference/display the original receipt as appropriate.

---

# 70. Return receipt

A return receipt should be reproducible from completed return facts.

It may show:

* returned merchandise;
* quantities;
* historical selling amounts;
* reversed discounts;
* reversed tax;
* sale items in an exchange;
* net amount;
* refund/payment tender;
* original receipt reference where applicable.

Exact layout belongs to Receipts.

---

# 71. Historical receipt does not change

Processing a return does not modify/reprint the original receipt as if the original sale had contained fewer items.

The original receipt continues to document the original sale.

The return receipt documents the later reversal.

---

# 72. Return activity/audit

ShelfSense should preserve meaningful return activity such as:

* original transaction/line selected;
* return quantity selected;
* return reason;
* exception requested;
* approval granted;
* refund method selected;
* return completed.

The completed return records remain authoritative; activity history is explanatory.

---

# 73. Reporting

Return reporting should support dimensions such as:

* store;
* workstation;
* business date;
* cashier;
* approver;
* original transaction;
* original business date;
* merchandise;
* department;
* inventory unit;
* return reason;
* linked/unlinked;
* refund tender;
* online/offline context.

---

# 74. Gross versus net reporting

ShelfSense should preserve separately:

```text
gross sales
gross returns
net sales
```

Return activity should not merely be netted invisibly into sales totals.

This is especially important for exchange reporting.

---

# 75. Historical component reporting

Return reporting should allow historical reversals to remain attributable to the original:

* price basis;
* discounts/programs;
* tax components;
* department/classification;
* inventory identity.

Current master data must not rewrite those dimensions.

---

# 76. Offline returns are higher risk than offline sales

Ordinary quantity sales can often be reconciled even when multiple terminals sell beyond available stock.

Returns are different because duplicate offline returns can create direct customer-value loss.

Example:

```text
Original line returnable = 1

Offline Terminal A
→ refunds it

Offline Terminal B
→ refunds it again
```

That cannot be treated casually as an ordinary negative-inventory condition.

---

# 77. Conservative initial offline-return policy

Initial offline return capability should therefore be narrower than ordinary sale capability.

A linked return may be permitted offline only when the workstation has sufficiently reliable evidence of:

* original completed sale;
* original line;
* remaining returnable quantity;
* historical financial components;
* exact unit identity where applicable;
* applicable authorization state.

This conservative approach is already present in the consolidated design. 

---

# 78. Uncertain return history requires authority

Where the workstation cannot reliably know whether the original line has already been returned elsewhere, the initial behavior should require central connectivity rather than risk duplicate monetary refund.

This is particularly relevant to:

* transactions originated on another workstation;
* long-offline workstations;
* unlinked returns;
* uncertain exact-unit return state.

---

# 79. Unlinked returns should initially require connectivity

Because unlinked returns already lack authoritative sale history and have elevated fraud/double-refund risk:

> **Initial unlinked-return behavior should require central connectivity.**

Any future offline unlinked return would require an explicit bounded-risk design.

---

# 80. Offline return synchronization

A locally completed permitted return produces the same durable originating-operation model as a sale.

The server:

* authenticates the installation;
* validates structure;
* validates idempotency;
* evaluates central returnability/conflicts;
* preserves the originating return;
* applies allowed authoritative secondary effects;
* returns the applicable reconciliation result.

---

# 81. Duplicate operation delivery

Retrying the **same** return operation must remain idempotent.

If the server already accepted:

```text
return operation R
```

then receiving R again must not:

* refund again;
* restore inventory again;
* consume returnability again.

This is ordinary transport idempotency.

---

# 82. Different duplicate return operations are a business conflict

Transport duplication is different from:

```text
Terminal A creates Return A
Terminal B creates Return B
both target the same remaining original quantity
```

Those are two distinct operations.

They cannot be solved merely through idempotency keys.

They require return-specific reconciliation/conflict policy.

---

# 83. Return conflict handling

Potential conflicts include:

* quantity already returned elsewhere;
* exact unit already returned;
* original transaction post-voided;
* stale refund policy;
* stale actor authority;
* duplicate cross-terminal refund;
* unavailable authoritative stored-value/card outcome.

Reconciliation owns outcome classification.

Returns owns what historical relationship the operation claims.

---

# 84. Preserve originating return facts

If an offline return completed locally and later conflicts centrally, ShelfSense must not silently rewrite:

* returned quantity;
* cashier;
* refund tender;
* exact unit;
* historical price/tax;
* original-line linkage.

The conflict must remain visible and be resolved through an explicit reconciliation/correction process.

---

# 85. Return and post-void distinction

A return means:

> Merchandise/value came back after a legitimate completed sale.

A post-void means:

> The original completed transaction itself should be reversed because its completion was erroneous.

Examples:

```text
Customer brings book back next week
→ return
```

```text
Cashier accidentally completed transaction twice
→ potential post-void
```

These must not be modeled as the same workflow.

---

# 86. Post-void remains pending

Before post-void is implemented, ShelfSense must define:

* eligible transaction types;
* required authority;
* tender reversal requirements;
* external Card behavior;
* stored-value behavior;
* inventory reversal;
* cash reporting;
* Z/business-date/reporting amendments;
* interaction with already-returned lines.

This specification only establishes that ordinary Returns does not replace that concept.

---

# 87. Conceptual linked-return model

Without locking physical schema:

```text
Return Transaction Line
│
├── direction = return
├── line_type
├── quantity
│
├── original_transaction_line
│
├── merchandise identity
├── inventory_unit identity
│
├── historical selling-price basis
├── historical discount reversal
├── historical tax reversal
│
├── return reason/context
│
└── approval relationship where required
```

The precise distribution between line fields and associated reversal records belongs to schema/contract design.

---

# 88. Conceptual returnability model

Conceptually:

```text
Original Completed Line
│
├── original quantity
│
├── Completed Return 1
│     └── returned quantity
│
├── Completed Return 2
│     └── returned quantity
│
└── Remaining Returnability
      =
      original
      - completed reversals
```

Returnability should be derivable/rebuildable from authoritative historical facts rather than relying solely on an independently mutable counter.

A maintained projection may be used for performance/concurrency.

---

# 89. Domain ownership

## Returns owns

* linked versus unlinked distinction;
* original-line relationship;
* returnability;
* return quantity;
* historical-reversal semantics;
* exchange semantics;
* return eligibility framework;
* offline-return policy;
* return-specific conflict semantics;
* return reason/context.

## Transaction Lines owns

* line type;
* explicit return direction;
* positive quantity;
* exact-unit association.

## Pricing owns

* meaning of original reference/selling prices.

## Discounts owns

* historical discount allocation/reversal rules.

## Tax owns

* historical component reversal.

## Tenders owns

* refund settlement facts and capabilities.

## Approvals owns

* controlled return/refund exceptions.

## Inventory Integration owns

* authoritative inventory reversal;
* exact-unit state;
* returned stock availability after custody restoration.

## Reconciliation owns

* central handling of stale/conflicting return state.

---

# 90. Phase 6.4 initial delivery

Before implementation, finalize ADR-016 and lock the remaining exception policies.

The core Phase 6.4 implementation should include:

### Linked returns

* original receipt/transaction lookup;
* original-line selection;
* remaining returnable quantity;
* quantity-tracked returns;
* exact-unit returns;
* historical selling-price reversal;
* historical discount reversal;
* historical tax reversal;
* inventory reversal.

### Partial returns

* deterministic historical cents;
* cumulative returnability enforcement.

### Refunds

* refund-enabled tender selection;
* original-tender context;
* alternate-method approval where required.

### Exchanges

* mixed return and sale lines;
* net payment/refund;
* gross reporting.

### Authorization

* return permissions;
* reasons;
* exception approvals.

### Synchronization

* idempotent return operation;
* central returnability checks;
* conflict/reconciliation handling.

---

# 91. Recommended initial unlinked-return scope

Unlinked returns should be treated as an exception extension within or after the linked-return implementation.

Before enabling them, explicitly define:

* refund basis;
* tax treatment;
* inventory treatment;
* allowed merchandise types;
* refund tender restrictions;
* connectivity requirement;
* reason;
* approval policy;
* fraud/reporting treatment.

Do not implement “no receipt return” merely by removing `original_transaction_line_id` from the linked workflow.

---

# 92. Deferred capabilities

This specification intentionally defers:

* automatic receipt lookup by payment-card details;
* advanced return windows;
* holiday return policies;
* customer return-history scoring;
* return fraud scoring;
* promotion clawback;
* cross-channel/online-order returns;
* mail returns;
* unlinked individually tracked return policy;
* supplier/warranty returns at POS;
* post-void implementation;
* completed-tender correction.

These should extend rather than weaken the historical-reversal model.

---

# 93. Pending decisions

## 93.1 Return eligibility policy

Define:

* return windows;
* merchandise exclusions;
* store-level overrides;
* exception paths.

---

## 93.2 Return-policy snapshots

Decide whether original sales need a specific return-policy/version snapshot and how eligibility is evaluated when policy changes after purchase.

---

## 93.3 Return reasons

Define initial structured reason catalog and which return types require a reason.

---

## 93.4 Linked-return approval thresholds

Determine what ordinary returns can be performed directly and which require approval based on:

* amount;
* age;
* merchandise type;
* refund method;
* exception status.

---

## 93.5 Unlinked-return refund basis

Required before unlinked returns.

This must explicitly define how financial value is established without historical sale evidence.

---

## 93.6 Unlinked-return tax treatment

Required before unlinked returns.

Do not assume current tax rules automatically represent a historical reversal.

---

## 93.7 Unlinked inventory-unit behavior

Define whether and how individually tracked items can be accepted without authoritative original line linkage.

---

## 93.8 Refund-selection policy

Define recommendations/restrictions for:

* original Card;
* Cash;
* Store Credit;
* Check;
* Other;
* mixed original tender.

Tenders defines capability; Returns must define selection policy.

---

## 93.9 Card refund workflow

Define external processor behavior and unknown-result recovery before Card returns are production-ready.

---

## 93.10 Stored Value refund protocol

Define the atomic authoritative credit protocol before Store Credit/Gift Card refund execution.

---

## 93.11 Partial-return residual rule

Discount and Tax specs already require deterministic historical-cent consumption.

Lock the shared algorithm/fixture contract before return implementation.

---

## 93.12 Offline return freshness

Define what constitutes “sufficiently reliable” cached original-return state for offline linked returns.

Recommended bias: conservative.

---

## 93.13 Cross-workstation return claim

Determine whether online central returnability validation/reservation is required before a return workflow can be completed when the original sale came from another workstation.

---

## 93.14 Post-void

Finalize as a separate correction specification/workflow rather than overloading Returns.

---

# 94. Core invariants summary

The following rules are authoritative unless explicitly superseded:

1. **A return is a new fact; it never edits the original completed sale.**
2. **A refund is settlement of value owed to the customer, not the return itself.**
3. **An exchange is one transaction containing sale and return lines.**
4. **Post-void is distinct from an ordinary return.**
5. **Return direction is explicit and quantity remains positive.**
6. **Linked return is the preferred return path.**
7. **A linked return references the original completed sale line.**
8. **Only completed reversals consume historical returnability.**
9. **A linked return cannot exceed remaining returnable quantity.**
10. **Individually tracked returns use the exact unit originally sold.**
11. **ShelfSense never substitutes another unit of the same variant.**
12. **Linked return value uses historical selling price, not reference/current price.**
13. **Price-override variance is not an additional refund adjustment.**
14. **Linked returns reverse historical discounts.**
15. **Linked returns do not receive current promotions or manual sale discounts.**
16. **Ordinary returns do not requalify the original promotion basket.**
17. **Linked returns reverse historical tax components.**
18. **Current tax rates do not determine linked-return tax reversal.**
19. **Partial returns consume historical discount/tax cents deterministically.**
20. **Cumulative reversals cannot exceed original historical amounts.**
21. **A full return reverses the original returned portion exactly.**
22. **Quantity-tracked returns restore returned quantity to inventory custody/on-hand.**
23. **Individually tracked returns restore the exact original unit.**
24. **Non-inventory merchandise and open rings have no inventory reversal.**
25. **POS has no return-disposition field.**
26. **Damage/RTV/unsellable handling is a subsequent Inventory workflow.**
27. **Sale and return lines net before tender settlement.**
28. **Original tender history informs but does not require proportional refund allocation.**
29. **Refund capability belongs to Tenders; refund-selection policy belongs to Returns.**
30. **Unlinked return is an exception workflow with stronger control.**
31. **Unlinked returns cannot fabricate historical price, discount, tax, or tender facts.**
32. **Return completion is atomic.**
33. **Completed returns and refund tenders are immutable.**
34. **Offline returns are more conservative than ordinary offline quantity sales.**
35. **Transport retries are idempotent.**
36. **Distinct duplicate-return operations are business conflicts, not transport duplicates.**
37. **A return conflict is reconciled explicitly rather than rewriting originating history.**
38. **Gross return and gross sale activity remain separately reportable within exchanges.**

---

# 95. Acceptance examples

## Example A — full linked quantity return

Given:

```text
Original line:
Qty 2
Selling unit price = $15
```

and no prior returns,

when the customer returns both copies,

then:

* return quantity is 2;
* historical selling basis is `$30`;
* historical discounts/tax for both units are reversed;
* quantity 2 is restored through Inventory;
* remaining returnable quantity becomes 0.

---

## Example B — current price changed

Given:

```text
Original selling price = $15
Current regular price  = $20
```

when the original line is returned,

then the return uses `$15`.

Current pricing does not affect historical return value.

---

## Example C — original override

Given:

```text
Original reference = $20
Original selling   = $16
```

when the item is returned,

then historical price basis is `$16`.

ShelfSense does not refund an additional `$4` “override.”

---

## Example D — historical discount

Given:

```text
Original selling = $20
Historical discount = $4
```

when the full line is returned,

then the customer financial reversal uses the historical net merchandise basis of `$16`, plus historical tax reversal as applicable.

Current discounts are not evaluated.

---

## Example E — transaction discount allocation

Given the original transaction had:

```text
$10 transaction discount

Line A allocation = $6
Line B allocation = $4
```

when Line A is fully returned,

then `$6` of historical transaction discount is reversed with Line A.

The original `$10` is not reallocated across Line B.

---

## Example F — historical tax change

Given:

```text
Original State Tax = $0.96 at 6%
Current rate = 7%
```

when the original line is fully returned,

then `$0.96` State Tax is reversed.

---

## Example G — partial-return cents

Given:

```text
Original Qty = 3
Historical discount allocation = $1.00
Historical tax = $1.00
```

when the quantity is returned across multiple transactions,

then:

* each return consumes deterministic historical cents;
* neither cumulative discount nor tax reversal exceeds `$1.00`;
* returning all three units reverses exactly `$1.00` of each.

---

## Example H — individually tracked return

Given original sale:

```text
Variant A
Inventory Unit U-123
Qty 1
```

when a linked return occurs,

then:

* return identifies U-123;
* quantity remains 1;
* U-123 returns to inventory custody;
* another unit of Variant A cannot be substituted.

---

## Example I — damaged returned item

Given a valid linked merchandise return,

when the physical item is damaged,

then:

1. POS completes the ordinary return and inventory reversal;
2. staff use a subsequent Inventory workflow to classify/move the item appropriately.

The POS return does not use a `damaged` disposition.

---

## Example J — exchange requiring payment

Given:

```text
Historical return value = $20
New sale total          = $30
```

then:

```text
transaction net = +$10
```

and the customer supplies `$10` in payment tender.

Reporting still records both `$20` of return activity and `$30` of sale activity.

---

## Example K — even exchange

Given:

```text
return value = $20
new sale = $20
```

then:

* transaction net is zero;
* no tender is required;
* return and sale inventory effects still occur.

---

## Example L — exchange requiring refund

Given:

```text
return value = $30
new sale = $10
```

then:

```text
transaction net = -$20
```

and eligible refund tenders settle `$20`.

---

## Example M — partial return from mixed original tender

Given original sale tendered:

```text
Cash $40
Card $60
```

when a `$20` linked partial return occurs,

then ShelfSense does not inherently require:

```text
Cash refund $8
Card refund $12
```

Refund policy determines the permitted/recommended method.

---

## Example N — unlinked return

Given a customer presents merchandise without an authoritative original sale-line reference,

then ShelfSense cannot assume:

* today's price equals historical price;
* today's tax equals historical tax;
* no prior return occurred.

The operation enters the stronger unlinked-return exception workflow.

---

## Example O — offline duplicate risk

Given an original line has one remaining returnable unit,

if two disconnected workstations each possess stale state showing that unit as returnable,

then ShelfSense must not treat two distinct completed return attempts as harmless idempotent duplicates.

They are competing business operations requiring reconciliation.

---

## Example P — same operation retried

Given one return operation is successfully accepted centrally but the acknowledgment is lost,

when the workstation retries the **same operation identity**,

then:

* no second refund effect is created;
* no second inventory restoration occurs;
* returnability is not consumed twice.

---

# 96. Related workflows

This specification should eventually be referenced by:

* `workflows/returns/linked-return.md`
* `workflows/returns/partial-return.md`
* `workflows/returns/individual-unit-return.md`
* `workflows/returns/unlinked-return.md`
* `workflows/returns/exchange.md`
* `workflows/returns/post-void.md`
* `workflows/sales/complete-transaction.md`
* `workflows/tenders/card.md`
* `workflows/tenders/stored-value.md`

---

# 97. Related contracts

Returns will require exact contracts and portable fixtures for:

### Returnability

```text
original quantity
completed linked reversals
→
remaining returnable quantity
```

### Historical merchandise reversal

```text
original selling price
returned quantity
→
historical selling-value reversal
```

### Historical discounts

* full reversal;
* partial reversal;
* residual-cent consumption;
* transaction-discount allocations.

### Historical tax

* component-level full reversal;
* partial reversal;
* residual cents;
* exchange across rate changes.

### Completed return operation

Including:

```text
return transaction/line identity
original transaction-line identity
returned quantity
merchandise/unit identity
historical pricing facts
discount reversals
tax reversals
refund/payment tenders
approval evidence
inventory consequence
```

### Offline conflict handling

Distinguish:

* retry of identical operation;
* competing return of already-consumed quantity;
* exact-unit duplicate return;
* stale authority/policy.

### Unlinked return

A separate contract should not be finalized until its refund-basis, tax, inventory, and authorization policies are decided.

The Returns domain defines **what ShelfSense is reversing and why**.

Those contracts define **how Rails and the POS workstation preserve that historical reversal exactly and prevent duplicate financial/inventory effects**.
