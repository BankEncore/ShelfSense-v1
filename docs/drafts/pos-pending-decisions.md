# POS Pending Decisions

**Status:** Active decision register  
**Source scope:** `docs/specifications/pos/*.md` on the repository `main` branch  
**Source review date:** 2026-08-14  
**Suggested repository path:** `docs/planning/pos-pending-decisions.md`

---
## Purpose
This document tracks unresolved design decisions explicitly identified by the POS domain specifications. It exists to prevent pending questions from being lost inside individual specifications and to make phase gates visible before implementation begins.
The register intentionally distinguishes source-derived timing from inferred implementation timing. It does **not** make a deferred feature mandatory merely because a pending question exists.
### Phase-association key
- **Explicit** — the owning specification states the target phase or deadline directly.
- **Inferred** — the phase is inferred from the specification's delivery sections and the first capability that requires the decision.
- **Conditional** — resolve only if/when the deferred capability is implemented.
### Status values
All entries are initially **Pending**. When a decision is made, retain the row, change `Status` to `Decided`, and record the governing ADR/spec/contract or short resolution. Existing decision IDs must never be renumbered or reused.
---
## Decision gates
The following are the decisions with the clearest near-term implementation dependency. Items already required in an earlier phase remain prerequisites for later phases even when not repeated there.
### Phase 4 — POS Runtime and Contract Foundation
- **POS-DEC-001 — Physical local schema** — [local-persistence.md](../specifications/pos/local-persistence.md) §27.1
- **POS-DEC-002 — Installation credential storage** — [local-persistence.md](../specifications/pos/local-persistence.md) §27.2
- **POS-DEC-011 — Policy-version semantics** — [approvals.md](../specifications/pos/approvals.md) §83.6
- **POS-DEC-043 — Inventory checkpoint contract** — [inventory-integration.md](../specifications/pos/inventory-integration.md) §42.1
- **POS-DEC-049 — Inventory-effect linkage** — [inventory-integration.md](../specifications/pos/inventory-integration.md) §42.7
- **POS-DEC-050 — Exact synchronization outcomes** — [operation-synchronization.md](../specifications/pos/operation-synchronization.md) §53.1
- **POS-DEC-051 — Payload canonicalization/hash** — [operation-synchronization.md](../specifications/pos/operation-synchronization.md) §53.2
- **POS-DEC-052 — Batch transport** — [operation-synchronization.md](../specifications/pos/operation-synchronization.md) §53.3
- **POS-DEC-055 — Server ingest retention** — [operation-synchronization.md](../specifications/pos/operation-synchronization.md) §53.6
- **POS-DEC-058 — Effective dating** — [pricing.md](../specifications/pos/pricing.md) §60.3
- **POS-DEC-074 — Initial condition catalog** — [reconciliation.md](../specifications/pos/reconciliation.md) §45.1
- **POS-DEC-075 — Severity vocabulary** — [reconciliation.md](../specifications/pos/reconciliation.md) §45.2
- **POS-DEC-080 — Cursor representation** — [reference-replication.md](../specifications/pos/reference-replication.md) §42.1
- **POS-DEC-081 — Delta organization** — [reference-replication.md](../specifications/pos/reference-replication.md) §42.2
- **POS-DEC-082 — Snapshot pagination/chunking** — [reference-replication.md](../specifications/pos/reference-replication.md) §42.3
- **POS-DEC-083 — Tombstone representation** — [reference-replication.md](../specifications/pos/reference-replication.md) §42.4
- **POS-DEC-086 — Inventory checkpoint replication** — [reference-replication.md](../specifications/pos/reference-replication.md) §42.7
- **POS-DEC-110 — Exact tax-rate representation** — [tax.md](../specifications/pos/tax.md) §86.1
- **POS-DEC-111 — Rate precision** — [tax.md](../specifications/pos/tax.md) §86.2
- **POS-DEC-112 — Stable component ordering** — [tax.md](../specifications/pos/tax.md) §86.3
- **POS-DEC-116 — Calendar-effective representation** — [tax.md](../specifications/pos/tax.md) §86.7
- **POS-DEC-135 — Installation credential mechanism** — [workstation-identity.md](../specifications/pos/workstation-identity.md) §46.1
- **POS-DEC-136 — Enrollment workflow** — [workstation-identity.md](../specifications/pos/workstation-identity.md) §46.2

### Phase 5 — First Operational Cash Sale
- **POS-DEC-016 — Drawer identity** — [cash-handling.md](../specifications/pos/cash-handling.md) §91.1
- **POS-DEC-044 — Local availability warnings** — [inventory-integration.md](../specifications/pos/inventory-integration.md) §42.2
- **POS-DEC-065 — Receipt display format** — [receipts.md](../specifications/pos/receipts.md) §71.1
- **POS-DEC-066 — Receipt sequence starting value** — [receipts.md](../specifications/pos/receipts.md) §71.2
- **POS-DEC-068 — Header/footer snapshot policy** — [receipts.md](../specifications/pos/receipts.md) §71.4
- **POS-DEC-069 — Reprint marking** — [receipts.md](../specifications/pos/receipts.md) §71.5
- **POS-DEC-070 — Initial print retry labeling** — [receipts.md](../specifications/pos/receipts.md) §71.6
- **POS-DEC-085 — Offline authorization data** — [reference-replication.md](../specifications/pos/reference-replication.md) §42.6
- **POS-DEC-087 — Business-day transition policy** — [reporting-periods.md](../specifications/pos/reporting-periods.md) §93.1
- **POS-DEC-089 — Minimum Phase 5 Z contents** — [reporting-periods.md](../specifications/pos/reporting-periods.md) §93.3
- **POS-DEC-130 — Meaningful cancellation threshold** — [transactions.md](../specifications/pos/transactions.md) §38.1

