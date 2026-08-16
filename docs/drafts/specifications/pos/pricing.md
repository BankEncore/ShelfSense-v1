# POS Domain Specification: Pricing

**Design status:** Core behavior decided; initial price-source hierarchy partly decided; future pricing sources remain extensible **Implementation status:** Planned incrementally across Phases 4–6 **Initial foundation:** Phase 4 — POS Runtime and Contract Foundation **First operational delivery:** Phase 5 — First Operational Cash Sale **Price-override delivery:** Phase 6.1 — Merchandise Breadth and Transaction Corrections **Related specifications:** Transactions, Transaction Lines, Discounts, Tax, Approvals, Receipts, Returns, Reference Replication, Reconciliation **Related workflows:** Cash Sale, Add Merchandise, Individually Tracked Sale, Price Override, Suspend/Recall, Linked Return

---

## 1\. Purpose

This specification defines the ShelfSense POS pricing domain.

It establishes:

* how POS resolves a merchandise line's initial price;  
* the distinction between reference price and selling price;  
* price-source identity and versioning;  
* initial price-source precedence;  
* pricing behavior for quantity-tracked and individually tracked merchandise;  
* pricing behavior for open rings;  
* price-override semantics;  
* price-override audit and approval requirements;  
* multi-quantity pricing behavior;  
* pricing snapshot requirements;  
* historical pricing immutability;  
* offline and stale-price behavior;  
* pricing interaction with discounts, tax, returns, receipts, and reporting.

This specification does **not** define:

* discount calculation;  
* promotion qualification;  
* tax calculation;  
* price-override approval thresholds;  
* return eligibility;  
* receipt layout;  
* master-data administration screens;  
* a future generalized promotional pricing engine.

Those rules belong to their owning specifications.

---

# 2\. Governing pricing model

ShelfSense distinguishes:

```
reference unit price
        ↓
optional explicit price override
        ↓
selling unit price
        ↓
line discounts
        ↓
transaction-discount allocations
        ↓
net merchandise amount / taxable basis
        ↓
tax
```

These stages are intentionally distinct.

The consolidated POS design establishes that a price override changes the selling price, while a discount reduces the amount charged from the selling price. Promotions are producers of discounts rather than another name for price override.

---

# 3\. Core pricing terms

## 3.1 Reference unit price

The **reference unit price** is the price ShelfSense resolves for one unit of merchandise before any cashier price override.

Conceptually:

```
reference_unit_price_cents
```

It answers:

> What price did ShelfSense's configured pricing data say this item should sell for at the time the line was priced?

The reference price is preserved even if the cashier later overrides the selling price.

---

## 3.2 Selling unit price

The **selling unit price** is the actual unit price used as the starting point for customer charges.

Conceptually:

```
selling_unit_price_cents
```

Without a price override:

```
selling_unit_price_cents
=
reference_unit_price_cents
```

With an override:

```
selling_unit_price_cents
≠
reference_unit_price_cents
```

Discounts do **not** change `selling_unit_price_cents`.

They reduce the financial amount downstream from it.

---

## 3.3 Net merchandise amount

The net merchandise amount is the amount remaining after applicable discounts.

It is not another synonym for selling price.

For example:

```
Reference price:      $20.00
Selling price:        $18.00  # price override
Discount:              $2.00
Net merchandise:      $16.00
```

ShelfSense must be able to distinguish:

```
$2.00 override variance
```

from:

```
$2.00 discount
```

because they have different:

* business meaning;  
* authorization;  
* reporting;  
* receipt presentation;  
* return behavior.

---

# 4\. Why reference and selling price are separate

Consider merchandise configured at `$16.00` but physically mislabeled `$15.00`.

ShelfSense should preserve:

```
reference_unit_price = $16.00
selling_unit_price   = $15.00
```

The customer bought the item for `$15.00`.

The `$1.00` difference is an internal price-integrity fact.

It is **not** a customer discount.

The consolidated design explicitly requires both values to be preserved and treats the variance as internal loss-prevention/reporting information rather than customer-facing discount activity.

---

# 5\. Price resolution

Price resolution determines the reference unit price for a merchandise line.

Conceptually:

```
PriceResolver.resolve(...)
    ↓
reference unit price
price source
source identity/version
```

The resolver should produce enough information that ShelfSense can later answer:

> Why did this completed line have this reference price?

---

# 6\. Deterministic behavior

For the same relevant:

* merchandise identity;  
* inventory-unit identity;  
* cached reference state;  
* configuration/version context;

the Rails and POS implementations must produce the same result.

Price resolution should therefore be represented by a deterministic calculation/resolution contract and portable fixtures where cross-platform behavior is relevant.

Phase 4 should establish this contract before Phase 5 builds the cashier UI around it.

---

# 7\. Offline price resolution

Ordinary supported POS merchandise must be priceable without a real-time server request.

The workstation therefore receives the pricing reference data required by the supported sale path through reference replication.

Conceptually:

```
server pricing configuration
        ↓ reference replication
workstation SQLite projection
        ↓
local price resolver
```

Network availability must not be required merely to determine the ordinary configured price of merchandise that the workstation is authorized to sell offline.

---

# 8\. Price-source identity

A resolved reference price should preserve information identifying where the price came from.

Conceptual price-source categories may include:

```
variant_regular
inventory_unit
```

The exact enum names are not locked by this specification.

The important requirement is that completed line history can distinguish the source used.

For example:

```
Source: Product Variant regular price
```

versus:

```
Source: Exact Inventory Unit approved selling price
```

---

# 9\. Price-source version/context

The resolver must preserve enough source/version context to explain the reference value after central pricing data changes.

This may include, depending on implementation:

* source record identity;  
* reference-data version;  
* source revision/version;  
* effective-date information where applicable.

The exact persistence representation belongs to schema and contract design.

The domain invariant is:

> **A completed line must remain able to explain the reference price that was actually used.**

---

# 10\. Initial quantity-tracked price resolution

For quantity-tracked merchandise, the initial resolver uses the product variant's configured regular price.

Conceptually:

```
quantity-tracked variant
        ↓
variant regular price
        ↓
reference_unit_price
```

This is the Phase 5 pricing path.

The consolidated design explicitly identifies the variant regular price as the initial resolver for quantity-tracked merchandise.

---

# 11\. Missing quantity-tracked price

For the Phase 5 path, a quantity-tracked variant without a resolvable regular price cannot silently invent a selling price.

ShelfSense should not automatically:

* use `$0`;  
* reuse a stale unrelated value;  
* create an open ring;  
* treat product list price as an unstated fallback;  
* prompt for an unrestricted cashier-entered price.

Instead, resolution fails and the cashier receives a configuration error.

A later explicit open-ring or override workflow must not be used to conceal broken merchandise configuration unless policy deliberately permits such an exception.

---

# 12\. Product list price is not currently a POS fallback

ShelfSense merchandise may retain product-level list price information.

However, the current POS design identifies **variant regular price** as the ordinary quantity-tracked POS source.

The source material does not establish product list price as an automatic fallback.

Therefore:

> **`product.list_price` should not become an implicit POS fallback unless a later pricing decision explicitly adds it to the resolver hierarchy.**

This avoids silently changing pricing semantics simply because another monetary field happens to exist.

---

# 13\. Individually tracked price resolution

For individually tracked merchandise, the initial intended hierarchy is:

```
exact inventory unit approved selling price
        ↓ if absent
variant regular price fallback
```

The consolidated design establishes exact-unit approved selling price as the preferred source when present, with a defined variant fallback required.

This supports used merchandise where physical copies of the same variant may legitimately carry different prices.

---

# 14\. Exact-unit price

Where an individually tracked inventory unit has its own approved selling price:

```
reference_unit_price
=
unit approved selling price
```

The price belongs to that exact unit.

For example:

```
Used Book Variant

Unit A — Good condition      $8.00
Unit B — Very Good          $11.00
Unit C — Acceptable          $5.00
```

Each unit receives its own line because inventory-unit identity and pricing are both independently meaningful.

---

# 15\. Individually tracked fallback

If the exact inventory unit does not carry an approved unit-specific price, the initial architecture permits a defined variant-level fallback.

The expected initial fallback is the variant's regular price.

The implementation contract must settle precisely:

* what qualifies as an available unit-specific price;  
* what value means “no unit-specific price”;  
* whether any additional fallback exists beyond variant regular price;  
* failure behavior when no permitted source resolves.

Until explicitly decided, ShelfSense must not introduce additional fallback levels implicitly.

---

# 16\. Known non-inventory merchandise

Known merchandise that does not affect inventory still uses normal merchandise price resolution.

It does not become an open ring merely because inventory is not tracked.

If it is a known quantity-style variant:

```
variant regular price
    → reference price
```

