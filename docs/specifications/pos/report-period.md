# POS Domain Specification: Reporting Periods

**Design status:** Core workstation Z, business-date, central aggregation, and optional Store Close model decided
**Implementation status:** Minimal Z support in Phase 5; expanded workstation reporting and optional Store Close in Phase 6
**Initial delivery:** Phase 5 — First Operational Cash Sale
**Expanded delivery:** Phase 6 — Core POS Operations
**Related specifications:** Transactions, Tenders, Cash Handling, Receipts, Operation Synchronization, Reconciliation
**Related workflows:** Drawer Open, Drawer Close, Run Z, Store Close, Late Offline Synchronization

---

## 1. Purpose

This specification defines how ShelfSense groups, closes, summarizes, and reports POS activity over operational periods.

It establishes:

* the distinction among occurrence time, business date, drawer sessions, and Z reports;
* workstation ownership of Z reports;
* offline Z operation;
* transaction association with business dates and Z reports;
* immutable Z checkpoints;
* register-level financial summaries;
* central store and organization reporting;
* the relationship between detailed transaction reporting and Z totals;
* the optional Store Close concept;
* handling of late-arriving workstation activity;
* boundaries between reporting periods, cash accountability, inventory authority, and bank-deposit tracking.

This specification does **not** define:

* detailed cash drawer count procedures;
* safe custody;
* cash transfers;
* deposit preparation;
* bank deposit reconciliation;
* general ledger posting;
* reconciliation of business conflicts;
* tax filing periods;
* organization accounting periods.

Those belong to their owning domains.

---

# 2. Governing model

ShelfSense uses three primary levels of POS reporting authority:

```text
Completed Transactions
        ↓
Workstation Z Reports
        ↓
Central Store / Organization Reports
```

An optional fourth concept may be used for management control:

```text
Store Close
```

These levels have different responsibilities.

---

# 3. Transactions remain the detailed financial facts

Completed POS transactions are the authoritative detailed business facts.

They preserve information such as:

* merchandise sold and returned;
* discounts;
* tax;
* tenders;
* actors;
* business date;
* workstation;
* inventory consequences;
* approvals;
* receipt identity.

Central analytical reporting should normally derive detail from these completed facts.

Examples include:

* sales by product;
* sales by department;
* discounts by cashier;
* tax by class/component;
* returns by reason;
* tender activity;
* inventory effects.

A Z report does not replace those underlying records.

---

# 4. Z reports are workstation settlement checkpoints

A Z report is an immutable summary of completed activity for one workstation reporting interval.

It answers:

> **What activity did this workstation settle during this reporting interval?**

Conceptually:

```text
Workstation
    ↓
Z Period
    ├── Completed Transaction A
    ├── Completed Transaction B
    ├── Completed Transaction C
    └── ...
```

The Z provides an operational checkpoint over those underlying facts.

---

# 5. Z is not the transaction authority

A Z may summarize:

* sales;
* returns;
* discounts;
* tax;
* tenders;
* cash expectation;
* inventory effects.

But it is not the source authority for those detailed effects.

For example:

```text
Inventory ledger
    = authoritative inventory history

Z inventory totals
    = summary of inventory-affecting POS activity
```

Likewise:

```text
Completed tender facts
    = authoritative settlement facts

Z tender totals
    = settlement summary
```

---

# 6. Core temporal concepts

ShelfSense distinguishes:

```text
occurred_at
business_date
Z report / Z period
drawer session
```

These concepts must not be treated as synonyms.

---

# 7. `occurred_at`

`occurred_at` records when the transaction actually completed.

It is:

* immutable;
* time-zone-aware;
* independent of later synchronization.

Example:

```text
occurred_at =
2026-08-14 00:37:14 -04:00
```

This is the real event timestamp.

---

# 8. Business date

`business_date` is the store-local operational reporting date assigned when a transaction completes.

Example:

```text
Store business-day boundary: 2:00 AM

Transaction completes:
August 14 at 12:37 AM

business_date:
August 13
```

Business date lets store operations report overnight activity as part of the intended operating day.

---

# 9. Business date is a reporting dimension

ShelfSense does **not** require a persistent central `StoreDay` aggregate merely because transactions have a business date.

Business date is fundamentally:

> **A reporting classification carried by completed activity.**

Central reports can aggregate:

```text
WHERE store_id = X
AND business_date = 2026-08-13
```

without requiring a separately authoritative store-day entity.

---

# 10. Business date is assigned at completion

A transaction receives its business date when it successfully completes.

It is not permanently assigned:

* when the transaction is opened;
* when the first item is scanned;
* when it is suspended;
* when synchronization occurs.

Conceptually:

```text
CompleteTransaction
    ↓
occurred_at assigned
business_date derived
Z association assigned
    ↓
commit
```

---

# 11. Business date is immutable after completion

Once completed:

