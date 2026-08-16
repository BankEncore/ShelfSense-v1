# POS Domain Specification: Discounts

**Design status:** Core discount representation and calculation sequence decided; promotion qualification and some eligibility/stacking policies remain pending
**Implementation status:** Planned primarily for Phase 6.3
**Contract foundation:** Phase 4 architecture must leave room for completed discount facts
**Initial delivery:** Phase 6.3 — Discounts and Promotions Foundation
**Related specifications:** Transactions, Transaction Lines, Pricing, Approvals, Tax, Tenders, Returns, Receipts, Reporting
**Related workflows:** Apply Line Discount, Apply Transaction Discount, Apply Coupon, Price Override, Linked Return, Exchange

---

## 1. Purpose

This specification defines the ShelfSense POS discount domain.

It establishes:

* what constitutes a discount;
* how discounts differ from price overrides and promotions;
* line-level versus transaction-level discounts;
* fixed-amount versus percentage discounts;
* discount sources;
* calculation order;
* discount stacking;
* eligibility;
* transaction-level discount allocation;
* deterministic cent handling;
* discount limits;
* manual discount authorization;
* promotion and coupon relationships;
* completed discount snapshots;
* return and partial-return behavior;
* receipt presentation;
* reporting requirements;
* offline behavior.

This specification does **not** define:

* reference-price resolution;
* price-override behavior;
* tax-rate/rule calculation;
* approval thresholds;
* promotion qualification rules;
* coupon campaign management;
* customer/member eligibility;
* tender processing;
* return eligibility.

Those belong to their owning specifications.

---

# 2. Governing distinction

ShelfSense distinguishes three related but different concepts:

```text
Price override
    changes the selling price

Discount
    reduces the amount charged from the selling price

Promotion
    is a rule/program that causes discount(s) to be applied
```

These concepts must not be collapsed into a generic “price adjustment.”

The governing sequence is:

```text
resolve reference price
        ↓
optional price override
        ↓
selling price
        ↓
ordered line-level discounts
        ↓
ordered transaction-level discount allocations
        ↓
net merchandise amount
        ↓
tax
```

This sequencing is part of the established POS design.

---

# 3. Discount definition

A discount is a reduction in the amount charged for eligible sale merchandise after the selling price has been established.

A discount therefore does not alter:

```text
reference_unit_price
```

or:

```text
selling_unit_price
```

Instead, it reduces the financial basis derived from the selling price.

Example:

```text
Reference price:       $20.00
Selling price:         $18.00   # override
Discount:               $3.00
Net merchandise:       $15.00
```

ShelfSense preserves all three amounts independently.

---

# 4. Why discount and override remain separate

Consider two transactions.

## Transaction A — price mismatch

```text
Reference price: $20
Selling price:   $18
Discount:         $0
```

The cashier honored an alternate actual selling price.

## Transaction B — customer discount

```text
Reference price: $20
Selling price:   $20
Discount:         $2
```

The merchandise sold at its normal price but the customer received a recognized discount.

Both customers pay `$18` before tax, but the internal business facts differ.

ShelfSense must preserve that distinction for:

* loss prevention;
* promotion analysis;
* margin reporting;
* employee/member reporting;
* return calculations;
* approvals;
* receipt presentation.

---

# 5. Discount scopes

ShelfSense supports two primary scopes:

```text
line
transaction
```

These describe where the customer-facing adjustment originates.

They do not necessarily describe where its financial effect must ultimately be stored.

---

# 6. Line-level discount

A line-level discount applies directly to one eligible sale line.

Examples:

```text
20% off this book
```

or:

```text
$5 off this item
```

Conceptually:

```text
Transaction Line
      ↓
Line Discount
```

The line discount directly reduces that line's merchandise amount.

---

# 7. Transaction-level discount

A transaction-level discount expresses a basket-level customer adjustment.

Examples:

```text
10% off your purchase
```

or:

```text
$10 off this transaction
```

Conceptually:

```text
Transaction
      ↓
Transaction Discount
      ↓
financial allocation across eligible lines
```

The adjustment remains logically one transaction-level discount even though ShelfSense allocates its financial effect to individual eligible lines internally.

The existing design explicitly requires this distinction so a cashier does not have to simulate one basket-level decision by manually editing each line.

---

# 8. Why transaction discounts require allocation

A transaction discount cannot remain only as an unallocated transaction total.

Its financial effect must be assigned to eligible lines because ShelfSense needs line-level amounts for:

* tax;
* department reporting;
* margin analysis;
* financial posting;
* partial returns;
* full returns;
* merchandise reporting.

Therefore:

> **A transaction discount remains one logical adjustment but has deterministic line allocations.**

---

# 9. Discount method

The initial discount model should support at least:

```text
fixed_amount
percentage
```

Additional methods should be introduced only explicitly.

---

# 10. Percentage discount

A percentage discount defines a percentage reduction against the applicable current discount basis.

Conceptually:

```text
percentage = 10%
basis      = $20.00
discount   = $2.00
```

ShelfSense should preserve both:

```text
configured/requested percentage
```

and:

```text
actual discount amount in cents
```

because cents are the authoritative financial result.

---

# 11. Fixed line discount

For a line-level fixed discount:

> **The fixed amount means an amount off the entire line total.**

Example:

```text
Qty:                 3
Selling unit price: $10
Line value:         $30
Fixed line discount: $5
Net line amount:    $25
```

It should not silently mean:

```text
$5 off each unit
```

A future `fixed_per_unit` method, if needed, must be explicit rather than inferred.

This behavior follows the current consolidated design.

---

# 12. Fixed transaction discount

A fixed transaction discount reduces the eligible transaction merchandise basis by a specified amount.

Example:

```text
Eligible merchandise: $75
Transaction discount: $10
```

The customer-facing adjustment is:

```text
$10 off transaction
```

Internally, the `$10` is allocated to eligible sale lines according to the allocation contract.

---

# 13. Discount source

Discount scope and discount source are independent concepts.

### Scope

```text
line
transaction
```

### Source

Potential sources include:

```text
manual
promotion
coupon
member
employee
other
```

The exact enum names are not locked here.

For example:

```text
scope  = line
source = promotion
```

and:

```text
scope  = transaction
source = manual
```

are both valid.

---

# 14. Manual discount

A manual discount is an explicit cashier-requested adjustment.

Manual discounts are controlled POS actions.

They may require:

* performer permission;
* structured reason;
* policy evaluation;
* second-actor approval.

Approvals owns that authorization behavior.

Discounts owns:

* requested method;
* requested value;
* calculated amount;
* scope;
* eligibility;
* financial effect.

---

# 15. Automatic discount

An automatic discount is produced by a recognized rule or program without a cashier manually entering the discount value.

Examples could eventually include:

* scheduled promotion;
* member benefit;
* employee program;
* coupon qualification.

Automatic discounts should still create ordinary completed discount facts.

The financial representation should not depend on whether the adjustment was manually or automatically generated.

---

# 16. Promotion definition

A promotion is a business rule or program that causes one or more discounts.

For example:

```text
Promotion:
20% off selected fiction
```

may produce:

```text
Line Discount
source = promotion
percentage = 20%
```

The promotion itself may have:

* identity;
* name;
* campaign dates;
* eligibility rules;
* stacking policy.

Those qualification rules are outside the initial Discount domain.

The resulting financial discount belongs here.

---

# 17. Promotion identity

Where a discount originates from a promotion, completed history should preserve enough information to explain:

> Which promotion caused this financial adjustment?

Conceptually:

```text
promotion_id
promotion snapshot/version
```

as appropriate.

The exact schema remains implementation-specific.

---

# 18. Discount calculation order

Multiple financial adjustment stages must execute in a defined sequence.

The current default order is:

```text
1. reference price resolution
2. explicit price override
3. automatic line promotions
4. manual line discounts
5. transaction-level discounts
6. tax
```

This ordering is already established as the current default in the consolidated design.

If future discount sources require additional ordering classes, they must define them explicitly.

---

# 19. Multiple line discounts

A line may carry multiple ordered discounts.

For example:

```text
Selling amount:             $100.00

Promotion 10%:
  discount                  -$10.00
  remaining                  $90.00

Manual $5:
  discount                   -$5.00
  remaining                  $85.00
```

This is different from applying both to the original `$100` basis.

The calculation sequence must therefore be explicit and reproducible.

---

# 20. Sequential percentage discounts

Percentage discounts apply sequentially according to their calculation order.

Example:

```text
Original selling amount: $100.00

10% discount:
  -$10.00
  basis remaining = $90.00

20% subsequent discount:
  -$18.00
  basis remaining = $72.00
```

The result is not equivalent to:

```text
30% off $100
```

unless a promotion explicitly defines that behavior.

---

# 21. Discount calculation sequence

Every discount should carry enough ordering information that completed financial results are reproducible.

Conceptually:

```text
calculation_sequence
```

or equivalent ordered relationships.

The exact field representation is not locked.

---

# 22. Eligibility

A discount applies only to eligible sale merchandise.

Eligibility may depend on:

* line type;
* merchandise identity;
* department;
* product/variant;
* promotion;
* customer program;
* employee program;
* explicit manual-selection behavior.

The complete promotion eligibility system is deferred.

The core domain requires that ShelfSense can identify which lines participated in each discount.

---

# 23. Sale-direction only

New discounts apply only to:

```text
direction = sale
```

lines.

A current promotion or manual discount does not apply to return-direction lines.

The consolidated design explicitly establishes this rule.

Return lines reverse the historical discounts associated with the original sale.

---

# 24. Return lines are not newly discounted

For a return:

```text
original sale history
        ↓
historical discount reversal
```

not:

```text
current return line
        ↓
today's discount engine
```

This prevents changes in current promotions or discount policy from changing the financial basis of historical returns.

---

# 25. Open-ring eligibility

Open rings may participate in discounts when policy permits.

However, some promotion types depend on known merchandise identity and therefore cannot meaningfully qualify an open ring.

Examples:

```text
10% manager discount on transaction
```