unless a later explicit pricing rule says otherwise.

Inventory behavior and pricing identity are independent.

---

# 17\. Open-ring pricing

Open rings do not use merchandise price resolution.

Because ShelfSense does not know the merchandise identity:

```
reference merchandise price = none
```

The cashier-entered unit price is the legitimate selling price.

Conceptually:

```
line_type = open_ring

reference_unit_price = absent
selling_unit_price   = entered price
```

This is not a price override because there was no resolved merchandise price to override.

The existing POS design explicitly distinguishes an entered open-ring price from a price override.

---

# 18\. Price override definition

A **price override** occurs when an authorized cashier explicitly changes a merchandise line's selling unit price away from its resolved reference unit price.

Conceptually:

```
resolved reference price = $16.00
cashier-entered override = $15.00

reference_unit_price = $16.00
selling_unit_price   = $15.00
```

A price override applies to known merchandise.

It is not:

* a discount;  
* a promotion;  
* an open-ring entered price;  
* a correction to master pricing data.

---

# 19\. Override does not modify master data

A POS price override affects the working transaction line only.

It must not update:

* variant regular price;  
* inventory-unit approved price;  
* central pricing configuration.

If the configured reference price itself is incorrect, staff should correct the appropriate master-data record through its administrative workflow.

A POS override records:

> We knowingly sold this transaction line at a different price.

It does not mean:

> The catalog price has now changed.

---

# 20\. Override scope

A price override normally changes the **unit selling price for the whole transaction line**.

For example:

```
Qty 3
reference_unit_price = $16
selling_unit_price   = $15
```

means all three units on that line are being sold at `$15` each.

ShelfSense should not maintain hidden per-unit price arrays inside a multi-quantity line.

---

# 21\. Mixed per-unit pricing requires line split

If only one item in a quantity line requires a different selling price, ShelfSense must represent it separately.

Incorrect:

```
Variant A
Qty 3
somehow:
  2 × $16
  1 × $15
```

Correct:

```
Line 1
Variant A
Qty 2
Reference $16
Selling   $16

Line 2
Variant A
Qty 1
Reference $16
Selling   $15
Override
```

This preserves economic homogeneity at line level and follows the Transaction Lines consolidation rules.

---

# 22\. Override variance

ShelfSense should be able to derive and report the difference between reference and selling price.

For one unit:

```
unit_override_variance
=
selling_unit_price
-
reference_unit_price
```

For a quantity line:

```
line_override_variance
=
unit_override_variance × quantity
```

The sign should be preserved so ShelfSense can distinguish downward and upward variance if both are permitted.

The exact reporting formulas belong in calculation/reporting contracts where necessary.

---

# 23\. Upward versus downward overrides

The core definition of override is an explicit change away from reference price.

The current design does not establish a universal rule prohibiting upward overrides.

Therefore, whether a cashier may:

* lower price only;  
* raise price;  
* do either within policy;

belongs to the approval/pricing policy.

The pricing model should not assume all override variance is negative.

---

# 24\. Override authorization

A price override is a controlled action.

The pricing domain requires the line to retain, as applicable:

* original reference price;  
* new selling price;  
* override reason;  
* performing actor;  
* occurrence time;  
* approver;  
* applicable policy/configuration version.

The exact threshold determining:

```
direct
approval required
prohibited
```

belongs to the Approvals specification.

The consolidated design also requires price-override policies to be able to consider both cents and percentage variance, with stronger approval requirements where configured.

---

# 25\. Override reason

The domain supports an explicit override reason.

Examples might eventually include business cases such as:

* shelf/sign mismatch;  
* damaged merchandise;  
* price match;  
* manager discretion.

The exact reason catalog is not locked here.

Whether a reason is:

* always required;  
* required only above thresholds;  
* optional;

belongs to policy configuration.

---

# 26\. Applying an override

While the parent transaction is open, an eligible active merchandise line may receive an override.

The conceptual operation is:

```
current:
reference = $16
selling   = $16

cashier requests $15
        ↓
authorization / approval
        ↓
selling = $15
reference remains $16
```

All downstream calculations must then be recalculated.

---

# 27\. Changing an override

While the transaction remains open, an existing override may be changed.

For example:

```
reference = $16
selling   = $15
```

may become:

```
reference = $16
selling   = $14
```

The meaningful before/after activity should remain auditable.

