# ShelfSense POS Specifications

This directory contains the durable domain and architectural specifications for the ShelfSense point-of-sale system.

These documents define **what POS concepts mean, which subsystem owns them, and which invariants must remain true across implementations**.

They are intentionally broader than any single implementation phase. Phase plans select subsets of these specifications for delivery; they do not redefine the underlying domain rules.

---

## Documentation model

ShelfSense separates architectural decisions, domain rules, workflows, contracts, and implementation plans.

```text
ADR
  ↓
Why was this architectural direction chosen?

Domain specification
  ↓
What does this concept mean?
What owns it?
What invariants apply?

Workflow specification
  ↓
How do multiple domain concepts cooperate
to perform a business operation?

Contract
  ↓
What exact data and behavior cross a boundary?

Phase / implementation plan
  ↓
Which subset are we building now,
and how will we implement it?
````

A business rule should have one authoritative home.

When a phase implements only part of a domain specification, the phase plan should reference the specification and identify the supported subset rather than copying or redefining the durable rule.

---

# Core POS architecture

ShelfSense POS is designed as an offline-capable peer to the organization server.

The basic authority model is:

```text
Organization Server
├── centrally mastered reference data
├── consolidated transaction history
├── authoritative inventory ledger
└── organization/store reporting

            ⇅ synchronization

POS Installation
├── durable local SQLite state
├── replicated reference projection
├── working transaction state
├── locally completed operations
└── transactional outbox
```

A supported POS operation completes against durable local state.

Network synchronization happens afterward.

```text
work locally
    ↓
validate
    ↓
atomic SQLite commit
    ├── completed business facts
    ├── receipt identity
    └── outbox operation
    ↓
customer/peripheral actions
    ↓
later synchronization
    ↓
central consolidation
```

The organization server remains authoritative for centrally mastered reference data and consolidated domain state, but a disconnected workstation can temporarily hold completed originating facts that the server has not yet received.

---

# Specification map

## Transaction model

### [Transactions](transactions.md)

Defines the POS transaction lifecycle, ownership, mutability, completion boundary, cancellation, suspension, and immutable completed state.

This is the root specification for most cashier activity.

### [Transaction Lines](transaction-lines.md)

Defines what transaction lines represent, including:

* merchandise versus open-ring lines;
* sale versus return direction;
* quantity-tracked versus individually tracked merchandise;
* active versus voided lines;
* line consolidation.

Transaction Lines describes **what is being transacted**. Pricing, Discounts, Tax, Returns, and Inventory Integration build on that model.

---

## Commercial calculation

### [Pricing](pricing.md)

Defines:

* reference price;
* selling price;
* price-source resolution;
* price overrides;
* historical price snapshots;
* stale/offline pricing behavior.

Pricing establishes the amount before discounts and tax.

### [Discounts](discounts.md)

Defines line and transaction discounts, allocation, discount sources, ordering, historical reversal, and the relationship between discounts and promotions.

The calculation sequence is conceptually:

```text
reference price
→ optional price override
→ selling price
→ discounts
→ net merchandise amount
→ tax
```

### [Tax](tax.md)

Defines POS tax treatment, store tax rules, tax components, effective dating, calculation and rounding, historical snapshots, and return reversal.

Tax uses the completed post-discount merchandise basis and preserves the tax treatment actually applied when the transaction occurred.

### Tenders

Defines how the signed transaction obligation is settled through:

* Cash;
* Card;
* Check;
* Stored Value;
* Other.

Tender semantics remain separate from what was sold and from physical Cash custody.

> **Repository note:** the current `tender.md` should be normalized into the formal POS Domain Specification format.

---

## Controlled actions and exceptions

### [Approvals](approvals.md)

Defines authorization of controlled POS actions such as:

* price overrides;
* discounts;
* line voids;
* transaction cancellation;
* open rings;
* Cash movements;
* exceptional returns.

The Approval domain separates:

```text
permission
policy
requested action
approval fact
```

An approval authorizes one sufficiently defined action; it does not become part of Pricing, Discounts, Cash Handling, or other owning domains.

---

## Returns

### Returns

Defines linked and unlinked returns, historical financial reversal, returnable quantity, individual-unit returns, refunds, exchanges, and the relationship between returns and inventory.

A return is a new POS fact that reverses all or part of an earlier sale. It never edits the original completed transaction.

> **Repository note:** the current file is named `returns` and should be renamed `returns.md`.

---

# Register operation

## [Cash Handling](cash-handling.md)

Defines physical Cash accountability, including:

* drawer sessions;
* opening float;
* expected Cash;
* physical counts;
* variance;
* paid-ins and paid-outs;
* drops and replenishments;
* internal Cash transfers;
* eventual safe/deposit custody.

Cash Handling is distinct from Cash tendering:

```text
Cash Tender
→ how the customer settled

Cash Handling
→ where physical Cash should be
  and what was actually counted
