# ShelfSense roadmap

Status: **canonical roadmap** (August 2026). This file is the authority for **domain sequencing**. An early planning outline that numbered Phase 8 as buyback and Phase 9 as financial posting is superseded. The Terminal productization track in [preliminary-roadmap.md](../drafts/preliminary-roadmap.md) remains a separate ADR-018 program (see [Terminal program](#terminal-program-adr-018) below).

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
| Phase 7.1 — Purchasing polish | Implemented | Work hub, admin purchasing presentation, ops closeout; 7.1.4 deferred ([README](phase7.1-purchasing-polish/README.md)) |
| Phase 8 — Customer foundation | Implemented | Identity, contact lookup, duplicate suggestions, merge ([README](phase8-customer-foundation/README.md)) |
| Phase 9 — Catalog enrichment | Implemented | Reviewed ISBNdb apply, contributions, local covers, subjects ([README](phase9-catalog-enrichment/README.md), [ADR-024](../adr/ADR-024-bibliographic-data-authority.md)) |
| UDS-1 — Warm Parchment tokens and primitives | Implemented | Tokens, `ActionButtonHelper`, shared CSS ([uds-1-plan.md](ux-design-system/uds-1-plan.md), [ADR-022](../adr/ADR-022-warm-parchment-visual-tokens.md)) |
| UDS-2 — Reference screen convergence | Implemented | Suppliers, Receiving, transaction history, review dialogs ([uds-2-plan.md](ux-design-system/uds-2-plan.md)) |
| UDS-3 — Register visual refinement | Implemented | Basket hierarchy, shortcut groups, overlays ([uds-3-plan.md](ux-design-system/uds-3-plan.md)) |
| UDS-4.0–4.2 — Navigation and adoption | Implemented | Grouped admin nav; non-purchasing ActionButtonHelper adoption ([uds-4-plan.md](ux-design-system/uds-4-plan.md)) |

Several roadmap goals are **not greenfield**. The forward phases below describe **completion and extension** of capabilities that already exist in part:

| Area | Already on `main` |
|---|---|
| Customers | Identity, contact lookup, duplicate suggestions, merge, requests, reservations, Register pickup |
| Register / POS | Session opening, cash sales, mixed tenders, returns, blind close, Z reporting, transaction history |
| Stored value | Store credit, trade credit, gift-card instruments, POS issuance and redemption, cash-out |
| Financial | GL classifications, tax calculation, inventory valuation, immutable POS facts |
| Product / catalog | Strong identifiers, classification, pricing, Used units, unified lookup, CSV import, bibliographic facts, local covers, subjects, reviewed ISBNdb apply |
| Layout / UX | Warm Parchment tokens, grouped navigation, ActionButtonHelper on reference and non-purchasing screens; remaining migration belongs to the feature phase that changes the screen |
| Buyback (inventory side) | Individually tracked Used units and valuation ledger as the acquisition destination |

## Cross-phase UX program

### UDS foundation exit (operationally complete)

UDS-1 through UDS-3 code is merged. Reference surfaces reached **`verified-automated`** per [uds-foundation-closeout-plan.md](ux-design-system/uds-foundation-closeout-plan.md) and [uds-foundation-closeout-evidence.md](ux-design-system/uds-foundation-closeout-evidence.md): Layer A (axe), Layer B (workflow), and Layer C (layout smoke). This is **not** full accessibility certification—SR-MANUAL, PERF-HUMAN, and independent review remain open for **`conforming`**. Future feature phases must include [ux-adoption-template.md](ux-design-system/ux-adoption-template.md).

### UDS-4 — Information architecture and adoption

**Status:** **UDS-4.0–4.2 complete on `main`** ([uds-4-plan.md](ux-design-system/uds-4-plan.md)). Coordination **Accepted** ([phase7.1-uds-coordination.md](phase7.1-purchasing-polish/phase7.1-uds-coordination.md)). Further screen migration belongs to the feature phase that materially changes the screen.

Continue the cross-phase [UX design system](ux-design-system/README.md). Authoritative slice plan: [uds-4-plan.md](ux-design-system/uds-4-plan.md).

Scope:

- Prototype and pass the [navigation prototype gate](ux-design-system/navigation-proposal.md#required-prototype-gate) using real permission and store-context rules.
- Replace the flat administrative header with permission-aware **grouped navigation** using the canonical groups in [navigation-proposal.md](ux-design-system/navigation-proposal.md) (not aspirational roadmap labels until those destinations exist).
- Continue migrating **non–Phase-7.1-owned** screens to Warm Parchment and `ActionButtonHelper` per the coordination ownership table.
- Standardize **non-purchasing** cross-links; purchasing entity links belong to Phase 7.1.

**Deliverable:**

> Authorized staff can reach operational destinations through grouped, permission-filtered navigation without relying on a flat link list, JavaScript-only access, or hidden authorization boundaries.

UDS-4.0 gate passed; UDS-4.1 shipped grouped nav into `application.html.erb`; UDS-4.2 shipped non-purchasing ActionButtonHelper adoption.

### UDS-5 — Administrative composition

**Status:** **Complete on `main`** (PR #57). 5.0 gate **Passed**; serif **adopted** ([uds-5-plan.md](ux-design-system/uds-5-plan.md), [uds-5.5-closeout-evidence.md](ux-design-system/uds-5.5-closeout-evidence.md)).

Scope:

- Establish UDS-5 authority and label inspirational mockup regions.
- Prototype compact presentations of the **existing** UDS-4 grouped catalog (disclosures and optional area row) without changing membership, labels, or predicates.
- After the gate: type/composition primitives, then Product as the administrative reference family.
- Record serif adopt/adjust/reject and a standing feature-led adoption rule at closeout (**done**; [uds-5.5-closeout-evidence.md](ux-design-system/uds-5.5-closeout-evidence.md)).

**Deliverable:**

> Authorized staff can scan Product reference screens and the administrative header for identity, status, and next action without a taller grouped-link wall, a persistent sidebar, or any change to catalog membership, permissions, or domain behavior.

Persistent sidebar and global search remain parked ([#56](https://github.com/BankEncore/ShelfSense-v1/issues/56)). Staff history composition is UDS-6.

## Phase 7.1 — Purchasing workflow and presentation closeout

**Status:** **Complete** — **7.1.1–7.1.3 on `main`** (PR #35, PR #40); **UDS-4.1/4.2 on `main`**; **7.1.4 deferred**.

Authoritative packet: [Phase 7.1](phase7.1-purchasing-polish/README.md).

Phase 7 shipped the bookstore-operable purchasing and customer-request path. Phase 7.1 closes **Phase 7 operability** (work hub, admin purchasing presentation, and ops interaction closeout in **7.1.3**)—not supplier returns, request expiration, or the AP/accounting interface. Forward domains (stored value, buyback, customer expansion, register cash) proceed separately; UDS grouped navigation is a parallel UDS program.

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

## Phase 8 — Customer foundation (MVP)

**Status:** **Complete** on `main` (PR #42, merge `b5ed590`). Planning packet: [phase8-customer-foundation/](phase8-customer-foundation/README.md). Phase 9 catalog enrichment and Phase 10 stored value are implemented.

Phase 7 created the minimum customer record required for requests. Phase 8 concentrates on **reliable identification**, **essential contact methods**, **duplicate prevention and safe merge**, and **minimal lifecycle governance**—not CRM, marketing, multiple contacts, or stored-value ledger design.

### Slices

| Slice | Deliverable |
|---|---|
| **8.1** Identity and lookup | Required `display_name`; optional `given_name` / `family_name`; normalized search (partial name, exact phone/email) |
| **8.2** Essential contact | Single email/phone; normalized values; `preferred_contact_method` with validation |
| **8.3** Duplicates and merge | Suggestions on create/edit; transactional merge; `merged_into_customer_id` tombstone; `customer_requests` reassignment; merge audit |
| **8.4** Lifecycle and governance | `active` / `inactive` / `merged`; policy doc for privacy/retention (no automation) |

### Build on what exists

- Customer record with `display_name`, email, phone, notes, and active flag
- Customer lookup, requests, reservations, special-order fulfillment, Register pickup
- Customer and customer-request administrative screens

### Explicitly defer

- Multiple phone numbers, emails, and postal addresses
- Receipt preferences; marketing consent; communication subscriptions
- Complex customer statuses beyond active/inactive/merged
- Note categories and fine-grained note visibility
- Automated retention, anonymization, or privacy-request processing
- **Customer tax exemption** — separate early POS policy slice, not Phase 8
- Customer purchase history workspace (Phase 13); CRM, loyalty, segmentation

### Stored-value boundary

Phase 8 does not create stored-value accounts. It documents the identity contract for Phase 10: canonical UUID, active canonical customer for new financial relationships, merged-alias resolution, explicit financial merge in Phase 10. See [phase8-stored-value-boundary.md](phase8-customer-foundation/phase8-stored-value-boundary.md).

**Deliverable:**

> Staff can quickly find or create the correct customer using name, phone, or email; the system warns about likely duplicates; authorized staff can safely merge duplicates without losing request history; and later customer-owned financial relationships can rely on one durable canonical identity.

## Phase 9 — Catalog and bibliographic enrichment

**Status:** Implemented. Planning packet: [phase9-catalog-enrichment/](phase9-catalog-enrichment/README.md). Policy: [ADR-024](../adr/ADR-024-bibliographic-data-authority.md). Phase 10 stored value is implemented.

Extends Phases 2 and 6.1; does not replace the product model. Policy: [ADR-024](../adr/ADR-024-bibliographic-data-authority.md).

### Build on what exists

- Products and sellable variants; generated internal identifiers
- Industry identifiers and lookup codes; Standard and Used distinctions
- Merchandise classifications and departments; inventory mode, pricing method, returnability
- Unified merchandise lookup and CSV import

### Add

- Contributor display names and roles; publisher/brand on `brand_name`; imprint
- Publication date (with approximate flag), edition display text, product form, language, page count, series
- Descriptions and local cover images; additional industry identifiers where justified
- External bibliographic providers with reviewed apply
- Search-result matching against existing products; candidate-product creation from external data
- Field provenance; staff-controlled selected-field apply
- Subject schemes and headings without remapping merchandise categories

The external lookup boundary returns **normalized candidate data**; the Product aggregate remains authoritative.

**Deliverable:**

> Staff can scan or search for a book ShelfSense has never carried, review trustworthy bibliographic data, match or create the correct product, and preserve locally curated information.

## Phase 10 — Stored value

**Status:** **Implemented** on `main` (August 2026). Manual test plan executed. Planning packet: [phase10-stored-value/](phase10-stored-value/README.md). Policy: [ADR-025](../adr/ADR-025-domain-owned-operational-ledgers.md), [ADR-026](../adr/ADR-026-gift-card-number-protection.md), [ADR-027](../adr/ADR-027-admin-gift-card-prefix-last-four-inquiry.md).

Stored-value redemption is **online-authorized** until a bounded offline mechanism exists ([ADR-005](../adr/ADR-005-terminal-originated-operations.md)). There is **no** universal operational financial-event table; each domain keeps its own immutable facts. Cross-domain accounting/export is Phase 14.

### Build on what exists

- Integer-cent money contracts; tender types and mixed tender
- Completed POS operations; refunds and post-voids
- Immutable operational facts; idempotency and reversal patterns
- Register session, expected cash, and business-date attribution
- Canonical customer identity and merge ([ADR-023](../adr/ADR-023-customer-merge.md))

### Slice 10.1 — Stored-value core

Accounts, operations, entries, posting service, projection verification, outbox messages.

### Slice 10.2 — Customer store credit and trade credit

Distinct customer-owned liabilities; administrative same-type transfers; account consolidation; merge transfer command; manual adjustment across eligible account types; deactivate-with-balance; customer activity.

### Slice 10.3 — Gift-card programs and instruments

Bearer identity, numbering and Rails encryption, scan routing, inquiry, suspend, replacement, optional customer association.

### Slice 10.4 — POS issuance, tenders, refund destinations, post-void

First-class issuance (not a merchandise SKU); `stored_value` tenders; signed-net rewrite; gift-card refund destinations; original-instrument verification; new refund gift-card creation; post-void fail-closed.

### Slice 10.5 — Cash-out, closeout, print, nav

Gift-card cash-out vs expected cash; X/Z; receipt/print; administrative navigation.

**Deliverable:**

> ShelfSense can issue, activate, reload, redeem, refund, transfer, consolidate, manually adjust, reverse, cash out, and reconcile store credit, trade credit, and gift cards without editable balances or a cross-domain financial-event subledger.

## Phase 11 — Cash accountability completion

**Status:** Proposed. **After Phase 10** stored-value and Register integration. Planning packet: [phase11-cash-accountability/](phase11-cash-accountability/README.md). Policy: [ADR-021](../adr/ADR-021-register-and-terminal-identity.md), [ADR-025](../adr/ADR-025-domain-owned-operational-ledgers.md).

Phase 5 implemented the beginning and end of the register session. Phase 11 fills in accountable movement during the session and between store cash locations. An open `PosSession` is till custody on a **Register**. There is no `cash_drawers` table in MVP.

Preserve the distinction between:

- **Register** — durable POS checkout and Z identity (does not hold cash between sessions)
- **POS session** — cashier custody interval
- **Cash location** — store safe and deposit in transit

### Build on what exists

- Register definition; session opening; `opening_float_cents` snapshot; cash tender; cash refunds; blind close; expected/count snapshots; immutable Z; Phase 10 gift-card cash-out

### Add

- One store safe with one-time initialization; opening float as safe→session transfer
- Close: over/short then transfer **counted** cash to the safe; available-cash on refunds and gift-card cash-outs
- Paid in; paid out; mid-shift drop; safe→session replenishment; atomic transfers (no acknowledgement workflow)
- Safe reconciliation; deposit in transit (no bank confirmation); store-day cash **report** (not a hard finalization)
- Manager-assisted session close; cash activity reasons; reversals of Phase 11 operations (not session reopen)

**Deliverable:**

> Every non-sale cash movement is authorized, attributable, reflected in expected cash, and reconcilable from session custody through safe or deposit.

## Phase 12 — Used buyback

**Status:** Proposed. **After Phase 8–9** (identity and catalog enrichment), **Phase 10** (trade credit), and **Phase 11** (cash payout).

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
| Pay trade credit | Phase 10 stored-value issue operation |
| Pay cash | Phase 11 cash accountability |
| Record financial consequences | Buyback domain facts plus stored-value operations ([ADR-025](../adr/ADR-025-domain-owned-operational-ledgers.md)) |

### Slice 12.1 — Intake and seller workflow

Intake batch; seller/customer association; queue and promised processing time; batch-limit policy; seller acknowledgement; compliance information; status and custody tracking.

### Slice 12.2 — Evaluation and offer

Scan or search; condition triage; rejection reason; inventory and demand warning; proposed resale price; proposed cash and trade value; buyer override and notes; offer totals; seller acceptance or rejection.

### Slice 12.3 — Payout and inventory induction

Cash, trade credit, or permitted split payout; cash-availability check; trade-credit issuance as a stored-value operation; buyback immutable facts; Used variant/unit creation or association; acquisition cost; condition, notes, and selling price; inventory posting; label generation.

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

Transactional domains own authoritative facts ([ADR-025](../adr/ADR-025-domain-owned-operational-ledgers.md)); reports consume projections. Phase 14 adds unified financial closeout and the versioned posting/export boundary across those sources.

### Build on what exists

- GL accounts and department mappings; tax calculation; inventory valuation
- POS transactions and tenders; session/Z facts; purchasing and receiving
- Stored-value operations and entries; cash movements; buyback acquisition and payouts (Phases 10–12)

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

The Rails-native Register on `main` is the current POS client. A future **Terminal** is a concrete offline-capable client for a Register ([ADR-021](../adr/ADR-021-register-and-terminal-identity.md)). Productization scope (runtime, synchronization, installers, hardware certification) is described in [preliminary-roadmap.md](../drafts/preliminary-roadmap.md) and governed by [ADR-018](../adr/ADR-018-pos-runtime-and-deployment.md).

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
| UDS-1–3 — Warm Parchment foundation | **Operationally complete** (`verified-automated`); see [uds-foundation-closeout-evidence.md](ux-design-system/uds-foundation-closeout-evidence.md) |
| Phase 7.1 — Purchasing workflow closeout | **Complete** on `main` ([packet](phase7.1-purchasing-polish/README.md)) |
| UDS-4 — Navigation and information architecture | **UDS-4.0–4.2 on `main`** ([uds-4-plan.md](ux-design-system/uds-4-plan.md)) |
| UDS-5 — Administrative composition | **Complete** on `main` (PR #57; [uds-5-plan.md](ux-design-system/uds-5-plan.md)) |
| Phase 8 — Customer foundation (MVP) | **Complete** on `main` (PR #42) |
| Phase 9 — Catalog and bibliographic enrichment | **Implemented** |
| Phase 10 — Stored value | **Implemented** on `main`; [manual test plan](phase10-stored-value/phase10-manual-test-plan.md) executed |
| Phase 11 — Cash accountability completion | **Proposed**; packet [phase11-cash-accountability/](phase11-cash-accountability/README.md) |
| Phase 12 — Used buyback | After 8–11 (payout after 10–11) |
| Phase 13 — Customer workspace | After activity sources exist |
| Phase 14 — Financial posting and reporting | Consolidates operational domains |
| Terminal program (ADR-018) | Separate track; parallel when contracts are stable |

## Roadmap invariant

> **Implemented phases record what shipped. Forward phases extend existing capabilities through vertical slices with authorization, validation, audit, and tests—not by renumbering history or treating mature subsystems as greenfield.**

## Related documents

| Document | Relationship |
|---|---|
| [Phase 10 stored value](phase10-stored-value/README.md) | Implemented; [ADR-025](../adr/ADR-025-domain-owned-operational-ledgers.md), [ADR-026](../adr/ADR-026-gift-card-number-protection.md), [ADR-027](../adr/ADR-027-admin-gift-card-prefix-last-four-inquiry.md) |
| [Phase 11 cash accountability](phase11-cash-accountability/README.md) | Proposed; extends Register session and store safe; [ADR-021](../adr/ADR-021-register-and-terminal-identity.md), [ADR-025](../adr/ADR-025-domain-owned-operational-ledgers.md) |
| [Phase planning packets](phase1-operational-foundation/phase1-plan.md) | Authoritative detail per implemented phase |
| [Phase 7.1 purchasing closeout](phase7.1-purchasing-polish/README.md) | Phase 7 operability finish; [coordination with UDS-4](phase7.1-purchasing-polish/phase7.1-uds-coordination.md) |
| [UDS-4 plan](ux-design-system/uds-4-plan.md) | Grouped navigation and cross-cutting adoption |
| [preliminary-roadmap.md](../drafts/preliminary-roadmap.md) | Terminal / ADR-018 productization detail; draft POS Phases 4–6B boundary text superseded for domain sequencing |
| [pos-pending-decisions.md](../drafts/pos-pending-decisions.md) | Open POS policy items referenced during phase planning |

Update this file when forward phase scope, sequencing, or implemented status changes. Update the root README compact summary in the same change.
