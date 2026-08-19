# Phase 6 — Operational POS MVP

**Status:** Slice 6.0 contract locked ([mvp-contract.md](mvp-contract.md)). Slice 6.1 merchandise breadth implemented ([merchandise-breadth.md](merchandise-breadth.md)). Slice 6.2 tender breadth implemented ([tender-breadth.md](tender-breadth.md)). Slice 6.3 transaction history implemented ([transaction-history.md](transaction-history.md)). Slice 6.4 controlled actions implemented ([controlled-actions.md](controlled-actions.md)). Slice 6.5A directional Core implemented; slice 6.5B linked-return operator workflow implemented ([returns.md](returns.md)).

**Authority**

| Document | Role |
|---|---|
| [MVP contract](mvp-contract.md) | Slice 6.0: CompletedPosOperation v2 and cross-cutting locks |
| [Merchandise breadth](merchandise-breadth.md) | Slice 6.1: Used/individual and non-inventory sales |
| [Tender breadth](tender-breadth.md) | Slice 6.2: Cash/Card/Check/Other settlement |
| [Transaction history](transaction-history.md) | Slice 6.3: completed lookup, detail, reprint |
| [Controlled actions](controlled-actions.md) | Slice 6.4: price override, line discount, Tax Class override |
| [Returns](returns.md) | Slice 6.5: linked/unlinked returns, refunds, mixed sale+return (6.5A/B implemented; 6.5C next) |
| [Phase 4 plan](../phase4-point-of-sale/phase4-plan.md) | Completion, receipt allocation, inventory posting |
| [CompletedPosOperation v1](../phase4-point-of-sale/completed-pos-operation-v1.md) | Commercial base; v2 is additive |
| [POS tax contract](../phase4-point-of-sale/pos-tax-contract.md) | Tax Class / Store Tax; linked-return reversal ([§10](../phase4-point-of-sale/pos-tax-contract.md)) |
| [Phase 5 plan](../phase5-cash-register/phase5-plan.md) | Cash register, session close, Z; all-Cash path must remain equivalent |
| [Phases 4–6 plan](../spec.md) | Broader sequencing; this packet supersedes conflicting §6 |
| Accepted ADRs | ADR-006, ADR-007, ADR-008, ADR-009, ADR-011, ADR-012, ADR-013, ADR-019, ADR-020, ADR-021 |

Phase 4 is a headless Cash sale. Phase 5 is a cashier-usable online Cash register for quantity-tracked Standard merchandise. Phase 6 is the operational POS MVP on that same Rails register. No Terminal table (ADR-021). Offline sales stay out.

Draft POS specifications under `docs/drafts/specifications/pos/` remain vocabulary and domain meaning. This packet is implementation authority for the MVP subset.

---

## 1. Objective

Deliver a cashier-usable online register for ordinary bookstore checkout beyond Cash / Standard:

> Can a cashier sell Used units and non-inventory, take mixed tenders, look up and reprint completed history, apply controlled price/discount/Tax Class changes, take linked and unlinked returns (including mixed sale/return), post-void a whole transaction, and still close and finalize Z?

Slice 6.0 locks the completed-operation shape so later slices do not each invent a new completion contract. Slices 6.1–6.7 are independently mergeable to `main` and must leave the register usable.

---

## 2. Locked invariants

```text
one transaction model

line.direction:
  sale
  return

tender.direction:
  payment
  refund

working transaction = mutable
completed transaction = immutable

returns / post-void = new facts
never edits to completed history

inventory movement occurs only at completion

receipt assigned only at completion

all completed effects remain one atomic boundary
```

Magnitudes stay positive. `direction` supplies economic sign. There is no separate sale / refund / exchange transaction type. An exchange is sale lines plus return lines in one transaction.

Draft intent may be edited. Effective configuration is superseded. Completed business facts are reversed or corrected through new records ([ADR-012](../../../adr/ADR-012-record-lifecycle.md), [ADR-013](../../../adr/ADR-013-append-only-facts.md)).

Controllers and Stimulus continue to call domain services only. No receipt allocation, inventory posting, or commercial freeze outside `Pos::CompleteTransaction` (and the later return / post-void completion commands that reuse the same atomic boundary).

