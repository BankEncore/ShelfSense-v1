# POS Domain Specification: Transaction Lines

**Design status:** Decided for core line model; some exception and policy details remain pending **Implementation status:** Planned incrementally across Phases 4–6 **Initial foundation:** Phase 4 — POS Runtime and Contract Foundation **First operational delivery:** Phase 5 — First Operational Cash Sale **Expanded delivery:** Phase 6 — Core POS Operations **Related specifications:** Transactions, Pricing, Discounts, Tax, Returns, Approvals, Receipts, Inventory Integration **Related workflows:** Cash Sale, Add Merchandise, Change Quantity, Void Line, Individually Tracked Sale, Open Ring, Linked Return, Exchange

---

## 1\. Purpose

This specification defines the transaction-line model used by ShelfSense POS.

It establishes:

* what a transaction line represents;  
* line types;  
* sale versus return direction;  
* active versus voided working state;  
* quantity rules;  
* merchandise and inventory-unit identity;  
* open-ring behavior;  
* line consolidation;  
* line snapshots;  
* pre-completion mutation;  
* completed-line immutability;  
* relationships to pricing, discounts, tax, inventory, returns, audit, receipts, and reporting.

This specification intentionally does **not** define detailed:

* price-resolution algorithms;  
* price-override thresholds;  
* discount calculations;  
* tax arithmetic;  
* return eligibility;  
* inventory-ledger posting;  
* scanner interaction;  
* receipt layout.

Those rules belong to their respective specifications and workflows.

---

# 2\. Governing principle

A transaction line represents one economically coherent component of a POS transaction.

The core rule is:

> **A line may combine multiple physical items only when ShelfSense can represent all financially and operationally meaningful facts for those items identically.**

A line must split when meaningful attributes differ.

For example:

```
2 copies × $16.00
same variant
same tax
same discounts
same override state
```

may be one quantity-two line.

But:

```
2 copies × $16.00
1 copy  × $15.00 because mislabeled
```

must be represented as separate lines.

Individually tracked inventory units are always separate lines.

---

# 3\. Independent line dimensions

ShelfSense must not overload one field to represent multiple business concepts.

A transaction line has several independent dimensions.

## 3.1 Line type

What kind of thing does the line represent?

```
merchandise
open_ring
```

Additional line types may be added later only when they represent genuinely different business concepts.

## 3.2 Direction

What economic direction does the line represent?

```
sale
return
```

Direction is explicit.

Negative quantity must not be used to mean return.

## 3.3 Working state

Does the line currently participate in the transaction?

```
active
voided
```

This state applies while the transaction itself is mutable.

## 3.4 Inventory identity/tracking

For merchandise lines, how is the merchandise tracked?

Conceptually:

```
quantity-tracked
individually tracked
non-inventory
```

This characteristic is derived from the merchandise/inventory model rather than represented by inventing additional POS line types.

An open ring has no merchandise inventory identity.

---

# 4\. Why these dimensions remain separate

The following are all valid conceptual combinations:

```
merchandise + sale + active + quantity-tracked
merchandise + sale + active + individually-tracked
merchandise + return + active + quantity-tracked
merchandise + return + active + individually-tracked

open_ring + sale + active
open_ring + return + active

merchandise + sale + voided
open_ring + sale + voided
```

ShelfSense should not create enums such as:

```
new_book_sale
used_book_sale
open_ring_sale
book_return
used_book_return
voided_sale
```

because those combine independent concepts and make the model difficult to extend.

---

# 5\. Line identity

Every persisted meaningful transaction line should have its own stable technical identity.

The exact UUID allocation timing is an implementation concern, but once a line is persisted and referenced by:

* audit/activity history;  
* discounts;  
* tax facts;  
* approvals;  
* returns;

its identity must remain stable.

A line must not receive a different identity merely because:

* its quantity changed;  
* its price was overridden;  
* a discount was applied;  
* the transaction was suspended and recalled.

---

# 6\. Line type: merchandise

A merchandise line represents a known sellable ShelfSense product variant.

A merchandise line therefore references:

```
product_variant
```

Where the variant is individually tracked, it also references:

```
inventory_unit
```

A merchandise line carries enough completed snapshot information to describe what was sold or returned even if master merchandise data changes later.

---

# 7\. Quantity-tracked merchandise

For quantity-tracked merchandise:

* `product_variant` is required;  
* `inventory_unit` is absent;  
* quantity is a positive integer;  
* quantity may be changed while the transaction is open;  
* repeated scans may consolidate when all consolidation requirements are satisfied.

Conceptually:

```
Product Variant: Notebook
Quantity:        3
Unit Price:      $4.50
```

represents three interchangeable units having identical commercial treatment on that transaction line.

---

# 8\. Individually tracked merchandise

For individually tracked merchandise:

* `product_variant` is required;  
* the exact `inventory_unit` is required;  
* quantity is always `1`;  
* each physical unit is represented by its own transaction line;  
* lines never consolidate into quantity greater than one.

Conceptually:

```
Product Variant: Used — The Great Gatsby
Inventory Unit:  UNIT-220...
Quantity:        1
```

The exact unit identity is operationally meaningful because individual units may differ in:

* condition;  
* notes;  
* price;  
* acquisition history;  
* inventory history.

The consolidated POS design specifically requires individually tracked units to remain separate quantity-one lines so their condition, price, and unit history remain independently preserved.

---

# 9\. Non-inventory merchandise

A known merchandise variant may be sellable without creating an inventory effect.

Such a sale remains a:

```
line_type = merchandise
```

because ShelfSense knows the merchandise identity.

It must not be represented as an open ring merely because it is non-inventory.

The distinction is:

```
Known merchandise that is not inventory-tracked
    → merchandise line

Unknown/unspecified merchandise identity
    → open-ring line
```

Inventory Integration determines whether a merchandise line produces an inventory effect.

---

# 10\. Line type: open ring

An open ring is a first-class line type representing a sale or linked return where ShelfSense intentionally does not have a known merchandise identity.

It is **not** represented by:

* fake merchandise;  
* miscellaneous SKU;  
* placeholder product;  
* synthetic product variant.

The cashier records only what is actually known.

For an open-ring line:

```
product_variant_id = absent
inventory_unit_id  = absent
department         = required
quantity           = positive integer
unit price         = required
tax treatment      = required/resolved
description        = optional
reason             = optional/policy-dependent
```

The existing design explicitly rejects miscellaneous pseudo-products in favor of an explicit open-ring line.

---

# 11\. Open-ring quantity

Open rings preserve quantity.

Quantity is a positive integer and normally defaults to one.

For example:

```
1 × Miscellaneous Merchandise @ $50
```

is operationally different from:

```
2 × Miscellaneous Merchandise @ $25
```

even though both produce $50 of sales.

Preserving quantity supports:

* customer receipt presentation;  
* item-count reporting;  
* cashier review;  
* partial linked returns;  
* operational analysis.

---

# 12\. Open-ring classification

Because no product variant exists, the open-ring line must carry the classification information actually known at the time of sale.

At minimum, the line requires a department.

The department supplies the financial/reporting classification and normally provides or resolves an applicable tax class according to the Tax specification.

An open ring must never invent merchandise identity merely to obtain classification.

---

# 13\. Open-ring price

The cashier-entered open-ring price is the line's legitimate selling price.

It is **not a price override**.

There is no reference merchandise price to override.

Conceptually:

```
Open ring:
Entered unit price = $12.00
Selling unit price = $12.00

Reference merchandise price = none
Override variance           = none
```

This distinction is important for:

* loss-prevention reporting;  
* discount calculations;  
* receipt presentation;  
* margin analysis.

Open-ring controls belong to policy/approval specifications rather than treating every open ring as a price exception.

---

# 14\. Open-ring inventory behavior

An open ring has no POS inventory effect.

ShelfSense does not know which inventory record was sold.

If staff later discover what physical item was actually involved, inventory is corrected through an inventory workflow.

The original completed POS line remains an open ring.

ShelfSense must not rewrite the completed sale later to pretend the cashier possessed merchandise identity that was unknown at checkout.

---

# 15\. Open-ring returns

A linked return of an open-ring line reverses the applicable historical financial facts.

It has no inventory effect because the original line had no known inventory identity.

A linked open-ring return may identify its original completed line even though neither line identifies a product variant.

Detailed financial reversal behavior belongs to Returns.

---

# 16\. Line direction

Every active financial line has an explicit direction:

```
sale
return
```

Quantity remains positive for both.

Examples:

```
direction = sale
quantity  = 2
```

means two items sold.

```
direction = return
quantity  = 2
```

means two items returned.

ShelfSense must not encode return meaning as:

```
quantity = -2
```

The consolidated return design explicitly establishes direction as business meaning and keeps quantity positive.

---

# 17\. Economic sign

Transaction arithmetic derives economic sign from direction rather than quantity.

Conceptually:

```
sale line
    contributes positive sale value

return line
    contributes reversal/negative net transaction value
```

The exact calculation representation belongs to the calculation contracts.

The important domain rule is:

> **Quantity describes how many units. Direction describes whether those units are leaving or returning to store custody.**

---

# 18\. Mixed transactions

A transaction may contain both:

```
sale-direction lines
```

and:

```
return-direction lines
```

This naturally supports exchange transactions.

For example:

```
Return original book       $16.00
Sell replacement book      $20.00
                           ------
Customer owes               $4.00
```

The transaction does not need a special `exchange` line type.

Exchange is an orchestration of ordinary return and sale lines.

