# POS Domain Specification: Receipts

**Design status:** Core receipt identity, assignment, rendering, and reprint semantics decided
**Implementation status:** Initial paper receipt delivery in Phase 5; broader rendering/delivery and replacement safeguards in Phase 6B
**Initial delivery:** Phase 5 — First Operational Cash Sale
**Expanded delivery:** Phase 6B — POS Productization
**Related specifications:** Transactions, Transaction Lines, Pricing, Discounts, Tax, Tenders, Returns, Reporting Periods, Workstation Identity, Local Persistence, Operation Synchronization
**Related workflows:** Complete Transaction, Receipt Printing, Receipt Reprint, Linked Return, Exchange, Workstation Replacement

---

## 1. Purpose

This specification defines the ShelfSense POS receipt domain.

It establishes:

* receipt identity;
* receipt-number scope;
* when receipt identity is assigned;
* offline receipt assignment;
* relationship between receipt and transaction identity;
* receipt sequence behavior;
* historical receipt rendering;
* printing and delivery behavior;
* print failure semantics;
* reprints;
* return and exchange receipts;
* relationships to workstation replacement, Z reporting, and synchronization.

This specification does **not** define:

* printer drivers or hardware protocols;
* detailed receipt visual design;
* exact receipt-number display formatting;
* workstation replacement sequence-recovery algorithms;
* electronic delivery implementation;
* legal receipt-content requirements for particular jurisdictions.

Those belong to narrower specifications, contracts, workflows, or productization work.

---

# 2. Governing principle

A ShelfSense receipt is the permanent human-facing identity and customer presentation of a completed POS transaction.

> **Receipt identity is assigned locally and atomically at transaction completion from a workstation-scoped monotonic sequence, remains unchanged through synchronization or reprinting, and is rendered from immutable completed transaction facts.**

Printing or other receipt delivery occurs only after transaction completion.

Delivery failure never changes the completed transaction.

---

# 3. Receipt identity and transaction identity are separate

Every POS transaction has a distributed technical identity.

Conceptually:

```text
transaction_id = UUIDv7
```

A completed transaction also receives a human-facing receipt identity.

These serve different purposes.

```text
Transaction ID
→ distributed/system identity

Receipt identity
→ customer/cashier/operational identity
```

Receipt number must not be used as the technical primary identity of the transaction.

---

# 4. Receipt identity components

The underlying receipt identity is scoped by:

```text
store
+
logical workstation
+
workstation receipt sequence
```

Conceptually:

```text
Store 01
Workstation 02
Receipt sequence 4814
```

The exact printed representation is a presentation concern.

Possible formats could later include:

```text
01-02-0004814
```

or:

```text
Store 01
Register 02
Receipt 4814
```

without changing the underlying identity.

---

# 5. Receipt sequence belongs to the logical workstation

Receipt sequence is owned by the logical workstation defined by Workstation Identity.

It is **not** owned by:

* installation;
* cashier;
* drawer session;
* Z report;
* business date.

Example:

```text
Front Register 1

Receipt 4812
Receipt 4813
Receipt 4814
```

If the workstation's POS installation is replaced, the receipt namespace remains associated with Front Register 1.

---

# 6. Installation replacement does not create a new receipt namespace

Given:

```text
Workstation W1
Installation A
```

is replaced by:

```text
Workstation W1
Installation B
```

then:

```text
workstation identity = unchanged
receipt namespace = unchanged
installation identity = changed
```

Receipt history remains continuous under the logical workstation.

The exact sequence-recovery algorithm for replacement is deferred.

---

# 7. Receipt identity is assigned only at completion

An open or suspended transaction does not have a permanent receipt identity merely because work has begun.

Before completion it has its technical transaction identity.

Conceptually:

```text
Open Transaction
├── transaction_id
└── no permanent receipt number
```

At successful completion:

```text
validate transaction
        ↓
allocate receipt sequence
        ↓
freeze completed facts
        ↓
commit transaction
+
receipt identity
+
outbox
```

