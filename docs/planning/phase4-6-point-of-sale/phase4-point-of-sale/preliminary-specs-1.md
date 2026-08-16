# POS Register Operating Model and Initial Implementation Scope

The initial Rails-native POS follows the same Register transaction and authoritative-posting model intended for a future standalone Register.

Rails may invoke the core posting boundary in-process, while a future standalone Register will submit the same class of completed operation through synchronization. The resulting authoritative central business facts must be materially equivalent regardless of client implementation.

---

# Register Operating Model

* **“Point of Sale” refers to the overall POS module. A “Register” is an individual logical cash register/workstation.** Registers are designed so they may ultimately operate independently of the core ShelfSense application.  
    
* **A Register is a durable logical identity distinct from the software installation operating it.** A future standalone installation may be replaced without creating a new Register. Only one active originating installation should normally operate for a Register at a time.  
    
* **Users may have POS-specific credentials consisting of a cashier number and PIN.** Registers receive only the authentication and authorization information necessary for POS operation; raw PINs are not replicated.  
    
* **Register authorization applies to the actor performing the operation, not merely to the Register.** Permissions, reasons, approvals, and controlled actions remain attributable to the specific cashier or approver involved.  
    
* **A Register may originate and complete POS transactions without real-time participation by the core application.** This remains the architectural model even though the initial Rails-native implementation completes through the central application.  
    
* **Transactions originate at the Register and become immutable once completed.** Corrections after completion are represented by new business facts, such as return lines or a post-void operation, rather than by modification or deletion of the original transaction.  
    
* **Only completed transactions cross the authoritative POS posting boundary as finalized commercial facts.** Working transaction state may be persisted centrally by the Rails POS or provisionally synchronized by a future standalone Register, but it remains mutable, non-final commercial state.  
    
* **Pending transaction synchronization, where supported, is provisional and remains distinct from authoritative completed transaction posting.** Pending transaction lines may contribute to `reserved` or another provisional inventory availability projection but do not post authoritative `on_hand` ledger movements until completion.  
    
* **Every Register-originated completed operation has a globally unique operation identity.** Re-delivery or retry of the same operation must not produce an additional central business effect.  
    
* **Core accepts a completed Register transaction as an originating commercial fact rather than reconstructing it from current configuration.** Core validates the submitted facts and authoritatively posts their consequences, including Inventory and reporting effects, but does not silently replace historical price, tax, discount, tender, or timing facts with current values.  
    
* **A completed transaction preserves its origin and time context.** At minimum, completed facts identify:  
    
  * operation;  
  * transaction;  
  * Store;  
  * Register;  
  * Session;  
  * performing actor;  
  * `occurred_at`;  
  * business date;  
  * central posting time.


  A later synchronization or posting timestamp does not replace `occurred_at` or change the transaction's business date.


* **Centrally mastered reference data is distinct from Register-originated operational data.** Merchandise, prices, tax rules, tender configuration, permissions, and similar configuration originate in core. Transactions, Register sessions, and Register operations originate at the POS.  
    
* **Changes to centrally mastered configuration do not retroactively alter completed Register transactions.** Completed transactions preserve the prices, discounts, tax determinations, tender facts, and other commercial context actually used at completion.  
    
* **Open and suspended transactions are working state, not completed commercial activity.** They do not contribute to completed sales, returns, tax, tender, Z, or financial totals until completion.  
    
* **A suspended transaction retains its originating Register and working history even if it is later recalled on another Register.** Cross-Register recall, if supported, does not erase the transaction's provenance.  
    
* **Receipt identity belongs to the completed transaction and is permanent once assigned.** Receipt numbering is scoped to Store \+ Register and does not change because of reprinting, synchronization, or subsequent correction.  
    
* **Register totals are derived from completed transactions and Cash movements rather than maintained as independent authoritative counters.** Cached or materialized summaries may exist for performance but must remain reproducible from authoritative business facts.  
    
* **Cash settlement and Cash custody are separate concerns.** Cash tenders describe settlement with the customer. Opening float, drawer/safe transfers, paid-ins, paid-outs, counts, and variances describe physical Cash custody and accountability.  
    
* **Cash custody transfers are distinct from paid-in and paid-out activity.** Drawer → Safe and Safe → Drawer transfers change where organization Cash is held; paid-in and paid-out operations represent external operational Cash events.  
    
* **Register operation must fail explicitly when required durable identity or state cannot be trusted.** A future standalone Register must not silently replace missing or corrupt production state or fabricate continuity following data loss.

---

# Register, Reporting Period, and Session Model

Conceptually:

```
Point of Sale
    └── Register
          └── Register Reporting / Z Period
                ├── Business Date
                │
                ├── Session A
                ├── Session B
                └── Session C
                      └── Transactions
```

A Register has at most one active Register reporting/Z period.

That period is associated with one confirmed business date.

Once opened:

* the business date cannot be changed arbitrarily;  
* multiple cashier sessions may occur within the period;  
* closing a cashier session does not itself finalize the Register/Z period;  
* finalizing the Z closes the Register reporting period.

A Session represents an operating/cash-accountability period on the Register and records, as applicable:

* cashier/operator;  
* opening time;  
* opening Cash/float;  
* completed transactions;  
* Cash movements;  
* closing Cash count;  
* expected Cash;  
* variance;  
* closing time.

A finalized Z/reporting period is immutable.

If a future standalone Register synchronizes late activity belonging to an already finalized period, that activity must be handled explicitly as late-arriving/reconciliation activity rather than silently rewriting the finalized Z.

---

# Inventory Interaction

For quantity-tracked merchandise:

```
working/suspended transaction line
→ may contribute provisional reserved quantity

completed sale line
→ remove applicable provisional reservation
→ post authoritative on_hand movement
```