---

# 19\. Linked return lines

A linked return should reference the original completed sale line.

Conceptually:

```
original_transaction_line_id
```

or equivalent linkage.

The original line supplies the historical facts needed for return processing, including:

* merchandise identity;  
* exact inventory unit where applicable;  
* original quantity;  
* original selling price;  
* historical discounts/allocations;  
* historical tax;  
* original inventory effect.

The exact schema is owned by the Returns specification.

---

# 20\. Return quantity

For quantity-tracked merchandise, linked-return quantity is a positive integer not exceeding the remaining returnable quantity according to the Returns rules.

For individually tracked merchandise:

```
quantity = 1
```

and the return identifies the exact unit sold originally.

ShelfSense must not substitute another inventory unit of the same variant.

---

# 21\. Line working state

While the parent transaction is mutable, a line is:

```
active
```

or:

```
voided
```

These are **working-state concepts**, not economic direction.

A voided sale line is not a return.

A voided return line is not a sale.

---

# 22\. Active lines

An active line:

* participates in transaction calculations;  
* contributes to customer-facing transaction content;  
* participates in tax/discount calculations as applicable;  
* participates in completed inventory behavior if the transaction completes.

Only active lines are frozen as active financial content at completion.

---

# 23\. Voided lines

A line void represents pre-completion removal of a meaningful working line from the transaction.

A voided line:

* does not contribute to transaction financial totals;  
* does not appear as an active line on the customer receipt;  
* creates no completed inventory effect;  
* remains internally retained when meaningful for audit/operational purposes.

A void is **not** a financial reversal because no completed financial fact existed yet.

---

# 24\. Soft void

Meaningful persisted transaction lines should normally be soft-voided rather than physically deleted.

A void may preserve facts such as:

```
voided_at
voided_by
reason
approved_by
```

when applicable.

The exact persistence fields remain implementation concerns.

The key invariant is:

> **ShelfSense should preserve enough information to distinguish a cashier correction from a line that never existed.**

The consolidated design specifically requires meaningful scanned lines to remain available for operational/loss-prevention reporting after voiding.

---

# 25\. Reason and approval policy for voids

Not every line void requires a reason or supervisor approval.

Routine corrections must remain fast.

For example:

```
scan item
immediately realize duplicate scan
void line
```

may require no additional friction.

Reasons and approvals may become required based on explicit policy dimensions such as:

* amount;  
* action type;  
* merchandise class;  
* department;  
* timing;  
* other defined risk criteria.

The line model must support the required facts without encoding the policy itself.

Detailed controls belong to Approvals.

---

# 26\. Quantity rules

Quantity always represents physical/business item count rather than economic sign.

General rule:

```
quantity > 0
```

for active lines.

Special rules:

| Line | Quantity |
| :---- | :---- |
| Quantity-tracked merchandise | Positive integer |
| Individually tracked merchandise | Exactly 1 |
| Open ring | Positive integer |
| Sale line | Positive |
| Return line | Positive |

Fractional quantities are not part of the current POS contract.

If ShelfSense later supports weight/measure merchandise, that would require a deliberate quantity-model extension rather than silently changing the integer invariant.

---

# 27\. Setting quantity to zero

Setting an active line's quantity to zero is semantically a line void.

The POS should translate:

```
quantity = 0
```

into:

```
line → voided
```

rather than retaining an active zero-quantity line.

There should be no active line whose quantity contributes nothing.

---

# 28\. Quantity mutation

Quantity may change while:

```
transaction.status = open
line.state = active
```

subject to line-type rules.

Changing quantity must cause all dependent provisional values to be recalculated, including as applicable:

* line extension;  
* discounts;  
* transaction-discount allocations;  
* taxable basis;  
* tax;  
* transaction total.

The calculation details belong to their respective specifications.

---

# 29\. Individually tracked quantity cannot change

An individually tracked line always represents one exact physical unit.

Therefore:

```
quantity = 1
```

cannot be changed to:

```
quantity = 2
```

If two individually tracked copies are sold:

```
Unit A → Line 1
Unit B → Line 2
```

even if both are variants of the same product.

---

# 30\. Repeated scans

Repeated scans of quantity-tracked merchandise may consolidate into an existing active line.

However, matching only:

```
product_variant_id
```

is insufficient.

Consolidation is allowed only when all financially and operationally meaningful line attributes are compatible.

At minimum this includes the same:

* direction;  
* product variant;  
* selling price;  
* price-override state;  
* discount treatment;  
* tax treatment;  
* other line-specific commercial state.

The source design explicitly requires these attributes to match before repeated scans consolidate.

---

# 31\. Consolidation invariant

The governing consolidation rule is:

> **Two physical items may share one quantity-tracked line only if separating them would not preserve any additional financially, operationally, or historically meaningful fact.**