> Phase 4/5 cross-phase entries such as tender configuration, offline valuation, and meaningful-line persistence are listed in the master register below rather than duplicated in both gate lists.
---
## Master pending-decision register
This register contains **139 source-level pending decisions**. Duplicate concerns intentionally remain source-traceable here; the cross-spec consolidation section identifies decisions that should be resolved once across multiple specifications.
### [`local-persistence.md`](../specifications/pos/local-persistence.md)
| ID | Source | Decision | Required by | Association | Owner | Status | Resolution |
|---|---|---|---|---|---|---|---|
| POS-DEC-001 | §27.1 | **Physical local schema** — Define local SQLite tables/indexes as owning domains are implemented without creating a second parallel business model. | Phase 4 | Explicit | Local Persistence | Pending | — |
| POS-DEC-002 | §27.2 | **Installation credential storage** — Choose which installation security material belongs in SQLite, platform-protected credential storage, or both. | Phase 4 | Inferred | Local Persistence / Workstation Identity | Pending | — |
| POS-DEC-003 | §27.3 | **Local history retention** — Determine how much centrally acknowledged local business history remains on the workstation. | Phase 6B | Inferred | Local Persistence / Receipts | Pending | — |
| POS-DEC-004 | §27.4 | **Backup and restore** — Define productized backup/restore after replacement, synchronization, and receipt/Z recovery rules are established. | Phase 6B | Explicit | Local Persistence | Pending | — |
| POS-DEC-005 | §27.5 | **Recovery tooling** — Define diagnosis and recovery for damaged or missing POS databases. | Phase 6B | Explicit | Local Persistence | Pending | — |

### [`approvals.md`](../specifications/pos/approvals.md)
| ID | Source | Decision | Required by | Association | Owner | Status | Resolution |
|---|---|---|---|---|---|---|---|
| POS-DEC-006 | §83.1 | **Concrete policy persistence model** — Choose a common typed policy model, action-specific policy records, or another constrained representation; do not create an unrestricted expression engine. | Phase 6.1 | Explicit | Approvals | **MVP-resolved** | [controlled-actions.md](../planning/phase4-6-point-of-sale/phase6-pos-mvp/controlled-actions.md): no policy table; `phase6_permission_tier_v1` |
| POS-DEC-007 | §83.2 | **Initial action catalog** — Lock application-defined controlled-action identifiers. | Phase 6.1 | Explicit | Approvals | **MVP-resolved** | 6.4 seeds `price_override`, `line_discount`, `tax_class_override`; others reserved |
| POS-DEC-008 | §83.3 | **Permission catalog** — Define perform/approve permissions for supported controlled actions. | Phase 5 / 6.1 | Inferred | Approvals / Authorization | **MVP-resolved** | `.perform` / `.approve` per 6.4 action |
| POS-DEC-009 | §83.4 | **Initial numeric thresholds** — Define organization defaults and store overrides for controlled-action thresholds as each capability is introduced. | Phase 6.1–6.5 | Explicit | Approvals + owning domains | Pending | Deferred; permission-tier only |
| POS-DEC-010 | §83.5 | **Reason requirements** — For each controlled action, determine whether a structured reason is never, conditionally, or always required independent of approval. | Phase 6.1–6.5 | Explicit | Approvals + owning domains | **MVP-resolved** | Always required for 6.4 actions |
| POS-DEC-011 | §83.6 | **Policy-version semantics** — Define the durable policy version/revision representation preserved by the workstation and completed facts. | Phase 4 | Inferred | Approvals / Reference Replication | **MVP-resolved** | Snapshot `phase6_permission_tier_v1` |
| POS-DEC-012 | §83.7 | **Action canonicalization/fingerprint** — If deterministic action fingerprints are used, define material fields, canonical representation, and versioning. | Phase 6.1 | Inferred | Approvals contract | **MVP-resolved** | Canonical JSON SHA-256; reason_code material; `v1` |
| POS-DEC-013 | §83.8 | **Quantity-change invalidation** — Define which quantity changes invalidate price-override or discount approval. | Phase 6.1 / 6.3 | Inferred | Approvals / Pricing / Discounts | **MVP-resolved** | Quantity change blocked until override/discount removed |
| POS-DEC-014 | §83.9 | **Transaction-change invalidation** — Define basket mutations that require transaction-level approval re-evaluation. | Phase 6.3 | Inferred | Approvals / Discounts | **MVP-resolved** | N/A until transaction-level actions |
| POS-DEC-015 | §83.10 | **Approval-request persistence** — Decide whether awaiting-approval requests are durable working records or represented through underlying working state plus activity. | Phase 6.1 | Inferred | Approvals / Local Persistence | **MVP-resolved** | None; synchronous second actor |