The inventory invariant remains:

```
available = on_hand - reserved - unavailable
```

Pending transaction state must never be treated as authoritative Inventory ledger history.

For individually tracked merchandise, the transaction line identifies the exact `inventory_unit`.

Completion, suspension/recall validation, linked returns, and Inventory posting operate against that specific unit rather than merely its parent variant.

---

# Minimum Viable Product / Initial POS Implementation Scope

## A. Register and Session Management

1. Confirm business date.  
2. Open the Register reporting/Z period if one is not already active.  
3. Open a cashier Session.  
4. Establish opening Cash/float.  
5. Ring transactions.  
6. Maintain accurate active-Session totals.  
7. Count and reconcile Cash.  
8. Close the cashier Session.  
9. Finalize the Register/Z period when appropriate.  
10. Retrieve previous Sessions and finalized Z reports.

---

# B. Transaction Merchandise and Line Operations

A POS transaction uses one transaction model containing independently directed sale and return lines.

ShelfSense does **not** persist separate transaction types for:

* sale;  
* refund;  
* exchange.

Those terms describe the transaction's composition or resulting settlement position.

## Supported line merchandise

Support lines for:

1. **Standard quantity-tracked merchandise**  
2. **Individually tracked merchandise**  
3. **Non-inventory merchandise**  
4. **Open-ring lines**

## Supported line operations

1. Add merchandise or open-ring line.  
2. Change quantity where permitted.  
3. Override selling price.  
4. Apply/remove line discount.  
5. Apply/remove transaction discount.  
6. Override tax treatment using valid configured tax rules.  
7. Void/remove a meaningful line according to transaction-line persistence rules.

Price overrides, tax overrides, discounts, line voids, and similar controlled actions may require:

* reason;  
* permission;  
* second-actor approval;

according to applicable policy.

---

# C. Transaction Lifecycle and Composition

## 1\. Open Transaction

A newly created transaction is mutable working state.

It may contain:

```
0..N sale lines
0..N return lines
0..N working tender attempts
```

until completion.

A transaction may freely combine sale and return activity where policy permits.

---

## 2\. Sale Lines

Support sale lines for:

* Standard merchandise;  
* individually tracked merchandise;  
* non-inventory merchandise;  
* open-ring lines.

A sale line contributes positive commercial value to the transaction.

For inventory-affecting merchandise, completion posts the appropriate authoritative Inventory consequence.

---

## 3\. Linked-Return Lines

A linked-return line reverses all or part of a previously completed sale line.

### Supported merchandise

Allow linked return of:

* Standard merchandise;  
* individually tracked merchandise;  
* non-inventory merchandise;  
* original open-ring lines where policy permits.

### Line relationship

Each linked-return line references the applicable original completed sale line.

Conceptually:

```
return_line
    ↓
original_sale_line
```

The relationship must exist at the line level rather than only between whole transactions.

### Eligibility

Calculate:

```
original sold quantity
-
previously completed returned quantity
=
remaining returnable quantity
```

A new linked-return line may not exceed the remaining returnable quantity.

For individually tracked merchandise, eligibility applies to the exact inventory unit as appropriate.

### Historical economics

A linked return reverses the applicable historical economics of the original line.

Preserve and reverse the applicable:

* original reference/selling price;  
* price override;  
* line discount;  
* allocated transaction discount;  
* original tax components and treatment;  
* merchandise snapshot/context.

Do **not** recalculate the original sale using current price, discount, or tax configuration.

### Transaction-level discount allocation

Transaction-level discounts must be deterministically allocated to eligible lines/components at completion.

The completed transaction preserves those allocations so a later partial linked return can reverse the correct historical discount amount.

### Original tender information

Display original tender information to assist refund-policy evaluation and cashier selection.

Original tender history informs refund policy but does not itself become the refund tender on the new transaction.

---

## 4\. Unlinked-Return Lines

Support return lines where no original ShelfSense sale line can be identified.

Allow, subject to policy:

* Standard merchandise;  
* individually tracked merchandise;  
* non-inventory merchandise;  
* open-ring return lines.

### Return value

Where an identifiable merchandise item has a current selling price:

1. propose that price as the return value;  
2. require explicit cashier confirmation;  
3. permit an authorized price override where policy allows.

The proposed current price is not represented as verified historical selling price.

### Tax

Default to the currently applicable configured tax treatment.

Where policy permits, allow an authorized override to another valid configured tax treatment.

Do not allow arbitrary freeform tax rates.

### Control

Unlinked returns are controlled operations and should support:

* required reason;  
* approval where applicable;  
* clear indication that the original sale economics were not verified.

---

## 5\. Suspend Transaction

Allow an open transaction to be suspended without completing or cancelling it.

Suspension preserves the working transaction, including as applicable:

* transaction identity;  
* Store;  
* originating Register;  
* current Session/operator context;  
* lines;  
* quantities;  
* selected inventory units;  
* working prices;  
* discounts;  
* working tax calculations;  
* entered reasons;  
* approvals where still applicable;  
* creation timestamp;  
* suspension timestamp.

A suspended transaction is **not** a completed commercial fact.

Suspension does not:

* assign final receipt identity;  
* create completed tender facts;  
* post final `on_hand` Inventory effects;  
* contribute to completed commercial totals;  
* contribute to completed Z financial totals.

A suspended transaction remains mutable working state.

---

## 6\. Recall Transaction

Allow an authorized cashier to retrieve a suspended transaction and resume working on it.

Recall must revalidate any mutable reference-dependent state that may have changed during suspension.

At minimum, revalidate:

```
merchandise remains sellable
inventory-unit state remains valid
price/reference state
tax configuration
discount eligibility
approval validity
```

### Governing rule