Every slice that adds a completed commercial fact must update, in that same slice:

```text
completed snapshot
receipt representation where customer-relevant
history / detail representation
audit
reporting where the new fact changes totals
```

6.7 consolidates and polishes. It does not repair knowingly inaccurate intermediate receipt, history, or Session/Z figures.

---

## 3. Delivery

Each numbered slice is a short-lived branch merged to `main` when the Phase 5 Cash sale path is still green. No long-lived `phase6` trunk ([github-workflow.md](../../../github-workflow.md)).

```text
main
  ├── 6.0  this packet (contract + 6.1 spec)
  ├── 6.1  merchandise breadth
  ├── 6.2  tender breadth
  ├── 6.3  transaction history
  ├── 6.4  controlled pricing / actions
  ├── 6.5  returns
  ├── 6.6  post-void
  └── 6.7  MVP closeout
```

Letter a slice (6.1A/B, 6.2A–E, 6.4A–D, 6.5A–D) only when a single PR would not stay reviewable. A stacked branch is allowed while a predecessor is still in review; the integration target remains `main`.

Write the detailed implementation contract for slices 6.6–6.7 immediately before building each slice, the same way Phase 5 locked [register-workspace.md](../phase5-cash-register/register-workspace.md) and [close-z-screens.md](../phase5-cash-register/close-z-screens.md) before those screens. 6.2–6.5 contracts are already written.

---

## 4. Slice map

| Slice | Scope | Primary deliverable | Merge gate (register remains usable) |
|---|---|---|---|
| **6.0** | MVP contract | Lock Phase 6 invariants and completed-operation shape | Docs only; no behavior change |
| **6.1** | Merchandise breadth | Used/individual + non-inventory sales | **Implemented.** Quantity-tracked Cash Standard path unchanged |
| **6.2** | Tender breadth | Card, Check, admin-created Other, mixed tender | **Implemented.** All-Cash sale remains Phase 5-equivalent; Session/Z shows Card/Check/Other |
| **6.3** | Transaction history | Lookup, detail, receipt reprint | **Implemented.** Sale workspace does not depend on history |
| **6.4** | Controlled pricing/actions | Approval framework, price override, line discount, Tax Class override | **Implemented.** Ordinary path stays `direct` unless policy requires a second actor |
| **6.5** | Returns | Linked, unlinked, price adjustment, mixed sale/return | **6.5A/B implemented** ([returns.md](returns.md)). 6.5C unlinked is next. Sale-only baskets still complete the same way; Session/Z is direction-aware |
| **6.6** | Post-void | Controlled whole-transaction correction | Entry is from history; sale path untouched |
| **6.7** | MVP closeout | Receipts, Z/tender reporting polish, audit/history UX, regression | Additive snapshots; already-finalized periods stay immutable |

---

## 5. Slices

### 6.0 — MVP contract (locked)

Authority: [mvp-contract.md](mvp-contract.md).

Planning/contract only. No unused Core columns. Defines CompletedPosOperation v2 so 6.1–6.6 do not break the completion shape six times.

### 6.1 — Merchandise breadth (implemented)

Authority: [merchandise-breadth.md](merchandise-breadth.md).

Sell every normal MVP tracking form on the existing Cash path:

```text
quantity-tracked Standard   (already works)
individually tracked Used
non-inventory Standard
```

Open ring is out. Unknown Used intake, buyback, transfers, and `reserved` are out.

### 6.2 — Tender breadth (implemented)

Authority: [tender-breadth.md](tender-breadth.md).

One settlement redesign, not three unrelated tender implementations.

- Seed protected system identities Cash, Card, and Check. Admins create genuine Other identities. Do not seed dummy Other codes.
- Other is configured identities, not free-typed cashier text.
- External Card: cashier processes outside ShelfSense, then records the tender. No processor, authorization status, or automatic reversal.
- Mixed tender accumulator; completion requires exact settlement (`SUM(payments) − SUM(refunds) = signed net`). 6.2 is payment-only; refunds wait for 6.5.
- Cash retains presented / applied / change. Replacement remaining due excludes the existing Cash row.
- Until Cash refunds exist, expected Cash stays the Phase 5 formula.
- Session/Z must show basic Card / Check / Other tender totals **before** those tenders are cashier-completable. Do not wait for 6.7.

