# POS Domain Specification: Cash Handling

**Design status:** Core drawer custody, expected-versus-counted reconciliation, cash movements, transfers, and variance semantics decided; advanced safe/deposit workflows remain partly deferred
**Implementation status:** Minimal drawer model in Phase 5; full cash operations in Phase 6.5
**Initial delivery:** Phase 5 — First Operational Cash Sale
**Expanded delivery:** Phase 6.5 — Full Cash Handling
**Related specifications:** Tenders, Transactions, Approvals, Reporting Periods, Workstation Identity, Operation Synchronization, Reconciliation
**Related workflows:** Drawer Open, Drawer Close, Paid-In, Paid-Out, Cash Drop, Replenishment, Safe Count, Cash Transfer
**Future related specifications:** Deposits / Financial Posting

---

## 1. Purpose

This specification defines the ShelfSense POS Cash Handling domain.

It establishes:

* physical cash custody;
* drawer sessions;
* opening floats;
* expected cash;
* physical cash counts;
* over/short variance;
* customer Cash tender interaction;
* paid-ins and paid-outs;
* internal cash transfers;
* drops and replenishments;
* cash locations;
* drawer closing and reconciliation;
* count immutability;
* approval and variance acknowledgment;
* offline behavior;
* reporting-period interaction;
* future safe and bank-deposit traceability.

This specification does **not** define:

* Cash tender settlement itself;
* transaction totals;
* Z-report lifecycle;
* bank-account reconciliation;
* general-ledger posting;
* detailed deposit workflow;
* card settlement;
* stored-value balances.

Those belong to their owning domains.

---

# 2. Governing principle

ShelfSense separates four fundamentally different kinds of Cash facts:

```text
Customer Cash Tender
    → customer payment/refund

External Cash Movement
    → cash enters/leaves store custody
      for a non-customer-tender reason

Internal Cash Transfer
    → cash moves between store cash locations

Cash Count
    → observation of physical cash
```

These concepts must not be collapsed.

Most importantly:

> **A cash count does not create or remove cash. It records what staff physically observed.**

---

# 3. Cash Handling versus Tenders

The Tender domain records customer settlement.

Example:

```text
Cash payment tender
applied = $17.24
```

Cash Handling consumes that completed fact as one contributor to physical cash expectation.

Tender answers:

> How much of the customer's obligation was settled in Cash?

Cash Handling answers:

> How much physical Cash should now be in this drawer, and how much was actually counted?

---

# 4. Customer Cash tender is not duplicated as a movement

A Cash sale must not create both:

```text
Cash Tender +$17.24
```

and:

```text
Generic Cash Movement +$17.24
```

as independent financial causes.

That would double-count the physical effect.

Instead:

```text
completed Cash tender
        ↓
contributes to expected cash
```

Customer tender is already the authoritative explanation for that physical cash activity.

---

# 5. Cash custody

Cash Handling tracks responsibility for physical currency held by the store.

Conceptually:

```text
Cash
  ↓
Cash Location
  ↓
Custody / Session
```

The initial important cash location is the POS drawer.

Later locations may include:

* safe;
* deposit staging location;
* other explicit store cash locations.

---

# 6. Drawer

A drawer represents a physical or logical POS cash container associated with register operation.

The drawer itself is not the same thing as:

```text
workstation
cashier
drawer session
Z
```

These relationships may often appear 1:1 operationally but remain separate domain concepts.

---

# 7. Drawer session

A **drawer session** is a bounded interval of Cash custody/accountability.

Conceptually:

```text
Drawer Session
├── workstation
├── drawer/cash location
├── opened_by
├── opened_at
├── opening float
├── Cash activity
├── counts
├── expected Cash
├── accepted/closing count
├── variance
├── closed_by
└── closed_at
```

A drawer session is mutable while open.

Once closed, its historical reconciliation facts become immutable.

---

# 8. Why drawer session is separate from Z

A Z answers:

> What financial activity did the workstation settle?

A drawer session answers:

> What physical Cash was under this custody interval, and did the count agree with expectation?

The concepts interact but should not be merged.

This allows future models such as:

```text
one Z
    ↓
multiple sequential drawer sessions
```

without redesigning transaction reporting.

---

# 9. Phase 5 simplification

Phase 5 intentionally supports only:

```text
one active Z per workstation
one open drawer session
one opening float
Cash sales
one closing count
one variance
```

Operationally this may resemble:

```text
Open register
→ open drawer
→ sell
→ count drawer
→ close drawer
→ finalize Z
```

The permanent model must not assume these are one object.

---

# 10. One open drawer session per workstation initially

The initial invariant is:

> **A workstation may have at most one open drawer session at a time.**

This avoids ambiguity over which physical cash location receives customer Cash tender activity.

Future shared-drawer or concurrent-custody models must be explicitly designed rather than implied.

---

# 11. Drawer opening

Opening a drawer session establishes the initial physical Cash custody context.

