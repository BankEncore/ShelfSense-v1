# POS Domain Specification: Approvals and Controlled Actions

**Design status:** Core framework decided; policy representation, action catalog details, and numeric thresholds remain partially pending
**Implementation status:** Foundation required before controlled Phase 6 capabilities
**Initial contract foundation:** Phase 4/5 as needed for authorization context
**First substantial delivery:** Phase 6.1 — Price Overrides and Transaction Corrections
**Expanded delivery:** Phase 6.3–6.5 and later exception workflows
**Related specifications:** Transactions, Transaction Lines, Pricing, Discounts, Tenders, Returns, Cash Handling, Workstation Identity, Reference Replication, Operation Synchronization, Reconciliation
**Related workflows:** Price Override, Void Line, Cancel Transaction, Open Ring, Apply Discount, Cash Paid-Out, Cash Transfer, Drawer Variance Approval, Unlinked Return, Alternate Refund

---

## 1. Purpose

This specification defines ShelfSense's reusable POS approval and controlled-action model.

It establishes:

* the distinction between permission, policy, reason, and approval;
* how ShelfSense represents a requested controlled action;
* how policy determines whether the action is:

  * direct;
  * approval required;
  * prohibited;
* how second-actor approval works;
* what an approval authorizes;
* how approvals bind to exact action values;
* when an approval becomes invalid;
* how approval works offline;
* how completed approval facts become immutable;
* how organization defaults and store overrides interact;
* how approval facts relate to transactions, lines, discounts, returns, and cash operations;
* how approval activity is audited and reported.

This specification does **not** define:

* the exact numeric threshold for every business action;
* the full permission catalog;
* POS credential cryptography;
* price-override calculation itself;
* discount calculation;
* return eligibility;
* cash-movement accounting;
* detailed cashier UI.

Those rules belong to the owning specifications, configuration, and workflows.

---

# 2. Governing principle

The central rule is:

> **Approval authorizes one specific requested business action. It does not grant a user temporary generalized authority.**

For example, an approval should mean:

```text
Approve:
  price override
  on transaction line X
  from $16.00
  to $12.00
  quantity 2
```

It must not mean:

```text
Manager approved this line.
```

or:

```text
Cashier may now perform price overrides.
```

Approval scope must remain narrow and explicit.

---

# 3. Four separate concepts

ShelfSense distinguishes four concepts that must not be collapsed:

```text
Permission
    ↓
Can this person perform or approve
this category of action at all?

Policy
    ↓
What authority is required for
this particular requested action?

Action context
    ↓
What exactly is being requested?

Approval fact
    ↓
Who authorized that exact request?
```

A fifth concept, **reason**, may also be required independently.

---

# 4. Permission

A permission answers:

> **Is this actor authorized to perform or approve this category of operation?**

Conceptual permissions might include:

```text
pos.price_override.perform
pos.price_override.approve

pos.line_void.perform
pos.line_void.approve

pos.discount.perform
pos.discount.approve

pos.cash_paid_out.perform
pos.cash_paid_out.approve
```

Exact permission codes remain an implementation/configuration decision.

Permission alone does **not** determine whether second-person approval is required for a particular transaction.

---

# 5. Approval policy

Approval policy answers:

> **Given this specific requested operation and its values, what authority level is required?**

The three policy outcomes are:

```text
direct
approval_required
prohibited
```

This three-state model is already established in the consolidated POS design. 

---

# 6. Direct action

A `direct` result means the performing actor possesses sufficient authority to perform the requested action without a second actor.

Conceptually:

```text
request
  ↓
performer permission valid
  ↓
policy result = direct
  ↓
execute action
```

A second-person approval fact is unnecessary.

The business action should still retain its ordinary:

* performer;
* reason where applicable;
* policy/configuration context;
* audit history.

---

# 7. Approval-required action

An `approval_required` result means:

1. the performing actor may initiate/request the action;
2. the action cannot execute until another qualifying actor approves it;
3. approval applies only to the exact requested action;
4. approval does not change the identity of the performer.

Conceptually:

```text
Cashier requests action
        ↓
policy = approval_required
        ↓
second actor authenticates
        ↓
approver authority validated
        ↓
approval bound to request
        ↓
action executes
        ↓
control returns to cashier
```

---

# 8. Prohibited action

A `prohibited` result means the requested action must not proceed under the current policy.

ShelfSense must not treat:

```text
prohibited
```

as:

```text
needs an even more senior manager
```

unless the policy explicitly defines such another authorized path.

A prohibited action is blocked.

---

# 9. Permission and policy are different

Consider a cashier who has:

```text
pos.price_override.perform
```

That permission may allow the cashier to request price overrides.

Policy might then produce:

```text
2% override
→ direct

15% override
→ approval_required

60% override
→ prohibited
```

The cashier's permission did not change between those requests.

The **action values** changed the policy result.

---

# 10. Performer versus approver

ShelfSense distinguishes:

```text
performed_by
approved_by
```

These are separate business facts.

The performer is the person carrying out the controlled business action.

The approver is the second actor who authorizes it when required.

The consolidated design explicitly requires this distinction and rejects manager takeover of the transaction. 

---

# 11. Second-actor approval

When policy requires a second actor:

```text
approved_by != performed_by
```

must hold.

The cashier remains the transaction operator.

Correct workflow:

```text
Cashier A requests action
        ↓
Supervisor B enters POS credential
        ↓
ShelfSense validates B
        ↓
Supervisor B approves exact action
        ↓
control returns immediately to Cashier A
```

Incorrect workflow:

```text
Cashier logs out
Supervisor logs in as cashier
Supervisor performs action
Supervisor logs out
Cashier logs back in
```

The latter destroys the distinction between operation and approval.

---

# 12. No artificial self-approval

ShelfSense should generally avoid creating fake self-approval records.

If a manager acting as cashier has sufficient authority to perform an action directly, policy should return:

```text
direct
```

rather than:

```text
approval_required
approved_by = performed_by
```

If policy explicitly requires **another actor**, self-approval is invalid.

---

# 13. Controlled action

Approvals operate against an explicit application-defined **action type**.

Examples include:

```text
price_override
line_void
transaction_cancel
open_ring
line_discount
transaction_discount

cash_paid_out
cash_transfer
cash_drop
drawer_variance_acceptance

unlinked_return
alternate_refund
post_void
```

The exact action catalog grows as capabilities are implemented.

The consolidated design already identifies price overrides, voids, cancellation, open rings, discounts, cash operations, variance approval, and return/refund exceptions as intended users of the common approval framework. 

---

# 14. Explicit actions, not generic expressions

ShelfSense should use an application-defined action catalog.

It should **not** initially implement a generic business-rules programming language.

Avoid a system where administrators enter arbitrary expressions such as:

```text
if department == "BOOKS"
and line.foo > ...
and user.bar ...
```

Instead:

```text
action_type = price_override
```

has a known, documented set of policy inputs.

Likewise:

```text
action_type = cash_paid_out
```

has its own known inputs.

This keeps policy behavior:

* understandable;
* testable;
* auditable;
* portable to the offline POS.

---

# 15. Action subject

A controlled action has a subject: the business object or context being acted upon.

Examples:

| Action                     | Subject                            |
| -------------------------- | ---------------------------------- |
| Price override             | Transaction line                   |
| Line void                  | Transaction line                   |
| Transaction discount       | Transaction                        |
| Transaction cancellation   | Transaction                        |
| Paid-out                   | Drawer session / proposed movement |
| Cash drop                  | Source/destination cash context    |
| Drawer variance acceptance | Drawer reconciliation/count        |
| Unlinked return            | Proposed return transaction/action |

The approval framework should not assume every approval belongs to a transaction line.

---

# 16. Requested-action context

A controlled request must contain enough information to determine:

1. what is being requested;
2. what policy applies;
3. what exact values are being approved;
4. whether those values changed afterward.

Conceptually:

```text
ControlledActionRequest
├── action_type
├── subject
├── performed_by
├── requested_values
├── reason/context
├── requested_at
└── policy/reference context
```

Exact serialization belongs to the Approval contract.

---

# 17. Action-specific values

Each action type defines the values that materially determine its meaning.

## Price override

Potential inputs:

```text
reference_unit_price_cents
requested_selling_unit_price_cents
quantity
unit_variance_cents
line_variance_cents
variance_percentage
```

## Line discount

Potential inputs:

```text
discount_method
requested_discount_cents
requested_percentage
eligible_line_basis_cents
```

## Transaction discount

Potential inputs:

```text
discount_method
requested_discount_cents
requested_percentage
eligible_transaction_basis_cents
```

## Line void

Potential inputs:

```text
line_id
quantity
current_line_value_cents
```

## Paid-out

Potential inputs:

```text
cash_location/drawer
amount_cents
reason
```

The owning domain determines the meaningful values.

Approvals consumes them for authorization.

---

# 18. Approval binds to the exact request

This is a core invariant:

> **An approval is valid only for the specific action and material values that were approved.**

Example:

```text
Reference price: $16
Requested selling price: $12
```

Supervisor approves.

If the cashier changes the requested selling price to:

```text
$8
```

the existing approval no longer satisfies the request.

The source design already establishes this exact invalidation principle. 

---

# 19. Material action identity

ShelfSense needs a deterministic way to identify the material contents of an approval request.

Conceptually:

```text
action_type
+
subject identity
+
material requested values
+
other policy-relevant context
=
action identity
```

An implementation may eventually represent this with:

* canonical serialized values;
* versioned action snapshot;
* deterministic fingerprint/hash;
* equivalent structured comparison.

This specification does not require hashing specifically.

The domain requirement is:

> ShelfSense can reliably determine whether the approved request is still the same request.

---

# 20. Action fingerprint concept

A useful conceptual model is:

```text
fingerprint(
  action_type,
  subject,
  material_values,
  policy-relevant context
)
```

Then:

```text
request changes materially
        ↓
fingerprint changes
        ↓
existing approval no longer matches
```

The exact canonicalization and hashing rules belong in a later contract if this implementation approach is adopted.

---

# 21. Approval invalidation

An approval becomes invalid for the current request when a material input changes.

Examples may include:

* requested price changes;
* discount amount changes;
* discount percentage changes;
* line quantity changes where financial impact changes;
* subject line changes;
* paid-out amount changes;
* return quantity changes;
* refund destination changes where policy-relevant.