**6.2E merge gate:** ordinary all-Cash behavior remains exactly equivalent to Phase 5.

### 6.3 — Completed transaction history (implemented)

Authority: [transaction-history.md](transaction-history.md).

Make completed commercial history retrievable before returns need it.

- Search: exact receipt reference (sufficient lookup), Register + `receipt_sequence`, exact `business_date`, recent. Not a reporting query builder.
- Authorized by `pos.transact` at the current Store, not original-cashier ownership. No open Session required.
- Detail: immutable completed facts (lines, tenders, totals, snapshots), including `cashier_name_snapshot`.
- Reprint: same completed snapshots as the original receipt, visibly marked **REPRINT**. No new receipt number, no commercial mutation, no live Product/price/tax.
- Immediate completion and historical lookup are separate screens that share print rendering.
- 6.5B attaches Return items on detail ([returns.md](returns.md)); 6.6 attaches post-void. 6.3 does not render those actions.

### 6.4 — Controlled actions and pricing (implemented)

Authority: [controlled-actions.md](controlled-actions.md).

Permission-tier policy (`phase6_permission_tier_v1`): `direct` / `approval_required` / `prohibited`. No policy configuration table. No persisted pending approvals. The cashier remains Session owner. Approval binds to the exact request (including `reason_code`), not manager mode.

- **6.4A/B:** foundation + price override. Reference preserved; selling changes. Scanner-safe second-actor overlay.
- **6.4C:** percentage line discount; tax on net merchandise; `signed net = 0` completes with no tender.
- **6.4D:** Tax Class override is selection among valid classes (default = ProductVariant Tax Class at add). Never cashier-entered rates. Purchaser exemption stays out.

Perform/approve permission keys arrive in this slice. Z finalize stays on `pos.transact` until a later controlled-action decision. 6.5 seeds only `unlinked_return` ([returns.md](returns.md)). `return_price_adjustment` / `post_void` remain reserved until a later policy model / 6.6.

### 6.5 — Returns and exchanges

**6.5A/B implemented. 6.5C next.** Authority: [returns.md](returns.md).

No Exchange entity. Returns are new facts; refunds are settlement. Directional Core keeps sale-side `subtotal_cents` / `discount_cents` / `tax_cents` and adds `return_*` plus persisted `signed_net_cents`. `total_cents = abs(signed_net_cents)`.

MVP linked-return eligibility is limited to authoritative original-line linkage, remaining returnable quantity, unit identity/state, and (from 6.6) post-void conflicts. Configurable return windows, merchandise exclusions, and broader policy exceptions stay deferred. Unlinked return is a controlled action using current rules, not a no-receipt return-policy engine.

- **Linked:** from completed detail; `original_transaction_line_id`; remaining returnable = original completed quantity minus completed linked returns. Reverse historical selling price, discount, and tax components. Do not rerun current pricing/tax or sale-line `recalc_extended!`. Partial quantities consume historical cents deterministically; the final eligible return takes residual cents. Individually tracked linked return restores the exact original `InventoryUnit`.
- **Unlinked:** creates the return line (`ExecuteUnlinkedReturn`); current merchandise valued under current POS rules. Cashier may enter a return unit price (`>= 0`, above or below reference). That difference is commercial history inside the single `unlinked_return` action, not a sale discount/override and not a second permission. No historical price/tax/tender claim. Unlinked Used requires an existing known **removed** `InventoryUnit`; unknown identifiers are intake/buyback, not this slice.
- **Mixed sale + return:** transaction `signed_net` determines payment, refund, or no tender. Do not overload Phase 4/5 unsigned `subtotal` / `tax` / `total`.
- **Refunds:** tender settlement, not return valuation. External Card refund is cashier-confirmed outside ShelfSense. Expected Cash becomes `float + Cash payments − Cash refunds` and **may be negative** (not a physical drawer cap).
- **Session/Z:** this slice must make commercial and Cash calculations direction-aware in the same change that first completes a return. `SUM(transaction.total_cents)` must not treat refund magnitude as sales. 6.7 may reorganize snapshot columns; it does not fix a knowingly wrong Z.