At minimum:

```text
workstation
drawer/location
opened_by
opened_at
opening_float_cents
```

Opening creates the baseline from which expected cash is derived.

---

# 12. Opening float

The opening float is the amount of physical Cash present when the drawer begins operating.

Example:

```text
Opening float = $100
```

Initial expected Cash is therefore:

```text
expected_cash = $100
```

before any further activity.

---

# 13. Opening float is not revenue

Opening float must not affect:

* sales;
* tender revenue;
* transaction totals;
* tax.

It is custody of preexisting Cash.

---

# 14. Future opening-float source

Once ShelfSense models safe custody and internal transfers fully, an opening float should normally be traceable to a source such as:

```text
Safe
   ↓ $100 transfer
Drawer Session
```

Phase 5 does not require this upstream custody chain.

It may simply record the opening float as the drawer-session starting condition.

---

# 15. Expected Cash

**Expected Cash** is the amount ShelfSense calculates should physically be present according to known authoritative Cash activity.

It is derived rather than manually declared.

Conceptually:

```text
Expected Cash
=
opening float
+ Cash payment tenders
- Cash refund tenders
+ external cash inflows
- external cash outflows
+ internal transfers in
- internal transfers out
```

Counts do not participate in this calculation.

---

# 16. Initial expected-Cash equation

Conceptually:

```text
expected_cash =
    opening_float
  + cash_payments
  - cash_refunds
  + paid_ins
  - paid_outs
  + replenishments
  - drops
  + other_internal_transfers_in
  - other_internal_transfers_out
```

The exact calculation contract will operate in integer cents.

---

# 17. Cash presented is not expected Cash

For a sale:

```text
Amount due       $17.24
Cash presented   $20.00
Change             2.76
Cash applied      17.24
```

drawer expectation increases by:

```text
$17.24
```

not:

```text
$20.00
```

because change immediately leaves the drawer again.

Cash Handling consumes the tender's **applied amount**.

---

# 18. Cash refund

A completed Cash refund reduces expected drawer Cash.

Example:

```text
Cash refund applied = $20
```

therefore:

```text
expected Cash change = -$20
```

No separate generic paid-out should be created for the same customer refund.

---

# 19. External cash movements

An external cash movement explains physical Cash entering or leaving store custody for reasons other than customer tender or internal transfer.

Initial important types include:

```text
paid_in
paid_out
```

These are operational Cash facts.

---

# 20. Paid-in

A paid-in records physical Cash entering the drawer/store for a non-sale reason.

Example:

```text
Paid-in
Amount: $25
Reason: ...
```

Effect:

```text
expected Cash +$25
```

It is not:

* sales revenue;
* customer tender;
* transfer from another tracked ShelfSense cash location.

---

# 21. Paid-out

A paid-out records physical Cash leaving the drawer/store for a non-customer-refund reason.

Example:

```text
Paid-out
Amount: $40
Reason: store emergency expense
```

Effect:

```text
expected Cash -$40
```

It is not:

* a return refund;
* a drop to the safe;
* a bank deposit.

---

# 22. Paid-out versus customer refund

These must remain distinct.

```text
Customer return
→ Cash refund tender
```

versus:

```text
Cash removed for store expense
→ paid-out
```

Both reduce physical drawer Cash, but their business explanations are completely different.

---

# 23. Paid-in/out reasons

Paid-ins and paid-outs should normally require structured reasons.

Potential examples may include:

```text
petty cash reimbursement
emergency local purchase
cash correction
other authorized reason
```

The actual reason catalog remains configurable.

Free-text notes may supplement structured reasons where appropriate.

---

# 24. Paid-in/out approval

Paid-ins and paid-outs are controlled Cash actions.

Approval policy may evaluate:

* amount;
* movement type;
* reason;
* performer;
* store policy.

Possible outcomes remain:

```text
direct
approval_required
prohibited
```

Approvals owns authorization.

Cash Handling owns the resulting physical cash fact.

---

# 25. Internal cash transfer

An internal Cash transfer moves physical Cash between two ShelfSense-controlled cash locations.

Conceptually:

```text
source location
    ↓ amount
destination location
```

The transfer does not create or destroy store Cash.

---

# 26. Transfer conservation invariant

For a completed internal transfer:

```text
source Cash decreases by X
destination Cash increases by X
```

The organization-wide physical Cash effect is:

```text
0
```

ignoring any later external deposit/removal.

---

# 27. Transfer is one logical business fact

A transfer should not be represented as two unrelated manual movements:

```text
source paid-out $500
destination paid-in $500
```

That loses the relationship between them.

Instead:

```text
Cash Transfer T
source = Drawer
destination = Safe
amount = $500
```

produces linked effects on both locations.

---

# 28. Cash drop

A Cash **drop** is an internal transfer out of a drawer, usually to a safer store-controlled location.

Conceptually:

```text
Drawer
  ↓
Safe
```