> **Suspension preserves the cashier's working transaction, but recall revalidates mutable reference-dependent decisions before further operation or completion.**

Where revalidation changes the commercial result, the POS must make the change visible to the cashier rather than silently substituting new values.

Exact refresh/revalidation rules remain owned by the relevant Pricing, Tax, Discounts, Approvals, and Inventory specifications.

### Cross-Register recall

Initially, recall should be supported at least within the same Store.

If another Register recalls the transaction, preserve both:

```
originating_register_id
current_register_id
```

or equivalent provenance.

---

## 7\. Cancel Transaction

An open or suspended transaction may be cancelled without completion.

Cancellation should:

* preserve appropriate working-history/audit facts once the transaction has become meaningful;  
* release provisional inventory reservations or unit claims;  
* release other temporary resources associated with the working transaction;  
* never create completed commercial/tender facts.

---

## 8\. Complete Transaction

Completion converts mutable working state into immutable completed commercial facts.

Conceptually:

```
Working Transaction
        ↓
CompleteTransaction
        ↓
Canonical Completed POS Operation
        ↓
Authoritative Posting Boundary
```

Completion must establish:

* immutable transaction identity;  
* immutable lines;  
* completed pricing facts;  
* completed discount allocations;  
* completed tax facts;  
* completed tender facts;  
* receipt identity;  
* Store/Register/Session/operator context;  
* `occurred_at`;  
* business date;  
* authoritative Inventory effects;  
* reporting effects;  
* operation identity/idempotency result.

The Rails-native POS invokes this boundary in-process.

A future standalone Register will submit materially equivalent completed operations through synchronization.

---

# D. Transaction Result Scenarios

Sale, refund, and exchange are result/workflow descriptions, not persisted transaction types.

The POS must correctly handle the following calculation scenarios.

## 1\. Net Payment

Where:

```
sale value > return value
```

the customer owes ShelfSense.

Example:

```
Sale lines      $50.00
Return lines   -$20.00
----------------------
Net             $30.00
```

Required settlement:

```
payment = $30.00
```

---

## 2\. Net Refund

Where:

```
return value > sale value
```

ShelfSense owes the customer.

Example:

```
Sale lines      $20.00
Return lines   -$30.00
----------------------
Net            -$10.00
```

Required settlement:

```
refund = $10.00
```

---

## 3\. Mixed Sale/Return Transaction

A transaction may contain both sale and return lines.

This may be presented to the cashier as an exchange workflow, but no separate `exchange` transaction type is required.

Reporting must preserve:

* gross sale activity;  
* gross return activity;

rather than reporting only their net.

---

## 4\. Zero-Net Transaction

Where sale and return activity net to exactly zero:

```
transaction net = 0
```

no payment or refund tender is required merely to mark the transaction settled.

---

# E. Tendering and Settlement

The transaction's net financial result determines the required settlement direction.

Conceptually:

```
transaction net > 0
→ payment tender(s)

transaction net < 0
→ refund tender(s)

transaction net = 0
→ no settlement required
```

## Supported tenders

Initially support:

1. **Cash**  
2. **Check**  
3. **Externally processed Card**  
4. **Configured Other tender**  
5. **Mixed tender**

Stored Value remains deferred.

---

## Cash

For Cash preserve:

```
applied
presented
change
```

For an ordinary payment:

```
presented = applied + change
```

Cash settlement contributes to physical Cash accountability according to Cash Handling rules.

---

## Check

Record the Check tender fact and any supported operational reference information.

Detailed check-clearing or banking workflows are outside POS completion.

---

## Externally Processed Card

ShelfSense initially records Card settlement that the cashier has processed using a separate external Card system.

ShelfSense:

* records the tender;  
* may preserve optional non-sensitive external references;  
* does not perform Card authorization;  
* does not claim that the Card was approved merely because a Card tender is selected.

Where a refund or correction requires an external Card refund/reversal, the cashier must perform the corresponding action through the external processor before ShelfSense records the resulting Card refund/reversal fact.

---

## Other Tender

`Other` must represent a genuine configured settlement mechanism.

It must not function as an unrestricted balancing entry used merely to force a transaction to zero.

---

# F. Refund Tendering

When the transaction has a negative net settlement amount:

1. calculate the amount owed to the customer independently of tender;  
2. determine valid refund tenders from policy;  
3. present only valid refund choices;  
4. for linked-return lines, use original tender information as input to refund policy where applicable;  
5. record the selected refund tender as a new completed settlement fact.

Return value and refund method remain separate concepts.

---

# G. Completed-Transaction Corrections

## Post-Void

Post-void is a correction operation against a previously completed transaction.

It is not a transaction type alongside sale/refund/exchange.

Conceptually:

```
Original Completed Transaction
        ↓
PostVoid Operation
        ↓
New Reversing Facts
```

The original transaction remains immutable.

Post-void should reverse, as applicable:

* sale activity;  
* return activity;  
* tax;  
* tender effects;  
* Inventory effects;  
* reporting effects.

Post-void normally requires:

* reason;  
* authorization;  
* approval according to policy.

Where an externally processed Card tender is involved, ShelfSense must not imply that the external Card reversal occurred unless the corresponding processor action was actually performed.

---

# H. Receipt and Completed Transaction Operations

## Receipt

1. Assign permanent receipt identity when the transaction is completed.  
2. Receipt numbering is scoped to Store \+ Register.  
3. Render receipt from immutable completed facts.  
4. Prompt to print after successful completion.  
5. Printing occurs outside the authoritative transaction-completion boundary.  
6. Printer failure does not reverse or reopen a completed transaction.  
7. Initial implementation does not require durable tracking of printer success/failure.

## Reprint

A receipt may be reprinted without changing its receipt identity.