### [`cash-handling.md`](../specifications/pos/cash-handling.md)
| ID | Source | Decision | Required by | Association | Owner | Status | Resolution |
|---|---|---|---|---|---|---|---|
| POS-DEC-016 | §91.1 | **Drawer identity** — Decide whether a physical drawer is a permanently configured object or initially a workstation-attached Cash location. | Phase 5 | Inferred | Cash Handling | Pending | — |
| POS-DEC-017 | §91.2 | **Cashier custody model** — Define Phase 6 semantics for cashier-owned drawers, shared drawers, and cashier handoff. | Phase 6.5 | Explicit | Cash Handling | Pending | — |
| POS-DEC-018 | §91.3 | **Opening-float source** — When safe custody exists, decide whether every opening float must be backed by a source transfer. | Phase 6.5 | Inferred | Cash Handling | Pending | — |
| POS-DEC-019 | §91.4 | **Drawer-close cash removal** — Decide whether count, retained float, and transfer-to-safe are one orchestrated workflow or separate commands while retaining distinct facts. | Phase 6.5 | Inferred | Cash Handling | Pending | — |
| POS-DEC-020 | §91.5 | **Paid-in/out reason catalogs** — Define initial structured paid-in and paid-out reasons. | Phase 6.5 | Explicit | Cash Handling | Pending | — |
| POS-DEC-021 | §91.6 | **Paid-in/out approval thresholds** — Define organization/store policy for direct, approval-required, and prohibited paid-in/out actions. | Phase 6.5 | Inferred | Cash Handling / Approvals | Pending | — |
| POS-DEC-022 | §91.7 | **Transfer approval** — Determine whether drops/replenishments require approval by amount or location. | Phase 6.5 | Inferred | Cash Handling / Approvals | Pending | — |
| POS-DEC-023 | §91.8 | **Cash locations** — Define initial Cash location types and whether stores may configure multiple safes or other locations. | Phase 6.5 | Inferred | Cash Handling | Pending | — |
| POS-DEC-024 | §91.9 | **Blind-count policy** — Define when first count is blind, who may see expected Cash, and when a second actor is required. | Phase 6.5 | Inferred | Cash Handling / Approvals | Pending | — |
| POS-DEC-025 | §91.10 | **Variance thresholds** — Define thresholds for ordinary close, approval-required close, and investigation/escalation. | Phase 6.5 | Inferred | Cash Handling / Approvals | Pending | — |
| POS-DEC-026 | §91.11 | **Count denomination detail** — Decide whether Phase 6.5 stores denomination-level counts or only total cents. | Phase 6.5 | Explicit | Cash Handling | Pending | — |
| POS-DEC-027 | §91.12 | **Closed-drawer corrections** — Define explicit correction workflow for Cash activity discovered after drawer close without reopening/editing the closed session. | Phase 6.5 | Inferred | Cash Handling | Pending | — |
| POS-DEC-028 | §91.13 | **Transfer in transit** — Introduce an in-transit custody state only if real workflows require delayed receipt acknowledgment. | Future | Conditional | Cash Handling | Pending | — |
| POS-DEC-029 | §91.14 | **Deposit tracking** — Define deposit batches/bags, bank references, verification, and bank reconciliation when deposit workflow is introduced. | Future | Conditional | Cash Handling / Financial | Pending | — |

### [`discounts.md`](../specifications/pos/discounts.md)
| ID | Source | Decision | Required by | Association | Owner | Status | Resolution |
|---|---|---|---|---|---|---|---|
| POS-DEC-030 | §87.1 | **Discount method set** — Confirm whether Phase 6.3 needs fixed_per_unit in addition to fixed_amount and percentage. | Phase 6.3 | Explicit | Discounts | Pending | — |
| POS-DEC-031 | §87.2 | **Discount source taxonomy** — Lock initial discount source identifiers such as manual, promotion, coupon, member, employee, and other. | Phase 6.3 | Inferred | Discounts | Pending | — |
| POS-DEC-032 | §87.3 | **Ordering within source classes** — Define deterministic order among multiple automatic promotions and multiple manual discounts. | Phase 6.3 | Inferred | Discounts | Pending | — |
| POS-DEC-033 | §87.4 | **Residual-cent allocation** — Define the exact stable residual-cent allocation rule for transaction discounts. | Phase 6.3 | Explicit | Discounts calculation contract | Pending | — |
| POS-DEC-034 | §87.5 | **Percentage rounding** — Define percentage basis, precision, rounding mode, and rounding stage. | Phase 6.3 | Explicit | Discounts calculation contract | **MVP-resolved** | Half-up on selling_basis × bp / 10_000; reject 0 cents |
| POS-DEC-035 | §87.6 | **Excess fixed-discount behavior** — Decide whether a requested fixed discount above eligible basis is capped, prohibited, or program-specific. | Phase 6.3 | Inferred | Discounts | Pending | — |
| POS-DEC-036 | §87.7 | **Open-ring eligibility** — Define default eligibility of open rings for manual line discounts, manual transaction discounts, and automatic promotions. | Phase 6.3 | Inferred | Discounts / Transaction Lines | Pending | — |
| POS-DEC-037 | §87.8 | **Discount reason policy** — Define which manual discounts require a structured reason independent of approval. | Phase 6.3 | Inferred | Discounts / Approvals | **MVP-resolved** | Always required |
| POS-DEC-038 | §87.9 | **Discount approval thresholds** — Define organization/store policies for line and transaction percentage/cents thresholds. | Phase 6.3 | Inferred | Discounts / Approvals | Pending | Deferred with POS-DEC-009 |
| POS-DEC-039 | §87.10 | **Transaction approval invalidation** — Lock basket changes that invalidate approval for a transaction-level discount. | Phase 6.3 | Inferred | Discounts / Approvals | Pending | — |
| POS-DEC-040 | §87.11 | **Suspended transaction refresh** — Decide how automatic and manual discounts behave when a suspended transaction is recalled. | Phase 6.3 | Inferred | Discounts / Transactions | Pending | — |
| POS-DEC-041 | §87.12 | **Coupon program classification** — When coupons are introduced, explicitly classify each program as discount or tender according to economic substance. | Future | Conditional | Discounts / Tenders | Pending | — |
| POS-DEC-042 | §87.13 | **Promotion clawback** — Keep historical proportional reversal initially; any promotion clawback/requalification must be designed explicitly. | Future | Conditional | Discounts / Returns | Pending | — |