Working/cancelled returns do not consume eligibility. Concurrency must prevent two Registers from both returning the final eligible quantity. Delivery: 6.5A Core and 6.5B operator workflow are implemented; 6.5C unlinked is next; 6.5D remains as specified in [returns.md](returns.md) §32.

### 6.6 — Post-void

Correct a transaction that should never have been completed. Distinct from customer return.

- Entry from completed detail: reason, controlled-action authorization, confirmation.
- Original remains untouched. One linked compensating operation reverses the whole transaction (lines, tenders, inventory, tax/reporting as new-period facts).
- Yesterday’s Z remains immutable; today receives the correction.
- Whole transaction only. Cannot post-void twice. Cannot post-void if a completed linked return or prior post-void exists. Cannot edit the generated reversal.
- External Card reversal must be performed and confirmed outside ShelfSense before the corresponding fact is recorded.

Partial correction uses return workflows.

### 6.7 — MVP closeout

No new business domain. Verify and polish facts **already represented truthfully** by earlier slices:

- Receipt/reprint: Used-unit identity, sale vs return, override, discount, return price adjustment, Tax Class/tax, multiple tenders, refunds, Cash presented/change. Customer copies omit unnecessary external Card/Check references.
- Session/Z presentation: gross sales, returns, discounts, net, tax; tender breakdown; Cash custody = float + Cash payments − Cash refunds. Additive snapshot columns if 6.2/6.5 left previews correct but snapshot shape incomplete. Already-finalized periods stay immutable.
- History/audit: enough to explain who changed price/discount/Tax Class, why, who approved, return linkage, return price adjustment, post-void relationship, tender settlement. Audit is implemented with each capability; 6.7 verifies completeness and presentation.
- Full keyboard register workflow pass across 6.1–6.6 plus close/Z.

Do not add paid-ins, drops, safe, drawer custody, denomination counts, or Store Close.

---

## 6. Phase 6 acceptance

A cashier can complete one ordinary path:

```text
open Register
  → confirm business date / opening float
  → scan Standard, Used unit, and non-inventory
  → price override / line discount / Tax Class override where policy allows
  → mixed tender to exact settlement
  → complete
  → print / reprint from snapshots
  → lookup yesterday’s transaction after catalog change
  → linked return and/or unlinked return / mixed sale+return
  → post-void a whole transaction that has no prior return
  → blind close
  → persisted expected / count / variance (Cash payments minus Cash refunds)
  → finalize immutable Z
```

The Phase 5 all-Cash Standard path remains green after every slice.

---

## 7. Out of this MVP

```text
Suspend / recall
Open ring
Transaction-wide discounts
Promotions / coupons
Stored Value / gift cards / store credit
Integrated Card processing
Customer tax exemptions
Paid-in / paid-out
Cash drops / safe transfers
Drawer model / shared Cash custody
Denomination counting
Variance approval / escalation
Advanced reporting
Formal Store Close
Z numbering
Electronic receipts
Customer display
Customer / reservation integration
Configurable return windows / merchandise exclusions
Unknown Used-item intake / buyback through returns
Cross-register work handoff
Offline / standalone Terminal
Deposits / bank reconciliation
Fractional quantities
```

---

## 8. Build order

```text
1. Lock 6.0 contract + 6.1 spec (this packet)
2. 6.1 merchandise breadth (Lookup, inventory_unit_id, PostSale unit + skip non-inventory, workspace scan)
3. Lock 6.2 tender contract → implement settlement redesign (Cash equivalence gate; Session/Z tender totals)
4. Lock 6.3 history contract → lookup / detail / reprint
5. Lock 6.4 controlled-action contract → framework, then override / discount / Tax Class
6. 6.5A linked Core and 6.5B operator workflow implemented ([returns.md](returns.md)) → 6.5C unlinked return, then 6.5D mixed/unlinked closeout hardening
7. Lock 6.6 post-void contract → compensating whole-transaction fact
8. Lock 6.7 closeout contract → receipt/Z/audit/keyboard regression (polish, not first truthful reporting)
```

Schema columns appear in the owning slice. 6.0 does not migrate unused fields.