A reprint should be visibly distinguishable as a copy/reprint.

---

## Completed Transaction Retrieval

Allow lookup using practical identifiers such as:

* receipt number;  
* transaction reference;  
* date/time;  
* Register;  
* Session.

From a completed transaction, support:

* view;  
* receipt reprint;  
* initiate linked return;  
* initiate post-void where authorized.

---

# I. Cash Movements and Accountability

Support:

1. Opening float.  
2. Cash customer payments.  
3. Cash customer refunds.  
4. Drawer → Safe transfer.  
5. Safe → Drawer transfer.  
6. Paid-in.  
7. Paid-out.  
8. Closing Cash count.

Internal transfers and external Cash movements remain distinct.

### Internal custody transfer

```
Drawer → Safe
Safe → Drawer
```

changes where organization Cash is held.

### Paid-in / paid-out

represents an external operational Cash event.

A customer Cash payment or refund is represented by tender settlement, not duplicated as paid-in/paid-out activity.

---

# J. Session Totals

Active Session totals must remain explainable from underlying completed business facts.

Suspended/open transactions do not contribute to completed financial totals.

## Commercial totals

Track at least:

* gross sale activity;  
* gross return activity;  
* discounts;  
* net sales/commercial activity;  
* tax;  
* completed transaction count;  
* tender totals by type.

Mixed sale/return transactions contribute separately to gross sale and gross return activity.

---

## Cash accountability

Conceptually:

```
opening float
+ Cash payments
- Cash refunds
+ paid-ins
- paid-outs
+ transfers in
- transfers out
=
expected Cash
```

Then:

```
counted Cash
-
expected Cash
=
variance
```

Totals should be derived from completed transactions and Cash movements.

Materialized/cached totals may exist but are not the independent source of authority.

---

# K. Register and Session Reports

Initial POS reporting should include:

## 1\. Current Session

Display operational totals such as:

* completed transaction activity;  
* gross sales;  
* gross returns;  
* discounts;  
* tax;  
* tender totals;  
* expected Cash;  
* suspended transaction count where useful.

---

## 2\. Session Close

Preserve the completed cashier Session's operational and Cash-accountability result, including as applicable:

* opening Cash;  
* Cash activity;  
* expected Cash;  
* counted Cash;  
* variance;  
* session totals;  
* opening/closing actor and timestamps.

Closing a Session does not necessarily finalize the Register's Z/reporting period.

---

## 3\. Current Register / Z Period

Display cumulative completed activity across Sessions belonging to the current Register business-date reporting period.

---

## 4\. Finalized Z

Finalization produces an immutable Register reporting-period snapshot.

A finalized Z should remain reproducible from or linked to its authoritative completed transaction, tender, tax, Session, and Cash facts.

---

## 5\. Previous Sessions and Z Periods

Allow retrieval of:

* previous Sessions;  
* previous finalized Z periods;  
* underlying completed transaction activity where appropriate.

---

# L. Pricing and Calculation Order

POS pricing must be deterministic and preserve enough completed detail to reproduce the commercial result without consulting current configuration.

## 1\. Pricing sequence

For an ordinary sale line, calculate value in the following order:

```
reference unit price
        ↓
optional price override
        ↓
selling unit price
        ↓
quantity
        ↓
extended selling price
        ↓
line discount(s)
        ↓
allocated transaction discount
        ↓
net merchandise amount
        ↓
tax basis
        ↓
tax
        ↓
completed line amount
```

Tax treatment may change whether all or part of the net merchandise amount forms the tax basis, but tax does not alter the merchandise selling price itself.

---

## 2\. Reference price

Every priced merchandise line has a reference price representing the ordinary price from which the transaction began.

For Standard merchandise, the initial resolution is generally:

```
current applicable variant regular price
→ reference unit price
```

For individually tracked merchandise, the applicable unit-specific approved selling price may take precedence where defined by Pricing policy.

Open-ring lines establish their reference/selling amount through the open-ring workflow rather than merchandise price lookup.

A merchandise item without a resolvable required price must not silently default to zero.

---

## 3\. Selling price

The selling price is the price actually used before discounts.

Normally:

```
selling unit price = reference unit price
```

Where an authorized price override occurs:

```
reference unit price
≠
selling unit price
```

Both values must be preserved on the completed line.

---

## 4\. Price override

A price override is a controlled action.

The completed transaction should preserve, as applicable:

```
reference unit price
requested/actual selling unit price
quantity
reason
performed_by
approved_by
policy/approval context
```

Price override policy may distinguish:

```
direct
approval_required
prohibited
```

An override does not modify the centrally configured regular price.

It applies only to the transaction line on which it was performed.

---

## 5\. Quantity

Quantity participates in the financial meaning of the line.

Changing quantity must cause ShelfSense to recalculate:

* extended selling price;  
* discount effects;  
* transaction-discount allocation;  
* tax;  
* line total.

Where an existing approval depended on quantity or total financial effect, a quantity change must re-evaluate that approval.

Individually tracked merchandise normally has quantity `1` per exact inventory-unit line unless the domain explicitly supports another representation.

---

## 6\. Completed pricing facts

Completion must preserve enough pricing information to explain:

> Why did the customer pay or receive this amount?

At minimum, completed line economics should preserve:

```
reference unit price
selling unit price
quantity
extended selling amount
line discount allocation
transaction discount allocation
net merchandise amount
tax components
completed line amount
```

Current prices must never be substituted when displaying, returning, auditing, or reporting a completed transaction.

---

# M. Discounts

Discounts reduce the applicable selling-price basis. They do not rewrite the reference or selling price.

## 1\. Discount levels

The initial POS supports:

```
line discount
transaction discount
```

A line discount applies to one eligible transaction line.

