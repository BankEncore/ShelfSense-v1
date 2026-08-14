# POS Domain Specification: Tenders

**Design status:** Core tender model, settlement rules, Cash behavior, external Card boundary, and Stored Value authority decided; processor-specific and advanced refund policies remain pending
**Implementation status:** Cash foundation required in Phase 4; first operational delivery in Phase 5; additional tenders in Phase 6
**Initial foundation:** Phase 4 — POS Runtime and Contract Foundation
**First operational delivery:** Phase 5 — First Operational Cash Sale
**Expanded delivery:** Phase 6.2 — Launch Tender Breadth and later return/refund workflows
**Related specifications:** Transactions, Transaction Lines, Pricing, Discounts, Tax, Returns, Cash Handling, Approvals, Receipts, Local Persistence, Reference Replication, Operation Synchronization, Reconciliation
**Related workflows:** Cash Sale, Cash Refund, Card Payment, Check Payment, Mixed Tender, Linked Return, Exchange

---

## 1. Purpose

This specification defines how ShelfSense POS represents settlement of a transaction.

It establishes:

* what a tender represents;
* the distinction between transaction value and settlement;
* payment versus refund direction;
* tender categories and configurable tender types;
* Cash applied, presented, and change;
* multiple and mixed tenders;
* Card processor boundaries;
* Check behavior;
* Stored Value authority;
* Other tender use;
* offline behavior;
* completion and immutability;
* return/refund relationships;
* Cash Handling integration.

This specification does **not** define:

* what merchandise was sold;
* price or discount calculation;
* tax calculation;
* physical Cash custody beyond tender effects;
* Card processor protocol;
* gift-card account implementation;
* return eligibility;
* accounting/GL posting.

Those belong to their owning specifications and domains.

---

## 2. Governing principle

Transaction lines determine the economic obligation.

Tenders describe how that obligation is settled.

```text
Transaction lines
    ↓
pricing / discounts / tax
    ↓
signed transaction net
    ↓
tenders
    ↓
settled transaction
```

> **A tender is a positive-valued, explicitly directed settlement fact associated with a POS transaction.**

A tender does not describe what was sold and does not change merchandise pricing.

---

## 3. Transaction net

The completed transaction has a signed net amount.

Conceptually:

```text
sale activity      → positive amount owed by customer
return activity    → negative amount owed to customer
```

Mixed transactions such as exchanges may contain both sale and return lines.

Example:

```text
Sale lines      $50.00
Return lines   -$20.00
----------------------
Net due         $30.00
```

Tenders settle the resulting `$30.00` obligation.

They do not independently reconstruct the gross sale and return activity.

---

## 4. Tender direction

Tender values are stored as positive monetary amounts.

Direction states whether value moves:

```text
payment
→ customer to merchant
```

or:

```text
refund
→ merchant to customer
```

ShelfSense should not rely on negative tender amounts to represent refunds.

For example:

```text
direction = refund
amount = $20.00
```

rather than:

```text
amount = -$20.00
```

This keeps value and direction explicit.

---

## 5. Settlement equation

A transaction is settled when the net effect of its completed tenders equals the signed transaction net.

Conceptually:

```text
payments
-
refunds
=
transaction net
```

For a `$30.00` sale:

```text
payments = $30.00
refunds  = $0.00
net      = $30.00
```

For a `$20.00` return:

```text
payments = $0.00
refunds  = $20.00
net      = -$20.00
```

For a mixed exchange with `$10.00` due:

```text
payments = $10.00
refunds  = $0.00
net      = $10.00
```

No artificial zero-dollar tender is required.

---

## 6. Tender amount

The tender's primary amount is the amount **applied to settlement**.

This is distinct from quantities such as:

* Cash presented;
* Cash change;
* Card authorization amount where processor behavior requires additional context;
* Check face/document information.

The applied amount is the value used in the transaction settlement equation.

---

## 7. Tender categories

ShelfSense defines five behavioral tender categories:

```text
Cash
Card
Check
Stored Value
Other
```

These categories describe core settlement behavior.

They are not necessarily the exact names shown to cashiers or customers.

---

## 8. Configurable tender types

A tender type is centrally configured and belongs to one behavioral category.

Examples:

```text
Cash
    └── Cash

Card
    ├── Credit/Debit
    └── External Card Terminal

Check
    └── Check

Stored Value
    ├── Gift Card
    └── Store Credit

Other
    └── Approved external settlement method
```