might permit open rings.

But:

```text
20% off titles from Publisher X
```

cannot identify an open ring as eligible.

### Pending decision

Define default open-ring eligibility for:

* manual line discounts;
* manual transaction discounts;
* automatic promotions.

---

# 26. Transaction-level eligibility

A transaction-level discount may apply to all sale lines or only a subset.

For example:

```text
Transaction:
Book       $20   eligible
Gift card  $25   not eligible
Open ring  $10   maybe eligible
```

The discount's calculation basis is the sum of **eligible sale-line amounts after their line-level discounts**.

---

# 27. Transaction discount allocation basis

The normal allocation basis is:

> **Each eligible sale line's amount after its line-level discounts.**

Conceptually:

```text
eligible_line_basis
=
selling amount
-
line-level discounts
```

Transaction-level adjustments then allocate across these resulting eligible amounts.

This allocation basis is explicitly established in the consolidated design.

---

# 28. Proportional transaction allocation

A fixed transaction discount is normally allocated proportionally according to eligible line bases.

Example:

```text
Line A eligible basis = $60
Line B eligible basis = $40

Total eligible basis = $100

Transaction discount = $10
```

Before rounding:

```text
Line A allocation = $6
Line B allocation = $4
```

The logical customer adjustment remains:

```text
$10 transaction discount
```

while internal accounting retains:

```text
Line A → $6
Line B → $4
```

---

# 29. Percentage transaction discount

A transaction-level percentage discount can similarly produce line allocations.

Example:

```text
Line A eligible basis = $60
Line B eligible basis = $40

Transaction discount = 10%
```

results:

```text
Line A allocation = $6
Line B allocation = $4
```

The completed transaction should preserve:

* requested/configured percentage;
* actual aggregate cents;
* line allocations.

---

# 30. Allocation must be exact

The sum of allocations must equal the logical transaction discount exactly.

Invariant:

```text
Σ allocation_cents
=
transaction_discount_cents
```

No penny may:

* disappear;
* appear twice;
* remain unassigned.

---

# 31. Residual-cent handling

Proportional allocation can produce fractional cents.

Example:

```text
$1 discount
allocated across 3 equal $10 lines
```

cannot be represented exactly as:

```text
$0.333333...
```

ShelfSense therefore requires a deterministic residual-cent rule.

Conceptually:

```text
Line A = $0.34
Line B = $0.33
Line C = $0.33
```

The specific stable residual ordering must be locked in the machine calculation contract.

---

# 32. Stable allocation rule

The residual allocation order must not depend on unstable implementation behavior such as:

* database return order;
* hash-map order;
* UI sort changes.

It should use a documented stable key/order.

The exact rule is a pending calculation-contract decision.

---

# 33. Discount floor

Discounts must not reduce an eligible merchandise amount below zero.

For every eligible line:

```text
net merchandise amount >= 0
```

A discount must not transform merchandise into:

* negative sale value;
* tender;
* customer credit.

This constraint is explicitly part of the consolidated design.

---

# 34. Excess fixed discount

If a requested fixed discount exceeds the eligible merchandise basis, the outcome depends on the discount/program rules.

ShelfSense must not automatically turn the unused portion into:

* cash refund;
* store credit;
* another tender.

Potential behavior includes:

* cap the applicable discount;
* prohibit the request;
* define offer-specific unused-value semantics.

The particular rule belongs to the adjustment/promotion policy.

---

# 35. Zero-value merchandise after discount

A legitimate discount may reduce eligible merchandise to exactly zero where policy allows.

For example:

```text
Selling amount: $5
Discount:       $5
Net:            $0
```

This remains a sale line with zero net merchandise value after discount.

It is not:

* voided;
* removed;
* a return.

The line remains historically meaningful.

---

# 36. Discount and quantity

A line discount operates against the current eligible line basis.

Changing line quantity may therefore alter:

* line value;
* percentage discount amount;
* transaction discount allocation;
* manual fixed-discount relative effect;
* approval threshold.

Quantity changes require discount recalculation.

---

# 37. Approval invalidation after quantity change

If a manual discount required approval and quantity changes alter the financial effect, the approval must be re-evaluated.

Example:

```text
Qty 1 × $100
Approved discount = 20% = $20
```

Cashier changes:

```text
Qty 5 × $100
20% = $100
```

The existing approval cannot automatically authorize the materially larger action.

Approvals owns the exact action-binding/invalidation semantics.

---

# 38. Manual line discount action context

A controlled manual line discount may conceptually provide Approvals with:

```text
action_type = line_discount
subject = transaction_line

method
requested_percentage
requested_amount_cents
eligible_basis_cents
resulting_discount_cents
quantity
```

as applicable.

Discounts supplies these business values.

Approvals determines authorization.

---

# 39. Manual transaction discount action context

A controlled transaction-level discount may conceptually provide:

```text
action_type = transaction_discount
subject = transaction

method
requested_percentage
requested_amount_cents
eligible_basis_cents
resulting_discount_cents
eligible_line_set/context
```

The exact action contract will be defined with Approvals.

---

# 40. Basket changes after approval