A transaction discount applies across the eligible transaction and must be allocated back to individual lines at completion.

---

## 2\. Initial discount methods

The initial implementation should support at least:

### Line

```
percentage
fixed amount / fixed-per-unit as explicitly selected
```

### Transaction

```
percentage
fixed total amount
```

The UI must make the meaning of a fixed discount unambiguous.

For example, ShelfSense must not accept:

```
Discount: $5
```

without knowing whether `$5` means:

```
$5 per unit
```

or:

```
$5 from the entire line
```

if both methods are supported.

---

## 3\. Discount order

The MVP calculation order is:

```
reference price
→ price override
→ selling price
→ line discount
→ transaction discount allocation
→ tax basis
```

Therefore:

> **A price override changes the selling-price basis; a discount reduces that resulting basis.**

---

## 4\. Discount stacking

The underlying model should permit multiple completed discount facts without requiring one synthetic combined discount.

The initial cashier UI may restrict which combinations are offered.

Where multiple discounts apply, application order must be deterministic.

ShelfSense must not make financial results depend on database row order or UI event timing.

---

## 5\. Discount eligibility

Discount policy must determine which lines are eligible.

Eligibility may depend on factors such as:

* merchandise/classification;  
* line type;  
* sale versus return direction;  
* open-ring status;  
* discount source;  
* other configured policy.

Open-ring and return-line discount behavior must be explicitly permitted rather than assumed.

---

## 6\. Transaction-discount allocation

A transaction-level discount must be allocated to eligible lines before completion.

Conceptually:

```
transaction discount
        ↓
eligible line bases
        ↓
deterministic proportional allocation
        ↓
line A allocation
line B allocation
line C allocation
```

Residual cents must be assigned through a stable deterministic rule.

A suitable initial rule is:

> Allocate proportionally to eligible line basis; distribute residual cents in deterministic line order according to the allocation algorithm defined by the calculation contract.

The exact algorithm must be covered by shared calculation fixtures.

---

## 7\. Discount floor

Unless a later capability explicitly permits otherwise:

> **Discounts may reduce an eligible merchandise amount to zero but must not cause the merchandise amount itself to become negative.**

A transaction resulting in a refund must result from return-line economics, not from applying an excessive sale discount.

---

## 8\. Controlled discounts

Manual discounts may require:

* permission;  
* reason;  
* approval;

according to policy.

Approval must bind to the actual requested discount and its material financial basis.

Changing the discount, quantity, or eligible basket basis may invalidate an existing approval.

---

## 9\. Historical discount facts

Completed transactions preserve:

* discount method;  
* source/type;  
* requested value;  
* actual applied amount;  
* line allocation;  
* performer;  
* reason;  
* approval where applicable.

Linked returns reverse the historical allocated discount rather than applying today's discount policy.

---

# N. Tax Calculation and Overrides

Tax must be deterministic, historically reproducible, and independent of current tax configuration after transaction completion.

## 1\. Tax determination

Ordinary tax determination uses:

```
Store
+
merchandise tax class
+
occurred_at
+
effective tax configuration
```

to resolve the applicable tax treatment and components.

`business_date` does not select the tax rule.

`occurred_at` does.

---

## 2\. Tax treatments

The initial model supports:

```
taxable
exempt
zero-rated
```

These remain distinct concepts even where the calculated tax happens to equal zero.

Completed tax facts should preserve the treatment actually applied.

---

## 3\. Tax components

A line may have zero or more tax components.

Example:

```
State Sales Tax
Food/Beverage Tax
```

For the initial implementation, components are independently calculated and **not compounded**.

Each component retains its own:

* identity;  
* treatment;  
* rate;  
* taxable basis;  
* calculated tax amount.

---

## 4\. Rate representation

Tax rates must use a deterministic decimal/fixed-precision representation.

Binary floating-point arithmetic must not determine financial results.

The Rails implementation and eventual standalone implementation must consume the same rate representation and calculation fixtures.

---

## 5\. Tax basis

Tax is calculated after applicable price overrides and discounts.

Conceptually:

```
selling amount
-
discount allocations
=
net merchandise amount
        ↓
tax treatment/rule
        ↓
taxable basis
```

Different components may produce different taxable bases where configuration requires it.

---

## 6\. Rounding

The initial POS uses deterministic monetary rounding at the defined line/component level.

Unless superseded by a jurisdiction-specific requirement, the calculation contract should use:

```
decimal half-up
→ whole cents
```

for each applicable line tax component.

The exact rules must be captured in portable fixtures.

---

## 7\. Linked returns

A linked return reverses the historical tax actually associated with the original sale line.

It does **not** ask:

> What tax would ShelfSense charge for this item today?

Instead:

```
original completed tax component
→ applicable historical reversal
```

Partial returns must consume historical tax cents deterministically so that returning the full eligible quantity over multiple transactions ultimately reverses the appropriate original tax amount.

---

## 8\. Unlinked returns

An unlinked return has no verified historical tax fact.

Therefore ShelfSense should:

1. resolve the current applicable tax treatment;  
2. present that as the default;  
3. allow only authorized overrides to another valid configured treatment where policy permits.

---

## 9\. Tax override

Tax override is a controlled action.

It selects an allowed configured tax treatment or tax-rule outcome.

It does **not** permit the cashier to type an arbitrary tax percentage.

Preserve:

```
default tax determination
actual applied determination
reason
performed_by
approved_by where required
```

---

# O. Permissions, Reasons, and Approvals

ShelfSense uses one common controlled-action model throughout POS.

## 1\. Separate concepts

The POS must distinguish:

```
Permission
→ May this actor perform/request this category of action?

Reason
→ Why is this action being taken?

Policy
→ What authority is required for this exact request?

Approval
→ Who authorized this exact request when another actor is required?
```

