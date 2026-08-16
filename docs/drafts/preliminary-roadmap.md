# ShelfSense POS Roadmap — Phases 4–6

## Purpose

Phases 4–6 establish ShelfSense as an offline-capable, separately deployable point-of-sale system without requiring the first POS increment to implement the entire workstation product defined by ADR-018.

The progression is:

```text
Phase 4
POS runtime + contracts + synchronization foundation
        ↓
Phase 5
First real operational cash sale
        ↓
Phase 6
Core POS operations + productization
```

The governing distinction is:

> **Phase 4 proves the peer architecture. Phase 5 proves one usable sale. Phase 6 expands that sale path into a complete operational POS and then productizes it across supported environments.**

ADR-018 defines the target POS workstation architecture. Its existence does **not** imply that every capability described by the ADR belongs in Phase 4 or Phase 5.

---

# Phase 4 — POS Runtime and Contract Foundation

## Objective

Establish and validate the workstation/server architecture required for an offline-capable POS client.

At the end of Phase 4, ShelfSense should be able to prove that a POS workstation can:

> enroll, receive reference data, deterministically calculate a representative sale, durably commit an immutable local operation and outbox entry, restart safely, synchronize that operation to Rails, replay it without duplication, and produce exactly one authoritative server inventory effect.

Phase 4 is **not a usable cashier register**.

---

## Phase 4.0 — Runtime Validation Spike

Phase 4.0 is a short validation activity, not a separate roadmap phase.

Its purpose is to validate the implementation assumptions already selected in ADR-018:

* .NET;
* Terminal.Gui;
* SQLite;
* self-contained workstation application;
* HTTPS synchronization with Rails.

The spike does **not** reopen the runtime choice unless a concrete blocking issue is discovered.

### Prove

* .NET/Terminal.Gui application starts on one representative platform;
* application layering is practical;
* SQLite initializes and migrates correctly;
* `WAL` + `synchronous=FULL` behaves as expected;
* local transaction + outbox can commit atomically;
* forced termination before and after commit produces correct recovery behavior;
* application can restart and recover local state;
* workstation can perform one authenticated HTTPS round-trip with Rails;
* Terminal.Gui can support the intended command-oriented keyboard model.

### Non-goals

* polished cashier UI;
* real printer integration;
* cash drawer;
* offline cashier PIN product;
* full platform certification;
* production updater;
* customer display.

### Exit gate

If the spike identifies no blocking runtime issue, ADR-018 remains the governing accepted architecture.

If a genuine blocker is discovered, amend or supersede ADR-018 before substantial POS implementation proceeds.

---

# Phase 4.1 — POS Application Foundation

Create the actual workstation solution and establish clean architectural boundaries.

Suggested structure:

```text
ShelfSense.Pos
├── Presentation.Terminal
├── Application
├── Domain
├── Persistence.Sqlite
├── Sync
├── Platform
└── ContractTests
```

Implement:

* .NET LTS runtime baseline;
* Terminal.Gui application shell;
* SQLite persistence;
* local schema migration framework;
* one local database per workstation installation;
* single active POS process enforcement;
* machine-scoped durable POS state;
* structured logging and diagnostics;
* clean startup/shutdown handling;
* platform abstraction boundaries;
* keyboard-command abstraction independent of individual UI controls.

### Keyboard contract

Phase 4 should establish the command architecture, but not build the final cashier experience.

For example:

```text
Keyboard input
    ↓
POS command
    ↓
Application service
    ↓
Domain behavior
```

Terminal.Gui views must not contain authoritative transaction or financial logic.

### Phase 4 UI non-goal

> **Phase 4 must not be treated or demonstrated as a production cashier register.**

Any Terminal.Gui surfaces created during this phase exist only to exercise:

* commands;
* runtime state;
* configuration;
* diagnostics;
* synchronization.

Cashier usability belongs to Phase 5.

---

# Phase 4.2 — Workstation Installation and Enrollment

Implement the distinction between:

```text
logical workstation
        ↓
workstation installation
```

Server-side work should include:

* workstation installation persistence;
* enrollment service;
* revocation/deactivation;
* unique installation UUID;
* one active originating installation per logical workstation;
* installation authentication credential;
* last-seen/software metadata as useful.

Client-side work should include:

* local installation identity;
* secure credential storage using platform facilities where practical;
* association with store/workstation;
* startup validation of installation state.