```text
business_date
```

must not be changed merely because:

* the workstation synchronized later;
* a manager already reviewed that date;
* central reports had already been generated;
* the date is considered operationally closed.

A late August 13 sale remains an August 13 sale.

---

# 12. Business date does not determine tax-effective configuration

Business date is an operational reporting dimension.

Tax-effective configuration remains based on the transaction's actual occurrence time according to the Tax specification.

Therefore:

```text
business_date = August 13
```

does not necessarily imply:

```text
August 13 tax rule
```

if the transaction actually occurred after midnight on August 14.

---

# 13. Z period

A Z period is a workstation-specific reporting interval.

A workstation may have:

```text
0..N Z reports per business date
```

For example:

```text
Store 01
Business date: August 13

Register 1
  Z 101
  Z 102

Register 2
  Z 205
```

ShelfSense must not assume:

```text
one workstation
+
one business date
=
one Z
```

---

# 14. Why multiple Zs are required

Multiple Z reports may result from:

* shift changes;
* register restarts;
* operational handoffs;
* workstation closure and reopening;
* business policies that require multiple settlement periods.

Central reporting aggregates all applicable Z activity for the reporting date.

---

# 15. Z identity

Every Z report requires stable identity independent of its displayed sequence number.

Conceptually:

```text
z_report_id
workstation_id
local z sequence
business_date/context
```

The technical identifier and human-facing sequence may be different.

As with receipt numbering, local workstation sequencing must work offline.

---

# 16. Z is workstation-originated

The workstation is authoritative for its own Z reporting interval.

This follows directly from offline operation.

A workstation must be able to:

```text
operate
complete transactions
close drawer
produce Z
```

without requiring central connectivity.

The organization server must not be required merely to produce the workstation's own close report.

---

# 17. Z data is durable locally

A finalized Z must survive:

* application restart;
* network outage;
* delayed synchronization.

Once finalized locally, the workstation can later synchronize the Z and its underlying operations centrally.

---

# 18. Transactions associate with a Z at completion

A completed POS transaction belongs to the workstation Z period active when it completes.

Example:

```text
Transaction opened: 13:50
Transaction completed: 14:10
```

Its Z association is based on the reporting interval active at 14:10.

Opening time does not determine Z association.

---

# 19. Active transactions block Z finalization

A workstation must not finalize a Z while it has active mutable transaction work that belongs to its current active reporting context.

Therefore:

> **Active transactions block final Z completion.**

The cashier must complete, cancel, or otherwise resolve the active transaction first.

---

# 20. Suspended transactions do not block Z

Suspended transactions remain incomplete work but do not belong permanently to a Z.

Therefore:

> **Suspended transactions do not block Z finalization.**

When later recalled and completed, they receive the business-date and Z context in force at that later completion.

This prevents suspended work from keeping reporting intervals open indefinitely.

---

# 21. Drawer session and Z are separate concepts

A drawer session represents physical Cash custody/accountability.

A Z represents workstation transaction settlement.

They answer different questions.

### Drawer session

> What physical cash was entrusted to this drawer/custodian, and what was counted?

### Z

> What POS financial activity did this workstation complete during this interval?

They may be tightly coupled operationally without being the same domain object.

---

# 22. Phase 5 may make drawer and Z appear equivalent

The initial Cash sale implementation deliberately limits scope to:

* one active Z/workstation;
* one open drawer session;
* opening float;
* Cash sales;
* one drawer close/count.

Operationally, Phase 5 may therefore look like:

```text
open drawer
→ run register
→ count drawer
→ close Z
```

The permanent domain model must not assume that one drawer session always equals one Z.

---

# 23. Final Z cannot contain unresolved open Cash accountability

A final Z must not leave associated Cash accountability unresolved.

At minimum:

> **A Z cannot become final while a drawer session required for that Z remains open.**

The exact relationship between multiple future drawer sessions and Zs belongs to Cash Handling.

---

# 24. Z lifecycle

The initial conceptual lifecycle is:

```text
open
→ final
```

A Z is mutable while open.

Once final, the Z checkpoint itself is immutable.

Additional intermediary operational states may be added if implementation requires them, but should not weaken the finality rule.

---

# 25. Final Z is an immutable checkpoint

Once a Z is finalized, its recorded settlement snapshot must not be silently rewritten.

It answers:

> What did this workstation report when it closed this interval?

That historical checkpoint remains valuable even if central knowledge changes later.

---

# 26. Z totals

A Z should preserve the important workstation settlement figures.

At minimum, progressively across Phases 5 and 6, this may include:

### Transaction activity

* transaction count;
* gross sale activity;
* gross return activity;
* net sales;
* cancelled/void activity as applicable.

### Adjustments

* price-override variance;
* discounts;
* promotions;
* relevant approval/exception counts.

### Tax

* taxable basis;
* exempt basis;
* zero-rated basis;
* tax by component;
* total tax.

