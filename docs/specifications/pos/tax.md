# POS Domain Specification: Tax

**Design status:** Core calculation and historical treatment decided; customer-specific exemptions and advanced jurisdictional features remain deferred
**Implementation status:** Foundation required in Phase 4; first operational delivery in Phase 5
**Initial contract foundation:** Phase 4 — POS Runtime and Contract Foundation
**First operational delivery:** Phase 5 — First Operational Cash Sale
**Expanded delivery:** Later POS/customer/reporting phases
**Related specifications:** Transactions, Transaction Lines, Pricing, Discounts, Returns, Receipts, Reference Replication, Operation Synchronization, Reconciliation
**Related workflows:** Cash Sale, Complete Transaction, Linked Return, Partial Return, Exchange

---

## 1. Purpose

This specification defines the ShelfSense POS tax domain.

It establishes:

* how merchandise tax classification relates to store tax configuration;
* how tax components and tax classes differ;
* how ShelfSense determines which tax rules apply;
* taxable, exempt, and zero-rated treatment;
* the distinction between explicit zero-tax treatment and non-applicability;
* taxable-basis calculation;
* multiple independent tax components;
* rounding and arithmetic requirements;
* effective-date behavior;
* completed tax snapshots;
* offline/stale tax behavior;
* historical return reversal;
* partial-return tax allocation;
* reporting requirements.

This specification does **not** define:

* merchandise pricing;
* discount calculation;
* customer-specific exemption workflows;
* jurisdictional filing rules;
* tax remittance;
* tax-accounting journal generation;
* tax-inclusive pricing;
* compounded taxes;
* cashier tax overrides;
* arbitrary tax-rule expression languages.

Those capabilities belong to other specifications or future extensions.

---

# 2. Governing principle

ShelfSense calculates tax from the actual financial facts of each sale line.

The governing sequence is:

```text
reference price
    ↓
optional price override
    ↓
selling price
    ↓
line discounts
    ↓
transaction-discount allocation
    ↓
net line tax basis
    ↓
applicable store tax components
    ↓
component tax amounts
```

Tax is therefore calculated **after pricing and discounts**.

Tax is not calculated from:

* reference price;
* undiscounted selling price;
* current master pricing during later synchronization.

---

# 3. Line-level tax model

Tax is calculated primarily at the transaction-line level.

For each active sale line:

```text
line
  ↓
net taxable basis
  ↓
applicable tax components
  ↓
line tax-component results
```

Transaction tax is then:

```text
transaction tax
=
sum of completed line tax-component amounts
```

This is authoritative for the initial POS model.

ShelfSense does not initially calculate one undifferentiated transaction-level sales-tax amount and then attempt to infer line allocation afterward.

---

# 4. Why tax is line-level

Line-level tax calculation supports:

* mixed taxable and non-taxable merchandise;
* multiple tax classes;
* multiple tax components;
* department/product reporting;
* deterministic offline calculation;
* linked returns;
* partial returns;
* exact historical reproduction;
* Rails/.NET calculation parity.

A completed line therefore carries enough tax detail to explain its own contribution to transaction tax.

---

# 5. Core tax concepts

ShelfSense distinguishes at least:

```text
Tax Class
Tax Component
Tax Rule
Completed Tax Component
```

These concepts serve different purposes.

---

# 6. Tax class

A **tax class** classifies merchandise for tax purposes.

Examples might include:

```text
physical_book
physical_clothing
physical_newspaper

food_beverage_bakery
food_beverage_grocery
food_beverage_bottled_soft_drink
```

A tax class does not itself contain a universal tax percentage.

Instead it answers:

> What kind of merchandise is this for tax-rule purposes?

---

# 7. Tax component

A **tax component** represents a separately identifiable tax imposed within a store's jurisdiction.

Examples:

```text
State Sales Tax
Food/Beverage Tax
Local Sales Tax
```

Each component may have:

* name;
* code;
* rate;
* effective period;
* reporting identity;
* rules describing which tax classes receive which treatment.

Separate components remain separately calculated and separately preserved in completed transaction history.

---

# 8. Tax rule

A tax rule connects:

```text
store
+
tax class
+
tax component
+
effective period
```

to the applicable treatment/rate behavior.

Conceptually:

```text
Store A
Physical Book
State Sales Tax
Effective Jan 1
→ taxable at 6%
```

while:

```text
Store A
Physical Newspaper
State Sales Tax
Effective Jan 1
→ exempt
```

Tax rules are store-specific because stores may operate in different tax jurisdictions.

---

# 9. Store-specific authority

The tax class alone does not determine the tax charged.

Tax resolution uses:

```text
store
+
line tax class
+
transaction occurred_at
```

to determine the applicable effective tax rules.

The same merchandise tax class may therefore produce different tax results at different stores.

---

# 10. Tax-effective time

Tax configuration is resolved according to the transaction's actual occurrence time.

ShelfSense distinguishes:

```text
occurred_at
```

from:

```text
business_date
```

`business_date` is a reporting classification.

`occurred_at` determines which tax configuration was legally/effectively in force.

Example:

```text
Business date policy closes at 2:00 AM.

Transaction completed:
January 1, 1:00 AM

business_date:
December 31
```

If a tax rate became effective at midnight January 1, the January 1 tax configuration applies even though the transaction is reported under the December 31 business date.

Therefore:

> **Tax-effective configuration is determined from `occurred_at`, not `business_date`.**

---

# 11. Effective-period boundaries

Tax-rule effective periods should use unambiguous half-open boundaries:

```text
[effective_from, effective_until)
```

Meaning:

```text
effective_from   inclusive
effective_until  exclusive
```

This avoids overlapping behavior at rule boundaries.

The physical representation may use dates or timestamps according to the governing tax rule, but resolution must remain deterministic.

---

# 12. Tax treatment

For a tax component and tax class, ShelfSense distinguishes:

```text
taxable
exempt
zero_rated
```

These treatments are economically and reportably different.

---

# 13. Taxable

`taxable` means the tax component applies to the line's applicable tax basis at the configured rate.

Example:

```text
basis = $100.00
rate  = 6.00%

tax = $6.00
```

The line contributes:

* taxable basis;
* tax amount.

---

# 14. Exempt

`exempt` means the merchandise or transaction circumstance is explicitly exempt from the tax component.

Example:

```text
basis     = $100.00
treatment = exempt
tax       = $0.00
```

The exempt amount should remain distinguishable for reporting.

It must not be classified as zero-rated merely because both produce zero tax.

---

# 15. Zero-rated

`zero_rated` means the transaction remains within the scope of the tax but has an applicable tax rate of zero.

Example:

```text
basis     = $100.00
treatment = zero_rated
rate      = 0%
tax       = $0.00
```

Zero-rated basis remains separately reportable from exempt basis.

---

# 16. Non-applicability

ShelfSense conceptually distinguishes:

```text
exempt
```

from:

```text
this tax component is not applicable to this tax class
```

For example, a special food tax may simply have no relevance to books.

Non-applicability does not necessarily require a stored `not_applicable` tax-rule value.

It may instead be represented by no applicable rule for that component/class combination.

The important domain distinction is:

> **No applicable tax rule is not the same thing as an explicit exempt or zero-rated tax decision.**

---

# 17. Completed zero-tax facts

When a component is explicitly:

```text
exempt
```

or:

```text
zero_rated
```

the completed transaction should retain the tax-component result even though:

```text
tax_cents = 0
```

This preserves:

* why tax was zero;
* taxable/exempt/zero-rated reporting;
* historical return behavior;
* configuration/version history.

A genuinely non-applicable component need not produce a completed component result.

---

# 18. Initial tax-exclusive pricing model

ShelfSense initially supports tax-exclusive selling prices.

Example:

```text
Net merchandise: $10.00
Tax:              $0.60
Total due:       $10.60
```

Tax is added to the net merchandise amount.

The initial model does not support deriving embedded tax from a tax-inclusive selling price.

Tax-inclusive pricing must be introduced later as an explicit capability if required.

---

# 19. Tax basis

For an ordinary sale line:

```text
tax basis
=
selling amount
-
line discounts
-
transaction-discount allocation
```

where those adjustments are applicable to that line.

Conceptually:

```text
Selling amount              $20.00
Line discount                -2.00
Transaction allocation       -1.00
                            -------
Net tax basis               $17.00
```

Tax calculations then consume the `$17.00` basis.

---

# 20. Reference-price variance does not affect tax independently

A price override is already reflected in the selling price.

Example:

```text
Reference price $20
Selling price   $18
Discount         $2

Tax basis       $16
```

Tax does not independently tax the `$2` reference-price variance.

It operates on the actual financial selling basis after discounts.

---

# 21. Discount relationship

Discounts reduce the applicable tax basis before tax calculation.

For example:

```text
Selling price:  $100
Discount:        $10

Tax basis:       $90
```

assuming ordinary discount treatment under the applicable jurisdiction.

Advanced jurisdictional rules where particular discounts affect taxable basis differently are not supported in the initial model and would require explicit extension.

---

# 22. Multiple tax components

A line may have multiple applicable tax components.

Example:

```text
State Sales Tax
Food/Beverage Tax
```

Each component produces its own completed tax result.

Conceptually:

```text
Line tax basis
    ├── State Tax
    │     → component amount
    │
    └── Food Tax
          → component amount
```

Transaction tax is the sum of those component amounts.

---

# 23. Non-compounded components

The initial tax model supports independent, non-compounded tax components.

Example:

```text
Tax basis: $100

State tax:
6.00% × $100 = $6.00

Food tax:
1.25% × $100 = $1.25
```

Total tax:

```text
$7.25
```

ShelfSense does **not** initially support:

```text
Food tax
=
1.25% × ($100 + $6 state tax)
```

Compounded tax requires an explicit future model.

---

# 24. Same-basis rule

For the initial non-compounded model, each applicable taxable component uses the same applicable net line tax basis unless its own explicit rule dictates no application.

Example:

```text
Line net basis = $10

State Tax applies:
basis = $10

Food Tax applies:
basis = $10
```

Components do not alter the basis of subsequent components.

---

# 25. Tax calculation unit

The atomic financial calculation unit is:

> **one transaction line × one tax component**

Conceptually:

```text
TaxCalculation
(
  line_tax_basis,
  treatment,
  rate
)
→
component tax cents
```

ShelfSense rounds at this level.

---

# 26. Rounding rule

Each taxable line/component calculation is independently rounded to cents.

Then completed component cents are summed.

Conceptually:

```text
Line A / State Tax
  → round

Line A / Food Tax
  → round

Line B / State Tax
  → round

Transaction tax
  = sum rounded components
```

ShelfSense does not calculate one aggregate transaction tax first and then distribute cents to lines afterward.

---

# 27. Rounding mode

The initial rounding rule is:

> **Round exact decimal tax results to the nearest cent using decimal half-up rounding.**

Examples:

```text
raw = 1.234
→ 1.23
```

```text
raw = 1.235
→ 1.24
```

This rule must be represented in shared Rails/.NET calculation fixtures.

If a future jurisdiction requires another rounding policy, that policy must be explicitly modeled rather than inferred.

---

# 28. No binary floating-point arithmetic

Tax calculations must not depend on binary floating-point arithmetic.

Prohibited conceptual implementation:

```text
double rate = 0.06
```

where cross-runtime floating-point behavior determines authoritative cents.

Tax calculations must use exact/controlled decimal or scaled-integer arithmetic according to the Tax calculation contract.

The exact machine representation may be:

* scaled integer rate;
* decimal representation;
* other explicitly versioned exact format.

But:

> **Binary floating point is not authoritative financial arithmetic.**

---

# 29. Tax-rate precision

Tax rates may require more precision than whole percentages or basis points.

Therefore the underlying rate representation must not assume:

```text
6.00%
```

is the maximum required precision.

The contract should select sufficient deterministic precision for supported jurisdictions.

The domain spec does not lock the scale, only the requirement that it be exact and portable.

---

# 30. Line tax total

For a completed line:

```text
line_tax_total_cents
=
Σ line tax-component cents
```

This may be stored as a projection/convenience value, but component facts remain authoritative for explaining the total.

---

# 31. Transaction tax total

For a completed transaction:

```text
transaction_tax_total_cents
=
Σ active completed line tax-component cents
```

or equivalently:

```text
=
Σ line_tax_total_cents
```

Transaction-level tax must reconcile exactly to completed line/component facts.

---

# 32. Completed tax snapshot

Completion freezes the tax facts actually used.

For each applicable completed line/component, ShelfSense should preserve enough information to reconstruct:

```text
tax component identity
component/name snapshot
tax treatment
rate used
basis cents
tax cents
tax class context
tax rule/source
effective configuration/version
```

The exact physical schema remains an implementation decision.

---

# 33. Why component snapshots are required

ShelfSense must be able to explain a historical transaction after:

* tax rate changes;
* tax rule changes;
* component renaming;
* merchandise reclassification;
* store configuration changes.

A completed receipt or tax report must not depend on running today's tax configuration against an old transaction.

---

# 34. Current master data does not rewrite tax history

Once a transaction completes:

* tax class snapshot does not change;
* treatment does not change;
* rate does not change;
* basis does not change;
* tax cents do not change.

Changing a central tax rule later affects future resolution only.

---

# 35. Merchandise tax-class resolution

A known merchandise line obtains its tax classification from the relevant merchandise configuration.

Conceptually:

```text
product variant / merchandise classification
        ↓
tax class
```

The completed transaction freezes the relevant tax-class context.

The precise merchandise-level ownership of `tax_class_id` belongs to the merchandise specification/schema.

---

# 36. Open-ring tax classification

An open ring has no product variant.

Therefore its tax classification must be resolved from explicit open-ring context, initially through the selected department/default tax configuration.

Conceptually:

```text
open-ring department
        ↓
resolved tax class
        ↓
normal store tax calculation
```

Open rings do not use a separate tax engine.

---

# 37. Invalid tax configuration

If an ordinary sale line cannot resolve required tax treatment, ShelfSense should fail safely.

Examples:

* required tax class absent;
* overlapping effective tax rules;
* ambiguous applicable rule;
* malformed rate;
* unsupported compounded configuration.

The initial POS should not invent tax behavior.

Completion must be blocked where the application cannot deterministically establish the required tax result.

---

# 38. No generic cashier tax override in the initial model

Phase 5 does not provide a generic cashier control to change:

```text
tax class
```

or:

```text
tax treatment
```

or:

```text
tax rate
```