Phase 4 does not need the full lost-machine/replacement UX, but the model must support it.

---

# Phase 4.3 — Rails POS Landing Model

Treat the Rails side as a first-class Phase 4 deliverable.

Implement the server structures and services necessary to receive one workstation-originated sale.

At minimum:

* workstation installation tables/services;
* reference projection/snapshot state;
* sync cursor/versioning state;
* accepted terminal-originated operation records;
* immutable accepted sale facts;
* idempotency persistence;
* payload hash comparison;
* acknowledgment state;
* minimal warning/quarantine representation;
* inventory-posting service integration.

The server must preserve the workstation-originated completed fact rather than reconstructing a different sale from current central configuration.

---

# Phase 4.4 — Reference Replication v1

Implement server → workstation replication sufficient for the first sale path.

Initial reference projection should include:

* store identity and required configuration;
* workstation configuration;
* product variants;
* identifiers;
* regular selling prices;
* departments/classification needed by POS;
* tax classes;
* effective store tax components/rates;
* cash tender configuration;
* enough actor identity to populate completed-operation proofs.

Phase 4 does **not** require a complete production offline cashier-authentication system.

Production-shaped cashier PIN/authentication belongs in Phase 5.

### Replication behavior

Support:

* full reference snapshot;
* schema/version metadata;
* cursor/version tracking;
* transactional application to SQLite;
* fresh-snapshot recovery when local state cannot continue incrementally.

Incremental replication may be implemented in Phase 4 or the contract may be established for subsequent implementation, depending on complexity, but the model must not assume full snapshot replacement forever.

---

# Phase 4.5 — Calculation Contract Pack v1

Define implementation-neutral financial contracts before Rails and .NET implementations diverge.

Create shared canonical fixtures consumed by both platforms.

Initial fixture scope:

* unit price;
* quantity extension;
* reference/selling-price representation;
* tax basis;
* supported initial tax components;
* deterministic rounding;
* subtotal;
* tax total;
* transaction total;
* cash amount presented;
* applied cash;
* change.

Example structure:

```text
contracts/pos/
├── pricing/
├── tax/
├── totals/
└── cash/
```

The invariant is:

> **Given identical inputs and configuration, Rails and .NET must produce identical authoritative cents.**

Phase 4 establishes the fixture format and test harness.

Later POS functionality extends the same contract pack rather than inventing separate test conventions.

---

# Phase 4.6 — Business-Date Contract

Define and implement the minimum business-date behavior required by completed transactions.

A completed workstation-originated transaction must contain:

* `occurred_at`;
* store timezone/configuration version;
* explicit `business_date`.

`business_date` should be derived according to the store's configured rules at completion.

Phase 4 does **not** require:

* Z-period implementation;
* drawer sessions;
* store daily finalization;
* missing-register completeness.

Those are separate concerns.

---

# Phase 4.7 — Completed Sale Operation Contract v1

Define the immutable operation envelope used by the workstation and server.

At minimum:

```text
operation_id
operation_type
payload_schema_version

store_id
workstation_id
installation_id

transaction_id
receipt_sequence
receipt_identity

actor_id
occurred_at
business_date

lines[]
tax_components[]
tenders[]

reference/configuration versions

idempotency_key
payload_hash
```

The completed payload must snapshot the facts needed to reproduce what occurred without recalculating against current master data.

---

# Phase 4.8 — Atomic Local Completion

Implement enough transaction-domain behavior to prove the completion boundary.

Conceptually:

```text
validate representative transaction
        ↓
BEGIN SQLITE TRANSACTION
        ↓
freeze transaction facts
assign transaction UUID
assign receipt identity
freeze line values
freeze tax
record cash tender
record local completed operation
record applicable local inventory consequence
insert durable outbox record
        ↓
COMMIT
```

A completed operation and its outbox record must be committed atomically.

### Local inventory semantics

Phase 4 must not create a second competing central inventory ledger.

The model is:

```text
last accepted server inventory state
        +
applicable unacknowledged local completed operations
        ↓
effective workstation inventory projection
```

The workstation's completed sale is the locally authoritative originating fact.

The central server remains authoritative for consolidated inventory ledger and valuation posting.

---

# Phase 4.9 — Server Ingest and Idempotency

Implement workstation → Rails operation intake.

Required:

* authenticated installation;
* versioned payload;
* structural validation;
* idempotency enforcement;
* duplicate payload detection;
* payload hash comparison;
* immutable preservation of accepted source facts;
* sale persistence;
* inventory posting through the existing inventory service boundary;
* acknowledgment response.

Initial outcomes should support at least:

```text
accepted
duplicate
invalid
quarantined
```

The full reconciliation operator workflow can follow later.

### Inventory authority

On server acceptance:

```text
completed POS sale
        ↓
server POS ingest
        ↓
Inventory sale-posting service
        ↓
authoritative inventory ledger
        ↓
inventory balance projection
```

The POS payload supplies the immutable sale facts required to post inventory.

It does not contain a competing central ledger transaction.

---

# Phase 4.10 — End-to-End Architecture Proof

Automate a representative scenario:

```text
enroll workstation
        ↓
download reference data
        ↓
construct representative sale
        ↓
calculate in .NET
        ↓
commit sale + outbox atomically
        ↓
terminate process
        ↓
restart
        ↓
resume outbox
        ↓
submit operation
        ↓
submit same operation again
        ↓
server stores one sale
        ↓
inventory posts once
```

Also compare Rails/.NET calculations against the same contract fixtures.

---

## Phase 4 Explicit Non-Goals

Phase 4 does not deliver:

* production cashier checkout UI;
* production offline PIN authentication;
* receipt printing;
* cash drawer integration;
* Z-period operations;
* drawer session operations;
* cash counts;
* paid-in/out;
* returns;
* exchanges;
* price overrides;
* discounts;
* promotions;
* card/check/stored-value tenders;
* mixed tenders;
* individually tracked unit sales;
* customer display;
* complete workstation recovery tooling;
* automatic updater;
* full Windows/macOS/Linux certification;
* printer compatibility matrix.

---

## Phase 4 Exit Criterion

> **A real ShelfSense POS installation can enroll, obtain sufficient reference data, calculate a representative sale according to the shared financial contracts, durably commit an immutable completed operation and outbox entry, survive restart, synchronize idempotently to Rails, and cause exactly one corresponding central inventory effect.**

Phase 4 completion does not mean ShelfSense has a usable cashier register.

---

# Phase 5 — First Operational Cash Sale

## Objective

Deliver the narrowest complete POS workflow that can be used by a cashier to perform a real bookstore sale.

At the end of Phase 5:

> **A cashier can sign in, establish minimum register context, scan a quantity-tracked item, calculate its configured price and tax, accept cash, calculate change, complete atomically while offline, receive a permanent receipt, and later synchronize exactly once to the central server.**

Phase 5 is the first point at which ShelfSense should be evaluated as a cashier-facing product.

---

# Phase 5.1 — Production Cashier Authentication

Implement production-shaped local POS authentication.

Required:

* cached eligible POS users;
* offline-verifiable cashier credential/PIN;
* store eligibility;
* required POS permission checks;
* local session identity;
* completed transaction `actor_id`;
* cached authorization/reference version information.

Installation identity remains separate from cashier identity.

```text
installation credential
    → authenticates machine to Rails

cashier credential
    → authenticates person to POS
```

Full supervisor threshold policy can remain limited to Phase 5 operations.

---

# Phase 5.2 — Minimum Register Context

Cash transactions must not exist outside basic accountability context.

Implement:

* explicit `business_date`;
* one active Z period per workstation;
* one open drawer session at a time;
* opening float;
* cash tender effect on expected drawer cash;
* drawer close count;
* expected versus counted variance;
* minimal Z summary.

## Phase 5 register-context contract

### Included

```text
one active Z per workstation

one open drawer session at a time

opening float

cash sales affect expected cash

closing physical count

expected cash
counted cash
variance

minimal Z:
  transaction count
  gross sales
  tax
  cash tender total
  expected cash
  counted cash
  variance
```

### Explicitly excluded

```text
paid-in
paid-out

cash drop
change replenishment

safe locations
safe balances

internal transfers

multiple concurrent drawer semantics
drawer handoff

blind counts
recounts
accepted-count workflow

bank deposits

store daily finalization
missing-register completeness
late-day amendment workflow
```

These remain Phase 6 concerns.

---

# Phase 5.3 — Cashier Transaction UI

Build the real keyboard-first Terminal.Gui register interface.

Required workflow:

```text
sign in
↓
open required register context
↓
READY FOR SCAN
↓
scan/type identifier
↓
add quantity-tracked item
↓
optional quantity change
↓
optional pre-completion void
↓
review totals
↓
select Cash
↓
enter amount presented
↓
calculate/display change
↓
complete
```

Every required action must be possible without a mouse or touchscreen.

### Command behavior

Phase 5 should establish the real cashier shortcut set.

Examples may include:

```text
F2   Lookup
F3   Quantity
F4   Void
F9   Tender
F10  Complete
```

Exact bindings remain configurable.

---

# Phase 5.4 — Merchandise Scope

Initial sale scope is:

> **Quantity-tracked Standard variants only.**

Support:

* normalized identifier scan;
* system SKU/identifier lookup as appropriate;
* active/sellable validation;
* quantity changes;
* line void before completion.

Initial error handling:

* identifier not found;
* inactive/not sellable;
* missing price;
* missing tax configuration;
* insufficient locally known configuration.

Phase 5 does not yet support individually tracked inventory units.

---

# Phase 5.5 — Price and Tax

Phase 5 sells merchandise at its configured resolved regular price.

Explicit rule:

> **Phase 5 has no cashier price overrides and no discounts.**

If price configuration is incorrect, correct the master data and replicate it.

Phase 5 uses the Phase 4 contract pack for:

* price;
* line extension;
* tax;
* transaction total.

Completed transaction snapshots preserve the actual calculation inputs/results used.

---

# Phase 5.6 — Cash Tender

Phase 5 supports only:

```text
Tender category: Cash
```

Required representation:

* total due;
* amount presented;
* applied cash;
* change.

Cash drawer expected amount uses the applied amount, not gross presented cash.

Example:

```text
Total due:       $17.24
Cash presented:  $20.00
Applied cash:    $17.24
Change:           $2.76
```

Phase 5 does not support:

* Card;
* Check;
* Stored Value;
* Other;
* mixed tenders.

The underlying data model may already accommodate future tender breadth.

---

# Phase 5.7 — Permanent Receipt Identity

Implement real workstation-local receipt sequencing.

Required:

* workstation-scoped monotonic sequence;
* assignment only at successful transaction completion;
* sequence durable across process/OS restart;
* gaps permitted;
* sequence never knowingly reused;
* central uniqueness enforcement;
* completed operation carries permanent receipt identity.

Receipt sequencing must not depend on server availability.

---

# Phase 5.8 — Receipt Printing

Implement one real supported printer path on the initial pilot/development platform.

Architecture:

```text
completed transaction
        ↓
receipt representation
        ↓
receipt renderer
        ↓
IReceiptPrinter
        ↓
platform adapter
        ↓
receipt printer
```

Rules:

* transaction commits before printing;
* print failure does not reverse completion;
* reprint uses original completed facts;
* reprint does not create another sale;
* reprint does not automatically open the drawer.

Automated tests should use a fake printer adapter.

Real-device integration should validate at least one declared supported receipt printer.

Phase 5 does **not** require a cross-platform printer compatibility matrix.

---

# Phase 5.9 — Printer-Driven Cash Drawer

Implement one real drawer path through the selected Phase 5 receipt printer environment.

Keep separate abstractions:

```text
IReceiptPrinter
ICashDrawer
```

even where the drawer is physically driven by the printer.

Rules:

* relevant cash completion may trigger drawer opening after durable commit;
* drawer failure does not invalidate a completed sale;
* explicit hardware failure is surfaced to cashier;
* receipt reprint does not trigger drawer open;
* tests use a fake drawer adapter;
* one real printer/drawer combination is sufficient for Phase 5.

---

# Phase 5.10 — Real Offline Cash Sale

Prove actual cashier operation with the server unavailable.

```text
references already cached
        ↓
disconnect server
        ↓
cashier signs in
        ↓
scan item
        ↓
calculate price/tax
        ↓
cash tender
        ↓
complete locally
        ↓
drawer/receipt
        ↓
operation remains in outbox
        ↓
reconnect
        ↓
sync
```

Cashier transaction completion must not wait for a connectivity probe or immediate server acknowledgment.

---

# Phase 5.11 — Minimal Drawer Close and Z

Implement enough register close behavior to make Phase 5 cash activity accountable.

### Drawer close

* prevent new cash activity during final count as appropriate;
* record physical count;
* calculate expected;
* calculate variance;
* close drawer session.

### Z

Summarize:

* transaction count;
* gross sale amount;
* tax;
* cash tender;
* expected drawer cash;
* counted drawer cash;
* variance.

This is intentionally not the final full Z/reporting model.

---

# Phase 5 Pilot Merchandise Gate

Phase 5 engineering completion does not inherently require individually tracked merchandise.

However:

> **If the selected pilot store requires used/individually tracked merchandise for normal operation, Phase 5 is not considered pilot-ready until the individual-unit slice is delivered.**

In that case, deliver a Phase 5.1 extension before pilot launch.

That extension should implement:

* exact inventory-unit scan/selection;
* quantity = 1;
* cached local unit sellability;
* exact local unit sale consequence;
* immutable unit identity in completed payload;
* central exact-unit inventory posting;
* accepted duplicate-unit offline conflict behavior from ADR-015.

This does not change the core Phase 5 cash-sale milestone.

---

## Phase 5 Explicit Non-Goals

Phase 5 excludes by default:

* price override;
* manual discount;
* promotion engine;
* coupons;
* Card;
* Check;
* Stored Value;
* Other tender;
* mixed tender;
* returns;
* exchanges;
* suspended transactions;
* customer association;
* open rings;
* paid-in/out;
* cash drops;
* replenishment;
* safe management;
* multiple drawer handoff;
* advanced approval policy;
* store daily finalization;
* broad cross-platform certification;
* updater/productized recovery;
* customer-facing display.

---

## Phase 5 Exit Criterion

> **A cashier can authenticate locally, open the required minimum register context, scan and sell a quantity-tracked Standard item using its configured regular price and tax, accept cash, calculate change, complete the transaction durably while offline, assign and print a permanent receipt, update the local cash/inventory projection, later synchronize idempotently, and produce exactly one central sale and inventory effect.**

---

# Phase 6 — Core POS Operations

## Objective

Expand the narrow Phase 5 sale into the POS functionality required for normal bookstore register operation.

Phase 6 has **two separate completion milestones**:

### Phase 6A — POS Domain Complete

ShelfSense can perform normal bookstore register operations on the primary supported/certified deployment platform.

### Phase 6B — POS Productized

The POS is hardened and certified across the declared workstation support matrix.

This distinction prevents packaging and certification work from blocking domain completion.

---

# Phase 6.1 — Merchandise Breadth and Transaction Corrections

Expand the sellable merchandise and working transaction model.

Implement:

### Individually tracked merchandise

* exact inventory-unit scan/selection;
* unit qty = 1;
* cached unit status;
* local unit consequence;
* server exact-unit posting;
* duplicate-unit offline reconciliation behavior.

### Open rings

* explicit open-ring line type;
* department;
* tax class;
* entered unit price;
* quantity;
* reason policy as required;
* no inventory effect.

### Working transaction behavior

* stronger manual lookup;
* line void audit;
* transaction cancellation;
* suspend transaction;
* local recall;
* activity/event history.

### Price override

Introduce intentionally here:

* reference price;
* selling price;
* reason;
* performed by;
* approval where policy requires;
* override activity history;
* reporting variance.

Phase 6.1 should not turn price overrides into discounts.

---

# Phase 6.2 — Launch-Required Tender Breadth

Expand tenders according to actual launch requirements.

Likely order:

### Card

Because ShelfSense records external card handling rather than processing the card itself:

* tender category Card;
* payment/refund behavior as configured;
* external/card type reference;
* optional external transaction reference;
* no PAN/CVV storage;
* no authorization lifecycle.

### Check

As required:

* check reference;
* configured payment/refund behavior.

### Other

For externally administered instruments as needed.

### Mixed tenders

Add when multiple-tender transactions are needed.

### Stored Value

May remain later within 6.2 or a dedicated extension because authoritative shared balances introduce stronger online/offline constraints.

Exact sequence of tender breadth versus discounts should be driven by pilot/launch needs.

---

# Phase 6.3 — Discounts and Promotions Foundation

Add the completed financial representation for discounts.

Implement:

### Line discounts

* fixed amount;
* percentage;
* source;
* reason;
* actor/approver as required;
* ordered application.

### Transaction discounts

* logical basket-level adjustment;
* eligibility;
* deterministic proportional allocation to lines;
* stable residual-cent handling.

### Contract fixture expansion

Extend shared Rails/.NET fixtures for:

* fixed discount;
* percentage rounding;
* stacking order;
* transaction allocation;
* tax after discount;
* receipt amounts.