For example:

### Consolidate

```
Book A
Regular price $16
No override
No discount
Same tax
```

scanned twice:

```
Book A
Qty 2 × $16
```

### Do not consolidate

First copy:

```
Book A
$16 regular price
```

Second copy:

```
Book A
$15 price override
```

Result:

```
Line 1: Qty 1 × $16
Line 2: Qty 1 × $15
```

---

# 32\. Consolidation after adjustments

If an existing quantity line later receives a line-specific adjustment that makes one physical unit commercially different from the others, the operation may require splitting the line.

For example:

```
Qty 3 × $16
```

cannot accurately represent:

```
2 × $16
1 × $15 override
```

The UI/application workflow should split the quantity as necessary so each line remains economically homogeneous.

The exact UX for line splitting belongs to workflow/implementation design.

---

# 33\. Individually tracked lines never consolidate

Individually tracked merchandise never consolidates into a multi-quantity line even when:

* product variant is identical;  
* selling price is identical;  
* tax treatment is identical.

Exact inventory-unit identity is itself a meaningful difference.

---

# 34\. Open-ring consolidation

Open-ring lines should not automatically consolidate merely because:

```
department
price
tax
```

happen to match.

An open ring represents cashier-entered knowledge, and two separately entered open rings may represent separate physical/operational observations.

### Recommended initial behavior

Keep separately entered open rings as separate lines unless the cashier explicitly uses quantity on the same line.

This preserves the distinction between:

```
enter one open ring, quantity 2
```

and:

```
enter two separate open rings
```

### Status

This exact automatic-consolidation policy is not explicitly resolved by the consolidated design and should be treated as a workflow decision rather than an immutable domain rule.

---

# 35\. Sale and return consolidation

Quantity-tracked sale and return lines must never consolidate with one another because direction differs.

For example:

```
sell Variant A qty 1
return Variant A qty 1
```

must remain two distinct lines even though net quantity and value might cancel.

This is necessary for correct reporting of:

* gross sales;  
* gross returns;  
* inventory effects;  
* tax reversals.

---

# 36\. Linked-return consolidation

Whether multiple linked return selections from the same original sale line consolidate into one return line should be governed by the Returns workflow.

If consolidation is allowed, the line must retain the same original-line linkage and historical financial basis.

Return lines originating from different original completed sale lines must not be merged merely because they reference the same current product variant.

Their historical:

* selling prices;  
* discounts;  
* taxes;  
* receipts;

may differ.

---

# 37\. Merchandise identity

For merchandise lines, completed identity should preserve both reference and historical presentation facts.

The line references the known current-domain object:

```
product_variant_id
```

and when applicable:

```
inventory_unit_id
```

The reference is not sufficient by itself for historical presentation.

---

# 38\. Snapshot principle

The governing snapshot rule is:

> **Foreign keys describe what a line referred to. Snapshots describe what actually happened.**

This is necessary because referenced master data may later change.

The consolidated design explicitly requires completed lines to preserve customer-facing description, identifiers where useful, department, tax classification, pricing-source information, prices, discounts, and tax results.

---

# 39\. Completed merchandise-line snapshots

Depending on the line's actual features, a completed merchandise line should preserve enough immutable information to reconstruct:

### Identity/presentation

* customer-facing description;  
* relevant product/variant identifier or SKU;  
* product/variant reference;  
* exact inventory-unit reference where applicable.

### Classification

* department;  
* merchandise classification needed for reporting;  
* tax-class identity/treatment as applicable.

### Pricing

* price source;  
* reference unit price;  
* selling unit price;  
* price override information where applicable.

### Discounts

* line-level discount results;  
* allocated transaction-level discount results where applicable.

### Tax

* completed taxable basis;  
* tax components/results as required by Tax.

### Quantity/direction

* positive quantity;  
* sale/return direction.

The exact field placement between the line and associated child records belongs to schema design.

---

# 40\. Snapshot timing

Snapshots are finalized at transaction completion.

Before completion, provisional line information may be recalculated or refreshed according to the applicable workflow.

After completion:

> **Historical line snapshots are immutable.**

Changing current merchandise master data must not change:

* the completed receipt;  
* completed financial reporting;  
* return basis;  
* historical tax/discount information.

---

# 41\. Open-ring snapshots

Because an open ring has no referenced merchandise master record, the cashier-entered/computed facts themselves constitute the historical identity.

Completed open-ring facts should preserve as applicable:

* description;  
* department;  
* quantity;  
* entered unit price;  
* selling price;  
* tax classification/treatment;  
* tax result;  
* discount results;  
* reason;  
* actors/approvals as required.

An open ring does not later acquire a `product_variant_id` merely because somebody identifies the item after completion.

---

# 42\. Price relationship

Transaction Lines owns the association of pricing facts with a line but not the price-resolution algorithm.