### Tender

* payment by tender type/category;
* refunds by tender type/category;
* net tender totals.

### Cash

* expected Cash;
* counted Cash;
* variance.

### Operational summaries

* inventory-affecting sale quantity;
* inventory-affecting return quantity;
* other useful exception metrics.

Not every metric is required in Phase 5.

---

# 27. Z totals should preserve gross activity

A Z should not collapse all activity into one net figure.

For example:

```text
Sales:      $1,000
Returns:      $100
Net:          $900
```

is more useful than storing only:

```text
Net sales: $900
```

Likewise:

```text
Cash payments
Cash refunds
Net Cash
```

should remain separately reportable.

---

# 28. Z inventory reporting is summary-only

Z reports may include operational inventory effects such as:

```text
quantity sold
quantity returned
individually tracked units sold
```

But these are reporting totals.

The central inventory ledger remains the authoritative inventory history.

A Z must never be used to reconstruct missing individual sale ledger effects if the underlying operations are absent.

---

# 29. Z calculation source

The workstation derives its Z from locally authoritative completed facts.

Conceptually:

```text
local completed transactions
+
local completed tender facts
+
local cash accountability facts
        ↓
Z calculation
```

The Z should be reproducible from those underlying local records where practical.

---

# 30. Z snapshot versus rebuildability

The underlying transactions remain authoritative, but the finalized Z snapshot should be stored.

This preserves:

> What totals were asserted when the workstation was closed?

Therefore ShelfSense should support both:

```text
recomputed totals from source facts
```

and:

```text
historical finalized Z snapshot
```

Differences between the two would represent a serious integrity/reconciliation condition.

---

# 31. Central store reporting

Store-level reports do not require a separate authoritative Store Close.

They may derive from synchronized detailed POS facts grouped by:

```text
store
business_date
calendar date
workstation
Z
department
product
tax component
tender
cashier
...
```

For example:

```text
Store 01
Business date August 13

Z 101 sales $1,250
Z 201 sales $1,100
Z 202 sales   $600

Store sales $2,950
```

---

# 32. Organization reporting

Organization reporting similarly aggregates detailed synchronized facts across stores.

Example dimensions may include:

* store;
* business date;
* calendar period;
* department;
* merchandise class;
* product;
* tender;
* tax component;
* cashier.

No organization-level POS "close" is required merely to produce these reports.

---

# 33. Detailed reporting should use transaction facts

Central reporting should not depend exclusively on pre-aggregated Z values.

For example:

```text
sales by author
sales by merchandise class
discounts by cashier
returns by reason
```

require transaction-level detail.

Therefore:

> **Transactions are the detailed reporting source; Z reports are settlement/control checkpoints.**

---

# 34. Central totals should reconcile to Z

Although detailed reports derive from transactions, central reporting should be able to reconcile workstation totals to accepted Z reports.

Conceptually:

```text
sum accepted transaction facts for Z 101
        ↕
Z 101 finalized totals
```

They should agree according to the applicable calculation contracts.

A discrepancy is a reconciliation/integrity condition, not a reason to silently edit one side.

---

# 35. No mandatory Store Day entity

ShelfSense does not initially require:

```text
StoreReportingPeriod
open
→ provisional
→ final
→ amended
```

for every:

```text
store + business_date
```

The existence of business-date reporting does not by itself justify that additional lifecycle.

This intentionally simplifies the offline reporting model.

---

# 36. Store Close is optional management control

ShelfSense may support a **Store Close** as an explicit management/audit snapshot.

A Store Close answers:

> Which register Z reports and exceptions did management review together for this business date?

It is not the authority that makes the underlying transactions valid.

---

# 37. Conceptual Store Close

Without locking schema:

```text
Store Close
│
├── store
├── business_date
├── performed_by
├── performed_at
│
├── included/reviewed Z reports
├── no-activity acknowledgments
├── excluded/missing register exceptions
│
└── optional totals snapshot
```

The exact delivery phase remains flexible.

---

# 38. Choosing Z reports for Store Close

A manager may explicitly review which finalized register reports are included.

Example:

```text
Store Close — August 13

Included:
✓ Register 1 / Z 101
✓ Register 2 / Z 201
✓ Register 2 / Z 202

No activity:
✓ Register 3

Exception:
! Register 4 — hardware failure
```

This creates management-control evidence without claiming unknown future activity cannot exist.

---

# 39. Store Close does not control report membership

A completed transaction's business date determines its reporting classification.

A Store Close must not mean:

> Only transactions from selected Zs are valid August 13 activity forever.

Instead it means:

> These were the Z reports management reviewed when this Store Close snapshot was created.

Late activity remains valid if otherwise legitimate.

---

# 40. Store Close does not close the database to late facts

If a workstation later synchronizes a legitimate transaction or Z for the same business date:

ShelfSense must not reject it solely because a Store Close already exists.

It must not rewrite the activity onto another date.

---

# 41. Late activity after Store Close

Example:

```text
August 13:
Register 4 completes offline activity.

August 14:
Manager performs Store Close without Register 4.

August 15:
Register 4 synchronizes.
```

The correct model is:

```text
Register 4 activity
retains business_date = August 13

Store Close remains historical evidence
of what management reviewed on August 14

Late activity is surfaced explicitly
```

---

# 42. Original Store Close snapshot remains immutable

If a Store Close exists, later activity must not make its original snapshot silently change.

ShelfSense should be able to answer:

> What was known and reviewed at close time?

and separately:

> What is now known for that business date?

---

# 43. Store Close amendment

If needed, late activity can produce a later Store Close amendment or supplemental review.

Conceptually:

```text
Store Close 100
August 13
Reviewed Zs: A, B, C

Amendment 1
Late Z: D
Reviewed by Manager B
```

The original Store Close remains historical.

A single mutable close record should not simply be overwritten.

---

# 44. Store Close is not required for ordinary reports

Reports such as:

```text
Daily Store Sales
Monthly Department Sales
Tax by Business Date
Tender Summary
```

must remain available even if no manager performs Store Close.

Store Close is an optional control process, not a prerequisite for reporting.

---

# 45. No-activity acknowledgment

If Store Close is implemented, a manager/workstation may explicitly record that an expected workstation had no relevant activity for the business date.

Absence of a Z alone should not necessarily be interpreted as no activity where control completeness matters.

Conceptually:

```text
Register 3
Business date August 13
No activity acknowledged
```

---

# 46. Missing-register exception

Store Close may permit an authorized exception for a register that cannot be accounted for.

Example:

```text
Register 4
Hardware failed
Local database unavailable
Included as management exception
```

This allows management to finish its operational review without pretending the missing register is known to contain no activity.

---

# 47. Store Close exceptions are historical

If a missing workstation later recovers and synchronizes, the prior exception is not deleted.

It remains evidence that management closed the store while that workstation was unavailable.

A later amendment records the newly available information.

---

# 48. Z versus Store Close authority

The permanent authority relationship is:

```text
Workstation Z
    = originating workstation settlement fact

Store Close
    = management review/control snapshot

Central Reports
    = aggregation of accepted detailed business facts
```

These concepts must not replace one another.

---

# 49. Offline Z behavior

A workstation must be able to finalize its Z without network connectivity.

Required local data includes enough information to determine:

* active transaction state;
* completed transactions;
* tender totals;
* Cash expectations;
* drawer close status;
* applicable business date.

Central connectivity cannot be a prerequisite for register close.

---

# 50. Z synchronization

Finalized Z reports synchronize to the organization server as durable originating facts.

Synchronization must be idempotent.

Retrying the same Z operation must not create another Z.

The server preserves:

* originating Z identity;
* workstation identity;
* business date;
* local sequence;
* finalized totals;
* close timestamp.

---

# 51. Late Z synchronization

A Z may arrive centrally after its business date.

This is ordinary in an offline-capable architecture.

The server must preserve the original:

```text
business_date
workstation
Z identity
```

and incorporate the underlying accepted activity into reporting for that original date.

---

# 52. Late Z does not move activity forward

Incorrect:

```text
Z for August 13 synchronized August 15
→ classify as August 15
```

Correct:

```text
Z for August 13 synchronized August 15
→ remains August 13 activity
```

Synchronization time is not reporting time.

---

# 53. Late activity and Store Close

If no Store Close exists:

* central reports simply incorporate the late facts.

If a Store Close already exists:

* the Store Close remains historically unchanged;
* late activity is surfaced;
* an amendment/review may be created if required.

Reporting Periods defines this reporting consequence.

Reconciliation may classify the lateness as an operational condition.

---

# 54. Register/Z sequence continuity

A workstation should maintain durable local Z sequencing appropriate for human operational use.

Gaps may be acceptable if they result from legitimate failed/abandoned preparation, depending on implementation.

Finalized Z identifiers/sequences must not knowingly be reused.

The exact numbering contract should be specified alongside receipt/workstation identity rules.

---

# 55. Business-date transitions

A workstation may encounter a business-date boundary while its current Z remains open.

ShelfSense should not assume business-date transition automatically forces the Z to close.

Potentially:

```text
Z 101
contains completed activity from business date August 13

business boundary reached
```

Before accepting activity for a new business date, the workstation should normally transition its reporting context deliberately.

The precise operational workflow should be defined in the Z workflow.

---

# 56. One Z should not span multiple business dates

I recommend the invariant:

> **A finalized Z belongs to exactly one business date.**

This keeps register settlement and daily reporting understandable.

If the business-date boundary changes while a Z is open, ShelfSense should require the workstation to finalize/transition before completing transactions under the next business date.

