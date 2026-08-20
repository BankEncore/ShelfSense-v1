# Phase 6 Slice 6.8 — POS presentation and MVP closeout

**Status:** Locked. Implementation authority for customer print, header/footer inheritance, Store legal-name enforcement, Used `condition_name` snapshots, Session/Z and history/audit **presentation**, and the final MVP regression. No new commercial behavior.

**Authority:** Presentation of facts 6.1–6.7 already made true. Customer print layout is [receipt-presentation.md](receipt-presentation.md). Operator lookup/reprint *mechanics* remain [transaction-history.md](transaction-history.md). Workflow/keys remain [pos-workflow.md](pos-workflow.md). Session/Z *math* remains 6.2 / 6.4 / 6.5 / 6.6.

Companions: [phase6-plan.md](phase6-plan.md), [close-z-screens.md](../phase5-cash-register/close-z-screens.md), [post-void.md](post-void.md), [mvp-contract.md](mvp-contract.md).

Draft [receipts.md](../../../drafts/specifications/pos/receipts.md) is vocabulary. This document plus [receipt-presentation.md](receipt-presentation.md) are implementation authority for the closeout subset. No new ADR.

### Actually locked

```text
no new commercial domain
customer print ≠ operator screen
omit business_date on customer paper
condition_name on new Used snapshots; old rows fall back to condition_code
legal_name required; admin + Register enter + print fail closed
Session/Z = labels/layout unless an additive snapshot is missing
history/audit fields stay operator-visible
no reprint audit
80-mm browser print for X / closed Session / Z (explicit Print; never on GET)
already-finalized periods stay immutable
```

---

## 1. Objective

Finish the operational POS MVP as a presentable, printable, explainable system after 6.7 made the cashier workflow coherent.

```text
customer receipt (80-mm browser print)
operator completion / history screens
Session / X / Z on-screen presentation
regression through 6.7 modes + blind close + immutable Z
```

6.8 does not invent truthful reporting that 6.2/6.5/6.6 already own. It does not add open-price, pickers, or keymap (6.7).

---

## 2. Customer print

Authority: [receipt-presentation.md](receipt-presentation.md).

Implement that contract in this slice, including header/footer `inherit` / `custom` / `none`, barcode of compact `transaction_reference`, post-void banners with **Post-voided by** on the printed original, and totals that equal persisted `signed_net_cents`.

### 2.1 Operator screen vs `_print`

Do **not** unify into one display partial.

```text
completion screen / history
→ operator grammar
→ directional totals
→ operational provenance
→ controls, return linkage, approvals

_print
→ customer receipt grammar
→ no internal price-adjustment provenance
→ customer discount presentation
→ 80-mm formatting
```

They consume the same immutable facts. Different audiences.

On-screen completion may still embed the hidden print partial for `window.print()`; the **visible** completion/history chrome stays operator grammar.

### 2.2 Business date (U1)

**Omit** `business_date` from the customer copy. Paper shows `completed_at` in the Store timezone plus receipt identity.

Business date remains on operator history, Session/X/Z, and reporting.

### 2.3 Used condition (U2)

New completions add `condition_name` to `merchandise_snapshot` at freeze (JSON only; no table column).

Customer print:

```text
condition_name present     → print "Used {condition_name}"   # e.g. Used Very Good
older row, code only       → print "Used {condition_code}"
```

Never live-lookup `merchandise_conditions` on reprint. Do not print a redundant `New` on Standard merchandise.

### 2.4 Store legal name (U3)

Never fall back to `stores.name` or System Settings names.

All three layers, after preflight of existing rows (identify blanks; **do not** copy `name` into `legal_name`):

```text
Store administration
→ legal_name required on create/update while the Store is active, and on activation
  (reprints use current Store presentation)
  Deactivate of a legacy blank legal_name is allowed; do not invent a name.

Register enter / open
→ refuse if legal_name blank:
  "This Store cannot use POS until its legal name is configured."

Receipt renderer
→ fail closed if somehow blank
```