Effect on drawer:

```text
expected Cash decreases
```

Effect on store-wide Cash:

```text
no change
```

A drop is not an expense.

---

# 29. Replenishment

A replenishment is an internal transfer of Cash into a drawer.

Conceptually:

```text
Safe
  ↓
Drawer
```

Effect on drawer:

```text
expected Cash increases
```

Effect on store-wide Cash:

```text
no change
```

A replenishment is not revenue.

---

# 30. Drops and replenishments are transfer semantics

ShelfSense may expose convenient workflow names:

```text
cash drop
replenishment
```

but their underlying accounting/custody meaning is:

```text
internal transfer
```

This prevents duplicate concepts from drifting apart.

---

# 31. Cash locations

The expanded Cash Handling model should support explicit physical Cash locations.

Examples:

```text
drawer
safe
deposit staging
```

Each location has stable identity.

Location type and individual location identity should remain distinct.

For example:

```text
type = safe
name = Main Office Safe
```

---

# 32. Location balances are derived

ShelfSense should prefer:

```text
opening state
+
authoritative Cash effects
```

to derive the expected amount associated with a cash location.

A stored/materialized balance may be useful operationally but should be rebuildable from authoritative Cash facts where practical.

---

# 33. Cash count

A Cash count is an independent observation:

> A person physically counted this amount at this location at this time.

Conceptually:

```text
Cash Count
├── cash location/session
├── counted_by
├── counted_at
├── counted_amount
└── count context
```

Counts do not alter expected Cash.

---

# 34. Count is not a movement

This is a core invariant.

Suppose:

```text
Expected = $500
Counted  = $498
```

Recording the `$498` count must **not** create:

```text
-$2 cash movement
```

or change expected Cash to `$498`.

The system now knows:

```text
expected = $500
counted  = $498
variance = -$2
```

All three facts matter.

---

# 35. Variance

Variance is derived as:

```text
variance
=
counted Cash
-
expected Cash
```

Therefore:

```text
positive variance
→ over
```

and:

```text
negative variance
→ short
```

Example:

```text
Expected = $500
Counted  = $498

Variance = -$2
```

The drawer is `$2 short`.

---

# 36. Variance is never automatically erased

ShelfSense must not generate an automatic balancing movement merely so:

```text
expected = counted
```

after a drawer count.

If the drawer is `$2 short`, it stays historically `$2 short`.

This is essential for:

* loss prevention;
* audit;
* cashier accountability;
* trustworthy reporting.

---

# 37. Approving a variance does not change it

Suppose:

```text
Expected = $500
Counted  = $480
Variance = -$20
```

Manager approval may record:

> This variance has been reviewed/accepted for operational close.

It must not transform the facts into:

```text
Expected = $480
Variance = $0
```

Approval is evidence of review, not a financial adjustment.

---

# 38. Recounts

A recount creates a new Cash Count.

It does not edit the previous count.

Example:

```text
Count 1
$480
by Cashier A
at 21:04

Count 2
$500
by Manager B
at 21:08
```

Both observations remain historically available.

---

# 39. Accepted closing count

Where multiple counts exist, the drawer-close workflow may identify which count is accepted as the closing reconciliation count.

Conceptually:

```text
closing_count_id = Count 2
```

This does not invalidate or delete Count 1.

---

# 40. Blind count

A future/full Cash workflow should support a blind first count.

In a blind count:

> The person counting is not shown the system's expected amount before submitting the count.

This reduces bias toward making the physical count match expectation.

Phase 5 does not need to require blind counting.

---

# 41. Recount after blind count

After a blind first count produces material variance, policy may permit or require:

```text
recount
second actor
manager review
```

Each count remains independently immutable.

Approval policy determines whether a variance requires another actor.

---

# 42. Denomination counts

The domain may later allow counts by denomination:

```text
$20 × 10
$10 × 12
$5 × 8
$1 × 40
coins ...
```

with derived total.

This is useful operationally but not necessary for the initial Cash model.

The authoritative count amount remains the accepted physical observation.

---

# 43. Drawer closing

Closing a drawer session establishes an immutable Cash reconciliation checkpoint.

At minimum the close freezes:

```text
expected Cash
accepted counted Cash
variance
closed_by
closed_at
```

and references the underlying Cash activity.

---

# 44. Drawer close prerequisites

Before ordinary drawer close:

* required Cash activity must be durable;
* required count must exist;
* unresolved count workflow must be completed;
* required variance approval must be satisfied;
* no operation may still be mutating the same drawer session.

Exact operational validation belongs to the drawer-close workflow.

---

# 45. Drawer close does not mean the Cash disappeared

Closing a drawer session ends the custody/accountability interval.

It does not by itself move physical Cash anywhere.

If staff remove Cash afterward:

```text
drawer
→ safe
```

that is a transfer.

If they leave Cash in the physical drawer for subsequent custody, that future process must explicitly define the new session's starting custody.