These concepts must not be collapsed.

---

## 2\. Policy outcomes

Controlled-action policy produces one of:

```
direct
approval_required
prohibited
```

### Direct

The actor may perform the requested operation without another actor.

### Approval required

The actor may request the operation, but another qualifying actor must approve the exact request.

### Prohibited

The operation cannot proceed under the current policy.

`prohibited` must not automatically mean:

> Ask someone more senior.

unless another explicit policy path allows it.

---

## 3\. Initial controlled-action catalog

The MVP common approval framework should be usable for at least:

```
price override
line void
transaction cancellation
line discount
transaction discount
tax override
unlinked return
return-policy exception
post-void
paid-in
paid-out
Cash transfer where policy requires
Cash variance acceptance where policy requires
```

Not every organization must require approval for every action.

---

## 4\. Performer and approver

Preserve:

```
performed_by
approved_by
```

as separate identities.

Where second-person approval is required:

```
approved_by != performed_by
```

The approving actor authenticates for the approval operation.

They do not become the active cashier or take ownership of the Register Session.

---

## 5\. Approval scope

An approval authorizes one exact requested action.

For example:

```
Approve:
  price override
  line L
  reference price = $20.00
  requested price = $15.00
  quantity = 2
```

It does not authorize:

```
cashier may perform arbitrary price overrides
```

---

## 6\. Approval invalidation

When a material field changes, policy must be re-evaluated.

Examples include:

* price changes;  
* discount value changes;  
* quantity changes that alter financial effect;  
* refund method changes;  
* return quantity changes;  
* controlled Cash amount changes.

If the changed request still requires approval, fresh approval is required.

---

## 7\. Reasons

Reason requirements are independent of approval.

Policy may require:

```
reason only
approval only
reason + approval
neither
```

Reason catalogs should belong to the applicable business domain rather than one unrestricted freeform approval system.

---

## 8\. Organization and Store policy

The preferred policy hierarchy is:

```
organization default
        ↓
optional Store override
```

Avoid per-user numeric authority matrices unless a concrete later requirement justifies them.

---

# P. Tender Configuration and Settlement Rules

Tender configuration determines which known settlement methods are available. Category-specific behavior remains defined by ShelfSense.

## 1\. Tender type configuration

A tender type should preserve at least:

```
stable identity
code
display name
category
payment availability
refund availability
active state
Store applicability
display order
```

Initial categories:

```
Cash
Card
Check
Other
```

Stored Value remains deferred.

---

## 2\. Settlement direction

Tender amounts are positive monetary values with explicit direction:

```
payment
refund
```

Do not represent a refund simply by storing a negative tender amount.

---

## 3\. Settlement equation

A completed transaction must satisfy:

```
payments
-
refunds
=
transaction net
```

Completion requires exact settlement unless a later explicitly designed settlement model says otherwise.

---

## 4\. Working tenders

Before completion, tender attempts remain mutable working state.

The cashier may add/remove/replace tender attempts according to workflow rules.

Only completed tender facts become immutable transaction history.

---

## 5\. Cash

Cash preserves:

```
amount applied
amount presented
change
```

For an ordinary payment:

```
presented = applied + change
```

`presented` may exceed the remaining amount due.

`applied` is the amount that participates in settlement.

Change is not represented as a separate refund tender.

---

## 6\. Check

Check applies only the amount used to settle the transaction.

Optional operational reference information may be retained.

Check-clearing or bank-settlement workflows remain outside transaction completion.

---

## 7\. Externally processed Card

For the initial POS, Card is processed outside ShelfSense.

The workflow is:

```
ShelfSense calculates amount
        ↓
cashier processes Card externally
        ↓
cashier confirms successful external processing
        ↓
ShelfSense records Card tender
```

ShelfSense does not claim to have authorized the Card itself.

Refund/reversal follows the same rule.

---

## 8\. Other tender

`Other` represents a real configured settlement method.

It must not be used as:

```
miscellaneous adjustment
```

or:

```
make this transaction balance
```

without an actual settlement event.

---

## 9\. Mixed tender

A transaction may contain multiple tenders.

Tender application order must be retained where operationally meaningful.

Non-Cash tenders should not ordinarily exceed the remaining settlement amount unless an explicit tender contract supports that behavior.

---

# Q. Return Eligibility and Historical Reversal

Returns are represented by return-directed transaction lines.

Return policy determines whether a proposed return line is permitted.

## 1\. Linked return eligibility

At minimum, a linked return must verify:

```
original completed sale line exists
requested return quantity is eligible
requested exact inventory unit is eligible where applicable
return policy permits the return
```

The core quantity invariant is:

```
original sold quantity
-
previously completed returned quantity
=
remaining returnable quantity
```

---

## 2\. Return policy

The MVP return policy must be capable of determining:

* return window;  
* merchandise/classes excluded from return;  
* open-ring return eligibility;  
* exact-unit requirements;  
* Store restrictions where applicable;  
* whether an exception may be approved;  
* valid refund methods.

The actual configured values belong to organization/Store configuration.

---

## 3\. Historical reversal

Linked returns reverse the original completed economics.

Applicable historical facts include:

```
selling price
price override
line discount
transaction-discount allocation
tax components
inventory unit
commercial classification/context required for reversal
```

Current configuration must not overwrite these historical facts.

---

## 4\. Partial returns

Partial returns must be deterministic.

For quantity-tracked lines, ShelfSense must track the remaining historical economic value available to reverse.

Residual discount/tax cents must not be created or lost across repeated partial returns.

The final eligible return consumes any applicable remaining historical residual.

---

## 5\. Individually tracked returns

Where the original sale involved an `inventory_unit`, the linked return identifies that exact unit.