---

# 57. Why Z should be single-business-date

Allowing:

```text
one Z
contains August 13 + August 14
```

would complicate:

* store daily reporting;
* tax reporting;
* Cash reconciliation;
* operational close procedures.

Multiple Zs on one business date are fine.

One Z across multiple business dates is not.

---

# 58. Z opening context

Opening a new Z should establish at least:

```text
workstation
business_date
opened_at
local sequence
```

and related drawer context where applicable.

The exact opening operation belongs to workflow design.

---

# 59. Z close timestamp

A final Z records the actual close/finalization timestamp separately from its business date.

Example:

```text
business_date = August 13
closed_at = August 14 01:42
```

These values answer different reporting questions and must both remain available.

---

# 60. Z and Cash

For Cash-capable Zs, Cash reconciliation may contribute:

```text
opening float
Cash payments
Cash refunds
other Cash Handling effects
expected Cash
counted Cash
variance
```

Cash Handling owns the calculation and custody semantics.

The Z snapshots the applicable result.

---

# 61. Z does not resolve Cash variance

If:

```text
Expected Cash = $500
Counted Cash  = $498
Variance      = -$2
```

the Z reports the `-$2` variance.

Closing the Z does not automatically create a `$2` balancing movement.

Approval/acknowledgment also does not erase the variance.

---

# 62. Drawer reconciliation must be independently identifiable

Even though bank-deposit tracking is deferred, ShelfSense should preserve each drawer reconciliation/count as an independently identifiable immutable fact.

This allows future workflows to reference:

```text
drawer reconciliation
→ cash transfer
→ safe
→ bank deposit
```

without redesigning historical Z data.

---

# 63. Bank deposits are not a reporting-period concern

The relationship:

```text
drawer close
→ safe custody
→ deposit batch
→ bank deposit
```

belongs to Cash Handling.

A Z should not attempt to represent which physical cash was deposited into which bank deposit.

---

# 64. Deposit tracking may be deferred

Initial reporting can stop at:

```text
Cash activity
→ expected Cash
→ counted Cash
→ variance
→ drawer reconciliation
```

Future Cash Handling can add:

* cash removal;
* safe location;
* deposit bags/batches;
* bank deposit reference;
* deposit verification.

No mandatory deposit architecture is required for Phase 5 Z reporting.

---

# 65. Store Close does not solve deposit custody

Even if Store Close includes several Z reports, that does not prove which physical cash entered a particular deposit.

Example:

```text
Z 101 expected Cash = $500
Z 201 expected Cash = $700
```

does not itself prove:

```text
Bank Deposit D1 = $1,200
```

because drawers may retain floats, incur drops, transfers, variances, or deposits at different times.

Deposit traceability must follow actual cash-custody facts.

---

# 66. Receipt/Z relationship

A Z does not assign receipt identities.

Completed transactions already possess permanent receipt identities.

The Z may report:

* first/last receipt sequence;
* transaction count;
* gaps where useful.

But receipt identity remains transaction/workstation-owned.

---

# 67. Reprints do not affect Z

Receipt reprints do not alter:

* transaction totals;
* tender totals;
* tax totals;
* Z totals.

Reprint activity may be audited but is not new financial activity.

---

# 68. Cancelled transactions

Cancelled transactions do not contribute to financial Z totals.

They may contribute to operational metrics such as:

```text
cancel count
cancelled value
```

where useful.

---

# 69. Suspended transactions

Suspended transactions are not completed financial activity and therefore do not contribute to Z financial totals.

They may remain as operational information but do not block Z finalization.

---

# 70. Voided lines

Pre-completion voided lines do not contribute to completed financial totals.

Z reporting may nevertheless include:

* line-void count;
* voided amount;
* approval counts;

for loss-prevention purposes.

---

# 71. Returns and exchanges

Z reporting should preserve gross:

```text
sales
returns
```

rather than reporting only net sales.

An exchange contributes to both categories according to its sale- and return-direction lines.

Tender reporting reflects only the transaction's net settlement.

---

# 72. Discounts and price overrides

Z should distinguish:

```text
reference-price variance
discount amount
```

rather than collapsing both into one markdown figure.

This preserves the Pricing/Discount domain distinction in register reporting.

---

# 73. Tax reporting

Z should preserve tax totals by component where required.

Examples:

```text
State Sales Tax
Food/Beverage Tax
```

and may report:

* taxable basis;
* exempt basis;
* zero-rated basis;
* collected tax.

The Tax domain defines the source facts.

---

# 74. Tender reporting

Z should preserve gross payments and refunds by tender category/type.

Example:

```text
Cash payments       $800
Cash refunds         $50
Net Cash            $750

Card payments      $1,200
Card refunds         $100
Net Card           $1,100
```

Net alone is insufficient for operational analysis.

---

# 75. External Card settlement is not the Z