just to make a transaction proceed.

Incorrect tax configuration should be corrected through administrative master data.

If manual tax exceptions are later required, they must be modeled explicitly as controlled actions with:

* permission;
* reason;
* approval where required;
* historical snapshots.

---

# 39. Customer-specific tax exemption

Customer-specific tax exemptions are deferred from the initial POS model.

Phase 4/5 calculation is based on:

```text
store
+
line tax class
+
occurred_at
```

without customer exemption modification.

A future model may introduce:

```text
customer exemption context
```

as an additional treatment input.

---

# 40. Future exemption evidence

The completed tax-component model should be extensible enough to later preserve:

```text
normally applicable treatment
actual treatment = exempt
exemption source/reference
customer/exemption evidence
```

without redesigning the completed transaction model.

This future capability is not implemented in Phase 5.

---

# 41. Working transaction recalculation

While a transaction remains open, tax is provisional.

Tax must be recalculated when tax-relevant inputs change.

Examples include:

* quantity change;
* selling-price change;
* price override;
* line discount;
* transaction-discount allocation;
* merchandise selection;
* open-ring tax classification;
* deliberate reference refresh.

Only tax values frozen at completion are historical facts.

---

# 42. Suspended transaction tax

A suspended transaction remains mutable work.

It does not permanently freeze tax configuration merely because it was suspended.

On recall, tax may need re-resolution according to the future suspend/recall refresh policy.

The exact refresh behavior remains governed by the Transactions workflow/specification.

Completed historical transactions are never re-resolved.

---

# 43. Transaction completion validation

Before transaction completion, ShelfSense must validate:

* every active financial line has resolvable tax classification;
* all applicable tax components were resolved;
* tax arithmetic conforms to the deterministic contract;
* component totals reconcile to line tax totals;
* line totals reconcile to transaction tax total;
* applicable configuration/version context is available for snapshotting.

A tax-validation failure blocks completion.

---

# 44. Offline tax calculation

Ordinary supported sales must be tax-calculable locally.

The POS workstation therefore caches enough reference data to determine:

* relevant tax classes;
* store tax components;
* effective tax rules;
* rates;
* treatments;
* version/effective context.

Network access is not required merely to calculate an ordinary supported offline sale.

---

# 45. Cached tax authority

The workstation calculates from the tax configuration it has legitimately received through reference replication.

Conceptually:

```text
central tax reference state
        ↓
POS reference projection
        ↓
local deterministic calculation
```

The workstation must preserve which reference/configuration context it used.

---

# 46. Stale offline tax

A workstation may legitimately complete a sale using tax configuration that has become stale centrally while it was offline.

Example:

```text
POS cached rate:     6%
Central current rate: 7%
POS offline
```

If the workstation correctly calculates the sale at 6% using its available authoritative cache:

> **The completed transaction remains a 6% historical transaction.**

Central synchronization must not silently retax it at 7%.

---

# 47. Stale tax is a reconciliation issue

A stale tax rule may produce a synchronization result such as:

```text
accepted
accepted_with_warning
quarantined
```

depending on reconciliation policy.

The originating completed facts remain preserved.

The exact central treatment belongs to Reconciliation.

---

# 48. Arithmetic validation versus current-rule validation

The server should distinguish two questions.

## Question 1

> Was this transaction calculated correctly according to the tax facts it claims to have used?

Example:

```text
basis $100
snapshotted rate 6%
reported tax $6
```

This is deterministic arithmetic validation.

## Question 2

> Was 6% still the current central tax rate at server receipt time?

That is a reconciliation/reference-freshness question.

These must not be conflated.

---

# 49. Server must not retax historical operations from current configuration

Incorrect:

```text
receive completed transaction
→ fetch today's tax rules
→ calculate what sale "should" have been
→ overwrite terminal tax
```

Correct:

```text
receive completed transaction
→ validate payload/calculation integrity
→ compare reference versions/current central knowledge
→ preserve originating tax facts
→ classify any stale/conflict condition
```

This follows the ShelfSense offline authority model.

---

# 50. Return tax principle

A linked return reverses the original completed historical tax.

It does not calculate new tax from current rules.

Conceptually:

```text
original completed line
        ↓
historical tax components
        ↓
return reversal
```

The returned merchandise therefore inherits its tax-reversal basis from the original sale history.

---

# 51. Full linked return

Suppose the original completed line contains:

```text
State tax:
basis = $16.00
rate  = 6%
tax   = $0.96

Food tax:
basis = $16.00
rate  = 1.25%
tax   = $0.20
```

A full linked return reverses:

```text
State tax = $0.96
Food tax  = $0.20
```

as historical economic reversals.

It does not matter if current rates are different.

---

# 52. Return tax-component identity

A linked return should retain the relationship to the original tax components being reversed.

This supports:

* audit;
* tax reporting;
* exact reversal;
* partial-return accumulation.

The exact schema may use:

* original component references;
* reversal records;
* historical component snapshots.

---

# 53. Partial returns

Partial returns consume historical tax cents deterministically.

Suppose:

```text
Original quantity = 3
Historical State Tax = $1.00
```

A return of one unit cannot simply store an infinitely precise one-third amount.

ShelfSense needs a deterministic cent-consumption rule.

---

# 54. Partial-return tax invariants

For any original tax component:

```text
Σ tax reversed across partial returns
<=
original tax cents
```

When all originally sold quantity has been returned:

```text
Σ tax reversed
=
original tax cents
```

exactly.

No cent may be:

* lost;
* duplicated;
* recalculated from current tax rates.

---

# 55. Partial-return allocation strategy

The exact method for assigning historical tax cents across partial returns belongs to the shared calculation contract.

It must be:

* deterministic;
* stable;
* portable across Rails and .NET;
* independent of current tax configuration.

The same principle applies to historical discount cents.

---

# 56. Return of individually tracked merchandise

Individually tracked merchandise always represents one exact unit.

Therefore a linked full return of that unit reverses the exact historical tax-component amounts associated with its original line.

No quantity-based allocation is needed where the original individually tracked line quantity is exactly one.

---

# 57. Unlinked returns

An unlinked return lacks an authoritative original sale line.

Therefore ShelfSense cannot simply claim to be reversing a known historical tax fact.

The tax treatment for unlinked returns is an exception policy owned jointly by Returns and Tax.

It must be defined explicitly before Phase 6.4.

ShelfSense should not silently pretend current tax calculation is equivalent to historical reversal.

---

# 58. Exchanges

An exchange transaction contains:

```text
return-direction line(s)
+
sale-direction line(s)
```

Tax behavior follows each line independently.

Return lines:

```text
reverse historical tax
```

New sale lines:

```text
calculate tax using current applicable rules
```

This allows an exchange to legitimately involve different historical/current rates.

---

# 59. Tax and line direction

New tax calculation applies to:

```text
direction = sale
```

lines.

Return-direction lines ordinarily use historical reversal.

The line's positive quantity remains separate from economic direction.

---

# 60. Non-inventory merchandise

Known non-inventory merchandise still participates in ordinary tax calculation.

Inventory behavior and taxability are separate dimensions.

A line can therefore be:

```text
known merchandise
non-inventory
taxable
```

without being an open ring.

---

# 61. Zero-net lines

A legitimate discount may reduce a sale line's net tax basis to zero.

Example:

```text
Selling amount = $5
Discount       = $5
Tax basis      = $0
```

Taxable components calculate:

```text
tax = $0
```

The line is still a completed sale line rather than a void.

---

# 62. Negative tax basis prohibited for ordinary sale lines

Discounts cannot produce a negative merchandise basis.

Therefore an ordinary sale-line tax basis must satisfy:

```text
tax_basis_cents >= 0
```

Return economic sign is represented by line direction/historical reversal, not a negative sale-line tax basis.

---

# 63. Tax component order

For non-compounded taxes, component order does not change the financial result.

However, ShelfSense should still preserve a stable component order for:

* deterministic serialization;
* receipts;
* reporting;
* calculation fixtures.

The exact stable ordering should be defined in the calculation/serialization contract.

---

# 64. Tax component identity

Tax components should have stable machine identity independent of display name.

Example conceptual distinction:

```text
code = state_sales_tax
display_name = State Sales Tax
```

Changing the display name later must not alter historical component identity.

Completed snapshots preserve the historical customer/reporting label where needed.

---

# 65. Tax-class identity

Likewise, tax classes should have stable machine identity independent of display labels.

Historical completed transactions preserve sufficient tax-class context even if the class is later renamed or superseded.

---

# 66. Tax rule version/context

The completed transaction must preserve enough information to answer:

> Which effective tax configuration produced this result?

Possible concepts include:

```text
tax_rule_id
tax_rule_version
reference_snapshot_version
effective_from
```

Exact persistence remains contract/schema design.

---

# 67. Tax reporting

Tax reporting should support component-level totals for at least:

```text
taxable basis
exempt basis
zero-rated basis
tax collected
```

by dimensions such as:

* store;
* business date;
* occurrence period;
* tax component;
* tax class;
* department;
* product/variant;
* transaction;
* line.

---

# 68. Business date versus legal/effective-date reporting

ShelfSense may report operational tax totals by `business_date`.

However, rule selection still uses `occurred_at`.

This means reporting and rule-effectiveness are intentionally separate concerns.

Tax reporting may eventually need both:

```text
business_date
```

and:

```text
legal/calendar occurrence date
```

depending on filing requirements.

---

# 69. Exempt reporting

Explicit exempt tax results should preserve exempt basis.

Example:

```text
Component: State Sales Tax
Treatment: exempt
Basis:     $25.00
Tax:        $0.00
```

This amount must not disappear simply because tax collected is zero.

---

# 70. Zero-rated reporting