If the new requested price materially differs from the exact values previously approved, the prior approval no longer satisfies the new action and must be re-evaluated according to the Approvals specification.

---

# 28\. Removing an override

While open, a cashier may remove an override when authorized.

Removing it restores:

```
selling_unit_price
=
reference_unit_price
```

assuming the reference price itself has not been deliberately re-resolved in the meantime.

The apply/remove activity remains part of meaningful transaction history.

---

# 29\. Price re-resolution

A working line's reference price may sometimes need to be re-resolved before completion.

Potential triggers include:

* deliberate reference refresh;  
* suspended transaction recall;  
* changed exact-unit selection;  
* relevant pricing reference update becoming locally available.

The precise automatic refresh policy should be conservative and explicit.

ShelfSense must not silently change prices in a way that makes cashier-visible working state inexplicable.

---

# 30\. Re-resolution after override

If the reference price is deliberately re-resolved while an override exists, ShelfSense must preserve the distinction between:

```
new reference price
```

and:

```
cashier-selected selling price
```

However, the existing override and any approval may need revalidation because its variance relative to the reference price changed.

Example:

```
Old reference: $16
Override:      $15
```

then reference data refreshes to:

```
New reference: $14
Existing selling price: $15
```

The system must not silently treat the old approval context as unchanged.

The exact refresh/approval UX remains a workflow-policy decision.

---

# 31\. Suspended transaction pricing

Suspension does not create historical pricing.

A suspended transaction remains incomplete working state.

On recall, reference-dependent pricing may be refreshed according to the suspended-transaction policy.

The consolidated design specifically states that suspension does not permanently freeze historical pricing and that manual overrides must not silently disappear on recall.

### Pending

Before suspend/recall is implemented, ShelfSense must decide:

* whether variant regular prices refresh automatically;  
* whether unit-specific prices refresh;  
* how material changes are surfaced;  
* whether the cashier may retain the old selling price as a new explicit override;  
* how approvals are revalidated.

---

# 32\. Phase 5 pricing rule

Phase 5 deliberately uses the narrowest price behavior:

> **Sell supported quantity-tracked merchandise at its resolved configured regular price.**

Therefore:

```
reference_unit_price
=
variant regular price

selling_unit_price
=
reference_unit_price
```

Phase 5 does not implement:

* price override;  
* manual discount;  
* promotion;  
* open-ring entered pricing;  
* individually tracked price resolution unless the optional unit-tracked pilot slice is pulled forward.

If a regular price cannot resolve, the item cannot complete through the normal Phase 5 sale path.

---

# 33\. Price override begins in Phase 6.1

Phase 6.1 adds the controlled override workflow.

That includes:

* entering a new selling unit price;  
* reason handling;  
* permission evaluation;  
* approval thresholds;  
* second-actor approval where required;  
* changing/removing overrides;  
* audit/activity history;  
* receipt behavior;  
* reporting variance.

This should be implemented as a coherent capability rather than as an ad hoc cashier-entered price field.

---

# 34\. Pricing and discounts

Pricing and discounts are separate domains.

Pricing establishes:

```
reference unit price
selling unit price
```

Discounts then reduce the amount charged.

For example:

```
Reference price             $20.00
Selling price override      $18.00
Line discount                $1.80
Net line basis              $16.20
```

The `$2.00` override variance and `$1.80` discount remain separately reportable.

The current POS architecture explicitly requires this sequencing.

---

# 35\. Pricing and promotions

A promotion does not directly redefine reference price under the current model.

Instead:

```
promotion
    ↓
causes one or more discounts
```

This protects the distinction between:

* normal/reference price;  
* actual selling price override;  
* promotional/customer adjustment.

If a future pricing feature genuinely changes the definition of the resolved reference price, that capability should be explicitly added to the price-source hierarchy rather than modeled ambiguously as a discount.

---

# 36\. Pricing and tax

Tax is calculated downstream from pricing and discounts.

Conceptually:

```
reference price
→ selling price
→ discounts
→ taxable basis
→ tax
```

Tax therefore uses the actual post-override/post-discount taxable amount rather than the original reference price.

The detailed taxable-basis and rounding rules belong to `tax.md`.

---

# 37\. Pricing and line consolidation

Two quantity-tracked merchandise units may share the same line only when their financially meaningful pricing attributes match.

At minimum:

```
same reference price context
same selling price
same override state
```

along with the other Transaction Lines requirements.

A price difference requires a distinct line.

---

# 38\. Pricing and quantity changes