### [`inventory-integration.md`](../specifications/pos/inventory-integration.md)
| ID | Source | Decision | Required by | Association | Owner | Status | Resolution |
|---|---|---|---|---|---|---|---|
| POS-DEC-043 | §42.1 | **Inventory checkpoint contract** — Define server-to-POS quantity balances, unit state, and watermark/acknowledgment needed to remove local overlays. | Phase 4 | Explicit | Inventory Integration / Reference Replication | Pending | — |
| POS-DEC-044 | §42.2 | **Local availability warnings** — Define cashier UX/policy when quantity-tracked effective available is less than or equal to zero. | Phase 5 | Inferred | Inventory Integration | Pending | — |
| POS-DEC-045 | §42.3 | **Reservation integration** — Define how local/central reservation facts contribute to reserved without becoming on-hand ledger movements. | Phase 7 | Inferred | Inventory Integration / Customer Requests | Pending | — |
| POS-DEC-046 | §42.4 | **Individually tracked availability projection** — Define exact local inventory-unit availability states. | Phase 6.1 | Explicit | Inventory Integration | Pending | — |
| POS-DEC-047 | §42.5 | **Unlinked-return inventory behavior** — Finalize inventory consequences for unlinked returns with Returns. | Phase 6.4 | Explicit | Inventory Integration / Returns | Pending | — |
| POS-DEC-048 | §42.6 | **Valuation of late offline operations** — Define how valuation treats business occurrence time versus central posting order for late sale/return operations. | Phase 4 / 5 | Inferred | Inventory Valuation | Pending | — |
| POS-DEC-049 | §42.7 | **Inventory-effect linkage** — Define exact central relationship among POS operation, transaction line, inventory ledger entry, and valuation entry for idempotency/audit/reporting. | Phase 4 | Inferred | Inventory Integration | Pending | — |

### [`operation-synchronization.md`](../specifications/pos/operation-synchronization.md)
| ID | Source | Decision | Required by | Association | Owner | Status | Resolution |
|---|---|---|---|---|---|---|---|
| POS-DEC-050 | §53.1 | **Exact synchronization outcomes** — Define the precise sync outcome vocabulary and relationship to warnings/reconciliation conditions. | Phase 4 | Explicit | Operation Synchronization / Sync Outcomes contract | Pending | — |
| POS-DEC-051 | §53.2 | **Payload canonicalization/hash** — Define material fields and canonicalization used to bind operation ID to payload identity. | Phase 4 | Inferred | Operation Synchronization contract | Pending | — |
| POS-DEC-052 | §53.3 | **Batch transport** — Decide whether Phase 4 sends single-operation requests or supports batches immediately. | Phase 4 | Explicit | Operation Synchronization | Pending | — |
| POS-DEC-053 | §53.4 | **Operation dependencies** — Define dependency semantics only for operation types that concretely require them. | Phase 6.4+ | Conditional | Operation Synchronization + owning domains | Pending | — |
| POS-DEC-054 | §53.5 | **Historical recovery from inactive installations** — Define whether and how previously committed operations from a replaced/inactive installation may upload later. | Phase 6B | Inferred | Operation Synchronization / Workstation Identity / Local Persistence | Pending | — |
| POS-DEC-055 | §53.6 | **Server ingest retention** — Define central retention of operation ID, payload hash, outcome, and reconciliation references sufficient for durable idempotency. | Phase 4 | Inferred | Operation Synchronization | Pending | — |

### [`pricing.md`](../specifications/pos/pricing.md)
| ID | Source | Decision | Required by | Association | Owner | Status | Resolution |
|---|---|---|---|---|---|---|---|
| POS-DEC-056 | §60.1 | **Final individually tracked fallback hierarchy** — Confirm unit approved price → variant regular price → failure, or define another explicit fallback. | Phase 6.1 | Explicit | Pricing | Pending | — |
| POS-DEC-057 | §60.2 | **Meaning of unit approved selling price** — Define which inventory-unit field/state qualifies and whether price approval is separate from ordinary unit editing. | Phase 6.1 | Inferred | Pricing / Inventory | Pending | — |
| POS-DEC-058 | §60.3 | **Effective dating** — Decide whether Phase 4/5 regular pricing requires effective-dated records or current reference configuration plus snapshots/version history. | Phase 4 | Explicit | Pricing / Reference Replication | Pending | — |
| POS-DEC-059 | §60.4 | **Override direction** — Confirm whether policy permits downward-only or both upward and downward overrides. | Phase 6.1 | Explicit | Pricing / Approvals | **MVP-resolved** | Both directions; price >= 0 |
| POS-DEC-060 | §60.5 | **Override thresholds** — Define cents/percentage threshold representation and initial organization/store policies. | Phase 6.1 | Explicit | Pricing / Approvals | Pending | Deferred with POS-DEC-009 |
| POS-DEC-061 | §60.6 | **Override reason policy** — Define reason catalog and whether reasons are universal or policy-controlled. | Phase 6.1 | Explicit | Pricing / Approvals | **MVP-resolved** | Always required; code-defined catalog |
| POS-DEC-062 | §60.7 | **Override percentage formula** — Lock sign convention, denominator, zero-reference behavior, and rounding. | Phase 6.1 | Explicit | Pricing calculation contract | Pending | — |
| POS-DEC-063 | §60.8 | **Suspended price refresh** — Define when reference prices refresh on recall and how existing override/approval state is handled. | Phase 6.1 | Inferred | Pricing / Transactions / Approvals | Pending | — |
| POS-DEC-064 | §60.9 | **Future price-source hierarchy** — Require formal precedence before adding any new price source beyond initial variant/unit rules. | Future | Conditional | Pricing | Pending | — |

