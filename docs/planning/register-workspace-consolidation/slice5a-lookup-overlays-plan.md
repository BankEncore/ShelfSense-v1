# Slice 5A — Lookup overlays

Status: **Implementation-ready.** Slice 4 is on `register-workspace-consolidation` ([#85](https://github.com/BankEncore/ShelfSense-v1/issues/85) / PR #98).

Authority: [plan.md](plan.md), [routing-and-authority.md](routing-and-authority.md), [textual-wireframes.md](textual-wireframes.md) O2–O5 / Part IV, [user-stories.md](user-stories.md), Phase 6.7 launch keys (`/`, `.`) until 7C.

Issue: [#86](https://github.com/BankEncore/ShelfSense-v1/issues/86). Branch: `86-lookup-overlays`. PR target: `register-workspace-consolidation`.

## Outcome

Establish the **shared blocking-overlay lifecycle** used by 5A–5D: top-layer tracking, background/parent inertness, entry focus, invocation-aware focus restoration, asynchronous request invalidation, local status feedback, and keyboard/pointer parity. Apply the **full visual lookup frame** only to the 5A family (product / variant / unit / customer / pickup). Open-price remains a resolve child with focus and zero-cent prefill fixes only.

## Scope

| In | Out |
|---|---|
| Overlay stack API replacing hard-coded priority lists | 5B returns content (O6–O8) |
| Workspace background inert + shell header/status inert while blocking | Blanket shell-background inert (would disable overlays) |
| O2 chrome for search / customer / pickup | Relocating overlays to shell-level host |
| O3 staged product → variant → unit with Back + Confirm | 5C controlled-action content |
| O4 customer, O5 pickup | 5D tender/issuance content |
| Async AbortController / request tokens | Slice 7 key remaps / tender replacement |
| Pointer select + explicit confirm; keyboard parity | Full customer create/merge |
| Open-price `currentCents != null` prefill + select-all | Quantity editor ownership |

Endpoints stay. Delete obsolete lookup targets/handlers in the same PR.

## Locked contracts

### 1. Overlay stack and restoration

Replace hard-coded `activeOverlayElement` priority with a LIFO stack of visible overlays:

```js
showOverlay(overlay, { initialFocus, opener, parent } = {})
hideOverlay(overlay)
topOverlay()
restoreOverlayFocus(closedOverlay)
```

Each open records: overlay node, invoking element, parent overlay (if any), preferred entry target.

- Escape closes **only the top** overlay.
- Child close restores the parent’s prior meaningful control (selected row or query).
- Root close restores the transaction command field and clears workspace-background inert.
- Closing a parent closes or invalidates its children.
- Turbo workspace replacement clears the stack safely.

Locked transitions: command → search → Escape → command; search → product/variant/unit → Escape → prior stage; parent → open-price → Escape → parent selection.

### 2. Genuine modal / inert

```erb
<div data-register-workspace-target="background">
  command / main / actions / forms
</div>
overlays
```

- Root open: workspace `background` is `inert`; overlays remain outside that subtree.
- Nested open: parent overlay is `inert`; only the top overlay is the effective modal surface.
- Shell: when any `[data-register-blocking-overlay]:not([hidden])` is present, header and status are `inert`. Do **not** inert the entire shell background.
- F10 remains suppressed while any blocking overlay is open (Slice 3).
- Assert actual `inert` in system tests, not only Tab containment.

### 3. Asynchronous lookup lifecycle

Per lookup family (search, pickup, customer): `AbortController` and/or monotonically increasing request token. Apply a response only when the request is still current, the overlay is still open, and the controller is still connected.

| Result | Focus |
|---|---|
| Loading | Remains in query; announce loading |
| Successful usable results | First **enabled** result |
| Empty | Stay/return to query; select existing query text |
| Error | Stay/return to query; preserve query; announce error |
| Stale/aborted | No DOM or focus change |
| All results disabled | Keep focus in query |

### 4. Pointer behavior and confirmation

Selection alone does not commit. Enter on a selected enabled row and the visible primary button perform the same commit. Disabled rows cannot be selected or committed. Every 5A lookup is completable pointer-only.

| Overlay | Secondary | Primary |
|---|---|---|
| Product search | Keep Searching | Choose Product |
| Variant chooser | Back to Products (when applicable) | Choose Variant |
| Unit chooser | Back to Variants (when applicable) | Add to Sale |
| Customer | Keep Current Customer / Close | Attach Customer |
| Pickup | Keep Transaction Unchanged | Add Pickup Items |

O3 Back is in scope: Back and Escape both dismiss the child and restore the parent stage.

### 5. Focus / keyboard entry

1. On open: focus first meaningful control (first text/search field, else first selected enabled list row).
2. Prepopulated text fields: after focus, `select()` so the next keystroke replaces the value.
3. Empty fields: focus only.
4. Tab / Shift+Tab trap inside the top overlay.
5. Printable keys never redirect to the command field while focus is in an overlay field.
6. F10 suppressed while any blocking overlay is open.

### 6. Open-price prefill

```js
currentCents != null ? this.formatCents(currentCents) : ""
```

- Nonzero edit → full value selected
- Zero-price edit → `0.00` selected (not blank)
- New add → empty focused field

Distinguish Add vs Edit in visible copy when invocation context knows; no service behavior change.

## Shared visual frame (5A family)

Title + Close; instruction; search controls where applicable; local feedback/loading/empty/error; results listbox; optional selected detail; footer secondary + primary. Lifecycle APIs are shared with 5B–5D without redesigning those families’ content.

## Tests

System coverage (no JS unit runner): workspace background inert; nested parent inert; child Escape → parent; root Escape → command; click select + confirm commit; disabled skipped; empty/all-disabled keep query; Escape during fetch; out-of-order search; Turbo aborts pending; zero/nonzero open-price select; pointer-only product/customer/pickup; Back from variant/unit.

## Explicit non-goals

Remapping `/` / `.`; return/control/tender content redesign; shell-level overlay host relocation; full customer create/merge; gift-card issuance inline focus (5D).

## Implementation sequence

1. Commit this packet (+ manual verification stub).
2. Overlay lifecycle (stack, workspace background, shell header/status inert).
3. Focus + async tokens + open-price nullish prefill.
4. Pointer select, confirm/Back, decoratePickerItem for pickup/customer.
5. Visual O2 chrome for 5A family; delete obsolete targets.
6. System matrix + docs; PR; close #86 manually after merge.