The returned unit's Inventory consequences operate against that exact unit.

---

## 6\. Unlinked return

An unlinked return does not claim historical sale verification.

It therefore:

* uses current/reference merchandise information where available;  
* proposes a current selling value;  
* requires explicit confirmation;  
* uses current tax treatment by default;  
* may allow controlled price/tax overrides;  
* requires a reason;  
* may require approval.

The completed return must remain visibly identifiable as unlinked.

---

## 7\. Refund method

Return value and refund settlement are distinct.

Original tenders inform refund policy for linked returns.

They do not automatically create the new refund tender.

---

# R. Authoritative Completion and Operation Contract

Completion is the architectural boundary between mutable Register work and immutable commercial history.

## 1\. Completion model

Conceptually:

```
Working Transaction
        ↓
CompleteTransaction
        ↓
Canonical Completed POS Operation
        ↓
Authoritative Posting Boundary
        ↓
Central Business Facts
```

The Rails-native POS invokes this boundary in-process.

A future standalone Register submits the same class of operation through synchronization.

---

## 2\. Completed-operation identity

Every completed operation has a globally unique:

```
operation_id
```

The operation also declares a versioned contract/schema version.

Operation identity is distinct from:

```
transaction_id
receipt identity
```

---

## 3\. Minimum operation content

The operation must contain enough information to describe the completed commercial event without hidden client state.

At minimum:

```
operation
  operation_id
  schema_version

origin
  store_id
  register_id
  session_id
  performed_by

transaction
  transaction_id
  occurred_at
  business_date
  receipt identity

lines[]
  line_id
  direction
  merchandise/open-ring identity
  inventory_unit_id where applicable
  quantity
  pricing facts
  discount facts/allocations
  tax facts

tenders[]

reasons/approvals as applicable
```

A future standalone origin may additionally identify its installation.

---

## 4\. Authoritative posting

The POS client does not directly mutate downstream Inventory balances, reporting totals, or financial projections.

The authoritative boundary:

1. validates the operation;  
2. establishes idempotency;  
3. commits completed transaction facts;  
4. posts required Inventory effects;  
5. associates reporting/Z context;  
6. records the authoritative operation result.

---

## 5\. Atomicity

For the Rails-native implementation, authoritative completion occurs within one required PostgreSQL transaction.

Conceptually:

```
BEGIN

record operation identity
record completed transaction
record completed lines
record pricing/discount facts
record tax facts
record tenders
assign receipt identity
record Session/Z association
post Inventory ledger effects
record operation result

COMMIT
```

ShelfSense must never report successful completion unless that required commit succeeds.

---

## 6\. Receipt assignment

The permanent receipt identity should be assigned as part of authoritative completion.

Therefore:

```
open transaction      → no final receipt number
suspended transaction → no final receipt number
cancelled transaction → no final receipt number
completed transaction → permanent receipt number
```

Receipt numbering remains Store \+ Register scoped.

---

## 7\. Idempotency

Required behavior:

```
same operation_id
+ same material operation
→ same completed result
```

and:

```
same operation_id
+ different material operation
→ integrity failure
```

Retry must not create a second:

* transaction;  
* receipt;  
* tender;  
* Inventory movement;  
* reporting effect.

---

# S. Cashier Interaction Requirements

The Rails POS must behave like a dedicated Register application rather than ordinary administrative CRUD.

## 1\. Governing UX principles

The ordinary cashier path is:

```
scanner-first
keyboard-first
pointer optional
```

Routine checkout must be fully operable without a mouse.

---

## 2\. Persistent workspace

An active transaction should remain within one persistent Register workspace.

Cashiers should not navigate through conventional multi-page Rails CRUD flows to:

* add lines;  
* change quantity;  
* tender;  
* suspend;  
* complete.

---

## 3\. Primary input target

In ordinary sale-entry mode, the merchandise scan/input control is the primary focus target.

After ordinary line operations finish:

```
focus
→ merchandise input
```

unless another explicit interaction remains active.

---

## 4\. Input modes

The POS should explicitly understand the current interaction context, for example:

```
SALE_ENTRY
LOOKUP
QUANTITY
PRICE_OVERRIDE
DISCOUNT
TAX_OVERRIDE
TENDER
APPROVAL
RETURN_LOOKUP
```

Input must not accidentally route to the wrong operation.

---

## 5\. Focused/modal commands

Secondary data-entry operations should use focused modal-style interaction where appropriate.

Examples:

```
Change Quantity
Price Override
Discount
Tax Override
Cash Tender
Approval
Paid-Out
```

When opened:

* intended input receives focus;  
* Enter confirms where safe;  
* Escape cancels/backs out;  
* focus returns predictably afterward.

---

## 6\. Scanner behavior

Keyboard-wedge scanning must operate reliably within ordinary Register entry.

Scanner input should not require repeatedly clicking a field before every scan.

After a modal closes, scanner input must not accidentally continue entering data into an obsolete modal/input target.

---

## 7\. Errors

Validation errors should preserve the cashier's working context.

Examples:

```
identifier not found
price unavailable
quantity invalid
approval required
tender insufficient
```

should be shown within the Register workspace.

Ordinary errors must not discard the transaction or navigate the cashier to a generic error screen.

---

## 8\. Completion behavior

Once completion succeeds:

```
transaction becomes immutable
→ receipt action offered
→ workspace resets
→ next transaction ready
→ scan target receives focus
```

Repeated Complete input while completion is underway must not create duplicate operations.

---

## 9\. Client-side responsibility

JavaScript/Stimulus may own:

* focus;  
* keyboard shortcuts;  
* modal behavior;  
* scanner interaction;  
* presentation state.

It must not become the authoritative implementation of:

* pricing;  
* discounts;  
* tax;  
* tender settlement;  
* transaction completion.

---

# T. Failure and Recovery Behavior

Failure behavior must be explicit so the cashier can distinguish a rejected action from a completed transaction.

## 1\. Working-state failures

Conditions such as:

```
unknown identifier
inactive merchandise
missing required price
unavailable inventory unit
invalid quantity
invalid tax configuration
unauthorized operation
approval denied
```

prevent the applicable action but leave the working transaction intact wherever safely possible.

---

## 2\. Tender failures

An invalid or insufficient tender does not complete the transaction.

External Card failure means no successful Card tender may be recorded.

The cashier remains in working tender state.

---

## 3\. Completion failure

If authoritative completion fails:

```
completed transaction = no
receipt assigned = no
Inventory posting = no
completed tender facts = no
```

The UI must not display a success/receipt state.

The cashier must be able to determine that completion did not occur.

---

## 4\. Uncertain client response

If the authoritative server commit succeeds but the browser does not receive the response, retry using the same `operation_id`.

Idempotency determines whether the operation already completed.

The cashier must not recreate the transaction as a new operation merely because a response was lost.

---

## 5\. Printer failure

Printing occurs after completion.

Therefore:

```
sale committed
+
printer fails
=
sale remains completed
```

The cashier may retry/reprint without changing the transaction.

---

## 6\. Browser refresh/restart

Working transactions intended to survive browser interruption must be durably persisted by the Rails application.

A browser refresh should not silently discard meaningful working or suspended transactions.

The Register should recover the applicable persisted working context where policy permits.

---

## 7\. Suspended-state recovery

Suspended transactions remain retrievable until:

```
recalled and completed
recalled and cancelled
explicitly cancelled
otherwise resolved according to policy
```

They must not disappear merely because a cashier Session or browser connection ends.

---

# U. Audit and Controlled-Action History

ShelfSense must preserve meaningful POS accountability without treating every cashier keystroke as an audit event.

## 1\. Audit versus business fact

Completed business facts remain authoritative for what occurred.

Audit/activity history explains meaningful actions surrounding those facts.

An audit event must not become the only surviving representation of:

* a tender;  
* a discount;  
* an Inventory movement;  
* a Cash movement;  
* an approval.

---

## 2\. Initial auditable actions

At minimum, retain durable accountability for:

```
price override
tax override
line discount
transaction discount
line void
transaction cancellation
unlinked return
return-policy exception
post-void
approval
paid-in
paid-out
Cash transfer
Cash variance acceptance/override
Session/Z finalization
```

---

## 3\. Required context

Where applicable, controlled-action history should preserve:

```
action type
subject
performed_by
approved_by
reason
before values
after/requested values
Register
Session
transaction/line
occurred_at
policy/approval context
```

---

## 4\. Approval history

Approval history must identify:

* performer;  
* approver;  
* exact controlled action approved;  
* material values approved;  
* approval time;  
* policy/version context where applicable.

A later changed request must not appear to have been approved by an approval that applied to different values.

---

## 5\. Transaction working history

ShelfSense does not need to audit every edit to an insignificant empty transaction.

Once working state becomes meaningful, cancellation, suspension, recall, controlled modifications, and other operationally significant events may be preserved for accountability and support.

Exact persistence thresholds belong to the transaction implementation contract.

---

## 6\. Completed transaction history

Completed facts are immutable.

Subsequent activity is represented through linked new facts:

```
original transaction
    ↑
linked return

original transaction
    ↑
post-void

completed receipt
    ↑
reprint activity where tracked
```

No audit or correction process rewrites the original economic history.

---

## 7\. Reporting and support

Audit/activity history should make it possible to answer operational questions such as:

> Who changed this price?  
>   
> Why was this tax treatment overridden?  
>   
> Who approved this unlinked return?  
>   
> Why was this transaction cancelled?  
>   
> Who performed this paid-out?  
>   
> Who accepted this Cash variance?

without requiring reconstruction from application logs.

---

# Deferred

Explicitly defer:

1. **Stored Value issuance/redemption**  
2. **Customer reservation pickup**  
3. **Customer display**  
4. **Integrated Card processor**  
5. **Standalone/offline Register runtime**

The standalone Register remains an architectural goal.

It will eventually add:

```
standalone POS runtime
local durable persistence
reference replication
offline authentication/authorization
local transaction completion
transactional outbox
operation synchronization
local inventory overlay
installation recovery
```

without changing the completed POS operation semantics established by the Rails implementation.

---

# Resulting Initial POS Scope

The initial complete Rails POS supports the operating cycle:

```
Confirm business date
        ↓
Open Register / Z period
        ↓
Open cashier Session
        ↓
Start transaction
        ↓
Add sale and/or return lines
        ├── continue
        ├── suspend
        └── cancel
              ↓
Recall suspended work
              ↓
Continue / complete / cancel
              ↓
Complete transaction
        ↓
Net result:
    payment / refund / zero
        ↓
Authoritative posting
        ↓
Receipt
        ↓
Additional transactions
        ↓
Cash movements
        ↓
Count and reconcile Session
        ↓
Close Session
        ↓
Additional Session(s), if needed
        ↓
Finalize Z / Register reporting period
```

The important invariant is:

> **ShelfSense has one POS transaction model composed of independently directed sale and return lines. The transaction's resulting net determines whether payment, refund, or no settlement is required. “Sale,” “refund,” and “exchange” describe cashier workflows or calculation scenarios; they are not separate persisted transaction types.**

And the architectural portability invariant remains:

> **The Rails-native POS must describe completed operations through the same durable business boundary that a future standalone Register will use. Implementation transport may differ, but completed commercial facts and authoritative downstream effects must remain equivalent.**  