The safest default is:

> **Material change requires fresh policy evaluation and, where required, new approval.**

---

# 22. Not every change is necessarily material

Some changes may not affect the approved business action.

For example, changing an unrelated UI selection should not invalidate approval.

Whether changing an optional free-text note invalidates approval depends on whether that note is part of the business/policy meaning.

Each action type should define its **material approval fields**.

---

# 23. Reasons are independent from approvals

Reason and approval answer different questions.

### Reason

> Why is the user doing this?

### Approval

> Did another authorized actor permit this exact action?

A policy may therefore require:

```text
reason = required
approval = not required
```

or:

```text
reason = required
approval = required
```

or:

```text
reason = not required
approval = not required
```

The consolidated design explicitly establishes this separation. 

---

# 24. Reason ownership

Approvals does not necessarily own the business reason catalog.

For example:

* price-override reasons belong logically with Pricing/POS administration;
* paid-out reasons belong with Cash Handling;
* return-exception reasons belong with Returns.

The Approval framework may reference the selected reason when that reason is part of the action context.

---

# 25. Policy inputs

Approval policy should operate on explicit normalized inputs defined for each action type.

Possible generic input categories include:

```text
amount_cents
percentage
quantity
total_financial_effect_cents
```

as appropriate.

The policy engine should not infer values by inspecting arbitrary unrelated database records.

The application service responsible for the action supplies the normalized policy context.

---

# 26. Multiple threshold dimensions

A policy may evaluate more than one dimension.

For example, a price override may evaluate:

```text
unit percentage variance
```

and:

```text
total line dollar variance
```

When multiple dimensions apply, the **stricter outcome controls**.

This follows the existing POS decision for approval thresholds. 

---

# 27. Policy severity ordering

Conceptually:

```text
direct
    <
approval_required
    <
prohibited
```

When multiple applicable policy checks produce different outcomes, use the most restrictive result.

Example:

```text
percentage policy → direct
dollar policy     → approval_required
```

final:

```text
approval_required
```

---

# 28. Threshold representation

A threshold policy might conceptually look like:

```text
Action: price_override

Direct:
  variance <= 5%

Approval required:
  variance > 5% and <= 25%

Prohibited:
  variance > 25%
```

However, this specification does **not** lock:

* actual percentages;
* actual dollar values;
* exact storage schema.

Those remain configuration decisions.

---

# 29. Organization defaults and store overrides

The preferred policy hierarchy is:

```text
organization default
        ↓
optional store override
```

Roles/permissions determine **who** may perform or approve actions.

The action policy determines **when** approval is required.

The existing design favors organization defaults with store-specific overrides and discourages per-user numeric limits absent a concrete future need. 

---

# 30. No per-user threshold matrix initially

ShelfSense should avoid rules such as:

```text
Alice may override 7%
Bob may override 9%
Charlie may override $32
```

unless a concrete business requirement later justifies that complexity.

Prefer:

```text
Role/permission
+
organization/store policy
```

This keeps authority understandable and easier to replicate offline.

---

# 31. Policy versioning

Because POS operates offline, the workstation must know which policy version it used.

A completed controlled action should preserve enough context to explain:

> This action was authorized under policy state/version X.

Possible concepts include:

```text
policy_id
policy_version
reference_snapshot_version
```

Exact fields remain contract/schema decisions.

---

# 32. Permission versioning

Likewise, offline approval needs evidence of the cached authorization state used.

Conceptually preserve:

```text
performed_by
performer authority/version

approved_by
approver authority/version
```

where relevant.

This does not mean copying the whole permission graph into every completed transaction.

The stored evidence should be sufficient to explain the authorization context.

---

# 33. Offline approval

A disconnected POS workstation must support approvals for actions that are themselves permitted offline.

The workflow is:

```text
cashier requests action
        ↓
local policy evaluation
        ↓
approval required
        ↓
approver authenticates locally
        ↓
cached permission verified
        ↓
approval recorded locally
        ↓
action proceeds
```

The workstation does not require central connectivity solely because another actor must approve.

This is already an explicit requirement in the consolidated design. 

---

# 34. Offline approver authentication

The approver uses the appropriate POS-specific offline-verifiable credential.

Approver authentication:

* validates the second actor;
* does not replace the cashier's active session;
* grants no persistent elevated mode;
* applies only to the requested approval.

Once approval is complete:

```text
control returns to original cashier
```

---

# 35. No manager mode

ShelfSense should not create a generic:

```text
MANAGER MODE ON
```

that enables broad elevated operations for an arbitrary period.

That would weaken:

* actor attribution;
* approval scope;
* loss-prevention audit;
* offline reconciliation.

Each controlled action is evaluated independently.

---

# 36. Batch approval

Initial behavior should assume one approval per requested controlled action.

ShelfSense should not initially support:

```text
Manager approves all future voids for next 10 minutes.
```

or:

```text
Manager approves every discount on this transaction.
```

unless a later deliberately designed batch-approval feature defines its exact scope.

---

# 37. Approval before action execution

Where second-actor approval is required, the controlled action should normally not take effect until the required approval exists.

For example:

```text
request price $12
        ↓
approval required
        ↓
approve
        ↓
apply $12 selling price
```