Receipt assignment is part of the completion boundary.

---

# 8. Cancelled transactions do not require completed receipt identities

A transaction that is cancelled before successful completion does not produce a customer financial receipt.

It therefore does not require a completed receipt identity.

Whether an attempted sequence allocation can occasionally produce a sequence gap is an implementation concern.

ShelfSense values safety and uniqueness over gapless numbering.

---

# 9. Receipt assignment is local

Receipt identity must be assignable without central connectivity.

The workstation must not require:

```text
POST /next_receipt_number
```

to complete a sale.

Instead, the POS maintains sufficient durable local workstation sequence state to allocate the receipt as part of the same local transaction that commits the completed sale.

---

# 10. Receipt assignment is atomic with transaction completion

The completion invariant is:

```text
completed transaction
⇔
permanent receipt identity assigned
```

For a normal completed POS transaction, ShelfSense must not produce:

```text
completed transaction
without receipt identity
```

or:

```text
permanent completed receipt
without completed transaction
```

The relevant transaction facts, receipt identity, and outbound synchronization record commit together.

---

# 11. Receipt identity exists before printing

A completed transaction's receipt identity exists immediately after successful database commit.

Physical printing is a subsequent action.

Therefore:

```text
COMMIT
    ↓
receipt exists
    ↓
print
```

not:

```text
print
    ↓
commit
```

---

# 12. Printing occurs after commit

Printer and drawer peripheral actions happen only after the completed transaction has been durably committed.

Conceptually:

```text
BEGIN SQLITE

validate completion
assign receipt identity
freeze transaction
write outbox

COMMIT

print receipt
open cash drawer
```

Peripheral actions are not part of the financial transaction commit.

---

# 13. Print failure does not roll back the sale

Example:

```text
transaction commits
receipt identity assigned
printer jams
```

The result is:

```text
transaction = completed
receipt = valid
printing = failed
```

not:

```text
transaction = reopened
```

or:

```text
sale = cancelled
```

The receipt can be printed again from completed historical facts.

---

# 14. Receipt exists independently of delivery

The domain concept of receipt is not identical to a piece of paper.

Conceptually:

```text
Completed Transaction
        ↓
Receipt representation
        ↓
Delivery channel
```

Initial delivery:

```text
paper print
```

Future delivery may include:

```text
email
electronic account history
other supported customer delivery
```

All channels represent the same completed receipt facts.

---

# 15. Receipt rendering

Receipt rendering is a presentation of immutable completed transaction facts.

The renderer consumes completed facts; it does not calculate financial results independently.

Incorrect:

```text
receipt renderer
→ look up current tax rule
→ recalculate tax
```

Correct:

```text
completed tax facts
→ receipt renderer
→ display completed tax
```

---

# 16. Historical receipt rendering

A historical receipt must remain materially faithful to what happened when the transaction completed.

It therefore uses completed snapshots for financial and commercial facts such as:

* merchandise description/context;
* selling price;
* price overrides;
* discounts;
* tax;
* tax-component labels where applicable;
* tender type/category;
* amounts;
* actors;
* transaction occurrence time;
* business date;
* workstation context;
* receipt identity.

Current master data must not silently change historical receipt contents.

---

# 17. Price changes do not change old receipts

Example:

```text
Original selling price:
$15.00

Current regular price:
$18.00
```

A receipt reprinted later still shows:

```text
$15.00
```

because the completed selling price is authoritative.

---

# 18. Discount changes do not change old receipts

A reprint uses the original completed discount facts.

It does not:

* rerun promotions;
* reevaluate membership;
* calculate current discount policy.

The receipt represents what was actually charged.

---

# 19. Tax changes do not change old receipts

A reprint uses the historical completed tax-component results.

Example:

```text
Original State Tax:
$0.96
```

A later rate change does not alter the receipt.

ShelfSense does not recalculate tax when rendering a historical receipt.

---

# 20. Tender changes do not change old receipts

If a tender type is renamed centrally:

```text
Credit Card
→
Card
```