Similarly:

```text
Component: State Sales Tax
Treatment: zero_rated
Basis:     $25.00
Rate:       0%
Tax:        $0.00
```

should remain separately reportable.

---

# 71. Non-applicable reporting

A component with no applicable rule need not necessarily create a line/component zero row.

ShelfSense reporting may infer non-applicability from configuration when needed, but completed financial history should not manufacture unnecessary tax decisions.

---

# 72. Receipt presentation

Receipts should present tax according to receipt policy.

At minimum they must be able to reproduce:

* total tax;
* component-level tax where required;
* applicable tax labels.

Receipts must use historical completed tax snapshots.

They must not recalculate from current tax configuration during reprint.

---

# 73. Receipt reprints

A receipt reprint must show the same completed tax amounts as the original receipt.

Example:

```text
Original sale:
State Tax $0.96
```

Even if the rate later changes, a reprint remains:

```text
State Tax $0.96
```

---

# 74. Tax audit/activity

Ordinary automatic tax calculations do not need a verbose event log for every component calculation.

The completed component facts themselves are the authoritative tax history.

Audit/activity becomes important for future exception actions such as:

* manual exemption;
* tax-class override;
* exemption-document change.

Those capabilities are deferred.

---

# 75. Reference replication

The POS workstation requires locally cached tax reference data sufficient for offline calculation.

The initial projection should include:

* active tax classes needed by POS;
* store tax components;
* rates;
* treatments/rules;
* effective periods;
* stable identities;
* reference version/cursor context.

Reference Replication owns transport and cache mechanics.

Tax owns the interpretation.

---

# 76. Reference application must be atomic

Tax reference updates should be applied transactionally with the broader reference snapshot/delta.

The POS must not temporarily observe inconsistent states such as:

```text
new tax component
+
old tax rule set
```

during reference application.

The exact replication mechanics belong to Reference Replication.

---

# 77. Unsupported tax configuration

The POS contract should explicitly reject or refuse to activate unsupported tax configurations such as:

* compounded tax;
* tax-inclusive pricing;
* ambiguous overlapping rules;
* unsupported rounding policies;
* unknown treatment types.

This is preferable to silently calculating them incorrectly.

---

# 78. Conceptual completed tax component

Without locking schema:

```text
Completed Line Tax Component
│
├── id
├── transaction_line
│
├── tax_component_id
├── component_code_snapshot
├── component_name_snapshot
│
├── tax_class/context
├── treatment
│   ├── taxable
│   ├── exempt
│   └── zero_rated
│
├── basis_cents
├── rate
├── tax_cents
│
├── tax_rule/reference identity
└── reference/config version
```

A return component may additionally reference the original completed component being reversed.

---

# 79. Conceptual tax rule model

Without locking physical schema:

```text
Tax Rule
│
├── store
├── tax_component
├── tax_class
├── treatment
├── rate          # meaningful for taxable/zero-rated as appropriate
├── effective_from
├── effective_until
└── version/audit context
```

The implementation may separate rates from treatment rules if appropriate.

The behavioral contract is more important than exact normalization at this stage.

---

# 80. Domain ownership

## Tax owns

* tax classes as POS tax inputs;
* tax components;
* treatment semantics;
* tax-rule resolution;
* effective-time semantics;
* tax basis consumption;
* component calculation;
* rounding;
* completed tax snapshots;
* stale-tax preservation;
* historical return tax reversal;
* tax reporting dimensions.

## Pricing owns

* reference price;
* selling price;
* price overrides.

## Discounts owns

* line discounts;
* transaction allocations;
* resulting reduction before tax.

## Transaction Lines owns

* line identity;
* direction;
* quantity;
* merchandise/open-ring classification context.

## Returns owns

* return eligibility;
* return quantity;
* linked/unlinked workflow.

## Reference Replication owns

* delivery of tax configuration to POS.

## Reconciliation owns

* central treatment of stale/conflicting tax reference state.

## Receipts owns

* customer-facing presentation.

---

# 81. Phase 4 foundation

Phase 4 should establish:

* tax data projection shape;
* deterministic tax calculation contract;
* exact rate representation;
* line/component calculation fixtures;
* half-up cent rounding fixtures;
* completed component payload shape;
* tax configuration versioning;
* stale-reference preservation semantics.

Representative fixtures should include at least:

```text
one taxable component
multiple non-compounded components
exempt component
zero-rated component
discounted taxable basis
rounding boundary cases
```

---

# 82. Phase 5 delivery

Phase 5 implements ordinary current sale tax for quantity-tracked Standard merchandise.

Required behavior:

```text
resolve line tax class
    ↓
resolve applicable store tax rules
    ↓
calculate post-discount tax basis
    ↓
calculate each component
    ↓
round each line/component
    ↓
freeze at completion
```

Phase 5 does not include:

* customer exemptions;
* manual tax overrides;
* compounded taxes;
* tax-inclusive prices;
* linked returns.