rather than:

```text
apply $12
        ↓
hope manager approves later
```

This avoids temporarily creating unauthorized working state.

---

# 38. Provisional request state

The UI/application may hold a proposed value while awaiting approval.

For example:

```text
Current selling price: $16
Requested:             $12
Status: awaiting approval
```

But the authoritative action should not be considered applied until authorization succeeds.

The precise UI representation is outside this specification.

---

# 39. Approval cancellation

If the cashier abandons a request before approval:

* no business action occurs;
* any provisional approval request state may be discarded/closed;
* no historical approval fact needs to imply that an action occurred.

If an approval was actually granted but the action is subsequently abandoned before completion, the activity may remain useful as operational history, depending on the persistence design.

---

# 40. Approval versus authorization evaluation

ShelfSense may conceptually distinguish:

```text
AuthorizationDecision
```

from:

```text
ApprovalFact
```

An authorization decision answers:

```text
direct | approval_required | prohibited
```

An approval fact exists only when:

```text
approval_required
```

and a qualifying actor approves.

This prevents unnecessary “approval” rows for ordinary direct actions.

---

# 41. Working approvals

Before the parent business fact completes, an approval may be part of mutable working state.

For a transaction-based action, it may later become:

* satisfied;
* invalidated;
* abandoned;
* superseded.

For example:

```text
$16 → $12 approved
        ↓
cashier changes to $10
        ↓
old approval invalid
        ↓
new approval required
```

---

# 42. Completion validation

Before a transaction completes, ShelfSense must confirm:

> Every active controlled action that currently requires approval has a valid approval matching its current material values.

A stale approval must not satisfy completion merely because an approval record exists somewhere on the transaction.

---

# 43. Completed approvals

When the associated business transaction/action completes:

* applicable approval facts become immutable historical evidence;
* approver identity is frozen;
* approved action values are frozen;
* relevant permission/policy context is frozen;
* later policy changes do not retroactively alter historical authorization.

This follows the broader completed-transaction immutability model.

---

# 44. Completed action correction

Correcting the resulting business fact later does not rewrite its historical approval.

For example:

```text
Price override approved and sale completed
        ↓
item later returned
```

The original approval remains part of the original historical sale.

The return may require its own separate authorization according to Return policy.

---

# 45. Revocation discovered after offline approval

Consider:

```text
Supervisor B cached as valid
        ↓
terminal goes offline
        ↓
B is centrally revoked
        ↓
B approves local transaction action
        ↓
transaction completes
        ↓
terminal reconnects
```

ShelfSense must preserve the historical fact that B approved the operation using the workstation's then-cached authority.

Synchronization may classify this as:

* accepted;
* accepted with warning;
* quarantined;

according to Reconciliation.

It must not silently delete or substitute the approver.

The source design explicitly calls for this behavior. 

---

# 46. Approval does not guarantee synchronization acceptance

Local approval means:

> The workstation considered the action authorized under its available authority and policy.

It does not guarantee that central reconciliation will find no conflict.

For example:

```text
locally valid approval
+
centrally revoked approver
=
completed originating fact
+
reconciliation condition
```

These concerns remain separate.

---

# 47. Controlled action ownership

Approvals authorizes actions.

It does not own their business effects.

For example:

```text
Pricing
owns the selling-price change.

Approvals
owns authorization of the requested change.
```

Similarly:

```text
Transaction Lines
owns the void.

Approvals
owns authorization if policy required it.
```

And:

```text
Cash Handling
owns the paid-out.

Approvals
owns authorization if policy required it.
```

---

# 48. Price-override integration

Pricing supplies the action context.

Example:

```text
action_type = price_override
subject     = transaction_line

reference_unit_price = 1600
requested_selling_unit_price = 1200
quantity = 2
```

Approvals evaluates the request.

Pricing retains the historical:

* reference price;
* selling price;
* reason/source;
* performer.

Approval retains the authorization fact.

---

# 49. Line-void integration

Transaction Lines owns the void.

Approval context may include:

```text
action_type = line_void
line
quantity
line value
performer
reason if applicable
```

If policy returns `direct`, void proceeds.

If `approval_required`, second actor must approve.

If `prohibited`, void is blocked.

---

# 50. Transaction-cancellation integration

Transactions owns cancellation.

Policy may distinguish, for example:

* low-value/trivial transaction;
* transaction with substantial line value;
* transaction with prior tender activity;
* other risk dimensions.

The exact cancellation policy is not defined here.

---

# 51. Open-ring integration

Transaction Lines owns open-ring creation.

Policy may use inputs such as:

* entered value;
* department;
* reason;
* quantity;
* total line amount.

Approvals controls authorization where required.

This avoids hard-coding manager approval directly into the Open Ring implementation.

---

# 52. Discount integration

Discounts owns:

* discount type;
* amount;
* percentage;
* eligibility;
* calculation.

Approvals receives the resulting controlled-action context.

Example:

```text
action_type = transaction_discount

eligible_basis_cents = 15000
requested_percentage = 10%
discount_cents = 1500
```

If the cashier changes to:

```text
25%
```

the previous 10% approval no longer matches.

---

# 53. Cash paid-out integration

Cash Handling owns the physical cash movement.