Inactive Stores may remain blank only as a legacy exception. Historical reprints still fail closed rather than substituting `stores.name`.

---

## 3. Session / X / Z presentation

6.8 owns **on-screen** labels, grouping, layout, navigation, and visual hierarchy, plus **80-mm browser print** for X, closed Session, and Z (operator report grammar, not customer receipt grammar).

Print uses the same lifecycle as customer receipts: explicit Print, never on GET, `window.print` + CSS, failure does not close a Session, unfinalize Z, or rewrite snapshots. Do not print expected Cash on a blind count screen. No ESC/POS, printer discovery, or print-attempt audit.

Customer 80-mm belongs to [receipt-presentation.md](receipt-presentation.md) (6.8B). Report print is 6.8C.

Conceptual grouping (existing formulas):

```text
Sales
Returns
Post-void
Net
Tax

Tender payments / refunds

Opening float
Cash payments
Cash refunds
Expected Cash
Counted Cash
Variance
```

Sales/Returns exclude post-void transactions; Net includes them; post-void snapshots are additive ([post-void.md](post-void.md) §13). Expected Cash remains `float + Cash payments − Cash refunds`.

If writing this closeout reveals a missing persisted snapshot required to reproduce an already-correct **preview**, an additive `finalized_*` column is acceptable. Otherwise no new reporting math. Already-finalized periods stay immutable. NULL on old Z still means “not captured.”

X Report presentation follows the same commercial/tender grouping as the live Session totals ([pos-workflow.md](pos-workflow.md) §11) and must remain clearly interim.

---

## 4. History / audit presentation

Keep operational detail on screen. Customer receipt simplification does **not** simplify the operator record.

6.8 verifies an authorized operator can explain:

```text
who performed an action
why
who approved
price / discount / Tax Class provenance
linked-return original
unlinked-return entered vs reference price
post-void original / correction relationship
tender settlement (including external references on screen)
```

Do not strip those fields because `_print` omits them.

History reads remain unaudited (6.3). Reprint still has **no** reprint audit.

---

## 5. Regression

One ordinary path through 6.7 modes plus blind close and immutable Z:

```text
POS Home → Open Register
  → scan Standard, Used unit, non-inventory, open-price Standard
  → / search + pickers
  → Price / discount / Tax Class
  → linked and unlinked return
  → mixed tender
  → print / reprint
  → lookup after catalog change
  → post-void from history
  → X Report (session remains open)
  → blind close
  → persisted expected / count / variance
  → finalize immutable Z
```

Phase 5 all-Cash Standard path remains green.

---

## 6. Delivery

Implement after 6.7 is usable. Letter only if a single PR would not stay reviewable (for example print/header-footer vs Session/Z chrome vs regression).

Schema that belongs here: `receipt_header_mode` / `receipt_footer_mode`, 500-character message limits, `condition_name` in freeze snapshots, Store `legal_name` presence. Do not migrate unused 6.7 workflow columns.

---

## 7. Acceptance

1. Customer print matches [receipt-presentation.md](receipt-presentation.md) acceptance, including U1–U3 as locked here.
2. Visible completion and history screens still use operator directional totals and provenance.
3. Session/X/Z on-screen grouping matches §3; 80-mm browser print for X / closed Session / Z uses the same grouping and explicit Print.
4. History still shows performer, reason, approver, return linkage, unlinked prices, post-void relationship, and tender references.
5. Additive snapshots only if a preview cannot be reproduced; old finalized Z rows remain valid.
6. The §5 path is cashier-completable; Phase 5 all-Cash Standard remains green.

---

## 8. Out of 6.8

```text
open-price Used
new keymap (6.7)
post-void from the selling surface
paid-ins / drops / drawer / Store Close
Z numbering
electronic receipts
ESC/POS
reprint audit
historical versioning of Store address/header/footer
```