For a homogeneous quantity line:

```
line pre-discount amount
=
selling_unit_price × quantity
```

Changing quantity does not change the unit reference/selling price by itself under the initial pricing model.

Future quantity-break pricing would require an explicit pricing capability and resolver contract; it is not implied today.

---

# 39\. Completed pricing snapshots

When a transaction completes, each active merchandise line must preserve the actual pricing facts used.

At minimum, conceptually:

```
reference_unit_price_cents
selling_unit_price_cents

price_source
price_source_identity/version
```

and, where applicable:

```
override reason
override actor
override time
override approval
```

Exact column/table placement remains an implementation decision.

The important invariant is historical reproducibility.

---

# 40\. Completed pricing is immutable

Once the parent transaction is completed:

* reference unit price cannot change;  
* selling unit price cannot change;  
* price source cannot change;  
* override facts cannot change.

A later master price edit does not change the completed line.

A completed transaction must never be centrally “corrected” by repricing it against current master data.

This follows the broader governing POS rule that completed price snapshots remain historical facts.

---

# 41\. Offline stale-price behavior

A workstation may complete a valid offline sale using a cached reference price that is no longer the current central price.

For example:

```
Workstation cached price: $16
Central price changed:    $17
Workstation offline
Cashier sells at:         $16
```

When synchronization occurs:

> **The completed transaction remains a $16 sale.**

The server must not silently rewrite it to `$17`.

Stale pricing may produce:

* acceptance;  
* acceptance with warning;  
* quarantine;

according to the reconciliation policy, but the originating completed fact remains preserved unless the operation is structurally invalid.

The consolidated design explicitly lists stale price as an expected distributed reconciliation condition and prohibits central repricing of completed offline facts.

---

# 42\. Stale price is not automatically an override

If the workstation sold merchandise at its legitimately resolved cached reference price:

```
reference = cached $16
selling   = cached $16
```

while central master data had already become `$17`, the transaction does **not** retroactively become a cashier price override.

The cashier did not override the workstation's resolved reference price.

Instead:

```
price override = no
reference staleness = yes
```

These are separate facts.

This distinction is important for loss-prevention reporting.

---

# 43\. Server synchronization

The completed-sale payload should preserve the pricing facts required by the server to understand what happened.

The server should not need to re-run today's price resolver to determine what the customer was charged.

Conceptually, the synchronized line includes or references:

* reference price used;  
* selling price used;  
* price-source snapshot/version;  
* override facts where applicable.

The exact payload belongs to the Completed Sale Operation contract.

---

# 44\. Linked returns

A linked return uses the original completed line's **historical selling price**, not:

* today's regular price;  
* today's inventory-unit price;  
* the original reference price when that differed due to override.

For example:

```
Original reference: $16
Original selling:   $15

Linked return price basis:
$15
```

The consolidated return model explicitly requires linked returns to reverse the actual historical selling price rather than current/reference pricing.

Discount and tax reversal occur separately according to their owning specifications.

---

# 45\. Partial linked returns

For a multi-quantity original line, a linked partial return begins from the original unit selling price.

Example:

```
Original:
Qty 3
Selling unit price $15
```

Return one:

```
historical selling basis = 1 × $15
```

Historical discount allocation and tax may make the final refund basis differ, but those calculations are not owned by Pricing.

---

# 46\. Unlinked returns

An unlinked return cannot automatically establish an authoritative original selling price because no original sale line exists.

Therefore, refund-basis determination for unlinked returns is not ordinary price resolution.

It is an exception-policy decision owned by Returns.

ShelfSense must not simply use current regular price and pretend that represents proven historical selling price.

---

# 47\. Receipts

The customer receipt should show the actual selling price charged.

It does not ordinarily expose:

* reference price;  
* internal override variance;  
* approval metadata.

For example:

```
Reference price: $16
Selling price:   $15
```

customer receipt:

```
Item              $15.00
```

not:

```
Item              $16.00
Manager override  -$1.00
```

unless a future receipt policy deliberately changes this behavior.

The existing receipt contract treats override variance as internal rather than customer-facing.

---

# 48\. Discounts on receipts

Customer-meaningful discounts may appear separately on receipts according to Receipt policy.

This reinforces the domain distinction:

```
price override
    → actual displayed selling price

discount
    → customer-visible adjustment where policy dictates
```

Internal reference-price variance does not masquerade as a discount.

---

# 49\. Reporting