### [`receipts.md`](../specifications/pos/receipts.md)
| ID | Source | Decision | Required by | Association | Owner | Status | Resolution |
|---|---|---|---|---|---|---|---|
| POS-DEC-065 | §71.1 | **Receipt display format** — Define the human-facing representation of store, workstation, and receipt sequence. | Phase 5 | Inferred | Receipts | Pending | — |
| POS-DEC-066 | §71.2 | **Receipt sequence starting value** — Define workstation sequence initialization behavior. | Phase 5 | Inferred | Receipts | Pending | — |
| POS-DEC-067 | §71.3 | **Replacement/high-water recovery** — Define safe receipt-sequence continuation when the old installation may contain unsynchronized receipts. | Phase 6B | Explicit | Receipts / Workstation Identity | Pending | — |
| POS-DEC-068 | §71.4 | **Header/footer snapshot policy** — Classify legal organization name, store address, phone, tax registration number, return policy, etc. as historical snapshot, current presentation, or legally historical. | Phase 5 | Inferred | Receipts | Pending | — |
| POS-DEC-069 | §71.5 | **Reprint marking** — Define customer-facing copy/reprint wording and layout. | Phase 5 | Inferred | Receipts | Pending | — |
| POS-DEC-070 | §71.6 | **Initial print retry labeling** — Decide whether a delayed successful first print after hardware failure is marked as a reprint. | Phase 5 | Inferred | Receipts | Pending | — |
| POS-DEC-071 | §71.7 | **Print-event persistence** — Decide which receipt delivery attempts/reprints require durable records versus ordinary logging/audit. | Phase 5 / 6B | Inferred | Receipts / Audit | Pending | — |
| POS-DEC-072 | §71.8 | **Electronic receipts** — Define channel-specific electronic receipt behavior only when a concrete need exists. | Phase 6B / Future | Conditional | Receipts | Pending | — |
| POS-DEC-073 | §71.9 | **Template version preservation** — Decide whether exact historical visual templates must be preserved or factual historical reproduction is sufficient. | Phase 6B | Inferred | Receipts | Pending | — |

### [`reconciliation.md`](../specifications/pos/reconciliation.md)
| ID | Source | Decision | Required by | Association | Owner | Status | Resolution |
|---|---|---|---|---|---|---|---|
| POS-DEC-074 | §45.1 | **Initial condition catalog** — Define reconciliation condition types incrementally as concrete conflict scenarios are implemented. | Phase 4 | Inferred | Reconciliation + owning domains | Pending | — |
| POS-DEC-075 | §45.2 | **Severity vocabulary** — Finalize the conceptual informational/warning/requires-action severity vocabulary. | Phase 4 | Inferred | Reconciliation | Pending | — |
| POS-DEC-076 | §45.3 | **Resolution outcomes** — Decide whether structured generic outcomes such as automatically_corrected, accepted_as_is, and corrective_action_completed are useful. | Phase 6 | Inferred | Reconciliation | Pending | — |
| POS-DEC-077 | §45.4 | **Assignment/ownership** — Decide whether open reconciliation conditions need assigned user/team and due/escalation metadata. | Phase 6 / 6B | Inferred | Reconciliation UX | Pending | — |
| POS-DEC-078 | §45.5 | **Acknowledgment** — Decide whether informational/warning conditions need a separate acknowledged state or whether resolution history is sufficient. | Phase 6 | Inferred | Reconciliation | Pending | — |
| POS-DEC-079 | §45.6 | **Reconciliation retention** — Confirm long-term retention of conditions/resolutions with operational history rather than deleting after resolution. | Phase 6B | Inferred | Reconciliation | Pending | — |

### [`reference-replication.md`](../specifications/pos/reference-replication.md)
| ID | Source | Decision | Required by | Association | Owner | Status | Resolution |
|---|---|---|---|---|---|---|---|
| POS-DEC-080 | §42.1 | **Cursor representation** — Define the exact cursor format; prefer opaque authoritative continuation token unless stronger semantics are needed. | Phase 4 | Explicit | Reference Replication contract | Pending | — |
| POS-DEC-081 | §42.2 | **Delta organization** — Choose one ordered global POS stream, scoped streams, or another mechanism preserving coherent ordering. | Phase 4 | Explicit | Reference Replication | Pending | — |
| POS-DEC-082 | §42.3 | **Snapshot pagination/chunking** — Decide whether initial snapshots require chunking and ensure partial snapshots are never exposed as complete. | Phase 4 | Inferred | Reference Replication | Pending | — |
| POS-DEC-083 | §42.4 | **Tombstone representation** — Define exact deactivation/removal representation. | Phase 4 | Inferred | Reference Replication contract | Pending | — |
| POS-DEC-084 | §42.5 | **Reference-history retention** — Determine how much prior reference-version data remains locally beyond values snapshotted into completed transactions. | Phase 6B | Inferred | Reference Replication / Local Persistence | Pending | — |
| POS-DEC-085 | §42.6 | **Offline authorization data** — Define minimum safe authentication/permission material needed for offline cashier authentication. | Phase 5 | Explicit | Reference Replication / Authentication | Pending | — |
| POS-DEC-086 | §42.7 | **Inventory checkpoint replication** — Define exact inventory checkpoint representation jointly with Inventory Integration. | Phase 4 | Explicit | Reference Replication / Inventory Integration | Pending | — |