Approval context may include:

```text
action_type = cash_paid_out
source = drawer_session
amount_cents = 15000
reason = ...
```

Approval authorizes the movement.

It does not itself change the cash balance.

---

# 54. Cash transfer/drop integration

A drawer-to-safe drop or other internal cash transfer remains a Cash Handling fact.

Approval may be required based on:

* amount;
* source/destination;
* purpose;
* store policy.

Approval must not cause the cash movement to be duplicated as some separate financial transaction.

---

# 55. Variance integration

Drawer/safe reconciliation owns:

```text
expected
counted
variance
```

Approval may represent acknowledgment of a significant variance.

Important invariant:

> **Approving a variance does not change the variance.**

For example:

```text
Expected: $500
Counted:  $480
Variance: -$20
Manager approval: yes
```

still means:

```text
Variance = -$20
```

Approval records review, not financial correction.

---

# 56. Return integration

Return policy may require approval for:

* unlinked return;
* outside-window return;
* alternate refund method;
* other exception cases.

The Return domain defines the exception and requested financial effect.

Approvals determines whether the exception may proceed.

The existing design specifically expects stronger permission/reason/approval for unlinked returns. 

---

# 57. Approval action catalog

A conceptual initial catalog might include:

| Action                 | Likely delivery                            |
| ---------------------- | ------------------------------------------ |
| `price_override`       | Phase 6.1                                  |
| `line_void`            | Phase 5 basic / Phase 6.1 policy expansion |
| `transaction_cancel`   | Phase 6.1 policy expansion                 |
| `open_ring`            | Phase 6.1                                  |
| `line_discount`        | Phase 6.3                                  |
| `transaction_discount` | Phase 6.3                                  |
| `cash_paid_out`        | Phase 6.5                                  |
| `cash_transfer`        | Phase 6.5                                  |
| `cash_drop`            | Phase 6.5                                  |
| `drawer_variance`      | Phase 6.5                                  |
| `unlinked_return`      | Phase 6.4                                  |
| `alternate_refund`     | Phase 6.4                                  |
| `post_void`            | Later/Phase 6                              |

This is an initial design catalog, not a locked enum list.

---

# 58. Reason catalog

Reasons should also be application-defined rather than arbitrary free text alone where structured reporting matters.

Conceptually:

```text
reason code
display name
applicable action types
active
```

Free-text notes may supplement the structured reason.

The reason catalog may be shared across selected action types, but each owning domain determines whether a reason makes sense.

---

# 59. Policy evaluation result

A conceptual authorization result may include:

```text
PolicyEvaluation
├── action_type
├── result
│   ├── direct
│   ├── approval_required
│   └── prohibited
├── policy identity/version
├── evaluated values
└── optional explanation/context
```

The precise machine contract should be defined later.

---

# 60. Approval fact

Conceptually, a granted approval may contain:

```text
Approval
├── id
├── action_type
├── subject
├── action identity/fingerprint
├── approved action snapshot
├── performed_by
├── approved_by
├── approved_at
├── policy identity/version
├── approver authority/version
└── reason/context where applicable
```

The exact schema is intentionally not locked here.

---

# 61. Approval identity

Every durable approval fact should have its own stable identifier.

An approval should be independently referable for:

* transaction history;
* audit;
* reporting;
* reconciliation;
* investigation.

This does not require approval to be a standalone aggregate independent of its business action; exact persistence remains an implementation choice.

---

# 62. Approval timestamp

`approved_at` records when the approver authorized the action.

It is distinct from:

* request time;
* business action execution time;
* transaction completion time;
* synchronization time.

For an offline approval, synchronization does not rewrite `approved_at`.

---

# 63. Approval expiration

ShelfSense should not introduce arbitrary time-based approval expiration unless the relevant workflow requires it.

The important initial validity condition is:

```text
approval still matches the material request
```

not:

```text
approval happened fewer than N minutes ago
```

A future action may add a defined temporal validity requirement explicitly.

---

# 64. Approval reuse

An approval must not normally be reused for:

* another transaction line;
* another transaction;
* another cash movement;
* another amount;
* another requested value.

The approval applies to one controlled request.

---

# 65. Approval copying

Copying or duplicating a transaction/action must not automatically copy valid approval authorization to the new business object.

A copied action constitutes a new request and requires fresh policy evaluation.

---

# 66. Suspended transactions

When a transaction is suspended, working approval state may remain associated with the suspended work.

On recall, approvals must be revalidated against the current material action values and refreshed underlying state.

For example, if pricing changes cause the override variance to change, an old approval may no longer be valid.

Exact suspend/recall revalidation rules remain pending in the Transactions/Pricing specs.

---

# 67. Voiding an approved action

If a working action is later removed before completion—for example, an approved discount is removed—the historical working activity may remain auditable, but the approval no longer authorizes anything active.

It must not become available for reuse elsewhere.

---

# 68. Approval and transaction completion

For transaction-scoped actions, approval facts relevant to the final completed transaction should be committed atomically with the transaction.

Conceptually:

```text
valid working approval
        ↓
CompleteTransaction validation
        ↓
freeze approved action
freeze approval evidence
        ↓
COMMIT
```

A completed transaction must not end up with an active controlled action whose required approval disappeared during completion.