A transaction-level discount approval may become invalid if the basket changes materially.

Potential material changes include:

* line added;
* line removed;
* line voided;
* quantity changed;
* selling price changed;
* line discount changed;
* eligibility changed.

Example:

```text
Approved:
10% of $100 eligible basis = $10
```

Then basket becomes:

```text
eligible basis = $500
```

The existing approval should not automatically authorize a `$50` discount.

### Governing rule

> A material change to the financial effect of an approved discount requires re-evaluation.

The exact action fingerprint fields belong to the Approval contract.

---

# 41. Reason

A manual discount may require a structured reason according to policy.

Examples might include:

* customer service;
* damaged merchandise;
* promotional accommodation;
* authorized institutional discount.

The exact reason catalog is not defined here.

Reason and second-actor approval remain independent.

---

# 42. Promotion-generated discounts and approvals

Automatic promotions normally do not require cashier second-actor approval merely because they produce discounts.

They are authorized by their centrally configured promotion rules.

However, manually forcing or overriding promotion behavior may be a distinct controlled action in the future.

That capability is not part of the initial Discount design.

---

# 43. Coupons

The word “coupon” does not determine ShelfSense's financial model.

The economic function does.

Two broad cases exist.

---

# 44. Store-funded coupon

If the coupon simply reduces what the customer owes and the store bears the reduction:

```text
coupon
→ discount
```

Example:

```text
Store coupon:
$5 off purchase
```

This creates a discount adjustment.

---

# 45. Reimbursable external coupon

If the instrument represents value that another party reimburses to the store:

```text
coupon
→ potentially Other tender
```

Example:

```text
Manufacturer reimburses store $5
```

The customer pays less cash, but economically the store receives external value.

That may be better represented as an `Other` tender rather than a discount.

The consolidated design explicitly makes this distinction.

---

# 46. Coupon classification must be configured explicitly

ShelfSense should not infer:

```text
contains word "coupon"
→ discount
```

Instead, the configured program/instrument must define its economic treatment.

This avoids accounting ambiguity.

---

# 47. Customer/member discounts

Future customer/member programs should normally produce standard discount facts.

For example:

```text
source = member
scope  = transaction
percentage = 10%
```

rather than adding permanent special columns such as:

```text
member_price_cents
```

to every transaction line.

The consolidated design currently favors ordinary discount adjustments for customer/member/employee benefits.

Whether a future program is genuinely a distinct price tier rather than a discount remains a Pricing decision.

---

# 48. Employee discounts

Employee benefits should follow the same financial representation when economically a discount:

```text
source = employee
```

The employee program determines eligibility.

Discounts owns the financial adjustment once applied.

---

# 49. Discount stacking

ShelfSense should eventually support explicit stacking rules for automatic programs.

Potential concepts include:

```text
stackable
exclusive
priority
group
```

However, the initial Phase 6.3 implementation does not need a generic promotion-expression engine.

The financial model simply needs to support multiple ordered discounts.

---

# 50. Manual stacking

Where more than one manual/automatic discount applies to the same line, ShelfSense must preserve each adjustment independently.

Do not collapse:

```text
Promotion $3
Manual $2
```

into:

```text
Discount $5
```

unless the actual business action was a single `$5` adjustment.

Separate adjustments are necessary for:

* source reporting;
* approval analysis;
* returns;
* promotion performance.

---

# 51. Completed discount fact

When the transaction completes, each applied discount becomes immutable historical information.

At minimum, depending on type/source, the completed fact should preserve:

```text
scope
method
source
sequence
configured/requested percentage
actual amount_cents
reason
promotion/program identity
performed_by
```

where applicable.

Any required approval is preserved through the Approval domain.

---

# 52. Transaction-discount allocation facts

For each completed transaction-level discount, ShelfSense must preserve its line allocations.

Conceptually:

```text
Transaction Discount
├── total amount
├── method/source
└── Allocations
    ├── Line A → x cents
    ├── Line B → y cents
    └── Line C → z cents
```

These allocations are immutable after completion.

---

# 53. Why allocation must be historical

Suppose a transaction discount is:

```text
$10 off purchase
```

and historically allocated:

```text
Line A → $6
Line B → $4
```

A later return of Line A must know that Line A received `$6` of the discount.

ShelfSense must not rerun today's basket allocation logic against the remaining transaction.

---

# 54. Returns use historical discounts

A linked return reverses the historical discount effect assigned to the returned merchandise.

It does **not** ask:

> If we recalculated the original transaction today without this item, would the customer still qualify?

The existing design explicitly rejects that retroactive requalification model for ordinary returns.

---

# 55. No routine promotion clawback

Example:

```text
Original transaction:
Buy $100
Get $10 off
```

Customer later returns a `$40` item.

Under the initial historical-reversal model, ShelfSense reverses the portion of the original `$10` allocated to that returned merchandise.

It does not automatically:

```text
recalculate original transaction
determine remaining $60 would not qualify
claw back entire promotion
```

Advanced promotion clawback, if ever required, is a distinct future feature.

---

# 56. Partial returns