The exact set may vary by organization/store.

The behavioral category remains stable so POS knows how the tender must be handled.

---

## 9. Tender configuration is reference data

Tender configuration is centrally mastered and replicated to the POS.

Reference data may include:

* tender type ID;
* display name;
* category;
* active state;
* store availability;
* payment/refund eligibility;
* other behavior required for offline selection.

Completed transactions preserve the tender facts/configuration context actually used.

Later changes to tender configuration do not rewrite historical transactions.

---

# Cash

## 10. Cash tender

Cash tender represents physical currency exchanged directly with the customer.

For Cash payments, ShelfSense distinguishes:

```text
amount applied
amount presented
change
```

These are not interchangeable.

---

## 11. Cash presented and change

Example:

```text
Transaction total   $17.24
Cash presented      $20.00
Cash applied        $17.24
Change               $2.76
```

The settlement amount is:

```text
$17.24
```

not:

```text
$20.00
```

The customer handed the cashier `$20.00`, but only `$17.24` settled the transaction.

---

## 12. Cash equation

For a normal Cash payment:

```text
presented
=
applied
+
change
```

Example:

```text
$20.00
=
$17.24
+
$2.76
```

Cash change is customer-facing settlement context, not another refund tender.

---

## 13. Cash drawer effect

Cash Handling uses the Cash **applied** amount for customer-settlement custody effects.

For the example above:

```text
drawer effect = +$17.24
```

not:

```text
+$20.00
```

The `$2.76` change is already represented by the difference between presented and applied.

ShelfSense must not double-count change as both:

* a negative Cash movement;
* and a reduction from the tendered amount.

---

## 14. Cash refunds

A completed Cash refund reduces expected drawer Cash by the refund amount.

Example:

```text
direction = refund
applied = $15.00
```

produces the customer-settlement Cash effect:

```text
-$15.00
```

Cash Handling must not also create an unrelated `paid_out` for the same customer refund.

Customer Cash refunds and operational Cash paid-outs are different facts.

---

## 15. Cash overpayment

Cash may allow presented value greater than the remaining amount due because change can be returned.

Other tender categories normally apply only the amount used to settle the obligation unless their owning integration explicitly provides otherwise.

---

# Card

## 16. Card tender

Card represents settlement performed through an external payment processor.

ShelfSense is not initially the Card processor.

Conceptually:

```text
ShelfSense POS
    ↓
external processor interaction
    ↓
processor outcome
    ↓
completed Card tender fact
```

Processor interaction and POS transaction completion are separate technical boundaries that must be coordinated deliberately.

---

## 17. Sensitive Card data

ShelfSense must not require storage of:

* full PAN;
* CVV;
* other prohibited sensitive authentication data.

Where operationally useful and permitted, the completed tender may preserve non-sensitive processor references such as:

* processor transaction/reference ID;
* authorization result/reference;
* card brand;
* masked account display information;
* terminal/device reference.

Exact fields depend on the selected processor integration.

---

## 18. Card external-state problem

Card creates a durability problem that Cash does not.

For example:

```text
processor approves payment
        ↓
POS crashes before local sale commit
```

The processor may now contain an approved financial event without a completed ShelfSense transaction.

Therefore Card workflows require durable handling of unresolved external processor state.

ShelfSense must not assume:

```text
failed local commit
=
processor authorization never happened
```

The exact Card state machine belongs to the Card workflow/contract.

---

## 19. Offline Card behavior

Ordinary Card processing should not be assumed to work offline merely because ShelfSense itself can operate offline.

Offline Card authorization depends on processor capabilities and organizational policy.

Until such capability is explicitly designed and approved:

> **Card requires the external processor path to be available.**

The POS may still perform other offline-supported tender types.

---

# Check

## 20. Check tender

Check represents settlement using a customer check.

The initial model may remain simple.

A completed Check tender may preserve appropriate operational information such as:

* amount;
* payment/refund direction where allowed;
* optional check/reference number;
* tender type;
* actor/time.

ShelfSense does not need to model check-clearing banking workflows as part of POS completion.

---

## 21. Check acceptance policy

Whether Check is:

* enabled;
* permitted for refund;
* subject to identification or approval;
* limited by amount;

belongs to tender configuration/approval policy.

Tender describes the completed settlement fact after those policies have been satisfied.

---

# Stored Value

## 22. Stored Value tender