---

# 69. Non-transaction approvals

Not all approvals belong to `CompleteTransaction`.

Examples include:

* cash paid-out;
* cash transfer;
* drawer variance acceptance.

For these actions, approval should be committed with the authoritative business operation it authorizes.

Same invariant:

> **The approved business action and the historical approval evidence must not diverge.**

---

# 70. Immutability

After the authorized business action becomes an immutable completed fact, the corresponding approval evidence is immutable.

Do not edit historical approval records to say:

* a different manager approved it;
* a different value was approved;
* today's policy would have produced another outcome.

If an approval record itself was erroneous or fraudulent, that should be handled through an explicit audit/correction/investigation mechanism, not ordinary editing.

---

# 71. Audit requirements

Approval activity should support audit of:

* action type;
* subject;
* performer;
* approver;
* requested values;
* policy result;
* reason;
* approval time;
* completion/execution outcome;
* offline authority context;
* later reconciliation state where relevant.

This is operational evidence, not necessarily a duplicate of the generic application `audit_events` record.

The POS approval fact is part of the business explanation of what occurred.

---

# 72. Reporting requirements

Approval reporting should support analysis by:

* store;
* workstation;
* business date;
* cashier/performer;
* approver;
* action type;
* reason;
* department/merchandise where applicable;
* financial amount;
* percentage;
* policy outcome;
* offline/online context;
* reconciliation result.

This aligns with the broader POS reporting model, which expects approver as an analytical dimension. 

---

# 73. Loss-prevention reporting

Approvals should support questions such as:

* Which cashiers request the most price overrides?
* Which managers approve the most overrides?
* What is the dollar value of approved override variance?
* Which stores have unusually high void approval rates?
* Which approvals occurred offline?
* Which controlled actions later produced reconciliation warnings?

Approval data therefore needs to remain structured rather than surviving only as free-text audit notes.

---

# 74. Reference replication

The workstation needs locally cached information sufficient to evaluate controlled actions offline.

This may include:

* applicable action-policy definitions;
* organization/store policy overrides;
* performer/approver permission projection;
* reason definitions;
* policy/configuration version.

Reference Replication owns how those records reach SQLite.

Approvals owns their business meaning.

---

# 75. Policy freshness

A workstation may operate on stale cached policy while genuinely offline.

If a completed action was authorized under the workstation's valid cached policy:

* the originating historical fact is preserved;
* synchronization compares it with central knowledge;
* any discrepancy becomes a reconciliation condition.

ShelfSense must not centrally rewrite the transaction to pretend a different approval process occurred.

---

# 76. Synchronization

Completed approval evidence needed to explain an originating operation must accompany or be reproducibly associated with that operation.

For example, the completed-sale operation may need to carry the applicable approval snapshots for:

* price override;
* discount;
* open ring;
* return exception.

Exact payload structure belongs to the operation contract.

---

# 77. Reconciliation

Potential approval-related reconciliation conditions include:

```text
unknown approver
revoked approver
stale permission version
stale policy version
missing required approval
approval action mismatch
unsupported action/policy version
```

Reconciliation owns the central outcome taxonomy.

Approvals owns the historical meaning of the local authorization evidence.

---

# 78. Structural invalidity versus stale authority

These should be distinguished.

### Example A — stale authority

The POS legitimately records:

```text
Approver B
cached permission version 12
```

but B had been centrally revoked while the POS was offline.

That is an offline business conflict.

### Example B — structurally invalid

The payload says:

```text
approval_required
```

but contains no approver identity or approval evidence.

That may be structurally invalid for the claimed completed action.

Exact server handling belongs to the synchronization/reconciliation contract.

---

# 79. Domain ownership

## Approvals owns

* permission versus policy distinction;
* policy outcome model;
* controlled action abstraction;
* approval scope;
* action/value binding;
* second-actor semantics;
* performer/approver distinction;
* invalidation;
* policy inheritance;
* offline approval semantics;
* historical approval evidence;
* reporting/audit dimensions.

## Owning business domains own

The requested business action and its effects.

Examples:

* Pricing → price override;
* Transaction Lines → line void/open ring;
* Discounts → discounts;
* Transactions → cancellation;
* Cash Handling → paid-outs/transfers/variance;
* Returns → return/refund exceptions.

## Workstation Identity/Auth owns

* POS credential verification;
* user identity;
* cached authentication mechanism.

## Reference Replication owns

* delivery of policies/permissions/reasons to workstation.

## Reconciliation owns

* central handling of stale/conflicting authorization state.

---

# 80. Conceptual domain model

Without locking schema:

```text
Controlled Action
│
├── action_type
├── subject
├── performed_by
├── requested values
├── reason/context
├── requested_at
│
└── Policy Evaluation
    ├── policy/version
    └── outcome
        ├── direct
        ├── approval_required
        └── prohibited

if approval_required:

Approval
├── id
├── controlled-action identity
├── approved action snapshot/fingerprint
├── approved_by
├── approved_at
├── approver authority/version
└── policy/version
```

This is a conceptual responsibility model rather than a migration specification.

---

# 81. Why approval should not be a few columns on every object

ShelfSense should avoid separately adding:

```text
approved_by
approved_at
approval_reason
```

