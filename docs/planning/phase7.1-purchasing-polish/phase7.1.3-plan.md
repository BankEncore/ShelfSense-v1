# Phase 7.1.3 — Purchasing ops interaction closeout

Status: **Complete** on branch `phase-7.1.3-purchasing-ops-closeout` (pending merge to `main`).

Authority: [phase7.1-plan.md](phase7.1-plan.md), [phase7-spec.md](../phase7-orders-and-receiving/phase7-spec.md) §17.3–17.4, [program-plan.md](../ux-design-system/program-plan.md) Phase 7.1.3 allowlist.

## Goal

Close shared **ops interaction contracts**—dirty abandonment, focus restoration, recoverable error handling, shortcut semantics, and action presentation—for Location and Draft PO. Receiving proves those contracts work; it is **not** the UX model for Location or Draft PO.

## Deliverable

> A floor associate or buyer can complete Location and Draft PO workflows predictably with keyboard, scanner, or pointer input; recover safely from errors; leave without silently losing changes; and understand the next action through consistent ops presentation.

## Branch policy

**Supersedes** [phase7.1-plan.md](phase7.1-plan.md) locked decision #4 for this slice: branch `phase-7.1.3-purchasing-ops-closeout` targets `main` directly. The `phase-7.1-purchasing-polish` integration branch is retired after 7.1.1–7.1.2 merged.

## Prerequisites (on `main`)

- Phase 7.1.1 hub and 7.1.2 admin purchasing indexes
- UDS-4.1 grouped navigation; UDS-4.2 non-purchasing adoption
- Shared ops layout with `ops-shortcuts`, `dirty-form`, `escape-cancel`

## Hard boundaries

**In scope:** Location + Draft PO interaction hardening; workspace-aware shared controller fixes; additive tests; [phase7.1.3-ops-evidence.md](phase7.1.3-ops-evidence.md).

**Out of scope:** New domain commands; Phase 7 contract changes; Receiving template changes; Turbo for Location; 7.1.4 customer-request purchasing links; shared Stimulus extraction unless already identical.

**Receiving protection:** No Receiving template or behavior changes. Shared-controller fixes must preserve Receiving’s contract and pass existing Receiving system tests unchanged.

## Escape precedence

Highest active state wins; owner must `stopPropagation` when handling.

| Priority | Active state | Owner | Result |
|---:|---|---|---|
| 1 | Consequential review dialog open | `review-dialog` | Close; restore trigger focus |
| 2 | Shortcut help open | `ops-shortcuts` | Close; restore help button |
| 3 | Location panel open, unchanged | `location-queue` | Close panel; focus originating row |
| 4 | Location panel open, dirty | `location-queue` | Confirm **“Discard this location entry?”**; close; focus row |
| 5 | Draft PO dirty inline or add-line form | `escape-cancel` + `dirty-form` | Reset active form; clear dirty; restore lookup |
| 6 | Draft PO clean selected row | `escape-cancel` + `row-selection` | Clear selection; restore lookup |
| 7 | Location queue, panel closed | — | No effect |
| 8 | No owned local state | — | No effect |

Turbo navigation: **“Discard unsaved purchasing changes?”** via `dirty-form`.

## Abandonment copy

| Context | Copy |
|---|---|
| Location panel abandon | Discard this location entry? |
| Draft PO / shared ops nav | Discard unsaved purchasing changes? |
| Business cancel request | Submit button label only; not used for Escape/Close |

## Contextual shortcut chrome

| Workspace | Bindings |
|---|---|
| Location | ↑/↓, Enter, Esc; visible Select / Located / Not located |
| Draft PO | `/`, ↑/↓, Enter, Esc, Ctrl/⌘+S, Ctrl/⌘+Enter |
| Receiving | Existing scan/save/review contract (unchanged) |

## Location contracts

**Dirty baseline:** panel dirty when any field differs from server-rendered initial value (checkbox, Used scan/select, notes, resolution, supplier, expected cost).

**Focus (post-redirect, no Turbo):**

| Outcome | Focus target |
|---|---|
| Open request | First required control |
| Switch to Not located | Notes |
| Select special order | First special-order field |
| Validation failure | First affected field |
| Close unchanged panel | Originating row |
| Abandon dirty panel | Originating row after confirm |
| Success, rows remain | First remaining row |
| Success, queue empty | Empty-state heading or first action |

**Commit buttons:** separate stable actions—Convert to special order (solid brand), Cancel request (solid danger). No morphing single submit.

## Draft PO contracts

- Add-line form participates in `data-dirty-track`
- Automatic lookup focus disabled when server designates a field-level error target
- Add-line success/failure → lookup focus; inline edit failure → affected row field

## Merge gate

1. Location and Draft PO primary workflows completable without pointer
2. Every Escape/Close path has explicit unchanged-vs-dirty contract
3. Documented focus targets after success, cancel, and recoverable failure
4. `focus-restore` does not override server-directed error focus
5. Scanner Enter cannot trigger consequential send
6. Submitted values survive recoverable validation/concurrency failures
7. Receiving + Phase 7 command tests unchanged and green
8. No domain command, lock order, authz, or inventory contract changes
9. [phase7.1.3-ops-evidence.md](phase7.1.3-ops-evidence.md) completed
10. Status documentation reflects merge

**Frozen suites:** `purchasing_ops_workspace_test.rb`, `location_queue_buttons_test.rb`, receiving-related tests per program-plan.
