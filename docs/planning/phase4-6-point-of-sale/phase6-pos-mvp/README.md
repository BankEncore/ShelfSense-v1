# Phase 6 — Operational POS MVP

**Status:** Slice 6.0 contract locked. Slices 6.1–6.8 are implemented.

| Document | Purpose |
|---|---|
| [phase6-plan.md](phase6-plan.md) | Scope, locked invariants, slice map, deferrals, merge-to-main, acceptance |
| [mvp-contract.md](mvp-contract.md) | Slice 6.0: CompletedPosOperation v2 shape and cross-cutting locks |
| [merchandise-breadth.md](merchandise-breadth.md) | Slice 6.1: Used/individual and non-inventory sales (implemented) |
| [tender-breadth.md](tender-breadth.md) | Slice 6.2: Cash/Card/Check/Other settlement (implemented) |
| [transaction-history.md](transaction-history.md) | Slice 6.3: completed lookup, detail, reprint (implemented) |
| [controlled-actions.md](controlled-actions.md) | Slice 6.4: price override, line discount, Tax Class override (implemented) |
| [returns.md](returns.md) | Slice 6.5: linked/unlinked returns, refunds, mixed sale+return (6.5A–D implemented) |
| [post-void.md](post-void.md) | Slice 6.6: whole-transaction compensating fact (implemented) |
| [pos-workflow.md](pos-workflow.md) | Slice 6.7: cashier Home, keys, pickers, open-price Standard, return entry, X Report (implemented) |
| [mvp-closeout.md](mvp-closeout.md) | Slice 6.8: presentation, regression; no new commercial behavior (implemented) |
| [receipt-presentation.md](receipt-presentation.md) | Customer print/reprint layout (implemented in 6.8) |

Parent multi-phase sequencing: [../spec.md](../spec.md). Phase 4 completion kernel: [../phase4-point-of-sale/](../phase4-point-of-sale/). Phase 5 cash register: [../phase5-cash-register/](../phase5-cash-register/).

Where this packet and `../spec.md` disagree on Phase 6 slice order, open ring, suspend/recall, cash operations, Store Close, or MVP deferrals, **prefer this packet**. 6.2–6.8 contracts are written. Slices 6.7 and 6.8 are implemented.