the historical receipt should preserve the relevant completed tender presentation context where required.

Receipt rendering uses completed tender snapshots rather than redefining historical settlement from current tender configuration.

---

# 21. Historical versus current presentation configuration

Not every aspect of receipt rendering necessarily needs to be historically snapshotted.

ShelfSense distinguishes:

## Historical transaction content

Must remain historically fixed.

Examples:

```text
prices
discounts
tax
tenders
transaction time
business date
workstation context
```

## Presentation configuration

May potentially use current settings where policy permits.

Examples:

```text
printer width
font/layout
logo
```

Some header/footer information may have legal or historical significance and should be treated deliberately.

Examples:

```text
store address
legal entity name
tax registration number
return policy text
```

The receipt template/configuration specification should explicitly classify such fields rather than relying on accidental current lookups.

---

# 22. Receipt template

ShelfSense should conceptually separate:

```text
Receipt Facts
    → completed immutable business data

Receipt Template
    → presentation rules

Rendered Receipt
    → customer document
```

The template owns presentation.

It must not become another financial calculation engine.

---

# 23. Receipt identity presentation snapshots

Where human-facing store/workstation labels are printed, completed transactions should preserve enough historical context to render them consistently.

For example:

```text
workstation_id = W1
workstation_label_snapshot = Front Register 1
```

If W1 is later renamed, the historical relational identity remains W1 while historical receipt rendering can preserve the original display context.

---

# 24. Receipt sequence monotonicity

Receipt sequences are monotonic within the logical workstation.

Conceptually:

```text
4812
4813
4814
4815
```

A later valid completed receipt must not intentionally use a sequence lower than or equal to an already issued sequence in that workstation namespace.

---

# 25. Receipt numbers are not required to be gapless

ShelfSense does not require:

```text
4812
4813
4814
4815
```

with no possible gaps.

A sequence such as:

```text
4812
4813
4815
```

may be acceptable if the missing sequence resulted from a safe failure/recovery condition.

The stronger requirements are:

* uniqueness;
* monotonic progression;
* no unsafe reuse.

---

# 26. Previously or potentially issued sequences must not knowingly be reused

Installation replacement or recovery may make the precise local high-water uncertain.

ShelfSense should prefer a safe gap rather than deliberately reuse a sequence that may already identify an unsynchronized historical receipt.

The exact high-water recovery mechanism belongs to a receipt identity/replacement contract.

---

# 27. Receipt sequence does not reset with business date

Incorrect permanent model:

```text
August 13
Receipt 1..500

August 14
Receipt 1..400
```

Initial ShelfSense behavior should instead maintain one workstation-local monotonic sequence across business dates.

Example:

```text
August 13
Receipt 4814

August 14
Receipt 4815
```

Business date remains separately available on the transaction.

---

# 28. Receipt sequence does not reset with Z

Closing a Z does not reset receipt numbering.

Example:

```text
Z 101
Receipt 4812
Receipt 4813

Z 102
Receipt 4814
Receipt 4815
```

Receipt and Z sequences have separate identities and purposes.

---

# 29. Store Close does not affect receipt identity

An optional Store Close does not:

* assign receipt numbers;
* finalize receipts;
* reset sequences;
* prevent late receipt synchronization.

Receipt authority remains at local completed transaction time.

---

# 30. Synchronization does not assign receipt identity

When a completed transaction later reaches Rails, the server receives its existing receipt identity.

The server validates and preserves it.

It must not replace:

```text
Workstation W1 / Receipt 4814
```

with some centrally generated number merely because the transaction synchronized later.

---

# 31. Receipt uniqueness

Within the supported business model, the combination of:

```text
store
+
workstation
+
receipt sequence
```

must identify at most one completed POS transaction.

The exact database constraints belong to implementation design.

Transaction UUID remains the primary technical identity.

---

# 32. Installation identity remains available separately

Although receipt numbering is workstation-scoped, the transaction still preserves:

```text
installation_id
```

that originated it.

Therefore support can determine:

```text
Receipt 4814
Workstation W1
Originating Installation I2
```

without making I2 part of the customer's permanent receipt-number namespace.

---

# 33. Reprint

A reprint reproduces the receipt representation of an existing completed transaction.

It does not create:

* a new transaction;
* a new receipt identity;
* a new receipt sequence;
* new financial effects.

Example:

```text
Original:
Receipt 4814

Reprint:
Receipt 4814
```

---

# 34. Reprints should be visibly identified

A deliberately reproduced receipt should normally contain an obvious indication such as:

```text
REPRINT
```

or equivalent template treatment.

This reduces the chance that multiple physical copies are mistaken for multiple distinct transactions.

Exact wording and layout belong to the receipt template.

---

# 35. Reprint event

A reprint may generate an operational/audit event containing information such as:

```text
receipt/transaction
printed_by
printed_at
reason
printer
success/failure
```

where useful.

The reprint event is not a new financial fact.

---

# 36. Print attempts

ShelfSense may preserve print-attempt activity independently from the completed receipt.

Conceptually:

```text
Completed Receipt
├── Print Attempt 1 — failed
├── Print Attempt 2 — succeeded
└── Reprint Event — later
```

These operational events do not modify the completed transaction.

---

# 37. Initial print retry versus reprint

There is a conceptual distinction between:

### Retry

The original completion occurred, but physical output failed.

```text
commit
→ print failure
→ retry
```

### Reprint

A receipt that has already been delivered or completed operationally is intentionally produced again.

```text
historical receipt lookup
→ reprint
```

Both use the same permanent receipt identity.

Exact display labeling for delayed first printing remains a workflow/presentation decision.

---

# 38. Receipt lookup

A completed receipt should be retrievable through suitable identifiers such as:

* receipt identity;
* transaction UUID;
* store/workstation/sequence;
* other authorized transaction lookup mechanisms.

The lookup workflow belongs elsewhere.

Receipt identity should be practical for human support and customer service.

---

# 39. Return receipt

A return is a new completed transaction and therefore receives its own new receipt identity.

Example:

```text
Original Sale
Receipt 4814

Return
Receipt 4930
```

The return receipt may reference:

```text
Original Receipt 4814
```

where appropriate.

It does not reuse the original receipt identity.

---

# 40. Exchange receipt

An exchange is one completed mixed sale/return transaction and therefore receives one receipt identity.

The receipt should present the gross transaction directions clearly.

Example:

```text
RETURN
Book A                 -$20.00

SALE
Book B                  $30.00

Balance Due             $10.00
Cash                    $10.00
```

The receipt should not hide the return merely because the transaction net was `$10`.

---

# 41. Receipt line direction

Receipt presentation should distinguish:

```text
sale
```

from:

```text
return
```

based on completed transaction-line direction.

It should not infer return behavior from negative quantities.

Transaction Lines owns the business semantics.

Receipts presents them.

---

# 42. Voided lines

Pre-completion voided lines ordinarily need not appear as customer financial lines on the completed receipt.

Whether selected operational/void information appears belongs to receipt policy.

The completed totals must reflect only active completed financial lines.

---

# 43. Open-ring lines

Open rings should render as their actual completed line facts.

The receipt must not fabricate a fake product or SKU to represent them.

Possible presentation may include:

* entered description;
* department/context;
* amount;
* tax.

Exact layout belongs to templates.

---

# 44. Cash tender presentation

Cash receipts should preserve the distinction among:

```text
applied amount
amount presented
change
```

Example:

```text
Cash                    $17.24
Tendered                $20.00
Change                   $2.76
```

The exact labels are presentation choices.

The values come from completed Tender facts.

---

# 45. Mixed tender presentation

A mixed-tender receipt should display each completed tender distinctly.

Example:

```text
Gift Card               $20.00
Card                    $30.00
Cash                    $10.00
```

Tender sequence may be preserved where useful.

---

# 46. Refund tender presentation

Return receipts should display the completed refund tender(s) where a refund occurs.

Example:

```text
Refund to Store Credit  $25.00
```