Partial returns require deterministic consumption of historical discount cents.

For example:

```text
Original line:
Qty 3
Historical discount allocated to line: $1.00
```

Returning one unit cannot simply compute:

```text
$1 / 3
```

without resolving the indivisible cent.

ShelfSense needs deterministic historical per-return allocation.

---

# 57. Partial-return invariant

Across all partial returns:

```text
Σ discount reversed
<=
original historical discount
```

When all original quantity has been returned:

```text
Σ discount reversed
=
original historical discount
```

exactly.

No cent is lost or reversed twice.

The consolidated design explicitly requires cumulative partial returns never to exceed the original discount and a full return to reverse it exactly.

---

# 58. Partial-return allocation contract

The exact rule for which returned unit consumes which residual cent belongs to a portable calculation contract.

It must be:

* deterministic;
* independent of Rails/.NET implementation;
* historically reproducible.

This should be part of the return/discount golden fixture set.

---

# 59. Return-direction discount representation

A return should preserve the fact that it is reversing historical discount value rather than creating a new present-day discount.

The exact schema might represent this through:

* references to original adjustments;
* reversal allocation records;
* historical amount snapshots.

This specification does not lock the physical representation.

The business meaning must remain clear.

---

# 60. Tax relationship

Tax uses the amount after applicable discounts.

Conceptually:

```text
selling price
        ↓
line discounts
        ↓
transaction discount allocation
        ↓
taxable basis
        ↓
tax
```

Tax does not calculate against the undiscounted selling price unless a particular jurisdictional rule explicitly requires another treatment in the future.

Detailed tax law/calculation behavior belongs to `tax.md`.

---

# 61. Tax classification is not discount eligibility

These concepts must remain separate.

A line might be:

```text
taxable = yes
discount eligible = no
```

or:

```text
taxable = no
discount eligible = yes
```

Discounts must not derive eligibility from tax treatment.

---

# 62. Receipt presentation

Customer receipts may show line-level discounts adjacent to their lines.

Example:

```text
Book                         $20.00
  Member discount             -2.00
```

A transaction-level discount may appear once at the basket level:

```text
Subtotal                     $50.00
Transaction discount          -5.00
```

The receipt does not need to expose internal line allocations of the `$5` transaction discount.

This customer-facing/internal distinction is already established by the consolidated design.

---

# 63. Price override receipt distinction

If a line had:

```text
Reference price: $20
Selling price:   $18
Discount:         $2
```

the customer receipt might show:

```text
Item                         $18.00
  Discount                    -2.00
```

It should not ordinarily show:

```text
Regular price                $20.00
Price override                -2.00
Discount                      -2.00
```

unless later receipt policy explicitly chooses to expose internal override information.

---

# 64. Reporting

Discount reporting should support both **scope** and **source**.

Useful dimensions include:

* store;
* workstation;
* business date;
* Z-period;
* cashier;
* approver;
* department;
* product/variant/unit;
* discount scope;
* discount method;
* discount source;
* reason;
* promotion/program;
* percentage;
* amount;
* manual/automatic;
* online/offline context.

---

# 65. Financial reporting

ShelfSense should preserve enough information to distinguish:

```text
gross selling value
-
discounts
=
net merchandise value
```

separately from:

```text
reference-price variance
```

This allows reporting such as:

```text
Reference value:        $10,000
Selling-price variance:   -$100
Discounts:                -$500
Net merchandise:         $9,400
```

without conflating the two causes.

---

# 66. Promotion reporting

Where promotion identity exists, reporting should support:

* use count;
* discounted line count;
* total discount amount;
* affected merchandise;
* store;
* business date;
* gross eligible basis.

Advanced promotion effectiveness analytics can follow later.

---

# 67. Manual discount reporting

Manual discount reporting should support:

* performer;
* approver;
* reason;
* amount;
* percentage;
* scope;
* merchandise/department;
* store/workstation.

This is important for loss-prevention analysis.

---

# 68. Offline behavior

Manual and automatic discounts that are explicitly permitted offline must operate using locally cached:

* discount/promotion configuration;
* reason definitions;
* approval policy;
* actor permissions.

A completed offline transaction preserves the actual discounts used.

Central synchronization must not re-run current promotion eligibility and rewrite the historical transaction.

---

# 69. Stale promotion/discount configuration

Example:

```text
POS cached:
Promotion valid through today

Central:
Promotion was deactivated while POS offline
```

If the offline workstation legitimately applied the cached promotion and completed the transaction:

* historical discount remains;
* the server does not silently remove it;
* stale configuration may become a reconciliation warning/quarantine condition according to policy.

This follows the broader terminal-originated fact model.

---

# 70. Stale policy versus invalid calculation

A stale central configuration conflict is different from a structurally invalid discount.

For example:

### Stale but internally valid

```text
10% promotion
correctly calculated under cached version
```

may be reconciled as stale configuration.

### Structurally invalid

```text
reported 10% of $100 = $47
```

fails deterministic arithmetic validation.

The synchronization/reconciliation contracts should distinguish these cases.

---

# 71. Recalculation while open