### [`reporting-periods.md`](../specifications/pos/reporting-periods.md)
| ID | Source | Decision | Required by | Association | Owner | Status | Resolution |
|---|---|---|---|---|---|---|---|
| POS-DEC-087 | §93.1 | **Business-day transition policy** — Define exactly when a workstation must close current Z and open a new one across a business-date boundary while preserving one-final-Z-per-business-date. | Phase 5 | Inferred | Reporting Periods | Pending | — |
| POS-DEC-088 | §93.2 | **Z numbering** — Define workstation-local Z sequence initialization, persistence, gap handling, and replacement behavior. | Phase 5 / 6B | Inferred | Reporting Periods / Workstation Identity | Pending | — |
| POS-DEC-089 | §93.3 | **Minimum Phase 5 Z contents** — Lock exact required Z snapshot fields. | Phase 5 | Explicit | Reporting Periods | Pending | — |
| POS-DEC-090 | §93.4 | **Multiple drawer/Z relationship** — Define allowed cardinality once Phase 6 Cash Handling supports multiple drawer sessions; do not assume permanent 1:1. | Phase 6.5 | Explicit | Reporting Periods / Cash Handling | Pending | — |
| POS-DEC-091 | §93.5 | **Store Close necessity** — Determine from pilot/operational experience whether formal Store Close is actually needed. | Phase 6 / Later | Conditional | Reporting Periods | Pending | — |
| POS-DEC-092 | §93.6 | **Store Close totals snapshot** — If Store Close is implemented, decide whether it stores only control metadata/Z references or also an immutable totals snapshot. | If Store Close | Conditional | Reporting Periods | Pending | — |
| POS-DEC-093 | §93.7 | **No-activity mechanism** — If Store Close requires completeness, decide whether no-activity acknowledgment is workstation-originated, manager-entered, or both. | If Store Close | Conditional | Reporting Periods | Pending | — |
| POS-DEC-094 | §93.8 | **Store Close amendments** — Define exact amendment/version mechanics only if Store Close is implemented. | If Store Close | Conditional | Reporting Periods | Pending | — |
| POS-DEC-095 | §93.9 | **Central report completeness messaging** — Define how UI/reporting communicates that disconnected workstations may make current central totals incomplete. | Phase 6 / 6B | Inferred | Reporting Periods UX | Pending | — |

### [`returns.md`](../specifications/pos/returns.md)
| ID | Source | Decision | Required by | Association | Owner | Status | Resolution |
|---|---|---|---|---|---|---|---|
| POS-DEC-096 | §93.1 | **Return eligibility policy** — Define return windows, merchandise exclusions, store overrides, and exception paths. | Phase 6.4 | Explicit | Returns | Pending | — |
| POS-DEC-097 | §93.2 | **Return-policy snapshots** — Decide whether original sales snapshot return-policy identity/version and how eligibility behaves after policy changes. | Phase 6.4 | Inferred | Returns | Pending | — |
| POS-DEC-098 | §93.3 | **Return reasons** — Define initial structured reason catalog and which return types require a reason. | Phase 6.4 | Inferred | Returns / Approvals | Pending | — |
| POS-DEC-099 | §93.4 | **Linked-return approval thresholds** — Define direct versus approval-required behavior by amount, age, merchandise, refund method, and exception status. | Phase 6.4 | Inferred | Returns / Approvals | Pending | — |
| POS-DEC-100 | §93.5 | **Unlinked-return refund basis** — Define how value is established without authoritative historical sale evidence. | Phase 6.4 | Explicit | Returns | Pending | — |
| POS-DEC-101 | §93.6 | **Unlinked-return tax treatment** — Define tax treatment for unlinked returns without pretending current tax is historical reversal. | Phase 6.4 | Explicit | Returns / Tax | Pending | — |
| POS-DEC-102 | §93.7 | **Unlinked inventory-unit behavior** — Define whether/how individually tracked merchandise may be accepted without authoritative original-line linkage. | Phase 6.4 | Explicit | Returns / Inventory Integration | Pending | — |
| POS-DEC-103 | §93.8 | **Refund-selection policy** — Define recommendations/restrictions across original Card, Cash, Store Credit, Check, Other, and mixed original tender. | Phase 6.4 | Inferred | Returns / Tenders | Pending | — |
| POS-DEC-104 | §93.9 | **Card refund workflow** — Define external processor refund behavior and unknown-result recovery before Card returns are production-ready. | Phase 6.4 | Explicit | Returns / Tenders | Pending | — |
| POS-DEC-105 | §93.10 | **Stored Value refund protocol** — Define authoritative atomic credit protocol before Store Credit/Gift Card refunds are enabled. | Future | Conditional | Returns / Stored Value / Tenders | Pending | — |
| POS-DEC-106 | §93.11 | **Partial-return residual rule** — Lock shared deterministic historical-cent consumption algorithm for Discounts and Tax. | Phase 6.4 | Explicit | Returns / Discounts / Tax | Pending | — |
| POS-DEC-107 | §93.12 | **Offline return freshness** — Define what cached original-return state is sufficiently reliable for offline linked returns. | Phase 6.4 | Explicit | Returns / Reconciliation | Pending | — |
| POS-DEC-108 | §93.13 | **Cross-workstation return claim** — Decide whether online central returnability validation/reservation is required when original sale came from another workstation. | Phase 6.4 | Inferred | Returns / Operation Synchronization | Pending | — |
| POS-DEC-109 | §93.14 | **Post-void** — Finalize post-void as a separate correction specification/workflow rather than overloading Returns. | Phase 6.4+ | Explicit | Returns / Transactions | Pending | — |