Do not build a general-purpose promotion-expression engine unless a concrete business requirement warrants it.

Future campaign constructs can produce the same underlying discount facts.

---

# Phase 6.4 — Returns, Refunds, and Exchanges

Finalize/revise ADR-016 before implementation.

Then implement:

### Linked returns

* original transaction-line reference;
* remaining returnable quantity;
* historical selling price;
* historical discounts;
* historical tax components;
* original inventory effect reversal.

### Partial returns

* deterministic cents allocation;
* cumulative returned amount cannot exceed original;
* full return exactly reverses original.

### Individually tracked returns

* exact original unit;
* qty = 1;
* restore unit to inventory.

### Refunds

* refund-enabled tender policies;
* cash refunds;
* card/reference behavior;
* Stored Value where supported.

### Exchanges

Mixed transaction:

```text
return lines
+
sale lines
=
net amount
```

### Unlinked returns

Only as an explicitly authorized exception with finalized policy.

### Inventory rule

A completed merchandise return restores the original inventory effect.

Damage, inspection, RTV, discard, or other post-return handling remains an inventory workflow, not POS return disposition.

---

# Phase 6.5 — Full Cash Operations

Expand the deliberately narrow Phase 5 cash model.

Implement:

* multiple sequential drawer sessions per Z;
* paid-ins;
* paid-outs;
* cash drops;
* change replenishment;
* safe/cash locations;
* drawer ↔ safe transfers;
* opening-float transfers;
* immutable physical counts;
* blind first count;
* recounts;
* accepted count;
* variance acknowledgment;
* applicable approval thresholds;
* post-close amendment/compensating foundations.

Retain the distinction:

```text
cash tender
≠
cash movement
≠
cash transfer
≠
cash count
```

Expected cash remains derived from recorded activity.

Physical count remains an independent observation.

Variance is never automatically erased through a balancing adjustment.

---

# Phase 6.6 — Reporting Periods and Store Completeness

Complete the operational reporting-period model.

Implement:

### Business date

* store-local rules;
* immutable assignment at transaction completion;
* late synchronization preserves original date.

### Z periods

* multiple Zs per business date;
* immutable Z checkpoint;
* association of completed activity with current period;
* full tender/tax/sale/return totals;
* operational exception metrics.

### Drawer/Z relationship

* Z cannot finalize with an associated open drawer session;
* multiple drawer sessions per Z allowed.

### Store daily completeness

Establish the central reporting/finalization model:

* open;
* pending registers;
* final;
* amended;

or equivalent finalized terminology.

Per expected workstation, central state eventually receives:

* final Z;
* explicit no-activity acknowledgment;
* authorized missing-register exception.

### Late offline activity

A transaction arriving after finalization:

* retains original business date;
* amends the affected reporting date;
* does not move to synchronization date;
* preserves reproducibility of the original final view.

This work should supersede or revise ADR-017 as required.

---

# Phase 6A Exit — Core POS Domain Complete

Phase 6A is complete when, on the primary supported platform, ShelfSense can perform normal bookstore register operations including:

* quantity-tracked merchandise;
* individually tracked merchandise where in scope;
* open rings;
* transaction corrections;
* price overrides;
* required tender categories;
* mixed tenders where needed;
* discounts;
* returns/exchanges;
* complete cash operations;
* drawer reconciliation;
* Z reporting;
* business-date/store completeness behavior.

At this milestone:

> **ShelfSense is operationally a complete POS on its primary supported deployment environment.**

Phase 6A does not wait for every operating-system/architecture combination to be fully productized.

---

# Phase 6.7 / Phase 6B — POS Productization and Hardening

## Objective

Turn the operational POS into a broadly deployable, supportable workstation product.

---

## Platform certification

Certify the declared ADR-018 matrix according to actual support priorities:

* Windows x64;
* Windows ARM64;
* macOS x64;
* macOS ARM64;
* Linux x64;
* Linux ARM64.

Certification may be rolled out progressively.

A platform is not considered supported merely because .NET can execute on it.

Certification includes:

* OS version;
* architecture;
* terminal environment;
* keyboard workflow;
* persistence;
* printer compatibility.

---

## Installation and replacement

Complete:

* installer;
* repair;
* uninstall without data destruction;
* explicit decommission;
* healthy workstation handoff;
* lost-workstation recovery;
* installation revocation;
* replacement enrollment;
* receipt high-water recovery;
* safe sequence jump;
* clone protection.