Stored Value represents settlement against an account or instrument whose remaining balance is maintained by ShelfSense or another authoritative shared service.

Examples include:

* gift card;
* store credit.

Stored Value differs materially from Cash or Check because spending changes a shared balance.

---

## 23. Shared balance authority

Stored Value requires authoritative balance control.

Conceptually:

```text
Stored Value Account
balance = $50

POS redemption = $20

new authoritative balance = $30
```

Two disconnected workstations must not independently assume the same `$50` can be spent.

Therefore:

> **ShelfSense must not permit speculative offline Stored Value redemption unless a concrete conflict-safe authority mechanism is designed.**

---

## 24. Stored Value offline behavior

Initial Stored Value redemption should require access to its authoritative balance service.

Potential future offline support would require an explicit mechanism such as:

* delegated spend authority;
* preallocated offline balance;
* another bounded conflict-safe design.

It must not be added simply by caching the last-known balance.

---

## 25. Stored Value issuance versus tender

Issuing or increasing Stored Value is not necessarily the same domain operation as redeeming it as tender.

For example:

```text
sell gift card
→ create/increase stored-value liability

redeem gift card
→ use Stored Value tender
```

The future Stored Value domain should own account balance semantics.

Tenders owns how an authoritative Stored Value result settles a POS transaction.

---

# Other

## 26. Other tender

`Other` is for genuine settlement methods that do not fit Cash, Card, Check, or Stored Value.

It must not become:

```text
miscellaneous adjustment
```

or:

```text
make transaction balance somehow
```

A configured Other tender must represent actual value exchanged or an externally recognized settlement mechanism.

---

## 27. Other is not a balancing mechanism

ShelfSense must not provide an unrestricted Other tender solely to force:

```text
remaining balance = 0
```

when a transaction otherwise does not reconcile.

Financial discrepancies should be resolved through the appropriate business workflow rather than hidden as a fake tender.

---

# Multiple tenders

## 28. Zero or more tender records

The transaction structure should support:

```text
0..N tenders
```

rather than assuming one tender per transaction.

This supports:

* mixed tender;
* even exchanges with no settlement;
* future workflows where settlement is deferred or externally handled.

A completed ordinary sale with an amount due still must satisfy its settlement rules.

---

## 29. Mixed tender

Multiple tender types may settle one transaction.

Example:

```text
Transaction total     $75.00

Stored Value          $20.00
Card                  $45.00
Cash                  $10.00
----------------------------
Total applied         $75.00
```

Each tender remains a distinct completed fact.

ShelfSense should not collapse them into one synthetic payment.

---

## 30. Tender order

Tender application order may matter operationally.

For example:

```text
Stored Value first
Card second
Cash last
```

may differ from another sequence where external authorizations are involved.

Where meaningful, ShelfSense should preserve tender ordering as part of completed settlement history.

---

## 31. Remaining balance

While tendering, the POS calculates the remaining amount to settle from authoritative transaction and tender state.

Conceptually:

```text
remaining balance
=
transaction net
-
net applied tenders
```

The customer display and cashier UI consume that calculated value.

They do not independently calculate settlement.

---

# Returns and refunds

## 32. Return value and refund tender are separate

A return line determines the value owed to the customer.

The refund tender describes **how ShelfSense satisfies that obligation**.

Example:

```text
Return value      $20.00
Refund tender:
Card              $20.00
```

Changing refund method does not change the historical merchandise return value.

---

## 33. Refund policy

Returns owns return eligibility and historical reversal.

Tender/refund policy determines which settlement methods may be used for the resulting refund.

Possible policies may include:

* original tender required;
* Cash permitted;
* Stored Value required;
* alternate tender with approval.

These policies must be explicit rather than inferred from tender category alone.

---

## 34. Linked returns

A linked return preserves historical transaction economics.

Its refund tender is a new completed settlement fact on the return transaction.

It does not edit or remove the tender used on the original sale.

Example:

```text
Original Sale
Card payment        $25.00

Later Return
Card refund         $25.00
```

Both tender facts remain historical.

---

## 35. Exchanges

An exchange may contain both sale and return activity in one transaction.

Tender applies only to the resulting net obligation.

Example:

```text
Return             -$20.00
New merchandise     $30.00
--------------------------
Net due              $10.00

Cash payment         $10.00
```

The receipt/reporting layers should still preserve gross sale and return activity.

---

## 36. Even exchange

If:

```text
sale value = return value
```