A Z summarizes what ShelfSense recorded as Card tender activity.

It does not assert that the external processor's batch settlement or bank deposit exactly matches it.

External Card reconciliation is a separate future integration/accounting concern.

---

# 76. Z report presentation

A human-facing Z should be concise enough to serve operational closing.

Detailed transaction drill-down remains available separately.

The Z should emphasize:

* financial totals;
* tender totals;
* tax;
* Cash accountability;
* exceptions;
* key activity counts.

It should not become a complete analytical report.

---

# 77. Central reporting by Z

Central reports should support filtering/grouping by Z.

This allows questions such as:

* What did Register 2 do during Z 205?
* Which transactions contributed to this variance?
* What were Card totals for this register close?
* Which overrides occurred in this Z?

---

# 78. Central reporting by business date

Reports should also work independently of Z.

Example:

```text
Store 01
Business date August 13

all accepted transactions
across all Zs
```

This produces store daily activity regardless of how many register close intervals occurred.

---

# 79. Calendar-date reporting

ShelfSense should retain the ability to report by actual occurrence/calendar period as well as business date.

These are different dimensions.

For example:

```text
business_date
```

is useful operationally.

```text
occurred_at between timestamps
```

is useful for legal, tax, audit, and analytical needs.

---

# 80. Monthly reporting

Monthly store/organization reports should normally derive from detailed transactions grouped by the intended date dimension.

A report must explicitly define whether "month" means:

* business-date month; or
* actual occurrence/calendar month.

Do not silently substitute one for the other.

---

# 81. Reporting freshness

Central reports reflect the accepted facts currently synchronized to the server.

Because workstations may be offline:

> **Central real-time reports may be incomplete relative to activity physically occurring at disconnected workstations.**

ShelfSense should not claim stronger completeness than it can prove.

---

# 82. Reporting completeness indicators

Even without mandatory Store Close, central reporting may surface useful indicators such as:

```text
latest Z synchronized per workstation
workstations currently offline
late Z received
Store Close exists / does not exist
```

These are operational aids rather than prerequisites for calculating report totals.

---

# 83. Store Close completeness

If Store Close is implemented, it provides a stronger answer to:

> What set of workstation settlements did management intentionally review?

It may therefore include:

* reviewed Zs;
* no-activity acknowledgments;
* missing-register exceptions.

But central reports remain independent.

---

# 84. Late reporting amendments

If a Store Close exists and new activity later becomes known, ShelfSense should preserve:

1. the original close snapshot;
2. the late activity;
3. any subsequent amendment/review.

The new facts must not be hidden merely to preserve the appearance of finality.

---

# 85. No arbitrary historical reopening

A late fact does not reopen:

* original completed transactions;
* original finalized Z;
* original Store Close.

Instead, new facts and amendments are appended.

This follows ShelfSense's broader immutable-history model.

---

# 86. Conceptual Z model

Without locking physical schema:

```text
Z Report
│
├── id
├── store
├── workstation
├── sequence
│
├── business_date
├── opened_at
├── closed_at
│
├── status
│   ├── open
│   └── final
│
├── financial totals snapshot
├── tender totals snapshot
├── tax totals snapshot
├── Cash reconciliation references/snapshot
├── exception/activity totals
│
└── synchronization/version context
```

Underlying completed transactions remain separately linked/referable.

---

# 87. Conceptual Store Close model

Optional future model:

```text
Store Close
│
├── id
├── store
├── business_date
├── performed_by
├── performed_at
│
├── reviewed_z_reports[]
├── no_activity_acknowledgments[]
├── authorized_exceptions[]
├── totals snapshot
│
└── amendment relationship
```

The exact implementation should be deferred until the management-control workflow is required.

---

# 88. Domain ownership

## Reporting Periods owns

* `business_date` reporting semantics;
* workstation Z periods;
* Z lifecycle/finality;
* Z totals;
* transaction-to-Z association;
* offline Z authority;
* central Z aggregation;
* optional Store Close semantics;
* late-reporting consequences;
* business-date versus occurrence-date reporting distinction.

## Transactions owns

* `occurred_at`;
* transaction lifecycle;
* completed financial facts.

## Cash Handling owns

* drawer sessions;
* Cash expectation;
* physical counts;
* variance;
* transfers;
* safe custody;
* deposits.

## Tax owns

* tax component calculations and legal/effective-time semantics.

## Tenders owns

* tender settlement facts.

## Inventory owns

* authoritative inventory effects.

## Synchronization owns

* transport of workstation Z/transaction facts.

## Reconciliation owns

* classification/tracking of inconsistencies and late/conflicting operational conditions.

---

# 89. Phase 5 delivery

Phase 5 requires only a narrow operational subset.

Implement:

* explicit business date;
* one active Z/workstation;
* one open drawer session;
* opening float;
* Cash transactions;
* drawer count;
* expected/count/variance;
* final Z.