---

## Database recovery

Productize:

* rolling backup management;
* migration backup;
* integrity checks;
* controlled recovery state;
* restore workflow;
* corrupt/missing DB handling;
* disk-full diagnostics;
* storage-health status.

Normal POS must never silently create a replacement database after failure.

---

## Updating

Implement:

* versioned release staging;
* signed/verified artifacts;
* safe update boundaries;
* pre-migration backup;
* compatible rollback;
* minimum/prohibited protocol version support;
* cross-platform updater behavior.

Add:

* Windows signing;
* macOS signing/notarization;
* Linux artifact verification.

---

## Hardware certification

Establish a declared compatibility matrix for:

* receipt printers;
* printer-mediated cash drawers;
* relevant OS/architecture combinations.

Keep the hardware API surface narrow unless additional peripherals become actual requirements.

---

## Diagnostics and support

Complete:

* support diagnostics screen/export;
* application/runtime versions;
* OS/architecture;
* DB schema/integrity;
* sync status;
* oldest pending operation;
* printer/drawer configuration;
* disk status;
* recent operational failures.

Ensure support bundles exclude secrets and unnecessary sensitive data.

---

## Optional customer-facing display

If desired, add the second-monitor customer display.

It remains:

* non-authoritative;
* local;
* independent of central connectivity;
* non-blocking to cashier operation.

Its implementation may be graphical even though the cashier UI remains Terminal.Gui.

---

# Phase 6B Exit — POS Productized

Phase 6B is complete when ShelfSense can be reliably installed, updated, recovered, diagnosed, and operated across the **declared supported platform/hardware matrix**.

It is explicitly possible for Phase 6A to be complete before Phase 6B.

---

# ADR Gates

| Gate                                                                   | Timing                          |
| ---------------------------------------------------------------------- | ------------------------------- |
| Validate ADR-018 runtime assumptions                                   | Phase 4.0                       |
| Amend ADR-018 only if validation exposes a blocker                     | Immediately after 4.0           |
| ADR-018 remains governing POS architecture                             | Phases 4–6                      |
| Finalize/revise ADR-016 return design                                  | Before Phase 6.4                |
| Revise/supersede ADR-017 reporting-period model                        | During Phase 6.6                |
| Do not infer implementation scope from ADR-018 productization sections | Throughout                      |
| Declare pilot used/unit-tracked requirement                            | Before Phase 5 pilot acceptance |
| Declare Phase 6 primary supported platform                             | Before Phase 6A completion      |
| Declare full productized support matrix                                | Before Phase 6B completion      |

---

# Phase Summary

| Phase  | Question answered                                         | Deliverable                                                                 |
| ------ | --------------------------------------------------------- | --------------------------------------------------------------------------- |
| **4**  | Can a workstation safely act as an offline peer of Rails? | Durable local operation → restart → idempotent sync → one inventory effect  |
| **5**  | Can a cashier perform one real sale?                      | Keyboard-only offline cash sale from scan through permanent printed receipt |
| **6A** | Can a bookstore run normal registers?                     | Core merchandise, tender, discount, return, cash, and reporting operations  |
| **6B** | Can we deploy/support the POS as a product?               | Certified platforms, installers, updater, recovery, hardware compatibility  |

---

# Boundary With Later Phases

The completion of Phase 6 establishes POS as a stable operational domain.

Subsequent phases integrate through those contracts rather than reopening transaction architecture.

### Phase 7 — Customers and Requests

Add:

* customer lookup/association;
* reservations;
* special-order request integration;
* customer pricing/discount programs as needed.

### Phase 8 — Purchasing and Receiving

Integrate received inventory and customer-request fulfillment through existing inventory/POS boundaries.

### Phase 9 — Buyback

Integrate customer-originated merchandise acquisition with existing individually tracked inventory, POS, and Stored Value concepts.

### Phase 10 — Financial Posting and Reporting

Translate established POS, tender, tax, cash, purchasing, and inventory facts into accounting postings and broader financial reporting.

---

## Roadmap invariant

> **Phase 4 builds the foundation without pretending to be a register. Phase 5 delivers one deliberately narrow but real register workflow. Phase 6 expands that workflow without allowing cross-platform productization to obscure the distinction between domain completeness and deployment maturity.**