the transaction net may be zero.

No zero-dollar tender is required simply to indicate settlement.

The transaction is already financially balanced.

---

# Completion and immutability

## 37. Tender is mutable before completion

While the transaction remains open, the cashier may add, remove, or replace tender attempts according to workflow rules.

However, external processor states may impose additional correction requirements.

The working transaction remains mutable until completion.

---

## 38. Completed tenders are immutable

When the transaction completes, its tender facts become immutable.

Completed tender history preserves:

* tender type/category;
* direction;
* applied amount;
* Cash presented/change where applicable;
* processor/reference context where applicable;
* actor/time;
* ordering/context required for reporting and refund policy.

A completed tender is not edited later to correct a transaction.

---

## 39. Tender corrections use new facts

If a completed settlement must be corrected, ShelfSense uses an explicit reversal/refund/corrective operation according to the relevant workflow.

Incorrect:

```text
edit old Card tender
$25 → $20
```

Preferred:

```text
preserve original $25 tender
+
record corrective financial fact
```

Exact post-completion correction behavior remains dependent on the tender category and processor.

---

## 40. Local completion

Cash and other locally authoritative tender types may participate directly in the atomic local transaction-completion commit.

For the Phase 5 Cash sale:

```text
BEGIN

transaction
lines
pricing/tax
Cash tender
receipt identity
outbox

COMMIT
```

Only after commit does ShelfSense report the transaction completed.

---

## 41. External tender completion

Tender types involving an external authority require a workflow that reconciles:

```text
external settlement state
```

with:

```text
local durable transaction state
```

ShelfSense must never pretend those two commits are one database transaction.

The workflow must explicitly handle failures between them.

---

# Offline and synchronization behavior

## 42. Offline authority varies by tender category

Offline support is a property of the tender's authority model.

### Cash

Can be completed fully offline.

### Check

May be locally accepted offline if organizational policy permits.

### Card

Depends on external processor capability; not assumed offline.

### Stored Value

Requires authoritative shared balance; speculative offline redemption is not initially allowed.

### Other

Depends on the configured settlement mechanism.

---

## 43. Completed tenders synchronize as historical facts

For locally completed tenders, synchronization transfers the already completed tender facts to the organization server.

Rails does not choose a new tender or recalculate what the customer paid.

Synchronization preserves:

* tender identity;
* type/category;
* direction;
* amount;
* relevant Cash/external context;
* originating transaction.

---

## 44. Idempotency

Retrying the same completed transaction operation must not create another central tender effect.

For example:

```text
Operation O
Cash $20
```

submitted twice still creates one central Cash tender fact.

Operation Synchronization owns the transport/idempotency mechanism.

---

## 45. Stale tender configuration

A workstation may complete an offline-supported tender using the most recent configuration it had locally.

If the tender type was later disabled centrally while the workstation was offline, synchronization preserves what happened.

Authorization/Reconciliation policy determines whether the stale use:

* is accepted;
* generates a warning;
* requires investigation.

The completed tender is not silently replaced with another type.

---

# Cash Handling integration

## 46. Tender settlement versus Cash custody

Cash tender and Cash Handling must remain distinct.

```text
Tenders
→ how customer obligation was settled

Cash Handling
→ where physical Cash is expected to be
```

A completed Cash tender contributes to Cash expected-balance calculations.

It does not create a separate generic Cash movement.

---

## 47. Cash movements are not tenders

Operational events such as:

* opening float;
* paid-in;
* paid-out;
* drop;
* replenishment;
* internal transfer;

do not settle a customer's transaction.

They therefore are not tenders.

Cash Handling owns them.

---

# Receipts and reporting

## 48. Receipt presentation

Receipts consume completed tender facts.

For Cash:

```text
Cash             $17.24
Tendered         $20.00
Change            $2.76
```

For mixed tender:

```text
Store Credit     $20.00
Card             $30.00
Cash             $10.00
```

Receipt rendering does not recalculate settlement.

---

## 49. Z and reporting

Z/reporting should summarize completed tenders by meaningful dimensions such as:

* tender type;
* category;
* payment versus refund;
* applied amount.

Cash reporting additionally integrates with Cash Handling expected balances.

Reporting should not use Cash presented as Cash revenue.

---

# Domain ownership

## 50. Tenders owns

* tender identity;
* tender type/category;
* payment/refund direction;
* applied settlement amount;
* Cash presented/change;
* mixed-tender representation;
* completed tender immutability;
* tender-specific settlement facts.