to every:

* transaction line;
* discount;
* cash movement;
* return;
* drawer count.

That pattern makes each domain invent its own approval semantics.

Instead:

> **Business objects retain their own actors/reasons/effects, while a common approval model records authorization of controlled actions.**

Physical denormalization may still be appropriate later for specific query/performance reasons, but it should not define the domain model.

---

# 82. Delivery by phase

## Phase 4

Phase 4 needs only enough authorization architecture to support:

* actor identity;
* permission/configuration versioning;
* completed-operation contract extensibility;
* offline reference projection shape.

No broad approval UI is required.

---

## Phase 5

The narrow Phase 5 regular-price Cash sale intentionally avoids most controlled actions.

Basic line void may initially operate under simple direct permission policy.

Phase 5 should not build a generalized supervisor workflow merely for future features.

However, the data/contract architecture must not make later approval impossible.

---

## Phase 6.1

First substantial Approval implementation.

Required for:

* price override;
* richer line void policy;
* transaction cancellation policy;
* open rings where policy requires.

Implement:

* action catalog;
* policy evaluation;
* second-actor PIN workflow;
* action binding;
* invalidation;
* offline approval;
* completed approval snapshots;
* audit/reporting.

---

## Phase 6.3

Extend action catalog/policy to:

* line discounts;
* transaction discounts;
* coupons/manual adjustment cases as applicable.

---

## Phase 6.4

Extend to:

* unlinked returns;
* return exceptions;
* alternate refund methods;
* post-void if implemented.

---

## Phase 6.5

Extend to:

* paid-outs;
* cash transfers/drops as needed;
* variance acknowledgment;
* other controlled cash operations.

---

# 83. Pending decisions

## 83.1 Concrete policy persistence model

Decide whether policies are represented using:

* one common policy table with typed action configurations;
* action-specific policy tables;
* another constrained model.

Do not create an unrestricted expression engine.

---

## 83.2 Initial action catalog

Lock action identifiers before Phase 6.1 implementation.

---

## 83.3 Permission catalog

Define corresponding:

```text
perform
approve
```

permissions for supported controlled actions.

---

## 83.4 Initial numeric thresholds

Define organization defaults and any store overrides for:

* price override;
* line void;
* transaction cancellation;
* open ring;
* discounts;
* paid-outs;
* variances;
* return exceptions.

These can be introduced alongside each capability rather than all at once.

---

## 83.5 Reason requirements

For each action, determine:

```text
reason never required
reason always required
reason policy-dependent
```

independently of second-actor approval.

---

## 83.6 Policy-version semantics

Determine the durable version/revision representation that the workstation and completed facts preserve.

---

## 83.7 Action canonicalization/fingerprint

If a deterministic fingerprint is used, lock:

* included fields;
* field order/canonical representation;
* schema version;
* hash algorithm if applicable.

This belongs in the machine contract, not this domain specification.

---

## 83.8 Quantity-change invalidation

For price override/discount approval, define exactly which quantity changes invalidate approval.

Recommended rule:

> Any quantity change that changes the financial effect of the approved action requires re-evaluation.

---

## 83.9 Transaction change invalidation

For transaction-level discounts or approvals, define which basket mutations require re-evaluation.

For example:

* added line;
* removed line;
* changed eligible basis;
* changed return/sale mixture.

---

## 83.10 Approval-request persistence

Determine whether awaiting-approval requests are persisted as durable working records or represented only through the underlying working business action plus activity state.

---

# 84. Core invariants summary

The following rules are authoritative unless explicitly superseded:

1. **Permission and approval policy are different concepts.**
2. **Policy outcomes are `direct`, `approval_required`, or `prohibited`.**
3. **Approval authorizes one exact requested action, not broad temporary authority.**
4. **Second-actor approval does not log the cashier out or make the approver the transaction operator.**
5. **`performed_by` and `approved_by` are distinct facts.**
6. **Where a second actor is required, `approved_by != performed_by`.**
7. **A sufficiently authorized performer should execute directly rather than create artificial self-approval.**
8. **Approval binds to the subject and material requested values.**
9. **A material request change invalidates the prior approval.**
10. **Each action type explicitly defines the values material to approval.**
11. **Reason and approval are independent requirements.**
12. **Approval does not own the underlying business action or its financial effect.**
13. **ShelfSense uses application-defined action types, not an unrestricted expression engine.**
14. **When multiple policy dimensions apply, the stricter outcome controls.**
15. **Organization defaults with optional store overrides are preferred.**
16. **Per-user numeric authority limits are avoided initially.**
17. **Approvals must work offline for offline-permitted actions.**
18. **Offline approval preserves cached approver/policy authority context.**
19. **Central revocation discovered later does not rewrite the historical approver.**
20. **Before completion, approval validity may change as working state changes.**
21. **Completion validates that required approvals match current action state.**
22. **Completed approval evidence is immutable.**
23. **Approval of a variance does not change the variance.**
24. **Approval of an action does not update master data or create unrelated business effects.**
25. **Approval must not be reused automatically for a different request.**

---

# 85. Acceptance examples

## Example A — direct price override

Given:

```text
Cashier has price-override perform permission
Requested override variance = 3%
Store policy:
  <= 5% → direct
```