Conceptually, merchandise lines support:

```
reference_unit_price
selling_unit_price
```

Pricing defines how those values are obtained and how overrides work.

For open rings:

```
selling_unit_price = cashier-entered price
```

and there is no merchandise reference price.

---

# 43\. Discount relationship

A line may have:

* line-level discounts;  
* allocated effects from transaction-level discounts.

Transaction Lines does not own the discount algorithms.

It does own the requirement that completed line history remain sufficient to determine its actual final financial contribution and historical return basis.

Return-direction lines reverse historical discounts rather than receiving new current sale discounts according to the established Discounts rules.

---

# 44\. Tax relationship

Every active financial line must have sufficient tax classification/input to be included correctly in transaction tax calculation.

Tax owns:

* rules;  
* rates;  
* component calculations;  
* rounding;  
* treatment.

Transaction Lines owns:

* the line's applicable classification/context;  
* completed association with the actual tax result.

An open ring obtains tax treatment through its entered/resolved classification rather than a product variant.

---

# 45\. Inventory relationship

Inventory effects differ by line kind.

| Line | Sale inventory effect | Return inventory effect |
| :---- | :---- | :---- |
| Quantity-tracked merchandise | Decrease quantity | Restore quantity |
| Individually tracked merchandise | Exact unit leaves stock | Exact unit returns |
| Non-inventory merchandise | None | None |
| Open ring | None | None |

Detailed posting behavior belongs to Inventory Integration.

The transaction line records the facts required to determine the applicable effect.

---

# 46\. Individually tracked local reservation

While an individually tracked sale transaction remains open, the exact unit may be locally reserved/marked unavailable for another local working transaction.

That operational reservation:

* is not a completed sale;  
* is not an inventory-ledger movement;  
* does not change line quantity;  
* remains associated with the exact unit.

Completion converts the exact unit's sale into a durable originating fact according to Inventory Integration.

---

# 47\. Duplicate exact-unit scan in one transaction

The same inventory unit must not appear twice as active sale lines on the same transaction.

If a cashier scans the same exact unit again, the POS should reject the duplicate and surface the existing active line.

It must not:

```
increase quantity to 2
```

because one physical unit cannot represent two units sold.

This behavior should be part of the Individually Tracked Sale workflow.

---

# 48\. Offline duplicate-unit conflict between workstations

Two disconnected workstations may each believe the same inventory unit is sellable.

If both complete a sale for that exact unit:

* both completed transaction histories are preserved;  
* neither line is rewritten to identify another unit;  
* the server detects the inventory conflict;  
* the conflicting inventory effect enters reconciliation/quarantine according to policy.

The POS line's exact historical unit identity is therefore immutable even when it later proves operationally conflicting.

---

# 49\. Returns relationship

Return lines use the same fundamental line model:

```
line_type = merchandise/open_ring
direction = return
quantity  = positive
```

There is no separate parallel “return-line” data model required simply because direction differs.

Returns adds:

* original-line linkage;  
* remaining-returnable quantity rules;  
* historical reversal calculations;  
* authorization/eligibility rules.

---

# 50\. Return inventory behavior

A recognized merchandise return reverses the original sale's inventory effect.

For quantity merchandise:

```
return → restore quantity
```

For individually tracked merchandise:

```
return → restore exact original inventory unit
```

The POS line does not contain a return-disposition field.

If merchandise is subsequently considered damaged, unsellable, return-to-vendor, etc., that is handled by an Inventory workflow after the POS return.

---

# 51\. No signed quantities

ShelfSense must not use signed quantity to combine:

* direction;  
* line state;  
* inventory effect.

These meanings remain separate.

Incorrect conceptual model:

```
sale   qty +1
return qty -1
void   qty  0
```

Correct model:

```
direction = sale | return
state     = active | voided
quantity  = positive integer
```

This makes reporting and validation explicit.

---

# 52\. Monetary amount representation

Line monetary values represent business amounts according to Pricing, Discounts, and Tax.

Direction determines whether those amounts contribute as sale activity or reversal activity to transaction net totals.

The line model should not rely on arbitrary negative unit prices to mean return.

Exact cents/sign rules should be formalized in the shared calculation contract rather than duplicated here.

---

# 53\. Working-line mutation

While the parent transaction is open, an active line may be modified according to supported capabilities.

Possible mutations include:

* quantity change;  
* price override;  
* discount changes;  
* tax/context refresh where permitted;  
* void.

Each meaningful mutation should cause dependent calculations to be recomputed and may create transaction activity history.

---

# 54\. Suspended transaction lines

When the parent transaction is suspended:

* its line state is preserved;  
* lines do not become completed;  
* completed snapshots are not yet historical facts;  
* no completed inventory movement occurs.