---

# 46. Closing count versus cash removal

These are independent.

Example:

```text
Closing count:
$500
```

Then:

```text
Retain float in drawer:
$100

Transfer to safe:
$400
```

The count proves what was present.

The transfer explains what physically happened afterward.

ShelfSense should not infer one from the other.

---

# 47. Sequential drawer sessions

Future/full Cash Handling should permit multiple sequential drawer sessions.

Example:

```text
Drawer Session A
08:00–14:00

Drawer Session B
14:05–21:00
```

Each has separate:

* custody;
* opening condition;
* activity;
* counts;
* variance.

---

# 48. Cashier identity

A drawer session should preserve the actors responsible for:

```text
opening
counts
closing
```

Potential future custody models may distinguish:

```text
single-cashier drawer
shared drawer
```

The initial Phase 5 model can use the active cashier/register context without locking the permanent system to single-cashier custody.

---

# 49. Drawer handoff

Explicit drawer/cashier handoff semantics are deferred from Phase 5.

A future handoff should not merely change:

```text
cashier_id
```

on an open drawer session without preserving accountability.

Potential designs include:

* close/reopen sessions;
* explicit custody handoff with counts;
* shared-drawer policy.

This must be deliberately designed before support.

---

# 50. Cash movement timestamps

Each completed Cash activity should preserve its actual occurrence time.

Examples:

```text
paid_out_at
transfer_at
counted_at
closed_at
```

Synchronization time is separate.

Offline synchronization must not rewrite the original operational time.

---

# 51. Business date

Cash activities associated with register operation should preserve applicable business-date context where meaningful.

For example:

* drawer session;
* paid-out;
* drop;
* closing count.

This supports Z/business-date reporting while keeping actual timestamps intact.

Reporting Periods owns the meaning of business date.

---

# 52. Z relationship

A drawer session may contribute Cash reconciliation data to a Z.

The Z may snapshot:

```text
opening float
Cash payments
Cash refunds
paid-ins
paid-outs
transfers
expected Cash
counted Cash
variance
```

according to its associated Cash activity.

Cash Handling remains the authority for those custody facts.

---

# 53. Z finalization dependency

A Z cannot become final while required associated drawer accountability remains open.

Conceptually:

```text
close/reconcile drawer
        ↓
Cash accountability complete
        ↓
finalize Z
```

This does not mean Z and drawer close are one domain operation.

---

# 54. Cash expected at Z versus drawer

Expected Cash fundamentally belongs to the drawer/location custody model.

The Z may report it as a snapshot.

ShelfSense should not calculate one independent expected-Cash number in Cash Handling and another unrelated number inside the Z implementation.

---

# 55. External movements and Z

Paid-ins/outs occurring during a Z interval should be included in relevant Cash reporting.

However, they must remain separately identifiable from customer tender activity.

Example Z:

```text
Cash payments      $1,000
Cash refunds          -50
Paid-ins              +20
Paid-outs             -30
Drops                -500
Expected drawer ...
```

This makes physical reconciliation explainable.

---

# 56. Cash expected is physical, not revenue

A drop of `$500` reduces drawer expected Cash by `$500`.

It does **not** reduce sales.

Likewise a `$20` paid-in increases expected Cash but does not increase sales revenue.

Financial-sales reporting and physical-Cash custody reporting remain separate.

---

# 57. Cash transfer authority

Internal transfers become authoritative physical-custody facts only when successfully completed.

The exact transfer workflow may eventually require:

* source actor;
* destination actor;
* amount;
* source/destination locations;
* reason;
* approval;
* acknowledgement.

The core invariant is preservation of the custody chain.

---

# 58. Transfer in transit

For simple same-store hand-to-hand transfers, ShelfSense may be able to commit source and destination effects atomically.

For future workflows where Cash physically travels between locations and receipt is delayed, the model may need an explicit:

```text
in_transit
```

custody state.

This is deferred until a concrete operational need exists.

---

# 59. Safe custody

Full Phase 6 Cash Handling may introduce safes as first-class cash locations.

A safe should support:

* internal transfers in/out;
* expected balance;
* counts;
* reconciliation.

It should not be modeled as an unusually large drawer session.

---

# 60. Safe count

Like drawer counts, a safe count is an independent physical observation.

```text
expected safe Cash
counted safe Cash
variance
```

The same invariant applies:

> Counting a safe does not create a cash movement or erase variance.

---

# 61. Deposit staging

Future deposit handling may introduce an intermediate custody concept such as:

```text
safe
→ deposit bag / deposit batch
→ bank
```

This is not required for initial Cash Handling.

The current model only needs to remain extensible to it.

---

# 62. Bank deposit

A bank deposit should eventually represent Cash leaving store physical custody for deposit with a financial institution.

Conceptually:

```text
one or more store Cash sources
        ↓
Deposit
        ↓
bank reference / confirmation
```

This is distinct from:

* Store Close;
* Z;
* drawer reconciliation.

---

# 63. Deposit traceability

A future deposit workflow should be able to answer:

> Which reconciled Cash/custody transfers contributed to this deposit?

Conceptually:

```text
Drawer Reconciliation A
    ↓ transfer
Safe

Drawer Reconciliation B
    ↓ transfer
Safe

Safe
    ↓
Deposit D100
```

This is why drawer reconciliations and transfers need stable identities now.

---

# 64. Deposits may be deferred

Phase 5 and the initial Phase 6 Cash model do not require full bank-deposit tracking.

It is sufficient initially to stop at:

```text
customer Cash activity
        ↓
expected drawer
        ↓
physical count
        ↓
variance
        ↓
drawer close
```

Expanded Cash Handling can add:

```text
transfers
safe custody
deposit
```

later without redefining tender or Z history.

---

# 65. Store Close does not control Cash custody

An optional Store Close may review:

```text
Z reports
drawer reconciliations
```

but does not itself move or deposit Cash.

Cash may still physically reside:

* in drawers;
* in a safe;
* in transfer.

Store Close is reporting/control evidence.

Cash Handling tracks physical custody.

---

# 66. Cash operations are business facts

Paid-ins, paid-outs, transfers, counts, and drawer closes should have stable identities.

They are not merely audit log messages.

They must be available for:

* reconciliation;
* reporting;
* synchronization;
* support investigation;
* future financial posting.

---

# 67. Activity audit versus Cash fact

For example:

```text
Cash Paid-Out P100
amount = $50
```

is the business fact.

An activity/audit event such as:

```text
Cashier initiated paid-out
Manager approved
Paid-out completed
```

provides explanatory history.

The audit stream does not replace the cash operation itself.

---

# 68. Completed Cash facts are immutable

After completion, ShelfSense should not allow in-place edits to:

* paid-in amount;
* paid-out amount;
* transfer amount;
* source/destination;
* count;
* accepted closing count;
* variance;
* drawer opening/closing facts.

Correction requires a new compensating or corrective operation.

---

# 69. Correcting a Cash movement

Suppose a paid-out was mistakenly recorded as `$50` but only `$40` actually left the drawer.

Do not edit:

```text
$50 → $40
```

after completion.

A defined correction operation should preserve:

```text
original paid-out $50
correction +$10
```

or another appropriate compensating representation.

Exact correction workflows are deferred.

---

# 70. Correcting a count

A mistaken count is corrected through another count/recount, not by editing the original observation.

Example:

```text
Count 1 = $480
Count 2 = $500
```

The accepted close may reference Count 2.

Count 1 remains historical.

---

# 71. Expected-Cash projection

For operational performance, ShelfSense may maintain a current expected-Cash projection for an open drawer/location.

That projection should be rebuildable from:

```text
opening state
+
completed Cash activity
```

where practical.

It is not more authoritative than the underlying facts.

---

# 72. Concurrency

A Cash location must not allow conflicting simultaneous operations to corrupt custody history.

Examples:

* two processes closing the same drawer;
* two transfers spending the same source balance;
* drawer closed while another movement commits.

The exact locking/concurrency mechanism belongs to implementation planning.

The domain invariant is consistent serialization of authoritative Cash effects.

---

# 73. Offline behavior

Cash Handling is a workstation-local operational domain for drawer activity.

The workstation must be able to perform ordinary supported Cash operations without central connectivity, including:

* Cash sale effects;
* closing count;
* drawer close;
* Z close.

Future offline support for:

* paid-ins/outs;
* drops;
* replenishments;

should likewise be defined explicitly.

---

# 74. Local authority

For an originating workstation drawer session:

> **The workstation's completed local Cash facts are authoritative originating facts.**

The server consolidates and validates them later.

It must not rewrite counts or variances merely because they arrived late.

---

# 75. Synchronization

Completed Cash operations synchronize idempotently.

Retrying the same:

```text
Paid-Out operation
```

must not reduce expected Cash twice.

Retrying the same:

```text
Transfer
```

must not move Cash twice.

Stable operation identity/idempotency applies just as it does to completed sale operations.

---

# 76. Stale authority

An offline paid-out might later be discovered to have been performed under stale cached permission.

That is an authorization/reconciliation condition.

The historical Cash fact must not silently change its:

* amount;
* actor;
* reason;
* occurrence time.

Approvals and Reconciliation determine the resulting handling.

---

# 77. Drawer variance is not a synchronization conflict by itself

If:

```text
expected = $500
counted = $498
variance = -$2
```

the variance is a legitimate business observation.

It is not evidence that synchronization failed.

It may require:

* acknowledgment;
* approval;
* investigation.

But the mere fact that counted cash differs from expected is not structurally invalid.

---

# 78. Cash reconciliation versus system reconciliation

The word “reconciliation” appears in two contexts and should remain distinguished.

## Cash reconciliation

