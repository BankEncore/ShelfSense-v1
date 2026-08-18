# Phase 5 — First Operational Cash Register

**Status:** Slice 1 (headless cash / Z) implemented. Slice 2 Register workspace implemented. Slice 3 print and close/Z screens implemented.

| Document | Purpose |
|---|---|
| [phase5-plan.md](phase5-plan.md) | Scope, locked decisions, slices, acceptance |
| [phase5-schema.md](phase5-schema.md) | Session cash columns and reporting-period Z snapshots |
| [register-workspace.md](register-workspace.md) | Slice 2 open gate, modes, HTTP/retry, focus, completion receipt vs print |
| [register-workspace-ux.md](register-workspace-ux.md) | Slice 2 low-fidelity wireframes (focus, Enter/Escape, shortcuts, Turbo regions) |
| [close-z-screens.md](close-z-screens.md) | Slice 3 print, blind close, enter-gate Z, HTTP/auth/retry |
| [close-z-screens-ux.md](close-z-screens-ux.md) | Slice 3 low-fidelity frames (receipt, blind count, closed Session, Z) |

Parent multi-phase sequencing: [../spec.md](../spec.md). Phase 4 completion kernel: [../phase4-point-of-sale/](../phase4-point-of-sale/). Phase 6 operational POS MVP: [../phase6-pos-mvp/](../phase6-pos-mvp/).

Where this packet and `../spec.md` disagree on cash columns, expected-cash formula, Z snapshots, authorization, or the register workspace interaction contract, **prefer this packet**.