When recalled, line reference-dependent values may be refreshed according to the future suspended-transaction refresh policy.

Manual values must not silently disappear merely because the transaction was suspended.

---

# 55\. Completed-line immutability

Once the parent transaction completes:

* active completed lines become immutable historical facts;  
* quantities cannot be edited;  
* direction cannot change;  
* merchandise identity cannot change;  
* inventory-unit identity cannot change;  
* financial snapshots cannot change.

If a completed line needs economic reversal:

```
create a return/reversal fact
```

not:

```
edit original line
```

---

# 56\. Voided lines at transaction completion

A transaction may retain voided working lines for operational/audit history.

Voided lines:

* are not customer financial content;  
* do not contribute to transaction totals;  
* do not generate completed inventory effects.

Whether they are stored in the same physical table as active completed lines or retained through an associated audit representation is an implementation/schema choice.

The domain requirement is that meaningful void history remains explainable.

---

# 57\. Activity history

Meaningful line-level events should be represented in POS transaction activity history.

Examples include:

```
line_added
quantity_changed
line_voided
price_override_applied
price_override_changed
price_override_removed
discount_applied
approval_granted
```

The line itself remains the authoritative current/completed state.

The activity stream is explanatory; ShelfSense is not event-sourced.

Every scanner keystroke or focus event must not become an audit record.

---

# 58\. Reporting behavior

Completed active lines support financial and operational reporting by dimensions such as:

* store;  
* workstation;  
* business date;  
* Z-period;  
* cashier;  
* approver;  
* direction;  
* line type;  
* department;  
* product;  
* variant;  
* inventory unit;  
* open-ring reason;  
* quantity;  
* reference/selling price;  
* override variance;  
* discount;  
* tax treatment.

Voided lines may support separate operational reporting:

* void count;  
* voided item count;  
* voided value;  
* actor;  
* approver;  
* reason.

Voided value must not be treated as negative revenue.

---

# 59\. Receipt behavior

Customer receipts show active completed financial lines.

Voided pre-completion lines are not presented as customer purchases.

For merchandise lines, the receipt uses the completed customer-facing description and actual selling price.

For open rings, the receipt uses the completed description/classification presentation defined by Receipt policy.

Internal information such as:

* reference-price variance;  
* approval metadata;  
* internal classification IDs;

does not automatically belong on the customer receipt.

---

# 60\. Conceptual line model

This specification does not lock schema names, but the conceptual shape is approximately:

```
Transaction Line
│
├── id
├── transaction
│
├── line_type
│   ├── merchandise
│   └── open_ring
│
├── direction
│   ├── sale
│   └── return
│
├── working_state
│   ├── active
│   └── voided
│
├── quantity
│
├── merchandise identity
│   ├── product_variant
│   └── inventory_unit
│
├── open-ring classification
│   ├── department
│   ├── description
│   └── reason
│
├── pricing snapshots/relations
├── discount relations
├── tax relations
│
├── original_transaction_line   # linked return, when applicable
│
└── void/audit metadata
```

Exact columns, nullability, associated tables, and denormalized snapshot fields belong to implementation/schema planning.

---

# 61\. Domain invariants by line type

## Merchandise

```
product_variant required
```

If quantity tracked:

```
inventory_unit absent
quantity > 0
```

If individually tracked:

```
inventory_unit required
quantity = 1
```

## Open ring

```
product_variant absent
inventory_unit absent
department required
quantity > 0
selling price required
```

Open ring creates no inventory effect.

---

# 62\. Domain invariants by direction

## Sale

Represents merchandise/value provided to the customer.

## Return

Represents reversal of previously sold value according to Returns rules.

Both:

```
quantity > 0
```

Sale and return lines do not consolidate with each other.

---

# 63\. Domain invariants by working state

## Active

* contributes to current transaction;  
* may become completed financial content.

## Voided

* does not contribute to totals;  
* produces no completed inventory effect;  
* may remain for operational audit.

An active quantity-zero line is prohibited; zero means void.

---

# 64\. Domain ownership

## Transaction Lines owns

* line identity;  
* line type;  
* line direction;  
* active/voided state;  
* quantity rules;  
* merchandise/individual-unit association;  
* open-ring identity/classification;  
* line consolidation invariants;  
* completed snapshot requirement;  
* line mutation/immutability boundary;  
* linkage needed for returns;  
* void-history requirement.

## Transactions owns

* parent transaction lifecycle;  
* completion boundary;  
* transaction-level immutability;  
* overall transaction state.

## Pricing owns

* price source;  
* reference price;  
* selling price;  
* override semantics.

## Discounts owns

* adjustment types;  
* sequencing;  
* allocation.

## Tax owns

* tax calculation;  
* taxable basis;  
* component arithmetic.

## Returns owns

* return eligibility;  
* remaining returnable quantity;  
* historical reversal calculations;  
* unlinked-return policy.

