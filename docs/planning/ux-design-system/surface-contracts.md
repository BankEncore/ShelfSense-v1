# Surface contracts — basket, history, and print

Status: **Proposed**

Defines presentation contracts for three related but distinct surfaces. Do not apply one layout to all three.

Inspirational receipt layout: [`receipt-overview-mockup.html`](receipt-overview-mockup.html) (planning packet; not binding).

## 1. Register basket (working transaction)

**Allowed:** a clean two-line (or stacked) merchandise presentation:

- Line 1 — title (primary text, emphasis).
- Line 2 — operational metadata (author, format, condition, etc.) in secondary text.
- Identifier (ISBN / SKU / unit id) may appear in monospace beneath or beside metadata.
- Prices: right-aligned, tabular numerals; omit decorative `+` prefixes on ordinary sale amounts.

**Must preserve:** existing Register shortcuts, scan buffer, focus restoration, Turbo region contracts, and controlled-action flows ([register-workspace.md](../phase4-6-point-of-sale/phase5-cash-register/register-workspace.md), [pos-workflow.md](../phase4-6-point-of-sale/phase6-pos-mvp/pos-workflow.md)).

Any metadata shown must come from **transaction-line snapshots** or other historical fields available on the working line—not by re-reading mutable live product records as if they were the sold description.

## 2. Transaction history / completed receipt (screen)

**Target structure** (when facts support it):

1. Header — identity, register, cashier, timestamps; action group (Reprint, Return Items, Post-Void as danger **outline** trigger—not solid brand).
2. Summary card — sales breakdown, returns breakdown, net and tenders when those distinctions exist in stored totals/tenders.
3. Line grid — type badge, item, qty, unit/adj, tax, net; **progressive disclosure** for extra detail.

### Line details (not “audit logs”)

Expanded row content is **Line details**, optionally sectioned as:

| Section | Examples |
|---|---|
| Pricing | Unit price, discounts, overrides |
| Tax | Tax class/components as stored on the line |
| Authorization | Manager approvals for controlled actions |
| Origin | Linked original receipt / return provenance |

Do **not** label this drawer “audit logs.” Application `audit_events` are a separate authorization and query concern and are not required on every history line for UDS-2.

### Disclosure interaction

Use an **explicit disclosure control** (button, expand affordance, or row action). Do **not** appropriate bare `Enter` on a selected history row without a defined grid-navigation contract that avoids conflicts with existing command keys ([deferred-patterns.md](deferred-patterns.md)).

### Historical truth

Transaction history must display **snapshots and stored facts**. It must not reconstruct sold titles, prices, or tax from current mutable merchandise configuration.

## 3. Printed customer receipt

**Unchanged** unless a separate print-presentation change is accepted:

- Retain the locked **one-line** item description and constrained print format ([receipt-presentation.md](../phase4-6-point-of-sale/phase6-pos-mvp/receipt-presentation.md)).
- Register basket two-line layout must **not** reverse the print contract.
- Warm Parchment is a **screen** system; print CSS remains its own target.

Phase 10 stored-value issuance, redemption, remaining balance, refund destinations, and cash-out are additional print/history facts specified in [phase10-gift-card-numbering.md](../phase10-stored-value/phase10-gift-card-numbering.md) and [phase10-reporting-closeout.md](../phase10-stored-value/phase10-reporting-closeout.md). Masked identity only on ordinary reprints. Issuance is a distinct basket section, not a merchandise two-line.

## Summary

| Surface | Density / layout | Description lines | Extra detail |
|---|---|---|---|
| Register basket | Standard / touch-friendly | Two-line OK | Minimal; working state |
| History / screen receipt | Compact-friendly | Title + metadata; summary card | Line details disclosure |
| Printed receipt | Fixed print | One-line locked | Per print contract only |
