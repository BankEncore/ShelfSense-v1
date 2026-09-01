# Admin Page Frame Program — Adoption outlook

**Not authorized. Not a delivery plan. A later packet must approve any family slice.**

**Program name:** Admin Page Frame Program (not UDS-6, UDS-7, or UDS-8)

**Status:** Non-authoritative outlook. **No implementation authority.**

This file preserves possible follow-on work after the Slice 1 closeout gate. It must not be read as Slices 2–6 of this program. Numbered slices in an authorized plan are treated as approved scope in this repository; these rows are not.

Authority for what may ship now: [plan.md](plan.md), [change-allowlist.md](change-allowlist.md). Inventory of surfaces: [slice-0.md](slice-0.md).

After Slice 1 closeout, choose **feature-led adoption** (UDS-5.5, remaining the default for domain chrome) or write a **new bounded family packet**. Do not start the work below from leftover energy in this program.

## Possible later family packets

These describe grammar work that would need its own allowlist, evidence, and frozen tests.

### Index family

Migrate bare, partial, and composed representatives; lock filters, result state, tables, empty states, and pagination; then migrate remaining indexes in coherent domain groups. Remove leftover index selectors only after no call sites remain.

Candidate representatives (not authorized): Users (bare), Customers (partial), Products (composed). Product is a compatibility consumer of the general frame, not a template to copy.

### Record family

Migrate simple, definition-heavy, and composed representatives; lock identity, status, metrics, panels, related content, activity, and technical details; then migrate remaining records in coherent flows.

Candidate representatives (not authorized): Adjustment Reason (already Slice 1), Store (long definition list), Product (composed).

### Form family

Migrate short, long, and advanced representatives; lock width selection, section grids, help/errors, and sticky-action behavior; then migrate remaining create/edit flows. Sticky footers remain opt-in.

### Hubs

Home landing purpose is an unresolved product decision. Purchasing hub is a useful later `workspace` validation surface and is too domain-rich to prove the foundation API. Do not duplicate global navigation as a grid of generic links.

### Workflows and management workspaces

Consequence review (inventory adjustment confirm, customer merge) and dense management surfaces (cash store day, purchase order show) test `wide` / `workspace` on real tasks. Keep native review-dialog contracts and server commands intact.

### History

Audit events and inventory balance history belong with UDS-6’s history contract. Do not invent a parallel grammar here.

### Reporting

Stored-value report and later financial/reporting composition are a separate program.

## Stylesheet extraction (separate maintenance)

`application.css` currently contains foundation, Admin, Ops, Register, thermal-document, print, dialog, and feature-specific rules. Extraction is **not** part of Slice 0 or Slice 1.

Target conceptual ownership, if a later maintenance packet is written:

```text
application.css      manifest/common entry
foundation.css       tokens, reset, typography, focus
components.css       buttons, forms, tables, badges, dialogs
admin.css            administrative shell and page composition
ops.css              purchasing operations workspace
pos.css              Register screen UI
print.css            receipts and operational reports
```

An extraction slice must be mechanical first: move selectors without changing computed presentation, preserve load order, and validate Admin, Ops, Register, and print before further refinement.

## Provisional interest order (informational only)

Former draft “P0–P2” labels. **Not a backlog.**

| Interest | Family | Why it would be informative later |
|---|---|---|
| After frame gate | Index representatives | Bare / partial / composed generations |
| After frame gate | Record / form representatives | Simple vs long vs composed |
| Later | Hub | Home purpose vs Purchasing work hub |
| Later | Workflow | Consequence review and comparison |
| Later | Workspace | Cash store day or purchase order show |
| Coordinate | History | UDS-6 |
| Coordinate | Reporting | Future financial/reporting packet |

Products remain a reference, not a template to copy mechanically. The general frame must explain Product composition while also scaling down to simple configuration pages — when a later packet says so.