## Inventory Integration owns

* local inventory effects;  
* central ledger posting;  
* exact-unit state transitions;  
* duplicate-unit conflicts.

## Approvals owns

* reason/approval requirements;  
* thresholds;  
* second-actor policy.

## Receipts owns

* customer presentation.

---

# 65\. Delivery by phase

## Phase 4 — Contract foundation

Establish enough line representation to support the headless completed-sale contract.

Implement or define:

* stable line identity;  
* merchandise line type;  
* direction field;  
* positive quantity;  
* product-variant reference;  
* completed snapshots;  
* regular pricing/tax relationships;  
* serialization in completed-sale payload.

Open-ring and individual-unit shapes may be represented in the contract architecture without needing production workflows.

---

## Phase 5 — First operational sale

Implement:

```
line_type = merchandise
direction = sale
tracking  = quantity-tracked
```

with:

* barcode/manual identifier resolution;  
* positive integer quantity;  
* repeated-scan consolidation;  
* quantity change;  
* pre-completion void;  
* regular price;  
* tax;  
* completed snapshots.

Phase 5 excludes by default:

* open rings;  
* individually tracked units;  
* returns;  
* price overrides;  
* discounts.

---

## Phase 5.1 / Phase 6.1 — Individually tracked merchandise

If pilot requirements demand used/unit-tracked merchandise, pull forward:

* exact inventory-unit identity;  
* quantity-one invariant;  
* duplicate same-transaction rejection;  
* local unit reservation;  
* local completion state;  
* server exact-unit posting;  
* offline duplicate-unit reconciliation.

Otherwise deliver in Phase 6.1.

---

## Phase 6.1 — Merchandise breadth and corrections

Add:

* open-ring lines;  
* richer void reason/approval behavior;  
* price overrides;  
* suspend/recall interactions;  
* full activity history behavior.

---

## Phase 6.3 — Discounts

Extend line commercial state with:

* line discounts;  
* transaction-discount allocations.

Update consolidation rules accordingly.

---

## Phase 6.4 — Returns

Activate:

```
direction = return
```

with:

* linked original-line identity;  
* remaining-returnable quantity;  
* historical price/discount/tax reversal;  
* exact-unit returns;  
* open-ring linked returns.

---

# 66\. Deferred capabilities

The line model should leave room for, but does not currently define:

* fractional/weighted quantity merchandise;  
* service-specific line types;  
* future fee line types;  
* transaction-level charge types that may not belong as merchandise lines;  
* complex promotion-generated synthetic lines;  
* cross-register ownership of open lines.

Any future line type should be introduced only after determining that it cannot be represented accurately by existing line concepts.

---

# 67\. Pending decisions

The following line-specific questions remain intentionally unresolved.

## 67.1 Exact open-ring reason policy

Determine:

* when a reason is optional;  
* when required;  
* which reasons exist;  
* when approval is required.

Target: Phase 6.1.

## 67.2 Open-ring discount eligibility

Determine default eligibility for:

* manual discounts;  
* transaction discounts;  
* promotions requiring merchandise identity.

Target: Phase 6.3.

## 67.3 Automatic open-ring consolidation

Recommended initial behavior is not to auto-consolidate separately entered open rings, but this should be confirmed with cashier UX design.

## 67.4 Return-line consolidation

Determine whether repeated linked-return selections from the same original line automatically merge.

Target: Phase 6.4.

## 67.5 Unvoid behavior

The current source defines active/voided lines and meaningful void history but does not explicitly settle whether a cashier may directly restore a voided line.

Possible approaches include:

* permit explicit unvoid with activity history;  
* require adding a new line instead.

This should be settled before broader line-correction UX is finalized.

## 67.6 Meaningful line persistence

Determine exactly when a newly entered working line becomes meaningful enough that later void/cancellation should retain it rather than treat it as ephemeral UI state.

This should align with the transaction cancellation-retention policy.

## 67.7 Fractional quantities

Not currently required. If weight/measure merchandise is introduced, revisit the positive-integer quantity invariant explicitly.

---

# 68\. Core invariants summary

The following rules are considered authoritative unless deliberately superseded:

1. **Line type, direction, working state, and inventory tracking are independent concepts.**  
2. **Core line types are merchandise and open ring.**  
3. **Economic direction is explicitly sale or return.**  
4. **Quantity is positive; negative quantity never represents a return.**  
5. **Working lines are active or voided.**  
6. **A zero quantity means void, not an active zero-value line.**  
7. **Quantity-tracked merchandise may use quantity greater than one.**  
8. **Individually tracked merchandise always has quantity one and exact unit identity.**  
9. **Individually tracked lines never consolidate.**  
10. **Repeated quantity-tracked scans consolidate only when all meaningful commercial attributes match.**  
11. **Sale and return lines never consolidate with one another.**  
12. **Meaningful line voids are retained rather than physically erased.**  
13. **A void is pre-completion cancellation of a line, not a financial return.**  
14. **Open rings are explicit lines, never pseudo-products.**  
15. **Open rings preserve quantity.**  
16. **Open-ring entered price is a selling price, not a price override.**  
17. **Open rings create no inventory movement.**  
18. **Known non-inventory merchandise remains merchandise, not open ring.**  
19. **Completed lines preserve immutable historical snapshots.**  
20. **Foreign keys identify referenced master records; snapshots describe what actually occurred.**  
21. **Completed line identity, quantity, direction, exact unit, and financial snapshots cannot be edited.**  
22. **Corrections to completed line economics occur through new return/reversal/correction facts.**  
23. **A linked individually tracked return uses the exact unit originally sold.**  
24. **Inventory disposition after a return is an inventory workflow, not a POS line attribute.**

---

# 69\. Acceptance examples

## Example A — repeated quantity-tracked scan

Given an active sale line:

```
Variant A
Qty 1
Selling price $16
No discount
Tax treatment X
```

when the same variant is scanned again with identical commercial treatment,

then:

```
Qty becomes 2
```

rather than creating a second line.

---

## Example B — different price requires separate line

Given:

```
Variant A
Qty 2
Price $16
```

when another copy of Variant A is sold at an authorized $15 selling price,

then the transaction contains:

```
Line 1
Variant A
Qty 2
Price $16

Line 2
Variant A
Qty 1
Price $15
```

The $15 unit is not hidden inside the quantity-three line.

---

## Example C — individually tracked merchandise

Given two used copies of the same variant:

```
Unit A
Unit B
```

when both are sold,

then:

```
Line 1 → Unit A, Qty 1
Line 2 → Unit B, Qty 1
```

They do not consolidate.

---

## Example D — duplicate individually tracked scan

Given Unit A already exists as an active sale line,

when Unit A is scanned again,

then:

* no second active sale line is created;  
* quantity does not become two;  
* the POS identifies the duplicate exact-unit scan.

---

## Example E — quantity zero

Given an active quantity-tracked line,

when its quantity is changed to zero,

then:

* the line becomes voided;  
* it no longer contributes to transaction totals;  
* meaningful void history remains available.

---

## Example F — open ring

Given the cashier must sell two unidentified merchandise items at $5 each,

when the cashier creates an open ring with:

```
Department: General Merchandise
Qty:        2
Unit price: $5
```

then:

* no product variant is invented;  
* no inventory movement is created;  
* the line contributes $10 before tax/discount treatment;  
* quantity two remains historically preserved.

---

## Example G — known non-inventory merchandise

Given ShelfSense knows the exact product variant but the variant does not track inventory,

when it is sold,

then:

* the line is `merchandise`;  
* the product variant is preserved;  
* no inventory effect occurs;  
* the line is not converted into an open ring.

---

## Example H — sale and return of same variant

Given a transaction contains:

```
Sale Variant A Qty 1
Return Variant A Qty 1
```

then the lines remain separate.

Reporting retains:

* one gross sale;  
* one gross return;

even if their financial net is zero.

---

## Example I — linked exact-unit return

Given Unit A was previously sold,

when a linked return is completed,

then:

* the return line references the original sale line;  
* direction is `return`;  
* quantity is one;  
* inventory identity remains Unit A;  
* ShelfSense does not substitute Unit B.

---

## Example J — voided line

Given a cashier scans an item and then voids the line before transaction completion,

then:

* the line does not contribute to the customer transaction;  
* no sale/inventory effect occurs for that line;  
* meaningful void metadata may remain available for audit/reporting.

---

# 70\. Related workflow specifications

This specification should be referenced by:

* `workflows/sales/cash-sale.md`  
* `workflows/sales/add-merchandise.md`  
* `workflows/sales/manual-lookup.md`  
* `workflows/sales/repeated-scan.md`  
* `workflows/sales/change-quantity.md`  
* `workflows/sales/void-line.md`  
* `workflows/sales/complete-transaction.md`  
* `workflows/sales/individual-unit-sale.md`  
* `workflows/sales/open-ring.md`  
* `workflows/adjustments/price-override.md`  
* `workflows/adjustments/line-discount.md`  
* `workflows/returns/linked-return.md`  
* `workflows/returns/individual-unit-return.md`  
* `workflows/returns/exchange.md`

---

# 71\. Related contract specifications

Transaction Lines depends on exact contracts for:

* completed-sale line payload;  
* pricing calculations;  
* discount allocation;  
* tax components;  
* return allocation;  
* inventory-unit identity;  
* reference-data snapshots.

This specification defines **what a line means**.

Those contracts define **how Rails and the POS encode and calculate that meaning identically**.