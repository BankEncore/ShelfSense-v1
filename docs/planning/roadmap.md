# ShelfSense roadmap

Status: **canonical forward-looking roadmap** (August 2026). Supersedes the preliminary Phase 8–9 outline in [planning/README.md](README.md) §3 and the boundary sections of [preliminary-roadmap.md](../drafts/preliminary-roadmap.md) for **domain sequencing**. The Terminal productization track in `preliminary-roadmap.md` remains a separate ADR-018 program (see [Terminal program](#terminal-program-adr-018) below).

The root [README.md](../../README.md) carries a compact status summary and links here for detail.

## How to read this document

| Label | Meaning |
|---|---|
| **Implemented** | Merged to `main`; authoritative planning packets describe shipped behavior |
| **Planned** | Approved direction; planning packet not yet written or incomplete |
| **Proposed** | Preferred sequencing or scope; requires a planning packet before implementation |
| **Deferred** | Explicitly out of scope for the named phase; may appear in a later phase |

Phase numbers **0–7** and **6.1** are **historical milestones**. Do not renumber implemented work. New domain phases continue from **Phase 8** onward. Cross-phase UX work uses **UDS-*** slice ids and is not a numbered domain phase.

Each operational phase should ship the **minimum reports** needed to reconcile its own facts. Phase 14 adds consolidated financial closeout and cross-domain reporting—not the first visibility into those transactions.

## Implemented foundation

| Milestone | Status | What it provides for later work |
|---|---|---|
| Phase 0 — Architecture | Implemented | UUIDv7, immutability, reversals, concurrency, idempotency, outbox, authority policies ([ADR index](../adr/README.md)) |
| Phase 1 — Operable foundation | Implemented | Stores, users, permissions, registers, configuration, audit ([phase1-plan.md](phase1-operational-foundation/phase1-plan.md)) |
| Phase 2 — Financial classification and merchandise | Implemented | Products, variants, identifiers, GL/tax/department reference data ([phase2-plan.md](phase2-financial-classification-and-merchandise-foundation/phase2-plan.md)) |
| Phase 2.1 — Merchandise correctness | Implemented | Reactivation, code normalization, pricing-method defaults ([phase-2.1-platform-and-merchandise-refinements.md](phase2.1-platform-merchandise-refinement/phase-2.1-platform-and-merchandise-refinements.md)) |
| Phase 2.2 — Administrative UX foundation | Implemented | Admin shell, shared partials, product reference flow ([phase-2.2-ux-foundation.md](phase2.2-ux-foundation/phase-2.2-ux-foundation.md)) |
| Phase 3 — Inventory foundation | Implemented | Physical and valuation ledgers, units, balances, corrections ([phase-3-inventory-foundation.md](phase3-inventory-foundation/phase-3-inventory-foundation.md)) |
| Phase 4 — POS posting foundation | Implemented | Headless Cash sale, `CompletedPosOperation` v1, inventory posting ([phase4-plan.md](phase4-6-point-of-sale/phase4-point-of-sale/phase4-plan.md)) |
| Phase 5 — Cash register | Implemented | Register workspace, opening float, blind close, immutable Z ([phase5-plan.md](phase4-6-point-of-sale/phase5-cash-register/phase5-plan.md)) |
| Phase 6 — Operational POS MVP | Implemented | Mixed tenders, Used sales, returns, refunds, post-void, history ([phase6-plan.md](phase4-6-point-of-sale/phase6-pos-mvp/phase6-plan.md)) |
| Phase 6.1 — Classification and identifiers | Implemented | Department/class policy, sticky variant defaults, product identity ([README](phase6.1-merchandise-classification-and-identifiers/README.md)) |
| Phase 7 — Orders, requests, and receiving | Implemented | Customers (minimal), requests, reservations, suppliers, POs, receiving, Register pickup ([README](phase7-orders-and-receiving/README.md)) |
| UDS-1 — Warm Parchment tokens and primitives | Implemented | Tokens, `ActionButtonHelper`, shared CSS ([uds-1-plan.md](ux-design-system/uds-1-plan.md), [ADR-022](../adr/ADR-022-warm-parchment-visual-tokens.md)) |
| UDS-2 — Reference screen convergence | Implemented | Suppliers, Receiving, transaction history, review dialogs ([uds-2-plan.md](ux-design-system/uds-2-plan.md)) |
| UDS-3 — Register visual refinement | Implemented | Basket hierarchy, shortcut groups, overlays ([uds-3-plan.md](ux-design-system/uds-3-plan.md)) |

Several roadmap goals are **not greenfield**. The forward phases below describe **completion and extension** of capabilities that already exist in part:

| Area | Already on `main` |
|---|---|
| Customers | Basic identity, lookup, requests, reservations, special-order fulfillment, Register pickup, admin screens |
| Register / POS | Session opening, cash sales, mixed tenders, returns, blind close, Z reporting, transaction history |
| Financial | GL classifications, tax calculation, inventory valuation, immutable POS facts |
| Product / catalog | Strong identifiers, classification, pricing, Used units, unified lookup, CSV import |
| Layout / UX | Warm Parchment tokens and action semantics on reference surfaces; broad screen migration remains |
| Buyback (inventory side) | Individually tracked Used units and valuation ledger as the acquisition destination |

## Cross-phase UX program

### UDS foundation exit (in progress)

UDS-1 through UDS-3 code is merged. [migration-matrix.md](ux-design-system/migration-matrix.md) rows may remain **partial** until [accessibility-ergonomic-test-matrix.md](ux-design-system/accessibility-ergonomic-test-matrix.md) evidence is attached per [program-plan.md](ux-design-system/program-plan.md). Completing that evidence is part of closing the UDS foundation program—not a blocker for starting domain Phase 8 planning.

### UDS-4 — Information architecture and adoption

**Status:** Proposed overall; **UDS-4.0–4.2 on `main`** ([uds-4.2-plan.md](ux-design-system/uds-4.2-plan.md)). Coordination **Accepted** ([phase7.1-uds-coordination.md](phase7.1-purchasing-polish/phase7.1-uds-coordination.md)).

Continue the cross-phase [UX design system](ux-design-system/README.md). Authoritative slice plan: [uds-4-plan.md](ux-design-system/uds-4-plan.md).

Scope:

- Prototype and pass the [navigation prototype gate](ux-design-system/navigation-proposal.md#required-prototype-gate) using real permission and store-context rules.
- Replace the flat administrative header with permission-aware **grouped navigation** using the canonical groups in [navigation-proposal.md](ux-design-system/navigation-proposal.md) (not aspirational roadmap labels until those destinations exist).
- Continue migrating **non–Phase-7.1-owned** screens to Warm Parchment and `ActionButtonHelper` per the coordination ownership table.
- Standardize **non-purchasing** cross-links; purchasing entity links belong to Phase 7.1.

**Deliverable:**

> Authorized staff can reach operational destinations through grouped, permission-filtered navigation without relying on a flat link list, JavaScript-only access, or hidden authorization boundaries.

UDS-4.0 gate passed; UDS-4.1 ships grouped nav into `application.html.erb`.

## Phase 7.1 — Purchasing workflow and presentation closeout

**Status:** **Complete** — **7.1.1–7.1.3 on `main`** (PR #35, PR #40); **UDS-4.1/4.2 on `main`**; **7.1.4 deferred**.

Authoritative packet: [Phase 7.1](phase7.1-purchasing-polish/README.md).

Phase 7 shipped the bookstore-operable purchasing and customer-request path. Phase 7.1 closes **Phase 7 operability** (work hub, admin purchasing presentation, and ops interaction closeout in **7.1.3**)—not supplier returns, request expiration, or the AP/accounting interface. Forward domains (stored value, buyback, customer expansion, bibliographic enrichment, register cash) proceed separately; UDS grouped navigation is a parallel UDS program.

### Slices (summary)

| Slice | Scope |
|---|---|
| 7.1.1 | Purchasing work hub (spec §17.1) ✓ |
| 7.1.2 | Admin orders / PO / receipt presentation and cross-links ✓ |
| 7.1.3 | Ops Location + Draft PO interaction closeout ✓ |
| 7.1.4 | Customer-request purchasing cross-links (deferred) |

Coordination with UDS-4: [phase7.1-uds-coordination.md](phase7.1-purchasing-polish/phase7.1-uds-coordination.md).

### Explicitly defer (beyond Phase 7.1)

- **Supplier returns** — return authorization, shipment, posted inventory reversal (see [long-term deferrals](#explicit-long-term-deferrals))
- **Request lifecycle automation** — reservation and request expiration (`default_customer_reservation_expiration_days` remains configuration-only)
- Accounts payable, landed-cost capitalization, replenishment automation, EDI, and related accounting workflows (Phase 14 for accounting closeout)

**Deliverable:**

> Authorized purchasing workflows gain justified ergonomics improvements without reopening Phase 7 core contracts or deferring higher-priority forward phases.

## Phase 8 — Customer foundation refinement

**Status:** Proposed. **May run in parallel with Phase 9.**

Phase 7 created the minimum customer record required for requests. Phase 8 makes customer identity reliable enough for stored value and buyback.

### Build on what exists

- Customer record with `display_name`, email, phone, notes, and active flag
- Customer lookup, requests, reservations, special-order fulfillment, Register pickup
- Customer and customer-request administrative screens

### Add

- Structured name fields where appropriate, retaining a usable display name
- Multiple phone numbers, emails, and addresses
- Preferred contact method; communication and receipt preferences
- Customer status and lifecycle
- Duplicate detection; customer merge with durable reference reassignment
- Search normalization for names, phones, and emails
- Basic operational notes with visibility rules
- Privacy, retention, and audit policies
- Stable eligibility for customer-owned stored-value accounts

### Adjacent deferrals from Phase 7 (evaluate in planning packet)

- **Customer tax exemption** — deferred from Phase 7; may land here or in an early POS policy slice
- **Marketing, CRM, loyalty, segmentation** — remain deferred

### Explicitly defer

- Marketing campaigns and sales leads
- Complex segmentation and loyalty programs
- Full CRM functionality
- The consolidated customer-history workspace (Phase 13)

**Deliverable:**

> Staff can reliably identify or create the correct customer, maintain useful contact information, avoid duplicate accounts, and use that identity as the owner of requests and stored value.

## Phase 9 — Catalog and bibliographic enrichment

**Status:** Proposed. **May run in parallel with Phase 8.**

Extends Phases 2 and 6.1; does not replace the product model.

### Build on what exists

- Products and sellable variants; generated internal identifiers
- Industry identifiers and lookup codes; Standard and Used distinctions
- Merchandise classifications and departments; inventory mode, pricing method, returnability
- Unified merchandise lookup and CSV import

### Add

- Contributors and contribution roles; publisher and imprint
- Publication date, edition, binding/format, language, page count, series
- Descriptions and cover references; additional industry identifiers where justified
- External bibliographic providers
- Search-result matching against existing products; candidate-product creation from external data
- Field provenance and last-refresh information; staff-controlled overwrite and conflict rules
- Background enrichment without silently changing curated data

The external lookup boundary returns **normalized candidate data**; the Product aggregate remains authoritative.

**Deliverable:**

> Staff can scan or search for a book ShelfSense has never carried, review trustworthy bibliographic data, match or create the correct product, and preserve locally curated information.

## Phase 10 — Stored value and financial event contract

**Status:** Proposed. **After Phase 8** (customer identity foundation).

Combines stored-value features with the narrow financial contract they require. ShelfSense already has mature posting systems (POS, inventory, tax); this phase does not introduce a broad abstract “financial foundation.”

Stored-value redemption is **online-authorized** until a bounded offline mechanism exists ([ADR-005](../adr/ADR-005-terminal-originated-operations.md)).

### Build on what exists

- Integer-cent money contracts; tender types and mixed tender
- Completed POS operations; refunds and post-voids
- GL accounts and department mappings; immutable operational facts
- Idempotency and reversal patterns; register session and business-date attribution

### Slice 10.1 — Financial event / posting contract

Define the common boundary needed by stored value, cash movements, and buyback:

- Source transaction and source line; store and business date
- Event classification; monetary amount and direction
- Liability or tender classification; posted/reversed status
- Idempotency key; reversal relationship; actor and occurrence time
- Accounting export/posting status

This is a reconstructable operational financial subledger with a later GL export—not a general ledger.

### Slice 10.2 — Customer account credit

- Customer-owned account; store credit and trade credit balances (shared infrastructure, distinguishable liabilities)
- Issue, redeem, reverse; manual adjustment with elevated permission
- Balance projection backed by an immutable ledger
- Split tender; refund-to-credit policy; customer balance and activity display

### Slice 10.3 — Gift cards

Implement separately (different identity and ownership):

- Gift-card number and secure lookup; activation; reload where policy permits
- Redemption; balance inquiry; replacement and transfer controls
- Optional customer association; anonymous/bearer use; void and reversal
- Liability and activity reporting

### Slice 10.4 — POS and reconciliation integration

- Accept stored value in the Register; return value according to refund policy
- Include stored value in transaction history and in Z / store-day reconciliation
- Prevent double redemption through locking and idempotency; handle transaction post-void correctly

**Deliverable:**

> ShelfSense can issue, redeem, reverse, and reconcile customer credit, trade credit, and gift cards without treating balances as editable customer fields.

## Phase 11 — Cash accountability completion

**Status:** Proposed. **After Phase 10** financial event contract.

Phase 5 implemented the beginning and end of the register session. Phase 11 fills in accountable movement during the session and between cash locations.

Preserve the distinction between:

- **Register** — durable POS identity
- **Register session** — cashier/accountability period
- **Cash container/location** — the actual pool of currency (drawer, safe, deposit-in-transit)

### Build on what exists

- Register definition; session opening; opening float
- Cash tender; cash refunds; blind close; expected/count comparison; immutable Z closeout

### Add

- Cash location or accountability model (drawer, register session, safe, deposit-in-transit if needed)
- Paid in; paid out; cash drop; drawer-to-safe transfer; safe-to-drawer replenishment
- Accountable handoff; reason codes; approval thresholds; available-cash checks
- Transfer acknowledgement; deposit preparation; cash movement reversal/correction
- Expanded over/short reconciliation; cash activity and safe-balance reports

**Deliverable:**

> Every non-sale cash movement is authorized, attributable, reflected in expected cash, and reconcilable from drawer through safe or deposit.

## Phase 12 — Used buyback

**Status:** Proposed. **After Phase 8–9** (identity and catalog enrichment), **Phase 10** (trade credit / financial events), and **Phase 11** (cash payout).

Evaluation and intake slices (12.1–12.2) may start before payout infrastructure is complete; payout (12.3) requires Phases 10–11.

| Buyback need | Existing or preceding capability |
|---|---|
| Identify the seller | Phase 8 customer refinement |
| Scan an ISBN | Phase 2 / 6.1 identifier lookup |
| Find an unknown title | Phase 9 external bibliographic lookup |
| Check current stock | Phase 3 inventory balances |
| Assess sales history | Phase 6 POS transactions |
| Create a unique used copy | Phase 3 inventory units |
| Establish cost and valuation | Phase 3 valuation ledger |
| Pay trade credit | Phase 10 stored value |
| Pay cash | Phase 11 cash accountability |
| Record financial consequences | Phase 10 financial event contract |

### Slice 12.1 — Intake and seller workflow

Intake batch; seller/customer association; queue and promised processing time; batch-limit policy; seller acknowledgement; compliance information; status and custody tracking.

### Slice 12.2 — Evaluation and offer

Scan or search; condition triage; rejection reason; inventory and demand warning; proposed resale price; proposed cash and trade value; buyer override and notes; offer totals; seller acceptance or rejection.

### Slice 12.3 — Payout and inventory induction

Cash, trade credit, or permitted split payout; cash-availability check; trade-credit issuance; buyback financial event; Used variant/unit creation or association; acquisition cost; condition, notes, and selling price; inventory posting; label generation.

### Slice 12.4 — Buying automation

Excess-stock thresholds; sales velocity; stale inventory; target margin; class-level buyback policy; obsolescence rules; external-market signals; configurable offer formulas; manager-review thresholds.

The first release remains **decision support**: ShelfSense recommends accept/reject/value; the buyer controls the offer.

**Deliverable:**

> Staff can intake used merchandise from a identified seller, evaluate and offer value, pay out through authorized tender paths, and induct inventory with immutable financial and inventory facts.

## Phase 13 — Customer workspace

**Status:** Proposed. **After** customer activity sources exist (requests, stored value, buyback).

Consolidates operational customer context—not a CRM:

- Contact information and preferences
- Purchase and return history; requests and reservations; special orders and pickups
- Stored-value accounts and activity; buyback offers and payouts
- Receipts; operational notes; current actions requiring attention

**Deliverable:**

> An authorized employee can open one customer record and understand the customer’s current obligations, balances, and operational history without searching multiple administrative areas.

## Phase 14 — Financial posting, reconciliation, and reporting

**Status:** Proposed. **Consolidates** operational sources after they are stable.

Transactional domains own authoritative facts; reports consume projections. Phase 14 adds unified financial closeout and cross-domain reporting.

### Build on what exists

- GL accounts and department mappings; tax calculation; inventory valuation
- POS transactions and tenders; session/Z facts; purchasing and receiving
- Stored-value events; cash movements; buyback acquisition and payouts (Phases 10–12)

### Add

- Posting rules from operational events to accounting classifications
- Balanced journal batches or accounting-export batches; posting-period controls
- Reversal and correction propagation; store-day reconciliation; accounting-system export
- Sales, tax, tender, and refund reporting
- Inventory movement and valuation reporting; purchasing and receiving reporting
- Stored-value liability reporting; cash movement, deposit, and over/short reporting
- Buyback cost, payout, and margin reporting; customer request fulfillment reporting
- Saved filters and export; role-sensitive financial access

Phase 7 deferred **AP, purchase journals, landed cost, and supplier returns**; Phase 14 is the appropriate home for accounting closeout. Supplier returns and request expiration remain deferred beyond Phase 7.1 (see [long-term deferrals](#explicit-long-term-deferrals)).

**Deliverable:**

> Finance and store management can reconcile operational facts across domains, export accounting batches, and close posting periods without duplicate source-of-truth tables.

## Terminal program (ADR-018)

**Status:** Proposed. **Separate program track**—not renumbered into Phases 8–14.

The Rails-native Register on `main` is the current POS client. A future **Terminal** is a concrete offline-capable client for a Register ([ADR-021](../adr/ADR-021-register-and-terminal-identity.md)). Productization scope (runtime, synchronization, installers, hardware certification) is described in [preliminary-roadmap.md](../drafts/preliminary-roadmap.md) and governed by [ADR-018](../adr/ADR-018-pos-workstation-architecture.md).

This program depends on stable POS, inventory, and completion contracts. It does not reopen transaction architecture established in Phases 4–6. Sequencing relative to Phases 8–14 is a deployment and connectivity decision, not a prerequisite for online bookstore operations on the Rails Register.

## Explicit long-term deferrals

The following remain out of scope until a planning packet and ADR review justify them:

| Topic | Notes |
|---|---|
| Supplier returns | Return authorization, shipment, inventory posting; deferred from Phase 7 and Phase 7.1 |
| Request/reservation expiration automation | `default_customer_reservation_expiration_days` remains configuration-only |
| Consignment inventory | README goal; no schema or workflow yet |
| Offline stored-value redemption | Online-authorized per ADR-005 |
| Full CRM / marketing automation | Phase 8 and 13 bound customer scope |
| Universal master-detail drawers, global Cmd/Ctrl+K search | [deferred-patterns.md](ux-design-system/deferred-patterns.md) |
| Standalone SQLite / .NET POS before contract stability | Terminal program |

## Sequencing summary

| Work item | Status / sequence |
|---|---|
| Phases 0–6.1 | Implemented |
| Phase 7 — Orders, requests, receiving | Implemented |
| UDS-1–3 — Warm Parchment foundation | Implemented (code); a11y matrix evidence in progress |
| Phase 7.1 — Purchasing workflow closeout | **Complete** on `main` ([packet](phase7.1-purchasing-polish/README.md)) |
| UDS-4 — Navigation and information architecture | **UDS-4.0–4.2 on `main`** ([uds-4-plan.md](ux-design-system/uds-4-plan.md)) |
| Phase 8 — Customer foundation refinement | Next; parallel with 9 |
| Phase 9 — Catalog and bibliographic enrichment | Next; parallel with 8 |
| Phase 10 — Stored value and financial event contract | After Phase 8 |
| Phase 11 — Cash accountability completion | After Phase 10 |
| Phase 12 — Used buyback | After 8–11 (payout after 10–11) |
| Phase 13 — Customer workspace | After activity sources exist |
| Phase 14 — Financial posting and reporting | Consolidates operational domains |
| Terminal program (ADR-018) | Separate track; parallel when contracts are stable |

## Roadmap invariant

> **Implemented phases record what shipped. Forward phases extend existing capabilities through vertical slices with authorization, validation, audit, and tests—not by renumbering history or treating mature subsystems as greenfield.**

## Related documents

| Document | Relationship |
|---|---|
| [planning/README.md](README.md) | Domain ownership and dependency guidance; §3 phase outline superseded by this file for forward sequencing |
| [Phase planning packets](phase1-operational-foundation/phase1-plan.md) | Authoritative detail per implemented phase |
| [Phase 7.1 purchasing closeout](phase7.1-purchasing-polish/README.md) | Phase 7 operability finish; [coordination with UDS-4](phase7.1-purchasing-polish/phase7.1-uds-coordination.md) |
| [UDS-4 plan](ux-design-system/uds-4-plan.md) | Grouped navigation and cross-cutting adoption |
| [preliminary-roadmap.md](../drafts/preliminary-roadmap.md) | Terminal / ADR-018 productization detail; draft POS Phases 4–6B boundary text superseded for domain sequencing |
| [pos-pending-decisions.md](../drafts/pos-pending-decisions.md) | Open POS policy items referenced during phase planning |

Update this file when forward phase scope, sequencing, or implemented status changes. Update the root README compact summary in the same change.