## Transactions owns

* transaction lifecycle;
* signed net amount to be settled;
* completion.

## Pricing / Discounts / Tax owns

* the commercial calculations that produce the transaction net.

## Returns owns

* return eligibility;
* historical return value;
* exchange structure.

## Cash Handling owns

* physical Cash custody;
* drawer expected/count/variance;
* non-customer Cash movements.

## Approvals owns

* authorization of controlled tender/refund exceptions.

## Reference Replication owns

* tender configuration distribution.

## Local Persistence owns

* durable local tender state and atomic completion.

## Operation Synchronization owns

* delivery/idempotency of completed tender facts.

## Reconciliation owns

* conflicts or stale-authority conditions discovered centrally.

---

# Phase delivery

## 51. Phase 4

Phase 4 should establish the tender calculation/contract foundation sufficient to prove a representative Cash sale.

Required:

* tender category/type representation;
* payment/refund direction structure;
* Cash applied/presented/change semantics;
* deterministic settlement validation;
* local durable Cash tender;
* completed-sale payload representation.

No broad cashier tender UI is required.

---

## 52. Phase 5

Phase 5 implements the first operational tender path:

```text
Cash
```

The cashier can:

```text
enter amount presented
↓
POS calculates Cash applied/change
↓
complete transaction locally
↓
Cash tender commits atomically
↓
receipt shows tender/change
↓
drawer expectation updates
```

Phase 5 does not require:

* Card;
* Check;
* Stored Value;
* Other;
* mixed tender.

---

## 53. Phase 6.2

Phase 6.2 expands launch tender breadth with:

* Card through external processor;
* Check;
* Other;
* mixed tender.

Stored Value should be implemented only after its shared balance authority is explicitly defined.

---

## 54. Phase 6.4

Return/refund implementation adds:

* refund tender direction;
* original-tender policy;
* alternate refund policy;
* mixed exchange settlement;
* processor-specific refund behavior.

These must align with `returns.md`.

---

# Pending decisions

## 55. Exact tender type configuration

Define fields such as:

* payment allowed;
* refund allowed;
* offline allowed;
* amount limits;
* approval requirements.

Avoid making the tender configuration into a generic business-rules engine.

---

## 56. Card processor contract

Before Card delivery, define:

* processor integration boundary;
* authorization/capture model;
* crash recovery;
* unresolved authorization state;
* reversal/void behavior;
* processor references retained by ShelfSense.

---

## 57. Check metadata

Determine whether ShelfSense needs durable fields beyond amount/type, such as:

* check number;
* identification reference;
* verification result.

Add only fields required by actual operations.

---

## 58. Stored Value domain

Define:

* account identity;
* authoritative balance;
* issuance;
* redemption;
* refund;
* expiration/restriction policy;
* offline authority.

before enabling Stored Value tender.

---

## 59. Other tender controls

Define which real external settlement methods justify use of the `Other` category and what configuration/approval is required.

---

## 60. Refund tender policy

Finalize with Returns:

* original-tender requirements;
* Cash refund restrictions;
* alternate refund authorization;
* Card refund behavior;
* Stored Value refund behavior.

---

# Core invariants

1. **Transaction lines determine what is owed; tenders determine how the net obligation is settled.**
2. **Tender amounts are positive; payment/refund direction is explicit.**
3. **Net payments minus net refunds must reconcile to the transaction net at completion.**
4. **Tender type and behavioral category are separate concepts.**
5. **The five core tender categories are Cash, Card, Check, Stored Value, and Other.**
6. **A transaction structurally supports zero or more tender records.**
7. **Mixed tenders remain distinct completed tender facts.**
8. **Cash applied, Cash presented, and change are distinct values.**
9. **Cash applied—not Cash presented—is the settlement amount and customer-tender drawer effect.**
10. **Change is not a separate refund tender or generic Cash movement.**
11. **Cash refunds reduce expected drawer Cash through the refund tender and are not duplicated as paid-outs.**
12. **Card settlement is externally processed; ShelfSense does not require prohibited sensitive Card data.**
13. **External processor state and local transaction state require explicit failure/recovery handling.**
14. **Card offline capability is not assumed.**
15. **Stored Value uses an authoritative shared balance and is not redeemed speculatively from a stale cached balance.**
16. **Other tender represents genuine settlement and is not a balancing adjustment.**
17. **Return value and refund method are separate concerns.**
18. **Even exchanges require no artificial zero-dollar tender.**
19. **Completed tenders are immutable historical facts.**
20. **Post-completion corrections use new facts rather than editing completed tenders.**
21. **Locally authoritative tenders participate in the atomic local completion commit.**
22. **Synchronization preserves completed tender facts rather than recalculating settlement.**
23. **Retrying a completed operation never creates duplicate central tender effects.**
24. **Cash tender and Cash Handling are distinct domains.**
25. **Opening floats, paid-ins, paid-outs, drops, replenishments, and transfers are Cash Handling facts, not tenders.**
26. **Receipts and reporting consume completed tender facts; they do not independently calculate them.**