### [`tax.md`](../specifications/pos/tax.md)
| ID | Source | Decision | Required by | Association | Owner | Status | Resolution |
|---|---|---|---|---|---|---|---|
| POS-DEC-110 | §86.1 | **Exact tax-rate representation** — Choose exact cross-runtime representation such as scaled integer or canonical decimal. | Phase 4 | Explicit | Tax calculation contract | Pending | — |
| POS-DEC-111 | §86.2 | **Rate precision** — Define supported tax-rate precision; do not assume two decimal places of percentage precision. | Phase 4 | Inferred | Tax calculation contract | Pending | — |
| POS-DEC-112 | §86.3 | **Stable component ordering** — Define deterministic tax-component ordering for fixtures, serialization, receipts, and reporting. | Phase 4 | Inferred | Tax calculation/serialization contract | Pending | — |
| POS-DEC-113 | §86.4 | **Partial-return cent consumption** — Define exact historical tax-cent allocation for quantity greater than one sharing an indivisible cent. | Phase 6.4 | Explicit | Tax / Returns | Pending | — |
| POS-DEC-114 | §86.5 | **Unlinked-return tax policy** — Define tax handling when no authoritative original sale exists. | Phase 6.4 | Explicit | Tax / Returns | Pending | — |
| POS-DEC-115 | §86.6 | **Future exemption override model** — Decide whether customer exemptions replace normal treatment or act as an explicit exemption modifier. | Future | Conditional | Tax / Customers | Pending | — |
| POS-DEC-116 | §86.7 | **Calendar-effective representation** — Choose exact local effective timestamps or local effective dates with deterministic midnight semantics. | Phase 4 | Inferred | Tax / Reference Replication | Pending | — |

### [`tender.md`](../specifications/pos/tender.md)
| ID | Source | Decision | Required by | Association | Owner | Status | Resolution |
|---|---|---|---|---|---|---|---|
| POS-DEC-117 | §55 | **Exact tender type configuration** — Define the minimal/configurable tender fields and behavior flags needed by actual operations without building a generic rules engine. | Phase 4 / 5 | Inferred | Tenders / Reference Replication | Pending | — |
| POS-DEC-118 | §56 | **Card processor contract** — Define processor boundary, authorization/capture model, unresolved-state recovery, reversal/void behavior, and retained processor references. | Phase 6.2 | Inferred | Tenders / Card integration | Pending | — |
| POS-DEC-119 | §57 | **Check metadata** — Decide whether durable fields beyond amount/type are needed, such as check number or identification reference. | Phase 6.2 | Inferred | Tenders | Pending | — |
| POS-DEC-120 | §58 | **Stored Value domain** — Define account identity, authoritative balance, redemption/credit semantics, and synchronization/atomicity before enabling Stored Value tender. | Future | Conditional | Stored Value / Tenders | Pending | — |
| POS-DEC-121 | §59 | **Other tender controls** — Define which real external settlement methods qualify as Other and what configuration/approval they require. | Phase 6.2 | Inferred | Tenders / Approvals | Pending | — |
| POS-DEC-122 | §60 | **Refund tender policy** — Finalize original-tender requirements and refund-method restrictions jointly with Returns. | Phase 6.4 | Inferred | Tenders / Returns | Pending | — |

### [`transaction-lines.md`](../specifications/pos/transaction-lines.md)
| ID | Source | Decision | Required by | Association | Owner | Status | Resolution |
|---|---|---|---|---|---|---|---|
| POS-DEC-123 | §67.1 | **Open-ring reason policy** — Define when open-ring reason is optional/required, reason catalog, and approval requirements. | Phase 6.1 | Explicit | Transaction Lines / Approvals | Pending | — |
| POS-DEC-124 | §67.2 | **Open-ring discount eligibility** — Define default open-ring eligibility for manual discounts, transaction discounts, and promotions requiring merchandise identity. | Phase 6.3 | Explicit | Transaction Lines / Discounts | Pending | — |
| POS-DEC-125 | §67.3 | **Automatic open-ring consolidation** — Confirm whether separately entered open rings should remain separate rather than auto-consolidate. | Phase 6.1 | Inferred | Transaction Lines / POS UX | Pending | — |
| POS-DEC-126 | §67.4 | **Return-line consolidation** — Decide whether repeated linked-return selections from the same original line automatically merge. | Phase 6.4 | Explicit | Transaction Lines / Returns | Pending | — |
| POS-DEC-127 | §67.5 | **Unvoid behavior** — Choose explicit unvoid with activity history or require adding a new line instead. | Phase 6.1 | Inferred | Transaction Lines | Pending | — |
| POS-DEC-128 | §67.6 | **Meaningful line persistence** — Define when a newly entered working line becomes meaningful enough that later void/cancellation must retain it. | Phase 5 / 6.1 | Inferred | Transaction Lines / Transactions | Pending | — |
| POS-DEC-129 | §67.7 | **Fractional quantities** — If weight/measure merchandise is introduced, deliberately redefine the current positive-integer quantity invariant. | Future | Conditional | Transaction Lines | Pending | — |

### [`transactions.md`](../specifications/pos/transactions.md)
| ID | Source | Decision | Required by | Association | Owner | Status | Resolution |
|---|---|---|---|---|---|---|---|
| POS-DEC-130 | §38.1 | **Meaningful cancellation threshold** — Define when abandoned work must be retained as a cancelled transaction instead of discarded as ephemeral UI state. | Phase 5 | Inferred | Transactions | Pending | — |
| POS-DEC-131 | §38.2 | **Suspended transaction refresh** — Define which prices, taxes, and automatic discounts refresh on recall and how overrides/approvals are preserved or revalidated. | Phase 6.1 / 6.3 | Inferred | Transactions / Pricing / Tax / Discounts / Approvals | Pending | — |
| POS-DEC-132 | §38.3 | **Cross-workstation handoff** — Define ownership, claim, concurrency, and stale-work behavior before suspended transactions may move between workstations. | Future | Conditional | Transactions / Synchronization | Pending | — |
| POS-DEC-133 | §38.4 | **Post-void** — Define authorization and reversal workflow for a completed transaction that should be treated as completed in error. | Phase 6.4+ | Inferred | Transactions / Returns / Tenders | Pending | — |
| POS-DEC-134 | §38.5 | **Completed tender correction** — Define correction of an incorrectly recorded completed tender without editing the completed transaction. | Phase 6.2 / 6.4+ | Inferred | Transactions / Tenders | Pending | — |