```

Bank-deposit tracking may build on this custody chain later.

---

## [Reporting Periods](report-period.md)

Defines operational grouping and settlement of POS activity through:

* `occurred_at`;
* `business_date`;
* workstation Z periods;
* Z totals;
* central reporting aggregation;
* optional Store Close snapshots.

The workstation Z is the primary register-level settlement checkpoint.

Store and organization reports may aggregate detailed synchronized transaction facts directly; they do not require a mandatory centrally authoritative Store Day entity.

> **Repository note:** consider renaming `report-period.md` to `reporting-periods.md` to match the domain name used throughout the specifications.

---

## [Receipts](receipts.md)

Defines the permanent customer-facing identity and representation of a completed POS transaction.

Receipt identity is:

```text
store
+
logical workstation
+
workstation receipt sequence
```

Receipt identity is assigned locally at transaction completion and survives:

* offline operation;
* synchronization;
* application restart;
* installation replacement;
* reprinting.

Printing is a post-commit delivery operation and cannot determine transaction completion.

---

# Offline runtime and synchronization

## [Workstation Identity](workstation-identity.md)

Defines the distinction between:

```text
logical workstation
```

and:

```text
POS installation
```

A workstation is the durable business/register identity.

An installation is the concrete authenticated POS runtime and local-state instance currently operating that workstation.

A workstation may have at most one active installation authorized to originate new POS activity at a time.

---

## [Local Persistence](local-persistence.md)

Defines the local durability boundary.

The POS SQLite database contains durable operational state rather than merely disposable cache data.

Its central guarantee is:

> Once ShelfSense reports an operation as completed, its completed facts and durable synchronization path have already committed locally.

The specification defines:

* installation/database ownership;
* originating versus replicated state;
* atomic completion;
* transactional outbox;
* restart guarantees;
* reference-state atomicity;
* recovery-required behavior when local state cannot be trusted.

---

## [Reference Replication](reference-replication.md)

Defines server-to-POS distribution of centrally mastered reference data.

```text
Organization Server
        ↓
snapshot / incremental changes
        ↓
POS reference projection
```

It covers:

* initial snapshots;
* incremental updates;
* cursors;
* tombstones/deactivation;
* effective-dated reference data;
* atomic local application;
* stale offline reference use.

The POS projection is purpose-built for POS operation and is not intended to mirror the Rails database.

---

## [Operation Synchronization](operation-synchronization.md)

Defines POS-to-server delivery of already completed workstation operations.

```text
local completion
        ↓
transactional outbox
        ↓
operation synchronization
        ↓
central acceptance / reconciliation
```

It defines:

* stable operation identity;
* installation authentication;
* payload identity;
* idempotent retry;
* durable acknowledgment;
* central acceptance boundaries.

Synchronization does **not** determine whether the transaction was locally completed.

---

## [Reconciliation](reconciliation.md)

Defines how ShelfSense handles understood originating facts that conflict with central state or other originating facts.

Its governing rule is:

> **Preserve what happened, identify what disagrees, and correct through new facts rather than rewriting the past.**

Reconciliation tracks:

* discrepancy type;
* affected subject/operations;
* severity;
* resolution state;
* corrective-action linkage.

The owning business domain performs the actual correction.

Transport retries and malformed protocol messages are synchronization concerns, not reconciliation conditions.

---

# Inventory boundary

## [Inventory Integration](inventory-integration.md)

Defines the POS/Inventory boundary.

```text
POS
→ records what was sold or returned

Inventory
→ records what that means for stock and valuation
```

The organization inventory ledger remains authoritative.

The POS maintains only the effective local view needed for offline operation, conceptually:

```text
accepted server checkpoint
+
applicable unacknowledged local effects
=
effective local inventory
```

This specification also defines quantity-tracked sales, individually tracked units, negative inventory behavior, linked return effects, and idempotent central inventory posting.

---

# Presentation

## Customer Display

Defines an optional, non-authoritative customer-facing display.

The intended authority model is:

```text
Authoritative POS
        ↓
presentation-ready state
        ↓
Customer Display
```

A customer display must never become part of transaction calculation or completion authority.

POS operation remains fully functional without it.

> **Repository note:** `customer-display.md` currently exists as a placeholder and still needs the domain-spec content added.

---

# How the specifications fit together

A normal sale crosses several specifications:

```text
Workstation Identity
        ↓
Local Persistence
        ↓
Reference Replication
        ↓
Transactions
        ↓
Transaction Lines
        ↓
Pricing
        ↓
Discounts
        ↓
Tax
        ↓
Tenders
        ↓
Completion
   ┌────┼───────────────┐
   ↓    ↓               ↓
Receipt Inventory       Outbox
        Integration        ↓
                     Operation Sync
                           ↓
                     Reconciliation
                     when necessary