when the cashier requests the override,

then:

* policy evaluates `direct`;
* no second-actor approval is required;
* pricing may apply the override;
* performer/reason/policy context remain auditable.

---

## Example B — price override requiring approval

Given:

```text
Requested override:
$16 → $12
```

and policy evaluates:

```text
approval_required
```

when Supervisor B authenticates and has approval permission,

then:

* B approves the exact `$16 → $12` request;
* B does not become the cashier;
* the override may be applied;
* approval evidence references that exact action.

---

## Example C — approved price changes

Given Supervisor B approved:

```text
$16 → $12
```

when the cashier changes the request to:

```text
$16 → $8
```

then:

* the prior approval no longer satisfies the action;
* policy is re-evaluated;
* a new approval is required if the new request permits approval.

---

## Example D — prohibited override

Given policy says:

```text
variance > 50% → prohibited
```

when the cashier requests a 60% override,

then:

* no approval prompt can make the action valid;
* the request is blocked.

---

## Example E — manager operating register

Given Manager M is the transaction cashier and has sufficient direct authority,

when M requests an action within that direct authority,

then:

* policy returns `direct`;
* ShelfSense does not create an approval where `performed_by = approved_by`.

---

## Example F — duplicate-scan void

Given store policy allows immediate low-value line void directly,

when the cashier voids an accidental duplicate scan,

then:

* no reason may be required;
* no second actor is required;
* the void remains an auditable business action.

---

## Example G — reason without approval

Given all price overrides require a reason but small overrides are direct,

when the cashier performs a 2% override,

then:

```text
reason = required
approval = not required
```

The reason requirement does not imply manager approval.

---

## Example H — transaction discount change

Given Supervisor B approves:

```text
10% transaction discount
eligible basis = $150
discount = $15
```

when the cashier changes the discount to 20%,

then:

* the original approval is invalid;
* policy evaluates the new request;
* another approval is required as applicable.

---

## Example I — paid-out approval

Given:

```text
Paid-out = $150
Reason = emergency supplies
```

and policy requires second-actor approval,

when Manager B approves,

then:

* the approval authorizes that exact `$150` paid-out;
* Cash Handling records the actual physical movement;
* Approval itself does not alter expected cash independently.

---

## Example J — drawer variance approval

Given:

```text
Expected = $500
Counted  = $480
Variance = -$20
```

and variance policy requires manager acknowledgment,

when the manager approves,

then:

* variance remains `-$20`;
* approval records that the discrepancy was reviewed;
* ShelfSense does not create an automatic `$20` balancing adjustment.

---

## Example K — offline approval with later revocation

Given:

1. Supervisor B is cached as authorized;
2. workstation loses connectivity;
3. central administrator revokes B;
4. B approves a locally permitted action before the workstation knows of revocation;
5. the transaction completes;

when synchronization later occurs,

then:

* the historical approval still identifies B;
* cached authority/version is preserved;
* reconciliation classifies the stale-authority condition;
* ShelfSense does not rewrite the completed transaction.

---

## Example L — copied transaction/action

Given Line X has an approved override,

when the line/business action is duplicated into a distinct new request,

then:

* the old approval does not automatically carry forward;
* the new request undergoes policy evaluation independently.

---

# 86. Related workflow specifications

This specification should eventually be referenced by:

* `workflows/approvals/second-actor-approval.md`
* `workflows/adjustments/price-override.md`
* `workflows/sales/void-line.md`
* `workflows/sales/cancel-transaction.md`
* `workflows/sales/open-ring.md`
* `workflows/adjustments/line-discount.md`
* `workflows/adjustments/transaction-discount.md`
* `workflows/cash/paid-out.md`
* `workflows/cash/cash-drop.md`
* `workflows/cash/cash-transfer.md`
* `workflows/cash/drawer-variance-approval.md`
* `workflows/returns/unlinked-return.md`
* `workflows/returns/post-void.md`

---

# 87. Related contracts

The Approval domain will eventually need machine contracts for:

### Controlled action context

Exact representation of:

```text
action_type
subject
performed_by
material action values
reason/context
policy/version
```

### Policy evaluation

Exact representation of:

```text
direct
approval_required
prohibited
```

### Approval fact

Exact representation of:

```text
action identity
approved action snapshot
approved_by
approved_at
authority/version
policy/version
```

### Action canonicalization

If a fingerprint/hash is used, define exact canonical material fields and versioning.

### Completed operation payload

Define how approval evidence is represented inside or alongside terminal-originated completed operations.

This domain specification defines **what an approval means**.

Those contracts will define **how ShelfSense reliably represents the same approval semantics in .NET, SQLite, synchronization payloads, and Rails**.

---

## One adjustment I would now make to `pricing.md`

Now that this domain boundary is explicit, I would revise pricing language from something conceptually like:

```text
price override stores:
  performed_by
  approved_by
  approval time
```

to:

> **Pricing owns the requested/reference/selling price and override reason/context. When policy requires approval, the override is authorized by an Approval-domain fact bound to that exact price-override request.**

Likewise, `transaction-lines.md` should say that a void may be **subject to** an approval fact, rather than treating approval as an intrinsic property of every line.

That keeps us from slowly rebuilding approval logic independently inside each POS domain.
