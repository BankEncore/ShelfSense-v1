# UDS-3 user stories

Status: **Implemented** ([uds-3-plan.md](uds-3-plan.md)); matrix evidence still pending for **conforming**.

---

## UDS-3a — Basket

### US-UDS-3a-1 — Two-level basket hierarchy

As a cashier, I need each line to show a clear title and secondary metadata so dense baskets stay scannable.

**Acceptance**

- [x] Working basket lines show primary title and secondary metadata from snapshots.
- [x] Selected and controlled lines are visually distinct with tokens.
- [x] Printed receipt description contract unchanged.

---

## UDS-3b — Shortcuts and overlays

### US-UDS-3b-1 — Visual shortcut groups with frozen bindings

As a cashier, I need related commands clustered visually without learning new keys.

**Acceptance**

- [x] Merchandise/control, tender, and cancel groups are visually separated.
- [x] Each command keeps exact `data-action`, targets, labels, and relative order.
- [x] Overlay focus/Escape/scan behavior unchanged; system Register tests green.

---

## UDS-3c — Exit

### US-UDS-3c-1 — Docs and evidence

**Acceptance**

- [x] Plan/stories/indexes updated; matrix partial until a11y evidence.
- [ ] Accessibility-ergonomic matrix evidence attached (manual).