```

These are domain boundaries, not necessarily separate processes or services.

---

# Recommended reading order

For understanding the basic POS model:

1. [Transactions](transactions.md)
2. [Transaction Lines](transaction-lines.md)
3. [Pricing](pricing.md)
4. [Discounts](discounts.md)
5. [Tax](tax.md)
6. Tenders
7. [Approvals](approvals.md)
8. Returns

For understanding register operation:

1. [Workstation Identity](workstation-identity.md)
2. [Cash Handling](cash-handling.md)
3. [Reporting Periods](report-period.md)
4. [Receipts](receipts.md)

For understanding offline architecture:

1. [Workstation Identity](workstation-identity.md)
2. [Local Persistence](local-persistence.md)
3. [Reference Replication](reference-replication.md)
4. [Operation Synchronization](operation-synchronization.md)
5. [Reconciliation](reconciliation.md)
6. [Inventory Integration](inventory-integration.md)

---

# Delivery relationship

The specifications describe the intended domain model across multiple roadmap phases.

They should not be interpreted as requiring every described capability in the first POS release.

## Phase 4 — POS Runtime and Contract Foundation

Phase 4 establishes the distributed/offline architecture:

* workstation and installation identity;
* SQLite durability;
* reference replication;
* deterministic transaction calculation;
* transactional outbox;
* operation synchronization;
* idempotent central processing;
* initial Inventory integration.

The goal is architectural proof, not a production-ready cash register.

## Phase 5 — First Operational Cash Sale

Phase 5 applies the foundation to one narrow production workflow:

```text
authenticate cashier
→ open register context
→ scan quantity-tracked merchandise
→ regular configured price
→ calculate tax
→ accept Cash
→ complete locally
→ assign/print receipt
→ update inventory
→ synchronize later
→ close drawer / Z
```

Phase 5 deliberately excludes broad price adjustment, discount, return, and tender functionality.

## Phase 6 — Core POS Operations

Phase 6 expands the stable transaction architecture with:

* merchandise breadth;
* individually tracked units;
* transaction corrections;
* additional tenders;
* discounts/promotions;
* returns/exchanges;
* full Cash handling;
* expanded Z/reporting;
* productization.

Later domains should integrate through these established POS boundaries rather than redefining the transaction architecture.

---

# Specification conventions

Each domain specification should normally identify:

```text
Design status
Implementation status
Initial delivery
Expanded delivery
Related specifications
Related workflows
Related contracts
```

The body should define, as appropriate:

* purpose and scope;
* terminology;
* domain authority;
* lifecycle/state;
* invariants;
* business rules;
* offline behavior;
* immutability/correction rules;
* authorization considerations;
* synchronization behavior;
* pending decisions;
* acceptance examples.

Not every document needs identical headings if the domain does not require them.

---

# Status language

Status metadata describes different dimensions and should not be conflated.

### Design status

Describes how settled the domain model is.

Examples:

* `Decided`
* `Core behavior decided; advanced policy pending`
* `Proposed`

### Implementation status

Describes how much of the specification currently exists in code.

A domain may be fully designed but not yet implemented.

### Initial / expanded delivery

Identifies the roadmap phase expected to implement a particular subset of the durable specification.

A later delivery phase does not make the earlier domain rules non-authoritative.

---

# Changing a specification

When implementation reveals that a durable domain rule should change:

1. identify the specification or ADR that currently owns the rule;
2. update or supersede that authority deliberately;
3. update affected workflows/contracts;
4. update the implementation/phase plan to reference the new rule;
5. add or modify tests/contract fixtures that prove the new behavior.

Do not resolve inconsistencies by adding a contradictory rule only to a phase plan.

---

# Pending decisions

Individual specifications contain their own pending decisions.

A pending decision means:

> The domain has intentionally left this behavior open until the relevant delivery phase or workflow requires it.

It does not mean implementations may choose arbitrary behavior.

Before implementing functionality dependent on a pending decision, resolve it in the owning specification or contract first.

---

# Related documentation

POS specifications should be read alongside:

```text
docs/adr/
    architectural decisions and rationale

docs/specifications/pos/workflows/
    cross-domain operational workflows

docs/contracts/pos/
    exact POS/server and calculation boundaries

docs/planning/
    roadmap and phase-specific delivery scope
```

The governing relationship is:

> **ADRs explain why. Specifications define what. Workflows define how concepts cooperate. Contracts define exact boundaries. Phase and implementation plans define what is being built now.**

```

### Repository cleanup I would do alongside it

I would normalize these before treating the directory as finished:

1. Rename `report-period.md` → `reporting-periods.md`; its actual title is already **Reporting Periods**. 
2. Rename `returns` → `returns.md`; the contents are already the formal Returns domain spec. 
3. Replace `tender.md` with the formal `tenders.md` draft we developed; the checked-in file is still discussion text rather than a specification. 
4. Populate `customer-display.md`; it is currently a zero-byte placeholder. 
5. Consider normalizing the metadata blocks in `transactions.md` and `transaction-lines.md`: their status fields are currently run together on one physical line, unlike newer specs such as Approvals.   

The README itself should stay relatively stable even as individual specs evolve; its main job is to explain **where to look and which document owns what**, not duplicate the detailed rules. 
```