While the transaction remains open, discounts may be recalculated when relevant inputs change.

Potential triggers include:

* quantity change;
* price override;
* line added/removed;
* line void;
* eligibility change;
* promotion refresh;
* customer association change;
* manual discount modification.

Any dependent transaction-level allocations must also be recalculated.

---

# 72. Manual discount removal

A manual discount may be removed while the transaction remains open.

The removal:

* restores the applicable basis;
* triggers recalculation;
* invalidates any approval that only authorized the removed action;
* remains auditable where meaningful.

After transaction completion, the historical discount cannot be removed.

---

# 73. Changing a manual discount

Changing:

```text
10%
```

to:

```text
20%
```

is a new material requested action for approval purposes.

ShelfSense should not edit the financial effect while silently retaining approval for the old value.

---

# 74. Promotion removal while open

An automatic promotion may cease to apply while the transaction is still mutable if its eligibility changes.

For example:

```text
Buy 2 eligible items
→ discount applies

void one eligible item
→ qualification no longer satisfied
→ automatic discount removed/recalculated
```

Detailed promotion qualification belongs to a later Promotion specification.

The Discount domain supports the resulting addition/removal of adjustments.

---

# 75. Suspension and recall

Suspended transactions remain mutable work, not historical pricing/discount facts.

On recall, automatic discounts may need to be re-evaluated using the configured suspend/recall refresh policy.

Manual discounts must not silently disappear.

However, their approval may require revalidation if:

* eligible basis changed;
* calculation changed;
* policy changed materially.

The exact suspended-discount refresh policy remains pending.

---

# 76. Completed discount immutability

Once the transaction completes:

* discount scope cannot change;
* method cannot change;
* source cannot change;
* percentage cannot change;
* cents cannot change;
* allocation cannot change;
* promotion identity cannot change.

Later configuration changes cannot modify historical discounts.

---

# 77. Conceptual line-discount model

Without locking schema:

```text
Line Discount
│
├── id
├── transaction_line
├── sequence
├── method
│   ├── fixed_amount
│   └── percentage
├── source
├── configured/requested value
├── actual_amount_cents
├── reason
├── promotion/program reference
├── performed_by
└── approval reference/context where required
```

Approval should preferably be represented through the shared Approval domain rather than bespoke `approved_by` semantics embedded here.

---

# 78. Conceptual transaction-discount model

```text
Transaction Discount
│
├── id
├── transaction
├── sequence
├── method
├── source
├── configured/requested value
├── eligible_basis_cents
├── actual_amount_cents
├── reason/program/performer
│
└── Allocations
    ├── transaction_line
    └── allocated_amount_cents
```

The exact schema remains implementation planning.

---

# 79. Why line allocation is not itself another discount

A transaction-discount allocation is the financial assignment of one logical adjustment.

It should not appear in reporting as separate discounts.

Example:

```text
Logical transaction discount:
$10 off

Allocations:
Line A $6
Line B $4
```

Reporting should be able to say:

```text
1 transaction discount = $10
```

not:

```text
2 discounts totaling $10
```

unless specifically reporting allocation rows.

---

# 80. Discount identity

Each durable completed logical discount should have stable identity.

This enables:

* allocation references;
* returns;
* audit;
* reporting;
* promotion attribution;
* approval association.

Allocation records likewise need stable/reliable linkage to their logical adjustment and target line.

---

# 81. Domain ownership

## Discounts owns

* discount meaning;
* line versus transaction scope;
* discount methods;
* source;
* ordering;
* eligibility representation;
* financial amount;
* transaction allocation;
* completed discount history;
* return historical-discount basis;
* coupon-as-discount semantics.

## Pricing owns

* reference price;
* selling price;
* price override.

## Approvals owns

* whether manual discount may proceed;
* direct/approval-required/prohibited;
* second actor;
* action/value binding;
* approval invalidation.

## Promotions/customer programs own

* qualification;
* eligibility rules;
* campaign/program definitions.

## Tax owns

* tax calculation on resulting taxable basis.

## Returns owns

* return eligibility;
* quantities;
* orchestration of historical reversal.

## Tenders owns

* reimbursable instruments treated as tender rather than discount.

## Receipts owns

* customer-facing display.

---

# 82. Phase 4 foundation

Phase 4 does **not** implement a production discount workflow.

However, foundational transaction/contracts should leave room for:

* completed line adjustments;
* completed transaction adjustments;
* transaction-level allocations;
* versioned financial payloads.

Golden fixtures for discounts are not required for the first cash-sale proof unless needed to validate contract extensibility.

---

# 83. Phase 5

Phase 5 explicitly has:

```text
no manual discounts
no promotions
no coupons
```

The first operational sale uses:

```text
selling price
→ tax
```

without a discount stage producing nonzero adjustments.

The architecture still preserves the future calculation stage.

---

# 84. Phase 6.3 initial delivery

Phase 6.3 should implement:

### Line discounts

* manual fixed amount;
* manual percentage;
* automatic line discount representation;
* multiple ordered adjustments.

### Transaction discounts

* manual fixed amount;
* manual percentage;
* deterministic allocations.