---

# 83. Phase 6.4 return integration

Return implementation adds:

* historical tax-component linkage;
* full component reversal;
* deterministic partial-return component cents;
* exchange behavior;
* explicit policy for unlinked returns.

The ordinary current-rate tax engine is not used to calculate linked-return reversal.

---

# 84. Future customer exemptions

A future customer exemption capability will need to define:

* exemption identity;
* applicable components;
* applicable tax classes;
* effective dates;
* evidence/certificate reference;
* expiration;
* transaction-level versus line-level scope;
* offline eligibility.

The resulting completed tax component should still use the same:

```text
treatment = exempt
```

historical model.

---

# 85. Deferred capabilities

This specification intentionally defers:

* tax-inclusive pricing;
* compounded taxes;
* customer exemptions;
* transaction-specific tax overrides;
* origin/destination sourcing rules;
* shipping/delivery taxation;
* tax holidays;
* threshold taxation;
* quantity/volume taxes;
* excise taxes;
* jurisdiction boundary/geolocation engines;
* external tax-service integration;
* filing/remittance workflows.

Any such feature must extend rather than bypass the completed component model.

---

# 86. Pending decisions

## 86.1 Exact tax-rate representation

Choose an exact cross-runtime representation, such as:

* scaled integer;
* canonical decimal.

Required before Phase 4 contract finalization.

---

## 86.2 Rate precision

Define sufficient supported precision for tax rates.

Do not assume two decimal places of percentage precision without verifying the intended supported jurisdictions.

---

## 86.3 Stable component ordering

Define deterministic component ordering for:

* fixtures;
* payload serialization;
* receipts/reporting.

---

## 86.4 Partial-return cent consumption

Define the exact historical allocation rule when quantity greater than one shares an indivisible tax cent.

Required before Phase 6.4.

---

## 86.5 Unlinked-return tax policy

Determine how tax is handled when no authoritative original sale exists.

Required before Phase 6.4.

---

## 86.6 Future exemption override model

Determine whether customer exemptions fully replace treatment or act as an explicit exemption modifier over the normal rule.

Not required for Phase 5.

---

## 86.7 Calendar-effective representation

Determine whether initial rules use:

* exact local effective timestamps; or
* local effective dates with deterministic midnight semantics.

Whichever is chosen must preserve the rule that `occurred_at`, not business date, selects the effective rule.

---

# 87. Core invariants summary

The following rules are authoritative unless explicitly superseded:

1. **Tax is calculated at the line/component level.**
2. **Transaction tax is the sum of completed line-component tax cents.**
3. **Tax is calculated after price overrides and discounts.**
4. **Tax class and tax component are separate concepts.**
5. **Tax rules are store-specific and effective-dated.**
6. **`occurred_at`, not `business_date`, determines effective tax configuration.**
7. **Effective intervals use unambiguous inclusive-start/exclusive-end semantics.**
8. **Tax treatments are taxable, exempt, and zero-rated.**
9. **Exempt and zero-rated are distinct reporting treatments.**
10. **Non-applicability is distinct from an explicit zero-tax treatment.**
11. **Exempt/zero-rated completed components preserve zero-tax historical facts.**
12. **Initial pricing is tax-exclusive.**
13. **Initial multiple tax components are independent and non-compounded.**
14. **Each applicable component uses the line's appropriate net tax basis independently.**
15. **Tax is rounded per line per component.**
16. **Initial rounding is decimal half-up to cents.**
17. **Binary floating-point arithmetic is not authoritative.**
18. **Completed tax components preserve treatment, basis, rate, amount, and configuration context.**
19. **Completed tax history is immutable.**
20. **Current central tax rules never rewrite completed terminal tax.**
21. **Offline stale tax is a reconciliation issue, not a recalculation instruction.**
22. **Server validation checks claimed historical arithmetic separately from reference freshness.**
23. **Linked returns reverse historical tax components.**
24. **Partial returns never reverse more tax than originally charged.**
25. **A full return reverses original historical tax exactly.**
26. **Return tax is not recalculated from current rates.**
27. **Open rings use the normal tax engine through resolved classification.**
28. **Known non-inventory merchandise uses ordinary tax rules.**
29. **Phase 5 provides no generic cashier tax override.**
30. **Unsupported tax configuration blocks deterministic completion rather than being guessed.**

---

# 88. Acceptance examples

## Example A — single taxable component

Given:

```text
Tax basis = $20.00
State Tax = 6%
```

then:

```text
State Tax = $1.20
Transaction tax contribution = $1.20
```

---

## Example B — multiple non-compounded components

Given:

```text
Tax basis = $100.00

State Sales Tax   = 6%
Food/Beverage Tax = 1.25%
```

then:

```text
State Tax = $6.00
Food Tax  = $1.25

Total tax = $7.25
```

Food tax is not calculated on `$106`.

---

## Example C — tax after discount

Given:

```text
Selling price = $20.00
Discount      = $2.00
State Tax     = 6%
```

then:

```text
Tax basis = $18.00
Tax       = $1.08
```

---

## Example D — price override plus discount

Given:

```text
Reference price = $20.00
Selling price   = $18.00
Discount        = $2.00
Tax rate        = 6%
```

then:

```text
Tax basis = $16.00
Tax       = $0.96
```

The `$2` reference-price variance is not separately taxed.

---

## Example E — exempt treatment

Given:

```text
Basis = $25.00
Treatment = exempt
```

then:

```text
Tax = $0.00
```

and completed history preserves:

```text
exempt basis = $25.00
```

---

## Example F — zero-rated treatment

Given:

```text
Basis = $25.00
Treatment = zero_rated
Rate = 0%
```

then:

```text
Tax = $0.00
```

and completed history preserves:

```text
zero-rated basis = $25.00
```

separately from exempt basis.

---

## Example G — non-applicable component

Given:

```text
Line tax class = physical_book
Food Tax has no applicable rule for physical_book
```

then:

* no Food Tax is charged;
* ShelfSense does not need to manufacture an exempt Food Tax result merely to explain zero tax.

---

## Example H — rounding

Given a taxable component whose exact calculation produces:

```text
raw tax = $1.235
```

then:

```text
completed tax = $1.24
```

using decimal half-up rounding.

Rails and .NET must produce the same cents.

---

## Example I — line-level rounding

Given two lines that individually produce fractional-cent tax,

then:

* each line/component rounds independently;
* transaction tax is the sum of those rounded component cents;
* ShelfSense does not calculate tax on the combined transaction basis and substitute a different total.

---

## Example J — tax rule changes at midnight

Given:

```text
Store business day closes at 2:00 AM

Old tax rate valid until:
January 1 00:00

New tax rate valid from:
January 1 00:00
```

and a transaction completes:

```text
January 1 at 01:00
business_date = December 31
```

then:

* the January 1 tax rule applies;
* the transaction may still report under business date December 31.

---

## Example K — stale offline tax rate

Given:

```text
POS cached rate = 6%
Central current rate = 7%
```

and the POS completes while offline,

then on synchronization:

* historical rate remains 6%;
* historical tax cents remain unchanged;
* server validates arithmetic under the claimed 6% rule;
* stale configuration is handled through reconciliation.

---

## Example L — full linked return

Given an original line with:

```text
State Tax = $0.96
Food Tax  = $0.20
```

when the whole line is linked and returned,

then the return reverses exactly:

```text
State Tax $0.96
Food Tax  $0.20
```

regardless of current rates.

---

## Example M — partial return

Given:

```text
Original quantity = 3
Original State Tax = $1.00
```

when units are returned across separate transactions,

then:

* historical cents are consumed deterministically;
* cumulative reversal never exceeds `$1.00`;
* once all three units are returned, exactly `$1.00` has been reversed.

---

## Example N — exchange across rate change

Given:

* original merchandise was sold when State Tax was 6%;
* current rate is 7%;
* customer exchanges the old item for a new item;

then:

```text
return line
→ reverses historical 6% tax cents

new sale line
→ calculates using current 7% rule
```

The transaction may therefore contain tax reversal and new tax calculated under different rule versions.

---

## Example O — invalid configuration

Given a line whose tax class has two overlapping active State Tax rules,

when the POS attempts to resolve tax,

then:

* tax resolution fails;
* ShelfSense does not arbitrarily choose one;
* transaction completion is blocked until configuration is valid.

---

# 89. Related workflows

This specification should eventually be referenced by:

* `workflows/sales/cash-sale.md`
* `workflows/sales/add-merchandise.md`
* `workflows/sales/open-ring.md`
* `workflows/sales/complete-transaction.md`
* `workflows/sales/suspend-recall.md`
* `workflows/returns/linked-return.md`
* `workflows/returns/individual-unit-return.md`
* `workflows/returns/exchange.md`
* future customer tax-exemption workflows.

---

# 90. Related contracts

Tax requires exact machine contracts and portable fixtures for:

### Tax-rule resolution

Inputs such as:

```text
store
tax class
occurred_at
reference/config version
```

and resulting applicable component rules.

### Tax arithmetic

For each line/component:

```text
basis
treatment
rate
rounding rule
→
tax cents
```

### Rounding

Golden fixtures covering:

* below half-cent;
* exact half-cent;
* above half-cent;
* zero basis;
* multiple components;
* multiple lines.

### Completed-sale payload

Exact representation of:

```text
tax component identity
treatment
basis
rate
tax cents
rule/reference version
```

### Historical return reversal

Fixtures covering:

* full return;
* partial return;
* residual cents;
* multiple components;
* exchange across rate changes.

The domain specification defines **what ShelfSense tax means and when a tax result is historically authoritative**.

The contract specifications define **the exact arithmetic and representation required for Rails and the POS workstation to reach identical results**.