An even exchange with no settlement should not invent a zero-dollar tender.

---

# 47. Card receipt data

ShelfSense should display only Card information it legitimately stores and is permitted to present.

The initial model does not require storage or printing of:

* PAN;
* CVV;
* sensitive authentication data.

Any future processor-specific receipt requirements belong to the Card integration specification.

---

# 48. Tax presentation

Receipts should be able to display:

* net merchandise amount;
* discounts;
* tax;
* total;

and component tax where required.

Example:

```text
Subtotal                 $20.00
Discount                  -2.00
State Sales Tax            1.08
Total                     $19.08
```

The receipt consumes completed Tax facts.

---

# 49. Exempt/zero-rated presentation

Where required by policy or jurisdiction, receipts may identify exempt or zero-rated treatment.

The underlying completed Tax domain already preserves those distinctions.

Receipt templates determine customer-facing presentation.

---

# 50. Receipt total must reconcile to completed transaction

A rendered receipt must faithfully reproduce the completed transaction's financial facts.

Conceptually:

```text
displayed merchandise
+
displayed tax
-
displayed discounts
=
displayed transaction total
```

subject to the exact presentation/allocation rules.

Receipt rendering must not create a total different from the completed transaction.

---

# 51. Receipt and business date

A receipt may display:

```text
occurred_at
```

and/or:

```text
business_date
```

according to receipt policy.

They are distinct facts.

For customer-facing timestamping, actual occurrence time is normally the primary customer-relevant date/time.

Business date remains operational/reporting context.

---

# 52. Receipt and Z

A completed transaction may reference its Z.

The receipt may optionally expose register/Z context where useful.

However:

> **Z does not own or assign receipt identity.**

Receipt numbering continues independently across Z transitions.

---

# 53. Receipt and drawer session

Cash drawer-session identity is not part of the customer receipt identity.

It may remain available internally for reconciliation and support.

The receipt presents customer settlement, not internal cash-custody structure.

---

# 54. Receipt and Store Close

Store Close is unrelated to receipt finality.

A receipt completed offline before Store Close remains valid even if it synchronizes later.

Store Close cannot reassign or invalidate its receipt number.

---

# 55. Receipt and operation synchronization

The completed-sale operation should carry sufficient receipt identity context for the server to preserve and validate:

```text
store
workstation
receipt sequence
transaction ID
```

and the originating installation separately.

Synchronization retries must not create another receipt.

---

# 56. Duplicate delivery

If a completed operation is delivered twice because an acknowledgment was lost:

```text
same operation ID
same transaction ID
same receipt identity
```

the server recognizes the idempotent retry.

It must not allocate or create a second receipt.

---

# 57. Conflicting receipt identity

If two distinct originating transactions claim the same receipt identity:

```text
Store S
Workstation W
Receipt 4814
```

that is a serious identity/reconciliation conflict.

ShelfSense must not silently renumber one transaction centrally.

Both originating facts should be preserved according to Reconciliation policy while the receipt-identity conflict is surfaced.

---

# 58. Why server renumbering is prohibited

Changing an offline receipt after the customer already received it would break the connection among:

* customer's paper receipt;
* cashier record;
* local transaction history;
* central transaction.

Therefore:

> **A centrally discovered sequence conflict must not be fixed by silently assigning a different receipt number to an already completed transaction.**

The conflict must be resolved explicitly.

---

# 59. Receipt configuration

Receipt presentation may eventually support configuration such as:

* organization/store header;
* footer;
* logo;
* return-policy text;
* width;
* tax labels;
* tender labels.

Configuration must affect rendering without changing the underlying completed financial facts.

---

# 60. Receipt renderer version

ShelfSense may eventually preserve renderer/template version context for support or exact historical reproduction.

This is optional initially.

The critical requirement is that financial content remain historically stable regardless of renderer version.

---

# 61. Exact visual reproduction versus factual reproduction

ShelfSense should distinguish:

```text
factual historical reproduction
```

from:

```text
pixel-identical historical reproduction
```

The core requirement is factual reproduction.

A receipt reprinted years later may use a newer visual template while still presenting the same historical:

* items;
* prices;
* discounts;
* tax;
* tender;
* totals;
* identity.

If exact old formatting is later required, template versioning can be added explicitly.

---

# 62. Receipt delivery channels

Receipt delivery should be extensible beyond paper.

Conceptually:

```text
Receipt
├── Print
├── Email
└── Future channel
```

These are delivery mechanisms for the same completed receipt facts.

Phase 5 requires only print.

---

# 63. Receipt delivery does not create financial state

Sending an email receipt or printing another copy:

* does not modify transaction totals;
* does not affect Z totals;
* does not affect tender;
* does not affect inventory;
* does not alter business date.

Delivery activity may be audited separately.

---

# 64. Conceptual receipt identity model

Without locking physical schema:

```text
Completed Transaction
│
├── transaction_id
│
├── store_id
├── workstation_id
├── installation_id
│
├── receipt_sequence
├── receipt display snapshots/context
│
└── immutable completed financial facts
```

A separate Receipt aggregate/table is not required merely to establish receipt identity.

---

# 65. Separate Receipt aggregate is not initially required

Unless ShelfSense later needs a receipt lifecycle independent of the transaction, the simplest model is:

> Receipt identity and receipt-rendering context are properties of the completed transaction.

A separate receipt table should only be introduced for a demonstrated persistence/lifecycle need.

---

# 66. Print-event model

If operational print history is persisted, it can be separate:

```text
Receipt Print Event
├── id
├── transaction
├── attempted_at
├── performed_by
├── printer/context
├── result
└── reprint/retry context
```

This record is operational evidence, not the receipt's financial identity.

---

# 67. Domain ownership

## Receipts owns

* receipt identity semantics;
* workstation sequence scope;
* assignment-at-completion rule;
* receipt immutability;
* historical rendering requirements;
* print/reprint semantics;
* customer-facing receipt representation.

## Transactions owns

* completion lifecycle;
* transaction UUID;
* immutable completed business facts.

## Workstation Identity owns

* logical workstation identity;
* installation identity;
* workstation replacement.

## Reporting Periods owns

* business date;
* Z identity.

## Pricing owns

* selling-price facts.

## Discounts owns

* discount facts.

## Tax owns

* tax-component facts.

## Tenders owns

* payment/refund facts;
* Cash presented/change.

## Returns owns

* return and original-sale linkage.

## Local Persistence owns

* durable local sequence state;
* crash recovery mechanics.

## Operation Synchronization owns

* receipt identity transport;
* central idempotent preservation.

## Reconciliation owns

* conflicting receipt identities.

---

# 68. Phase 5 delivery

Phase 5 should implement:

* workstation-scoped receipt sequence;
* local receipt allocation;
* receipt assignment during transaction commit;
* permanent receipt identity;
* basic historical transaction rendering;
* paper printing;
* Cash presented/change display;
* tax display;
* print-after-commit behavior;
* printer-failure retry;
* basic reprint capability.

Phase 5 does not require:

* electronic receipts;
* advanced template editing;
* exact historical template preservation;
* sophisticated replacement sequence recovery;
* multi-printer routing.

---

# 69. Phase 6 expansion

As the POS gains broader operations, receipts should expand to support:

* multiple tenders;
* Card;
* Check;
* Stored Value;
* discounts/promotions;
* returns;
* exchanges;
* open-ring presentation;
* broader tax-component display;
* richer reprint audit.

These should extend the same completed-fact rendering model.

---

# 70. Phase 6B productization

Productization should add:

* robust receipt-printer support;
* workstation replacement sequence safeguards;
* receipt high-water recovery;
* clone/sequence conflict diagnostics;
* printer-health diagnostics;
* template/configuration management;
* optional electronic delivery.

None of these changes receipt authority.

---

# 71. Pending decisions

## 71.1 Receipt display format

Define the human-facing format for:

```text
store
workstation
receipt sequence
```