Minimum Z totals:

```text
transaction count
gross sales
tax
Cash payments
Cash refunds if supported
expected Cash
counted Cash
variance
```

Phase 5 does **not** require:

* multiple drawer sessions;
* advanced Z exceptions;
* Store Close;
* bank deposits;
* no-activity declarations;
* store completeness workflow.

---

# 90. Phase 6 expansion

Phase 6 should expand Z reporting to include:

* multiple Zs per business date;
* returns;
* discounts;
* overrides;
* broader tender categories;
* tax components;
* full Cash activity;
* exception metrics;
* richer drawer relationships;
* central Z drill-down/reconciliation.

---

# 91. Store Close delivery

Store Close should be implemented only when a concrete management-control need justifies it.

A likely later Phase 6 capability could include:

* choose/review finalized Zs;
* identify no-activity registers;
* authorize missing-register exceptions;
* capture management review snapshot;
* surface later activity;
* create amendments.

It should not block ordinary central reporting if deferred.

---

# 92. Cash deposit delivery

Bank-deposit tracking should remain deferred to Cash Handling.

When implemented, it should reference immutable Cash facts such as:

* drawer reconciliation;
* transfers from drawer;
* safe receipts;
* deposit batch;
* bank reference.

No changes to Z authority should be required.

---

# 93. Pending decisions

## 93.1 Business-day transition policy

Define exactly when a workstation must close its current Z and open a new one across a business-date boundary.

Recommended invariant:

> One final Z belongs to exactly one business date.

---

## 93.2 Z numbering

Define workstation-local Z sequence behavior, including:

* sequence initialization;
* persistence;
* gap handling;
* replacement workstation behavior.

---

## 93.3 Minimum Phase 5 Z contents

Lock exact required snapshot fields before implementation.

---

## 93.4 Multiple drawer/Z relationship

Define allowed cardinality once Phase 6 Cash Handling supports multiple drawer sessions.

Do not assume permanent 1:1.

---

## 93.5 Store Close necessity

Determine from pilot/operational experience whether management actually needs a formal Store Close.

It is not required for the core reporting architecture.

---

## 93.6 Store Close totals snapshot

If Store Close is implemented, determine whether it stores:

* only reviewed Z references and control metadata; or
* an additional immutable totals snapshot.

A totals snapshot is useful for audit but not required for calculation authority.

---

## 93.7 No-activity mechanism

If Store Close requires register completeness, determine whether no-activity acknowledgment is:

* workstation-originated;
* manager-entered;
* either depending on circumstances.

---

## 93.8 Store Close amendments

Define exact version/amendment mechanics only when Store Close is implemented.

---

## 93.9 Central report completeness messaging

Define how UI/reporting communicates that disconnected workstations may make current central totals incomplete.

---

# 94. Core invariants summary

The following rules are authoritative unless explicitly superseded:

1. **Completed transactions are the detailed authoritative POS business facts.**
2. **Z reports are workstation settlement checkpoints, not replacements for transactions.**
3. **Z reports may summarize inventory effects but do not replace the inventory ledger.**
4. **`occurred_at` and `business_date` are separate concepts.**
5. **Business date is assigned when the transaction completes.**
6. **Business date is immutable after completion.**
7. **Synchronization time never determines business date.**
8. **Tax-effective rule selection uses occurrence time, not business date.**
9. **A workstation may have multiple Zs on one business date.**
10. **One finalized Z belongs to exactly one business date.**
11. **Z association is assigned when the transaction completes.**
12. **Active transactions block Z finalization.**
13. **Suspended transactions do not block Z finalization.**
14. **Drawer session and Z are separate domain concepts.**
15. **A Z cannot finalize while required associated Cash accountability remains open.**
16. **A finalized Z is an immutable workstation-originated checkpoint.**
17. **Workstations must be able to produce Zs offline.**
18. **Central analytical reporting derives primarily from detailed accepted transaction facts.**
19. **Central reports should reconcile back to workstation Z totals.**
20. **Store/organization reports do not require a mandatory Store Day entity.**
21. **Store Close is optional management-control evidence, not transaction authority.**
22. **A Store Close may record reviewed Zs, no-activity acknowledgments, and exceptions.**
23. **Late legitimate activity is not rejected merely because a Store Close already exists.**
24. **Late activity retains its original business date and Z identity.**
25. **Original finalized Z and Store Close snapshots are never silently rewritten.**
26. **Late facts are represented through additional facts/amendments where needed.**
27. **Bank-deposit traceability belongs to Cash Handling, not Reporting Periods.**
28. **Drawer reconciliation should remain independently identifiable for future deposit traceability.**
29. **Central reporting may be incomplete while workstations remain offline.**
30. **ShelfSense must not claim reporting completeness merely from the absence of unsynchronized data.**

---

# 95. Acceptance examples