Pricing should support reporting by dimensions such as:

* store;  
* workstation;  
* business date;  
* cashier;  
* approver;  
* department;  
* product;  
* variant;  
* inventory unit;  
* price source;  
* override reason.

Metrics should include, where useful:

```
reference sales value
actual selling value
override variance amount
override variance percentage
override count
```

The consolidated architecture explicitly calls for reporting override variance by cashier, approver, store, workstation, business date, department, merchandise, reason, dollar variance, and percentage variance.

---

# 50\. Override percentage variance

For authorization/reporting purposes, ShelfSense may need to calculate percentage variance.

The exact formula and zero-reference behavior should be specified in the pricing/approval calculation contract before implementation.

For example, a naïve form might be based on:

```
(reference - selling) / reference
```

but this specification does **not** lock the arithmetic until edge cases such as zero reference price and upward override are explicitly settled.

---

# 51\. Price-source hierarchy expansion

The initial resolver is intentionally small.

Future pricing capabilities may introduce additional sources such as:

* store-specific price;  
* effective-dated sale price;  
* customer/member price;  
* contractual/institutional price;  
* other explicit price books.

Adding such sources requires a deliberate update to:

1. source precedence;  
2. eligibility;  
3. offline replication;  
4. source/version snapshots;  
5. calculation fixtures;  
6. suspended-transaction refresh rules;  
7. reporting.

They must not be introduced as one-off conditionals scattered across the POS application.

---

# 52\. Promotions should not pollute price-source precedence

Future promotions should normally remain part of the Discounts domain.

For example:

```
Variant regular price      $20
Promotion: 20% off
```

should normally remain:

```
reference price            $20
selling price              $20
promotion discount          $4
net                        $16
```

rather than:

```
reference price            $16
```

This preserves the original price and promotion impact separately.

---

# 53\. Customer/member pricing is a future decision

The current design anticipates customer/member programs but does not yet determine whether a future member benefit is:

* a true price-source tier; or  
* a discount applied to ordinary selling price.

The consolidated design presently leans toward customer/member/employee benefits producing ordinary discount adjustments rather than dedicated special price columns.

That distinction should be explicitly revisited when the customer/pricing feature is designed.

---

# 54\. Price administration versus POS pricing

This specification describes **runtime POS price behavior**.

It does not define how administrators:

* create a variant regular price;  
* edit prices;  
* approve inventory-unit prices;  
* import prices;  
* schedule future prices.

Those belong to merchandise/pricing administration specifications.

POS consumes the authoritative configuration through reference replication.

---

# 55\. Conceptual price-resolution result

Without locking an implementation API, the resolver conceptually returns:

```
PriceResolution
├── reference_unit_price_cents
├── price_source
├── source_identity
├── source_version/context
└── resolved_at/context as required
```

A working merchandise line then starts with:

```
selling_unit_price_cents
=
reference_unit_price_cents
```

unless an authorized override changes it.

---

# 56\. Conceptual override fact

Without locking schema:

```
Price Override
├── transaction_line
├── reference_unit_price
├── requested/approved selling_unit_price
├── reason
├── performed_by
├── performed_at
├── approved_by          # nullable where direct action allowed
├── approved_at          # nullable
└── policy/config version
```

Whether overrides are stored as line columns, adjustment records, activity records, or a combination belongs to schema planning.

The domain behavior is authoritative; the physical representation is not yet locked.

---

# 57\. Domain ownership

## Pricing owns

* reference unit price;  
* selling unit price;  
* price resolution;  
* price-source precedence;  
* source/version snapshot requirements;  
* price override semantics;  
* price override variance;  
* historical price immutability;  
* offline stale-price semantics;  
* return historical selling-price basis.

## Transaction Lines owns

* line type;  
* quantity;  
* merchandise/unit identity;  
* line splitting/consolidation;  
* line snapshot container.

## Discounts owns

* discount scope;  
* discount methods;  
* promotion-produced discounts;  
* sequencing after selling price;  
* transaction allocation.

## Tax owns

* taxable basis;  
* rates/treatment;  
* tax calculation.

## Approvals owns

* direct/approval-required/prohibited policy;  
* threshold logic;  
* second actor;  
* approval invalidation.

## Returns owns

* return eligibility;  
* linked/unlinked behavior;  
* quantity returnability;  
* refund basis for unlinked returns.

## Reference Replication owns

* transfer of pricing reference data to the workstation;  
* reference version/cursor mechanics.