The underlying identity is already fixed.

---

## 71.2 Receipt sequence starting value

Determine workstation initialization behavior.

This is operational configuration, not a domain-model change.

---

## 71.3 Replacement/high-water recovery

Define the exact algorithm for a replacement installation when the old installation may contain unsynchronized receipt sequences.

Required before full workstation replacement support.

---

## 71.4 Header/footer snapshot policy

Classify configuration fields as:

* historical snapshot;
* current presentation;
* legally required historical value.

Examples requiring explicit decisions include:

* legal organization name;
* store address;
* phone;
* tax registration number;
* return-policy text.

---

## 71.5 Reprint marking

Define customer-facing wording/layout such as:

```text
REPRINT
DUPLICATE
COPY
```

---

## 71.6 Initial print retry labeling

Determine whether a delayed successful first print after an initial hardware failure is marked as a reprint.

This does not affect financial semantics.

---

## 71.7 Print-event persistence

Determine how much receipt delivery activity needs durable persistence versus ordinary application logging/audit.

---

## 71.8 Electronic receipts

Defer channel-specific implementation until a concrete need exists.

The receipt domain already supports multiple delivery mechanisms conceptually.

---

## 71.9 Template version preservation

Determine whether ShelfSense needs exact historical visual-template reproduction or only historically accurate factual rendering.

Recommended initial requirement: **factual reproduction**.

---

# 72. Core invariants summary

The following rules are authoritative unless explicitly superseded:

1. **Receipt identity and transaction identity are separate.**
2. **Receipt identity is human-facing; transaction UUID is the technical identity.**
3. **Receipt identity is scoped by store + logical workstation + workstation sequence.**
4. **Receipt sequence belongs to the logical workstation, not the installation.**
5. **Receipt identity is assigned only when the transaction completes.**
6. **Receipt assignment occurs locally and must work offline.**
7. **Receipt identity commits atomically with the completed transaction.**
8. **A completed transaction has its permanent receipt identity before printing.**
9. **Printing occurs after transaction commit.**
10. **Printer failure never rolls back or reopens a completed transaction.**
11. **The receipt exists independently of successful physical printing.**
12. **Receipt rendering uses completed historical financial facts.**
13. **Current prices, discounts, taxes, and tender configuration do not rewrite historical receipts.**
14. **Receipt templates present facts; they do not recalculate them.**
15. **Receipt sequences are monotonic within the workstation.**
16. **Receipt sequences are not required to be gapless.**
17. **Previously or potentially issued numbers must not knowingly be reused.**
18. **Receipt sequence does not reset at Z close.**
19. **Receipt sequence does not reset at business-date transition.**
20. **Store Close does not assign, invalidate, or modify receipt identities.**
21. **Synchronization does not replace a locally assigned receipt identity.**
22. **Reprints use the same receipt identity.**
23. **Reprints create no financial effects.**
24. **A reprinted customer document should normally be visibly identified as a copy/reprint.**
25. **Returns receive new receipt identities.**
26. **Exchanges receive one receipt for the new mixed transaction.**
27. **Receipt content preserves sale/return direction rather than hiding gross activity.**
28. **Tender and tax presentation consume completed domain facts.**
29. **A receipt-number conflict discovered centrally is not repaired by silently renumbering completed transactions.**
30. **A separate Receipt aggregate is not required unless an independent receipt lifecycle emerges.**

---

# 73. Acceptance examples

## Example A — ordinary Cash sale

Given:

```text
Store S1
Workstation W1
next receipt sequence = 4814
```

when a `$17.24` Cash transaction successfully commits,

then the transaction receives:

```text
Store S1
Workstation W1
Receipt 4814
```

before printing begins.

---

## Example B — printer failure

Given Receipt 4814 has committed,

when the printer jams,

then:

* transaction remains completed;
* Receipt 4814 remains assigned;
* Cash/inventory/tax effects remain completed;
* cashier may retry printing Receipt 4814.

No new receipt number is allocated.

---

## Example C — reprint