### Approval integration

* manual discount permission;
* reason;
* thresholds;
* second-actor approval;
* invalidation after material changes.

### Contract fixtures

* line fixed discount;
* line percentage;
* sequential discounts;
* transaction fixed allocation;
* transaction percentage allocation;
* residual-cent allocation;
* tax after discounts;
* return reversal basis.

---

# 85. Promotion engine boundary

Phase 6.3 should **not** automatically mean implementation of a generalized promotion rules engine.

It may initially support:

* manually applied adjustments;
* simple centrally defined promotions;
* explicit program-generated discounts.

More sophisticated capabilities can follow later:

* Buy X Get Y;
* mix-and-match;
* tiered thresholds;
* exclusivity groups;
* customer segmentation;
* coupon usage limits;
* campaign budgeting.

The financial Discount domain remains the same.

---

# 86. Deferred capabilities

This specification intentionally leaves room for:

* fixed amount per unit;
* buy-X-get-Y;
* quantity-break promotions;
* threshold promotions;
* free-item promotions;
* coupon usage counts;
* exclusive promotion groups;
* customer-specific qualification;
* employee program configuration;
* promotion clawback;
* complex transaction eligibility;
* external promotion engines.

None should require abandoning the underlying line/transaction adjustment model.

---

# 87. Pending decisions

## 87.1 Discount method set

Initial methods:

```text
fixed_amount
percentage
```

Confirm whether any initial business case requires:

```text
fixed_per_unit
```

before Phase 6.3.

---

## 87.2 Discount source taxonomy

Lock initial source identifiers, likely covering:

```text
manual
promotion
coupon
member
employee
other
```

without overfitting hypothetical programs.

---

## 87.3 Calculation ordering within source classes

The broad ordering is established, but exact ordering among:

* multiple automatic promotions;
* multiple manual discounts;

needs deterministic rules.

---

## 87.4 Residual-cent allocation

Define exact stable allocation rule for transaction discounts.

This is required before implementation and shared Rails/.NET fixtures.

---

## 87.5 Percentage rounding

Define exactly:

* basis;
* precision;
* rounding mode;
* stage at which cents are rounded.

Required in the shared calculation contract.

---

## 87.6 Excess fixed-discount behavior

Decide whether an excessive requested discount is:

* capped;
* prohibited;
* handled according to program-specific rule.

---

## 87.7 Open-ring eligibility

Determine default policy for:

* manual line discount;
* manual transaction discount;
* automatic promotion.

---

## 87.8 Discount reason policy

Define which manual discounts require reason independently from approval.

---

## 87.9 Discount approval thresholds

Define organization default/store override policies for:

* line percentage;
* line cents;
* transaction percentage;
* transaction cents.

Approvals owns the framework.

---

## 87.10 Transaction approval invalidation

Lock which basket changes invalidate approval for a transaction-level discount.

Recommended principle:

> Re-evaluate whenever the eligible basis, resulting discount amount, or eligible line set materially changes.

---

## 87.11 Suspended transaction refresh

Decide how automatic and manual discounts behave on recall.

---

## 87.12 Coupon program classification

When coupons are introduced, explicitly classify each program as:

```text
discount
```

or:

```text
tender
```

according to economic substance.

---

## 87.13 Promotion clawback

Initial policy is historical proportional reversal without requalification.

Any clawback behavior must be deliberately designed as a future capability.

---

# 88. Core invariants summary

The following are authoritative unless explicitly superseded:

1. **A discount reduces the amount charged from the selling price.**
2. **A discount does not change reference price or selling price.**
3. **Price override and discount remain separate business facts.**
4. **Promotions produce discounts rather than automatically redefining price.**
5. **Discount scope is line or transaction.**
6. **Discount source is separate from scope.**
7. **Initial methods are fixed amount and percentage.**
8. **A fixed line discount applies to the line total, not per unit, unless a separate method explicitly says otherwise.**
9. **Multiple discounts are ordered and sequential.**
10. **New discounts apply only to sale-direction lines.**
11. **Return lines reverse historical discounts rather than receiving current discounts.**
12. **Transaction discounts remain one logical adjustment.**
13. **Transaction discount financial effects are allocated to eligible sale lines.**
14. **Transaction allocation uses post-line-discount eligible bases by default.**
15. **Allocation is proportional unless another explicit method is defined.**
16. **Allocation cents must sum exactly to the logical transaction discount.**
17. **Residual cents follow a deterministic stable rule.**
18. **Discounts cannot reduce eligible merchandise below zero.**
19. **Unused discount value does not automatically become tender or customer credit.**
20. **Manual discounts are controlled actions subject to the Approval domain.**
21. **Reason and approval remain independent.**
22. **Material changes to an approved discount require approval re-evaluation.**
23. **Completed discounts and allocations are immutable.**
24. **Linked returns reverse historical completed discount allocation.**
25. **Partial returns never reverse more discount than originally assigned.**
26. **A full return reverses the original discount exactly.**
27. **Ordinary returns do not re-run promotion qualification against the remaining original basket.**
28. **Store-funded coupons that reduce customer obligation are discounts.**
29. **Externally reimbursable coupons may instead be tenders.**
30. **Customer/member/employee benefits normally use ordinary discount facts when economically discounts.**
31. **Customer receipts need not expose internal transaction-discount allocations.**
32. **Offline completed discounts are not centrally recalculated using current promotion configuration.**