## Reconciliation owns

* classification/resolution of stale-price conflicts after synchronization.

---

# 58\. Delivery by phase

## Phase 4 — Price contract foundation

Implement/define:

* `reference_unit_price`;  
* `selling_unit_price`;  
* quantity-tracked variant regular-price resolution;  
* price-source metadata/versioning;  
* deterministic Rails/.NET resolver fixtures;  
* completed pricing snapshots;  
* stale-price preservation semantics.

If the individual-unit shape is included in the operation contract, define its price-source representation even if its cashier workflow is deferred.

---

## Phase 5 — Regular-price sale

Implement:

```
quantity-tracked Standard variant
    ↓
variant regular price
    ↓
reference = selling
```

No:

* override;  
* discount;  
* promotion;  
* open-ring pricing.

---

## Phase 5.1 / 6.1 — Individually tracked pricing

Implement:

```
exact-unit price
    ↓ fallback
variant regular price
```

along with exact-unit scan/sale behavior.

---

## Phase 6.1 — Price overrides

Implement:

* override entry;  
* reasons;  
* permissions;  
* approval thresholds;  
* second-actor approval;  
* change/remove;  
* line splitting where necessary;  
* activity history;  
* reporting.

---

## Phase 6.3 — Discounts/promotions

Consume the established selling-price output and add discount behavior without redefining pricing history.

---

# 59\. Deferred capabilities

This specification intentionally leaves room for, but does not currently define:

* store-specific price books;  
* scheduled/effective-dated sale prices;  
* quantity-break pricing;  
* customer-specific price levels;  
* membership pricing tiers;  
* employee pricing;  
* promotional reference-price replacement;  
* multi-currency POS pricing;  
* dynamic market pricing;  
* MSRP/list-price fallback;  
* automatic competitive pricing.

Any such feature requires an explicit resolver/source decision rather than merely adding another nullable price field.

---

# 60\. Pending decisions

## 60.1 Final individually tracked fallback hierarchy

Confirm:

```
unit approved price
→ variant regular price
→ failure
```

or define any additional explicit fallback.

Required before individually tracked POS implementation.

---

## 60.2 Exact meaning of unit “approved selling price”

Define which inventory-unit field/state qualifies as an approved price and whether pricing approval is separate from ordinary inventory-unit editing.

---

## 60.3 Effective dating

Determine whether initial regular pricing requires effective-dated records or whether Phase 4/5 uses current reference configuration plus snapshot/version history.

---

## 60.4 Override direction

Confirm whether policy may permit:

* downward only;  
* upward and downward.

The model supports either.

---

## 60.5 Override thresholds

Define the concrete cents/percentage threshold representation and initial organization/store policies.

Owned jointly with Approvals before Phase 6.1.

---

## 60.6 Override reason policy

Define reason catalog and whether reasons are universally required or policy-controlled.

---

## 60.7 Override percentage formula

Lock:

* sign convention;  
* denominator;  
* zero-reference behavior;  
* rounding.

Required before threshold implementation/reporting.

---

## 60.8 Suspended price refresh

Define exactly when reference prices refresh on recall and how existing override/approval state is handled.

---

## 60.9 Future price-source hierarchy

No source beyond the initial variant/unit rules should be added without defining formal precedence.

---

# 61\. Core invariants summary

The following rules are authoritative unless explicitly superseded:

1. **Reference price and selling price are distinct concepts.**  
2. **Reference price is the price resolved by ShelfSense before override.**  
3. **Selling price is the actual unit price used before discounts.**  
4. **Without override, selling price equals reference price.**  
5. **A price override changes selling price, not reference price.**  
6. **A discount does not change selling price.**  
7. **A promotion normally produces discounts rather than redefining reference price.**  
8. **Quantity-tracked Phase 5 merchandise resolves from variant regular price.**  
9. **Individually tracked merchandise prefers its exact-unit approved price when present, with an explicitly defined fallback.**  
10. **Open-ring entered price is a selling price, not an override.**  
11. **Open rings have no merchandise reference price.**  
12. **Known non-inventory merchandise still uses merchandise pricing.**  
13. **Different selling prices require separate quantity lines.**  
14. **Price override does not update merchandise master data.**  
15. **Override reason/actor/approval facts are preserved where applicable.**  
16. **Completed reference and selling prices are immutable.**  
17. **Current central price changes never reprice a completed transaction.**  
18. **A stale cached reference price is not retroactively classified as a cashier override.**  
19. **Linked returns use the original historical selling price.**  
20. **Customer receipts normally present selling price rather than internal reference-price variance.**  
21. **Price-source identity/version must be sufficiently preserved to explain completed history.**  
22. **Future pricing sources require explicit precedence and replication contracts.**