Given Receipt 4814 completed yesterday,

when an authorized user requests another copy,

then the document still identifies:

```text
Receipt 4814
```

and is visibly identified as a reprint/copy according to presentation policy.

---

## Example D — price change after sale

Given:

```text
Receipt 4814 selling price = $15
Current regular price = $18
```

when Receipt 4814 is reprinted,

then it shows `$15`.

---

## Example E — tax change after sale

Given Receipt 4814 originally recorded:

```text
State Sales Tax = $0.96
```

when the current tax rate later changes,

then the reprint continues to show `$0.96`.

---

## Example F — workstation installation replacement

Given:

```text
W1 / Installation I1
last issued receipt = 4814
```

when I1 is replaced by I2,

then I2 remains part of the same W1 receipt namespace.

It does not automatically begin a new installation-scoped Receipt 1 sequence.

Exact safe starting sequence is determined by the replacement contract.

---

## Example G — Z close

Given:

```text
Z 101
last receipt = 4814
```

when Z 101 closes and Z 102 opens,

then the next completed receipt remains in the same workstation sequence, for example:

```text
Receipt 4815
```

not Receipt 1.

---

## Example H — business-date change

Given Receipt 4814 completed on business date August 13,

when the workstation transitions to August 14,

then its next receipt remains in the same sequence.

Business-date transition does not reset receipt numbering.

---

## Example I — return

Given original sale:

```text
Receipt 4814
```

when the customer later completes a linked return,

then the return receives its own new receipt, for example:

```text
Receipt 4930
```

and may display:

```text
Original Receipt: 4814
```

---

## Example J — even exchange

Given a customer returns `$20` merchandise and purchases `$20` merchandise,

then the completed exchange receives one new receipt.

The receipt shows both:

```text
RETURN
...
SALE
...
```

and no artificial zero-dollar tender is required.

---

## Example K — Cash tender display

Given:

```text
Cash applied   = $17.24
Cash presented = $20.00
Change         = $2.76
```

then the receipt can display all three values distinctly.

It does not treat `$20` as transaction revenue.

---

## Example L — late synchronization

Given Receipt 4814 completes offline on August 13 and synchronizes August 15,

then central ShelfSense preserves:

```text
Receipt 4814
original workstation
original transaction
original business date
```

It does not allocate a new August 15 receipt identity.

---

## Example M — duplicate synchronization

Given the same completed Receipt 4814 operation is submitted twice because an acknowledgment was lost,

then the server recognizes the same operation/transaction identity and creates one central receipt association.

---

## Example N — conflicting receipt identities

Given two distinct completed transactions claim:

```text
Store S1
Workstation W1
Receipt 4814
```

then ShelfSense surfaces a receipt-identity conflict.

It does not silently change one historical transaction to Receipt 4815.

---

# 74. Related workflows

This specification should eventually be referenced by:

* `workflows/peripherals/receipt-printing.md`
* `workflows/peripherals/reprint.md`
* `workflows/sales/complete-transaction.md`
* `workflows/returns/linked-return.md`
* `workflows/returns/exchange.md`
* `workflows/workstation/replacement.md`
* `workflows/workstation/recovery.md`

---

# 75. Related contracts

Receipts will eventually require exact contracts for:

### Receipt identity

```text
store_id
workstation_id
receipt_sequence
```

plus display formatting rules where required.

### Local allocation

Define how local durable workstation state allocates a receipt sequence as part of transaction completion.

### Completed-sale operation

Define exact transmission of:

```text
transaction_id
store_id
workstation_id
installation_id
receipt_sequence
```

and historical display snapshots.

### Receipt rendering

Define the required completed facts exposed to receipt templates without permitting recalculation.

### Reprint

Define authorized lookup and operational audit semantics.

### Workstation replacement

Define safe sequence continuation when the old installation's local high-water may be uncertain.

The Receipts domain defines **the permanent human identity and customer-facing historical representation of a completed POS transaction**.

Transaction completion creates that identity. Printing and delivery merely present it.