### [`workstation-identity.md`](../specifications/pos/workstation-identity.md)
| ID | Source | Decision | Required by | Association | Owner | Status | Resolution |
|---|---|---|---|---|---|---|---|
| POS-DEC-135 | §46.1 | **Installation credential mechanism** — Define exact machine credential form and lifecycle in enrollment/synchronization contracts. | Phase 4 | Inferred | Workstation Identity / Operation Synchronization | Pending | — |
| POS-DEC-136 | §46.2 | **Enrollment workflow** — Define who may enroll, workstation selection, bootstrap-token mechanics, and re-enrollment behavior. | Phase 4 | Inferred | Workstation Identity | Pending | — |
| POS-DEC-137 | §46.3 | **Inactive-reason taxonomy** — Decide whether structured reasons such as replaced/revoked/lost/decommissioned are needed or audit metadata is sufficient. | Phase 6B | Inferred | Workstation Identity | Pending | — |
| POS-DEC-138 | §46.4 | **Historical upload from inactive installation** — Decide whether an inactive/recovered installation may submit already-committed historical operations. | Phase 6B | Inferred | Workstation Identity / Operation Synchronization | Pending | — |
| POS-DEC-139 | §46.5 | **Clone detection** — Define production clone-detection strategy while preserving the one-originating-instance invariant. | Phase 6B | Explicit | Workstation Identity / Productization | Pending | — |

### [`customer-display.md`](../specifications/pos/customer-display.md)
The checked-in file is currently empty, so there are no source-supported pending decisions to include. Treat customer-display design as a documentation gap until that specification is authored; do not infer a decision backlog here from unrelated documents.
---
## Cross-spec consolidation candidates
The master register preserves every source entry, but the following concerns should normally be resolved as **one decision with multiple affected specifications** rather than independently in each document.
| Shared decision | Source entries to reconcile |
|---|---|
| **Inventory checkpoint + overlay watermark** | inventory-integration.md §42.1; reference-replication.md §42.7 |
| **Suspended-transaction refresh/revalidation** | transactions.md §38.2; pricing.md §60.8; discounts.md §87.11 |
| **Partial-return residual cents** | returns.md §93.11; tax.md §86.4; discounts.md §87.4/87.5 |
| **Unlinked-return tax** | returns.md §93.6; tax.md §86.5 |
| **Unlinked-return inventory** | returns.md §93.7; inventory-integration.md §42.5 |
| **Refund tender selection** | returns.md §93.8; tender.md §60 |
| **Card refund/external-state recovery** | returns.md §93.9; tender.md §56 |
| **Post-void** | returns.md §93.14; transactions.md §38.4 |
| **Historical upload from inactive installation** | workstation-identity.md §46.4; operation-synchronization.md §53.5; local-persistence.md §27.4/27.5 |
| **Receipt/Z sequence recovery after installation replacement** | receipts.md §71.3; reporting-periods.md §93.2; workstation-identity.md §46.5 |
| **Approval thresholds and reasons** | approvals.md §83.4/83.5; pricing.md §60.5/60.6; discounts.md §87.8/87.9; returns.md §93.3/93.4; cash-handling.md §91.5/91.6/91.7/91.10 |
| **Meaningful working-state persistence** | transactions.md §38.1; transaction-lines.md §67.6 |
| **Effective-date representation/versioning** | pricing.md §60.3; tax.md §86.7; reference-replication.md effective-dated contract |

When one of these is resolved, update all affected specifications to point to the same governing contract/ADR/specification rather than restating divergent rules.
---
## Phase-oriented working queues
For planning, the source-level register can be reduced to the following working queues. This section is guidance only; the master rows remain authoritative for source traceability.
### Phase 4 / Phase 5 — resolve before implementation
Prioritize runtime identity/enrollment, local durability, reference cursor/snapshot mechanics, sync outcomes/idempotency identity, inventory checkpoint/linkage, deterministic tax representation, Phase 5 offline authentication, Cash drawer identity, receipt sequence/presentation, Z transition/numbering/content, and cancellation/meaningful-line persistence.
### Phase 6.1–6.5 — resolve vertically with each capability
Resolve price-override/open-ring rules in 6.1, tender breadth in 6.2, discount arithmetic/policy in 6.3, return/refund/post-void rules in 6.4, and full Cash custody/count/transfer policy in 6.5. Avoid prematurely solving later-domain thresholds in Phase 4/5.
### Phase 6B — productization/recovery
Resolve workstation replacement, receipt/Z high-water recovery, clone detection, local retention/backup/recovery, richer diagnostics, and exact receipt-template/version behavior as productization work.
### Conditional/future
Stored Value, formal Store Close, deposits, fractional quantities, customer tax exemptions, advanced promotion clawback, electronic receipts, cross-workstation suspended handoff, and similar entries should remain dormant until a concrete roadmap capability requires them.
---
## Maintenance rules
1. Add a decision here when a POS specification marks a question as pending/open/unresolved or introduces a concrete decision gate.
2. Never renumber, recycle, or reorder the meaning of an existing `POS-DEC-###` ID; append new IDs at the end of the sequence.
3. Do not create speculative decisions merely because a future feature is imaginable.
4. Preserve the source section reference even after the decision is resolved.
5. Prefer one governing resolution for cross-spec decisions; update affected specifications to reference it.
6. Resolve decisions at the latest responsible moment before their implementation phase, not all POS policy up front.
7. If a decision changes an architectural invariant, record or supersede the appropriate ADR rather than resolving it only in this tracker.
8. When a source specification removes or resolves a pending decision, mark the tracker entry `Decided` and link the authority rather than deleting the row.
---
## Known source-level gates outside the rows
- `returns.md` requires **ADR-016** to be finalized or superseded before Phase 6.4 implementation.
- `customer-display.md` is empty and therefore contributes no source-supported decisions yet.