---

# 62\. Acceptance examples

## Example A — normal quantity-tracked sale

Given:

```
Variant regular price = $16.00
```

when the line is resolved,

then:

```
reference_unit_price = $16.00
selling_unit_price   = $16.00
price_source         = variant regular
override             = none
```

---

## Example B — missing regular price

Given a Phase 5 quantity-tracked variant with no valid regular price,

when the cashier attempts to sell it,

then:

* price resolution fails;  
* ShelfSense does not assume zero;  
* ShelfSense does not silently use product list price;  
* ShelfSense does not create an open ring automatically;  
* normal completion is blocked until valid pricing is available.

---

## Example C — price override

Given:

```
Reference = $16
```

when an authorized cashier overrides the item to `$15`,

then:

```
reference = $16
selling   = $15
```

and:

* override reason/actor are retained as required;  
* downstream calculations use `$15`;  
* customer receipt uses `$15`;  
* reporting can identify `$1` reference-price variance.

---

## Example D — one unit differs within a quantity line

Given three copies of the same variant and only one is sold at `$15` instead of `$16`,

then ShelfSense represents:

```
Line A
Qty 2
Reference $16
Selling   $16

Line B
Qty 1
Reference $16
Selling   $15
Override
```

rather than a single quantity-three line.

---

## Example E — discount after override

Given:

```
Reference price = $20
Override price  = $18
Line discount   = $2
```

then ShelfSense preserves:

```
Reference       $20
Selling         $18
Discount         $2
Net             $16
```

The override and discount do not collapse into one `$4` adjustment.

---

## Example F — individually tracked price

Given:

```
Variant regular price = $10
Unit A approved price = $7
```

when Unit A is sold,

then:

```
reference price = $7
price source    = exact inventory unit
```

not `$10`.

---

## Example G — individually tracked fallback

Given:

```
Variant regular price = $10
Unit A has no unit-specific approved price
```

when the configured initial fallback applies,

then:

```
reference price = $10
price source    = variant regular fallback
```

subject to finalization of the unit fallback contract.

---

## Example H — open ring

Given a cashier creates an open ring for `$12`,

then:

```
reference merchandise price = absent
selling price               = $12
price override              = false
```

---

## Example I — stale offline price

Given:

```
Workstation cache = $16
Central current   = $17
```

while the workstation is offline,

when the cashier sells the item at its locally resolved `$16` and completes,

then on synchronization:

* historical reference price remains `$16`;  
* historical selling price remains `$16`;  
* the transaction is not centrally repriced;  
* it is not retroactively considered a cashier override;  
* stale pricing is classified separately according to reconciliation policy.

---

## Example J — historical return after price change

Given an item originally completed with:

```
Reference = $16
Selling   = $15
```

and current regular price later becomes `$18`,

when the original line is returned,

then the historical selling-price basis is:

```
$15
```

not `$16` and not `$18`.

---

## Example K — completed history after master-data change

Given a completed line:

```
reference = $16
selling   = $16
```

when an administrator later changes the variant regular price to `$17`,

then:

* future resolution may use `$17`;  
* the completed line remains `$16`;  
* reprinted receipts remain based on `$16`.

---

# 63\. Related workflows

This specification should be referenced by:

* `workflows/sales/cash-sale.md`  
* `workflows/sales/add-merchandise.md`  
* `workflows/sales/individual-unit-sale.md`  
* `workflows/sales/open-ring.md`  
* `workflows/adjustments/price-override.md`  
* `workflows/sales/suspend-recall.md`  
* `workflows/returns/linked-return.md`  
* `workflows/returns/exchange.md`

---

# 64\. Related contracts

Pricing should eventually have explicit machine contracts for:

* price-resolution inputs/outputs;  
* quantity-tracked regular-price fixtures;  
* individually tracked source/fallback fixtures;  
* override variance arithmetic;  
* completed-sale pricing payload;  
* reference-data pricing projection;  
* stale-price synchronization cases.

The domain specification defines **what ShelfSense prices mean**.

The contract specifications define **the exact data and arithmetic Rails and .NET must use to preserve those meanings**.