```text
expected Cash
versus
physical count
```

## Distributed/system Reconciliation domain

```text
originating facts
versus
central consolidated state
```

They are related operationally but are not the same process.

---

# 79. Reporting

Cash Handling should support reporting by:

* store;
* workstation;
* drawer;
* drawer session;
* business date;
* Z;
* cashier/actor;
* cash location;
* movement type;
* reason;
* approver.

Useful metrics include:

```text
opening float
Cash payments
Cash refunds
paid-ins
paid-outs
transfers in
transfers out
expected Cash
counted Cash
variance
```

---

# 80. Variance reporting

Variance reporting should preserve:

```text
over amount
short amount
net variance
count actor
closing actor
approver
reason/context
```

where applicable.

Do not report only net variance across many drawers if that would hide individual over/short events.

---

# 81. Gross movement reporting

Cash reporting should retain gross movement categories.

Example:

```text
Paid-ins        $100
Paid-outs        $80
Net external     $20
```

rather than only:

```text
Net movement $20
```

The underlying behaviors matter operationally.

---

# 82. Transfer reporting

Internal transfers should remain separately reportable by:

* source;
* destination;
* amount;
* reason/type;
* actor;
* approval;
* time.

They should not inflate organization-wide Cash inflow/outflow metrics.

---

# 83. Conceptual drawer-session model

Without locking schema:

```text
Drawer Session
│
├── id
├── store
├── workstation
├── drawer/cash_location
│
├── opened_by
├── opened_at
├── opening_float_cents
│
├── business_date/context
├── Z relationship
│
├── accepted_closing_count
├── expected_at_close_cents
├── counted_at_close_cents
├── variance_cents
│
├── closed_by
├── closed_at
│
└── status
    ├── open
    └── closed
```

Expected Cash should remain derivable rather than represented only by a mutable manually editable field.

---

# 84. Conceptual cash movement model

External movement:

```text
Cash Movement
│
├── id
├── cash location/session
├── movement_type
│   ├── paid_in
│   └── paid_out
├── amount_cents
├── reason
├── performed_by
├── occurred_at
└── approval relationship
```

Customer Cash tenders are not represented here.

---

# 85. Conceptual cash-transfer model

```text
Cash Transfer
│
├── id
├── transfer_type/context
│
├── source_cash_location
├── destination_cash_location
├── amount_cents
│
├── performed_by
├── occurred_at
├── reason
└── approval relationship
```

Convenience workflows such as `drop` and `replenishment` can use this underlying model.

---

# 86. Conceptual cash-count model

```text
Cash Count
│
├── id
├── cash location/session
├── counted_amount_cents
├── counted_by
├── counted_at
├── count_type/context
└── denomination detail optional
```

Counts are append-only observations.

---

# 87. Domain ownership

## Cash Handling owns

* physical Cash custody;
* drawer sessions;
* opening float;
* expected Cash;
* Cash counts;
* variance;
* paid-ins;
* paid-outs;
* internal Cash transfers;
* drops;
* replenishments;
* safe Cash locations;
* eventual deposit custody chain.

## Tenders owns

* customer Cash payment/refund;
* presented amount;
* applied amount;
* change.

## Reporting Periods owns

* Z lifecycle;
* business date;
* Z summaries;
* optional Store Close.

## Approvals owns

* controlled Cash-action authorization;
* variance approval/acknowledgment.

## Transactions owns

* customer sale/return financial facts.

## Reconciliation owns

* distributed/offline conflicts and stale authority.

---

# 88. Phase 5 delivery

Phase 5 implements the minimum usable Cash accountability model:

```text
one open drawer session/workstation
one opening float
Cash sale effects
expected Cash
one closing count
variance
drawer close
minimal Z
```

Required capabilities:

* open drawer;
* record opening float;
* derive expected Cash from completed Cash sales;
* record closing count;
* calculate variance;
* close drawer;
* expose result to Z.

Phase 5 explicitly excludes:

* paid-ins;
* paid-outs;
* drops;
* replenishments;
* safe custody;
* multiple drawer sessions;
* blind counts;
* recount workflow;
* accepted-count workflow;
* deposits.

---

# 89. Phase 6.5 delivery

Full Cash Handling should add:

### Multiple/sequential drawer sessions

* session history;
* custody accountability;
* richer Z relationships.

### External movements

* paid-in;
* paid-out;
* structured reasons;
* approvals.

### Internal transfers

* drops;
* replenishments;
* explicit locations;
* source/destination linkage.

### Cash locations

* drawers;
* safe(s).

### Counts

* immutable multiple observations;
* blind first count;
* recount;
* accepted count.

### Variance

* threshold policies;
* approval/acknowledgment;
* reporting.

### Correction foundation

* compensating Cash operations rather than editing completed history.

---

# 90. Deposit extension

Bank-deposit tracking may be implemented later without changing the core model.

It should build from:

```text
drawer reconciliation
        ↓
internal transfers
        ↓
safe/location custody
        ↓
deposit record
        ↓
bank reference
```

The exact financial posting/reconciliation model is deferred.

---

# 91. Pending decisions

## 91.1 Drawer identity

Define whether a physical drawer is permanently configured as its own object or initially represented as a workstation-attached Cash location.

---

## 91.2 Cashier custody model

Decide supported Phase 6 semantics for:

* cashier-owned drawer;
* shared drawer;
* cashier handoff.

Do not overload Phase 5 with this decision.

---

## 91.3 Opening float source

When safe custody exists, define whether every opening float must have a corresponding source transfer.

Recommended for the full model: **yes**.

---

## 91.4 Drawer close cash removal

Decide whether standard operations:

1. count drawer;
2. retain configured float;
3. transfer remainder to safe;

are one orchestrated workflow or separate explicit commands.

The underlying facts should remain distinct either way.

---

## 91.5 Paid-in/out reason catalogs

Define initial structured reasons before Phase 6.5.

---

## 91.6 Paid-in/out approval thresholds

Define organization/store policy for direct, approval-required, and prohibited amounts/actions.

---

## 91.7 Transfer approval

Determine whether drops/replenishments require approval based on amount/location.

---

## 91.8 Cash locations

Define initial location types and whether stores may configure multiple safes/other physical locations.

---

## 91.9 Blind-count policy

Determine:

* when first count must be blind;
* who may view expected Cash before recount;
* when second actor is required.

---

## 91.10 Variance thresholds

Define thresholds for:

```text
ordinary close
approval required
investigation/escalation
```

Approval never changes the variance itself.

---

## 91.11 Count denomination detail

Determine whether Phase 6.5 needs denomination-level count records or only total cents.

---

## 91.12 Closed-drawer corrections

Define explicit correction workflow for Cash activity discovered after drawer close.

Do not reopen and edit the closed session.

---

## 91.13 Transfer-in-transit

Only introduce an `in_transit` custody state if real workflows require delayed receipt acknowledgment.

---

## 91.14 Deposit tracking

Defer exact:

* deposit batches;
* deposit bags;
* bank references;
* deposit verification;
* bank reconciliation.

The current model must only preserve sufficient custody lineage to add them later.

---

# 92. Core invariants summary

The following rules are authoritative unless explicitly superseded:

1. **Cash Handling tracks physical Cash custody; Tenders tracks customer settlement.**
2. **Customer Cash tenders are not duplicated as generic Cash movements.**
3. **Drawer session and Z are separate concepts.**
4. **Initial POS allows at most one open drawer session per workstation.**
5. **Opening float establishes starting expected Cash and is not revenue.**
6. **Expected Cash is derived from authoritative Cash activity.**
7. **Cash presented does not determine drawer expectation; Cash applied does.**
8. **Cash refunds reduce expected Cash through their tender facts.**
9. **Paid-ins and paid-outs are external Cash movements, not customer tenders.**
10. **Internal transfers move Cash between locations and do not create/destroy store Cash.**
11. **Cash drops are internal transfers out of drawers, not expenses.**
12. **Replenishments are internal transfers into drawers, not revenue.**
13. **A transfer is one logical linked fact, not unrelated paid-out/paid-in records.**
14. **Cash counts are independent physical observations.**
15. **A count does not create a Cash movement.**
16. **Variance equals counted minus expected.**
17. **Variance is never automatically erased with a balancing movement.**
18. **Approving variance does not change expected, counted, or variance.**
19. **Recounts create new immutable count observations.**
20. **An accepted closing count may reference one of several historical counts.**
21. **A closed drawer session is immutable.**
22. **Closing the drawer does not itself move physical Cash.**
23. **Physical removal after close requires a transfer/movement fact.**
24. **Expected-Cash projections should be rebuildable from authoritative Cash facts.**
25. **Completed Cash operations require stable identity and idempotent synchronization.**
26. **Offline operation preserves original occurrence and actor facts.**
27. **Cash variance is not inherently a distributed synchronization conflict.**
28. **Z may summarize Cash Handling but does not own Cash custody facts.**
29. **A Z cannot finalize while required Cash accountability remains open.**
30. **Store Close does not move or deposit Cash.**
31. **Drawer reconciliation remains independently identifiable for future deposit traceability.**
32. **Bank-deposit tracking can be deferred without weakening the drawer-reconciliation model.**
33. **Corrections use new compensating facts rather than editing completed Cash history.**

---

# 93. Acceptance examples

## Example A — opening float and Cash sale

Given:

```text
Opening float = $100
```

and a completed Cash sale:

```text
Cash applied = $17.24
Cash presented = $20
Change = $2.76
```

then:

```text
Expected Cash = $117.24
```

not `$120`.

---

## Example B — Cash refund

Given:

```text
Opening/current expected = $200
Cash refund applied = $25
```

then:

```text
Expected Cash = $175
```

No separate `$25` paid-out is created.

---

## Example C — paid-out

Given:

```text
Expected Cash before paid-out = $500
Paid-out = $40
```

then:

```text
Expected Cash = $460
```

The paid-out is reported independently from customer refunds.

---

## Example D — drawer drop

Given:

```text
Drawer expected = $1,000
```

and:

```text
Transfer:
Drawer → Safe
$600
```

then:

```text
Drawer expected = $400
Safe expected increases by $600
Store total Cash unchanged
```

The `$600` is not an expense.

---

## Example E — replenishment

Given a transfer:

```text
Safe → Drawer
$50
```

then:

```text
Drawer expected +$50
Safe expected -$50
Store total Cash unchanged
```

---

## Example F — shortage

Given:

```text
Expected = $500
Counted  = $498
```

then:

```text
Variance = -$2
```

ShelfSense does not automatically post a `$2` balancing movement.

---

## Example G — overage

Given:

```text
Expected = $500
Counted  = $503
```

then:

```text
Variance = +$3
```

The drawer is `$3 over`.

The count itself does not increase expected Cash.

---

## Example H — manager accepts variance

Given:

```text
Expected = $500
Counted  = $480
Variance = -$20
```

and policy requires manager approval,

when Manager B approves the close,

then the historical result remains:

```text
Expected = $500
Counted  = $480
Variance = -$20
```

with approval evidence attached.

---

## Example I — recount

Given first count:

```text
$480
```

and second count:

```text
$500
```

then:

* both counts remain historical;
* the close may identify `$500` as the accepted count;
* the `$480` observation is not edited or deleted.

---

## Example J — close does not remove Cash

Given a closing count of:

```text
$500
```

when the drawer session closes,

then ShelfSense does not assume `$500` left the drawer.

A later transfer must explain any physical removal.

---

## Example K — retain float and transfer excess

Given:

```text
Closing counted Cash = $500
Desired retained float = $100
```

then a later/full workflow may create:

```text
Drawer → Safe transfer = $400
```

The count and transfer remain separate facts.

---

## Example L — paid-out versus drop

Given `$100` leaves a drawer:

### Case 1

Cash is spent externally for an authorized store purpose:

```text
paid_out = $100
```

Store physical Cash decreases.

### Case 2

Cash moves to the office safe:

```text
transfer Drawer → Safe = $100
```

Store physical Cash is unchanged.

ShelfSense must not represent both as the same movement type.

---

## Example M — offline close

Given the workstation has no server connectivity,

when:

* Cash transactions have completed locally;
* Cash is counted;
* required variance approval is available locally;

then the drawer may close using local authoritative facts.

The completed drawer reconciliation synchronizes later.

---

## Example N — retry after lost acknowledgment

Given a completed `$50` paid-out synchronizes successfully but the response is lost,

when the workstation retries the same operation,

then central state must contain one `$50` paid-out effect, not `$100`.

---

## Example O — future deposit traceability

Given:

```text
Drawer Session A closing reconciliation
Counted = $500

Transfer Drawer A → Safe = $400
```

a future Deposit workflow can include that Cash through subsequent custody facts without modifying the original drawer session or Z.

---

# 94. Related workflows

This specification should eventually be referenced by:

* `workflows/cash/drawer-open.md`
* `workflows/cash/drawer-close.md`
* `workflows/cash/paid-in.md`
* `workflows/cash/paid-out.md`
* `workflows/cash/cash-drop.md`
* `workflows/cash/replenishment.md`
* `workflows/cash/safe-count.md`
* `workflows/cash/cash-transfer.md`
* `workflows/reporting/run-z.md`
* future `workflows/cash/prepare-deposit.md`

---

# 95. Related contracts

Cash Handling will eventually require exact contracts for:

### Expected Cash

```text
opening float
+ Cash payment tenders
- Cash refund tenders
+ paid-ins
- paid-outs
+ transfers in
- transfers out
→ expected Cash
```

### Drawer reconciliation

```text
expected Cash
counted Cash
→ variance
```

with:

```text
variance = counted - expected
```

### Counts

Exact representation of:

* count identity;
* location/session;
* amount;
* actor;
* time;
* accepted-count relationship.

### Cash movements

Exact representation for:

* paid-in;
* paid-out;
* reasons;
* authorization context.

### Transfers

Exact source/destination conservation and idempotency semantics.

### Completed Cash operation synchronization

Define operation identity, payload version, actor/time context, and central acceptance.

### Future deposits

When implemented, define custody lineage from:

```text
drawer reconciliation
→ transfer
→ safe
→ deposit
```

without redefining historical drawer facts.

The Cash Handling domain defines **where physical Cash is expected to be, what staff actually observed, and why Cash moved between custody locations**.

Tenders explain customer settlement; Reporting Periods summarize register activity; future deposit/accounting workflows can build on the resulting immutable custody chain.
