# Phase 6 — Operational POS MVP

**Status:** Slice 6.0 contract locked. Slice 6.1 merchandise breadth is implemented. Slice 6.2 tender breadth is implemented ([tender-breadth.md](tender-breadth.md)). Slice 6.3 transaction history is implemented ([transaction-history.md](transaction-history.md)). Slice 6.4 controlled actions are implemented ([controlled-actions.md](controlled-actions.md)).

| Document | Purpose |
|---|---|
| [phase6-plan.md](phase6-plan.md) | Scope, locked invariants, slice map, deferrals, merge-to-main, acceptance |
| [mvp-contract.md](mvp-contract.md) | Slice 6.0: CompletedPosOperation v2 shape and cross-cutting locks |
| [merchandise-breadth.md](merchandise-breadth.md) | Slice 6.1: Used/individual and non-inventory sales (implemented) |
| [tender-breadth.md](tender-breadth.md) | Slice 6.2: Cash/Card/Check/Other settlement (implemented) |
| [transaction-history.md](transaction-history.md) | Slice 6.3: completed lookup, detail, reprint (implemented) |
| [controlled-actions.md](controlled-actions.md) | Slice 6.4: price override, line discount, Tax Class override (implemented) |

Parent multi-phase sequencing: [../spec.md](../spec.md). Phase 4 completion kernel: [../phase4-point-of-sale/](../phase4-point-of-sale/). Phase 5 cash register: [../phase5-cash-register/](../phase5-cash-register/).

Where this packet and `../spec.md` disagree on Phase 6 slice order, open ring, suspend/recall, cash operations, Store Close, or MVP deferrals, **prefer this packet**. Write the detailed implementation contract for slices 6.2–6.7 immediately before building each slice.
