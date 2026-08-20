# Phase 6 — Operational POS MVP

**Status:** Slice 6.0 contract locked ([mvp-contract.md](mvp-contract.md)). Slice 6.1 merchandise breadth implemented ([merchandise-breadth.md](merchandise-breadth.md)). Slice 6.2 tender breadth implemented ([tender-breadth.md](tender-breadth.md)). Slice 6.3 transaction history implemented ([transaction-history.md](transaction-history.md)). Slice 6.4 controlled actions implemented ([controlled-actions.md](controlled-actions.md)). Slice 6.5 returns implemented (6.5A–D; [returns.md](returns.md)). Slice 6.6 post-void implemented ([post-void.md](post-void.md)). Slice 6.7 workflow contract locked ([pos-workflow.md](pos-workflow.md)). Slice 6.8 closeout contract locked ([mvp-closeout.md](mvp-closeout.md) / [receipt-presentation.md](receipt-presentation.md)).

**Authority**

| Document | Role |
|---|---|
| [MVP contract](mvp-contract.md) | Slice 6.0: CompletedPosOperation v2 and cross-cutting locks |
| [Merchandise breadth](merchandise-breadth.md) | Slice 6.1: Used/individual and non-inventory sales |
| [Tender breadth](tender-breadth.md) | Slice 6.2: Cash/Card/Check/Other settlement |
| [Transaction history](transaction-history.md) | Slice 6.3: completed lookup, detail, reprint |
| [Controlled actions](controlled-actions.md) | Slice 6.4: price override, line discount, Tax Class override |
| [Returns](returns.md) | Slice 6.5: linked/unlinked returns, refunds, mixed sale+return (6.5A–D implemented) |
| [Post-void](post-void.md) | Slice 6.6: whole-transaction compensating fact (implemented) |
| [POS workflow](pos-workflow.md) | Slice 6.7: cashier Home, keys, pickers, open-price Standard, return entry, X Report (locked) |
| [MVP closeout](mvp-closeout.md) | Slice 6.8: presentation, regression; no new commercial behavior (locked) |
| [Receipt presentation](receipt-presentation.md) | Customer print/reprint layout (locked; implement in 6.8) |
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

Slice 6.0 locks the completed-operation shape so later slices do not each invent a new completion contract. Slices 6.1–6.8 are independently mergeable to `main` and must leave the register usable.

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

6.8 consolidates presentation. It does not repair knowingly inaccurate intermediate receipt, history, or Session/Z figures. 6.7 is operator workflow, not polish.

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
  ├── 6.7  POS operator workflow
  └── 6.8  POS presentation & MVP closeout