## Example A — one register, one Z

Given:

```text
Register 1
Business date August 13
Z 101 open
```

when five Cash sales complete and the drawer is counted and reconciled,

then:

* Z 101 may finalize;
* all five transactions reference Z 101;
* Z totals summarize those completed transactions;
* finalized Z 101 is immutable.

---

## Example B — multiple Zs on one business date

Given:

```text
Register 1
Business date August 13
```

when:

```text
Z 101 closes at 14:00
Z 102 opens at 14:05
```

then both Z reports belong to August 13.

Store reporting for August 13 includes activity from both.

---

## Example C — active transaction blocks Z

Given an open transaction with scanned merchandise,

when the cashier attempts to finalize the current Z,

then ShelfSense requires the active transaction to be:

* completed;
* cancelled;
* otherwise resolved.

The Z cannot finalize first.

---

## Example D — suspended transaction does not block Z

Given a suspended incomplete transaction,

when the register closes its Z,

then the suspended transaction does not block finalization.

When later recalled and completed, it receives the then-current business-date/Z context.

---

## Example E — late synchronization

Given:

```text
Transaction completed offline:
August 13
business_date = August 13
Z = 101

Synchronization:
August 15
```

then centrally:

* business date remains August 13;
* Z remains 101;
* August 13 reports incorporate the activity.

---

## Example F — store reporting without Store Close

Given Store 1 has synchronized:

```text
Z 101 sales = $1,000
Z 201 sales = $800
```

for August 13,

then ShelfSense can report:

```text
Store 1 sales
August 13
= $1,800
```

without any persistent Store Close record.

---

## Example G — optional Store Close

Given three register Zs:

```text
Register 1 / Z 101
Register 2 / Z 201
Register 3 / Z 301
```

when Manager A reviews all three and performs Store Close,

then the close records the reviewed Z set and management metadata.

It does not modify the underlying Zs or transactions.

---

## Example H — missing register at Store Close

Given Register 4 cannot be recovered,

when management performs Store Close,

then it may record an authorized exception such as:

```text
Register 4
Hardware failure
Not available at close
```

rather than falsely recording no activity.

---

## Example I — late register after Store Close

Given Store Close was performed without Register 4,

when Register 4 later synchronizes valid August 13 transactions and Z data,

then:

* the late activity remains August 13;
* it is incorporated into current central reports;
* the original Store Close remains unchanged;
* the late activity may trigger a Store Close amendment/review.

---

## Example J — Z totals versus transaction detail

Given Z 101 reports:

```text
Sales = $1,000
```

then central reporting should be able to derive the same applicable total from the accepted transactions associated with Z 101.

If it cannot, the discrepancy is surfaced rather than silently correcting the finalized Z.

---

## Example K — inventory reporting

Given Z 101 summarizes:

```text
Quantity sold = 42
Quantity returned = 3
```

then those figures are operational summaries.

The authoritative inventory ledger remains composed of the underlying accepted inventory effects.

---

## Example L — Cash variance

Given:

```text
Expected Cash = $500
Counted Cash  = $498
Variance      = -$2
```

when the drawer/Z closes,

then:

* Z records `-$2` variance;
* no automatic balancing Cash movement occurs;
* the variance remains historically visible.

---

## Example M — future deposit

Given Drawer Reconciliation R1 records Cash transferred out of a closed drawer,

a future Cash Handling implementation may link:

```text
R1
→ Cash transfer
→ Safe
→ Deposit D100
```

without changing the historical Z.

---

# 96. Related workflows

This specification should eventually be referenced by:

* `workflows/reporting/run-z.md`
* `workflows/reporting/store-close.md`
* `workflows/reporting/late-offline-amendment.md`
* `workflows/cash/drawer-open.md`
* `workflows/cash/drawer-close.md`
* `workflows/sales/complete-transaction.md`
* `workflows/sync/completed-operation.md`

---

# 97. Related contracts

Reporting Periods will eventually need exact contracts for:

### Business-date assignment

Inputs such as:

```text
occurred_at
store timezone
business-day configuration
```

producing:

```text
business_date
```

### Z identity

Including:

```text
workstation
Z UUID
local Z sequence
business date
opened_at
closed_at
```

### Z totals

Exact calculation definitions for:

* sale/return totals;
* discounts;
* tax;
* tender payments/refunds;
* Cash expected/count/variance;
* key operational metrics.

### Z synchronization

Define idempotent transfer and verification of workstation-originated final Z facts.

### Optional Store Close

If implemented, define:

* reviewed Z references;
* no-activity acknowledgments;
* authorized exceptions;
* immutable snapshot/amendment relationships.

The Reporting Periods domain defines **how POS activity is grouped and operationally settled over time**.

Detailed transactions remain the financial facts; Z reports provide the durable register-close checkpoint; central reporting aggregates those facts without requiring an artificial store-day authority layer.
