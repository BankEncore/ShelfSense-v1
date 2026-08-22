# UDS-3 — Register visual refinement

Status: **Implemented** (matrix **partial** until a11y-matrix evidence)

Slice id remains **UDS-3**. Not a Phase 7 domain number. Authority: [UX design system packet](README.md). Prior: [UDS-1](uds-1-plan.md), [UDS-2](uds-2-plan.md).

Companion backlog: [uds-3-user-stories.md](uds-3-user-stories.md).

## Purpose

Refine the cashier Register workspace visually—two-level basket hierarchy, clearer selection/totals, shortcut visual groups, and overlay separation—without changing shortcuts, scanning, focus restoration, Turbo contracts, or printed receipt one-line descriptions.

## Deliverable

> Cashiers see a Warm Parchment Register basket with title/metadata hierarchy, clear selected-line and totals treatment, visually grouped shortcuts, and stronger overlay separation; keyboard bindings and print remain unchanged.

## Prerequisites

1. UDS-1 and UDS-2 complete for shared tokens/helper.
2. Follow [rollout contract](program-plan.md#implementation-rollout-contract) UDS-3 frozen suites.
3. Change only the [UDS-3 allowlist](program-plan.md#slice-change-allowlist).

## Locked decisions

1. Bindings, Turbo targets, form methods, and print selectors stay frozen ([register-workspace.md](../phase4-6-point-of-sale/phase5-cash-register/register-workspace.md)).
2. Basket metadata comes from line snapshots / working-line fields only ([surface-contracts.md](surface-contracts.md)).
3. Shortcut regrouping is **visual only**.
4. `ActionButtonHelper` for Register actions; size `:large` for command cluster.
5. Full [accessibility-ergonomic-test-matrix.md](accessibility-ergonomic-test-matrix.md) (including timed cashier) required before matrix **conforming**.

## Delivery sub-slices

```mermaid
flowchart LR
  a[UDS3a_BasketHierarchy]
  b[UDS3b_ShortcutsOverlays]
  c[UDS3c_DocsMatrix]
  a --> b --> c
```

### UDS-3a — Basket hierarchy and selection — done

- Two-level line presentation via `pos_basket_line_title` / `pos_basket_line_metadata`; `data-description` and print keep one-line helpers.
- Selected-line and controlled-line styling via Warm Parchment table/warning tokens.
- Totals/feedback/banner token cleanup.

### UDS-3b — Shortcut groups and overlays — done

- Visual groups: returns/pickup, line controls, tender, remove, cancel.
- Register commands and overlay actions on `ActionButtonHelper`; Stimulus `data-action` / targets preserved.
- Overlay panels use dialog surface + elevated boundary; picker selected state matches table tokens.

### UDS-3c — Docs exit — done (evidence pending)

- Plan/stories/indexes/matrix updated to **partial**.
- Conforming only with a11y-matrix evidence.

## Out of scope

- Printed receipt changes; binding changes; global search; drawers; admin Hotwire.

## Acceptance

1. Two-level basket visible; print still one-line. ✓
2. Shortcuts visually grouped; bindings unchanged. ✓
3. Frozen Register system suites green (run on slice).
4. Matrix updated; conforming only with evidence. ✓ partial