```

Letter a slice (6.1A/B, 6.2A–E, 6.4A–D, 6.5A–D, 6.7A–E) only when a single PR would not stay reviewable. A stacked branch is allowed while a predecessor is still in review; the integration target remains `main`.

6.2–6.8 contracts are written. Build 6.7 next ([pos-workflow.md](pos-workflow.md)), then 6.8.

---

## 4. Slice map

| Slice | Scope | Primary deliverable | Merge gate (register remains usable) |
|---|---|---|---|
| **6.0** | MVP contract | Lock Phase 6 invariants and completed-operation shape | Docs only; no behavior change |
| **6.1** | Merchandise breadth | Used/individual + non-inventory sales | **Implemented.** Quantity-tracked Cash Standard path unchanged |
| **6.2** | Tender breadth | Card, Check, admin-created Other, mixed tender | **Implemented.** All-Cash sale remains Phase 5-equivalent; Session/Z shows Card/Check/Other |
| **6.3** | Transaction history | Lookup, detail, receipt reprint | **Implemented.** Sale workspace does not depend on history |
| **6.4** | Controlled pricing/actions | Approval framework, price override, line discount, Tax Class override | **Implemented.** Ordinary path stays `direct` unless policy requires a second actor |
| **6.5** | Returns | Linked, unlinked, price adjustment, mixed sale/return | **Implemented** ([returns.md](returns.md)). Sale-only baskets still complete the same way; Session/Z is direction-aware |
| **6.6** | Post-void | Controlled whole-transaction correction | Implemented ([post-void.md](post-void.md)). Entry is from history; sale path untouched |
| **6.7** | POS operator workflow | Home, keys, pickers, open-price Standard, return entry, X Report | Contract locked ([pos-workflow.md](pos-workflow.md)). Phase 5 all-Cash Standard path stays green |
| **6.8** | Presentation & closeout | Customer print, Session/Z/history chrome, regression | Contract locked ([mvp-closeout.md](mvp-closeout.md)). Additive snapshots only; already-finalized periods stay immutable |

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
- Session/Z must show basic Card / Check / Other tender totals **before** those tenders are cashier-completable. Do not wait for 6.8.

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

**6.5A–D implemented. Phase 6.5 complete.** Authority: [returns.md](returns.md).

No Exchange entity. Returns are new facts; refunds are settlement. Directional Core keeps sale-side `subtotal_cents` / `discount_cents` / `tax_cents` and adds `return_*` plus persisted `signed_net_cents`. `total_cents = abs(signed_net_cents)`.

MVP linked-return eligibility is limited to authoritative original-line linkage, remaining returnable quantity, unit identity/state, and (from 6.6) post-void conflicts. Configurable return windows, merchandise exclusions, and broader policy exceptions stay deferred. Unlinked return is a controlled action using current rules, not a no-receipt return-policy engine.

- **Linked:** from completed detail; `original_transaction_line_id`; remaining returnable = original completed quantity minus completed linked returns. Reverse historical selling price, discount, and tax components. Do not rerun current pricing/tax or sale-line `recalc_extended!`. Partial quantities consume historical cents deterministically; the final eligible return takes residual cents. Individually tracked linked return restores the exact original `InventoryUnit`.
- **Unlinked:** creates the return line (`ExecuteUnlinkedReturn`); current merchandise valued under current POS rules. Cashier may enter a return unit price (`>= 0`, above or below reference). That difference is commercial history inside the single `unlinked_return` action, not a sale discount/override and not a second permission. No historical price/tax/tender claim. Unlinked Used requires an existing known **removed** `InventoryUnit`; unknown identifiers are intake/buyback, not this slice.
- **Mixed sale + return:** transaction `signed_net` determines payment, refund, or no tender. Do not overload Phase 4/5 unsigned `subtotal` / `tax` / `total`.
- **Refunds:** tender settlement, not return valuation. External Card refund is cashier-confirmed outside ShelfSense. Expected Cash becomes `float + Cash payments − Cash refunds` and **may be negative** (not a physical drawer cap).
- **Session/Z:** this slice must make commercial and Cash calculations direction-aware in the same change that first completes a return. `SUM(transaction.total_cents)` must not treat refund magnitude as sales. 6.8 may reorganize snapshot **presentation**; it does not fix a knowingly wrong Z.

Working/cancelled returns do not consume eligibility. Concurrency must prevent two Registers from both returning the final eligible quantity. Delivery: 6.5A Core, 6.5B operator workflow, 6.5C unlinked return, and 6.5D mixed/closeout hardening are implemented as specified in [returns.md](returns.md) §32.

### 6.6 — Post-void

**Implemented (6.6A–B).** Authority: [post-void.md](post-void.md).

Correct a transaction that should never have been completed. Distinct from customer return. Correction lineage is `post_void_of_transaction_id` / `post_void_source_line_id` / `post_void_source_tender_id` — not `original_transaction_line_id`.

- Entry from completed detail: reason, controlled-action authorization, per-Card confirmation.
- Original remains untouched. One compensating completed transaction reverses the whole source (exact historical freeze, `Inventory::PostPostVoid`, tax/reporting as new-period facts).
- Yesterday’s Z remains immutable; today receives the correction. Session/Z Sales and Returns exclude post-void transactions; additive `finalized_post_void_*` snapshots ship in this slice.
- Whole transaction only. Cannot post-void twice. Cannot post-void if an effective completed linked return or prior post-void exists. Cannot edit the generated reversal.
- External Card reversal must be performed and confirmed outside ShelfSense before the corresponding fact is recorded.

Partial correction uses return workflows.

### 6.7 — POS operator workflow

**Contract locked.** Authority: [pos-workflow.md](pos-workflow.md).

Make all MVP capabilities practical to operate from one coherent cashier workflow. This is **not** closeout polish.

```text
POS Home / sparse Register chrome
preferred Register cookie
X Report (interim; does not close)
breaking keyboard remap (F5 left for the browser)
variant / unit pickers and / search
open-price quantity-tracked and non-inventory Standard
- linked/unlinked return chooser
F1–F4 tenders; + = Cash remaining
```

Open-price Used/individual is deferred (explicit POS refusal). Post-void stays history-only. Customer print is 6.8.

Delivery letters: 6.7A docs (this lock), 6.7B Home/X, 6.7C keys, 6.7D pickers/open-price, 6.7E returns+tenders.

### 6.8 — POS presentation and MVP closeout

**Contract locked.** Authority: [mvp-closeout.md](mvp-closeout.md) and [receipt-presentation.md](receipt-presentation.md).

No new commercial behavior. Verify and present facts **already represented truthfully** by earlier slices, after 6.7 is usable:

- Receipt/reprint: customer copy per [receipt-presentation.md](receipt-presentation.md). Operator history stays [transaction-history.md](transaction-history.md). Do not unify those grammars.
- Session/X/Z **on-screen** grouping (Sales / Returns / Post-void / Net / tenders / Cash custody). No thermal Z print. Additive snapshot columns only if a correct preview cannot be reproduced. Already-finalized periods stay immutable.
- History/audit: enough to explain who/why/approver, return linkage, unlinked prices, post-void, tender settlement. Customer print omitting a field does not remove it from history.
- Regression: ordinary path through 6.7 modes plus blind close and immutable Z.

Do not add paid-ins, drops, safe, drawer custody, denomination counts, or Store Close.

---

## 6. Phase 6 acceptance

A cashier can complete one ordinary path:

```text
open Register (from POS Home)
  → confirm business date / opening float
  → scan Standard, Used unit, non-inventory, open-price Standard
  → price / line discount / Tax Class where policy allows
  → mixed tender to exact settlement
  → complete
  → print / reprint from snapshots
  → lookup yesterday’s transaction after catalog change
  → linked return and/or unlinked return / mixed sale+return
  → post-void a whole transaction that has no prior return (from history)
  → X Report (session remains open)
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
Open-price Used / individual merchandise
Z printing on thermal paper
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
6. 6.5A–D implemented ([returns.md](returns.md)); Phase 6.5 complete
7. Lock 6.6 post-void contract ([post-void.md](post-void.md)) → compensating whole-transaction fact
8. Lock 6.7 workflow ([pos-workflow.md](pos-workflow.md)) → Home, keys, pickers, open-price Standard, return entry, X Report
9. Lock 6.8 closeout ([mvp-closeout.md](mvp-closeout.md)) → customer print, Session/Z/history presentation, regression
```

Schema columns appear in the owning slice. 6.0 does not migrate unused fields.