---

# 89. Acceptance examples

## Example A — simple percentage line discount

Given:

```text
Selling amount = $20.00
Discount = 10%
```

then:

```text
Discount amount = $2.00
Net merchandise = $18.00
```

and ShelfSense preserves:

```text
percentage = 10%
actual_amount_cents = 200
```

---

## Example B — fixed line discount on quantity

Given:

```text
Qty = 3
Selling unit price = $10
Line value = $30
Fixed line discount = $5
```

then:

```text
Net line value = $25
```

not `$15`.

---

## Example C — override plus discount

Given:

```text
Reference = $20
Selling override = $18
Discount = 10%
```

then:

```text
Reference               $20.00
Selling                  $18.00
Discount                  $1.80
Net                       $16.20
```

ShelfSense preserves override variance and discount independently.

---

## Example D — sequential discounts

Given:

```text
Selling basis = $100
First discount = 10%
Second discount = 20%
```

then:

```text
First discount  = $10
Remaining       = $90

Second discount = $18
Net             = $72
```

not `$70`.

---

## Example E — transaction fixed discount allocation

Given:

```text
Line A basis = $60
Line B basis = $40
Transaction discount = $10
```

then:

```text
Line A allocation = $6
Line B allocation = $4
```

and:

```text
$6 + $4 = $10
```

---

## Example F — residual penny

Given:

```text
3 equal eligible lines
Transaction discount = $1
```

then allocation must produce exactly:

```text
$1.00 total
```

using the documented stable residual-cent rule.

Rails and .NET must produce the same line allocations.

---

## Example G — return line receives no current promotion

Given an original line completed with:

```text
Selling amount = $20
Historical discount = $4
```

and current promotion rules have changed,

when the line is returned,

then:

* return reverses the historical `$4`;
* current promotion rules are not applied to the return.

---

## Example H — partial return

Given:

```text
Original quantity = 3
Historical line discount = $1
```

when units are returned across multiple transactions,

then:

* each return consumes a deterministic portion of the historical `$1`;
* cumulative reversed discount never exceeds `$1`;
* returning all 3 units reverses exactly `$1`.

---

## Example I — approved transaction discount changes

Given:

```text
Eligible basis = $100
Requested transaction discount = 10%
Result = $10
```

and a manager approves it,

when the basket changes to:

```text
Eligible basis = $500
Same 10% = $50
```

then:

* previous approval no longer automatically satisfies the request;
* discount is recalculated;
* Approval policy is re-evaluated.

---

## Example J — discount floor

Given:

```text
Eligible line basis = $8
Requested fixed discount = $10
```

then ShelfSense must not produce:

```text
Net merchandise = -$2
```

The applicable policy determines whether the discount is capped or prohibited.

---

## Example K — store-funded coupon

Given:

```text
Store coupon = $5 off purchase
```

and the store bears the cost,

then the `$5` is represented as a discount.

---

## Example L — manufacturer reimbursable coupon

Given a customer presents a `$5` instrument and an external manufacturer reimburses the store `$5`,

then ShelfSense may represent the instrument as an `Other` tender rather than a discount.

The configured economic treatment determines the model.

---

## Example M — stale offline promotion

Given:

1. workstation cached a valid 10% promotion;
2. workstation goes offline;
3. central configuration later disables the promotion;
4. cashier completes a valid local transaction using the cached promotion;

when synchronization occurs,

then:

* historical discount remains;
* transaction is not centrally recalculated;
* stale promotion state may generate reconciliation handling.

---

# 90. Related workflows

This specification should eventually be referenced by:

* `workflows/adjustments/line-discount.md`
* `workflows/adjustments/transaction-discount.md`
* `workflows/adjustments/apply-coupon.md`
* `workflows/sales/cash-sale.md`
* `workflows/sales/complete-transaction.md`
* `workflows/sales/suspend-recall.md`
* `workflows/returns/linked-return.md`
* `workflows/returns/exchange.md`

---

# 91. Related contracts

Discounts will require exact machine contracts and golden fixtures for:

### Line discount calculation

* fixed amount;
* percentage;
* sequential discounts;
* zero floor.

### Transaction discount calculation

* eligible basis;
* fixed discount;
* percentage discount;
* proportional allocation;
* residual-cent allocation.

### Approval context

* requested line discount;
* requested transaction discount;
* material values used for approval binding.

### Completed-sale payload

* logical discount facts;
* scope/source/method;
* adjustment sequence;
* line allocations;
* promotion/program snapshots.

### Return reversal

* historical discount reversal;
* partial-return cents;
* cumulative exactness.

The domain specification defines **what a ShelfSense discount means**.

The contract specifications must define **the exact arithmetic and representation required for Rails and the POS workstation to produce identical completed results**.