---

# Acceptance examples

## Example A — exact Cash

Given:

```text
Transaction total = $17.24
```

when the cashier receives `$17.24`,

then:

```text
Cash presented = $17.24
Cash applied   = $17.24
Change         = $0.00
```

and the transaction is fully settled.

---

## Example B — Cash with change

Given:

```text
Transaction total = $17.24
Cash presented    = $20.00
```

then:

```text
Cash applied = $17.24
Change       = $2.76
```

Cash Handling receives a customer-tender drawer effect of `+$17.24`.

---

## Example C — Cash refund

Given a completed return creates:

```text
$15.00 due to customer
```

and policy permits Cash refund,

then:

```text
direction = refund
Cash applied = $15.00
```

reduces expected drawer Cash by `$15.00`.

No separate paid-out is created.

---

## Example D — mixed tender

Given:

```text
Transaction total = $75.00
```

when the customer settles with:

```text
Stored Value = $20.00
Card         = $45.00
Cash         = $10.00
```

then all three tenders remain separate facts whose applied values total `$75.00`.

---

## Example E — partial tender

Given:

```text
Transaction total = $50.00
Card applied      = $30.00
```

then:

```text
remaining due = $20.00
```

The transaction cannot complete as fully settled until an allowed workflow accounts for the remaining `$20.00`.

---

## Example F — even exchange

Given:

```text
Returned merchandise = $20.00
Purchased merchandise = $20.00
```

then:

```text
transaction net = $0.00
```

No tender is required.

The completed transaction may have zero tender records.

---

## Example G — exchange with amount due

Given:

```text
Return = $20.00
Sale   = $30.00
```

then:

```text
transaction net = $10.00
```

A `$10.00` Cash payment settles the exchange.

Tenders does not hide the gross `$20` return and `$30` sale.

---

## Example H — Card processor approves before local failure

Given the external Card processor approves `$30.00`,

when the POS fails before its local transaction commits,

then ShelfSense does not assume the processor transaction disappeared.

The Card workflow enters the defined external-state recovery path.

---

## Example I — Stored Value while offline

Given the POS last knew:

```text
Gift Card balance = $50.00
```

and the authoritative Stored Value service is unavailable,

then ShelfSense does not permit an ordinary `$40.00` redemption solely on the cached balance.

The same balance may have been consumed elsewhere.

---

## Example J — synchronization retry

Given an offline Cash sale with:

```text
Cash applied = $20.00
```

has already synchronized,

when the same operation is delivered again,

then ShelfSense does not create another `$20.00` tender centrally.

---

## Example K — stale tender configuration

Given Check was locally enabled when the workstation went offline,

when it later completes a permitted Check sale and discovers during synchronization that Check had since been centrally disabled,

then the completed historical tender remains Check.

Policy/Reconciliation determines whether the stale use requires further action.

---

# Related contracts

Tenders should eventually be supported by exact contracts for:

## Cash settlement

Defines deterministic calculation of:

```text
amount due
cash presented
cash applied
change
remaining balance
```

## Completed Sale Operation

Defines completed tender representation, including:

```text
tender_id
tender_type_id
category
direction
applied_amount
presented/change when applicable
ordering
external reference context when applicable
```

## Card integration

Defines the relationship between:

```text
processor operation
local tender state
transaction completion
recovery/reversal
```

## Stored Value

Defines authoritative balance reservation/redemption and its relationship to POS tender completion.

---

The Tender domain defines **how a completed transaction's economic obligation is settled**.

Its key boundary is:

> **The transaction determines how much is owed. Tenders record how that amount was paid or refunded. Cash Handling, payment processors, and Stored Value services then own the physical or external value systems behind those settlement facts.**
